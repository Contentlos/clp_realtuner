-- =============================================================================
--  clp_realtuner - Dynamische ox_target Zonen pro Fahrzeug
--
--  Strategie:
--    * Globale Vehicle-Optionen via exports.ox_target:addGlobalVehicle
--    * Nutzung des `bones`-Felds pro Option, damit nur die Zone relevant ist.
--    * canInteract prüft Fahrzeug-Kontext (Haube offen, Motor aus, Job, etc.)
--
--  Bones (GTA V):
--    bonnet, boot, door_dside_f, door_pside_f, door_dside_r, door_pside_r,
--    wheel_lf, wheel_rf, wheel_lr, wheel_rr, exhaust_1, spoiler
-- =============================================================================

local target = exports.ox_target

HCM_C = HCM_C or {}
HCM_C.zones = {} -- gebucht global

local function canInteractBase(entity, distance, coords, _name, _bone)
    if not DoesEntityExist(entity) then return false end
    if GetEntityType(entity) ~= 2 then return false end
    if (HCM_C.me and (HCM_C.me.isMech or HCM_C.me.isAdmin)) or Config.AllowOutsideJob then
        return true
    end
    return false
end

local function canEngineAccess(entity)
    if not canInteractBase(entity) then return false end
    if not Config.Target.RequireHoodOpenForEngine then return true end
    -- Door 4 = Haube
    return GetVehicleDoorAngleRatio(entity, 4) > 0.1
end

local function engineIsOff(entity)
    return GetIsVehicleEngineRunning(entity) == false and GetEntitySpeed(entity) < (Config.Install.MaxVehicleSpeed or 0.1)
end

local function hoodOpen(entity)
    return GetVehicleDoorAngleRatio(entity, 4) > 0.1
end

-- Motorhaube öffnen/schließen ------------------------------------------------
local function toggleHood(entity)
    if GetVehicleDoorAngleRatio(entity, 4) > 0.1 then
        SetVehicleDoorShut(entity, 4, false)
    else
        SetVehicleDoorOpen(entity, 4, false, false)
    end
end

-- Kofferraum -----------------------------------------------------------------
local function toggleTrunk(entity)
    if GetVehicleDoorAngleRatio(entity, 5) > 0.1 then
        SetVehicleDoorShut(entity, 5, false)
    else
        SetVehicleDoorOpen(entity, 5, false, false)
    end
end

-- Options definieren ---------------------------------------------------------

