-- =============================================================================
--  clp_realtuner - Migrations-Loader
--  Liest alle `migrations/*.sql` in lexikalischer Reihenfolge und fuehrt jede
--  noch nicht angewandte Migration genau einmal aus. State in `_hcm_migrations`.
-- =============================================================================

local RESOURCE = GetCurrentResourceName()

local function listMigrations()
    local out = {}
    -- LoadResourceFile kann Dateien enumerieren nur indirekt; wir fuehren einen
    -- Index-File an, damit kein ls/os.* noetig ist.
    local idx = LoadResourceFile(RESOURCE, 'migrations/INDEX.txt')
    if not idx or idx == '' then return out end
    for line in idx:gmatch('[^\r\n]+') do
        local trimmed = line:match('^%s*(.-)%s*$') or ''
        if trimmed ~= '' and not trimmed:match('^#') then
            out[#out + 1] = trimmed
        end
    end
    return out
end

local function splitStatements(sql)
    -- naive Splitter am `;` am Zeilenende, reicht fuer unsere Migrations (keine
    -- Trigger/Procedures mit DELIMITER-Tricks)
    local stmts = {}
    local buf = {}
    for line in (sql .. '\n'):gmatch('([^\r\n]*)\r?\n') do
        local stripped = line:match('^%s*(.-)%s*$') or ''
        if stripped:match('^%-%-') or stripped == '' then
            -- comment / blank -> skip
        else
            buf[#buf + 1] = line
            if stripped:sub(-1) == ';' then
                local full = table.concat(buf, '\n')
                local body = full:gsub(';%s*$', '')
                if body:match('%S') then stmts[#stmts + 1] = body end
                buf = {}
            end
        end
    end
    return stmts
end

local function isApplied(id)
    local row = MySQL.single.await('SELECT id FROM _hcm_migrations WHERE id = ?', { id })
    return row ~= nil
end

CreateThread(function()
    Wait(500) -- MySQL ready
    -- Bootstrap: _hcm_migrations Tabelle selbst anlegen, falls INSTALL.sql nicht
    -- (neu) geladen wurde. Macht das ganze Script resilient.
    pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `_hcm_migrations` (
                `id`         VARCHAR(64)  NOT NULL,
                `applied_at` BIGINT       NOT NULL,
                PRIMARY KEY (`id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])
        -- Auch vehicles_data Grund-Tabelle sicherstellen (vin-Fehler!)
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `vehicles_data` (
                `plate` VARCHAR(16) NOT NULL,
                PRIMARY KEY (`plate`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `mechanic_logs` (
                `id` BIGINT NOT NULL AUTO_INCREMENT,
                `identifier` VARCHAR(64) NOT NULL,
                `charname` VARCHAR(64) DEFAULT NULL,
                `action` VARCHAR(64) NOT NULL,
                `plate` VARCHAR(16) DEFAULT NULL,
                `vin` VARCHAR(24) DEFAULT NULL,
                `detail` JSON NULL,
                `timestamp` BIGINT NOT NULL,
                PRIMARY KEY (`id`),
                KEY `idx_identifier` (`identifier`),
                KEY `idx_plate` (`plate`),
                KEY `idx_time` (`timestamp`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `mechanic_skill` (
                `identifier` VARCHAR(64) NOT NULL,
                `xp` INT NOT NULL DEFAULT 0,
                `level` INT NOT NULL DEFAULT 1,
                `repairs` INT NOT NULL DEFAULT 0,
                `installs` INT NOT NULL DEFAULT 0,
                `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (`identifier`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])
    end)

    local files = listMigrations()
    if #files == 0 then return end
    local applied, skipped = 0, 0
    for _, rel in ipairs(files) do
        local id = rel:gsub('%.sql$', ''):gsub('^migrations/', '')
        if isApplied(id) then
            skipped = skipped + 1
        else
            local sql = LoadResourceFile(RESOURCE, rel)
            if not sql or sql == '' then
                print(('[realtuner] migration %s fehlt oder ist leer'):format(rel))
            else
                local stmts = splitStatements(sql)
                local ok = true
                for _, stmt in ipairs(stmts) do
                    local success, err = pcall(function()
                        MySQL.query.await(stmt)
                    end)
                    if not success then
                        ok = false
                        print(('[realtuner] Migration %s Fehler: %s'):format(id, tostring(err)))
                        print(('[realtuner] Statement: %s'):format(stmt:sub(1, 200)))
                        break
                    end
                end
                if ok then
                    applied = applied + 1
                    print(('[realtuner] Migration %s angewendet.'):format(id))
                end
            end
        end
    end
    print(('[realtuner] Migrations: %d neu, %d bereits vorhanden.'):format(applied, skipped))
end)
