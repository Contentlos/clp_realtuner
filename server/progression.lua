-- =============================================================================
--  clp_realtuner - Mechaniker-Progression (Batch 6)
--   - Rank/Tier: Lehrling -> Geselle -> Meister (mit Pruefung)
--   - Spezialisierungen (spec_engine, spec_brakes, spec_paint, spec_electrics, spec_chassis)
--   - Portfolio (Aufzeichnung vergangener Arbeiten)
--   - Tutorial-Flag
--   - Zertifikate (als Inventar-Item + DB Eintrag)
-- =============================================================================

local ESX = exports['es_extended']:getSharedObject()
local ox  = exports.ox_inventory

local RANK_THRESHOLDS = {
    lehrling = 1,   -- Default
    geselle  = 5,
    meister  = 9,
}
local RANK_ORDER = { 'lehrling', 'geselle', 'meister' }

local SPEC_MAP = {
    ['install:engine_block'] = 'spec_engine',
    ['install:turbo']        = 'spec_engine',
    ['install:intake']       = 'spec_engine',
    ['install:exhaust']      = 'spec_engine',
    ['install:camshaft']     = 'spec_engine',
    ['install:injector']     = 'spec_engine',
    ['install:ecu']          = 'spec_electrics',
    ['install:brakes']       = 'spec_brakes',
    ['install:service_brake']= 'spec_brakes',
    ['paint']                = 'spec_paint',
    ['install:suspension']   = 'spec_chassis',
    ['install:wheel_rim']    = 'spec_chassis',
    ['install:tire']         = 'spec_chassis',
    ['install:spoiler']      = 'spec_chassis',
    ['install:side_skirt']   = 'spec_chassis',
    ['install:fender']       = 'spec_chassis',
}

local function loadExtended(identifier)
    local row
    pcall(function()
        row = MySQL.single.await([[
            SELECT identifier, xp, level, repairs, installs,
                   COALESCE(tier,'lehrling') AS tier, COALESCE(tutorial_done,0) AS tutorial_done,
                   COALESCE(spec_engine,0) AS spec_engine,
                   COALESCE(spec_brakes,0) AS spec_brakes,
                   COALESCE(spec_paint,0) AS spec_paint,
                   COALESCE(spec_electrics,0) AS spec_electrics,
                   COALESCE(spec_chassis,0) AS spec_chassis
              FROM mechanic_skill WHERE identifier = ? LIMIT 1
        ]], { identifier })
    end)
    return row
end

local function getIdent(xPlayer)
    return xPlayer.identifier or (xPlayer.getIdentifier and xPlayer.getIdentifier()) or nil
end

-- Oeffentliche API -----------------------------------------------------------
function HCM.server.getProgression(xPlayer)
    local ident = getIdent(xPlayer)
    if not ident then return nil end
    return loadExtended(ident)
end

function HCM.server.addSpecPoint(xPlayer, action)
    local ident = getIdent(xPlayer)
    if not ident then return end
    local col = SPEC_MAP[action]
    if not col then
        -- generic prefix match (install:<slot>)
        for k, v in pairs(SPEC_MAP) do
            if action:sub(1, #k) == k then col = v; break end
        end
    end
    if not col then return end
    pcall(function()
        MySQL.update.await(
            ('UPDATE mechanic_skill SET %s = %s + 1 WHERE identifier = ?'):format(col, col),
            { ident }
        )
    end)
end

function HCM.server.logPortfolio(xPlayer, action, plate, vin, detail)
    local ident = getIdent(xPlayer)
    if not ident then return end
    pcall(function()
        MySQL.insert.await([[
            INSERT INTO mechanic_portfolio (identifier, plate, vin, action, detail, timestamp)
            VALUES (?, ?, ?, ?, ?, ?)
        ]], { ident, plate or '', vin, action, detail and json.encode(detail) or nil, os.time() })
    end)
end

-- In logging-pipeline einhaengen: jede log() haengt automatisch ein Portfolio-Entry an
local origLog = HCM.server.log
HCM.server.log = function(xPlayer, action, plate, vin, detail)
    origLog(xPlayer, action, plate, vin, detail)
    -- Spec-Punkte
    if action and (action:sub(1, 8) == 'install:' or action == 'paint' or action == 'service') then
        HCM.server.addSpecPoint(xPlayer, action)
    end
    -- Portfolio: nur Mechaniker-Arbeiten (nicht admin:* / patch / odometer)
    if action and not action:match('^admin:') and action ~= 'patch' and action ~= 'odometer' then
        HCM.server.logPortfolio(xPlayer, action, plate, vin, detail)
    end
end

-- Tutorial-Flag --------------------------------------------------------------
lib.callback.register('clp_realtuner:progression:getTutorialDone', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return true end
    local p = HCM.server.getProgression(xPlayer)
    return p and p.tutorial_done == 1 or false
end)

RegisterNetEvent('clp_realtuner:progression:markTutorial', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src); if not xPlayer then return end
    local ident = getIdent(xPlayer); if not ident then return end
    pcall(function()
        MySQL.update.await('UPDATE mechanic_skill SET tutorial_done = 1 WHERE identifier = ?', { ident })
    end)
end)

