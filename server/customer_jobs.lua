-- =============================================================================
--  clp_realtuner - Kunden-Auftraege (Batch 8)
--   - Kosten-Voranschlag mit Bestaetigung
--   - Abhol-Service
--   - Bewertung
--   - Notfall-Anrufe
-- =============================================================================

local ESX = exports['es_extended']:getSharedObject()

local function getIdent(xPlayer)
    return xPlayer.identifier or (xPlayer.getIdentifier and xPlayer.getIdentifier()) or nil
end

local function notify(src, title, desc, kind)
    TriggerClientEvent('ox_lib:notify', src, { title = title, description = desc, type = kind or 'inform' })
end

-- Problem-Generator fuer NPC-Auftraege (basiert auf echtem Fahrzeug-Zustand)
local PROBLEM_TEMPLATES = {
    { tag = 'engine_warning',   text = 'Motorlampe leuchtet seit gestern, Leistung weg.' },
    { tag = 'brakes_weak',      text = 'Bremse quietscht und wirkt schwach.' },
    { tag = 'oil_dark',         text = 'Oel ist rabenschwarz, letzte Wartung Monate her.' },
    { tag = 'coolant_low',      text = 'Kuehlmittel verschwindet staendig.' },
    { tag = 'no_start',         text = 'Springt nicht zuverlaessig an, Batterie?' },
    { tag = 'turbo_whistle',    text = 'Turbo pfeift anders als sonst.' },
    { tag = 'gearbox_slip',     text = 'Getriebe rutscht im 3. Gang.' },
    { tag = 'suspension_bump',  text = 'Fahrwerk klopft bei Bodenwellen.' },
    { tag = 'emissions_fail',   text = 'Fehlermeldung Abgas, TUeV laeuft ab.' },
    { tag = 'windshield_chip',  text = 'Steinschlag in der Windschutzscheibe.' },
}

-- Kosten-Voranschlag erzeugen
function HCM.server.createJob(plate, vin, customer_ident, problem, quote, workshop_id)
    local id
    pcall(function()
        id = MySQL.insert.await([[
            INSERT INTO mechanic_customer_jobs
                (workshop_id, plate, vin, customer, problem, quote, status, created_at)
            VALUES (?, ?, ?, ?, ?, ?, 'open', ?)
        ]], { workshop_id, plate, vin, customer_ident, problem, quote or 0, os.time() })
    end)
    return id
end

lib.callback.register('clp_realtuner:jobs:list', function(source, status, limit)
    local rows = {}
    pcall(function()
        rows = MySQL.query.await([[
            SELECT id, workshop_id, plate, vin, customer, problem, quote, status, assigned, rating, tip, created_at, closed_at
              FROM mechanic_customer_jobs
             WHERE status = COALESCE(?, status)
             ORDER BY created_at DESC LIMIT ?
        ]], { status, tonumber(limit) or 50 }) or {}
    end)
    return rows
end)

lib.callback.register('clp_realtuner:jobs:createEmergency', function(source, problemText)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return false end
    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local vehicle = GetVehiclePedIsIn(ped, false)
    local plate = vehicle ~= 0 and GetVehicleNumberPlateText(vehicle) or 'EMERGENCY'
    plate = (plate or ''):gsub('%s+', '')
    local id
    pcall(function()
        id = MySQL.insert.await([[
            INSERT INTO mechanic_customer_jobs
                (workshop_id, plate, vin, customer, problem, quote, status, created_at)
            VALUES (NULL, ?, NULL, ?, ?, 0, 'emergency', ?)
        ]], { plate, getIdent(xPlayer), ('[Notfall bei %.0f/%.0f] %s'):format(coords.x, coords.y, problemText or 'Panne'), os.time() })
    end)
    -- Broadcast an alle Mechaniker/Tuning-Job-Spieler
    local players = ESX.GetExtendedPlayers()
    for _, p in pairs(players) do
        local j = p.getJob and p.getJob() or { name = 'unknown' }
        -- Config.MechanicJobs ist ein Hash ({ mechanic = true, ... }); Lookup per Key.
        if Config.MechanicJobs and Config.MechanicJobs[j.name] then
            notify(p.source, 'Notfall-Dispatch', ('%s braucht Hilfe: %s'):format(xPlayer.getName and xPlayer.getName() or 'Spieler', problemText or 'Panne'), 'error')
            TriggerClientEvent('clp_realtuner:jobs:newEmergency', p.source, {
                id = id, plate = plate, coords = { x = coords.x, y = coords.y, z = coords.z },
                customer_id = source, problem = problemText or 'Panne',
            })
        end
    end
    return id ~= nil, id
end)

