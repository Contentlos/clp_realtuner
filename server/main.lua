-- =============================================================================
--  clp_realtuner - Server Main (ESX + Callbacks + ox_inventory Hooks)
-- =============================================================================

local ESX = exports['es_extended']:getSharedObject()
local ox  = exports.ox_inventory

-- Helper ----------------------------------------------------------------------
local function log(...)
    if Config.Debug then print('[realtuner]', ...) end
end

local function isMechanic(xPlayer)
    if not xPlayer then return false end
    if Config.AllowOutsideJob then return true end
    local job = xPlayer.job and xPlayer.job.name
    return job and Config.MechanicJobs[job] or false
end

local function isAdmin(xPlayer)
    if not xPlayer then return false end
    local grp = xPlayer.getGroup and xPlayer.getGroup() or nil
    return grp and Config.AdminGroups[grp] or false
end

-- Record Lookup / Load --------------------------------------------------------
lib.callback.register('clp_realtuner:load', function(source, plate, model)
    plate = HCM.util.normalizePlate(plate)
    if plate == '' then return nil end
    local rec = HCM.server.loadRecord(plate, model)
    return rec
end)

lib.callback.register('clp_realtuner:get', function(source, plate)
    local rec = HCM.server.loadRecord(HCM.util.normalizePlate(plate))
    return rec
end)

-- Generisches Patchen vom Client (validiert durch Job-Check) ------------------
---@param patch table
RegisterNetEvent('clp_realtuner:patch', function(plate, patch, reason)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if not isMechanic(xPlayer) and not isAdmin(xPlayer) then return end
    if type(patch) ~= 'table' then return end

    plate = HCM.util.normalizePlate(plate)
    local rec = HCM.server.loadRecord(plate)
    if not rec then return end

    -- Whitelist erlaubter Felder
    local allowed = {
        engine_health=true, transmission_health=true, brake_health=true,
        turbo_health=true, suspension_health=true, ecu_state=true,
        installed_parts=true, tuning_data=true, last_service=true,
        odometer=true, paint_quality=true, model=true,
    }
    local clean = {}
    for k, v in pairs(patch) do if allowed[k] then clean[k] = v end end
    for k, v in pairs(clean) do
        if type(v) == 'number' and (k:match('_health$') or k == 'paint_quality') then
            clean[k] = HCM.util.clamp(v, 0.0, 100.0)
        end
    end
    HCM.server.applyPatch(plate, clean)
    HCM.server.log(xPlayer, reason or 'patch', plate, rec.vin, clean)
end)

-- Einbau: Item entfernen + Slot setzen ----------------------------------------
lib.callback.register('clp_realtuner:install', function(source, plate, itemName, slotOverride)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false, 'no_player' end
    if not isMechanic(xPlayer) and not isAdmin(xPlayer) then return false, 'not_mechanic' end

    local part = Parts[itemName]
    if not part then return false, 'unknown_part' end

    local count = ox:GetItemCount(source, itemName)
    if (count or 0) < 1 then return false, 'no_item' end

    plate = HCM.util.normalizePlate(plate)
    local rec = HCM.server.loadRecord(plate)
    if not rec then return false, 'no_record' end

    local slotKey = slotOverride or part.slot
    local installed = rec.installed_parts or {}

    -- Item verbrauchen
    local ok, err = ox:RemoveItem(source, itemName, 1)
    if not ok then return false, err or 'remove_failed' end

    -- Alten Eintrag in Slot ggf. vorher ausbauen (wird im Client vorher durchgespielt)
    installed[slotKey] = { item = part.item, quality = part.quality, ts = os.time(), condition = 100.0 }

    local patch = { installed_parts = installed }
    -- Service-Items erhöhen Komponenten-Health
    if part.health and part.health.target then
        local cur = rec[part.health.target] or 100.0
        patch[part.health.target] = HCM.util.clamp(cur + part.health.add, 0.0, 100.0)
    end
    HCM.server.applyPatch(plate, patch)
    HCM.server.log(xPlayer, 'install:' .. slotKey, plate, rec.vin, { item = itemName })
    HCM.server.addSkillXP(xPlayer, Config.Skill.XP.install_success)
    return true
end)

-- Einbau fehlgeschlagen: ggf. Teil zerstören ---------------------------------
lib.callback.register('clp_realtuner:installFail', function(source, plate, itemName)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    if not isMechanic(xPlayer) and not isAdmin(xPlayer) then return false end
    local part = Parts[itemName]
    if not part then return false end

    if Config.Install.FailDamageParts and math.random() < (Config.Install.FailReturnRate or 0.4) then
        ox:RemoveItem(source, itemName, 1)
        HCM.server.log(xPlayer, 'install:fail_destroyed', plate, nil, { item = itemName })
    else
        HCM.server.log(xPlayer, 'install:fail', plate, nil, { item = itemName })
    end
    HCM.server.addSkillXP(xPlayer, Config.Skill.XP.install_fail)
    return true
end)

