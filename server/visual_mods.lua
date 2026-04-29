-- =============================================================================
--  clp_realtuner - Visual-Mods Server-Persistenz (Batch 14a)
--
--  Speichert die Snapshot-Payload aus dem Inspector im tuning_data.visualMods
--  Feld der vehicles_data Zeile. Das ist eine reine Persistenzschicht; das
--  Anwenden auf einer Entity passiert clientseitig (siehe client/inspector.lua
--  und client/runtime.lua applyVisuals()).
--
--  Auth: Mechaniker oder Admin; Plate wird normalisiert; tuning_data wird als
--  JSON-Patch geschrieben.
-- =============================================================================

local ESX = exports['es_extended']:getSharedObject()

local function isMechanic(xPlayer)
    if not xPlayer then return false end
    if Config.AllowOutsideJob then return true end
    local job = xPlayer.job and xPlayer.job.name
    return job and Config.MechanicJobs and Config.MechanicJobs[job] or false
end

local function isAdmin(xPlayer)
    if not xPlayer then return false end
    local grp = xPlayer.getGroup and xPlayer.getGroup() or nil
    return grp and Config.AdminGroups and Config.AdminGroups[grp] or false
end

-- Sanitize: nur erlaubte Felder uebernehmen, Zahlen clampen.
local function sanitize(payload)
    if type(payload) ~= 'table' then return nil end
    local out = { mods = {}, toggles = {}, colors = {} }
    if type(payload.mods) == 'table' then
        for k, v in pairs(payload.mods) do
            if type(k) == 'string' and type(v) == 'table'
                and tonumber(v.modType) and tonumber(v.idx) then
                out.mods[k] = { modType = tonumber(v.modType), idx = tonumber(v.idx) }
            end
        end
    end
    if type(payload.toggles) == 'table' then
        for k, v in pairs(payload.toggles) do
            if type(k) == 'string' and type(v) == 'table' and tonumber(v.modType) then
                out.toggles[k] = { modType = tonumber(v.modType), on = v.on and true or false }
            end
        end
    end
    if type(payload.colors) == 'table' then
        for _, ck in ipairs({ 'primary','secondary','pearl','wheel','interior','dashboard' }) do
            local v = tonumber(payload.colors[ck])
            if v then out.colors[ck] = math.max(0, math.min(255, math.floor(v))) end
        end
    end
    if tonumber(payload.wheelType) then out.wheelType = math.max(0, math.min(11, math.floor(payload.wheelType))) end
    if tonumber(payload.livery)     then out.livery    = math.max(-1, math.floor(payload.livery)) end
    if tonumber(payload.windowTint) then out.windowTint = math.max(0, math.min(6, math.floor(payload.windowTint))) end
    return out
end

lib.callback.register('clp_realtuner:visual:apply', function(source, plate, payload)
    local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return false, 'no_player' end
    if not isMechanic(xPlayer) and not isAdmin(xPlayer) then return false, 'not_mechanic' end
    plate = HCM.util.normalizePlate(plate)
    if plate == '' then return false, 'no_plate' end
    local clean = sanitize(payload)
    if not clean then return false, 'bad_payload' end
    local rec = HCM.server.loadRecord(plate); if not rec then return false, 'no_record' end
    local td = rec.tuning_data or {}
    td.visualMods = clean
    HCM.server.applyPatch(plate, { tuning_data = td })
    HCM.server.log(xPlayer, 'visual:apply', plate, rec.vin, {
        slots = clean.mods and (function() local n=0; for _ in pairs(clean.mods) do n=n+1 end; return n end)() or 0,
    })
    return true
end)
