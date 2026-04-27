-- =============================================================================
--  clp_realtuner - ECU Feintuning
-- =============================================================================

HCM_C = HCM_C or {}

function HCM_C.openECU(entity)
    local plate = HCM_C.plateOf(entity)
    if not plate then return end
    local rec = HCM_C.getRecord(entity)
    if not rec then return end
    local ecu = rec.ecu_state or {}

    local result = lib.inputDialog('ECU Feintuning', {
        {
            type = 'slider', label = 'AFR (Luft/Kraftstoff)', icon = 'gas-pump',
            min = Config.ECU.AFR.min, max = Config.ECU.AFR.max, step = 0.1,
            default = ecu.afr or Config.ECU.AFR.stock,
            description = ('Safe-Bereich: %.1f - %.1f'):format(Config.ECU.AFR.safe[1], Config.ECU.AFR.safe[2]),
        },
        {
            type = 'slider', label = 'Drehmoment', icon = 'bolt',
            min = Config.ECU.Torque.min, max = Config.ECU.Torque.max, step = 0.05,
            default = ecu.torque or Config.ECU.Torque.stock,
            description = ('Safe: %.2f - %.2f'):format(Config.ECU.Torque.safe[1], Config.ECU.Torque.safe[2]),
        },
        {
            type = 'slider', label = 'Fuel Map', icon = 'droplet',
            min = Config.ECU.FuelMap.min, max = Config.ECU.FuelMap.max, step = 0.05,
            default = ecu.fuel or Config.ECU.FuelMap.stock,
            description = ('Safe: %.2f - %.2f'):format(Config.ECU.FuelMap.safe[1], Config.ECU.FuelMap.safe[2]),
        },
    })
    if not result then return end

    local newEcu = { afr = result[1], torque = result[2], fuel = result[3] }
    local ok, payload = lib.callback.await('clp_realtuner:ecuFlash', 2500, plate, newEcu)
    if not ok then
        lib.notify({ title = 'ECU', description = 'Fehler beim Flash: ' .. tostring(payload), type = 'error' })
        return
    end

    if payload.safe then
        lib.notify({ title = 'ECU', description = 'Flash OK (Safe-Werte).', type = 'success' })
    else
        lib.notify({ title = 'ECU', description = 'Flash mit Risiko - Motorschaden!', type = 'error' })
    end

    -- Tuning-Effekt lokal: Torque skaliert Beschleunigung
    local tuning = rec.tuning_data or {}
    local torqueDelta = math.floor(((newEcu.torque or 1.0) - 1.0) * 30)
    tuning.accel = (tuning.accel or 0) + torqueDelta - (tuning.ecu_accel_prev or 0)
    tuning.ecu_accel_prev = torqueDelta
    HCM_C.pushPatch(plate, { tuning_data = tuning }, 'ecu_apply')
    if HCM_C.applyHandling then HCM_C.applyHandling(entity) end
end
