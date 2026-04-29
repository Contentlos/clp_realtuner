-- =============================================================================
--  clp_realtuner - Werkstatt-PC + Storage + Bestellsystem (Batch 14b)
--
--  Endpunkte:
--    wspc:status     -> { workshop, stock={parts={...}, body=...}, orders, capacities, prices, bank }
--    wspc:catalog    -> bestellbare Items (Parts + Verbrauchsstoffe + Lacke), gruppiert
--    wspc:order      -> erstellt Bestellung (Geld vom Werkstattkonto, Lieferzeit Config.OrderDelayMin..Max)
--    wspc:cancel     -> storniert pending Order (refund)
--    wspc:withdraw   -> Bargeld vom Bank holen
--    wspc:depositCash-> Cash -> Workshop-Bank
--    wspc:setPrice   -> Service-Preis editieren
--    wspc:setMinStock-> Mindestbestand fuer Auto-Replenish (Hinweis im UI)
--    wspc:takeStock  -> Item aus Lager in Spieler-Inventar (fuer Einbau)
--    wspc:returnStock-> Item zurueck ins Lager (z.B. nach Ausbau)
--
--  Lieferungs-Tick: alle 30s wird gepollt; pending Bestellungen mit
--  delivers_at <= now() werden ins Lager gebucht (sofern Kapazitaet reicht;
--  andernfalls bleibt die Order 'overflow' und blinkt im UI).
-- =============================================================================

local ESX = exports['es_extended']:getSharedObject()
local ox  = exports.ox_inventory

local function getIdent(xPlayer)
    return xPlayer.identifier or (xPlayer.getIdentifier and xPlayer.getIdentifier()) or nil
end

local function isAdmin(xPlayer)
    if not xPlayer then return false end
    local grp = xPlayer.getGroup and xPlayer.getGroup() or 'user'
    return grp and Config.AdminGroups and Config.AdminGroups[grp] or false
end

-- Membership-Check: Owner / Manager / Mitarbeiter
local function membership(xPlayer, workshopId)
    local ident = getIdent(xPlayer); if not ident then return nil end
    local row
    pcall(function()
        row = MySQL.single.await('SELECT owner FROM mechanic_workshops WHERE id = ?', { tonumber(workshopId) })
    end)
    if not row then return nil end
    if row.owner == ident then return 'owner' end
    local emp
    pcall(function()
        emp = MySQL.single.await('SELECT role FROM mechanic_workshop_employees WHERE workshop_id = ? AND identifier = ?',
            { workshopId, ident })
    end)
    if emp and emp.role then return emp.role end
    if isAdmin(xPlayer) then return 'admin' end
    return nil
end

local function canManage(role)
    return role == 'owner' or role == 'manager' or role == 'admin'
end

-- ============================================================================
--  Status / Catalog
-- ============================================================================
local function fullStatus(workshopId)
    workshopId = tonumber(workshopId); if not workshopId then return nil end
    local row
    pcall(function()
        row = MySQL.single.await([[
            SELECT id, name, owner, bank, tool_tier,
                   cap_parts, cap_body, cap_paint, cap_fluids
              FROM mechanic_workshops WHERE id = ?
        ]], { workshopId })
    end)
    if not row then return nil end
    local stock = {}
    for _, c in ipairs(HCM.categories) do stock[c] = {} end
    pcall(function()
        local rows = MySQL.query.await(
            'SELECT item, amount, min_stock, category FROM mechanic_workshop_stock WHERE workshop_id = ?',
            { workshopId }) or {}
        for _, s in ipairs(rows) do
            local cat = (s.category and s.category ~= '') and s.category or HCM.itemCategory(s.item)
            stock[cat] = stock[cat] or {}
            stock[cat][#stock[cat]+1] = {
                item = s.item, amount = tonumber(s.amount) or 0,
                minStock = tonumber(s.min_stock) or 0, category = cat,
            }
        end
    end)
    local orders = {}
    pcall(function()
        orders = MySQL.query.await([[
            SELECT id, item, category, amount, unit_cost, total_cost,
                   ordered_by, ordered_at, delivers_at, delivered_at, status
              FROM mechanic_workshop_orders
             WHERE workshop_id = ?
             ORDER BY id DESC LIMIT 100
        ]], { workshopId }) or {}
    end)
    local prices = {}
    pcall(function()
        prices = MySQL.query.await(
            'SELECT service, price FROM mechanic_workshop_prices WHERE workshop_id = ?',
            { workshopId }) or {}
    end)
    return {
        workshop = {
            id = row.id, name = row.name, owner = row.owner,
            bank = tonumber(row.bank) or 0, toolTier = tonumber(row.tool_tier) or 1,
        },
        capacities = {
            parts  = tonumber(row.cap_parts)  or 80,
            body   = tonumber(row.cap_body)   or 50,
            paint  = tonumber(row.cap_paint)  or 40,
            fluids = tonumber(row.cap_fluids) or 60,
        },
        stock = stock,
        orders = orders,
        prices = prices,
        now = os.time(),
    }
