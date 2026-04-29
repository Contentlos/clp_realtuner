-- =============================================================================
--  clp_realtuner - Werkstatt-Wirtschaft (Batch 7)
--   - Workshops (owner, bank, tool_tier, coords)
--   - Employees mit Perms
--   - Stock mit min_stock (Nachbestellung)
--   - Preise pro Service
--   - Bank (Einnahmen/Auszahlungen)
--   - Rechnungen, Trinkgeld, Rating
-- =============================================================================

local ESX = exports['es_extended']:getSharedObject()

local function getIdent(xPlayer)
    return xPlayer.identifier or (xPlayer.getIdentifier and xPlayer.getIdentifier()) or nil
end

local function isAdmin(xPlayer)
    return HCM.util.isAdmin(xPlayer)
end

local function loadWorkshop(id)
    local row
    pcall(function()
        row = MySQL.single.await('SELECT * FROM mechanic_workshops WHERE id = ?', { tonumber(id) })
    end)
    if not row then return nil end
    row.coords = row.coords and json.decode(row.coords) or nil
    row.employees = MySQL.query.await(
        'SELECT identifier, role, perms FROM mechanic_workshop_employees WHERE workshop_id = ?',
        { row.id }) or {}
    for _, e in ipairs(row.employees) do e.perms = e.perms and json.decode(e.perms) or {} end
    row.stock = MySQL.query.await(
        'SELECT item, amount, min_stock FROM mechanic_workshop_stock WHERE workshop_id = ?',
        { row.id }) or {}
    row.prices = MySQL.query.await(
        'SELECT service, price FROM mechanic_workshop_prices WHERE workshop_id = ?',
        { row.id }) or {}
    return row
end

local function isEmployeeOrOwner(xPlayer, id)
    local ident = getIdent(xPlayer); if not ident then return false end
    local ws = loadWorkshop(id); if not ws then return false end
    if ws.owner == ident then return ws, 'owner' end
    for _, e in ipairs(ws.employees) do
        if e.identifier == ident then return ws, e.role or 'employee' end
    end
    return false
end

local function hasWorkshopPerm(xPlayer, id, perm)
    local ws, role = isEmployeeOrOwner(xPlayer, id)
    if not ws then return false, ws end
    if role == 'owner' or role == 'manager' then return true, ws end
    for _, e in ipairs(ws.employees) do
        if e.identifier == getIdent(xPlayer) then
            return e.perms and e.perms[perm] == true, ws
        end
    end
    return false, ws
end

-- Oeffentliche API ----------------------------------------------------------
function HCM.server.getWorkshopByOwner(identifier)
    local row
    pcall(function()
        row = MySQL.single.await('SELECT id FROM mechanic_workshops WHERE owner = ? LIMIT 1', { identifier })
    end)
    return row and loadWorkshop(row.id) or nil
end

-- Expose tool_tier for Install (reduce install-time)
function HCM.server.getWorkshopToolTier(id)
    local ws = loadWorkshop(id); if not ws then return 1 end
    return tonumber(ws.tool_tier) or 1
end

-- Callbacks / Events ---------------------------------------------------------
lib.callback.register('clp_realtuner:workshop:list', function(source)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return {} end
    local rows = {}
    pcall(function()
        rows = MySQL.query.await('SELECT id, name, owner, tool_tier FROM mechanic_workshops ORDER BY name') or {}
    end)
    return rows
end)

lib.callback.register('clp_realtuner:workshop:get', function(source, id)
    return loadWorkshop(id)
end)

lib.callback.register('clp_realtuner:workshop:buy', function(source, id)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return false, 'no player' end
    local ws = loadWorkshop(id); if not ws then return false, 'no workshop' end
    if ws.owner and ws.owner ~= '' then return false, 'Bereits verkauft.' end
    -- Preis ist server-authoritativ (ehemals vom Client uebergeben -> Exploit).
    local cost = tonumber(Config.WorkshopBuyPrice) or 500000
    if xPlayer.getMoney() < cost and xPlayer.getAccount('bank').money < cost then
        return false, 'Nicht genuegend Geld (' .. cost .. ')'
    end
    -- Atomarer Claim: UPDATE ... WHERE owner IS NULL OR owner = '' -> genau ein Gewinner.
    -- Geld wird erst abgebucht, wenn der Claim wirklich durchgegangen ist (TOCTOU-safe).
    local ident = getIdent(xPlayer)
    local affected
    local ok = pcall(function()
        affected = MySQL.update.await([[
            UPDATE mechanic_workshops
               SET owner = ?, updated_at = ?
             WHERE id = ? AND (owner IS NULL OR owner = '')
        ]], { ident, os.time(), id })
    end)
    if not ok or (tonumber(affected) or 0) < 1 then
        return false, 'Werkstatt wurde gerade von jemand anderem gekauft.'
    end
    if xPlayer.getAccount('bank').money >= cost then
        xPlayer.removeAccountMoney('bank', cost)
    else
        xPlayer.removeMoney(cost)
    end
    HCM.server.log(xPlayer, 'workshop:buy', nil, nil, { id = id, cost = cost })
    return true, 'Werkstatt gekauft fuer $' .. cost
end)

