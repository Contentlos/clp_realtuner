-- =============================================================================
--  clp_realtuner - Einbau / Ausbau / Service
-- =============================================================================

HCM_C = HCM_C or {}

local ox = exports.ox_inventory

-- Hilfsfunktion: Dauer mit Skill-Bonus + Drehmoment-Schluessel-Bonus
local function withSkill(time, failChance)
    local lvl = (HCM_C.me and HCM_C.me.skill and HCM_C.me.skill.level) or 1
    local dur = math.max(Config.Install.MinDuration, time * (1 - (lvl - 1) * (Config.Skill.SpeedBonusPerLevel or 0.04)))
    dur = math.min(dur, Config.Install.MaxDuration)
    local chance = math.max(0.01, failChance - (lvl - 1) * (Config.Skill.FailRateReductionPerLevel or 0.03))
    -- Drehmoment-Schluessel: -40% Fehlerchance, -10% Dauer
    if HCM_C.hasTorqueWrench and HCM_C.hasTorqueWrench() then
        chance = math.max(0.005, chance * 0.6)
        dur = math.max(Config.Install.MinDuration, dur * 0.9)
    end
    -- Werkstatt-Buffs (Food/Kaffee/Radio) + Tool-Tier (Batch 7)
    if HCM_C.getWorkshopBuffPenaltyMult then
        chance = math.max(0.002, chance * HCM_C.getWorkshopBuffPenaltyMult())
    end
    if HCM_C.currentWorkshopToolTier and HCM_C.currentWorkshopToolTier > 1 then
        local tier = HCM_C.currentWorkshopToolTier
        dur = math.max(Config.Install.MinDuration, dur * (1.0 - 0.10 * (tier - 1)))
        chance = math.max(0.002, chance * (1.0 - 0.15 * (tier - 1)))
    end
    return dur, chance
end

local function playInstallAnim()
    local ped = PlayerPedId()
    local dict = Config.Install.Animation.dict
    lib.requestAnimDict(dict, 5000)
    TaskPlayAnim(ped, dict, Config.Install.Animation.anim, 8.0, 1.0, -1, Config.Install.Animation.flag, 0, false, false, false)
end

local function stopInstallAnim()
    ClearPedTasks(PlayerPedId())
end

local function safetyCheck(entity)
    if Config.Install.RequireEngineOff and GetIsVehicleEngineRunning(entity) then
        lib.notify({ title = 'Tuning', description = 'Motor muss aus sein.', type = 'error' }); return false
    end
    if GetEntitySpeed(entity) > (Config.Install.MaxVehicleSpeed or 0.1) then
        lib.notify({ title = 'Tuning', description = 'Fahrzeug muss stehen.', type = 'error' }); return false
    end
    if Config.Install.MustBeOutside and IsPedInAnyVehicle(PlayerPedId(), false) then
        lib.notify({ title = 'Tuning', description = 'Steige aus dem Fahrzeug aus.', type = 'error' }); return false
    end
    if (ox:GetItemCount(Config.Install.ToolItem) or 0) < 1 then
        lib.notify({ title = 'Tuning', description = 'Du brauchst: ' .. Config.Install.ToolItem, type = 'error' }); return false
    end
    return true
end

-- zone -> logische Slot-Liste
local function slotsForZone(zone)
    return SLOTS_BY_ZONE[zone] or {}
end

local function isSlotValidForEntity(entity, slotKey, part)
    if not part then return false end
    if part.modType and part.modType ~= -1 then
        if TOGGLE_MODS and TOGGLE_MODS[part.modType] then
            return true
        end
        local count = GetNumVehicleMods(entity, part.modType)
        return (count or 0) > 0
    end
    return true -- Logik-Teile (ECU, Öl, etc.)
end

