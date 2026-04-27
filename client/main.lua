-- =============================================================================
--  clp_realtuner - Client Main (State, Spawn-Hooks, Bridge)
-- =============================================================================

local ESX = exports['es_extended']:getSharedObject()

HCM_C = HCM_C or {}
HCM_C.records = HCM_C.records or {}     -- plate -> record
HCM_C.pending = HCM_C.pending or {}     -- plate -> true (lade gerade)
HCM_C.me      = HCM_C.me or { skill = { level = 1, xp = 0 } }

local function plateOf(veh)
    if not veh or veh == 0 then return nil end
    local p = GetVehicleNumberPlateText(veh)
    if not p then return nil end
    return (p:gsub('%s', '')):upper()
end
HCM_C.plateOf = plateOf

function HCM_C.getRecord(veh, force)
    local plate = plateOf(veh)
    if not plate then return nil end
    if HCM_C.records[plate] and not force then return HCM_C.records[plate] end
    if HCM_C.pending[plate] then
        local deadline = GetGameTimer() + 3000
        while HCM_C.pending[plate] and GetGameTimer() < deadline do Wait(25) end
        return HCM_C.records[plate]
    end
    HCM_C.pending[plate] = true
    local model = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
    local rec = lib.callback.await('clp_realtuner:load', 1500, plate, model)
    HCM_C.pending[plate] = nil
    if rec then
        HCM_C.records[plate] = rec
    end
    return rec
end

function HCM_C.pushPatch(plate, patch, reason)
    if type(plate) ~= 'string' or type(patch) ~= 'table' then return end
    -- Lokal updaten
    local rec = HCM_C.records[plate]
    if rec then for k, v in pairs(patch) do rec[k] = v end end
    TriggerServerEvent('clp_realtuner:patch', plate, patch, reason)
end

function HCM_C.refresh(plate)
    local rec = lib.callback.await('clp_realtuner:get', 1000, plate)
    if rec then HCM_C.records[plate] = rec end
    return rec
end

-- Me / Skill -----------------------------------------------------------------
local function refreshMe()
    local me = lib.callback.await('clp_realtuner:whoami', 1000)
    if me then HCM_C.me = me end
end

CreateThread(function()
    Wait(2000)
    refreshMe()
end)

RegisterNetEvent('esx:setJob', function()
    SetTimeout(500, refreshMe)
end)

RegisterNetEvent('clp_realtuner:skillUp', function(level)
    HCM_C.me.skill = HCM_C.me.skill or {}
    HCM_C.me.skill.level = level
    lib.notify({ title = 'Mechaniker', description = 'Skill-Level erhöht: ' .. level, type = 'success' })
end)

-- Spawn-Hook: preloadRecord beim Einsteigen ----------------------------------
CreateThread(function()
    local lastVeh, lastPlate
    while true do
        Wait(500)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and veh ~= lastVeh then
            lastVeh = veh
            local plate = plateOf(veh)
            if plate ~= lastPlate then
                lastPlate = plate
                HCM_C.getRecord(veh)
            end
        elseif veh == 0 then
            lastVeh, lastPlate = nil, nil
        end
    end
end)

-- Hilfsfunktionen global verfügbar ------------------------------------------
exports('getRecord', function(plate)
    return HCM_C.records[plate]
end)

exports('getNearestVehicle', function(radius)
    radius = radius or 5.0
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    -- Effizient: GetClosestVehicle native statt FindFirstVehicle-Iteration
    local best = GetClosestVehicle(coords.x, coords.y, coords.z, radius + 0.0, 0, 70)
    if best and best ~= 0 and DoesEntityExist(best) then return best end
    return nil
end)

-- Odometer Tracking (für Verschleiß) ----------------------------------------
CreateThread(function()
    local lastCoords, lastPlate
    while true do
        Wait(5000)
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(veh, -1) == ped then
                local plate = plateOf(veh)
                local coords = GetEntityCoords(veh)
                if plate and lastPlate == plate and lastCoords then
                    local dist = #(coords - lastCoords) / 1000.0 -- km
                    if dist > 0.001 and dist < 2.0 then
                        TriggerServerEvent('clp_realtuner:odometer', plate, dist)
                    end
                end
                lastCoords, lastPlate = coords, plate
            end
        else
            lastCoords, lastPlate = nil, nil
        end
    end
end)
