-- =============================================================================
--  clp_realtuner - Server Diagnose (Batch 2)
-- =============================================================================

local ESX = exports['es_extended']:getSharedObject()

RegisterNetEvent('clp_realtuner:diag:logBrakeStand', function(report)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or type(report) ~= 'table' then return end
    HCM.server.log(xPlayer, 'diag:brake_stand', report.plate, nil, report)
end)

RegisterNetEvent('clp_realtuner:diag:tuevPass', function(plate)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not plate then return end
    plate = HCM.util.normalizePlate(plate)
    local days = (Config.TUeV and Config.TUeV.ValidDays) or 365
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
lib.callback.register('clp_realtuner:diag:setTUeV', function(source, plate, expires)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    local grp = xPlayer.getGroup and xPlayer.getGroup() or 'user'
    local ok = false
    for _, allowed in ipairs(Config.AdminGroups or { 'admin' }) do
        if grp == allowed then ok = true break end
    end
    if not ok then return false end
    plate = HCM.util.normalizePlate(plate)
    pcall(function()
        MySQL.update.await('UPDATE vehicles_data SET tuev_expires = ? WHERE plate = ?',
            { tonumber(expires) or 0, plate })
    end)
    HCM.server.log(xPlayer, 'admin:set_tuev', plate, nil, { expires = expires })
    return true
end)