end

local function catalog()
    local out = { parts = {}, body = {}, paint = {}, fluids = {} }
    -- Parts (alle bekannten)
    if Parts then
        for itemName, def in pairs(Parts) do
            local cat = HCM.itemCategory(itemName)
            out[cat] = out[cat] or {}
            out[cat][#out[cat]+1] = {
                item = itemName, label = def.label or itemName,
                quality = def.quality or 1, unitCost = HCM.defaultUnitCost(itemName),
                category = cat,
            }
        end
    end
    -- Festeintraege fuer Lager-relevante Verbrauchsstoffe + Lacke
    local fixedItems = {
        { item='motor_oil',         label='Motoröl (5L Kanister)' },
        { item='brake_fluid',       label='Bremsflüssigkeit' },
        { item='coolant',           label='Kühlmittel' },
        { item='spark_plug',        label='Zündkerze' },
        { item='headlight_bulb',    label='Scheinwerfer-Birne' },
        { item='rearlight_bulb',    label='Rücklicht-Birne' },
        { item='battery',           label='Autobatterie' },
        { item='windshield_repair', label='Scheibenreparatur-Set' },
        { item='rust_remover',      label='Rostentferner' },
        { item='paint_primer',      label='Grundierung' },
        { item='paint_can',         label='Lackdose (Standard)' },
        { item='paint_can_metallic',label='Lackdose (Metallic)' },
        { item='paint_can_pearl',   label='Lackdose (Pearl)' },
        { item='paint_can_matt',    label='Lackdose (Matt)' },
        { item='paint_clearcoat',   label='Klarlack' },
        { item='paint_thinner',     label='Verdünner' },
    }
    for _, e in ipairs(fixedItems) do
        local cat = HCM.itemCategory(e.item)
        out[cat] = out[cat] or {}
        -- Skip wenn das item auch in Parts vorhanden waere (kein Duplikat).
        local exists = false
        for _, x in ipairs(out[cat]) do if x.item == e.item then exists = true; break end end
        if not exists then
            out[cat][#out[cat]+1] = {
                item = e.item, label = e.label, quality = 1,
                unitCost = HCM.defaultUnitCost(e.item), category = cat,
            }
        end
    end
    -- Sortieren je Kategorie alphabetisch
    for _, list in pairs(out) do
        table.sort(list, function(a, b) return a.label < b.label end)
    end
    return out
end

-- Capacity-Check (sum amount per category vs cap)
local function categoryUsage(workshopId, category)
    local row
    pcall(function()
        row = MySQL.single.await([[
            SELECT COALESCE(SUM(amount), 0) AS sum
              FROM mechanic_workshop_stock
             WHERE workshop_id = ? AND category = ?
        ]], { workshopId, category })
    end)
    return row and tonumber(row.sum) or 0
end

local function categoryCap(workshopId, category)
    local row
    pcall(function()
        row = MySQL.single.await([[
            SELECT cap_parts, cap_body, cap_paint, cap_fluids
              FROM mechanic_workshops WHERE id = ?
        ]], { workshopId })
    end)
    if not row then return 50 end
    if category == 'parts'  then return tonumber(row.cap_parts)  or 80 end
    if category == 'body'   then return tonumber(row.cap_body)   or 50 end
    if category == 'paint'  then return tonumber(row.cap_paint)  or 40 end
    if category == 'fluids' then return tonumber(row.cap_fluids) or 60 end
    return 50
end

-- ============================================================================
--  Callbacks
-- ============================================================================
lib.callback.register('clp_realtuner:wspc:status', function(source, workshopId)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return nil end
    if not membership(xPlayer, workshopId) then return nil end
    return fullStatus(workshopId)
end)

