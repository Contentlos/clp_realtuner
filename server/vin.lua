-- =============================================================================
--  clp_hardcore_mechanic - VIN & Persistenz (Server)
-- =============================================================================

HCM = HCM or {}
HCM.server = HCM.server or {}

local cache = {}     -- plate -> record
local dirty = {}     -- plate -> true
local loading = {}   -- plate -> promise

local DEFAULT_RECORD = {
    engine_health       = 100.0,
    transmission_health = 100.0,
    brake_health        = 100.0,
    turbo_health        = 100.0,
    suspension_health   = 100.0,
    ecu_state           = { afr = 14.7, torque = 1.0, fuel = 1.0 },
    installed_parts     = {},
    tuning_data         = {},
    last_service        = 0,
    odometer            = 0,
    paint_quality       = 100.0,
    -- Migration 001: Fluids / Wear / Physics
    oil_km              = 0,
    oil_quality         = 100.0,
    fuel_leak           = 0.0,
    spark_plug          = 100.0,
    battery             = 100.0,
    battery_last_ts     = 0,
    headlight_state     = 100.0,
    rearlight_state     = 100.0,
    brake_fluid         = 100.0,
    coolant             = 100.0,
    coolant_temp        = 85.0,
    rust                = 0.0,
    windshield_broken   = false,
    tc_enabled          = true,
    abs_enabled         = true,
    exhaust_flap        = false,
    ecu_map             = 'stock',
    tuev_expires        = 0,
    neon                = nil,
    tint                = 0.0,
    wrap                = nil,
    interior_mods       = nil,
}

local function deepCopy(t)
    if type(t) ~= 'table' then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = deepCopy(v) end
    return r
end

local function jsonDecode(s)
    if s == nil or s == '' then return nil end
    local ok, v = pcall(json.decode, s)
    if ok then return v end
    return nil
end

local function jsonEncode(v)
    return json.encode(v or {})
end

local function normalize(plate)
    return (plate or ''):gsub('%s', ''):upper()
end

---@param plate string
---@return table record
function HCM.server.loadRecord(plate, model)
    plate = normalize(plate)
    if cache[plate] then return cache[plate] end
    if loading[plate] then
        while loading[plate] do Wait(25) end
        return cache[plate]
    end
    loading[plate] = true

    local row = MySQL.single.await(
        'SELECT * FROM vehicles_data WHERE plate = ? LIMIT 1', { plate }
    )

    local rec
    if row then
        rec = {
            plate               = plate,
            vin                 = row.vin,
            model               = row.model,
            engine_health       = tonumber(row.engine_health)       or 100.0,
            transmission_health = tonumber(row.transmission_health) or 100.0,
            brake_health        = tonumber(row.brake_health)        or 100.0,
            turbo_health        = tonumber(row.turbo_health)        or 100.0,
            suspension_health   = tonumber(row.suspension_health)   or 100.0,
            ecu_state           = jsonDecode(row.ecu_state)         or deepCopy(DEFAULT_RECORD.ecu_state),
            installed_parts     = jsonDecode(row.installed_parts)   or {},
            tuning_data         = jsonDecode(row.tuning_data)       or {},
            last_service        = tonumber(row.last_service)        or 0,
            odometer            = tonumber(row.odometer)            or 0,
            paint_quality       = tonumber(row.paint_quality)       or 100.0,
            -- Migration 001 Felder (mit Fallbacks falls Migration noch nicht gelaufen)
            oil_km              = tonumber(row.oil_km)           or 0,
            oil_quality         = tonumber(row.oil_quality)      or 100.0,
            fuel_leak           = tonumber(row.fuel_leak)        or 0.0,
            spark_plug          = tonumber(row.spark_plug)       or 100.0,
            battery             = tonumber(row.battery)          or 100.0,
            battery_last_ts     = tonumber(row.battery_last_ts)  or os.time(),
            headlight_state     = tonumber(row.headlight_state)  or 100.0,
            rearlight_state     = tonumber(row.rearlight_state)  or 100.0,
            brake_fluid         = tonumber(row.brake_fluid)      or 100.0,
            coolant             = tonumber(row.coolant)          or 100.0,
            coolant_temp        = tonumber(row.coolant_temp)     or 85.0,
            rust                = tonumber(row.rust)             or 0.0,
            windshield_broken   = (tonumber(row.windshield_broken) or 0) == 1,
            tc_enabled          = (tonumber(row.tc_enabled) or 1) == 1,
            abs_enabled         = (tonumber(row.abs_enabled) or 1) == 1,
            exhaust_flap        = (tonumber(row.exhaust_flap) or 0) == 1,
            ecu_map             = row.ecu_map or 'stock',
            tuev_expires        = tonumber(row.tuev_expires)     or 0,
            neon                = jsonDecode(row.neon),
            tint                = tonumber(row.tint)             or 0.0,
            wrap                = jsonDecode(row.wrap),
            interior_mods       = jsonDecode(row.interior_mods),
        }
    else
        rec = deepCopy(DEFAULT_RECORD)
        rec.plate = plate
        rec.model = model
        rec.vin   = HCM.util.generateVIN(plate, model, os.time())
        MySQL.insert.await(
            'INSERT INTO vehicles_data (plate, vin, model, ecu_state, installed_parts, tuning_data, last_service) VALUES (?, ?, ?, ?, ?, ?, ?)',
            { plate, rec.vin, model or nil, jsonEncode(rec.ecu_state), jsonEncode(rec.installed_parts), jsonEncode(rec.tuning_data), os.time() }
        )
    end

    cache[plate] = rec
    loading[plate] = nil
    return rec