-- Ausbau: Teil zurück ins Inventar, Slot leeren ------------------------------
lib.callback.register('clp_realtuner:remove', function(source, plate, slotKey)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false, 'no_player' end
    if not isMechanic(xPlayer) and not isAdmin(xPlayer) then return false, 'not_mechanic' end

    plate = HCM.util.normalizePlate(plate)
    local rec = HCM.server.loadRecord(plate)
    if not rec then return false, 'no_record' end

    local entry = (rec.installed_parts or {})[slotKey]
    if not entry then return false, 'slot_empty' end

    local itemName = entry.item
    local canHold = ox:CanCarryItem(source, itemName, 1)
    if not canHold then return false, 'inventory_full' end

    local meta = { condition = math.floor(entry.condition or 100), label = Parts[itemName] and Parts[itemName].label or nil }
    ox:AddItem(source, itemName, 1, meta)

    local installed = rec.installed_parts or {}
    installed[slotKey] = nil
    HCM.server.applyPatch(plate, { installed_parts = installed })
    HCM.server.log(xPlayer, 'remove:' .. slotKey, plate, rec.vin, { item = itemName })
    return true
end)

-- Lackierung ------------------------------------------------------------------
lib.callback.register('clp_realtuner:paint', function(source, plate, colorType, primaryRGB, secondaryRGB, pearlRGB)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false, 'no_player' end
    if not isMechanic(xPlayer) and not isAdmin(xPlayer) then return false, 'not_mechanic' end

    plate = HCM.util.normalizePlate(plate)
    local rec = HCM.server.loadRecord(plate)
    if not rec then return false, 'no_record' end

    -- Fehlerrate abhängig vom Farbtyp & Skill
    local baseRate
    if colorType == 'pearl' then baseRate = Config.Paint.PearlPerfectRate
    elseif colorType == 'metallic' then baseRate = Config.Paint.MetallicPerfectRate
    else baseRate = Config.Paint.MattePerfectRate end
    local skill = HCM.server.getSkill(xPlayer)
    local perfectChance = HCM.util.clamp(baseRate + (skill.level - 1) * Config.Skill.FailRateReductionPerLevel, 0.05, 0.95)
    local perfect = math.random() < perfectChance
    local quality = perfect and Config.Paint.QualityPerfect or (Config.Paint.QualityFloor + math.random() * 40.0)

    HCM.server.applyPatch(plate, { paint_quality = HCM.util.round(quality, 2) })
    HCM.server.log(xPlayer, 'paint', plate, rec.vin, {
        type = colorType, primary = primaryRGB, secondary = secondaryRGB, pearl = pearlRGB, quality = quality
    })
    if perfect then HCM.server.addSkillXP(xPlayer, Config.Skill.XP.paint_success) end
    return true, { perfect = perfect, quality = quality }
end)

-- ECU Flash -------------------------------------------------------------------
lib.callback.register('clp_realtuner:ecuFlash', function(source, plate, newState)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false, 'no_player' end
    if not isMechanic(xPlayer) and not isAdmin(xPlayer) then return false, 'not_mechanic' end

    if (ox:GetItemCount(source, Config.ECU.RequireItem) or 0) < 1 then
        return false, 'no_flasher'
    end

    plate = HCM.util.normalizePlate(plate)
    local rec = HCM.server.loadRecord(plate)
    if not rec then return false, 'no_record' end

    local ecu = rec.ecu_state or {}
    ecu.afr    = HCM.util.clamp(tonumber(newState.afr)    or ecu.afr    or Config.ECU.AFR.stock,    Config.ECU.AFR.min,    Config.ECU.AFR.max)
    ecu.torque = HCM.util.clamp(tonumber(newState.torque) or ecu.torque or Config.ECU.Torque.stock, Config.ECU.Torque.min, Config.ECU.Torque.max)
    ecu.fuel   = HCM.util.clamp(tonumber(newState.fuel)   or ecu.fuel   or Config.ECU.FuelMap.stock, Config.ECU.FuelMap.min, Config.ECU.FuelMap.max)

    local safe = (ecu.afr    >= Config.ECU.AFR.safe[1]    and ecu.afr    <= Config.ECU.AFR.safe[2])
             and (ecu.torque >= Config.ECU.Torque.safe[1] and ecu.torque <= Config.ECU.Torque.safe[2])
             and (ecu.fuel   >= Config.ECU.FuelMap.safe[1]and ecu.fuel   <= Config.ECU.FuelMap.safe[2])

    local patch = { ecu_state = ecu }
    if not safe then
        patch.engine_health = HCM.util.clamp((rec.engine_health or 100) - Config.ECU.EngineDamageOnFlash, 0.0, 100.0)
    else
        HCM.server.addSkillXP(xPlayer, Config.Skill.XP.ecu_flash_safe)
    end
    HCM.server.applyPatch(plate, patch)
    HCM.server.log(xPlayer, safe and 'ecu:flash_safe' or 'ecu:flash_risky', plate, rec.vin, ecu)
    return true, { safe = safe, ecu = ecu }
end)

