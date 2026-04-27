-- =============================================================================
--  clp_realtuner - Logging & Skill System
-- =============================================================================

HCM = HCM or {}
HCM.server = HCM.server or {}

local skillCache = {} -- identifier -> { xp, level, repairs, installs }

-- Logging --------------------------------------------------------------------
function HCM.server.log(xPlayer, action, plate, vin, detail)
    local ident = xPlayer.identifier or xPlayer.getIdentifier and xPlayer.getIdentifier() or 'unknown'
    local name  = xPlayer.getName and xPlayer.getName() or tostring(ident)
    MySQL.insert('INSERT INTO mechanic_logs (identifier, charname, action, plate, vin, detail, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        ident, name, action, plate, vin, json.encode(detail or {}), os.time()
    })
end

-- Skill ----------------------------------------------------------------------
local function loadSkill(identifier)
    if skillCache[identifier] then return skillCache[identifier] end
    local row = MySQL.single.await('SELECT * FROM mechanic_skill WHERE identifier = ? LIMIT 1', { identifier })
    if not row then
        MySQL.insert.await('INSERT INTO mechanic_skill (identifier, xp, level, repairs, installs) VALUES (?, 0, 1, 0, 0)', { identifier })
        row = { identifier = identifier, xp = 0, level = 1, repairs = 0, installs = 0 }
    end
    row.xp       = tonumber(row.xp) or 0
    row.level    = tonumber(row.level) or 1
    row.repairs  = tonumber(row.repairs) or 0
    row.installs = tonumber(row.installs) or 0
    skillCache[identifier] = row
    return row
end

function HCM.server.getSkill(xPlayer)
    local ident = xPlayer.identifier or xPlayer.getIdentifier and xPlayer.getIdentifier()
    if not ident then return { xp = 0, level = 1, repairs = 0, installs = 0 } end
    return loadSkill(ident)
end

function HCM.server.addSkillXP(xPlayer, amount)
    local ident = xPlayer.identifier or xPlayer.getIdentifier and xPlayer.getIdentifier()
    if not ident or (amount or 0) <= 0 then return end
    local s = loadSkill(ident)
    s.xp = s.xp + amount
    -- Level-Up Schleife
    while s.level < Config.Skill.MaxLevel and s.xp >= Config.Skill.LevelCurve(s.level) do
        s.xp = s.xp - Config.Skill.LevelCurve(s.level)
        s.level = s.level + 1
        TriggerClientEvent('clp_realtuner:skillUp', xPlayer.source, s.level)
    end
    MySQL.update('UPDATE mechanic_skill SET xp = ?, level = ? WHERE identifier = ?', { s.xp, s.level, ident })
end

-- Aufräumen alter Logs -------------------------------------------------------
CreateThread(function()
    Wait(10 * 60 * 1000)
    local cutoff = os.time() - (Config.LogRetentionDays * 86400)
    MySQL.update('DELETE FROM mechanic_logs WHERE timestamp < ?', { cutoff })
end)
