-- =============================================================================
--  clp_realtuner - Storage-Kategorien (Batch 14b)
--
--  Mappt Inventar-Items auf Lager-Kategorien (parts/body/paint/fluids).
--  Wird im Werkstatt-PC fuer Bestellungen + Lager-Anzeige genutzt.
-- =============================================================================

HCM = HCM or {}
HCM.categories = { 'parts', 'body', 'paint', 'fluids' }

HCM.categoryLabel = {
    parts  = 'Mechanik-Lager',
    body   = 'Karosserie-Lager',
    paint  = 'Lack-Lager',
    fluids = 'Verbrauchsstoffe',
}

-- Mapping auf Basis von Parts[].category (siehe config/parts.lua)
-- engine/drivetrain/brakes/electronics/wheels -> 'parts'
-- body/interior                                -> 'body'
local PARTS_CATEGORY_MAP = {
    engine      = 'parts',
    drivetrain  = 'parts',
    brakes      = 'parts',
    electronics = 'parts',
    suspension  = 'parts',
    wheels      = 'parts',
    body        = 'body',
    interior    = 'body',
}

-- Items, die nicht in Parts vorkommen, aber dennoch ins Lager gehoeren.
-- (Verschleissteile, Verbrauchsstoffe, Lackmittel, Werkzeug)
local FIXED = {
    -- fluids / verbrauchsstoffe
    motor_oil          = 'fluids',
    brake_fluid        = 'fluids',
    coolant            = 'fluids',
    spark_plug         = 'fluids',
    headlight_bulb     = 'fluids',
    rearlight_bulb     = 'fluids',
    battery            = 'fluids',
    windshield_repair  = 'fluids',
    rust_remover       = 'fluids',
    fuel_filter        = 'fluids',
    air_filter_consumable = 'fluids',
    -- paint
    paint_can          = 'paint',
    paint_can_metallic = 'paint',
    paint_can_pearl    = 'paint',
    paint_can_matt     = 'paint',
    paint_clearcoat    = 'paint',
    paint_thinner      = 'paint',
    paint_primer       = 'paint',
    paint_red          = 'paint',
    paint_blue         = 'paint',
    paint_black        = 'paint',
    paint_white        = 'paint',
    -- werkzeug
    repairkit          = 'parts',
    advanced_repairkit = 'parts',
    obd_scanner        = 'parts',
    endoscope          = 'parts',
    torque_wrench      = 'parts',
}

---@param item string
---@return string category
function HCM.itemCategory(item)
    if not item or item == '' then return 'parts' end
    if FIXED[item] then return FIXED[item] end
    local def = (Parts and Parts[item]) or nil
    if def and def.category and PARTS_CATEGORY_MAP[def.category] then
        return PARTS_CATEGORY_MAP[def.category]
    end
    return 'parts' -- safe default
end

-- Default-Preise (server-authoritativ; per Workshop-Setting koennen abweichen)
HCM.defaultUnitCost = function(item)
    local def = Parts and Parts[item] or nil
    if def and def.quality then
        -- Quality 1-5 -> 50 / 200 / 600 / 1500 / 4000
        local TABLE = { 50, 200, 600, 1500, 4000 }
        return TABLE[math.max(1, math.min(5, def.quality))] or 200
    end
    -- Verbrauchsstoffe / Lacke: gunstig
    if HCM.itemCategory(item) == 'fluids' then return 80 end
    if HCM.itemCategory(item) == 'paint'  then return 250 end
    return 200
end
