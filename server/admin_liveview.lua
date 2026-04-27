-- =============================================================================
--  clp_realtuner - Admin-Live-View + Teleport (Batch 12)
-- =============================================================================

local ESX = exports['es_extended']:getSharedObject()

local function isAdmin(xPlayer)
    if not xPlayer then return false end
    local grp = xPlayer.getGroup and xPlayer.getGroup() or nil
    return grp and Config.AdminGroups and Config.AdminGroups[grp] or false
end

-- Live-Subscriptions: src -> plate (oder nil). Server pusht alle 2s den aktuellen Record.
local subs = {}

lib.callback.register('clp_realtuner:admin:liveSubscribe', function(source, plate)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return false end
    if not isAdmin(xPlayer) then return false end
    plate = HCM.util.normalizePlate(plate or '')
    if plate == '' then subs[source] = nil; return true end
    subs[source] = plate
    return true
end)

AddEventHandler('playerDropped', function() subs[source] = nil end)

CreateThread(function()
    while true do
        Wait(2000)
        for src, plate in pairs(subs) do
            local rec = HCM.server.loadRecord(plate)
            if rec then
                TriggerClientEvent('clp_realtuner:admin:liveUpdate', src, plate, rec)
            end
        end
    end
end)

-- VIN oder Plate -> Fahrzeug aufspueren + Admin teleportieren.
-- Wir finden das Fahrzeug ueber Server-Enumeration aller Netz-Fahrzeuge und
-- Vergleich gegen den Plate-Record.
lib.callback.register('clp_realtuner:admin:findVehicle', function(source, query)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return nil end
    if not isAdmin(xPlayer) then return nil end
    query = tostring(query or ''):upper():gsub('%s+', '')
    if query == '' then return nil end

    -- Erst ueber VIN/Plate in DB den kanonischen Plate bestimmen
    local canonicalPlate
    pcall(function()
        local row = MySQL.single.await([[
            SELECT plate FROM vehicles_data
             WHERE plate = ? OR vin = ? OR etched_vin = ?
             LIMIT 1
        ]], { query, query, query })
        if row then canonicalPlate = row.plate end
    end)
    canonicalPlate = canonicalPlate or query

    -- Netz-Fahrzeuge durchsuchen
    for _, veh in ipairs(GetAllVehicles()) do
        local plate = HCM.util.normalizePlate(GetVehicleNumberPlateText(veh) or '')
        if plate == canonicalPlate then
            local coords = GetEntityCoords(veh)
            local netId = NetworkGetNetworkIdFromEntity(veh)
            return {
                plate = plate, netId = netId,
                x = coords.x, y = coords.y, z = coords.z,
                heading = GetEntityHeading(veh),
                driver = GetPedInVehicleSeat(veh, -1),
            }
        end
    end
    return { plate = canonicalPlate, offline = true }
end)

-- Admin-Teleport zum Fahrzeug (server-side SetEntityCoords auf Admin-Ped)
RegisterNetEvent('clp_realtuner:admin:teleport', function(query)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src); if not xPlayer then return end
    if not isAdmin(xPlayer) then return end
    query = tostring(query or ''):upper():gsub('%s+', '')
    local info = lib.callback.await('clp_realtuner:admin:findVehicle', 5000, query)
    if info and info.x and not info.offline then
        local ped = GetPlayerPed(src)
        SetEntityCoords(ped, info.x + 2.0, info.y + 0.0, info.z + 0.5, false, false, false, true)
        SetEntityHeading(ped, info.heading or 0.0)
        TriggerClientEvent('ox_lib:notify', src, { title = 'Teleport', description = ('Zu %s'):format(info.plate), type = 'success' })
    else
        TriggerClientEvent('ox_lib:notify', src, { title = 'Teleport', description = 'Fahrzeug offline oder nicht gefunden', type = 'error' })
    end
    HCM.server.log(xPlayer, 'admin:teleport', info and info.plate or query, nil, info)
end)
