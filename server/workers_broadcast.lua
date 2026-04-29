-- =============================================================================
--  clp_realtuner - Worker-Position Broadcast
--    Alle 5s sammelt der Server alle Online-Mechaniker (Job in MechanicJobs +
--    Admins) inkl. Coords + Name und schickt sie als TriggerClientEvent an
--    alle Mechaniker - daraus zeichnet client/workshop_world.lua Map-Blips.
--    Nicht-Mechaniker bekommen kein Event und damit auch keine Blips.
-- =============================================================================

local ESX = exports['es_extended']:getSharedObject()

local INTERVAL_MS = 5000

local function isStaff(xPlayer)
    if not xPlayer then return false end
    if Config.AllowOutsideJob then return true end
    local job = xPlayer.job and xPlayer.job.name
    if job and Config.MechanicJobs and Config.MechanicJobs[job] then return true end
    if HCM.util.isAdmin(xPlayer) then return true end
    return false
end

local function tickOnce()
    local players = ESX.GetExtendedPlayers and ESX.GetExtendedPlayers() or {}
    local list = {}
    local recipients = {}

    for _, xP in ipairs(players) do
        if isStaff(xP) then
            local src = xP.source
            local ped = GetPlayerPed(src)
            if ped and ped ~= 0 then
                local cx, cy, cz = table.unpack(GetEntityCoords(ped))
                local name = (xP.getName and xP.getName())
                    or (xP.get and xP.get('firstName') and xP.get('lastName')
                        and (xP.get('firstName') .. ' ' .. xP.get('lastName')))
                    or ('ID ' .. src)
                list[#list+1] = { id = src, name = name, coords = { x = cx, y = cy, z = cz } }
                recipients[#recipients+1] = src
            end
        end
    end

    -- Eigene ID aus dem List vor dem Versand entfernen pro Empfaenger
    for _, rsrc in ipairs(recipients) do
        local filtered = {}
        for _, w in ipairs(list) do
            if w.id ~= rsrc then filtered[#filtered+1] = w end
        end
        TriggerClientEvent('clp_realtuner:workers:update', rsrc, filtered)
    end
end

CreateThread(function()
    -- 8s warten bis ESX-Player vollstaendig geladen sind
    Wait(8000)
    while true do
        local ok, err = pcall(tickOnce)
        if not ok and Config.Debug then print('[realtuner] workers tick error:', err) end
        Wait(INTERVAL_MS)
    end
end)
