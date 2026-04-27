-- =============================================================================
--  clp_realtuner - NUI Tablet Bridge
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

-- Öffnen / Schließen --------------------------------------------------------
function HCM_C.openTablet(payload)
    if isOpen then return end
    isOpen = true
    payload = payload or {}
    setFocus(true)

    -- Animation
    local dict = Config.Tablet.AnimationDict
    if dict then
        lib.requestAnimDict(dict, 5000)
        TaskPlayAnim(PlayerPedId(), dict, Config.Tablet.AnimationName or 'base', 3.0, 3.0, -1, 49, 0, false, false, false)
    end

    -- Scan-Payload mitsenden, wenn Fahrzeug bekannt
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then veh = exports[GetCurrentResourceName()]:getNearestVehicle(6.0) end
    local scan = veh and HCM_C.scanSummary and HCM_C.scanSummary(veh) or nil
    local diag = veh and HCM_C.diagnose and HCM_C.diagnose(veh) or nil
    local history = payload.plate and lib.callback.await('clp_realtuner:history', 1500, payload.plate, 30) or nil

    post('open', {
        tab = payload.tab or 'diag',
        plate = payload.plate or (veh and HCM_C.plateOf(veh)),
        me = HCM_C.me,
        scan = scan,
        diag = diag,
        history = history,
    })
end

function HCM_C.closeTablet()
    if not isOpen then return end
    isOpen = false
    setFocus(false)
    ClearPedTasks(PlayerPedId())
    post('close')
end

RegisterNUICallback('close', function(_, cb)
    HCM_C.closeTablet()
    cb({ ok = true })
end)

RegisterNUICallback('refresh', function(data, cb)
    local plate = data and data.plate
    if plate then
        local rec = HCM_C.refresh(plate)
        cb({ rec = rec })
    else
        cb({ rec = nil })
    end
end)

RegisterNUICallback('history', function(data, cb)
    local plate = data and data.plate
    if plate then
        local rows = lib.callback.await('clp_realtuner:history', 1500, plate, 50)
        cb({ rows = rows or {} })
    else
        cb({ rows = {} })
    end
end)

RegisterNUICallback('scan', function(_, cb)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then veh = exports[GetCurrentResourceName()]:getNearestVehicle(6.0) end
    if not veh or veh == 0 then cb({ scan = nil }); return end
    cb({ scan = HCM_C.scanSummary(veh) })
end)

-- Server Event: Tablet via Item öffnen ---------------------------------------
RegisterNetEvent('clp_realtuner:openTablet', function()
    HCM_C.openTablet({})
end)

-- Keybind (optional) ---------------------------------------------------------
if Config.Tablet.OpenKeybind then
    lib.addKeybind({
        name = 'clp_realtuner_open',
        description = 'Mechaniker Tablet öffnen',
        defaultKey = Config.Tablet.OpenKeybind,
        onPressed = function()
            if isOpen then HCM_C.closeTablet() else HCM_C.openTablet({}) end
        end,
    })
end
