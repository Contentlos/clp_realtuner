-- =============================================================================
--  clp_hardcore_mechanic - Teile-Definitionen (Inventar-Items)
--
--  Felder:
--    item      = Name des ox_inventory Items
--    label     = Anzeige
--    modType   = MOD.* aus shared/modtypes.lua (bei -1 = reines Logik-Teil, kein SetVehicleMod)
--    modIndex  = welchen Mod-Index dieses Teil installiert (-1 = letzter verfügbarer, n = konkret)
--                -1 = "höchste verfügbare Stufe dieses Modtyps am Fahrzeug"
--    quality   = 1..5 (1=billig, 5=race)
--    installTime = ms baseline
--    failChance  = 0..1 baseline (vor Skill-Adjust)
--    wearMult    = Verschleißmultiplikator
--    slot        = Logik-Slot im installed_parts JSON (String)
--    category    = 'engine'|'drivetrain'|'brakes'|'suspension'|'body'|'wheels'|'electronics'
--    tuning      = { stat = delta } Auswirkung aufs Handling (additiv, in Prozent)
--    health      = { target = 'engine_health', add = 10 } Reparatur-Effekt (optional)
--    requires    = { 'item_name' } andere Items die gleichzeitig verbraucht werden
-- =============================================================================

Parts = {}

-- ---------------------------------------------------------------------------
--  MOTOR
-- ---------------------------------------------------------------------------
Parts['engine_block_stock']     = { item='engine_block_stock',     label='Motorblock (Serie)',       category='engine', slot='engine_block',    modType=MOD.ENGINE, modIndex=0, quality=2, installTime=18000, failChance=0.08, wearMult=1.0, tuning={ accel=0,  topspeed=0  }, health={ target='engine_health', add=60 } }
Parts['engine_block_forged']    = { item='engine_block_forged',    label='Motorblock (Geschmiedet)', category='engine', slot='engine_block',    modType=MOD.ENGINE, modIndex=2, quality=4, installTime=24000, failChance=0.12, wearMult=0.7, tuning={ accel=15, topspeed=10 }, health={ target='engine_health', add=100 } }
Parts['engine_block_race']      = { item='engine_block_race',      label='Motorblock (Race)',        category='engine', slot='engine_block',    modType=MOD.ENGINE, modIndex=3, quality=5, installTime=28000, failChance=0.18, wearMult=1.4, tuning={ accel=25, topspeed=18 }, health={ target='engine_health', add=100 } }

Parts['turbo_stock']            = { item='turbo_stock',            label='Turbolader (Basis)',       category='engine', slot='turbo',           modType=MOD.TURBO,  modIndex=0, quality=2, installTime=14000, failChance=0.10, wearMult=1.0, tuning={ accel=8,  topspeed=3  }, toggle=true,  health={ target='turbo_health', add=70 } }
Parts['turbo_stage2']           = { item='turbo_stage2',           label='Turbolader Stufe 2',       category='engine', slot='turbo',           modType=MOD.TURBO,  modIndex=0, quality=4, installTime=16000, failChance=0.14, wearMult=1.2, tuning={ accel=18, topspeed=8  }, toggle=true,  health={ target='turbo_health', add=100 } }
Parts['turbo_stage3']           = { item='turbo_stage3',           label='Bi-Turbo (Stufe 3)',       category='engine', slot='turbo',           modType=MOD.TURBO,  modIndex=0, quality=5, installTime=18000, failChance=0.22, wearMult=1.6, tuning={ accel=28, topspeed=14 }, toggle=true,  health={ target='turbo_health', add=100 } }

Parts['ecu_basic']              = { item='ecu_basic',              label='ECU Chip (Basis)',         category='electronics', slot='ecu',        modType=-1,        quality=2, installTime=9000,  failChance=0.06, wearMult=1.0, tuning={ accel=3,  topspeed=2  } }
Parts['ecu_race']               = { item='ecu_race',               label='ECU Chip (Race)',          category='electronics', slot='ecu',        modType=-1,        quality=5, installTime=12000, failChance=0.12, wearMult=1.2, tuning={ accel=10, topspeed=6  } }

Parts['intake_short']           = { item='intake_short',           label='Sportluftfilter',          category='engine', slot='intake',          modType=MOD.AIR_FILTER, modIndex=-1, quality=3, installTime=7000,  failChance=0.05, wearMult=1.0, tuning={ accel=4 } }
Parts['intake_cold']            = { item='intake_cold',            label='Kaltluft-Ansaugung',       category='engine', slot='intake',          modType=MOD.AIR_FILTER, modIndex=-1, quality=5, installTime=9000,  failChance=0.08, wearMult=1.1, tuning={ accel=8, topspeed=2 } }

