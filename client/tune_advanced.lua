-- =============================================================================
--  clp_realtuner - Erweiterte Tuning-Features (Batch 5)
--   - ECU-Maps (Eco/Sport/Race)
--   - Neon-Unterboden + Farben
--   - Felgen-Farbe, Bremssattel-Farbe
--   - Scheiben-Toenung (Prozent)
--   - Innenraum-Mods (Sport-Lenkrad, Leder-Sitze)
--   - Wraps (Livery-Pattern)
--   - Motor-Swap (Sound + Power)
--   - Supercharger (alternative zum Turbo)
-- =============================================================================

HCM_C = HCM_C or {}

local function sendNui(action, data) SendNUIMessage({ action = action, data = data }) end

local function getVeh() return GetVehiclePedIsIn(PlayerPedId(), false) end

-- ============================================================================
-- ECU-Map-Presets (Eco / Sport / Race)
-- ============================================================================
local MAP_PRESETS = {
    stock = { power = 1.0,  accel = 0,  label = 'Stock (Serie)',   torque = 1.0,  afr = 14.7 },
    eco   = { power = 0.9,  accel = -5, label = 'Eco',             torque = 0.9,  afr = 15.5 },
    sport = { power = 1.12, accel = 8,  label = 'Sport',           torque = 1.12, afr = 14.0 },
    race  = { power = 1.25, accel = 18, label = 'Race (Risiko!)',  torque = 1.22, afr = 13.2 },
}

function HCM_C.setEcuMap(veh, mapName)
    if not MAP_PRESETS[mapName] then return false end
    local preset = MAP_PRESETS[mapName]
    local plate = HCM_C.plateOf(veh); if not plate then return false end
    local rec = HCM_C.getRecord(veh); if not rec then return false end
    SetVehicleEnginePowerMultiplier(veh, (preset.power - 1.0) * 100.0)
    rec.ecu_map = mapName
    rec.tuning_data = rec.tuning_data or {}
    rec.tuning_data.accel = (preset.accel or 0)
    rec.ecu_state = rec.ecu_state or {}
    rec.ecu_state.afr = preset.afr
    rec.ecu_state.torque = preset.torque
    HCM_C.pushPatch(plate, { ecu_map = mapName, tuning_data = rec.tuning_data, ecu_state = rec.ecu_state }, 'ecu:map_' .. mapName)
    if HCM_C.applyHandling then HCM_C.applyHandling(veh) end
    lib.notify({ title = 'ECU Map', description = preset.label .. ' aktiv.', type = 'success' })
    return true
end

RegisterNUICallback('tune:setEcuMap', function(data, cb)
    local veh = getVeh()
    if veh == 0 then cb({ ok = false }); return end
    local ok = HCM_C.setEcuMap(veh, data.map or 'stock')
    cb({ ok = ok })
end)

-- ============================================================================
-- Neon
-- ============================================================================
function HCM_C.setNeon(veh, opts)
    if not veh or not DoesEntityExist(veh) then return end
    opts = opts or {}
    local on = opts.on
    local color = opts.color or { 0, 255, 0 }
    for i = 0, 3 do SetVehicleNeonLightEnabled(veh, i, on and true or false) end
    if color then SetVehicleNeonLightsColour(veh, color[1] or 0, color[2] or 255, color[3] or 0) end
    local plate = HCM_C.plateOf(veh)
    if plate then
        local rec = HCM_C.getRecord(veh)
        if rec then
            rec.neon = { on = on and true or false, color = color }
            HCM_C.pushPatch(plate, { neon = rec.neon }, 'neon')
        end
    end
end

RegisterNUICallback('tune:setNeon', function(data, cb)
    local veh = getVeh(); if veh == 0 then cb({ ok = false }); return end
    HCM_C.setNeon(veh, data)
    cb({ ok = true })
end)

-- ============================================================================
-- Scheiben-Toenung (0 = klar, bis 4 = maximum)
-- ============================================================================
RegisterNUICallback('tune:setTint', function(data, cb)
    local veh = getVeh(); if veh == 0 then cb({ ok = false }); return end
    local level = math.max(0, math.min(4, tonumber(data.level) or 0))
    SetVehicleWindowTint(veh, level)
    local plate = HCM_C.plateOf(veh)
    if plate then
        local rec = HCM_C.getRecord(veh)
        if rec then
            rec.tint = level
            HCM_C.pushPatch(plate, { tint = level }, 'tint')
        end
    end
    cb({ ok = true, level = level })
end)

-- ============================================================================
-- Felgen- / Bremssattel-Farbe
-- ============================================================================
RegisterNUICallback('tune:setWheelColor', function(data, cb)
    local veh = getVeh(); if veh == 0 then cb({ ok = false }); return end
    SetVehicleMod(veh, 23, GetVehicleMod(veh, 23), (data.custom and true) or false)
    -- Bremssattel via extra color (Index 24 nutzt pearl fuer caliper seit manchen Updates)
    local _, _, pearl, wheelCol = GetVehicleColours(veh)
    SetVehicleExtraColours(veh, pearl or 0, tonumber(data.wheel) or wheelCol or 156)
    local plate = HCM_C.plateOf(veh)
    if plate then
        local rec = HCM_C.getRecord(veh)
        if rec then
            rec.tuning_data = rec.tuning_data or {}
            rec.tuning_data.wheel_color = tonumber(data.wheel) or 156
            HCM_C.pushPatch(plate, { tuning_data = rec.tuning_data }, 'tune:wheel_color')
        end
    end
    cb({ ok = true })
end)

