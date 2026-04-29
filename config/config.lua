-- =============================================================================
--  clp_hardcore_mechanic - Hauptkonfiguration
-- =============================================================================

Config = {}

-- ESX / Debug -----------------------------------------------------------------
Config.Debug          = false                   -- ox_target Debug-Draw, Zusatz-Logs
Config.Locale         = 'de'
Config.AdminGroups    = { admin = true, superadmin = true, owner = true }
Config.MechanicJobs   = { mechanic = true, tuning = true, lscustoms = true } -- ESX jobs die Mechaniker-Aktionen ausführen dürfen
Config.PoliceJobs     = { police = true, sheriff = true, fib = true, state = true } -- duerfen Polizei-Scanner benutzen
Config.AllowOutsideJob = false                  -- true = jeder darf (Off-Road-Reparatur)
Config.WorkshopBuyPrice = 500000                -- server-authoritativer Preis fuer Werkstatt-Kauf

-- Bestellsystem (Batch 14b) -------------------------------------------------
-- Lieferzeit-Spanne fuer Lager-Bestellungen (Sekunden)
Config.OrderDelayMin = 300                       -- 5 Minuten
Config.OrderDelayMax = 900                       -- 15 Minuten

-- Lager-Pflicht: wenn true, koennen Mechaniker Teile NUR aus dem
-- Werkstatt-Lager einbauen (nicht aus eigenem Inventar). Default false
-- = locker (Inventar geht weiterhin), true = hardcore.
Config.WorkshopMustUseStock = false
Config.TUeVValidDays   = 365                    -- wie lange eine bestandene TUeV-Pruefung gilt
Config.TUeVGracePeriod = 14                     -- Tage Toleranz nach Ablauf

-- Persistenz ------------------------------------------------------------------
Config.AutoSaveInterval     = 60 * 1000         -- ms, periodisches Speichern laufender Fahrzeuge
Config.ServiceIntervalHours = 72                -- Ingame-Stunden bis Service fällig (Default 72h realtime)
Config.HealthDecayPerKm     = 0.015             -- Basis Verschleiß pro gefahrenem km

-- ox_target Zonen -------------------------------------------------------------
Config.Target = {
    HoodDistance       = 1.6,
    TrunkDistance      = 1.6,
    SideDistance       = 1.4,
    WheelDistance      = 0.9,
    RequireHoodOpenForEngine = true,
    ShowDebug          = false,
}

-- Einbau / Ausbau -------------------------------------------------------------
Config.Install = {
    MinDuration            = 5000,              -- ms, abhängig von Skill
    MaxDuration            = 25000,
    Animation              = { dict = 'mini@repair', anim = 'fixing_a_ped', flag = 1 },
    ToolItem               = 'toolbox',          -- muss im ox_inventory existieren
    AdvancedToolItem       = 'mechanic_toolkit', -- für höherwertige Teile erforderlich
    RequireEngineOff       = true,
    MaxVehicleSpeed        = 0.1,                -- m/s
    MustBeOutside          = true,               -- Spieler darf nicht im Fahrzeug sitzen
    FailDamageParts        = true,               -- Bei Fehler kann das Teil beschädigt werden
    FailReturnRate         = 0.4,                -- 0..1 Chance, dass Teil bei Fehler zerstört wird
}

-- Schaden / Hardcore ----------------------------------------------------------
Config.Damage = {
    Enabled                = true,
    Interval               = 2000,               -- ms, Tick-Intervall Engine-Monitor
    OverheatThreshold      = 0.75,               -- Anteil EngineHealth vs Max ab dem Überhitzung greift
    TurboBoostDamageAbove  = 0.85,               -- Anteil throttle bei dem Turbo leidet (wenn Qualität niedrig)
    TransmissionRedline    = 0.92,               -- RPM Anteil ab dem Getriebe Schaden nimmt
    BrakeHeatThreshold     = 0.9,
    SmokeParticleMinHealth = 45,                 -- < als Wert -> Rauch
    BackfireMinHealth      = 25,
    StallMinHealth         = 10,
}

-- Fahrverhalten ---------------------------------------------------------------
Config.Handling = {
    Enabled      = true,
    Interval     = 1500,
    FieldWeights = {
        -- Faktor je Komponentenhealth (0..1). Werte unter 1 reduzieren, über 1 erhöhen.
        -- Reihenfolge: keys sind HandlingFloats, values Funktion(tuning, health).
        -- Werte werden per SetVehicleHandlingFloat relativ zum Baseline-Handling gesetzt.
    },
    MinAccelMult     = 0.35,
    MinTopSpeedMult  = 0.55,
    MinBrakeMult     = 0.4,
    MinTractionMult  = 0.6,
}

-- Lackierung ------------------------------------------------------------------
Config.Paint = {
    Duration          = 20000,                  -- ms Sprühprozess
    ParticleDict      = 'core',
    ParticleName      = 'ent_amb_smoke_foundry',
    SoundSet          = 'DLC_Dmod_Prop_Editor_Sounds',
    SoundName         = 'Start_Spray',
    Tool              = 'spraycan',             -- ox_inventory item
    MattePerfectRate  = 0.60,
    MetallicPerfectRate = 0.45,
    PearlPerfectRate  = 0.30,
    QualityFloor      = 35.0,
    QualityPerfect    = 100.0,
}