Parts['exhaust_sport']          = { item='exhaust_sport',          label='Sportauspuff',             category='engine', slot='exhaust',         modType=MOD.EXHAUST, modIndex=-1, quality=3, installTime=8000,  failChance=0.05, wearMult=1.0, tuning={ accel=4,  topspeed=2 } }
Parts['exhaust_race']           = { item='exhaust_race',           label='Race Auspuff (Titan)',     category='engine', slot='exhaust',         modType=MOD.EXHAUST, modIndex=-1, quality=5, installTime=11000, failChance=0.10, wearMult=1.1, tuning={ accel=9,  topspeed=5 } }

-- Nockenwellen-Tuning (Batch 5)
Parts['cam_stage1']             = { item='cam_stage1',             label='Nockenwelle Stage 1',       category='engine', slot='camshaft',        modType=-1,        quality=3, installTime=14000, failChance=0.10, wearMult=1.1, tuning={ accel=6,  topspeed=2 } }
Parts['cam_stage2']             = { item='cam_stage2',             label='Nockenwelle Stage 2',       category='engine', slot='camshaft',        modType=-1,        quality=4, installTime=16000, failChance=0.14, wearMult=1.2, tuning={ accel=12, topspeed=5 } }
Parts['cam_stage3']             = { item='cam_stage3',             label='Nockenwelle Race',          category='engine', slot='camshaft',        modType=-1,        quality=5, installTime=18000, failChance=0.18, wearMult=1.4, tuning={ accel=18, topspeed=8 } }

-- Einspritzer (Batch 5)
Parts['injector_street']        = { item='injector_street',        label='Einspritzer Street',        category='engine', slot='injector',        modType=-1,        quality=3, installTime=9000,  failChance=0.07, wearMult=1.0, tuning={ accel=3 } }
Parts['injector_sport']         = { item='injector_sport',         label='Einspritzer Sport',         category='engine', slot='injector',        modType=-1,        quality=4, installTime=10000, failChance=0.10, wearMult=1.1, tuning={ accel=7 } }
Parts['injector_race']          = { item='injector_race',          label='Einspritzer Race',          category='engine', slot='injector',        modType=-1,        quality=5, installTime=12000, failChance=0.14, wearMult=1.3, tuning={ accel=14, topspeed=3 } }

-- Supercharger (Batch 5) – Alternative zum Turbo
Parts['supercharger']           = { item='supercharger',           label='Supercharger-Kit',         category='engine', slot='turbo',           modType=MOD.TURBO, modIndex=0, quality=5, installTime=22000, failChance=0.16, wearMult=1.3, tuning={ accel=22, topspeed=10 }, toggle=true, health={ target='turbo_health', add=100 } }

-- Innenraum + Optik (Batch 5)
Parts['leather_seats']          = { item='leather_seats',          label='Leder-Sportsitze',          category='body',   slot='seats',           modType=32,        modIndex=-1, quality=4, installTime=9000,  failChance=0.04, wearMult=1.0, tuning={} }
Parts['sport_steering']         = { item='sport_steering',         label='Sport-Lenkrad',             category='body',   slot='steering_wheel',  modType=33,        modIndex=-1, quality=3, installTime=5000,  failChance=0.03, wearMult=1.0, tuning={} }
Parts['neon_kit']               = { item='neon_kit',               label='Unterboden-Neon-Kit',       category='body',   slot='neon',            modType=-1,        quality=3, installTime=7000,  failChance=0.04, wearMult=1.0, tuning={} }

-- ---------------------------------------------------------------------------
--  GETRIEBE & BREMSEN
-- ---------------------------------------------------------------------------
Parts['transmission_stock']     = { item='transmission_stock',     label='Getriebe (Serie)',         category='drivetrain', slot='transmission', modType=MOD.TRANSMISSION, modIndex=0, quality=2, installTime=20000, failChance=0.10, wearMult=1.0, tuning={ accel=0 }, health={ target='transmission_health', add=60 } }
Parts['transmission_sport']     = { item='transmission_sport',     label='Sportgetriebe',            category='drivetrain', slot='transmission', modType=MOD.TRANSMISSION, modIndex=1, quality=4, installTime=22000, failChance=0.14, wearMult=1.1, tuning={ accel=10 }, health={ target='transmission_health', add=100 } }
Parts['transmission_race']      = { item='transmission_race',      label='Race Getriebe (Sequ.)',    category='drivetrain', slot='transmission', modType=MOD.TRANSMISSION, modIndex=2, quality=5, installTime=26000, failChance=0.20, wearMult=1.4, tuning={ accel=18 }, health={ target='transmission_health', add=100 } }

