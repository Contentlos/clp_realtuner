-- =============================================================================
--  clp_realtuner - Dyno Runs + Fahrtenbuch (Batch 3 / 9)
-- =============================================================================

local ESX = exports['es_extended']:getSharedObject()

-- Tabelle sicherstellen (falls Migration 003 nicht drin)
CreateThread(function()
    if HCM.server.waitForMigrations then HCM.server.waitForMigrations(20000) end
    pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `mechanic_dyno_runs` (
                `id`          BIGINT NOT NULL AUTO_INCREMENT,
                `plate`       VARCHAR(16) NOT NULL,
                `vin`         VARCHAR(24) DEFAULT NULL,
                `identifier`  VARCHAR(64) DEFAULT NULL,
                `peak_hp`     INT NOT NULL DEFAULT 0,
                `peak_torque` INT NOT NULL DEFAULT 0,
                `t_0_100`     DECIMAL(5,2) DEFAULT 0,
                `t_0_200`     DECIMAL(5,2) DEFAULT 0,
                `qm_time`     DECIMAL(5,2) DEFAULT 0,
                `curve_json`  JSON NULL,
                `timestamp`   BIGINT NOT NULL,
                PRIMARY KEY (`id`),
                KEY `idx_plate` (`plate`),
                KEY `idx_identifier` (`identifier`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `mechanic_trips` (
                `id`          BIGINT NOT NULL AUTO_INCREMENT,
                `plate`       VARCHAR(16) NOT NULL,
                `identifier`  VARCHAR(64) DEFAULT NULL,
                `start_ts`    BIGINT NOT NULL,
                `end_ts`      BIGINT NOT NULL,
                `km`          DECIMAL(8,2) NOT NULL DEFAULT 0,
                `max_kmh`     INT NOT NULL DEFAULT 0,
                `avg_kmh`     INT NOT NULL DEFAULT 0,
                `start_x`     FLOAT NULL, `start_y` FLOAT NULL, `start_z` FLOAT NULL,
                `end_x`       FLOAT NULL, `end_y`   FLOAT NULL, `end_z`   FLOAT NULL,
                PRIMARY KEY (`id`),
                KEY `idx_plate` (`plate`),
                KEY `idx_identifier` (`identifier`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])
    end)
end)

RegisterNetEvent('clp_realtuner:dyno:store', function(result)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or type(result) ~= 'table' then return end
    local plate = HCM.util.normalizePlate(result.plate or '')
    if plate == '' then return end
    local rec = HCM.server.getRecord and HCM.server.getRecord(plate) or nil
    local vin = rec and rec.vin or nil
    local curve = { rpm = result.rpmCurve, hp = result.hpCurve }
    pcall(function()
        MySQL.insert.await([[
            INSERT INTO mechanic_dyno_runs
                (plate, vin, identifier, peak_hp, peak_torque, t_0_100, t_0_200, qm_time, curve_json, timestamp)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            plate, vin, xPlayer.identifier,
            tonumber(result.peakHP) or 0, tonumber(result.peakTorque) or 0,
            tonumber(result.t0to100) or 0, tonumber(result.t0to200) or 0,
            (result.quarterMile and tonumber(result.quarterMile.time)) or 0,
            json.encode(curve), os.time(),
        })
    end)
    HCM.server.log(xPlayer, 'dyno:run', plate, vin, {
        peakHP = result.peakHP, peakTorque = result.peakTorque,
        t0to100 = result.t0to100, qm = result.quarterMile,
    })
end)

lib.callback.register('clp_realtuner:dyno:history', function(source, plate, limit)
    plate = HCM.util.normalizePlate(plate or '')
    local rows = {}
    pcall(function()
        rows = MySQL.query.await([[
            SELECT id, peak_hp, peak_torque, t_0_100, t_0_200, qm_time, timestamp
              FROM mechanic_dyno_runs
             WHERE plate = ?
             ORDER BY timestamp DESC LIMIT ?
        ]], { plate, tonumber(limit) or 25 }) or {}
    end)
    return rows
end)

-- Fahrtenbuch: aus client/wartung.lua km-Delta aggregierten Trip abschicken
RegisterNetEvent('clp_realtuner:trip:end', function(trip)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or type(trip) ~= 'table' then return end
    local plate = HCM.util.normalizePlate(trip.plate or '')
    if plate == '' then return end
    pcall(function()
        MySQL.insert.await([[
            INSERT INTO mechanic_trips
                (plate, identifier, start_ts, end_ts, km, max_kmh, avg_kmh,
                 start_x, start_y, start_z, end_x, end_y, end_z)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            plate, xPlayer.identifier,
            tonumber(trip.startTs) or os.time(), tonumber(trip.endTs) or os.time(),
            tonumber(trip.km) or 0, tonumber(trip.maxKmh) or 0, tonumber(trip.avgKmh) or 0,
            trip.startX or 0, trip.startY or 0, trip.startZ or 0,
            trip.endX or 0, trip.endY or 0, trip.endZ or 0,
        })
    end)
end)

lib.callback.register('clp_realtuner:trip:history', function(source, plate, limit)
    plate = HCM.util.normalizePlate(plate or '')
    local rows = {}
    pcall(function()
        rows = MySQL.query.await([[
            SELECT id, start_ts, end_ts, km, max_kmh, avg_kmh,
                   start_x, start_y, start_z, end_x, end_y, end_z
              FROM mechanic_trips
             WHERE plate = ?
             ORDER BY end_ts DESC LIMIT ?
        ]], { plate, tonumber(limit) or 50 }) or {}
    end)
    return rows
end)
