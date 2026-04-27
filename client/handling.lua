-- =============================================================================
--  clp_realtuner - Dynamisches Fahrverhalten
--
--  Multiplikatoren werden lokal (Owner-Entity) über SetVehicleHandlingFloat
--  gesetzt. Baseline stammt aus handling.meta (GetVehicleHandlingFloat nach Spawn).
-- =============================================================================

HCM_C = HCM_C or {}

local baselines = {}  -- netId -> baseline-values

local HANDLING_FIELDS = {
    'fInitialDriveForce',       -- Beschleunigung
    'fInitialDriveMaxFlatVel',  -- Topspeed
    'fDriveInertia',
    'fBrakeForce',
    'fTractionCurveMax',
    'fTractionCurveMin',
    'fHandBrakeForce',
    'fSteeringLock',
}

local function getBaseline(veh)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    if baselines[netId] then return baselines[netId] end
    local b = {}
    for _, f in ipairs(HANDLING_FIELDS) do
        b[f] = GetVehicleHandlingFloat(veh, 'CHandlingData', f)
    end
    baselines[netId] = b
    return b
end

local function avg(rec, keys)
    local s, n = 0, 0
    for _, k in ipairs(keys) do
        if rec[k] then s = s + rec[k]; n = n + 1 end
    end
    return n == 0 and 100.0 or (s / n)
end

---@param veh number
function HCM_C.applyHandling(veh)
    if not Config.Handling.Enabled then return end
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    if NetworkGetEntityOwner(veh) ~= PlayerId() then return end
    local rec = HCM_C.getRecord(veh)
    if not rec then return end

    local base = getBaseline(veh)
    local tuning = rec.tuning_data or {}

    local engineHealth = (rec.engine_health or 100) / 100
    local turboHealth  = (rec.turbo_health or 100) / 100
    local brakeHealth  = (rec.brake_health or 100) / 100
    local trnHealth    = (rec.transmission_health or 100) / 100
    local suspHealth   = (rec.suspension_health or 100) / 100

    local powerFactor = (engineHealth * 0.7 + turboHealth * 0.3)
    local gripFactor  = (suspHealth * 0.6 + 0.4)
    local brakeFactor = brakeHealth
    local driveFactor = (engineHealth * 0.5 + trnHealth * 0.5)

    local accelBonus    = (tuning.accel    or 0) / 100
    local topspeedBonus = (tuning.topspeed or 0) / 100
    local brakeBonus    = (tuning.brake    or 0) / 100
    local tractionBonus = (tuning.traction or 0) / 100

    local accelMult = HCM.util.clamp(powerFactor * (1 + accelBonus), Config.Handling.MinAccelMult, 1.8)
    local topMult   = HCM.util.clamp(driveFactor * (1 + topspeedBonus), Config.Handling.MinTopSpeedMult, 1.6)
    local brakeMult = HCM.util.clamp(brakeFactor * (1 + brakeBonus), Config.Handling.MinBrakeMult, 1.5)
    local gripMult  = HCM.util.clamp(gripFactor  * (1 + tractionBonus), Config.Handling.MinTractionMult, 1.6)

    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveForce',      base.fInitialDriveForce      * accelMult)
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fDriveInertia',           base.fDriveInertia           * accelMult)
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel', base.fInitialDriveMaxFlatVel * topMult)
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fBrakeForce',             base.fBrakeForce             * brakeMult)
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fHandBrakeForce',         base.fHandBrakeForce         * brakeMult)
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionCurveMax',       base.fTractionCurveMax       * gripMult)
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionCurveMin',       base.fTractionCurveMin       * gripMult)
end

-- Ticker: aktives Fahrzeug alle Interval ms updaten
CreateThread(function()
    while true do
        Wait(Config.Handling.Interval or 1500)
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            HCM_C.applyHandling(veh)
        end
    end
end)
