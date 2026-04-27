-- =============================================================================
--  clp_realtuner - Admin NUI Bridge
-- =============================================================================

HCM_C = HCM_C or {}

local isOpen = false

local function setFocus(state)
    SetNuiFocus(state, state)
    SetNuiFocusKeepInput(false)
end

local function post(name, data)
    SendNUIMessage({ action = name, data = data })
end

local function openAdmin()
    if isOpen then return end
    if not (HCM_C.me and HCM_C.me.isAdmin) then
        lib.notify({ title = 'Admin', description = 'Keine Berechtigung.', type = 'error' })
        return
    end
    isOpen = true
    setFocus(true)
    local snap = lib.callback.await('clp_realtuner:admin:snapshot', 3000)
    post('adminOpen', { snapshot = snap })
end

local function closeAdmin()
    if not isOpen then return end
    isOpen = false
    setFocus(false)
    post('adminClose')
end

RegisterNetEvent('clp_realtuner:openAdmin', openAdmin)

-- Keybind (optional, default nicht gebunden - via ox_lib einstellbar)
lib.addKeybind({
    name = 'clp_realtuner_admin',
    description = 'Realtuner Admin-Panel',
    defaultKey = '',
    onPressed = function()
        if isOpen then closeAdmin() else openAdmin() end
    end,
})

-- NUI Callbacks --------------------------------------------------------------

RegisterNUICallback('admin:close', function(_, cb)
    closeAdmin(); cb({ ok = true })
end)

RegisterNUICallback('admin:snapshot', function(_, cb)
    local snap = lib.callback.await('clp_realtuner:admin:snapshot', 3000)
    cb({ snapshot = snap })
end)

RegisterNUICallback('admin:setConfig', function(data, cb)
    local ok = lib.callback.await('clp_realtuner:admin:setConfig', 2000, data.keyPath, data.value)
    cb({ ok = ok })
end)

RegisterNUICallback('admin:setPart', function(data, cb)
    local ok = lib.callback.await('clp_realtuner:admin:setPart', 2000, data.item, data.def)
    cb({ ok = ok })
end)

RegisterNUICallback('admin:setLocations', function(data, cb)
    local ok = lib.callback.await('clp_realtuner:admin:setLocations', 2000, data.category, data.list)
    cb({ ok = ok })
end)

RegisterNUICallback('admin:listVehicles', function(data, cb)
    local rows = lib.callback.await('clp_realtuner:admin:listVehicles', 3000, data.search, data.limit, data.offset)
    cb({ rows = rows or {} })
end)

RegisterNUICallback('admin:getVehicle', function(data, cb)
    local rec = lib.callback.await('clp_realtuner:admin:getVehicle', 2000, data.plate)
    cb({ record = rec })
end)

RegisterNUICallback('admin:updateVehicle', function(data, cb)
    local ok = lib.callback.await('clp_realtuner:admin:updateVehicle', 2000, data.plate, data.patch)
    cb({ ok = ok })
end)

RegisterNUICallback('admin:resetVehicle', function(data, cb)
    local ok = lib.callback.await('clp_realtuner:admin:resetVehicle', 2000, data.plate)
    cb({ ok = ok })
end)

RegisterNUICallback('admin:logs', function(data, cb)
    local rows = lib.callback.await('clp_realtuner:admin:logs', 3000, data)
    cb({ rows = rows or {} })
end)

RegisterNUICallback('admin:listSkills', function(data, cb)
    local rows = lib.callback.await('clp_realtuner:admin:listSkills', 2000, data.search)
    cb({ rows = rows or {} })
end)

RegisterNUICallback('admin:setSkill', function(data, cb)
    local ok = lib.callback.await('clp_realtuner:admin:setSkill', 2000, data.identifier, data.level, data.xp)
    cb({ ok = ok })
end)

RegisterNUICallback('admin:addPaintBoothHere', function(data, cb)
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    local ok = lib.callback.await('clp_realtuner:admin:addPaintBooth', 2000,
        { x = c.x, y = c.y, z = c.z }, h, tonumber(data.radius) or 3.0)
    cb({ ok = ok, coords = { x = c.x, y = c.y, z = c.z }, heading = h })
end)

RegisterNUICallback('admin:removePaintBooth', function(data, cb)
    local ok = lib.callback.await('clp_realtuner:admin:removePaintBooth', 2000, data.index)
    cb({ ok = ok })
end)
