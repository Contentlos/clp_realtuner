-- =============================================================================
--  clp_realtuner - Statische Locations
--
--  Locations.workshops  : Haupt-Definition pro Werkstatt
--                         (id passt 1:1 auf mechanic_workshops.id, label =
--                          Anzeigename, mainBlip = Karten-Blip am Eingang,
--                          stations = einzelne Arbeitsplaetze mit Markern +
--                          ox_target-Zonen)
--  Legacy-Tabellen (paintBooths, dynoStations, serviceBays, workshopPCs)
--  werden automatisch aus Locations.workshops abgeleitet damit alter Code
--  weiter funktioniert.
-- =============================================================================

Locations = Locations or {}

-- ============================================================================
--  Workshops (Haupt-Definition)
-- ============================================================================
Locations.workshops = {
    {
        id    = 1,
        label = 'LS Customs (Strawberry)',
        -- Eingangs-Blip (sichtbar fuer alle Spieler)
        mainBlip = {
            coords = vector3(-336.04, -136.74, 39.00),
            sprite = 446,                -- Werkstatt / Schraubenschluessel
            color  = 5,                  -- Gelb
            scale  = 0.9,
            shortRange = false,
        },
        -- Arbeits-Stationen (nur im Inneren, mit Markern + ox_target)
        stations = {
            { kind = 'pc',     label = 'Werkstatt-PC',         coords = vector3(-340.96, -135.20, 38.86), heading = 250.0, model = 'prop_laptop_lester', size = vec3(1.0, 0.5, 1.0) },
            { kind = 'lift',   label = 'Hebebuehne',           coords = vector3(-347.05, -117.16, 38.00), heading = 340.0, size = vec3(5.5, 2.5, 1.0) },
            { kind = 'paint',  label = 'Lackier-Kabine',       coords = vector3(-337.76, -136.37, 39.00), heading = 250.0, radius = 3.0, size = vec3(6.0, 4.0, 1.0) },
            { kind = 'dyno',   label = 'Pruefstand (Dyno)',    coords = vector3(-347.24, -133.51, 38.92), heading = 250.0, size = vec3(4.0, 2.5, 1.0) },
            { kind = 'brake',  label = 'Bremsenpruefstand',    coords = vector3(-344.20, -134.70, 38.92), heading = 250.0, size = vec3(3.0, 3.0, 1.0) },
            { kind = 'storage_parts',  label = 'Lager: Mechanik',   coords = vector3(-345.00, -120.00, 38.00), size = vec3(2.0, 2.0, 1.0) },
            { kind = 'storage_body',   label = 'Lager: Karosserie', coords = vector3(-343.00, -120.00, 38.00), size = vec3(2.0, 2.0, 1.0) },
            { kind = 'storage_paint',  label = 'Lager: Lacke',      coords = vector3(-341.00, -120.00, 38.00), size = vec3(2.0, 2.0, 1.0) },
        },
    },
    {
        id    = 2,
        label = 'LS Customs (Mission Row)',
        mainBlip = {
            coords = vector3(731.93, -1088.89, 22.17),
            sprite = 446, color = 5, scale = 0.9, shortRange = false,
        },
        stations = {
            { kind = 'pc',     label = 'Werkstatt-PC',         coords = vector3(725.96, -1095.79, 22.17), heading = 0.0,   model = 'prop_laptop_lester', size = vec3(1.0, 0.5, 1.0) },
            { kind = 'lift',   label = 'Hebebuehne',           coords = vector3(725.77, -1088.76, 22.17), heading = 0.0,   size = vec3(5.5, 2.5, 1.0) },
            { kind = 'paint',  label = 'Lackier-Kabine',       coords = vector3(731.93, -1088.89, 22.17), heading = 180.0, radius = 3.0, size = vec3(6.0, 4.0, 1.0) },
        },
    },
}

-- ============================================================================
--  Legacy-Aliase (alte Tabellen, automatisch generiert)
--  Damit aelterer Code (paint, dyno, service) weiter funktioniert ohne dass
--  irgendetwas an zwei Stellen gepflegt werden muss.
-- ============================================================================
local function deriveLegacy()
    local paint, dyno, service, pcs = {}, {}, {}, {}
    for _, ws in ipairs(Locations.workshops or {}) do
        for _, st in ipairs(ws.stations or {}) do
            if st.kind == 'paint' then
                paint[#paint+1]   = { coords = st.coords, heading = st.heading or 0.0, radius = st.radius or 3.0 }
            elseif st.kind == 'dyno' then
                dyno[#dyno+1]     = { coords = st.coords, heading = st.heading or 0.0 }
            elseif st.kind == 'lift' then
                service[#service+1] = { coords = st.coords, heading = st.heading or 0.0, radius = st.radius or 3.5 }
            elseif st.kind == 'pc' then
                pcs[#pcs+1] = {
                    coords = st.coords, heading = st.heading or 0.0,
                    model = st.model or 'prop_laptop_lester', workshopId = ws.id,
                }
            end
        end
    end
    return paint, dyno, service, pcs
end

local _paint, _dyno, _service, _pcs = deriveLegacy()
Locations.paintBooths  = _paint
Locations.dynoStations = _dyno
Locations.serviceBays  = _service
Locations.workshopPCs  = _pcs