lib.callback.register('clp_realtuner:wspc:catalog', function(source, workshopId)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return nil end
    if not membership(xPlayer, workshopId) then return nil end
    return catalog()
end)

lib.callback.register('clp_realtuner:wspc:order', function(source, workshopId, item, amount)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return false, 'no_player' end
    local role = membership(xPlayer, workshopId)
    if not canManage(role) then return false, 'Keine Berechtigung (Owner/Manager).' end
    workshopId = tonumber(workshopId); item = tostring(item or '')
    amount = math.max(1, math.min(50, tonumber(amount) or 1))
    if item == '' then return false, 'Kein Item.' end
    local cat = HCM.itemCategory(item)
    local unitCost = HCM.defaultUnitCost(item)
    local total = unitCost * amount
    -- Bank-Pruefung + atomarer Abzug
    local row
    pcall(function() row = MySQL.single.await('SELECT bank FROM mechanic_workshops WHERE id = ?', { workshopId }) end)
    if not row or (tonumber(row.bank) or 0) < total then
        return false, 'Werkstattkonto nicht ausreichend ($' .. total .. ').'
    end
    local affected
    pcall(function()
        affected = MySQL.update.await([[
            UPDATE mechanic_workshops
               SET bank = bank - ?, updated_at = ?
             WHERE id = ? AND bank >= ?
        ]], { total, os.time(), workshopId, total })
    end)
    if (tonumber(affected) or 0) < 1 then return false, 'Buchung fehlgeschlagen.' end
    -- Lieferzeit: Config.OrderDelayMin..Max Sekunden (Default 5..15 Minuten)
    local minS = tonumber(Config.OrderDelayMin) or 300
    local maxS = tonumber(Config.OrderDelayMax) or 900
    local eta  = os.time() + math.random(minS, maxS)
    pcall(function()
        MySQL.insert.await([[
            INSERT INTO mechanic_workshop_orders
                (workshop_id, item, category, amount, unit_cost, total_cost,
                 ordered_by, ordered_at, delivers_at, status)
            VALUES (?,?,?,?,?,?,?,?,?,'pending')
        ]], { workshopId, item, cat, amount, unitCost, total,
              getIdent(xPlayer), os.time(), eta })
    end)
    HCM.server.log(xPlayer, 'wspc:order', nil, nil,
        { id = workshopId, item = item, amount = amount, total = total, eta = eta })
    return true, ('Bestellt: %dx %s · ETA %s'):format(amount, item, os.date('%H:%M', eta))
end)

lib.callback.register('clp_realtuner:wspc:cancel', function(source, workshopId, orderId)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return false end
    local role = membership(xPlayer, workshopId)
    if not canManage(role) then return false, 'Keine Berechtigung.' end
    local order
    pcall(function()
        order = MySQL.single.await([[
            SELECT id, total_cost, status FROM mechanic_workshop_orders
             WHERE id = ? AND workshop_id = ?
        ]], { tonumber(orderId), tonumber(workshopId) })
    end)
    if not order then return false, 'Bestellung nicht gefunden.' end
    if order.status ~= 'pending' then return false, 'Bestellung nicht stornierbar.' end
    local affected
    pcall(function()
        affected = MySQL.update.await([[
            UPDATE mechanic_workshop_orders
               SET status = 'cancelled', delivered_at = ?
             WHERE id = ? AND status = 'pending'
        ]], { os.time(), order.id })
    end)
    if (tonumber(affected) or 0) < 1 then return false, 'Race: Bereits geliefert oder storniert.' end
    pcall(function()
        MySQL.update.await(
            'UPDATE mechanic_workshops SET bank = bank + ?, updated_at = ? WHERE id = ?',
            { tonumber(order.total_cost) or 0, os.time(), tonumber(workshopId) })
    end)
    HCM.server.log(xPlayer, 'wspc:cancel', nil, nil, { orderId = order.id })
    return true, 'Bestellung storniert, Betrag erstattet.'
end)

lib.callback.register('clp_realtuner:wspc:withdraw', function(source, workshopId, amount)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return false end
    if membership(xPlayer, workshopId) ~= 'owner' then return false, 'Nur Owner.' end
    amount = tonumber(amount) or 0
    if amount <= 0 then return false, 'Betrag ungueltig.' end
    local affected
    pcall(function()
        affected = MySQL.update.await(
            'UPDATE mechanic_workshops SET bank = bank - ?, updated_at = ? WHERE id = ? AND bank >= ?',
            { amount, os.time(), workshopId, amount })
    end)
    if (tonumber(affected) or 0) < 1 then return false, 'Nicht genug Guthaben.' end
    xPlayer.addAccountMoney('bank', amount)
    HCM.server.log(xPlayer, 'wspc:withdraw', nil, nil, { id = workshopId, amount = amount })
    return true, 'Auszahlung: $' .. amount
end)