Parts['brakes_stock']           = { item='brakes_stock',           label='Bremsen (Serie)',          category='brakes', slot='brakes',          modType=MOD.BRAKES, modIndex=0, quality=2, installTime=12000, failChance=0.06, wearMult=1.0, tuning={ brake=0 },  health={ target='brake_health', add=60 } }
Parts['brakes_street']          = { item='brakes_street',          label='Street Brakes',            category='brakes', slot='brakes',          modType=MOD.BRAKES, modIndex=1, quality=3, installTime=13000, failChance=0.08, wearMult=1.0, tuning={ brake=10 }, health={ target='brake_health', add=90 } }
Parts['brakes_race']            = { item='brakes_race',            label='Race Brakes (Keramik)',    category='brakes', slot='brakes',          modType=MOD.BRAKES, modIndex=2, quality=5, installTime=15000, failChance=0.12, wearMult=1.2, tuning={ brake=25 }, health={ target='brake_health', add=100 } }

-- ---------------------------------------------------------------------------
--  FAHRWERK
-- ---------------------------------------------------------------------------
Parts['suspension_stock']       = { item='suspension_stock',       label='Fahrwerk (Serie)',         category='suspension', slot='suspension',  modType=MOD.SUSPENSION, modIndex=0, quality=2, installTime=14000, failChance=0.08, wearMult=1.0, tuning={ traction=0 },  health={ target='suspension_health', add=60 } }
Parts['suspension_lowered']     = { item='suspension_lowered',     label='Tieferlegung',             category='suspension', slot='suspension',  modType=MOD.SUSPENSION, modIndex=1, quality=3, installTime=15000, failChance=0.08, wearMult=1.0, tuning={ traction=5  }, health={ target='suspension_health', add=90 } }
Parts['suspension_sport']       = { item='suspension_sport',       label='Sportfahrwerk',            category='suspension', slot='suspension',  modType=MOD.SUSPENSION, modIndex=2, quality=4, installTime=17000, failChance=0.10, wearMult=1.1, tuning={ traction=12 }, health={ target='suspension_health', add=100 } }
Parts['suspension_race']        = { item='suspension_race',        label='Gewindefahrwerk',          category='suspension', slot='suspension',  modType=MOD.SUSPENSION, modIndex=3, quality=5, installTime=19000, failChance=0.14, wearMult=1.2, tuning={ traction=20 }, health={ target='suspension_health', add=100 } }

-- ---------------------------------------------------------------------------
--  RÄDER (je Rad einzeln, Slot trägt Position)
-- ---------------------------------------------------------------------------
Parts['wheel_rim_basic']        = { item='wheel_rim_basic',        label='Felge (Basic)',            category='wheels', slot='wheel_rim',       modType=MOD.FRONT_WHEELS, modIndex=-1, quality=2, installTime=6000,  failChance=0.03, wearMult=1.0, tuning={} }
Parts['wheel_rim_sport']        = { item='wheel_rim_sport',        label='Felge (Sport)',            category='wheels', slot='wheel_rim',       modType=MOD.FRONT_WHEELS, modIndex=-1, quality=4, installTime=7000,  failChance=0.05, wearMult=1.0, tuning={ traction=3 } }

Parts['tire_street']            = { item='tire_street',            label='Reifen (Street)',          category='wheels', slot='tire',            modType=-1, quality=3, installTime=5000, failChance=0.03, wearMult=1.0, tuning={ traction=2 } }
Parts['tire_sport']             = { item='tire_sport',             label='Reifen (Sport)',           category='wheels', slot='tire',            modType=-1, quality=4, installTime=5500, failChance=0.05, wearMult=1.1, tuning={ traction=8 } }
Parts['tire_race']              = { item='tire_race',              label='Reifen (Semi-Slick)',      category='wheels', slot='tire',            modType=-1, quality=5, installTime=6000, failChance=0.08, wearMult=1.4, tuning={ traction=15, brake=5 } }
Parts['tire_drift']             = { item='tire_drift',             label='Drift Reifen',             category='wheels', slot='tire',            modType=-1, quality=4, installTime=5500, failChance=0.06, wearMult=1.3, tuning={ traction=-8 } }