-- ECU Tuning ------------------------------------------------------------------
Config.ECU = {
    AFR = { min = 10.5, max = 16.5, stock = 14.7, safe = { 12.5, 14.7 } },
    Torque = { min = 0.8, max = 1.4, stock = 1.0, safe = { 0.9, 1.15 } },
    FuelMap = { min = 0.7, max = 1.4, stock = 1.0, safe = { 0.9, 1.2 } },
    EngineDamageOnFlash = 5.0,                  -- Punkte Engine-Health-Verlust pro unsicherem Flash
    RequireItem = 'ecu_flasher',
}

-- Skill-System ----------------------------------------------------------------
Config.Skill = {
    MaxLevel = 10,
    XP = {
        install_success = 8,
        install_fail    = 2,
        repair          = 5,
        diagnose        = 1,
        paint_success   = 6,
        ecu_flash_safe  = 4,
    },
    LevelCurve = function(level)
        return math.floor(80 * (level ^ 1.5))
    end,
    FailRateReductionPerLevel = 0.03,
    SpeedBonusPerLevel        = 0.04,
}

-- Tablet ----------------------------------------------------------------------
Config.Tablet = {
    Item                = 'mechanic_tablet',
    OpenKeybind         = nil,                  -- z.B. 'F6'; nil = nur per Item
    AnimationDict       = 'amb@world_human_seat_wall_tablet@female@base',
    AnimationName       = 'base',
}

-- Admin / Logs ----------------------------------------------------------------
Config.AdminCommand       = 'hcmadmin'          -- /hcmadmin dump <plate>
Config.LogRetentionDays   = 90

-- =============================================================================
--  Wartung, Flüssigkeiten, Verschleiß (Batch 1)
-- =============================================================================
Config.Wartung = {
    Interval          = 5000,  -- ms, client tick fuer Fluessigkeiten
    -- Öl: pro gefahrenem km verliert Qualitaet; ab X km Dringlicher Wechsel
    OilKmWarn         = 3000,
    OilKmCritical     = 6000,
    OilQualityPerKm   = 0.012,
    -- Zündkerzen: Verschleiß pro km + Redline-Strafe
    SparkPlugPerKm    = 0.008,
    SparkPlugRedlinePer10s = 0.5,  -- bei Redline laufen, verliert zusaetzlich
    -- Batterie: entlaedt ueber Zeit (Standzeit) und bei gezogenem Strom
    BatteryDrainPerHour   = 0.8,  -- %/h Standzeit
    BatteryDrainPerMinRun = 0.04, -- %/min Motor laeuft zieht minimal (Reserve)
    BatteryChargePerMinDrive = 1.2,
    BatteryNoStartBelow   = 10,
    -- Lichter: brennen durch bei hoher Benutzung
    BulbDecayPerHour      = 0.25,
    -- Bremsfluessigkeit: verliert bei Hard-Brake
    BrakeFluidPerHardBrake = 0.03,
    BrakeFluidLeakOnCrashAbove = 25.0,  -- Crash-Damage in % -> Leck moeglich
    -- Kuehlmittel
    CoolantBoilTemp       = 108,  -- °C ab wann Engine Damage
    CoolantAmbient        = 20,
    CoolantWarmupPerSecondRun = 1.5,
    CoolantCoolDownPerSecondOff = 0.8,
    CoolantLeakOnCrash    = 0.6,  -- je % crash -> %/s Verlust
    -- Rost
    RustPerHourOutdoor    = 0.015,
    RustResetOnService    = true,
    RustPaintProtect      = 0.4,  -- Multiplikator wenn paint_quality > 80
    -- Turbo Lag
    TurboLagMinMult       = 0.35, -- bei turbo_health = 0: 0.35x Response
    -- Scheibenbruch-Repair
    WindshieldRepairItem  = 'windshield_kit',
    WindshieldRepairTime  = 12000,
}

-- =============================================================================
--  Physik-Toggles (Batch 1)
-- =============================================================================
Config.Physics = {
    -- Traction Control: wenn off -> leichteres Drift, mehr Grip-Verlust bei Vollgas
    TC_TractionDropOff    = 0.15,  -- Faktor wenn TC aus
    ABS_BrakeDropOff      = 0.25,  -- ohne ABS: blockieren lassen, laenger Bremsweg
    -- Aerodynamik durch Bodykits
    Aero = {
        -- modIndex im modType 'spoiler' -> Downforce-Faktor (0 = keiner, 1 = stock, >1 = mehr)
        SpoilerMult       = { [0] = 1.0, [1] = 1.15, [2] = 1.25, [3] = 1.35, [4] = 1.45 },
        BodyKitMult       = { [0] = 1.0, [1] = 1.10, [2] = 1.18, [3] = 1.28 },
        DragPenaltyMult   = 0.95, -- schweres Bodykit reduziert Top-Speed
    },
    -- Auspuffklappe: lauter + leichte RPM-Gewinn / Fuel-Verbrauch-Verlust
    ExhaustFlap = {
        BackfireChance    = 0.08, -- pro Lift-Off bei offener Klappe
        VolumeMult        = 1.8,
        TorqueMult        = 1.04,
    },
}

