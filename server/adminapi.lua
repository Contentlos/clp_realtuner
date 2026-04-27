-- =============================================================================
--  clp_realtuner - Admin API (NUI)
--  Alle Endpoints sind Admin-gegated.
-- =============================================================================

local ESX = exports['es_extended']:getSharedObject()

local function isAdmin(xPlayer)
    if not xPlayer then return false end
    local grp = xPlayer.getGroup and xPlayer.getGroup() or nil
    return grp and Config.AdminGroups[grp] or false
end

local function guard(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    return isAdmin(xPlayer), xPlayer
end

-- Bootstrap / Vollansicht ----------------------------------------------------
lib.callback.register('clp_realtuner:admin:snapshot', function(source)
    local ok, xPlayer = guard(source)
    if not ok then return nil end
    return {
        config    = HCM.runtime.getConfigSnapshot(),
        parts     = HCM.runtime.getPartsSnapshot(),
        locations = HCM.runtime.getLocationsSnapshot(),
        overrides = HCM.runtime.getState(),
    }
end)

-- Config --------------------------------------------------------------------
lib.callback.register('clp_realtuner:admin:setConfig', function(source, keyPath, value)
    local ok, xPlayer = guard(source)
    if not ok then return false end
    HCM.runtime.setConfig(keyPath, value)
    HCM.server.log(xPlayer, 'admin:set_config:' .. keyPath, nil, nil, { value = value })
    return true
end)

-- Parts ---------------------------------------------------------------------
lib.callback.register('clp_realtuner:admin:setPart', function(source, item, def)
    local ok, xPlayer = guard(source)
    if not ok then return false end
    HCM.runtime.setPart(item, def)
    HCM.server.log(xPlayer, 'admin:set_part:' .. tostring(item), nil, nil, def or { removed = true })
    return true
end)

-- Locations -----------------------------------------------------------------
lib.callback.register('clp_realtuner:admin:setLocations', function(source, category, list)
    local ok, xPlayer = guard(source)
    if not ok then return false end
    HCM.runtime.setLocation(category, list)
    HCM.server.log(xPlayer, 'admin:set_loc:' .. tostring(category), nil, nil, { count = #(list or {}) })
    return true
end)

-- Vehicles ------------------------------------------------------------------
lib.callback.register('clp_realtuner:admin:listVehicles', function(source, search, limit, offset)
    local ok = guard(source)
    if not ok then return nil end
    limit = tonumber(limit) or 100
    offset = tonumber(offset) or 0
    local q = '%'
    if search and search ~= '' then q = '%' .. search .. '%' end
    -- Full-select damit fehlende Spalten (vor Migration) nicht crashen.
    -- Filterung hier per LIKE auf plate (sicher vorhanden) + optional vin/model.
    local okq, rows = pcall(function()
        return MySQL.query.await([[
            SELECT * FROM vehicles_data
            WHERE plate LIKE ? OR IFNULL(vin,'') LIKE ? OR IFNULL(model,'') LIKE ?
            ORDER BY plate ASC LIMIT ? OFFSET ?
        ]], { q, q, q, limit, offset })
    end)
    if not okq or not rows then
        -- Fallback: nur nach plate filtern
        local okq2, rows2 = pcall(function()
            return MySQL.query.await(
                'SELECT * FROM vehicles_data WHERE plate LIKE ? ORDER BY plate ASC LIMIT ? OFFSET ?',
                { q, limit, offset }
            )
        end)
        rows = okq2 and rows2 or {}
    end
    return rows or {}
end)

lib.callback.register('clp_realtuner:admin:getVehicle', function(source, plate)
    local ok = guard(source)
    if not ok then return nil end
    plate = HCM.util.normalizePlate(plate)
    return HCM.server.loadRecord(plate)
end)

lib.callback.register('clp_realtuner:admin:updateVehicle', function(source, plate, patch)
    local ok, xPlayer = guard(source)
    if not ok then return false end
    plate = HCM.util.normalizePlate(plate)
    HCM.server.applyPatch(plate, patch)
    HCM.server.save(plate)
    HCM.server.log(xPlayer, 'admin:update_vehicle', plate, nil, patch)
    return true
end)

lib.callback.register('clp_realtuner:admin:resetVehicle', function(source, plate)
    local ok, xPlayer = guard(source)
    if not ok then return false end
    plate = HCM.util.normalizePlate(plate)
    HCM.server.applyPatch(plate, {
        engine_health = 100.0, transmission_health = 100.0, brake_health = 100.0,
        turbo_health = 100.0, suspension_health = 100.0, paint_quality = 100.0,
        installed_parts = {}, tuning_data = {}, last_service = os.time(),
        ecu_state = { afr = Config.ECU.AFR.stock, torque = Config.ECU.Torque.stock, fuel = Config.ECU.FuelMap.stock },
    })
    HCM.server.save(plate)
    HCM.server.log(xPlayer, 'admin:reset_vehicle', plate, nil, {})
    return true
end)

-- Logs ----------------------------------------------------------------------
lib.callback.register('clp_realtuner:admin:logs', function(source, filter)
    local ok = guard(source)
    if not ok then return nil end
    filter = filter or {}
    local limit = tonumber(filter.limit) or 200
    local conds, params = {}, {}
    if filter.plate and filter.plate ~= '' then
        table.insert(conds, 'plate LIKE ?'); table.insert(params, '%' .. filter.plate .. '%')
    end
    if filter.identifier and filter.identifier ~= '' then
        table.insert(conds, 'identifier LIKE ?'); table.insert(params, '%' .. filter.identifier .. '%')
    end
    if filter.action and filter.action ~= '' then
        table.insert(conds, 'action LIKE ?'); table.insert(params, '%' .. filter.action .. '%')
    end
    local where = #conds > 0 and (' WHERE ' .. table.concat(conds, ' AND ')) or ''
    table.insert(params, limit)
    local rows = MySQL.query.await(
        'SELECT id, identifier, charname, action, plate, vin, detail, timestamp FROM mechanic_logs' ..
        where .. ' ORDER BY id DESC LIMIT ?', params
    )
    return rows or {}
end)

-- Skills --------------------------------------------------------------------
lib.callback.register('clp_realtuner:admin:listSkills', function(source, search)
    local ok = guard(source)
    if not ok then return nil end
    local q = '%'
    if search and search ~= '' then q = '%' .. search .. '%' end
    return MySQL.query.await(
        'SELECT * FROM mechanic_skill WHERE identifier LIKE ? ORDER BY level DESC, xp DESC LIMIT 200',
        { q }
    ) or {}
end)

lib.callback.register('clp_realtuner:admin:setSkill', function(source, identifier, level, xp)
    local ok, xPlayer = guard(source)
    if not ok then return false end
    MySQL.update.await(
        'INSERT INTO mechanic_skill (identifier, level, xp) VALUES (?, ?, ?) ' ..
        'ON DUPLICATE KEY UPDATE level = VALUES(level), xp = VALUES(xp)',
        { identifier, level, xp }
    )
    HCM.server.log(xPlayer, 'admin:set_skill:' .. identifier, nil, nil, { level = level, xp = xp })
    return true
end)

-- Paint-Booth jetzt hinzufügen (Koordinaten vom Client) ---------------------
lib.callback.register('clp_realtuner:admin:addPaintBooth', function(source, coords, heading, radius)
    local ok, xPlayer = guard(source)
    if not ok then return false end
    local list = Locations.paintBooths or {}
    list[#list+1] = { coords = coords, heading = heading or 0.0, radius = radius or 3.0 }
    HCM.runtime.setLocation('paintBooths', list)
    HCM.server.log(xPlayer, 'admin:add_paint_booth', nil, nil, { coords = coords })
    return true
end)

lib.callback.register('clp_realtuner:admin:removePaintBooth', function(source, index)
    local ok, xPlayer = guard(source)
    if not ok then return false end
    local list = Locations.paintBooths or {}
    table.remove(list, tonumber(index) or 0)
    HCM.runtime.setLocation('paintBooths', list)
    HCM.server.log(xPlayer, 'admin:remove_paint_booth', nil, nil, { index = index })
    return true
end)

-- =============================================================================
--  Give-Items (Werkzeuge-Tab im Admin-Panel)
-- =============================================================================
local function collectResourceItems()
    local set = {}
    for _, def in pairs(Parts or {}) do
        if type(def) == 'table' and def.item then set[def.item] = true end
    end
    local addons = {
        Config.Install and Config.Install.ToolItem,
        Config.Install and Config.Install.AdvancedToolItem,
        Config.ECU and Config.ECU.RequireItem,
        Config.Paint and Config.Paint.Tool,
        Config.Tablet and Config.Tablet.Item,
        Config.Wartung and Config.Wartung.WindshieldRepairItem,
        Config.Progression and Config.Progression.CertificateItem,
        Config.Progression and Config.Progression.ExamItem,
        'oil_basic', 'oil_full_synth', 'coolant', 'brake_pad_set',
        'spark_plug', 'battery', 'headlight_bulb', 'rearlight_bulb',
        'brake_fluid_bottle', 'fuel_hose', 'rust_remover',
        'obd_scanner', 'endoscope', 'dyno_chip', 'torque_wrench',
        'wrap_kit', 'tint_kit', 'neon_kit',
    }
    for _, name in ipairs(addons) do
        if name and name ~= '' then set[name] = true end
    end
    local list = {}
    for k in pairs(set) do list[#list+1] = k end
    table.sort(list)
    return list
end

lib.callback.register('clp_realtuner:admin:listResourceItems', function(source)
    local ok = guard(source)
    if not ok then return {} end
    return collectResourceItems()
end)

lib.callback.register('clp_realtuner:admin:listPlayers', function(source)
    local ok = guard(source)
    if not ok then return {} end
    local players = ESX.GetExtendedPlayers()
    local out = {}
    for _, xP in pairs(players or {}) do
        out[#out+1] = {
            id = xP.source,
            name = xP.getName and xP.getName() or (xP.identifier or ('ID ' .. xP.source)),
            identifier = xP.identifier,
            job = xP.job and xP.job.name or '',
            group = xP.getGroup and xP.getGroup() or 'user',
        }
    end
    table.sort(out, function(a, b) return (a.id or 0) < (b.id or 0) end)
    return out
end)

---@param targetKind 'self'|'id'|'all'|'nearest'
---@param targetId number|nil (server-id bei 'id', oder vom Client bereits aufgeloester source bei 'nearest')
---@param items string[]|'ALL'
---@param amount number
lib.callback.register('clp_realtuner:admin:giveItems', function(source, targetKind, targetId, items, amount)
    local ok, xPlayer = guard(source)
    if not ok then return { ok = false, reason = 'Keine Berechtigung' } end
    amount = math.max(1, math.floor(tonumber(amount) or 1))
    if items == 'ALL' or items == nil then items = collectResourceItems() end
    if type(items) ~= 'table' then return { ok = false, reason = 'Keine Items' } end

    local targets = {}
    if targetKind == 'self' then
        targets[#targets+1] = xPlayer
    elseif targetKind == 'id' then
        local t = ESX.GetPlayerFromId(tonumber(targetId) or 0)
        if t then targets[#targets+1] = t end
    elseif targetKind == 'all' then
        for _, p in pairs(ESX.GetExtendedPlayers()) do targets[#targets+1] = p end
    elseif targetKind == 'nearest' then
        -- Client sollte naechsten Spieler vorher aufgeloest haben und als
        -- targetId uebergeben. Falls nicht: selbst.
        local t = tonumber(targetId) and ESX.GetPlayerFromId(tonumber(targetId)) or xPlayer
        if t then targets[#targets+1] = t end
    end

    if #targets == 0 then return { ok = false, reason = 'Ziel nicht gefunden' } end

    local given, failed = 0, {}
    for _, t in ipairs(targets) do
        for _, item in ipairs(items) do
            local ok2 = pcall(function()
                local added = exports.ox_inventory:AddItem(t.source, item, amount)
                if added then given = given + 1 end
            end)
            if not ok2 then failed[#failed+1] = item end
        end
    end

    HCM.server.log(xPlayer, 'admin:give_items:' .. tostring(targetKind), nil, nil, {
        items = items, amount = amount, targets = #targets, given = given, failed = failed,
    })
    return { ok = true, given = given, failed = failed, targets = #targets }
end)

-- Performance-Profiler ------------------------------------------------------
lib.callback.register('clp_realtuner:admin:profiler', function(source, doReset)
    local ok = guard(source)
    if not ok then return nil end
    if doReset then HCM.profiler.reset() end
    return {
        memoryKb = collectgarbage('count'),
        uptime   = math.floor((GetGameTimer() or 0) / 1000),
        entries  = HCM.profiler.snapshot(),
    }
end)
