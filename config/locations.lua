-- =============================================================================
--  clp_hardcore_mechanic - Statische Locations (optional)
--  Werkstätten werden dynamisch an jedem Fahrzeug erzeugt, diese Orte markieren
--  optional Lackierbuchten / Diagnose-Hebebühnen für Job-Workflow.
-- =============================================================================

Locations = {
    paintBooths = {
        { coords = vector3(-337.76, -136.37, 39.00), heading = 250.0, radius = 3.0 },
        { coords = vector3(731.93, -1088.89, 22.17), heading = 180.0, radius = 3.0 },
    },
    dynoStations = {
        { coords = vector3(-347.24, -133.51, 38.92), heading = 250.0 },
    },
    serviceBays = {
        { coords = vector3(-347.05, -117.16, 38.00), heading = 340.0, radius = 3.5 },
        { coords = vector3(725.77, -1088.76, 22.17), heading = 0.0,   radius = 3.5 },
    },
}