-- =============================================================================
--  ECU-Maps (Eco/Sport/Race) - Batch 5, Konfig hier weil shared
-- =============================================================================
Config.ECUMaps = {
    stock = { label = 'Stock',  afr = 14.7, torque = 1.00, fuel = 1.00, riskMult = 0.0 },
    eco   = { label = 'Eco',    afr = 15.2, torque = 0.92, fuel = 0.85, riskMult = 0.0 },
    sport = { label = 'Sport',  afr = 13.8, torque = 1.12, fuel = 1.10, riskMult = 0.10 },
    race  = { label = 'Race',   afr = 12.8, torque = 1.28, fuel = 1.30, riskMult = 0.35 },
}

-- =============================================================================
--  TÜV / Inspektion (Batch 10)
-- =============================================================================
Config.TUeV = {
    Enabled        = true,
    ValidDays      = 365,
    InspectionPrice = 250,
    FailThresholds = {
        engine_health = 40,
        brake_health  = 45,
        suspension_health = 40,
        brake_fluid   = 25,
        coolant       = 25,
        rust          = 70,
        headlight_state = 40,
        rearlight_state = 40,
        windshield_broken = 0,
    },
}

-- =============================================================================
--  HUD / UI (Batch 3)
-- =============================================================================
Config.HUD = {
    Enabled           = true,
    Key               = 'F7',
    DefaultEnabled    = true,
    Refresh           = 250,  -- ms
    Position          = 'bottom-right',
    ShowBoost         = true,
    ShowOilPressure   = true,
    ShowCoolantTemp   = true,
    ShowBattery       = true,
}

-- =============================================================================
--  Audio FX (Batch 4)
-- =============================================================================
Config.AudioFX = {
    Enabled              = true,
    BackfireMinHealth    = 40,   -- bereits bei 40 fehlerzuendungen
    TurboWhistleVolume   = 0.8,
    GearboxRattleBelow   = 50,
    BrakeSqueakBelow     = 45,
    ExhaustPopsOnLiftoff = true,
}

-- =============================================================================
--  Insurance (Batch 11)
-- =============================================================================
Config.Insurance = {
    Enabled = true,
    Plans = {
        basic = { label = 'Basic',   price = 2500,  deductible = 1000, sum = 8000,  days = 30 },
        full  = { label = 'Vollkasko', price = 6500,  deductible = 500,  sum = 25000, days = 30 },
    },
    ClaimTimeoutMinutes = 15,
}

-- =============================================================================
--  Dyno / Racing (Batch 9)
-- =============================================================================
Config.Dyno = {
    Enabled           = true,
    ZeroHundredTarget = 100.0,    -- km/h
    QuarterMile       = 402.336,  -- m
    RecordKeepTop     = 50,
}

-- =============================================================================
--  Mechaniker-Progression (Batch 6)
-- =============================================================================
Config.Progression = {
    Tiers = {
        lehrling  = { minLevel = 1,  label = 'Lehrling',   failMult = 1.00, speedMult = 1.00 },
        geselle   = { minLevel = 4,  label = 'Geselle',    failMult = 0.75, speedMult = 1.10 },
        meister   = { minLevel = 8,  label = 'Meister',    failMult = 0.50, speedMult = 1.25 },
    },
    Specializations = {
        motor      = { label = 'Motor-Spezialist',   failMultOn = { 'engine', 'turbo' },       bonus = 0.3 },
        bremsen    = { label = 'Bremsen-Spezialist', failMultOn = { 'brakes' },                bonus = 0.35 },
        lack       = { label = 'Lackierer',          paintBonus = 0.25 },
        elektrik   = { label = 'Elektrik-Spezialist',failMultOn = { 'ecu', 'lights', 'battery' }, bonus = 0.3 },
    },
    CertificateItem = 'mechanic_certificate',
    ExamItem        = 'mechanic_exam_paper',
}

-- =============================================================================
--  Fuel-Bridge (Batch 11)
-- =============================================================================
Config.FuelBridge = {
    -- Provider: 'auto' (detect), 'ox_fuel', 'LegacyFuel', 'cdn_fuel', 'qs_fuelstations', 'ps-fuel', 'none'
    Provider = 'auto',
    WrongFuelDamagePerUnit = 0.25,  -- Motor-Health-Verlust pro Liter falscher Sprit
}

-- =============================================================================
--  Phone Bridge (Batch 11)
-- =============================================================================
Config.PhoneBridge = {
    Provider = 'auto',          -- auto, lb-phone, qs-smartphone, okokPhone, yseries, none
    AppIdentifier = 'realtuner',
}