lib.callback.register('clp_realtuner:jobs:assign', function(source, jobId)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return false end
    pcall(function()
        MySQL.update.await('UPDATE mechanic_customer_jobs SET assigned = ?, status = ? WHERE id = ? AND status IN (?, ?)',
            { getIdent(xPlayer), 'assigned', tonumber(jobId) or 0, 'open', 'emergency' })
    end)
    HCM.server.log(xPlayer, 'job:assign', nil, nil, { id = jobId })
    return true
end)

lib.callback.register('clp_realtuner:jobs:setQuote', function(source, jobId, amount)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return false end
    pcall(function()
        MySQL.update.await('UPDATE mechanic_customer_jobs SET quote = ? WHERE id = ? AND assigned = ?',
            { tonumber(amount) or 0, tonumber(jobId) or 0, getIdent(xPlayer) })
    end)
    -- Kunde fragen
    local row
    pcall(function()
        row = MySQL.single.await('SELECT customer, plate FROM mechanic_customer_jobs WHERE id = ?', { jobId })
    end)
    if row then
        local customer = ESX.GetPlayerFromIdentifier(row.customer)
        if customer then
            TriggerClientEvent('clp_realtuner:jobs:quotePrompt', customer.source, jobId, row.plate, amount, source)
        end
    end
    return true
end)

RegisterNetEvent('clp_realtuner:jobs:quoteAnswer', function(jobId, accepted, mechanicSrc)
    local src = source
    local customer = ESX.GetPlayerFromId(src); if not customer then return end
    local status = accepted and 'quoted_accepted' or 'quoted_rejected'
    pcall(function()
        MySQL.update.await('UPDATE mechanic_customer_jobs SET status = ? WHERE id = ? AND customer = ?',
            { status, tonumber(jobId) or 0, getIdent(customer) })
    end)
    local mechanic = ESX.GetPlayerFromId(tonumber(mechanicSrc) or -1)
    if mechanic then
        notify(mechanic.source, 'Voranschlag',
            accepted and 'Kunde hat akzeptiert.' or 'Kunde hat abgelehnt.',
            accepted and 'success' or 'error')
    end
end)

lib.callback.register('clp_realtuner:jobs:complete', function(source, jobId)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return false end
    local row
    pcall(function()
        row = MySQL.single.await('SELECT * FROM mechanic_customer_jobs WHERE id = ?', { jobId })
    end)
    if not row then return false, 'Auftrag nicht gefunden' end
    if row.assigned ~= getIdent(xPlayer) then return false, 'Du bist nicht zugewiesen' end
    local total = tonumber(row.quote) or 0
    -- Kunden abbuchen (falls online)
    local customer = ESX.GetPlayerFromIdentifier(row.customer)
    if customer and total > 0 then
        if customer.getAccount('bank').money >= total then customer.removeAccountMoney('bank', total)
        elseif customer.getMoney() >= total then customer.removeMoney(total)
        else return false, 'Kunde kann nicht zahlen' end
        if row.workshop_id and row.workshop_id ~= 0 then
            pcall(function()
                MySQL.update.await('UPDATE mechanic_workshops SET bank = bank + ? WHERE id = ?', { total, row.workshop_id })
            end)
        else
            xPlayer.addMoney(total)
        end
    end
    pcall(function()
        MySQL.update.await('UPDATE mechanic_customer_jobs SET status = ?, closed_at = ? WHERE id = ?',
            { 'closed', os.time(), jobId })
    end)
    -- Bewertungs-Prompt
    if customer then
        TriggerClientEvent('clp_realtuner:jobs:ratePrompt', customer.source, jobId, xPlayer.source)
    end
    HCM.server.log(xPlayer, 'job:complete', row.plate, row.vin, { id = jobId, total = total })
    return true, ('Auftrag abgeschlossen ($%d abgerechnet)'):format(total)
end)