-- Dialog: Teil auswählen ----------------------------------------------------
function HCM_C.openPartPicker(entity, zone)
    if not safetyCheck(entity) then return end
    local plate = HCM_C.plateOf(entity)
    local rec   = HCM_C.getRecord(entity)
    if not plate or not rec then return end

    local slots = slotsForZone(zone)
    local listItems = {}

    for _, slotKey in ipairs(slots) do
        -- Alle passenden Parts holen die ich im Inventar habe
        local parts = GetPartsForSlot(slotKey)
        for _, p in ipairs(parts) do
            if isSlotValidForEntity(entity, slotKey, p) and (ox:GetItemCount(p.item) or 0) > 0 then
                local installed = (rec.installed_parts or {})[slotKey]
                local desc = ('Qualität %d • %s%s'):format(
                    p.quality,
                    p.tuning and next(p.tuning) and 'Tuning' or 'Serie',
                    installed and (' • ersetzt: ' .. (installed.item or '')) or ''
                )
                listItems[#listItems+1] = {
                    title = p.label,
                    description = desc,
                    icon = 'wrench',
                    onSelect = function()
                        HCM_C.performInstall(entity, slotKey, p)
                    end,
                }
            end
        end
    end

    if #listItems == 0 then
        lib.notify({ title = 'Tuning', description = 'Keine passenden Teile im Inventar.', type = 'inform' })
        return
    end

    lib.registerContext({
        id = 'clp_realtuner_install_' .. zone,
        title = 'Einbau • ' .. zone,
        options = listItems,
    })
    lib.showContext('clp_realtuner_install_' .. zone)
end

function HCM_C.openRemovePicker(entity, zone)
    if not safetyCheck(entity) then return end
    local rec = HCM_C.getRecord(entity)
    if not rec then return end
    local slots = slotsForZone(zone)
    local opts = {}
    for _, slotKey in ipairs(slots) do
        local entry = (rec.installed_parts or {})[slotKey]
        if entry then
            local p = Parts[entry.item]
            opts[#opts+1] = {
                title = (p and p.label or entry.item) .. '  (' .. slotKey .. ')',
                description = ('Zustand: %s%%'):format(math.floor(entry.condition or 100)),
                icon = 'minus',
                onSelect = function()
                    HCM_C.performRemove(entity, slotKey)
                end,
            }
        end
    end
    if #opts == 0 then
        lib.notify({ title = 'Tuning', description = 'Keine Teile in diesen Slots.', type = 'inform' })
        return
    end
    lib.registerContext({ id = 'clp_realtuner_remove_' .. zone, title = 'Ausbau • ' .. zone, options = opts })
    lib.showContext('clp_realtuner_remove_' .. zone)
end

-- Einbau ausführen ----------------------------------------------------------
function HCM_C.performInstall(entity, slotKey, part)
    if not safetyCheck(entity) then return end
    local plate = HCM_C.plateOf(entity)
    if not plate then return end

    local duration, failChance = withSkill(part.installTime, part.failChance)
    playInstallAnim()

    local done = lib.progressCircle({
        label = 'Baue ein: ' .. part.label,
        duration = duration,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, move = true, combat = true },
    })
    stopInstallAnim()

    if not done then return end

    -- Fehler?
    if math.random() < failChance then
        lib.notify({ title = 'Tuning', description = 'Einbau fehlgeschlagen!', type = 'error' })
        lib.callback.await('clp_realtuner:installFail', 2000, plate, part.item)
        -- kleiner Zusatzschaden
        if part.health and part.health.target then
            HCM_C.pushPatch(plate, { [part.health.target] = math.max(0, (HCM_C.getRecord(entity)[part.health.target] or 100) - 5) }, 'install_fail_damage')
        end
        return
    end

    -- GTA-Mod setzen (clientseitig, Besitzer-Entity)
    if part.modType and part.modType ~= -1 then
        SetVehicleModKit(entity, 0)
        if TOGGLE_MODS and TOGGLE_MODS[part.modType] then
            ToggleVehicleMod(entity, part.modType, true)
        else
            local modIndex = part.modIndex
            if modIndex == -1 or modIndex == nil then
                modIndex = GetNumVehicleMods(entity, part.modType) - 1
            end
            local maxIdx = GetNumVehicleMods(entity, part.modType) - 1
            if modIndex > maxIdx then modIndex = maxIdx end
            if modIndex < 0 then modIndex = 0 end
            SetVehicleMod(entity, part.modType, modIndex, false)
        end
    end

    -- Tuning-Werte persistieren
    local rec = HCM_C.getRecord(entity)
    local tuning = rec.tuning_data or {}
    for stat, val in pairs(part.tuning or {}) do
        tuning[stat] = (tuning[stat] or 0) + val
    end

    local ok, err = lib.callback.await('clp_realtuner:install', 3000, plate, part.item, slotKey)
    if not ok then
        lib.notify({ title = 'Tuning', description = 'Einbau Server-Fehler: ' .. tostring(err), type = 'error' })
        return
    end

    HCM_C.pushPatch(plate, { tuning_data = tuning }, 'install_tuning')
    lib.notify({ title = 'Tuning', description = part.label .. ' verbaut.', type = 'success' })

    -- Handling neu anwenden
    if HCM_C.applyHandling then HCM_C.applyHandling(entity) end
