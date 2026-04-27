-- =============================================================================
--  clp_hardcore_mechanic - Hauptkonfiguration
-- =============================================================================

Config = {}

-- ESX / Debug -----------------------------------------------------------------
Config.Debug          = false                   -- ox_target Debug-Draw, Zusatz-Logs
Config.Locale         = 'de'
Config.AdminGroups    = { admin = true, superadmin = true, owner = true }
Config.MechanicJobs   = { mechanic = true, tuning = true, lscustoms = true } -- ESX jobs die Mechaniker-Aktionen ausführen dürfen
Config.AllowOutsideJob = false                  -- true = jeder darf (Off-Road-Reparatur)

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
