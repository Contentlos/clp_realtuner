-- =============================================================================
--  clp_hardcore_mechanic - GTA V Vehicle Mod Type Constants
--  Quelle: eVehicleModType (Rockstar) - dokumentiert von FiveM Community
-- =============================================================================

MOD = {
    SPOILER       = 0,
    FRONT_BUMPER  = 1,
    REAR_BUMPER   = 2,
    SIDE_SKIRT    = 3,
    EXHAUST       = 4,
    FRAME         = 5,
    GRILLE        = 6,
    HOOD          = 7,
    FENDER        = 8,
    RIGHT_FENDER  = 9,
    ROOF          = 10,
    ENGINE        = 11,
    BRAKES        = 12,
    TRANSMISSION  = 13,
    HORNS         = 14,
    SUSPENSION    = 15,
    ARMOR         = 16,
    -- 17 = nitrous (not used by SetVehicleMod, toggle)
    TURBO         = 18, -- toggle
    -- 19 = subwoofer
    TYRE_SMOKE    = 20, -- toggle
    -- 21 = hydraulics
    XENON         = 22, -- toggle
    FRONT_WHEELS  = 23,
    BACK_WHEELS   = 24,
    PLATE_HOLDER  = 25,
    VANITY_PLATES = 26,
    TRIM_DESIGN   = 27,
    ORNAMENTS     = 28,
    DASHBOARD     = 29,
    DIAL_DESIGN   = 30,
    DOOR_SPEAKER  = 31,
    SEATS         = 32,
    STEERING      = 33,
    SHIFTER       = 34,
    PLAQUES       = 35,
    SPEAKERS      = 36,
    TRUNK         = 37,
    HYDRAULICS    = 38,
    ENGINE_BLOCK  = 39,
    AIR_FILTER    = 40,
    STRUTS        = 41,
    ARCH_COVER    = 42,
    AERIAL        = 43,
    TRIM          = 44,
    TANK          = 45,
    WINDOWS       = 46,
    -- 47 unused
    LIVERY        = 48,
}

MOD_NAMES = {
    [0]='Spoiler',[1]='Frontstoßstange',[2]='Heckstoßstange',[3]='Seitenschweller',
    [4]='Auspuff',[5]='Rahmen',[6]='Kühlergrill',[7]='Motorhaube',
    [8]='Kotflügel L',[9]='Kotflügel R',[10]='Dach',[11]='Motor',
    [12]='Bremsen',[13]='Getriebe',[14]='Hupe',[15]='Fahrwerk',
    [16]='Panzerung',[18]='Turbo',[20]='Reifenrauch',[22]='Xenon',
    [23]='Vorderreifen',[24]='Hinterreifen',[40]='Luftfilter',[48]='Livery',
}

-- Toggle-Mods (On/Off, nicht SetVehicleMod sondern ToggleVehicleMod)
TOGGLE_MODS = {
    [MOD.TURBO]      = true,
    [MOD.TYRE_SMOKE] = true,
    [MOD.XENON]      = true,
}
