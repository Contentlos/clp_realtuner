-- =============================================================================
--  clp_realtuner - Versicherung (Batch 11)
--   - Policen (basic/comfort/premium) mit Monatspraemien
--   - Schadenmeldungen (Claims)
--   - Auszahlung bei Totalverlust
-- =============================================================================

local ESX = exports['es_extended']:getSharedObject()

CreateThread(function()
    if HCM.server.waitForMigrations then HCM.server.waitForMigrations(20000) end
    pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `mechanic_insurance_policies` (
                `id`          BIGINT NOT NULL AUTO_INCREMENT,
                `owner`       VARCHAR(64) NOT NULL,
                `plate`       VARCHAR(16) NOT NULL,
                `vin`         VARCHAR(24) DEFAULT NULL,
                `policy_type` VARCHAR(16) NOT NULL DEFAULT 'basic',
                `premium`     INT NOT NULL DEFAULT 0,
                `coverage`    INT NOT NULL DEFAULT 0,
                `deductible`  INT NOT NULL DEFAULT 500,
                `valid_until` BIGINT NOT NULL DEFAULT 0,
                `status`      VARCHAR(16) NOT NULL DEFAULT 'active',
                `created_at`  BIGINT NOT NULL DEFAULT 0,
                PRIMARY KEY (`id`),
                KEY `idx_owner` (`owner`), KEY `idx_plate` (`plate`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `mechanic_insurance_claims` (
                `id`         BIGINT NOT NULL AUTO_INCREMENT,
                `policy_id`  BIGINT NOT NULL,
                `plate`      VARCHAR(16) NOT NULL,
                `reporter`   VARCHAR(64) NOT NULL,
                `amount`     INT NOT NULL DEFAULT 0,
                `payout`     INT NOT NULL DEFAULT 0,
                `reason`     TEXT NULL,
                `status`     VARCHAR(16) NOT NULL DEFAULT 'open',
                `created_at` BIGINT NOT NULL DEFAULT 0,
                `closed_at`  BIGINT NULL,
                PRIMARY KEY (`id`), KEY `idx_plate` (`plate`), KEY `idx_policy` (`policy_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])
    end)
end)

local POLICY_PRESETS = {
    basic   = { premium = 250,  coverage = 15000, deductible = 1500 },
    comfort = { premium = 750,  coverage = 45000, deductible =  750 },
    premium = { premium = 1800, coverage = 90000, deductible =  250 },
}

lib.callback.register('clp_realtuner:insurance:list', function(source)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return {} end
    local rows = {}
    pcall(function()
        rows = MySQL.query.await([[
            SELECT id, plate, vin, policy_type, premium, coverage, deductible, valid_until, status
              FROM mechanic_insurance_policies
             WHERE owner = ? AND status = 'active'
        ]], { xPlayer.identifier }) or {}
    end)
    return rows
end)

lib.callback.register('clp_realtuner:insurance:buy', function(source, plate, policyType)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return false, 'Auth' end
    local preset = POLICY_PRESETS[policyType or 'basic']; if not preset then return false, 'Typ' end
    plate = HCM.util.normalizePlate(plate or '')
    if plate == '' then return false, 'Plate fehlt' end
    local rec = HCM.server.loadRecord(plate); if not rec then return false, 'Fahrzeug unbekannt' end
    if xPlayer.getAccount('bank').money < preset.premium then
        if xPlayer.getMoney() < preset.premium then return false, 'Nicht genug Geld' end
        xPlayer.removeMoney(preset.premium)
    else
        xPlayer.removeAccountMoney('bank', preset.premium)
    end
    local expires = os.time() + 30 * 86400 -- 30 Tage
    pcall(function()
        MySQL.insert.await([[
            INSERT INTO mechanic_insurance_policies
                (owner, plate, vin, policy_type, premium, coverage, deductible, valid_until, status, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'active', ?)
        ]], { xPlayer.identifier, plate, rec.vin, policyType,
             preset.premium, preset.coverage, preset.deductible, expires, os.time() })
    end)
    HCM.server.log(xPlayer, 'insurance:buy', plate, rec.vin, { type = policyType, premium = preset.premium })
    return true, ('Versicherung "%s" gekauft - $%d / 30 Tage'):format(policyType, preset.premium)
end)

lib.callback.register('clp_realtuner:insurance:claim', function(source, plate, amount, reason)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return false, 'Auth' end
    plate = HCM.util.normalizePlate(plate or '')
    amount = math.max(0, tonumber(amount) or 0)
    local row
    pcall(function()
        row = MySQL.single.await([[
            SELECT id, coverage, deductible, valid_until, status
              FROM mechanic_insurance_policies
             WHERE plate = ? AND owner = ? AND status = 'active'
             LIMIT 1
        ]], { plate, xPlayer.identifier })
    end)
    if not row then return false, 'Keine aktive Police auf dieses Kennzeichen' end
    if tonumber(row.valid_until) < os.time() then return false, 'Police abgelaufen' end
    local payout = math.min(tonumber(row.coverage) or 0, math.max(0, amount - (tonumber(row.deductible) or 0)))
    pcall(function()
        MySQL.insert.await([[
            INSERT INTO mechanic_insurance_claims (policy_id, plate, reporter, amount, payout, reason, status, created_at, closed_at)
            VALUES (?, ?, ?, ?, ?, ?, 'paid', ?, ?)
        ]], { row.id, plate, xPlayer.identifier, amount, payout, reason, os.time(), os.time() })
    end)
    if payout > 0 then xPlayer.addAccountMoney('bank', payout) end
    HCM.server.log(xPlayer, 'insurance:claim', plate, nil,
        { amount = amount, payout = payout, policy_id = row.id, reason = reason })
    return true, ('Schaden reguliert: $%d (Selbstbeteiligung $%d)'):format(payout, row.deductible)
end)
