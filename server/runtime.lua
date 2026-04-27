-- =============================================================================
--  clp_realtuner - Runtime Override Layer
--
--  Liest/Schreibt data/runtime.json auf dem Server und wendet die enthaltenen
--  Overrides live auf Config / Parts / Locations an - ohne Resource-Neustart.
--  Syncronisiert relevante Felder an alle Clients, damit die NUI / Scan ohne
--  Rejoin aktuell bleibt.
-- =============================================================================

HCM = HCM or {}
HCM.runtime = HCM.runtime or {}

local RUNTIME_FILE = 'data/runtime.json'

local function tablelen(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

local function deepMerge(dst, src)
    if type(dst) ~= 'table' or type(src) ~= 'table' then return src end
    for k, v in pairs(src) do
        if type(v) == 'table' and type(dst[k]) == 'table' then
            deepMerge(dst[k], v)
        else
            dst[k] = v
        end
    end
    return dst
end

local function readJSON(path)
    local raw = LoadResourceFile(GetCurrentResourceName(), path)
    if not raw or raw == '' then return nil end
    local ok, v = pcall(json.decode, raw)
    return ok and v or nil
end

local function writeJSON(path, value)
    return SaveResourceFile(GetCurrentResourceName(), path, json.encode(value, { indent = true }), -1)
end

-- Öffentliches State-Objekt --------------------------------------------------
local state = {
    configOverride    = {},
    partsOverride     = {}, -- item -> partial
    partsAdded        = {}, -- item -> full part
    partsRemoved      = {}, -- item -> true
    locationsOverride = {}, -- { paintBooths = {...}, dynoStations = {...}, serviceBays = {...} }
}

local function applyOverrides()
    if next(state.configOverride) ~= nil then
        deepMerge(Config, state.configOverride)
    end
    -- Parts partial overrides / additions / removals
    for item, patch in pairs(state.partsOverride) do
        if Parts[item] then deepMerge(Parts[item], patch) end
    end
    for item, def in pairs(state.partsAdded) do
        Parts[item] = def
    end
    for item in pairs(state.partsRemoved) do
        Parts[item] = nil
    end
    if next(state.locationsOverride or {}) then
        for cat, list in pairs(state.locationsOverride) do
            Locations[cat] = list
        end
    end
end

local function persist()
    writeJSON(RUNTIME_FILE, state)
end

-- Public API -----------------------------------------------------------------

---@return table state kopiert
function HCM.runtime.getState()
    return state
end

function HCM.runtime.getConfigSnapshot()
    return Config
end

function HCM.runtime.getPartsSnapshot()
    return Parts
end

function HCM.runtime.getLocationsSnapshot()
    return Locations
end

---@param keyPath string -- z.B. "Install.MinDuration"
---@param value   any
function HCM.runtime.setConfig(keyPath, value)
    local cur = state.configOverride
    local parts = {}
    for part in keyPath:gmatch('[^.]+') do parts[#parts+1] = part end
    for i = 1, #parts - 1 do
        local k = parts[i]
        cur[k] = cur[k] or {}
        cur = cur[k]
    end
    cur[parts[#parts]] = value
    applyOverrides()
    persist()
    TriggerClientEvent('clp_realtuner:runtimeSync', -1, { kind = 'config', keyPath = keyPath, value = value })
end

function HCM.runtime.setPart(item, def)
    if def == nil then
        Parts[item] = nil
        state.partsAdded[item] = nil
        state.partsOverride[item] = nil
        state.partsRemoved[item] = true
    elseif state.partsAdded[item] or not Parts[item] then
        state.partsAdded[item] = def
        state.partsRemoved[item] = nil
        Parts[item] = def
    else
        state.partsOverride[item] = state.partsOverride[item] or {}
        deepMerge(state.partsOverride[item], def)
        deepMerge(Parts[item], def)
    end
    persist()
    TriggerClientEvent('clp_realtuner:runtimeSync', -1, { kind = 'part', item = item, def = def })
end

function HCM.runtime.setLocation(category, list)
    state.locationsOverride[category] = list
    Locations[category] = list
    persist()
    TriggerClientEvent('clp_realtuner:runtimeSync', -1, { kind = 'location', category = category, list = list })
end

function HCM.runtime.resetAll()
    state = { configOverride = {}, partsOverride = {}, partsAdded = {}, partsRemoved = {}, locationsOverride = {} }
    persist()
    TriggerClientEvent('clp_realtuner:runtimeSync', -1, { kind = 'reset' })
end

-- Initialer Load -------------------------------------------------------------
CreateThread(function()
    local saved = readJSON(RUNTIME_FILE)
    if saved then
        state.configOverride    = saved.configOverride    or {}
        state.partsOverride     = saved.partsOverride     or {}
        state.partsAdded        = saved.partsAdded        or {}
        state.partsRemoved      = saved.partsRemoved      or {}
        state.locationsOverride = saved.locationsOverride or {}
        applyOverrides()
        print(('[realtuner] Runtime-Overrides geladen (%d config, %d parts override, %d parts added)'):format(
            tablelen(state.configOverride), tablelen(state.partsOverride), tablelen(state.partsAdded)
        ))
    end
end)

-- Sync an joinende Spieler ---------------------------------------------------
RegisterNetEvent('clp_realtuner:requestRuntime', function()
    local src = source
    TriggerClientEvent('clp_realtuner:runtimeBootstrap', src, {
        config    = Config,
        parts     = Parts,
        locations = Locations,
    })
end)