lib.callback.register('clp_realtuner:workshop:hireEmployee', function(source, id, targetId, role)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return false end
    local ws, workshopRole = isEmployeeOrOwner(xPlayer, id)
    if not ws or (workshopRole ~= 'owner' and workshopRole ~= 'manager') then
        return false, 'Keine Berechtigung.'
    end
    local target = ESX.GetPlayerFromId(tonumber(targetId))
    if not target then return false, 'Spieler nicht online.' end
    role = role or 'employee'
    pcall(function()
        MySQL.insert.await([[
            INSERT INTO mechanic_workshop_employees (workshop_id, identifier, role, perms)
            VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE role = VALUES(role)
        ]], { id, getIdent(target), role, json.encode({ install = true, service = true }) })
    end)
    HCM.server.log(xPlayer, 'workshop:hire', nil, nil, { id = id, target = getIdent(target), role = role })
    TriggerClientEvent('ox_lib:notify', target.source, { title = 'Werkstatt', description = 'Du wurdest als ' .. role .. ' eingestellt.', type = 'success' })
    return true
end)

lib.callback.register('clp_realtuner:workshop:fire', function(source, id, identifier)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return false end
    local ws, role = isEmployeeOrOwner(xPlayer, id)
    if not ws or (role ~= 'owner' and role ~= 'manager') then return false end
    pcall(function()
        MySQL.update.await('DELETE FROM mechanic_workshop_employees WHERE workshop_id = ? AND identifier = ?',
            { id, identifier })
    end)
    HCM.server.log(xPlayer, 'workshop:fire', nil, nil, { id = id, target = identifier })
    return true
end)

lib.callback.register('clp_realtuner:workshop:setPerms', function(source, id, identifier, perms)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return false end
    local ws, role = isEmployeeOrOwner(xPlayer, id)
    if not ws or (role ~= 'owner' and role ~= 'manager') then return false end
    pcall(function()
        MySQL.update.await('UPDATE mechanic_workshop_employees SET perms = ? WHERE workshop_id = ? AND identifier = ?',
            { json.encode(perms or {}), id, identifier })
    end)
    return true
end)

lib.callback.register('clp_realtuner:workshop:setPrice', function(source, id, service, price)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return false end
    local ok = hasWorkshopPerm(xPlayer, id, 'prices')
    local ws, role = isEmployeeOrOwner(xPlayer, id)
    if not (ok or role == 'owner' or role == 'manager') then return false end
    pcall(function()
        MySQL.insert.await([[
            INSERT INTO mechanic_workshop_prices (workshop_id, service, price) VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE price = VALUES(price)
        ]], { id, service, tonumber(price) or 0 })
    end)
    HCM.server.log(xPlayer, 'workshop:price', nil, nil, { id = id, service = service, price = price })
    return true
end)

lib.callback.register('clp_realtuner:workshop:orderStock', function(source, id, item, amount, unitCost)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return false end
    local ws, role = isEmployeeOrOwner(xPlayer, id)
    if not ws or (role ~= 'owner' and role ~= 'manager') then return false, 'Keine Berechtigung' end
    amount = math.max(1, tonumber(amount) or 1)
    local cost = (tonumber(unitCost) or 100) * amount
    if (ws.bank or 0) < cost then
        return false, 'Werkstattkonto hat nicht genug Geld'
    end
    pcall(function()
        MySQL.update.await('UPDATE mechanic_workshops SET bank = bank - ?, updated_at = ? WHERE id = ?',
            { cost, os.time(), id })
        MySQL.insert.await([[
            INSERT INTO mechanic_workshop_stock (workshop_id, item, amount, min_stock)
            VALUES (?, ?, ?, 0)
            ON DUPLICATE KEY UPDATE amount = amount + VALUES(amount)
        ]], { id, item, amount })
    end)
    HCM.server.log(xPlayer, 'workshop:order', nil, nil, { id = id, item = item, amount = amount, cost = cost })
    return true, ('Bestellung: %dx %s für $%d'):format(amount, item, cost)
end)

