-- =============================================================================
--  clp_realtuner - Performance-Profiler (shared)
-- =============================================================================
--  Simples, allocation-armes Messwerkzeug fuer Ausfuehrungszeit & Aufrufzaehler
--  pro benanntem System. Wird automatisch vom Admin-Panel eingelesen.
-- =============================================================================

HCM = HCM or {}
HCM.profiler = HCM.profiler or {}

local stats = {} -- name -> { count, totalMs, maxMs, lastMs }

local function now()
    return GetGameTimer and GetGameTimer() or (os.clock() * 1000)
end

---@param name string
---@return number startToken
function HCM.profiler.start(name)
    return now()
end

---@param name string
---@param startToken number
function HCM.profiler.stop(name, startToken)
    local dt = now() - (startToken or now())
    local s = stats[name]
    if not s then
        s = { count = 0, totalMs = 0.0, maxMs = 0.0, lastMs = 0.0 }
        stats[name] = s
    end
    s.count    = s.count + 1
    s.totalMs  = s.totalMs + dt
    s.lastMs   = dt
    if dt > s.maxMs then s.maxMs = dt end
end

--- Wrappt eine Funktion so, dass jeder Aufruf automatisch gemessen wird.
---@param name string
---@param fn function
---@return function wrapped
function HCM.profiler.wrap(name, fn)
    return function(...)
        local t = HCM.profiler.start(name)
        local results = { fn(...) }
        HCM.profiler.stop(name, t)
        return table.unpack(results)
    end
end

---@return table
function HCM.profiler.snapshot()
    local out = {}
    for name, s in pairs(stats) do
        out[#out+1] = {
            name    = name,
            count   = s.count,
            totalMs = math.floor(s.totalMs * 100) / 100,
            avgMs   = s.count > 0 and math.floor((s.totalMs / s.count) * 100) / 100 or 0.0,
            maxMs   = math.floor(s.maxMs * 100) / 100,
            lastMs  = math.floor(s.lastMs * 100) / 100,
        }
    end
    table.sort(out, function(a, b) return a.totalMs > b.totalMs end)
    return out
end

function HCM.profiler.reset()
    stats = {}
end

return HCM.profiler
