-- =============================================================================
--  clp_realtuner - Werkstatt-PC Client (Batch 14b)
--
--  Spawnt pro Eintrag in Locations.workshopPCs eine Computer-Prop und
--  haengt eine ox_target-Zone dran. Beim Auswaehlen wird das NUI #wspc
--  geoeffnet, das alle Tabs (Bestellungen, Lager, Preise, Bank,
--  Lieferungen) bedient.
-- =============================================================================

HCM_C = HCM_C or {}
local target = exports.ox_target
local spawned = {}        -- prop -> entity handle
local activeWorkshopId    -- aktuell geoeffneter PC

local function isStaff()
    return (HCM_C.me and (HCM_C.me.isMech or HCM_C.me.isAdmin)) or Config.AllowOutsideJob
end

-- Catalog wird nur bei Open geladen + zwischengespeichert (Static).
local catalogCache

local function loadCatalog(workshopId)
    if catalogCache then return catalogCache end
    catalogCache = lib.callback.await('clp_realtuner:wspc:catalog', 8000, workshopId) or {}
    return catalogCache
end

local function refreshUI()
    if not activeWorkshopId then return end
    local status = lib.callback.await('clp_realtuner:wspc:status', 6000, activeWorkshopId)
    if not status then return end
    SendNUIMessage({ type = 'wspc:status', status = status, catalog = loadCatalog(activeWorkshopId) })
end

function HCM_C.openWorkshopPC(workshopId)
    workshopId = tonumber(workshopId)
    if not workshopId then return end
    if not isStaff() then
        lib.notify({ title = 'Werkstatt-PC', description = 'Nur Mechaniker / Admin.', type = 'error' })
        return
    end
    activeWorkshopId = workshopId
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'wspc:open', workshopId = workshopId })
    refreshUI()
end

local function closePC()
    activeWorkshopId = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'wspc:close' })
end

-- ============================================================================
--  NUI Callbacks (alle nur waehrend offen gueltig)
-- ============================================================================
RegisterNUICallback('wspc:close', function(_, cb)
    closePC(); cb({ ok = true })
end)

RegisterNUICallback('wspc:order', function(data, cb)
    if not activeWorkshopId then return cb({ ok = false }) end
    local ok, msg = lib.callback.await('clp_realtuner:wspc:order', 8000, activeWorkshopId, data.item, tonumber(data.amount) or 1)
    if ok then lib.notify({ title = 'Bestellung', description = msg, type = 'success' })
    else lib.notify({ title = 'Bestellung', description = tostring(msg or 'Fehler'), type = 'error' }) end
    refreshUI()
    cb({ ok = ok })
end)

RegisterNUICallback('wspc:cancel', function(data, cb)
    if not activeWorkshopId then return cb({ ok = false }) end
    local ok, msg = lib.callback.await('clp_realtuner:wspc:cancel', 8000, activeWorkshopId, tonumber(data.id) or 0)
    if ok then lib.notify({ title = 'Bestellung', description = msg, type = 'success' })
    else lib.notify({ title = 'Bestellung', description = tostring(msg or 'Fehler'), type = 'error' }) end
    refreshUI()
    cb({ ok = ok })
end)

RegisterNUICallback('wspc:withdraw', function(data, cb)
    if not activeWorkshopId then return cb({ ok = false }) end
    local ok, msg = lib.callback.await('clp_realtuner:wspc:withdraw', 8000, activeWorkshopId, tonumber(data.amount) or 0)
    lib.notify({ title = 'Bank', description = tostring(msg or ''), type = ok and 'success' or 'error' })
    refreshUI()
    cb({ ok = ok })
end)

RegisterNUICallback('wspc:depositCash', function(data, cb)
    if not activeWorkshopId then return cb({ ok = false }) end
    local ok, msg = lib.callback.await('clp_realtuner:wspc:depositCash', 8000, activeWorkshopId, tonumber(data.amount) or 0)
    lib.notify({ title = 'Bank', description = tostring(msg or ''), type = ok and 'success' or 'error' })
    refreshUI()
    cb({ ok = ok })
end)

RegisterNUICallback('wspc:setMinStock', function(data, cb)
    if not activeWorkshopId then return cb({ ok = false }) end
    lib.callback.await('clp_realtuner:wspc:setMinStock', 5000, activeWorkshopId, tostring(data.item or ''), tonumber(data.minStock) or 0)
    refreshUI()
    cb({ ok = true })
end)

RegisterNUICallback('wspc:setPrice', function(data, cb)
    if not activeWorkshopId then return cb({ ok = false }) end
    lib.callback.await('clp_realtuner:wspc:setPrice', 5000, activeWorkshopId, tostring(data.service or ''), tonumber(data.price) or 0)
    refreshUI()
    cb({ ok = true })
end)

RegisterNUICallback('wspc:takeStock', function(data, cb)
    if not activeWorkshopId then return cb({ ok = false }) end
    local ok, msg = lib.callback.await('clp_realtuner:wspc:takeStock', 6000, activeWorkshopId, tostring(data.item or ''), tonumber(data.amount) or 1)
    lib.notify({ title = 'Lager', description = tostring(msg or ''), type = ok and 'success' or 'error' })
    refreshUI()
    cb({ ok = ok })
end)

RegisterNUICallback('wspc:returnStock', function(data, cb)
    if not activeWorkshopId then return cb({ ok = false }) end
    local ok, msg = lib.callback.await('clp_realtuner:wspc:returnStock', 6000, activeWorkshopId, tostring(data.item or ''), tonumber(data.amount) or 1)
    lib.notify({ title = 'Lager', description = tostring(msg or ''), type = ok and 'success' or 'error' })
    refreshUI()
    cb({ ok = ok })
end)

RegisterNUICallback('wspc:refresh', function(_, cb)
    refreshUI(); cb({ ok = true })
end)

-- ============================================================================
--  Prop-Spawn + ox_target
-- ============================================================================
local function spawnPC(loc)
    local model = GetHashKey(loc.model or 'prop_laptop_lester')
    if not HasModelLoaded(model) then RequestModel(model) end
    local deadline = GetGameTimer() + 4000
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(50) end
    if not HasModelLoaded(model) then return end
    local prop = CreateObject(model, loc.coords.x, loc.coords.y, loc.coords.z - 1.0, false, false, false)
    SetEntityHeading(prop, loc.heading or 0.0)
    PlaceObjectOnGroundProperly(prop)
    FreezeEntityPosition(prop, true)
    SetEntityAsMissionEntity(prop, true, true)
    target:addLocalEntity(prop, {
        {
            name = 'clp_realtuner:wspc:open:' .. tostring(loc.workshopId or 0),
            label = 'Werkstatt-PC öffnen',
            icon = 'fa-solid fa-desktop',
            distance = 1.6,
            canInteract = function() return isStaff() end,
            onSelect = function() HCM_C.openWorkshopPC(loc.workshopId or 1) end,
        },
    })
    spawned[#spawned+1] = prop
end

CreateThread(function()
    Wait(2500)
    if not Locations or type(Locations.workshopPCs) ~= 'table' then return end
    for _, loc in ipairs(Locations.workshopPCs) do
        spawnPC(loc)
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for _, p in ipairs(spawned) do
        if DoesEntityExist(p) then DeleteObject(p) end
    end
end)

-- Live-Tick: ETA-Updates fuers UI nicht noetig (Browser-Side rechnet selbst);
-- alle 25s pollen wir den Status falls der PC offen ist (Lieferungen kommen
-- typischerweise alle 30s an).
CreateThread(function()
    while true do
        Wait(25000)
        if activeWorkshopId then refreshUI() end
    end
end)
