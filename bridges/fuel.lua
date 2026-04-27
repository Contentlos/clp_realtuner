-- =============================================================================
--  clp_realtuner - Fuel Bridge (Batch 11)
--  Unterstuetzt: ox_fuel, LegacyFuel, cdn-fuel, qs-fuelstations, ps-fuel.
--  Exposed via exports.clp_realtuner:GetVehicleFuel(veh) / SetVehicleFuel / GetFuelType
--  Falscher Sprit (Diesel in Benziner) -> Motorschaden ueber HCM_C.dmg.
-- =============================================================================

HCM_C = HCM_C or {}
HCM_C.fuel = HCM_C.fuel or {}

local FUEL_RESOURCES = {
    'ox_fuel', 'LegacyFuel', 'cdn-fuel', 'cdn_fuel',
    'qs-fuelstations', 'ps-fuel', 'ps_fuel', 'mm-fuel',
}

local activeName
CreateThread(function()
    for _, name in ipairs(FUEL_RESOURCES) do
        if GetResourceState(name) == 'started' or GetResourceState(name) == 'starting' then
            activeName = name
            break
        end
    end
    if activeName then
        print(('[clp_realtuner] Fuel-Bridge aktiv: %s'):format(activeName))
    end
end)

function HCM_C.fuel.getLevel(veh)
    if not veh or veh == 0 then return 100.0 end
    -- ox_fuel nutzt Statebag
    local state = Entity(veh).state
    if state and state.fuel then return tonumber(state.fuel) or 100.0 end
    -- LegacyFuel exports
    if activeName == 'LegacyFuel' and exports.LegacyFuel then
        local ok, val = pcall(function() return exports.LegacyFuel:GetFuel(veh) end)
        if ok and val then return val end
    end
    if (activeName == 'cdn-fuel' or activeName == 'cdn_fuel') and exports['cdn-fuel'] then
        local ok, val = pcall(function() return exports['cdn-fuel']:GetFuel(veh) end)
        if ok and val then return val end
    end
    return GetVehicleFuelLevel(veh) or 100.0
end

function HCM_C.fuel.setLevel(veh, level)
    level = math.max(0.0, math.min(100.0, tonumber(level) or 0.0))
    if not veh or veh == 0 then return end
    if Entity(veh).state and Entity(veh).state.fuel ~= nil then
        Entity(veh).state:set('fuel', level, true)
    end
    if activeName == 'LegacyFuel' and exports.LegacyFuel then
        pcall(function() exports.LegacyFuel:SetFuel(veh, level) end)
    end
    if (activeName == 'cdn-fuel' or activeName == 'cdn_fuel') and exports['cdn-fuel'] then
        pcall(function() exports['cdn-fuel']:SetFuel(veh, level) end)
    end
    SetVehicleFuelLevel(veh, level + 0.0)
end

-- Fahrzeug-Kraftstoffart nach Modell-Heuristik
-- (Config.Fuel.DieselModels + Klassen-Check)
local DIESEL_CLASSES = { [16] = true, [17] = true, [18] = true, [19] = true, [20] = true }

function HCM_C.fuel.getType(veh)
    if not veh or veh == 0 then return 'gasoline' end
    local model = GetEntityModel(veh)
    local cfg = (Config.Fuel and Config.Fuel.DieselModels) or {}
    if cfg[model] then return 'diesel' end
    local class = GetVehicleClass(veh)
    if DIESEL_CLASSES[class] then return 'diesel' end
    return 'gasoline'
end

-- Tanken-Hook: wenn falscher Sprit getankt wurde, Motor-Schaden progressiv.
function HCM_C.fuel.refuel(veh, fuelType, liters)
    if not veh or veh == 0 then return end
    local correct = HCM_C.fuel.getType(veh)
    local level = HCM_C.fuel.getLevel(veh)
    HCM_C.fuel.setLevel(veh, math.min(100, level + (tonumber(liters) or 0)))
    if fuelType and correct ~= fuelType then
        -- Falscher Sprit: Motor-Schaden ~0.5 pro Liter, sofortige Warnung
        local damage = (tonumber(liters) or 0) * 0.5
        local plate = (GetVehicleNumberPlateText(veh) or ''):gsub('%s+', '')
        if plate ~= '' and damage > 0 then
            TriggerServerEvent('clp_realtuner:damage', plate, 'engine', math.min(100, damage))
        end
        lib.notify({
            title = 'Falscher Kraftstoff!',
            description = ('%s in %s getankt - Motor nimmt Schaden!'):format(fuelType, correct),
            type = 'error', duration = 10000,
        })
    end
end

RegisterNetEvent('clp_realtuner:fuel:refuel', function(plate, fuelType, liters)
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then return end
    HCM_C.fuel.refuel(veh, fuelType, liters)
end)

exports('GetVehicleFuel', HCM_C.fuel.getLevel)
exports('SetVehicleFuel', HCM_C.fuel.setLevel)
exports('GetVehicleFuelType', HCM_C.fuel.getType)
