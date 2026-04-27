-- =============================================================================
--  clp_realtuner - Visuelle Overlays (Batch 3)
--  Thermal-View, Damage-3D, Live-Slider, Sound-Preview
-- =============================================================================

HCM_C = HCM_C or {}

local function sendNui(action, data) SendNUIMessage({ action = action, data = data }) end

-- ============================================================================
-- Thermal-View: Hitze-Verteilung auf Motor
-- ============================================================================
function HCM_C.openThermal(veh)
    veh = veh or GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then
        local ped = PlayerPedId()
        local c = GetEntityCoords(ped)
        veh = GetClosestVehicle(c.x, c.y, c.z, 5.0, 0, 71)
    end
    if veh == 0 or not DoesEntityExist(veh) then return end
    local rec = HCM_C.getRecord(veh)
    if not rec then return end
    local eh = rec.engine_health or 100
    local cool = rec.coolant or 100
    local coolTemp = rec.coolant_temp or 85
    local turboH = rec.turbo_health or 100
    local oil = rec.oil_quality or 100
    local zones = {
        { id='block',   label='Motorblock',     temp = math.floor(coolTemp + (100 - eh) * 0.5) },
        { id='head',    label='Zylinderkopf',   temp = math.floor(coolTemp + (100 - eh) * 0.7) },
        { id='turbo',   label='Turbo',          temp = math.floor(250 + (100 - turboH) * 2) },
        { id='exhaust', label='Auspuffkruemmer', temp = math.floor(300 + (100 - eh) * 1.5) },
        { id='oilpan',  label='Oelwanne',       temp = math.floor(coolTemp - 5 + (100 - oil) * 0.4) },
        { id='rad',     label='Kuehler',        temp = math.floor(coolTemp - 10 - (100 - cool) * 0.3) },
        { id='battery', label='Batterie',       temp = math.floor(30 + (100 - (rec.battery or 100)) * 0.4) },
        { id='intake',  label='Ansaugung',      temp = math.floor(25 + (100 - eh) * 0.2) },
    }
    sendNui('thermal:open', {
        plate = HCM_C.plateOf(veh),
        zones = zones,
        avgTemp = coolTemp,
        critical = coolTemp > 105 or turboH < 30,
    })
    SetNuiFocus(true, true)
end
exports('openThermal', HCM_C.openThermal)
RegisterNUICallback('thermal:close', function(_, cb) SetNuiFocus(false, false); cb({ ok = true }) end)

-- ============================================================================
-- Damage-3D: klickbares SVG-Auto mit Komponenten-Status
-- ============================================================================
function HCM_C.openDamage3D(veh)
    veh = veh or GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then
        local ped = PlayerPedId()
        local c = GetEntityCoords(ped)
        veh = GetClosestVehicle(c.x, c.y, c.z, 5.0, 0, 71)
    end
    if veh == 0 or not DoesEntityExist(veh) then return end
    local rec = HCM_C.getRecord(veh)
    if not rec then return end
    local bodyHealth = GetVehicleBodyHealth(veh)
    local components = {
        { id='engine',   label='Motor',        hp = rec.engine_health or 100 },
        { id='trans',    label='Getriebe',     hp = rec.transmission_health or 100 },
        { id='brakes',   label='Bremsen',      hp = rec.brake_health or 100 },
        { id='turbo',    label='Turbo',        hp = rec.turbo_health or 100 },
        { id='susp',     label='Fahrwerk',     hp = rec.suspension_health or 100 },
        { id='body',     label='Karosserie',   hp = bodyHealth / 10 },
        { id='paint',    label='Lack',         hp = rec.paint_quality or 100 },
        { id='fl',       label='Reifen vl',    hp = GetVehicleWheelHealth(veh, 0) / 10 },
        { id='fr',       label='Reifen vr',    hp = GetVehicleWheelHealth(veh, 1) / 10 },
        { id='rl',       label='Reifen hl',    hp = GetVehicleWheelHealth(veh, 2) / 10 },
        { id='rr',       label='Reifen hr',    hp = GetVehicleWheelHealth(veh, 3) / 10 },
        { id='windows',  label='Scheiben',     hp = rec.windshield_broken and 0 or 100 },
    }
    sendNui('damage3d:open', {
        plate = HCM_C.plateOf(veh),
        model = GetDisplayNameFromVehicleModel(GetEntityModel(veh)),
        components = components,
    })
    SetNuiFocus(true, true)
end
exports('openDamage3D', HCM_C.openDamage3D)
RegisterNUICallback('damage3d:close', function(_, cb) SetNuiFocus(false, false); cb({ ok = true }) end)

-- ============================================================================
-- Live-Slider: Ride-Height & Camber mit Live-Vorschau
-- ============================================================================
RegisterNUICallback('tune:setRideHeight', function(data, cb)
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then cb({ ok = false }); return end
    local h = tonumber(data.value) or 0.0 -- -0.15 .. +0.10
    h = math.max(-0.15, math.min(0.10, h))
    SetVehicleSuspensionHeight(veh, h)
    local plate = HCM_C.plateOf(veh)
    if plate then
        local rec = HCM_C.getRecord(veh)
        if rec then
            rec.tuning_data = rec.tuning_data or {}
            rec.tuning_data.ride_height = h
            TriggerServerEvent('clp_realtuner:patch', plate, { tuning_data = rec.tuning_data }, 'tune:ride_height')
        end
    end
    cb({ ok = true, value = h })
end)

RegisterNUICallback('tune:setFlap', function(data, cb)
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then cb({ ok = false }); return end
    local plate = HCM_C.plateOf(veh)
    if plate then
        local rec = HCM_C.getRecord(veh)
        if rec then
            rec.exhaust_flap = data.value and true or false
            TriggerServerEvent('clp_realtuner:physics:toggle', plate, 'flap', rec.exhaust_flap)
        end
    end
    cb({ ok = true })
end)

-- ============================================================================
-- Sound-Preview: kurzer Motor-Sound Vorschau
-- ============================================================================
RegisterNUICallback('sound:preview', function(data, cb)
    local engineName = data and data.engine
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 or not engineName then cb({ ok = false }); return end
    -- Apply engine sound temporarily, restore after 6s
    local prev = GetVehicleEngineHash and GetVehicleEngineHash(veh) or nil
    ForceVehicleEngineAudio(veh, engineName)
    SetVehicleEngineOn(veh, true, false, false)
    CreateThread(function()
        Wait(6000)
        if prev and DoesEntityExist(veh) then
            -- zuruecksetzen auf Modell-Default
            ForceVehicleEngineAudio(veh, '')
        end
    end)
    cb({ ok = true })
end)