-- Abhol-Service: Mechaniker-Dispatch-Request vom Kunden
RegisterNetEvent('clp_realtuner:jobs:requestPickup', function(problemText)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src); if not xPlayer then return end
    local ped = GetPlayerPed(src); local coords = GetEntityCoords(ped)
    local vehicle = GetVehiclePedIsIn(ped, false)
    local plate = vehicle ~= 0 and GetVehicleNumberPlateText(vehicle) or ''
    plate = (plate or ''):gsub('%s+', '')
    pcall(function()
        MySQL.insert.await([[
            INSERT INTO mechanic_customer_jobs
                (workshop_id, plate, customer, problem, status, created_at)
            VALUES (NULL, ?, ?, ?, 'pickup', ?)
        ]], { plate, getIdent(xPlayer), ('[Abhol @ %.0f/%.0f] %s'):format(coords.x, coords.y, problemText or 'Abhol-Service'), os.time() })
    end)
    -- Broadcast (Config.MechanicJobs ist ein Hash, per Key-Lookup pruefen)
    local players = ESX.GetExtendedPlayers()
    for _, p in pairs(players) do
        local j = p.getJob and p.getJob() or { name = 'unknown' }
        if Config.MechanicJobs and Config.MechanicJobs[j.name] then
            notify(p.source, 'Abhol-Auftrag', ('Kunde braucht Abholung bei %.0f/%.0f'):format(coords.x, coords.y), 'inform')
            TriggerClientEvent('clp_realtuner:jobs:newPickup', p.source, {
                plate = plate, coords = { x = coords.x, y = coords.y, z = coords.z },
                customer_id = src, problem = problemText or 'Abhol-Service',
            })
        end
    end
end)

-- Bewertung
RegisterNetEvent('clp_realtuner:jobs:rate', function(jobId, rating, tipAmount)
    local src = source
    local customer = ESX.GetPlayerFromId(src); if not customer then return end
    rating = math.max(1, math.min(5, tonumber(rating) or 0))
    pcall(function()
        MySQL.update.await('UPDATE mechanic_customer_jobs SET rating = ?, tip = ? WHERE id = ? AND customer = ?',
            { rating, tonumber(tipAmount) or 0, tonumber(jobId) or 0, getIdent(customer) })
    end)
    if (tonumber(tipAmount) or 0) > 0 and customer.getMoney() >= tonumber(tipAmount) then
        customer.removeMoney(tonumber(tipAmount))
        -- Trinkgeld an zugewiesenen Mechaniker
        local row
        pcall(function()
            row = MySQL.single.await('SELECT assigned FROM mechanic_customer_jobs WHERE id = ?', { jobId })
        end)
        if row and row.assigned then
            local mech = ESX.GetPlayerFromIdentifier(row.assigned)
            if mech then mech.addMoney(tonumber(tipAmount)) end
        end
    end
end)

-- NPC-Auftrags-Generator (server-seitig, alle 10 min ein neuer Auftrag an Werkstatt 1)
CreateThread(function()
    Wait(30000)
    while true do
        Wait(600000) -- 10 min
        local tmpl = PROBLEM_TEMPLATES[math.random(#PROBLEM_TEMPLATES)]
        pcall(function()
            MySQL.insert.await([[
                INSERT INTO mechanic_customer_jobs
                    (workshop_id, plate, customer, problem, quote, status, created_at)
                VALUES (?, ?, NULL, ?, ?, 'open', ?)
            ]], {
                1,
                ('NPC%04d'):format(math.random(9999)),
                ('[NPC:%s] %s'):format(tmpl.tag, tmpl.text),
                math.random(600, 3500),
                os.time(),
            })
        end)
    end
end)