-- ---------------------------------------------------------------------------
--  BODY / OPTIK
-- ---------------------------------------------------------------------------
Parts['spoiler_basic']          = { item='spoiler_basic',          label='Spoiler (GT)',             category='body', slot='spoiler',           modType=MOD.SPOILER,     modIndex=-1, quality=3, installTime=8000, failChance=0.04, wearMult=1.0, tuning={ traction=3 } }
Parts['spoiler_race']           = { item='spoiler_race',           label='Spoiler (Race Wing)',      category='body', slot='spoiler',           modType=MOD.SPOILER,     modIndex=-1, quality=5, installTime=10000, failChance=0.06, wearMult=1.0, tuning={ traction=8 } }
Parts['bodykit_side']           = { item='bodykit_side',           label='Seitenschweller-Kit',      category='body', slot='side_skirt',        modType=MOD.SIDE_SKIRT,  modIndex=-1, quality=3, installTime=9000,  failChance=0.04, wearMult=1.0, tuning={} }
Parts['bodykit_front']          = { item='bodykit_front',          label='Front-Bumper-Kit',         category='body', slot='front_bumper',      modType=MOD.FRONT_BUMPER, modIndex=-1, quality=3, installTime=9000,  failChance=0.04, wearMult=1.0, tuning={} }
Parts['bodykit_rear']           = { item='bodykit_rear',           label='Heck-Bumper-Kit',          category='body', slot='rear_bumper',       modType=MOD.REAR_BUMPER,  modIndex=-1, quality=3, installTime=9000,  failChance=0.04, wearMult=1.0, tuning={} }
Parts['hood_vented']            = { item='hood_vented',            label='Motorhaube (belüftet)',    category='body', slot='hood',              modType=MOD.HOOD,        modIndex=-1, quality=3, installTime=9000,  failChance=0.04, wearMult=1.0, tuning={ accel=2 } }
Parts['grille_mesh']            = { item='grille_mesh',            label='Grill (Mesh)',             category='body', slot='grille',            modType=MOD.GRILLE,      modIndex=-1, quality=3, installTime=7000,  failChance=0.04, wearMult=1.0, tuning={} }
Parts['fender_wide']            = { item='fender_wide',            label='Kotflügel (Wide)',         category='body', slot='fender',            modType=MOD.FENDER,      modIndex=-1, quality=3, installTime=8000,  failChance=0.04, wearMult=1.0, tuning={} }

-- ---------------------------------------------------------------------------
--  SERVICE / VERBRAUCHSTEILE
-- ---------------------------------------------------------------------------
Parts['oil_basic']              = { item='oil_basic',              label='Motoröl (Basic)',          category='service', slot='service_oil',    modType=-1, quality=2, installTime=4000, failChance=0.02, wearMult=1.0, tuning={}, health={ target='engine_health', add=15 } }
Parts['oil_full_synth']         = { item='oil_full_synth',         label='Motoröl (Vollsynth.)',     category='service', slot='service_oil',    modType=-1, quality=5, installTime=5000, failChance=0.02, wearMult=0.8, tuning={}, health={ target='engine_health', add=35 } }
Parts['coolant']                = { item='coolant',                label='Kühlmittel',               category='service', slot='service_coolant',modType=-1, quality=3, installTime=3500, failChance=0.02, wearMult=1.0, tuning={}, health={ target='engine_health', add=10 } }
Parts['brake_pad_set']          = { item='brake_pad_set',          label='Bremsbeläge',              category='service', slot='service_brake',  modType=-1, quality=3, installTime=6000, failChance=0.03, wearMult=1.0, tuning={}, health={ target='brake_health',  add=40 } }

-- ---------------------------------------------------------------------------
--  Helper: alle Parts eines Slots ermitteln
-- ---------------------------------------------------------------------------
function GetPartsForSlot(slot)
    local out = {}
    for _, p in pairs(Parts) do
        if p.slot == slot then out[#out+1] = p end
    end
    table.sort(out, function(a, b) return a.quality < b.quality end)
    return out
end

function GetPartByItem(item)
    return Parts[item]
end

-- Slot-Definition (logisch) pro Zone. Gibt Reihenfolge Anzeige vor.
SLOTS_BY_ZONE = {
    hood       = { 'engine_block', 'turbo', 'intake', 'ecu', 'service_oil', 'service_coolant', 'hood', 'grille' },
    trunk      = { 'spoiler' },
    front      = { 'front_bumper' },
    rear       = { 'rear_bumper', 'exhaust' },
    side_left  = { 'side_skirt', 'fender' },
    side_right = { 'side_skirt', 'fender' },
    wheel_fl   = { 'wheel_rim', 'tire', 'service_brake', 'brakes', 'suspension' },
    wheel_fr   = { 'wheel_rim', 'tire', 'service_brake', 'brakes', 'suspension' },
    wheel_rl   = { 'wheel_rim', 'tire', 'service_brake', 'brakes', 'suspension', 'transmission' },
    wheel_rr   = { 'wheel_rim', 'tire', 'service_brake', 'brakes', 'suspension' },
}
