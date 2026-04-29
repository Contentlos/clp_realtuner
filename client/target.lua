-- =============================================================================
--  clp_realtuner - Dynamische ox_target Zonen pro Fahrzeug (gruppiert)
--
--  Statt 15 flachen Eintraege pro Fahrzeug bauen wir 4 Hauptkategorien als
--  Sub-Menues (ox_target `menuName` / `menu`-Feld). Beim Targeten siehst du
--  pro Bone genau 1-3 Wurzel-Eintraege, die jeweils ein Untermenue oeffnen.
--
--  Wurzel-Kategorien:
--    1) Motor & Diagnose       (bonnet)
--    2) Heck & Auspuff         (boot, spoiler, exhaust)
--    3) Karosserie             (Tueren, Bumper)
--    4) Allgemein              (chassis/roof) - Inspector / Scan / Lack /
--                              Service / Testlauf
--
--  Raeder bleiben als 4 separate Eintraege (Bones wheel_lf/_rf/_lr/_rr),
--  da sie ohnehin nur einen Eintrag haben („Rad-Tuning").
-- =============================================================================

local target = exports.ox_target

HCM_C = HCM_C or {}
HCM_C.zones = {}

local function canInteractBase(entity)
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
    return GetVehicleDoorAngleRatio(entity, 4) > 0.1
end

local function engineIsOff(entity)
    return GetIsVehicleEngineRunning(entity) == false
        and GetEntitySpeed(entity) < (Config.Install.MaxVehicleSpeed or 0.1)
end

local function toggleHood(entity)
    if GetVehicleDoorAngleRatio(entity, 4) > 0.1 then
        SetVehicleDoorShut(entity, 4, false)
    else
        SetVehicleDoorOpen(entity, 4, false, false)
    end
end

local function toggleTrunk(entity)
    if GetVehicleDoorAngleRatio(entity, 5) > 0.1 then
        SetVehicleDoorShut(entity, 5, false)
    else
        SetVehicleDoorOpen(entity, 5, false, false)
    end
end

-- ============================================================================
--  Optionen (gruppiert via ox_target menu / menuName)
-- ============================================================================
local options = {
    -- ===== ROOT: Motor & Diagnose =====
    {
        name = 'clp_rt:root_engine',
        label = 'Motor & Diagnose',
        icon = 'fa-solid fa-screwdriver-wrench',
        bones = { 'bonnet' },
        distance = Config.Target.HoodDistance,
        canInteract = canInteractBase,
        menuName = 'clp_rt_engine',
    },
    {   menu = 'clp_rt_engine',
        name = 'clp_rt:hood_toggle',
        label = 'Motorhaube oeffnen / schliessen',
        icon = 'fa-solid fa-car',
        canInteract = canInteractBase,
        onSelect = function(d) toggleHood(d.entity) end,
    },
    {   menu = 'clp_rt_engine',
        name = 'clp_rt:engine_diag',
        label = 'Diagnose durchfuehren',
        icon = 'fa-solid fa-stethoscope',
        canInteract = canEngineAccess,
        onSelect = function(d) HCM_C.openTablet({ tab = 'diag', plate = HCM_C.plateOf(d.entity) }) end,
    },
    {   menu = 'clp_rt_engine',
        name = 'clp_rt:engine_install',
        label = 'Motorteil einbauen',
        icon = 'fa-solid fa-plus',
        canInteract = function(e)
            if not canEngineAccess(e) then return false end
            if Config.Install.RequireEngineOff and not engineIsOff(e) then return false end
            return true
        end,
        onSelect = function(d) HCM_C.openPartPicker(d.entity, 'hood') end,
    },
    {   menu = 'clp_rt_engine',
        name = 'clp_rt:engine_remove',
        label = 'Motorteil ausbauen',
        icon = 'fa-solid fa-minus',
        canInteract = function(e)
            if not canEngineAccess(e) then return false end
            if Config.Install.RequireEngineOff and not engineIsOff(e) then return false end
            return true
        end,
        onSelect = function(d) HCM_C.openRemovePicker(d.entity, 'hood') end,
    },
    {   menu = 'clp_rt_engine',
        name = 'clp_rt:ecu_flash',
        label = 'ECU flashen',
        icon = 'fa-solid fa-microchip',
        canInteract = function(e) return canEngineAccess(e) and engineIsOff(e) end,
        onSelect = function(d) HCM_C.openECU(d.entity) end,
    },
    {   menu = 'clp_rt_engine',
        name = 'clp_rt:service',
        label = 'Service / Wartung',
        icon = 'fa-solid fa-oil-can',
        canInteract = canEngineAccess,
        onSelect = function(d) HCM_C.doService(d.entity) end,
    },
    {   menu = 'clp_rt_engine',
        name = 'clp_rt:testdrive',
        label = 'Testlauf starten',
        icon = 'fa-solid fa-gauge-high',
        canInteract = canEngineAccess,
        onSelect = function(d) HCM_C.dynoTest(d.entity) end,
    },

    -- ===== ROOT: Heck & Auspuff =====
    {
        name = 'clp_rt:root_rear',
        label = 'Heck & Auspuff',
        icon = 'fa-solid fa-suitcase',
        bones = { 'boot', 'spoiler', 'exhaust', 'exhaust_1', 'exhaust_2' },
        distance = Config.Target.TrunkDistance,
        canInteract = canInteractBase,
        menuName = 'clp_rt_rear',
    },
    {   menu = 'clp_rt_rear',
        name = 'clp_rt:trunk_toggle',
        label = 'Kofferraum oeffnen / schliessen',
        icon = 'fa-solid fa-suitcase',
        canInteract = canInteractBase,
        onSelect = function(d) toggleTrunk(d.entity) end,
    },
    {   menu = 'clp_rt_rear',
        name = 'clp_rt:spoiler_install',
        label = 'Spoiler / Heckteil montieren',
        icon = 'fa-solid fa-wind',
        canInteract = function(e) return canInteractBase(e) and engineIsOff(e) end,
        onSelect = function(d) HCM_C.openPartPicker(d.entity, 'trunk') end,
    },
    {   menu = 'clp_rt_rear',
        name = 'clp_rt:exhaust_change',
        label = 'Auspuff wechseln',
        icon = 'fa-solid fa-smog',
        canInteract = function(e) return canInteractBase(e) and engineIsOff(e) end,
        onSelect = function(d) HCM_C.openPartPicker(d.entity, 'rear') end,
    },

    -- ===== ROOT: Karosserie =====
    {
        name = 'clp_rt:root_body_left',
        label = 'Karosserie (links)',
        icon = 'fa-solid fa-car-side',
        bones = { 'door_dside_f', 'door_dside_r' },
        distance = Config.Target.SideDistance,
        canInteract = canInteractBase,
        menuName = 'clp_rt_body_left',
    },
    {   menu = 'clp_rt_body_left',
        name = 'clp_rt:body_left',
        label = 'Bodyparts links montieren',
        icon = 'fa-solid fa-car-side',
        canInteract = function(e) return canInteractBase(e) and engineIsOff(e) end,
        onSelect = function(d) HCM_C.openPartPicker(d.entity, 'side_left') end,
    },
    {   menu = 'clp_rt_body_left',
        name = 'clp_rt:door_left_diag',
        label = 'Tuer-Diagnose (Elektrik / Schloss)',
        icon = 'fa-solid fa-stethoscope',
        canInteract = canInteractBase,
        onSelect = function(d) HCM_C.openTablet({ tab = 'diag', plate = HCM_C.plateOf(d.entity) }) end,
    },
    {
        name = 'clp_rt:root_body_right',
        label = 'Karosserie (rechts)',
        icon = 'fa-solid fa-car-side',
        bones = { 'door_pside_f', 'door_pside_r' },
        distance = Config.Target.SideDistance,
        canInteract = canInteractBase,
        menuName = 'clp_rt_body_right',
    },
    {   menu = 'clp_rt_body_right',
        name = 'clp_rt:body_right',
        label = 'Bodyparts rechts montieren',
        icon = 'fa-solid fa-car-side',
        canInteract = function(e) return canInteractBase(e) and engineIsOff(e) end,
        onSelect = function(d) HCM_C.openPartPicker(d.entity, 'side_right') end,
    },
    {   menu = 'clp_rt_body_right',
        name = 'clp_rt:door_right_diag',
        label = 'Tuer-Diagnose (Elektrik / Schloss)',
        icon = 'fa-solid fa-stethoscope',
        canInteract = canInteractBase,
        onSelect = function(d) HCM_C.openTablet({ tab = 'diag', plate = HCM_C.plateOf(d.entity) }) end,
    },
    {
        name = 'clp_rt:root_front',
        label = 'Front',
        icon = 'fa-solid fa-car',
        bones = { 'bumper_f', 'grille' },
        distance = Config.Target.SideDistance,
        canInteract = canInteractBase,
        menuName = 'clp_rt_front',
    },
    {   menu = 'clp_rt_front',
        name = 'clp_rt:front_bumper',
        label = 'Frontstossstange / Grill',
        icon = 'fa-solid fa-car',
        canInteract = function(e) return canInteractBase(e) and engineIsOff(e) end,
        onSelect = function(d) HCM_C.openPartPicker(d.entity, 'front') end,
    },

    -- ===== Raeder (4x einzeln, kein Submenu) =====
    {
        name = 'clp_rt:wheel_fl', label = 'Rad VL (Tuning)',
        icon = 'fa-solid fa-circle', bones = { 'wheel_lf' }, distance = Config.Target.WheelDistance,
        canInteract = function(e) return canInteractBase(e) and engineIsOff(e) end,
        onSelect = function(d) HCM_C.openPartPicker(d.entity, 'wheel_fl') end,
    },
    {
        name = 'clp_rt:wheel_fr', label = 'Rad VR (Tuning)',
        icon = 'fa-solid fa-circle', bones = { 'wheel_rf' }, distance = Config.Target.WheelDistance,
        canInteract = function(e) return canInteractBase(e) and engineIsOff(e) end,
        onSelect = function(d) HCM_C.openPartPicker(d.entity, 'wheel_fr') end,
    },
    {
        name = 'clp_rt:wheel_rl', label = 'Rad HL (Tuning)',
        icon = 'fa-solid fa-circle', bones = { 'wheel_lr' }, distance = Config.Target.WheelDistance,
        canInteract = function(e) return canInteractBase(e) and engineIsOff(e) end,
        onSelect = function(d) HCM_C.openPartPicker(d.entity, 'wheel_rl') end,
    },
    {
        name = 'clp_rt:wheel_rr', label = 'Rad HR (Tuning)',
        icon = 'fa-solid fa-circle', bones = { 'wheel_rr' }, distance = Config.Target.WheelDistance,
        canInteract = function(e) return canInteractBase(e) and engineIsOff(e) end,
        onSelect = function(d) HCM_C.openPartPicker(d.entity, 'wheel_rr') end,
    },

    -- ===== ROOT: Allgemein =====
    {
        name = 'clp_rt:root_general',
        label = 'Allgemein',
        icon = 'fa-solid fa-list',
        bones = { 'chassis', 'roof' },
        distance = 2.5,
        canInteract = canInteractBase,
        menuName = 'clp_rt_general',
    },
    {   menu = 'clp_rt_general',
        name = 'clp_rt:inspector',
        label = '3D-Inspector / visuelles Tuning',
        icon = 'fa-solid fa-camera-rotate',
        canInteract = function(e) return canInteractBase(e) and engineIsOff(e) end,
        onSelect = function(d) HCM_C.openInspector(d.entity) end,
    },
    {   menu = 'clp_rt_general',
        name = 'clp_rt:fullscan',
        label = 'Fahrzeug analysieren',
        icon = 'fa-solid fa-magnifying-glass-chart',
        canInteract = canInteractBase,
        onSelect = function(d) HCM_C.openTablet({ tab = 'scan', plate = HCM_C.plateOf(d.entity) }) end,
    },
    {   menu = 'clp_rt_general',
        name = 'clp_rt:paint',
        label = 'Lackieren',
        icon = 'fa-solid fa-spray-can-sparkles',
        canInteract = function(e)
            if not canInteractBase(e) then return false end
            if not engineIsOff(e) then return false end
            if HCM_C.isInPaintBooth then return HCM_C.isInPaintBooth(e) end
            return true
        end,
        onSelect = function(d) HCM_C.openPaint(d.entity) end,
    },
}

CreateThread(function()
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