local options = {
    -- ===== HOOD / MOTOR =====
    {
        name   = 'clp_realtuner:hood_toggle',
        label  = 'Motorhaube öffnen / schließen',
        icon   = 'fa-solid fa-car',
        bones  = { 'bonnet' },
        distance = Config.Target.HoodDistance,
        canInteract = function(entity) return canInteractBase(entity) end,
        onSelect = function(data) toggleHood(data.entity) end,
    },
    {
        name   = 'clp_realtuner:engine_diagnose',
        label  = 'Diagnose durchführen',
        icon   = 'fa-solid fa-stethoscope',
        bones  = { 'bonnet' },
        distance = Config.Target.HoodDistance,
        canInteract = function(entity) return canEngineAccess(entity) end,
        onSelect = function(data)
            HCM_C.openTablet({ tab = 'diag', plate = HCM_C.plateOf(data.entity) })
        end,
    },
    {
        name   = 'clp_realtuner:engine_install',
        label  = 'Motorteil einbauen',
        icon   = 'fa-solid fa-screwdriver-wrench',
        bones  = { 'bonnet' },
        distance = Config.Target.HoodDistance,
        canInteract = function(entity)
            if not canEngineAccess(entity) then return false end
            if Config.Install.RequireEngineOff and not engineIsOff(entity) then return false end
            return true
        end,
        onSelect = function(data)
            HCM_C.openPartPicker(data.entity, 'hood')
        end,
    },
    {
        name   = 'clp_realtuner:engine_remove',
        label  = 'Motorteil ausbauen',
        icon   = 'fa-solid fa-minus',
        bones  = { 'bonnet' },
        distance = Config.Target.HoodDistance,
        canInteract = function(entity)
            if not canEngineAccess(entity) then return false end
            if Config.Install.RequireEngineOff and not engineIsOff(entity) then return false end
            return true
        end,
        onSelect = function(data)
            HCM_C.openRemovePicker(data.entity, 'hood')
        end,
    },
    {
        name   = 'clp_realtuner:ecu_flash',
        label  = 'ECU flashen',
        icon   = 'fa-solid fa-microchip',
        bones  = { 'bonnet' },
        distance = Config.Target.HoodDistance,
        canInteract = function(entity) return canEngineAccess(entity) and engineIsOff(entity) end,
        onSelect = function(data)
            HCM_C.openECU(data.entity)
        end,
    },

    -- ===== TRUNK / HECK =====
    {
        name   = 'clp_realtuner:trunk_toggle',
        label  = 'Kofferraum öffnen / schließen',
        icon   = 'fa-solid fa-suitcase',
        bones  = { 'boot' },
        distance = Config.Target.TrunkDistance,
        canInteract = function(entity) return canInteractBase(entity) end,
        onSelect = function(data) toggleTrunk(data.entity) end,
    },
    {
        name   = 'clp_realtuner:spoiler_install',
        label  = 'Spoiler / Heckteil montieren',
        icon   = 'fa-solid fa-wind',
        bones  = { 'boot', 'spoiler' },
        distance = Config.Target.TrunkDistance,
        canInteract = function(entity) return canInteractBase(entity) and engineIsOff(entity) end,
        onSelect = function(data) HCM_C.openPartPicker(data.entity, 'trunk') end,
    },
    {
        name   = 'clp_realtuner:exhaust_change',
        label  = 'Auspuff wechseln',
        icon   = 'fa-solid fa-smog',
        bones  = { 'exhaust', 'exhaust_1', 'exhaust_2' },
        distance = Config.Target.TrunkDistance,
        canInteract = function(entity) return canInteractBase(entity) and engineIsOff(entity) end,
        onSelect = function(data) HCM_C.openPartPicker(data.entity, 'rear') end,
    },

    -- ===== SEITEN =====
    {
        name   = 'clp_realtuner:side_left',
        label  = 'Bodyparts links',
        icon   = 'fa-solid fa-car-side',
        bones  = { 'door_dside_f', 'door_dside_r' },
        distance = Config.Target.SideDistance,
        canInteract = function(entity) return canInteractBase(entity) and engineIsOff(entity) end,
        onSelect = function(data) HCM_C.openPartPicker(data.entity, 'side_left') end,
    },
    {
        name   = 'clp_realtuner:side_right',
        label  = 'Bodyparts rechts',
        icon   = 'fa-solid fa-car-side',
        bones  = { 'door_pside_f', 'door_pside_r' },
        distance = Config.Target.SideDistance,
        canInteract = function(entity) return canInteractBase(entity) and engineIsOff(entity) end,
        onSelect = function(data) HCM_C.openPartPicker(data.entity, 'side_right') end,
    },
    {
        name   = 'clp_realtuner:front_bumper',
        label  = 'Frontstoßstange / Grill',
        icon   = 'fa-solid fa-car',
        bones  = { 'bumper_f', 'grille' },
        distance = Config.Target.SideDistance,
        canInteract = function(entity) return canInteractBase(entity) and engineIsOff(entity) end,
        onSelect = function(data) HCM_C.openPartPicker(data.entity, 'front') end,
    },

    -- ===== RÄDER (einzeln) =====
    {
        name = 'clp_realtuner:wheel_fl', label = 'Rad vorne links (Tuning)',
        icon = 'fa-solid fa-circle', bones = { 'wheel_lf' }, distance = Config.Target.WheelDistance,
        canInteract = function(e) return canInteractBase(e) and engineIsOff(e) end,
        onSelect = function(d) HCM_C.openPartPicker(d.entity, 'wheel_fl') end,
    },
    {
        name = 'clp_realtuner:wheel_fr', label = 'Rad vorne rechts (Tuning)',
        icon = 'fa-solid fa-circle', bones = { 'wheel_rf' }, distance = Config.Target.WheelDistance,
        canInteract = function(e) return canInteractBase(e) and engineIsOff(e) end,
        onSelect = function(d) HCM_C.openPartPicker(d.entity, 'wheel_fr') end,
    },
    {
        name = 'clp_realtuner:wheel_rl', label = 'Rad hinten links (Tuning)',
        icon = 'fa-solid fa-circle', bones = { 'wheel_lr' }, distance = Config.Target.WheelDistance,
        canInteract = function(e) return canInteractBase(e) and engineIsOff(e) end,
        onSelect = function(d) HCM_C.openPartPicker(d.entity, 'wheel_rl') end,
    },
    {
        name = 'clp_realtuner:wheel_rr', label = 'Rad hinten rechts (Tuning)',
        icon = 'fa-solid fa-circle', bones = { 'wheel_rr' }, distance = Config.Target.WheelDistance,
        canInteract = function(e) return canInteractBase(e) and engineIsOff(e) end,
        onSelect = function(d) HCM_C.openPartPicker(d.entity, 'wheel_rr') end,
    },

    -- ===== GLOBAL =====
    {
        name = 'clp_realtuner:fullscan',
        label = 'Fahrzeug analysieren',
        icon = 'fa-solid fa-magnifying-glass-chart',
        bones = { 'bonnet', 'boot', 'chassis' },
        distance = 2.0,
        canInteract = function(entity) return canInteractBase(entity) end,
        onSelect = function(data)
            HCM_C.openTablet({ tab = 'scan', plate = HCM_C.plateOf(data.entity) })
        end,
    },
    {
        name = 'clp_realtuner:paint',
        label = 'Lackieren',
        icon = 'fa-solid fa-spray-can-sparkles',
        bones = { 'chassis', 'roof' },
        distance = 2.0,
        canInteract = function(entity)
            if not canInteractBase(entity) then return false end
            if not engineIsOff(entity) then return false end
            -- Nur in Paint Booth
            if HCM_C.isInPaintBooth then return HCM_C.isInPaintBooth(entity) end
            return true
        end,
        onSelect = function(data) HCM_C.openPaint(data.entity) end,
    },
    {
        name = 'clp_realtuner:testdrive',
        label = 'Testlauf starten',
        icon = 'fa-solid fa-gauge-high',
        bones = { 'bonnet' },
        distance = Config.Target.HoodDistance,
        canInteract = function(entity) return canEngineAccess(entity) end,
        onSelect = function(data) HCM_C.dynoTest(data.entity) end,
    },
    {
        name = 'clp_realtuner:service',
        label = 'Service / Wartung buchen',
        icon = 'fa-solid fa-oil-can',
        bones = { 'bonnet' },
        distance = Config.Target.HoodDistance,
        canInteract = function(entity) return canEngineAccess(entity) end,
        onSelect = function(data) HCM_C.doService(data.entity) end,
    },
}

CreateThread(function()
    -- Warten bis ox_target geladen ist
    while GetResourceState('ox_target') ~= 'started' do Wait(200) end
    target:addGlobalVehicle(options)
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    local names = {}
    for _, o in ipairs(options) do names[#names+1] = o.name end
    pcall(function() target:removeGlobalVehicle(names) end)
end)

-- Paint Booth Check ---------------------------------------------------------
function HCM_C.isInPaintBooth(entity)
    local coords = GetEntityCoords(entity)
    for _, b in ipairs(Locations.paintBooths or {}) do
        if #(coords - b.coords) <= (b.radius or 3.0) then return true end
    end
    return false
end
