-- =============================================================================
--  clp_realtuner - Dyno-Run (Batch 3 + Batch 9)
--  Misst 0-100, 0-200, Viertelmeile und generiert HP/Torque-Kurve per RPM-Bin
-- =============================================================================

HCM_C = HCM_C or {}

local function sendNui(action, data) SendNUIMessage({ action = action, data = data }) end

local function kmhToMs(kmh) return kmh / 3.6 end

local function estimatePeakHP(veh)
    -- Aus HandlingFloat fInitialDriveForce * fMass / ca. 0.16 -> grobe HP-Schätzung
    local mass = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fMass') or 1500.0
    local drive = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveForce') or 0.3
    return math.floor(mass * drive * 1.85)
end

--- Fuehrt einen Dyno-Run auf dem aktuellen Fahrzeug aus
--- @param maxKmh number Ziel-Geschwindigkeit fuer den Pull (z.B. 250)
--- @return table result { peakHP, peakTorque, t0to100, t0to200, quarterMile, rpmCurve, hpCurve }
function HCM_C.runDyno(maxKmh)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        lib.notify({ title = 'Dyno', description = 'Bitte in ein Fahrzeug einsteigen.', type = 'error' })
        return nil
    end
    maxKmh = maxKmh or 250
    local rec = HCM_C.getRecord(veh)
    if not rec then return nil end

    local samples = {}         -- {rpm=x, kmh=y, t=ms, accel=m/s^2}
    local startTs = GetGameTimer()
    local t100, t200, qmDist, qmT = 0, 0, 0, 0
    local prevSpeed = 0
    local prevTs = startTs
    local totalDist = 0

    -- Vollgas erzwingen waehrend des Runs
    sendNui('dyno:start', { maxKmh = maxKmh, plate = HCM_C.plateOf(veh) })

    local running = true
    CreateThread(function()
        while running do
            SetControlValue(0, 71, 254)
            Wait(0)
        end
    end)

    -- 20s maximale Sampling-Phase
    local startDist = GetEntityCoords(veh)
    while running do
        local now = GetGameTimer()
        local elapsed = now - startTs
        if elapsed > 20000 then break end
        local speedMs = GetEntitySpeed(veh)
        local kmh = speedMs * 3.6
        local rpmPct = GetVehicleCurrentRpm(veh) or 0
        local rpm = math.floor(rpmPct * 8000)
        local dt = (now - prevTs) / 1000.0
        local accel = dt > 0 and (speedMs - prevSpeed) / dt or 0
        samples[#samples + 1] = { rpm = rpm, kmh = kmh, t = elapsed, accel = accel }

        if t100 == 0 and kmh >= 100 then t100 = elapsed / 1000.0 end
        if t200 == 0 and kmh >= 200 then t200 = elapsed / 1000.0 end
        totalDist = #(GetEntityCoords(veh) - startDist)
        if qmDist == 0 and totalDist >= 402 then -- Viertelmeile (402m)
            qmDist = totalDist
            qmT = elapsed / 1000.0
        end

        prevSpeed = speedMs
        prevTs = now

        if kmh >= maxKmh or qmT > 0 then break end
        Wait(50)
    end
    running = false

    -- HP-Kurve: pro 500 RPM Bin den Peak accel -> grobe HP ableiten
    local mass = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fMass') or 1500.0
    local bins = {}
    for _, s in ipairs(samples) do
        if s.rpm > 800 and s.accel > 0 then
            local bin = math.floor(s.rpm / 500) * 500
            local force = mass * s.accel                 -- Newton
            local powerW = force * math.max(1, s.kmh / 3.6)  -- P = F * v
            local hp = powerW / 745.7
            bins[bin] = math.max(bins[bin] or 0, hp)
        end
    end
    local rpmCurve, hpCurve = {}, {}
    for rpm, _ in pairs(bins) do rpmCurve[#rpmCurve + 1] = rpm end
    table.sort(rpmCurve)
    for _, rpm in ipairs(rpmCurve) do hpCurve[#hpCurve + 1] = bins[rpm] end

    local peakHP = 0
    for _, v in ipairs(hpCurve) do if v > peakHP then peakHP = v end end
    -- Sanity-Fallback bei sehr kurzen Runs
    if peakHP < 20 then peakHP = estimatePeakHP(veh) end
    local peakTorque = math.floor(peakHP * 0.75) -- grobe Heuristik (HP ~ Nm * rpm / 7127)

    local result = {
        peakHP = math.floor(peakHP),
        peakTorque = peakTorque,
        t0to100 = math.floor(t100 * 100) / 100,
        t0to200 = math.floor(t200 * 100) / 100,
        quarterMile = { dist = math.floor(qmDist), time = math.floor(qmT * 100) / 100 },
        rpmCurve = rpmCurve, hpCurve = hpCurve,
        plate = HCM_C.plateOf(veh),
        model = GetDisplayNameFromVehicleModel(GetEntityModel(veh)),
        timestamp = HCM.util.now(),
    }
    sendNui('dyno:result', result)
    SetNuiFocus(true, true)
    TriggerServerEvent('clp_realtuner:dyno:store', result)
    return result
end

RegisterNUICallback('dyno:close', function(_, cb) SetNuiFocus(false, false); cb({ ok = true }) end)
RegisterNUICallback('dyno:run', function(data, cb)
    cb({ ok = true })
    CreateThread(function()
        HCM_C.runDyno(tonumber(data and data.maxKmh) or 250)
    end)
end)

exports('runDyno', HCM_C.runDyno)

-- Befehl fuer schnelles Testen
RegisterCommand('dyno', function() HCM_C.runDyno(250) end, false)
