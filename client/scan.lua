-- =============================================================================
--  clp_realtuner - Auto-Scan (installierte Teile + freie Slots + Upgrades)
-- =============================================================================

HCM_C = HCM_C or {}

-- Mod-Typen die wir automatisch scannen (incl. Toggle)
local SCAN_MOD_TYPES = {
    MOD.SPOILER, MOD.FRONT_BUMPER, MOD.REAR_BUMPER, MOD.SIDE_SKIRT,
    MOD.EXHAUST, MOD.FRAME, MOD.GRILLE, MOD.HOOD, MOD.FENDER, MOD.RIGHT_FENDER,
    MOD.ROOF, MOD.ENGINE, MOD.BRAKES, MOD.TRANSMISSION, MOD.HORNS, MOD.SUSPENSION,
    MOD.ARMOR, MOD.TURBO, MOD.TYRE_SMOKE, MOD.XENON,
    MOD.FRONT_WHEELS, MOD.BACK_WHEELS, MOD.AIR_FILTER, MOD.LIVERY,
}

local TOGGLE_SET = TOGGLE_MODS or {}

---@param veh number
---@return table
function HCM_C.scanVehicle(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    SetVehicleModKit(veh, 0) -- Voraussetzung, damit Mods lesbar sind

    local scan = {
        plate  = HCM_C.plateOf(veh),
        model  = GetDisplayNameFromVehicleModel(GetEntityModel(veh)),
        slots  = {}, -- logical slot -> { installed = <item|nil>, options = { parts... }, current = { gtaIndex, gtaCount } }
        gtaMods = {},
    }

    -- 1. GTA Mods erfassen (was existiert, was ist drin)
    for _, modType in ipairs(SCAN_MOD_TYPES) do
        if TOGGLE_SET[modType] then
            scan.gtaMods[modType] = {
                isToggle = true,
                enabled  = IsToggleModOn(veh, modType),
                count    = 1,
            }
        else
            local count = GetNumVehicleMods(veh, modType) or 0
            if count > 0 then
                scan.gtaMods[modType] = {
                    isToggle = false,
                    index    = GetVehicleMod(veh, modType), -- -1 = stock
                    count    = count,
                    custom   = (modType == MOD.FRONT_WHEELS or modType == MOD.BACK_WHEELS) and GetVehicleModVariation(veh, modType) or false,
                }
            end
        end
    end

    -- 2. Record-Slots mappen -> Upgrades pro Slot
    local rec = HCM_C.getRecord(veh) or { installed_parts = {} }
    local installed = rec.installed_parts or {}

    -- Alle bekannten Slots aus Parts-Table
    local slotSet = {}
    for _, p in pairs(Parts) do slotSet[p.slot] = true end

    for slotKey in pairs(slotSet) do
        local entry = installed[slotKey]
        local options = GetPartsForSlot(slotKey)
        -- Nur Teile deren modType (wenn != -1) auch am Fahrzeug existiert
        local filtered = {}
        for _, p in ipairs(options) do
            local mt = p.modType
            if mt == -1 or mt == nil or scan.gtaMods[mt] then
                filtered[#filtered + 1] = p
            end
        end
        scan.slots[slotKey] = {
            installed = entry,
            options   = filtered,
            -- aktueller GTA-Index (falls Slot einen modType hat)
            currentGtaIndex = (function()
                local first = filtered[1]
                if first and first.modType and first.modType ~= -1 then
                    local m = scan.gtaMods[first.modType]
                    return m and m.index or -1
                end
                return nil
            end)(),
        }
    end

    return scan
end

-- Formatierte Ausgabe für Tablet -------------------------------------------
function HCM_C.scanSummary(veh)
    local s = HCM_C.scanVehicle(veh)
    if not s then return nil end
    local installed, missing, upgrades = {}, {}, {}
    for slotKey, data in pairs(s.slots) do
        if data.installed then
            installed[#installed+1] = { slot = slotKey, part = data.installed, options = data.options }
        else
            missing[#missing+1] = { slot = slotKey, options = data.options }
        end
        if #data.options > 0 then
            upgrades[#upgrades+1] = { slot = slotKey, best = data.options[#data.options] }
        end
    end
    return {
        plate = s.plate, model = s.model,
        installed = installed, missing = missing, upgrades = upgrades,
    }
end
