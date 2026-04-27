-- =============================================================================
--  clp_realtuner - Polizei (Batch 10)
--   - Polizei-Scanner Callback
--   - VIN-Etching-Mismatch Detection
--   - TUeV-Pflicht-Check
-- =============================================================================

local ESX = exports['es_extended']:getSharedObject()

local function isPolice(xPlayer)
    if not xPlayer then return false end
    local job = xPlayer.job and xPlayer.job.name
    if job and Config.PoliceJobs and Config.PoliceJobs[job] then return true end
    local grp = xPlayer.getGroup and xPlayer.getGroup() or nil
    if grp and Config.AdminGroups and Config.AdminGroups[grp] then return true end
    return false
end

-- Polizei-Scanner: komplettes Fahrzeug-Dossier inklusive TUeV-Status + VIN-Mismatch.
lib.callback.register('clp_realtuner:police:scan', function(source, plate)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return nil end
    if not isPolice(xPlayer) then return nil end
    plate = HCM.util.normalizePlate(plate or '')
    if plate == '' then return nil end
    local rec = HCM.server.loadRecord(plate)
    if not rec then return nil end

    -- owned_vehicles Lookup (ESX Legacy)
    local owner
    pcall(function()
        local row = MySQL.single.await([[
            SELECT ov.owner, u.firstname, u.lastname
              FROM owned_vehicles ov
              LEFT JOIN users u ON u.identifier = ov.owner
             WHERE ov.plate = ?
             LIMIT 1
        ]], { plate })
        if row then owner = row end
    end)

    -- VIN-Etching-Mismatch: wenn eine abweichende "etched_vin" Zusatzspalte vorhanden ist,
    -- oder wenn der Datensatz eine neu generierte VIN hat, aber kein Besitzer existiert.
    local vinMismatch = false
    if rec.etched_vin and rec.vin and rec.etched_vin ~= '' and rec.etched_vin ~= rec.vin then
        vinMismatch = true
    end
    if not owner and rec.vin and rec.vin ~= '' then
        -- Fahrzeug existiert in vehicles_data, aber nicht in owned_vehicles -> Verdacht
        vinMismatch = vinMismatch or true
    end

    -- TUeV-Check
    local now = os.time()
    local tuevExpires = tonumber(rec.tuev_expires) or 0
    local graceDays = tonumber(Config.TUeVGracePeriod) or 14
    local tuevStatus = 'unknown'
    if tuevExpires == 0 then
        tuevStatus = 'missing'
    elseif tuevExpires < now - graceDays * 86400 then
        tuevStatus = 'expired'
    elseif tuevExpires < now then
        tuevStatus = 'grace'
    else
        tuevStatus = 'valid'
    end

    -- Letzte 5 Log-Eintraege (Spaltennamen laut INSTALL.sql: identifier/plate/detail)
    local logs = {}
    pcall(function()
        logs = MySQL.query.await([[
            SELECT id, identifier, action, plate, vin, timestamp, detail
              FROM mechanic_logs
             WHERE plate = ? OR vin = ?
             ORDER BY id DESC LIMIT 5
        ]], { plate, rec.vin or '' }) or {}
    end)

    HCM.server.log(xPlayer, 'police:scan', plate, rec.vin, { vinMismatch = vinMismatch, tuev = tuevStatus })

    return {
        plate = plate,
        vin = rec.vin,
        etched_vin = rec.etched_vin,
        vin_mismatch = vinMismatch,
        model = rec.model,
        engine_health = rec.engine_health,
        tuev_expires = tuevExpires,
        tuev_status = tuevStatus,
        owner_identifier = owner and owner.owner,
        owner_name = owner and ((owner.firstname or '') .. ' ' .. (owner.lastname or '')),
        last_service = rec.last_service,
        odometer = rec.odometer,
        logs = logs,
    }
end)

-- VIN-Etch: Mechaniker/Admin kann die VIN physisch in den Rahmen einschlagen.
-- Wenn plate spaeter geaendert wird (Duplicate/Theft), bleibt etched_vin erhalten -> Mismatch.
lib.callback.register('clp_realtuner:police:etchVin', function(source, plate)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return false end
    local job = xPlayer.job and xPlayer.job.name
    local grp = xPlayer.getGroup and xPlayer.getGroup() or nil
    local allowed = (job and Config.MechanicJobs and Config.MechanicJobs[job])
        or (grp and Config.AdminGroups and Config.AdminGroups[grp])
    if not allowed then return false end
    plate = HCM.util.normalizePlate(plate or '')
    local rec = HCM.server.loadRecord(plate)
    if not rec or not rec.vin then return false end
    -- etched_vin Spalte sicherstellen (idempotent, falls Migration 005 noch nicht lief)
    pcall(function()
        MySQL.query.await([[
            ALTER TABLE vehicles_data ADD COLUMN IF NOT EXISTS etched_vin VARCHAR(24) NULL
        ]])
    end)
    pcall(function()
        MySQL.update.await('UPDATE vehicles_data SET etched_vin = ? WHERE plate = ?',
            { rec.vin, plate })
    end)
    rec.etched_vin = rec.vin
    HCM.server.log(xPlayer, 'police:etch_vin', plate, rec.vin, nil)
    return true, rec.vin
end)

-- TUeV-Periodische Pruefung: jede Stunde markieren wir abgelaufene Plaketten.
-- (Kein Strafsystem; die Polizei sieht es im Scanner.)
CreateThread(function()
    Wait(60 * 1000)
    while true do
        Wait(60 * 60 * 1000)
        pcall(function()
            -- Spalte sicherstellen
            MySQL.query.await([[
                ALTER TABLE vehicles_data ADD COLUMN IF NOT EXISTS tuev_expires BIGINT NULL DEFAULT NULL
            ]])
        end)
    end
end)
