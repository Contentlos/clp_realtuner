-- =============================================================================
--  clp_realtuner - ox_inventory Items (in data/items.lua einfügen)
--  Alle Items decken die Teile aus config/parts.lua ab + Werkzeuge & Tablet.
-- =============================================================================

return {
    -- Werkzeuge ------------------------------------------------------------
    ['toolbox']          = { label = 'Werkzeugkasten',         weight = 4000, stack = false, close = true },
    ['mechanic_toolkit'] = { label = 'Profi-Werkzeugkoffer',   weight = 8000, stack = false, close = true },
    ['ecu_flasher']      = { label = 'ECU-Flasher',            weight = 800,  stack = false, close = true },
    ['spraycan']         = { label = 'Lackspraydose',          weight = 300,  stack = true,  close = true },
    ['mechanic_tablet']  = { label = 'Mechaniker-Tablet',      weight = 500,  stack = false, close = true },

    -- Motor ----------------------------------------------------------------
    ['engine_block_stock']  = { label = 'Motorblock (Serie)',        weight = 40000, stack = false },
    ['engine_block_forged'] = { label = 'Motorblock (Geschmiedet)',  weight = 42000, stack = false },
    ['engine_block_race']   = { label = 'Motorblock (Race)',         weight = 45000, stack = false },

    ['turbo_stock']         = { label = 'Turbolader (Basis)',        weight = 8000, stack = false },
    ['turbo_stage2']        = { label = 'Turbolader Stufe 2',        weight = 8500, stack = false },
    ['turbo_stage3']        = { label = 'Bi-Turbo Stufe 3',          weight = 11000, stack = false },

    ['ecu_basic']           = { label = 'ECU Chip (Basis)',          weight = 400,  stack = false },
    ['ecu_race']            = { label = 'ECU Chip (Race)',           weight = 400,  stack = false },

    ['intake_short']        = { label = 'Sportluftfilter',           weight = 1500, stack = false },
    ['intake_cold']         = { label = 'Kaltluft-Ansaugung',        weight = 3000, stack = false },

    ['exhaust_sport']       = { label = 'Sportauspuff',              weight = 7000, stack = false },
    ['exhaust_race']        = { label = 'Race Auspuff (Titan)',      weight = 5500, stack = false },

    -- Getriebe / Bremsen ---------------------------------------------------
    ['transmission_stock']  = { label = 'Getriebe (Serie)',          weight = 35000, stack = false },
    ['transmission_sport']  = { label = 'Sportgetriebe',             weight = 35000, stack = false },
    ['transmission_race']   = { label = 'Race Getriebe (Sequ.)',     weight = 36000, stack = false },

    ['brakes_stock']        = { label = 'Bremsen (Serie)',           weight = 9000, stack = false },
    ['brakes_street']       = { label = 'Street Brakes',             weight = 10000, stack = false },
    ['brakes_race']         = { label = 'Race Brakes (Keramik)',     weight = 11000, stack = false },

    -- Fahrwerk -------------------------------------------------------------
    ['suspension_stock']    = { label = 'Fahrwerk (Serie)',          weight = 18000, stack = false },
    ['suspension_lowered']  = { label = 'Tieferlegung',              weight = 18000, stack = false },
    ['suspension_sport']    = { label = 'Sportfahrwerk',             weight = 19000, stack = false },
    ['suspension_race']     = { label = 'Gewindefahrwerk',           weight = 20000, stack = false },

    -- Räder ----------------------------------------------------------------
    ['wheel_rim_basic']     = { label = 'Felge (Basic)',             weight = 7000, stack = true },
    ['wheel_rim_sport']     = { label = 'Felge (Sport)',             weight = 7200, stack = true },

    ['tire_street']         = { label = 'Reifen (Street)',           weight = 6000, stack = true },
    ['tire_sport']          = { label = 'Reifen (Sport)',            weight = 6200, stack = true },
    ['tire_race']           = { label = 'Reifen (Semi-Slick)',       weight = 6500, stack = true },
    ['tire_drift']          = { label = 'Drift Reifen',              weight = 6300, stack = true },

    -- Body / Optik ---------------------------------------------------------
    ['spoiler_basic']       = { label = 'Spoiler (GT)',              weight = 4000, stack = false },
    ['spoiler_race']        = { label = 'Spoiler (Race Wing)',       weight = 4500, stack = false },
    ['bodykit_side']        = { label = 'Seitenschweller-Kit',       weight = 6000, stack = false },
    ['bodykit_front']       = { label = 'Front-Bumper-Kit',          weight = 7000, stack = false },
    ['bodykit_rear']        = { label = 'Heck-Bumper-Kit',           weight = 7000, stack = false },
    ['hood_vented']         = { label = 'Motorhaube (belüftet)',     weight = 8000, stack = false },
    ['grille_mesh']         = { label = 'Grill (Mesh)',              weight = 2500, stack = false },
    ['fender_wide']         = { label = 'Kotflügel (Wide)',          weight = 5500, stack = false },

    -- Service --------------------------------------------------------------
    ['oil_basic']           = { label = 'Motoröl (Basic)',           weight = 1200, stack = true },
    ['oil_full_synth']      = { label = 'Motoröl (Vollsynthetik)',   weight = 1200, stack = true },
    ['coolant']             = { label = 'Kühlmittel',                weight = 1500, stack = true },
    ['brake_pad_set']       = { label = 'Bremsbeläge',               weight = 2000, stack = true },
    ['brake_fluid']         = { label = 'Bremsflüssigkeit',          weight = 800,  stack = true },
    ['spark_plug']          = { label = 'Zündkerzen (Satz)',         weight = 400,  stack = true },
    ['battery']             = { label = 'Autobatterie',              weight = 15000, stack = false },
    ['headlight_bulb']      = { label = 'Scheinwerfer-Birne',        weight = 200,  stack = true },
    ['rearlight_bulb']      = { label = 'Rücklicht-Birne',           weight = 200,  stack = true },
    ['windshield_repair']   = { label = 'Windschutzscheiben-Kit',    weight = 5000, stack = false },
    ['rust_remover']        = { label = 'Rostentferner + Lack',      weight = 1500, stack = true },

    -- Diagnose-Tools (Batch 2) --------------------------------------------
    ['obd_scanner']         = { label = 'OBD-Scanner',               weight = 600,  stack = false, close = true,
                                description = 'Liest Live-Daten und DTC-Codes aus jedem Fahrzeug.' },
    ['endoscope']           = { label = 'Endoskop-Kamera',           weight = 1000, stack = false, close = true,
                                description = 'Kamera für Motor-Innenraum-Inspektion.' },
    ['torque_wrench']       = { label = 'Drehmoment-Schlüssel',      weight = 1500, stack = false, close = true,
                                description = 'Reduziert Einbau-Fehlerchance um 40%.' },

    -- Tuning-Tiefe (Batch 5) -----------------------------------------------
    ['cam_stage1']          = { label = 'Nockenwelle Stage 1',       weight = 3000, stack = false },
    ['cam_stage2']          = { label = 'Nockenwelle Stage 2',       weight = 3000, stack = false },
    ['cam_stage3']          = { label = 'Nockenwelle Race',          weight = 3000, stack = false },
    ['injector_street']     = { label = 'Einspritzer Street',        weight = 1200, stack = false },
    ['injector_sport']      = { label = 'Einspritzer Sport',         weight = 1200, stack = false },
    ['injector_race']       = { label = 'Einspritzer Race',          weight = 1300, stack = false },
    ['supercharger']        = { label = 'Supercharger-Kit',          weight = 15000, stack = false,
                                description = 'Alternativer Lader zum Turbo, konstanter Boost.' },
    ['neon_kit']            = { label = 'Unterboden-Neon-Kit',       weight = 2500, stack = false },
    ['wrap_vinyl']          = { label = 'Wrap-Folie',                weight = 1800, stack = true },
    ['leather_seats']       = { label = 'Leder-Sportsitze',          weight = 12000, stack = false },
    ['sport_steering']      = { label = 'Sport-Lenkrad',             weight = 2500, stack = false },
    ['window_tint_film']    = { label = 'Scheibentönungs-Folie',     weight = 600,  stack = true },
    ['caliper_paint']       = { label = 'Bremssattel-Lack',          weight = 400,  stack = true },
}
