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
    local rows = MySQL.query.await([[
        SELECT plate, vin, model, engine_health, transmission_health, brake_health,
               turbo_health, suspension_health, last_service, odometer, paint_quality, updated_at
        FROM vehicles_data
        WHERE plate LIKE ? OR vin LIKE ? OR model LIKE ?
        ORDER BY updated_at DESC LIMIT ? OFFSET ?
    ]], { q, q, q, limit, offset })
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