end

-- Ausbau ausführen ----------------------------------------------------------
function HCM_C.performRemove(entity, slotKey)
    if not safetyCheck(entity) then return end
    local plate = HCM_C.plateOf(entity)
    if not plate then return end
    local rec = HCM_C.getRecord(entity)
    local entry = (rec.installed_parts or {})[slotKey]
    if not entry then return end
    local part = Parts[entry.item]
    local duration, _ = withSkill(part and part.installTime or 8000, 0.0)

    playInstallAnim()
    local done = lib.progressCircle({
        label = 'Baue aus: ' .. (part and part.label or entry.item),
        duration = duration,
        position = 'bottom',
        disable = { car = true, move = true, combat = true },
    })
    stopInstallAnim()
    if not done then return end

    -- GTA-Mod zurücksetzen
    if part and part.modType and part.modType ~= -1 then
        SetVehicleModKit(entity, 0)
        if TOGGLE_MODS and TOGGLE_MODS[part.modType] then
            ToggleVehicleMod(entity, part.modType, false)
        else
            SetVehicleMod(entity, part.modType, -1, false)
        end
    end

    -- Tuning subtrahieren
    local tuning = rec.tuning_data or {}
    for stat, val in pairs(part and part.tuning or {}) do
        tuning[stat] = (tuning[stat] or 0) - val
    end

    local ok, err = lib.callback.await('clp_realtuner:remove', 2000, plate, slotKey)
    if not ok then
        lib.notify({ title = 'Tuning', description = 'Ausbau Fehler: ' .. tostring(err), type = 'error' })
        return
    end
    HCM_C.pushPatch(plate, { tuning_data = tuning }, 'remove_tuning')
    lib.notify({ title = 'Tuning', description = 'Teil entfernt.', type = 'success' })
    if HCM_C.applyHandling then HCM_C.applyHandling(entity) end
end

-- Service durchführen --------------------------------------------------------
function HCM_C.doService(entity)
    if not safetyCheck(entity) then return end
    local plate = HCM_C.plateOf(entity)
    if not plate then return end
    playInstallAnim()
    local done = lib.progressCircle({
        label = 'Wartung läuft...', duration = 15000, position = 'bottom',
        disable = { car = true, move = true, combat = true },
    })
    stopInstallAnim()
    if not done then return end
    lib.callback.await('clp_realtuner:service', 2000, plate)
    HCM_C.pushPatch(plate, {
        engine_health       = math.min(100, (HCM_C.getRecord(entity).engine_health or 100) + 8),
        brake_health        = math.min(100, (HCM_C.getRecord(entity).brake_health or 100) + 5),
        suspension_health   = math.min(100, (HCM_C.getRecord(entity).suspension_health or 100) + 5),
        transmission_health = math.min(100, (HCM_C.getRecord(entity).transmission_health or 100) + 5),
    }, 'service')
    lib.notify({ title = 'Service', description = 'Wartung abgeschlossen.', type = 'success' })
end

-- Dyno / Testlauf -----------------------------------------------------------
function HCM_C.dynoTest(entity)
    local rec = HCM_C.getRecord(entity)
    if not rec then return end
    local ok = lib.progressCircle({
        label = 'Testlauf...', duration = 8000, position = 'bottom',
        disable = { car = true, move = true, combat = true },
    })
    if not ok then return end
    local tuning = rec.tuning_data or {}
    lib.alertDialog({
        header = 'Dyno Ergebnis',
        content = ('PS-Bonus: %d%%\nTop-Speed: %d%%\nBremsen: %d%%\nGrip: %d%%\nMotor-Zustand: %s'):format(
            tuning.accel or 0, tuning.topspeed or 0, tuning.brake or 0, tuning.traction or 0,
            HCM.util.statusLabel(rec.engine_health)
        ),
        centered = true,
    })
end
