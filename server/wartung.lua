-- =============================================================================
--  clp_realtuner - Wartung / Fluessigkeiten / Verschleiss (Server)
--  Standzeit-basierter Verschleiss: Rost draussen, Batterie entlaedt.
--  Clients schicken Delta-Updates aus client/wartung.lua.
-- =============================================================================

HCM = HCM or {}
HCM.server = HCM.server or {}

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Standzeit-Tick: alle 5 Minuten alle geparkten VINs erfassen. ---------------
CreateThread(function()
    Wait(60 * 1000) -- einmal anlaufen lassen
    while true do
        Wait(5 * 60 * 1000) -- alle 5 Minuten
        local wartung = Config.Wartung or {}
        local rows = MySQL.query.await([[
            SELECT plate, battery, rust, paint_quality, battery_last_ts, coolant_temp
            FROM vehicles_data
            WHERE battery > 0 OR rust < 100
        ]]) or {}
        local now = os.time()
        for _, row in ipairs(rows) do
            local lastTs = tonumber(row.battery_last_ts) or now
            local hours = math.max(0, (now - lastTs) / 3600)
            if hours > 0.1 then
                local battery = clamp((tonumber(row.battery) or 100)
                    - hours * (wartung.BatteryDrainPerHour or 0.8), 0, 100)
                local rustProtect = (tonumber(row.paint_quality) or 100) > 80
                    and (wartung.RustPaintProtect or 0.4) or 1.0
                local rust = clamp((tonumber(row.rust) or 0)
                    + hours * (wartung.RustPerHourOutdoor or 0.015) * rustProtect, 0, 100)
                local coolant = math.max(tonumber(row.coolant_temp) or 85,
                    wartung.CoolantAmbient or 20)
                if coolant > (wartung.CoolantAmbient or 20) then
                    coolant = math.max(wartung.CoolantAmbient or 20,
                        coolant - hours * 60 * (wartung.CoolantCoolDownPerSecondOff or 0.8))
                end
                MySQL.update.await([[
                    UPDATE vehicles_data SET battery=?, rust=?, coolant_temp=?, battery_last_ts=?
                    WHERE plate=?
                ]], { battery, rust, coolant, now, row.plate })
                -- Cache-Update wenn geladen
                local rec = HCM.server.getRecord and HCM.server.getRecord(row.plate)
                if rec then
                    rec.battery = battery
                    rec.rust = rust
                    rec.coolant_temp = coolant
                    rec.battery_last_ts = now
                end
            end
        end
    end
end)

-- Client -> Server Delta-Update ---------------------------------------------
RegisterNetEvent('clp_realtuner:wartung:delta', function(plate, delta)
    if type(plate) ~= 'string' or type(delta) ~= 'table' then return end
    plate = HCM.util.normalizePlate(plate)
    local rec = HCM.server.loadRecord(plate)
    if not rec then return end
    local fields = {
        oil_km = { cap = 99999, add = true },
        oil_quality = { min = 0, max = 100 },
        spark_plug = { min = 0, max = 100 },
        battery = { min = 0, max = 100 },
        brake_fluid = { min = 0, max = 100 },
        coolant = { min = 0, max = 100 },
        coolant_temp = { min = -20, max = 140 },
        headlight_state = { min = 0, max = 100 },
        rearlight_state = { min = 0, max = 100 },
        fuel_leak = { min = 0, max = 100 },
        rust = { min = 0, max = 100 },
    }
    for k, spec in pairs(fields) do
        if delta[k] ~= nil then
            local cur = tonumber(rec[k]) or 0
            local next_val
            if spec.add then
                next_val = cur + (tonumber(delta[k]) or 0)
                if spec.cap then next_val = math.min(next_val, spec.cap) end
            else
                next_val = clamp(tonumber(delta[k]) or cur,
                    spec.min or 0, spec.max or 100)
            end
            rec[k] = next_val
        end
    end
    if delta.windshield_broken ~= nil then
        rec.windshield_broken = delta.windshield_broken and true or false
    end
    HCM.server.markDirty(plate)
end)

-- Service-Reset ---------------------------------------------------------------
RegisterNetEvent('clp_realtuner:wartung:service', function(plate, svc)
    local src = source
    plate = HCM.util.normalizePlate(plate or '')
    local rec = HCM.server.loadRecord(plate)
    if not rec then return end
    local xPlayer = (exports['es_extended']:getSharedObject()).GetPlayerFromId(src)
    svc = svc or {}
    if svc.oil then
        rec.oil_km = 0; rec.oil_quality = 100.0
    end
    if svc.spark then rec.spark_plug = 100.0 end
    if svc.battery then rec.battery = 100.0; rec.battery_last_ts = os.time() end
    if svc.lights then rec.headlight_state = 100.0; rec.rearlight_state = 100.0 end
    if svc.brakefluid then rec.brake_fluid = 100.0 end
    if svc.coolant then rec.coolant = 100.0 end
    if svc.fuel then rec.fuel_leak = 0.0 end
    if svc.rust and (Config.Wartung.RustResetOnService) then rec.rust = 0.0 end
    if svc.windshield then rec.windshield_broken = false end
    HCM.server.markDirty(plate)
    if HCM.server.log then HCM.server.log(xPlayer, 'wartung:service', plate, rec.vin, svc) end
    TriggerClientEvent('clp_realtuner:wartung:synced', -1, plate, {
        oil_km = rec.oil_km, oil_quality = rec.oil_quality, spark_plug = rec.spark_plug,
        battery = rec.battery, headlight_state = rec.headlight_state, rearlight_state = rec.rearlight_state,
        brake_fluid = rec.brake_fluid, coolant = rec.coolant, fuel_leak = rec.fuel_leak,
        rust = rec.rust, windshield_broken = rec.windshield_broken,
    })
end)

-- Physik-Toggles (TC, ABS, Auspuffklappe) -----------------------------------
RegisterNetEvent('clp_realtuner:physics:toggle', function(plate, key, value)
    plate = HCM.util.normalizePlate(plate or '')
    local rec = HCM.server.loadRecord(plate)
    if not rec then return end
    if key == 'tc' then rec.tc_enabled = value and true or false
    elseif key == 'abs' then rec.abs_enabled = value and true or false
    elseif key == 'flap' then rec.exhaust_flap = value and true or false
    else return end
    HCM.server.markDirty(plate)
    TriggerClientEvent('clp_realtuner:physics:synced', -1, plate, key, rec[key == 'tc' and 'tc_enabled' or key == 'abs' and 'abs_enabled' or 'exhaust_flap'])
end)
