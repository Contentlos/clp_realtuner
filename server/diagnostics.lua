-- =============================================================================
--  clp_realtuner - Server Diagnose (Batch 2)
-- =============================================================================

local ESX = exports['es_extended']:getSharedObject()

local function isMechOrAdmin(xPlayer)
    if not xPlayer then return false end
    if Config.AllowOutsideJob then return true end
    local job = xPlayer.job and xPlayer.job.name
    if job and Config.MechanicJobs and Config.MechanicJobs[job] then return true end
    if HCM.util.isAdmin(xPlayer) then return true end
    return false
end

RegisterNetEvent('clp_realtuner:diag:logBrakeStand', function(report)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or type(report) ~= 'table' then return end
    if not isMechOrAdmin(xPlayer) then return end
    HCM.server.log(xPlayer, 'diag:brake_stand', report.plate, nil, report)
end)

RegisterNetEvent('clp_realtuner:diag:tuevPass', function(plate)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not plate then return end
    -- Nur Mechaniker / Admin duerfen TUeV freigeben, sonst kann jeder Spieler
    -- sich selbst seine TUeV-Plakette erneuern.
    if not isMechOrAdmin(xPlayer) then return end
    plate = HCM.util.normalizePlate(plate)
    local days = (Config.TUeV and Config.TUeV.ValidDays) or Config.TUeVValidDays or 365
    local expires = os.time() + days * 86400
    pcall(function()
        MySQL.update.await(
            'UPDATE vehicles_data SET tuev_expires = ? WHERE plate = ?',
            { expires, plate }
        )
    end)
    local rec = HCM.server.getRecord and HCM.server.getRecord(plate) or nil
    if rec then rec.tuev_expires = expires end
    HCM.server.log(xPlayer, 'diag:tuev_pass', plate, nil, { expires = expires })
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'TUeV bestanden',
        description = ('Gueltig bis %s'):format(os.date('%d.%m.%Y', expires)),
        type = 'success',
    })
end)

-- Admin callback: TUeV manuell setzen/zuruecksetzen
-- Config.AdminGroups ist ein Dictionary { admin = true, ... } – also Key-Lookup.
lib.callback.register('clp_realtuner:diag:setTUeV', function(source, plate, expires)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    if not HCM.util.isAdmin(xPlayer) then return false end
    plate = HCM.util.normalizePlate(plate)
    pcall(function()
        MySQL.update.await('UPDATE vehicles_data SET tuev_expires = ? WHERE plate = ?',
            { tonumber(expires) or 0, plate })
    end)
    HCM.server.log(xPlayer, 'admin:set_tuev', plate, nil, { expires = expires })
    return true
end)
