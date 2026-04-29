-- =============================================================================
--  clp_realtuner - Workshop World (Batch 14e)
--    * Map-Blip pro Werkstatt (mainBlip)
--    * Marker (Bodenkasten) an jeder Station bei Annaeherung
--    * Sphere-/Box-Zonen via ox_target an Stationen mit gruppierten Aktionen
--    * Worker-Blips: Mechaniker sehen sich gegenseitig auf der Map
-- =============================================================================

HCM_C = HCM_C or {}

local target = exports.ox_target
local workshopBlips = {}
local stationZones = {}

-- ============================================================================
--  Map-Blips an jeder Werkstatt
-- ============================================================================
local function addWorkshopBlip(ws)
    if not ws.mainBlip or not ws.mainBlip.coords then return end
    local b = ws.mainBlip
    local blip = AddBlipForCoord(b.coords.x, b.coords.y, b.coords.z)
    SetBlipSprite(blip, b.sprite or 446)
    SetBlipColour(blip, b.color or 5)
    SetBlipScale(blip, b.scale or 0.9)
    SetBlipAsShortRange(blip, b.shortRange ~= false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(ws.label or 'Werkstatt')
    EndTextCommandSetBlipName(blip)
    workshopBlips[#workshopBlips+1] = blip
end

-- ============================================================================
--  Marker-Loop: zeichnet Bodenkaesten in der Naehe (DrawMarker Type 1)
-- ============================================================================
local MARKER_DRAW_DIST = 25.0
local STATION_MARKER_COLORS = {
    pc            = { r = 70,  g = 200, b = 255, a = 130 }, -- cyan
    lift          = { r = 255, g = 180, b = 0,   a = 130 }, -- gelb-orange
    paint         = { r = 220, g = 50,  b = 200, a = 130 }, -- magenta
    dyno          = { r = 0,   g = 255, b = 120, a = 130 }, -- gruen
    brake         = { r = 255, g = 80,  b = 80,  a = 130 }, -- rot
    storage_parts = { r = 130, g = 200, b = 255, a = 110 },
    storage_body  = { r = 200, g = 200, b = 255, a = 110 },
    storage_paint = { r = 255, g = 200, b = 130, a = 110 },
}

CreateThread(function()
    while true do
        Wait(0)
        local ped = PlayerPedId()
        local px, py, pz = table.unpack(GetEntityCoords(ped))
        local drewAny = false
        for _, ws in ipairs(Locations.workshops or {}) do
            for _, st in ipairs(ws.stations or {}) do
                local c = st.coords
                local d2 = (c.x - px)^2 + (c.y - py)^2 + (c.z - pz)^2
                if d2 <= MARKER_DRAW_DIST * MARKER_DRAW_DIST then
                    local size = st.size or vec3(2.0, 2.0, 1.0)
                    local col  = STATION_MARKER_COLORS[st.kind] or { r = 200, g = 200, b = 200, a = 110 }
                    -- Type 1 = quadratischer Bodenkasten
                    DrawMarker(1, c.x, c.y, c.z - 0.95, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        size.x, size.y, size.z * 0.4,
                        col.r, col.g, col.b, col.a,
                        false, false, 2, false, nil, nil, false)
                    drewAny = true
                end
            end
        end
        if not drewAny then Wait(400) end -- Sleep wenn keine Marker in Naehe
    end
end)

-- ============================================================================
--  ox_target-Sphere/Box pro Station mit Untergruppen
-- ============================================================================
local function isStaff()
    return (HCM_C.me and (HCM_C.me.isMech or HCM_C.me.isAdmin)) or Config.AllowOutsideJob
end

local function stationOptions(ws, st)
    local opts = {}
    if st.kind == 'pc' then
        opts[#opts+1] = {
            name = 'wspc:open:' .. ws.id,
            label = 'Werkstatt-PC oeffnen',
            icon = 'fa-solid fa-desktop',
            canInteract = isStaff,
            onSelect = function() HCM_C.openWorkshopPC(ws.id) end,
        }
    elseif st.kind == 'lift' then
        opts[#opts+1] = {
            name = 'lift:toggle:' .. ws.id,
            label = 'Hebebuehne hoch/runter',
            icon = 'fa-solid fa-arrows-up-down',
            canInteract = isStaff,
            onSelect = function()
                local ped = PlayerPedId()
                local veh = GetClosestVehicle and GetClosestVehicle(st.coords.x, st.coords.y, st.coords.z, 5.0, 0, 70)
                    or GetVehiclePedIsIn(ped, true)
                if veh and veh ~= 0 and DoesEntityExist(veh) then
                    if HCM_C.toggleLift then HCM_C.toggleLift(veh) end
                else
                    lib.notify({ title = 'Hebebuehne', description = 'Kein Fahrzeug auf der Buehne.', type = 'error' })
                end
            end,
        }
        opts[#opts+1] = {
            name = 'lift:diag:' .. ws.id,
            label = 'Diagnose (Tablet)',
            icon = 'fa-solid fa-stethoscope',
            canInteract = isStaff,
            onSelect = function() HCM_C.openTablet({ tab = 'diag' }) end,
        }
    elseif st.kind == 'paint' then
        opts[#opts+1] = {
            name = 'paint:open:' .. ws.id,
            label = 'Lackieren starten',
            icon = 'fa-solid fa-spray-can-sparkles',
            canInteract = function()
                if not isStaff() then return false end
                local veh = GetClosestVehicle and GetClosestVehicle(st.coords.x, st.coords.y, st.coords.z, 5.0, 0, 70) or 0
                return veh ~= 0 and DoesEntityExist(veh)
            end,
            onSelect = function()
                local veh = GetClosestVehicle(st.coords.x, st.coords.y, st.coords.z, 5.0, 0, 70)
                if veh ~= 0 and HCM_C.openPaint then HCM_C.openPaint(veh) end
            end,
        }
    elseif st.kind == 'dyno' then
        opts[#opts+1] = {
            name = 'dyno:start:' .. ws.id,
            label = 'Dyno-Run starten',
            icon = 'fa-solid fa-gauge-high',
            canInteract = isStaff,
            onSelect = function()
                if HCM_C.startDyno then HCM_C.startDyno() end
            end,
        }
    elseif st.kind == 'brake' then
        opts[#opts+1] = {
            name = 'brake:test:' .. ws.id,
            label = 'Bremsenpruefstand starten',
            icon = 'fa-solid fa-circle-stop',
            canInteract = isStaff,
            onSelect = function()
                if HCM_C.runBrakeTest then HCM_C.runBrakeTest() end
            end,
        }
    elseif st.kind == 'storage_parts' or st.kind == 'storage_body' or st.kind == 'storage_paint' then
        local cat = st.kind:gsub('storage_', '')
        opts[#opts+1] = {
            name = 'storage:open:' .. ws.id .. ':' .. cat,
            label = 'Lager oeffnen (' .. (st.label or cat) .. ')',
            icon = 'fa-solid fa-box-archive',
            canInteract = isStaff,
            onSelect = function()
                -- ox_inventory stash konvention: clp_realtuner_storage_<cat>_<wsId>
                exports.ox_inventory:openInventory('stash', {
                    id = 'clp_realtuner_storage_' .. cat .. '_' .. ws.id,
                })
            end,
        }
    end
    return opts
end

local function addStationZone(ws, st)
    local opts = stationOptions(ws, st)
    if #opts == 0 then return end
    local size = st.size or vec3(2.0, 2.0, 1.5)
    local zoneId = ('clp_rt_st_%s_%s_%d_%d'):format(ws.id, st.kind, math.floor(st.coords.x), math.floor(st.coords.y))
    -- ox_target box-zone
    local id = target:addBoxZone({
        coords = vector3(st.coords.x, st.coords.y, st.coords.z),
        size = vec3(size.x, size.y, math.max(size.z, 1.5)),
        rotation = st.heading or 0.0,
        debug = Config.Debug or false,
        options = opts,
        name = zoneId,
    })
    stationZones[#stationZones+1] = id
end

CreateThread(function()
    while GetResourceState('ox_target') ~= 'started' do Wait(200) end
    Wait(500)
    for _, ws in ipairs(Locations.workshops or {}) do
        addWorkshopBlip(ws)
        for _, st in ipairs(ws.stations or {}) do
            addStationZone(ws, st)
        end
    end
end)

-- ============================================================================
--  Worker-Blips: Mechaniker sehen sich gegenseitig
-- ============================================================================
local workerBlips = {}    -- [serverId] = { blip, lastSeen }
local lastWorkerSync = 0

local function clearWorkerBlip(sid)
    local entry = workerBlips[sid]
    if entry and DoesBlipExist(entry.blip) then RemoveBlip(entry.blip) end
    workerBlips[sid] = nil
end

local function setWorkerBlip(sid, name, coords)
    local entry = workerBlips[sid]
    local blip
    if entry and DoesBlipExist(entry.blip) then
        blip = entry.blip
        SetBlipCoords(blip, coords.x, coords.y, coords.z)
    else
        blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, 280)         -- Wrench
        SetBlipColour(blip, 5)            -- gelb
        SetBlipScale(blip, 0.75)
        SetBlipCategory(blip, 7)          -- Mitspieler-Gruppe
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Mechaniker - ' .. (name or sid))
        EndTextCommandSetBlipName(blip)
    end
    workerBlips[sid] = { blip = blip, lastSeen = HCM.util.now() }
end

RegisterNetEvent('clp_realtuner:workers:update', function(list)
    if not isStaff() then
        -- Nicht-Mechaniker sehen keine Worker-Blips
        for sid in pairs(workerBlips) do clearWorkerBlip(sid) end
        return
    end
    list = list or {}
    local seen = {}
    for _, w in ipairs(list) do
        seen[w.id] = true
        if w.coords then
            setWorkerBlip(w.id, w.name, w.coords)
        end
    end
    -- Aufraeumen alter Blips
    for sid in pairs(workerBlips) do
        if not seen[sid] then clearWorkerBlip(sid) end
    end
    lastWorkerSync = HCM.util.now()
end)

-- Server-side broadcast laeuft alle 5s; falls keine Updates kommen
-- (z.B. weil wir grad kein Mechaniker sind), Blips nach 30s wegraeumen
CreateThread(function()
    while true do
        Wait(15000)
        if HCM.util.now() - lastWorkerSync > 30 then
            for sid in pairs(workerBlips) do clearWorkerBlip(sid) end
        end
    end
end)

-- ============================================================================
--  Cleanup
-- ============================================================================
AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for _, b in ipairs(workshopBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    for sid in pairs(workerBlips) do clearWorkerBlip(sid) end
    for _, id in ipairs(stationZones) do
        pcall(function() target:removeZone(id) end)
    end
end)