lib.callback.register('clp_realtuner:workshop:withdraw', function(source, id, amount)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return false end
    local ws, role = isEmployeeOrOwner(xPlayer, id)
    if not ws or role ~= 'owner' then return false, 'Nur Besitzer' end
    amount = tonumber(amount) or 0
    if amount <= 0 or (ws.bank or 0) < amount then return false, 'Nicht genug Guthaben' end
    pcall(function()
        MySQL.update.await('UPDATE mechanic_workshops SET bank = bank - ? WHERE id = ?', { amount, id })
    end)
    xPlayer.addAccountMoney('bank', amount)
    HCM.server.log(xPlayer, 'workshop:withdraw', nil, nil, { id = id, amount = amount })
    return true
end)

-- Rechnung + Trinkgeld + Rating
RegisterNetEvent('clp_realtuner:workshop:invoice', function(id, plate, services, customerId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src); if not xPlayer then return end
    local ws, role = isEmployeeOrOwner(xPlayer, id)
    if not ws then return end
    local total = 0
    for _, s in ipairs(services or {}) do total = total + (tonumber(s.price) or 0) end
    if total <= 0 then return end
    local customer = tonumber(customerId) and ESX.GetPlayerFromId(tonumber(customerId)) or nil
    if not customer then
        return TriggerClientEvent('ox_lib:notify', src, { title = 'Rechnung', description = 'Kunde nicht erreichbar', type = 'error' })
    end
    local bankMoney = customer.getAccount('bank').money
    local cashMoney = customer.getMoney()
    if bankMoney + cashMoney < total then
        return TriggerClientEvent('ox_lib:notify', src, { title = 'Rechnung', description = 'Kunde kann nicht zahlen (' .. total .. ')', type = 'error' })
    end
    if bankMoney >= total then customer.removeAccountMoney('bank', total)
    else customer.removeMoney(total) end
    pcall(function()
        MySQL.update.await('UPDATE mechanic_workshops SET bank = bank + ? WHERE id = ?', { total, id })
    end)
    HCM.server.log(xPlayer, 'workshop:invoice', plate, nil, { id = id, services = services, total = total, customer = getIdent(customer) })
    TriggerClientEvent('ox_lib:notify', src, { title = 'Rechnung', description = ('$%d abgerechnet'):format(total), type = 'success' })
    TriggerClientEvent('ox_lib:notify', customer.source, { title = 'Rechnung', description = ('Du hast $%d an die Werkstatt gezahlt.'):format(total), type = 'inform' })
    TriggerClientEvent('clp_realtuner:workshop:promptTip', customer.source, id, xPlayer.source, total)
end)

RegisterNetEvent('clp_realtuner:workshop:tip', function(id, mechanicServerId, amount)
    local src = source
    local customer = ESX.GetPlayerFromId(src); if not customer then return end
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if amount == 0 then return end
    if customer.getMoney() < amount then return end
    customer.removeMoney(amount)
    local mechanic = ESX.GetPlayerFromId(tonumber(mechanicServerId) or -1)
    if mechanic then mechanic.addMoney(amount) end
    pcall(function()
        MySQL.update.await('UPDATE mechanic_customer_jobs SET tip = tip + ? WHERE workshop_id = ? ORDER BY id DESC LIMIT 1',
            { amount, id })
    end)
    HCM.server.log(customer, 'workshop:tip', nil, nil, { id = id, amount = amount, mechanic = getIdent(mechanic or {}) })
    if mechanic then
        TriggerClientEvent('ox_lib:notify', mechanic.source, { title = 'Trinkgeld', description = ('$%d erhalten'):format(amount), type = 'success' })
    end
end)

RegisterNetEvent('clp_realtuner:workshop:rate', function(jobId, rating)
    local src = source
    local customer = ESX.GetPlayerFromId(src); if not customer then return end
    rating = math.max(1, math.min(5, tonumber(rating) or 0))
    pcall(function()
        MySQL.update.await('UPDATE mechanic_customer_jobs SET rating = ? WHERE id = ?', { rating, tonumber(jobId) or 0 })
    end)
end)

-- Admin/Dashboard
lib.callback.register('clp_realtuner:workshop:dashboard', function(source)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return {} end
    if not isAdmin(xPlayer) then return {} end
    local rows = {}
    pcall(function()
        rows = MySQL.query.await([[
            SELECT w.id, w.name, w.owner, w.bank, w.tool_tier,
                   (SELECT COUNT(*) FROM mechanic_workshop_employees e WHERE e.workshop_id = w.id) AS employees,
                   (SELECT COUNT(*) FROM mechanic_workshop_stock s WHERE s.workshop_id = w.id) AS stock_types
              FROM mechanic_workshops w
             ORDER BY w.bank DESC
        ]]) or {}
    end)
    return rows
end)
