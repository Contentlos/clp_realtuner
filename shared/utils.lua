-- =============================================================================
--  clp_hardcore_mechanic - Shared Utilities
-- =============================================================================

HCM = HCM or {}
HCM.util = {}

local VIN_ALPHABET = 'ABCDEFGHJKLMNPRSTUVWXYZ0123456789' -- keine I,O,Q (ISO 3779)
local VIN_LEN = 17

local function seedrandom(seed)
    math.randomseed(seed)
    for _ = 1, 3 do math.random() end
end

-- Generiert einen deterministischen 17-stelligen VIN aus Kennzeichen + Model + Timestamp
function HCM.util.generateVIN(plate, model, timestamp)
    plate = (plate or ''):gsub('%s', ''):upper()
    model = tostring(model or 'UNK')
    timestamp = timestamp or os.time()
    local seed = timestamp
    for i = 1, #plate do seed = (seed * 131 + plate:byte(i)) % 2147483647 end
    for i = 1, #model do seed = (seed * 131 + model:byte(i)) % 2147483647 end
    seedrandom(seed)
    local out = {}
    for i = 1, VIN_LEN do
        local idx = math.random(1, #VIN_ALPHABET)
        out[i] = VIN_ALPHABET:sub(idx, idx)
    end
    return table.concat(out)
end

function HCM.util.round(n, d)
    local m = 10 ^ (d or 0)
    return math.floor(n * m + 0.5) / m
end

function HCM.util.clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function HCM.util.trim(s)
    return (s or ''):match('^%s*(.-)%s*$')
end

function HCM.util.normalizePlate(plate)
    return HCM.util.trim(plate):upper()
end

-- Health -> Status Label (für normale Spieler)
function HCM.util.statusLabel(health)
    if health == nil then return 'unbekannt' end
    if health >= 85 then return 'gut'
    elseif health >= 60 then return 'ok'
    elseif health >= 35 then return 'bedenklich'
    elseif health >= 15 then return 'kritisch'
    else return 'defekt' end
end

function HCM.util.shallowCopy(t)
    local r = {}
    for k, v in pairs(t or {}) do r[k] = v end
    return r
end

-- Minimal OBD-II style Fehlercodes basierend auf Zuständen
function HCM.util.generateDTC(data)
    local codes = {}
    if (data.engine_health or 100) < 50 then table.insert(codes, 'P0300 - Zündaussetzer erkannt') end
    if (data.engine_health or 100) < 25 then table.insert(codes, 'P0217 - Motor Überhitzung') end
    if (data.turbo_health or 100) < 40 then table.insert(codes, 'P0234 - Turbo Überdruck') end
    if (data.transmission_health or 100) < 40 then table.insert(codes, 'P0700 - Getriebesteuerung') end
    if (data.brake_health or 100) < 40 then table.insert(codes, 'C1214 - Bremsdruckverlust') end
    if (data.suspension_health or 100) < 30 then table.insert(codes, 'C0710 - Fahrwerksensor Fehler') end
    local ecu = data.ecu_state or {}
    if ecu.afr and (ecu.afr < 11.5 or ecu.afr > 15.0) then
        table.insert(codes, 'P0172/P0171 - Gemisch ausserhalb Toleranz')
    end
    return codes
end