end

function HCM.server.getRecord(plate)
    plate = normalize(plate)
    return cache[plate]
end

function HCM.server.markDirty(plate)
    dirty[normalize(plate)] = true
end

---@param rec table
function HCM.server.applyPatch(plate, patch)
    plate = normalize(plate)
    local rec = cache[plate]
    if not rec then return nil end
    for k, v in pairs(patch or {}) do rec[k] = v end
    dirty[plate] = true
    return rec
end

---@param plate string
local function boolToInt(v) return v and 1 or 0 end

function HCM.server.save(plate)
    plate = normalize(plate)
    local rec = cache[plate]
    if not rec then return end
    -- zuerst die Kern-Felder (immer vorhanden)
    MySQL.update.await([[
        UPDATE vehicles_data
        SET engine_health=?, transmission_health=?, brake_health=?, turbo_health=?,
            suspension_health=?, ecu_state=?, installed_parts=?, tuning_data=?,
            last_service=?, odometer=?, paint_quality=?, model=COALESCE(?, model)
        WHERE plate=?
    ]], {
        rec.engine_health, rec.transmission_health, rec.brake_health, rec.turbo_health,
        rec.suspension_health, jsonEncode(rec.ecu_state), jsonEncode(rec.installed_parts),
        jsonEncode(rec.tuning_data), rec.last_service, rec.odometer, rec.paint_quality,
        rec.model, plate,
    })
    -- Migration 001 Felder - pcall, damit das Speichern auch ohne gelaufene
    -- Migration nicht den kompletten Save-Flow kaputtmacht
    pcall(function()
        MySQL.update.await([[
            UPDATE vehicles_data SET
                oil_km=?, oil_quality=?, fuel_leak=?, spark_plug=?, battery=?, battery_last_ts=?,
                headlight_state=?, rearlight_state=?, brake_fluid=?, coolant=?, coolant_temp=?,
                rust=?, windshield_broken=?, tc_enabled=?, abs_enabled=?, exhaust_flap=?,
                ecu_map=?, tuev_expires=?, neon=?, tint=?, wrap=?, interior_mods=?
            WHERE plate=?
        ]], {
            rec.oil_km or 0, rec.oil_quality or 100.0, rec.fuel_leak or 0.0, rec.spark_plug or 100.0,
            rec.battery or 100.0, rec.battery_last_ts or os.time(),
            rec.headlight_state or 100.0, rec.rearlight_state or 100.0,
            rec.brake_fluid or 100.0, rec.coolant or 100.0, rec.coolant_temp or 85.0,
            rec.rust or 0.0,
            boolToInt(rec.windshield_broken), boolToInt(rec.tc_enabled ~= false),
            boolToInt(rec.abs_enabled ~= false), boolToInt(rec.exhaust_flap),
            rec.ecu_map or 'stock', rec.tuev_expires or 0,
            rec.neon and jsonEncode(rec.neon) or nil, rec.tint or 0.0,
            rec.wrap and jsonEncode(rec.wrap) or nil,
            rec.interior_mods and jsonEncode(rec.interior_mods) or nil,
            plate,
        })
    end)
    dirty[plate] = nil
end

function HCM.server.saveAllDirty()
    for plate in pairs(dirty) do
        HCM.server.save(plate)
    end
end

-- Periodischer Auto-Save ------------------------------------------------------
CreateThread(function()
    while true do
        Wait(Config.AutoSaveInterval or 60000)
        HCM.server.saveAllDirty()
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    HCM.server.saveAllDirty()
end)

AddEventHandler('txAdmin:events:serverShuttingDown', function()
    HCM.server.saveAllDirty()
end)