-- Rank-Pruefung --------------------------------------------------------------
lib.callback.register('clp_realtuner:progression:attemptRankUp', function(source)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return false, 'no xplayer' end
    local ident = getIdent(xPlayer); if not ident then return false, 'no ident' end
    local row = loadExtended(ident)
    if not row then return false, 'no row' end
    local cur = row.tier or 'lehrling'
    local idx = 1
    for i, r in ipairs(RANK_ORDER) do if r == cur then idx = i; break end end
    local next_ = RANK_ORDER[idx + 1]
    if not next_ then
        return false, ('Du bist bereits Meister.')
    end
    local needLvl = RANK_THRESHOLDS[next_] or 99
    if (row.level or 1) < needLvl then
        return false, ('Mindestens Level %d noetig (du bist %d).'):format(needLvl, row.level or 1)
    end
    -- Pruefung: Spezialisierung >= 5 Punkte in mind. 2 Bereichen
    local specCount = 0
    for _, k in ipairs({ 'spec_engine','spec_brakes','spec_paint','spec_electrics','spec_chassis' }) do
        if (row[k] or 0) >= 5 then specCount = specCount + 1 end
    end
    if next_ == 'geselle' and specCount < 1 then
        return false, 'Mind. 5 Arbeiten in einem Spezialgebiet noetig.'
    end
    if next_ == 'meister' and specCount < 2 then
        return false, 'Mind. 5 Arbeiten in zwei Spezialgebieten noetig.'
    end
    -- Pruefung bestehen
    pcall(function()
        MySQL.update.await('UPDATE mechanic_skill SET tier = ?, exam_passed = ? WHERE identifier = ?',
            { next_, json.encode({ ts = os.time(), from = cur, to = next_ }), ident })
        MySQL.insert.await('INSERT INTO mechanic_certificates (identifier, kind, issued_at, issuer) VALUES (?, ?, ?, ?)',
            { ident, next_, os.time(), 'system' })
    end)
    -- Zertifikat-Item ins Inventar
    pcall(function()
        local itemName = 'cert_' .. next_
        ox:AddItem(source, itemName, 1, {
            description = ('%s-Zertifikat, ausgestellt %s'):format(next_, os.date('%d.%m.%Y')),
            issued_at = os.time(),
        })
    end)
    HCM.server.log(xPlayer, 'progression:rank_up:' .. next_, nil, nil, { from = cur, to = next_ })
    return true, ('Beförderung zu %s bestanden!'):format(next_)
end)

-- Portfolio-Abruf fuer Tablet ------------------------------------------------
lib.callback.register('clp_realtuner:progression:portfolio', function(source, limit)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return {} end
    local ident = getIdent(xPlayer); if not ident then return {} end
    local rows = {}
    pcall(function()
        rows = MySQL.query.await([[
            SELECT plate, vin, action, detail, timestamp
              FROM mechanic_portfolio
             WHERE identifier = ?
             ORDER BY timestamp DESC LIMIT ?
        ]], { ident, tonumber(limit) or 100 }) or {}
    end)
    return rows
end)

-- Zertifikate abrufen --------------------------------------------------------
lib.callback.register('clp_realtuner:progression:certificates', function(source)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return {} end
    local ident = getIdent(xPlayer); if not ident then return {} end
    local rows = {}
    pcall(function()
        rows = MySQL.query.await(
            'SELECT kind, issued_at, issuer FROM mechanic_certificates WHERE identifier = ? ORDER BY issued_at DESC',
            { ident }) or {}
    end)
    return rows
end)