RegisterNUICallback('tune:setCaliper', function(data, cb)
    local veh = getVeh(); if veh == 0 then cb({ ok = false }); return end
    local modIdx = tonumber(data.index) or -1
    if modIdx >= 0 then SetVehicleMod(veh, 22, modIdx, true) end
    local plate = HCM_C.plateOf(veh)
    if plate then
        local rec = HCM_C.getRecord(veh)
        if rec then
            rec.tuning_data = rec.tuning_data or {}
            rec.tuning_data.caliper_mod = modIdx
            HCM_C.pushPatch(plate, { tuning_data = rec.tuning_data }, 'tune:caliper')
        end
    end
    cb({ ok = true })
end)

-- ============================================================================
-- Innenraum-Mods (Sport-Lenkrad, Leder-Sitze)
-- ============================================================================
RegisterNUICallback('tune:setInterior', function(data, cb)
    local veh = getVeh(); if veh == 0 then cb({ ok = false }); return end
    local plate = HCM_C.plateOf(veh)
    local rec = plate and HCM_C.getRecord(veh)
    local key = data.key
    local idx = tonumber(data.index) or 0
    local slots = {
        steering_wheel = 33, shifter = 34, plaques = 35, seats = 32,
        dashboard = 29, dial = 30, speakers = 36, trunk = 37, engine_block = 31,
    }
    if slots[key] then
        SetVehicleMod(veh, slots[key], idx, true)
        if rec then
            rec.interior_mods = rec.interior_mods or {}
            rec.interior_mods[key] = idx
            HCM_C.pushPatch(plate, { interior_mods = rec.interior_mods }, 'tune:interior:' .. key)
        end
    end
    cb({ ok = true })
end)

-- ============================================================================
-- Wraps / Liveries (Livery index)
-- ============================================================================
RegisterNUICallback('tune:setLivery', function(data, cb)
    local veh = getVeh(); if veh == 0 then cb({ ok = false }); return end
    local idx = tonumber(data.index) or 0
    if GetVehicleModKit(veh) ~= 0 then SetVehicleModKit(veh, 0) end
    if GetVehicleLiveryCount(veh) > 0 then
        SetVehicleLivery(veh, idx)
    else
        SetVehicleMod(veh, 48, idx, true)  -- modern livery slot
    end
    local plate = HCM_C.plateOf(veh)
    if plate then
        local rec = HCM_C.getRecord(veh)
        if rec then
            rec.wrap = { livery = idx }
            HCM_C.pushPatch(plate, { wrap = rec.wrap }, 'tune:livery')
        end
    end
    cb({ ok = true })
end)

-- ============================================================================
-- Motor-Swap (Sound + Power)
-- ============================================================================
local ENGINE_PRESETS = {
    adder = { power = 1.15, label = 'Adder W16' },
    zentorno = { power = 1.12, label = 'Zentorno V12' },
    entityxf = { power = 1.10, label = 'Entity V10' },
    rhapsody = { power = 0.85, label = 'Rhapsody (Econo)' },
    infernus = { power = 1.08, label = 'Infernus V12' },
    diesel = { power = 0.92, label = 'Diesel (tief)' },
}

RegisterNUICallback('tune:engineSwap', function(data, cb)
    local veh = getVeh(); if veh == 0 then cb({ ok = false }); return end
    local name = data.engine
    if not ENGINE_PRESETS[name] then cb({ ok = false, reason = 'unknown engine' }); return end
    ForceVehicleEngineAudio(veh, name)
    SetVehicleEnginePowerMultiplier(veh, (ENGINE_PRESETS[name].power - 1.0) * 100.0)
    local plate = HCM_C.plateOf(veh)
    if plate then
        local rec = HCM_C.getRecord(veh)
        if rec then
            rec.tuning_data = rec.tuning_data or {}
            rec.tuning_data.engine_swap = name
            HCM_C.pushPatch(plate, { tuning_data = rec.tuning_data }, 'tune:engine_swap:' .. name)
        end
    end
    cb({ ok = true, power = ENGINE_PRESETS[name].power })
end)

-- ============================================================================
-- Apply on vehicle load (persistiere)
-- ============================================================================
CreateThread(function()
    while true do
        Wait(2000)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
            local rec = HCM_C.getRecord(veh)
            if rec then
                if rec.neon and rec.neon.on then
                    for i = 0, 3 do SetVehicleNeonLightEnabled(veh, i, true) end
                    if rec.neon.color then SetVehicleNeonLightsColour(veh, rec.neon.color[1] or 0, rec.neon.color[2] or 255, rec.neon.color[3] or 0) end
                end
                if rec.tint then SetVehicleWindowTint(veh, rec.tint) end
                if rec.ecu_map and rec.ecu_map ~= 'stock' and MAP_PRESETS[rec.ecu_map] then
                    SetVehicleEnginePowerMultiplier(veh, (MAP_PRESETS[rec.ecu_map].power - 1.0) * 100.0)
                end
                if rec.tuning_data and rec.tuning_data.engine_swap and ENGINE_PRESETS[rec.tuning_data.engine_swap] then
                    ForceVehicleEngineAudio(veh, rec.tuning_data.engine_swap)
                end
            end
        end
    end
end)