lib.callback.register('clp_realtuner:wspc:depositCash', function(source, workshopId, amount)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return false end
    if not membership(xPlayer, workshopId) then return false, 'Kein Mitarbeiter.' end
    amount = tonumber(amount) or 0
    if amount <= 0 then return false end
    if xPlayer.getMoney() < amount then return false, 'Nicht genug Bargeld.' end
    xPlayer.removeMoney(amount)
    local affected = 0
    local dbOk = pcall(function()
        affected = MySQL.update.await(
            'UPDATE mechanic_workshops SET bank = bank + ?, updated_at = ? WHERE id = ?',
            { amount, os.time(), workshopId })
    end)
    if not dbOk or (tonumber(affected) or 0) < 1 then
        xPlayer.addMoney(amount)
        return false, 'Datenbankfehler – Betrag zurueckerstattet.'
    end
    HCM.server.log(xPlayer, 'wspc:deposit', nil, nil, { id = workshopId, amount = amount })
    return true, 'Eingezahlt: $' .. amount
end)

lib.callback.register('clp_realtuner:wspc:setMinStock', function(source, workshopId, item, minStock)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return false end
    if not canManage(membership(xPlayer, workshopId)) then return false end
    pcall(function()
        local cat = HCM.itemCategory(item)
        MySQL.insert.await([[
            INSERT INTO mechanic_workshop_stock (workshop_id, item, amount, min_stock, category)
            VALUES (?, ?, 0, ?, ?)
            ON DUPLICATE KEY UPDATE min_stock = VALUES(min_stock), category = VALUES(category)
        ]], { workshopId, item, math.max(0, math.floor(tonumber(minStock) or 0)), cat })
    end)
    return true
end)

lib.callback.register('clp_realtuner:wspc:setPrice', function(source, workshopId, service, price)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return false end
    if not canManage(membership(xPlayer, workshopId)) then return false end
    pcall(function()
        MySQL.insert.await([[
            INSERT INTO mechanic_workshop_prices (workshop_id, service, price) VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE price = VALUES(price)
        ]], { workshopId, service, math.max(0, math.floor(tonumber(price) or 0)) })
    end)
    return true
end)

-- Item aus Lager in Spieler-Inventar transferieren (fuer Einbau)
lib.callback.register('clp_realtuner:wspc:takeStock', function(source, workshopId, item, amount)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return false end
    if not membership(xPlayer, workshopId) then return false, 'Kein Mitarbeiter.' end
    amount = math.max(1, math.min(20, tonumber(amount) or 1))
    -- Stock atomar dekrementieren
    local affected
    pcall(function()
        affected = MySQL.update.await([[
            UPDATE mechanic_workshop_stock
               SET amount = amount - ?
             WHERE workshop_id = ? AND item = ? AND amount >= ?
        ]], { amount, workshopId, item, amount })
    end)
    if (tonumber(affected) or 0) < 1 then return false, 'Nicht genug im Lager.' end
    local ok = ox:AddItem(source, item, amount)
    if not ok then
        -- Rollback Stock
        pcall(function()
            MySQL.update.await(
                'UPDATE mechanic_workshop_stock SET amount = amount + ? WHERE workshop_id = ? AND item = ?',
                { amount, workshopId, item })
        end)
        return false, 'Inventar voll.'
    end
    HCM.server.log(xPlayer, 'wspc:take', nil, nil, { id = workshopId, item = item, amount = amount })
    return true, ('%dx %s entnommen'):format(amount, item)
end)

