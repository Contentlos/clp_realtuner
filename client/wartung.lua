-- =============================================================================
--  clp_realtuner - Wartung / Fluessigkeiten / Verschleiss (Client)
--  Trackt den eigenen Fahrsitz + akkumuliert km-basierten Verschleiss.
--  Sendet Delta-Updates an Server alle 10 Sekunden.
-- =============================================================================

HCM = HCM or {}
HCM_C = HCM_C or {}
HCM_C.wartung = HCM_C.wartung or {}

local function getPlate(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    return (GetVehicleNumberPlateText(veh) or ''):gsub('%s', ''):upper()
end

local last = {
    veh = nil, plate = nil,
    speed = 0, rpm = 0, brake = 0,
    lastPosTime = 0, lastPos = nil,
}

local accum = {}           -- plate -> delta table (additive)
local lastFlushT = 0
local HARD_BRAKE_COOLDOWN = 0

local function getAccum(plate)
    if not accum[plate] then accum[plate] = {} end
    return accum[plate]
end

local function addDelta(plate, key, v)
    local a = getAccum(plate)
    a[key] = (a[key] or 0) + v
end

local function setVal(plate, key, v)
    local a = getAccum(plate)
    a[key] = v
end

local function flush()
    local now = GetGameTimer()
    if now - lastFlushT < 10000 then return end
    lastFlushT = now
    for plate, delta in pairs(accum) do
        -- oil_km ist additiv, Rest ist neuer Absolutwert
        local payload = {}
        for k, v in pairs(delta) do payload[k] = v end
        TriggerServerEvent('clp_realtuner:wartung:delta', plate, payload)
    end
    accum = {}
end

-- Haupt-Tick ----------------------------------------------------------------
CreateThread(function()
    while true do
        local interval = (Config.Wartung and Config.Wartung.Interval) or 5000
        Wait(interval)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and DoesEntityExist(veh) then
            local plate = getPlate(veh)
            if plate then
                -- km-Delta (nur wenn Motor laeuft bzw. sich bewegt)
                local pos = GetEntityCoords(veh)
                local now = GetGameTimer()
                if last.lastPos and last.plate == plate then
                    local dx = pos.x - last.lastPos.x
                    local dy = pos.y - last.lastPos.y
                    local dist = math.sqrt(dx * dx + dy * dy) -- Meter
                    local km = dist / 1000.0
                    if km > 0.0005 then
                        local w = Config.Wartung
                        addDelta(plate, 'oil_km', math.floor(dist))
                        -- oil_quality degrade
                        local rec = HCM_C.records and HCM_C.records[plate]
                        if rec then
                            rec.oil_quality = math.max(0, (rec.oil_quality or 100) - km * (w.OilQualityPerKm or 0.012))
                            rec.spark_plug  = math.max(0, (rec.spark_plug or 100) - km * (w.SparkPlugPerKm or 0.008))
                            -- Redline
                            local rpm = GetVehicleCurrentRpm(veh)
                            if rpm > 0.92 then
                                rec.spark_plug = math.max(0, rec.spark_plug - (w.SparkPlugRedlinePer10s or 0.5) / 10 * (interval / 1000))
                            end
                            -- Kuehlmittel-Temp Simulation
                            local engOn = GetIsVehicleEngineRunning(veh)
                            local temp = rec.coolant_temp or 85
                            if engOn then
                                local load = math.min(1.5, rpm * 1.2)
                                temp = math.min(130, temp + (w.CoolantWarmupPerSecondRun or 1.5) * load * (interval/1000))
                            else
                                temp = math.max(w.CoolantAmbient or 20, temp - (w.CoolantCoolDownPerSecondOff or 0.8) * (interval/1000))
                            end
                            -- Coolant leak Wenn sehr heiss und niedrig
                            if temp > (w.CoolantBoilTemp or 108) then
                                rec.coolant = math.max(0, (rec.coolant or 100) - 0.5)
                                rec.engine_health = math.max(0, (rec.engine_health or 100) - 0.2)
                            end
                            rec.coolant_temp = temp
                            -- Batterie aufladen beim Fahren
                            rec.battery = math.min(100, (rec.battery or 100) + (w.BatteryChargePerMinDrive or 1.2) / 60 * (interval/1000))
                            -- Lichter: brennen durch wenn an. GetVehicleLightsState gibt (ok, lowBeam, highBeam)
                            -- zurueck; das erste Return ist nur Erfolgs-Flag und wurde frueher faelschlich als Zustand
                            -- interpretiert, was zu Dauerverschleiss fuehrte.
                            local _, vehLowBeam, vehHighBeam = GetVehicleLightsState(veh)
                            local lightsOn = IsVehicleInteriorLightOn(veh) or vehLowBeam == 1 or vehLowBeam == true
                                or vehHighBeam == 1 or vehHighBeam == true
                            if lightsOn then
                                rec.headlight_state = math.max(0, (rec.headlight_state or 100) - (w.BulbDecayPerHour or 0.25) / 3600 * (interval/1000))
                                rec.rearlight_state = math.max(0, (rec.rearlight_state or 100) - (w.BulbDecayPerHour or 0.25) / 3600 * (interval/1000))
                            end
                            setVal(plate, 'oil_quality', rec.oil_quality)
                            setVal(plate, 'spark_plug',  rec.spark_plug)
                            setVal(plate, 'coolant_temp', rec.coolant_temp)
                            setVal(plate, 'coolant',     rec.coolant)
                            setVal(plate, 'battery',     rec.battery)
                            setVal(plate, 'headlight_state', rec.headlight_state)
                            setVal(plate, 'rearlight_state', rec.rearlight_state)
                        end
                    end
                end
                last.lastPos = pos
                last.plate = plate
                -- Harter Bremsvorgang?
                local brakePressure = GetControlValue(0, 72) / 255.0
                if brakePressure > 0.85 and now - HARD_BRAKE_COOLDOWN > 1500 then
                    HARD_BRAKE_COOLDOWN = now
                    local rec = HCM_C.records and HCM_C.records[plate]
                    if rec then
                        rec.brake_fluid = math.max(0, (rec.brake_fluid or 100) - (Config.Wartung.BrakeFluidPerHardBrake or 0.03))
                        setVal(plate, 'brake_fluid', rec.brake_fluid)
                    end
                end
                -- Fenster kaputt?
                local broken = IsVehicleWindowIntact and not IsVehicleWindowIntact(veh, 1)
                if broken then
                    setVal(plate, 'windshield_broken', 1)
                end
            end
        else
            last.lastPos = nil
            last.plate = nil
        end
        flush()
    end
end)

-- Server -> Client Sync (Service Reset) ------------------------------------
RegisterNetEvent('clp_realtuner:wartung:synced', function(plate, patch)
    local rec = HCM_C.records and HCM_C.records[plate]
    if not rec then return end
    for k, v in pairs(patch or {}) do rec[k] = v end
end)