-- Service / Reparatur --------------------------------------------------------
lib.callback.register('clp_realtuner:service', function(source, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    if not isMechanic(xPlayer) and not isAdmin(xPlayer) then return false end
    plate = HCM.util.normalizePlate(plate)
    local rec = HCM.server.loadRecord(plate)
    if not rec then return false end
    HCM.server.applyPatch(plate, { last_service = os.time() })
    HCM.server.log(xPlayer, 'service', plate, rec.vin, {})
    HCM.server.addSkillXP(xPlayer, Config.Skill.XP.repair)
    return true
end)

-- Diagnose Historie ----------------------------------------------------------
lib.callback.register('clp_realtuner:history', function(source, plate, limit)
    plate = HCM.util.normalizePlate(plate)
    limit = tonumber(limit) or 20
    local rows = MySQL.query.await(
        'SELECT charname, action, detail, timestamp FROM mechanic_logs WHERE plate = ? ORDER BY id DESC LIMIT ?',
        { plate, limit }
    )
    return rows or {}
end)

-- Info über aktuellen Mechaniker ---------------------------------------------
lib.callback.register('clp_realtuner:whoami', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return nil end
    local skill = HCM.server.getSkill(xPlayer)
    return {
        charname = xPlayer.getName and xPlayer.getName() or ('ID ' .. source),
        job      = xPlayer.job and xPlayer.job.name,
        isMech   = isMechanic(xPlayer),
        isAdmin  = isAdmin(xPlayer),
        skill    = skill,
    }
end)

-- Tablet öffnen via Item -----------------------------------------------------
if Config.Tablet.Item then
    CreateThread(function()
        ox:registerHook('usingItem', function(payload)
            if payload.item.name == Config.Tablet.Item then
                TriggerClientEvent('clp_realtuner:openTablet', payload.source)
                return false -- verhindert default usable-Behandlung
            end
        end, {
            itemFilter = { [Config.Tablet.Item] = true },
        })
    end)
end

-- Diagnose-Tools via Item (Batch 2) ------------------------------------------
CreateThread(function()
    local diagItems = {
        obd_scanner = 'clp_realtuner:useItem:obd',
        endoscope   = 'clp_realtuner:useItem:endoscope',
    }
    for item, ev in pairs(diagItems) do
        ox:registerHook('usingItem', function(payload)
            if payload.item.name == item then
                TriggerClientEvent(ev, payload.source)
                return false
            end
        end, { itemFilter = { [item] = true } })
    end
end)

-- Odometer Updates vom Client ------------------------------------------------
RegisterNetEvent('clp_realtuner:odometer', function(plate, delta)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    plate = HCM.util.normalizePlate(plate)
    local rec = HCM.server.loadRecord(plate)
    if not rec then return end
    delta = tonumber(delta) or 0
    if delta <= 0 or delta > 5 then return end -- Plausibilität (max 5km pro Tick)
    local km = (rec.odometer or 0) + delta
    local wear = delta * Config.HealthDecayPerKm
    local patch = {
        odometer            = km,
        engine_health       = HCM.util.clamp((rec.engine_health or 100) - wear, 0.0, 100.0),
        brake_health        = HCM.util.clamp((rec.brake_health or 100)  - wear * 0.8, 0.0, 100.0),
        suspension_health   = HCM.util.clamp((rec.suspension_health or 100) - wear * 0.6, 0.0, 100.0),
        transmission_health = HCM.util.clamp((rec.transmission_health or 100) - wear * 0.5, 0.0, 100.0),
    }
    HCM.server.applyPatch(plate, patch)
end)

-- Schadens-Events vom Client -------------------------------------------------
RegisterNetEvent('clp_realtuner:damage', function(plate, component, amount)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    plate = HCM.util.normalizePlate(plate)
    local rec = HCM.server.loadRecord(plate)
    if not rec then return end
    amount = tonumber(amount) or 0
    local field = ({
        engine='engine_health', turbo='turbo_health',
        brakes='brake_health', transmission='transmission_health',
        suspension='suspension_health',
    })[component]
    if not field then return end
    local cur = rec[field] or 100.0
    HCM.server.applyPatch(plate, { [field] = HCM.util.clamp(cur - amount, 0.0, 100.0) })
end)