lib.callback.register('clp_realtuner:wspc:returnStock', function(source, workshopId, item, amount)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return false end
    if not membership(xPlayer, workshopId) then return false end
    amount = math.max(1, math.min(20, tonumber(amount) or 1))
    -- Capacity check
    local cat = HCM.itemCategory(item)
    local usage = categoryUsage(workshopId, cat)
    local cap   = categoryCap(workshopId, cat)
    if usage + amount > cap then return false, 'Lager voll (' .. cat .. ': ' .. cap .. ').' end
    local count = ox:GetItemCount(source, item)
    if (count or 0) < amount then return false, 'Nicht genug im Inventar.' end
    local ok = ox:RemoveItem(source, item, amount)
    if not ok then return false, 'Inventar-Fehler.' end
    pcall(function()
        MySQL.insert.await([[
            INSERT INTO mechanic_workshop_stock (workshop_id, item, amount, min_stock, category)
            VALUES (?, ?, ?, 0, ?)
            ON DUPLICATE KEY UPDATE amount = amount + VALUES(amount), category = VALUES(category)
        ]], { workshopId, item, amount, cat })
    end)
    HCM.server.log(xPlayer, 'wspc:return', nil, nil, { id = workshopId, item = item, amount = amount })
    return true, ('%dx %s eingelagert'):format(amount, item)
end)

-- ============================================================================
--  Lieferungs-Tick (alle 30 s)
-- ============================================================================
local function processDeliveries()
    local now = os.time()
    local rows = MySQL.query.await([[
        SELECT id, workshop_id, item, category, amount, total_cost
          FROM mechanic_workshop_orders
         WHERE status = 'pending' AND delivers_at <= ?
         ORDER BY id ASC LIMIT 50
    ]], { now }) or {}
    for _, r in ipairs(rows) do
        local cat   = (r.category and r.category ~= '') and r.category or HCM.itemCategory(r.item)
        local usage = categoryUsage(r.workshop_id, cat)
        local cap   = categoryCap(r.workshop_id, cat)
        if usage + (tonumber(r.amount) or 0) > cap then
            -- Lager voll: Order auf 'overflow' setzen, der Operator muss Lager freiraeumen
            pcall(function()
                MySQL.update.await(
                    'UPDATE mechanic_workshop_orders SET status = ?, delivered_at = ? WHERE id = ? AND status = ?',
                    { 'overflow', now, r.id, 'pending' })
            end)
        else
            -- Order zuerst auf 'delivered' setzen (mit Status-Guard), erst dann
            -- Stock einbuchen. Schlaegt das UPDATE fehl/ist 0 affected, wird
            -- die Order beim naechsten Tick erneut versucht - aber es wird
            -- niemals doppelt eingelagert.
            pcall(function()
                local affected = MySQL.update.await(
                    'UPDATE mechanic_workshop_orders SET status = ?, delivered_at = ? WHERE id = ? AND status = ?',
                    { 'delivered', now, r.id, 'pending' })
                if (tonumber(affected) or 0) >= 1 then
                    MySQL.insert.await([[
                        INSERT INTO mechanic_workshop_stock (workshop_id, item, amount, min_stock, category)
                        VALUES (?, ?, ?, 0, ?)
                        ON DUPLICATE KEY UPDATE amount = amount + VALUES(amount), category = VALUES(category)
                    ]], { r.workshop_id, r.item, r.amount, cat })
                end
            end)
        end
    end
    -- Overflow-Orders nach 24h automatisch stornieren + Refund.
    local stale = MySQL.query.await([[
        SELECT id, workshop_id, total_cost FROM mechanic_workshop_orders
         WHERE status = 'overflow' AND delivers_at < ?
         ORDER BY id ASC LIMIT 20
    ]], { now - 24 * 3600 }) or {}
    for _, s in ipairs(stale) do
        -- Refund zuerst, erst dann Order auf 'cancelled'. Schlaegt der Refund
        -- fehl, bleibt die Order auf 'overflow' und der naechste Tick
        -- versucht es erneut.
        pcall(function()
            local refunded = MySQL.update.await(
                'UPDATE mechanic_workshops SET bank = bank + ?, updated_at = ? WHERE id = ?',
                { tonumber(s.total_cost) or 0, now, s.workshop_id })
            if (tonumber(refunded) or 0) >= 1 then
                MySQL.update.await(
                    'UPDATE mechanic_workshop_orders SET status = ?, delivered_at = ? WHERE id = ? AND status = ?',
                    { 'cancelled', now, s.id, 'overflow' })
            end
        end)
    end
end

CreateThread(function()
    -- Erst nach Migrationen
    if HCM.server and HCM.server.waitForMigrations then HCM.server.waitForMigrations(20000) end
    while true do
        local ok = pcall(processDeliveries)
        if not ok and Config.Debug then print('[realtuner] wspc delivery tick error') end
        Wait(30000)
    end
end)
