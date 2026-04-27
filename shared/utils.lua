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
    -- Batch 1/2 Zusatzcodes
    if (data.oil_quality or 100) < 30 then table.insert(codes, 'P0520 - Oeldruck-Sensor (Qualitaet niedrig)') end
    if (data.oil_km or 0) > 6000 then table.insert(codes, 'B1000 - Service faellig (Oelwechsel)') end
    if (data.spark_plug or 100) < 35 then table.insert(codes, 'P0301-P0304 - Zuendkerzenverschleiss') end
    if (data.battery or 100) < 30 then table.insert(codes, 'P0562 - Bordnetzspannung niedrig') end
    if (data.brake_fluid or 100) < 30 then table.insert(codes, 'C1201 - Bremsfluessigkeit niedrig') end
    if (data.coolant or 100) < 30 then table.insert(codes, 'P0128 - Kuehlmittelstand niedrig') end
    if (data.coolant_temp or 85) > 105 then table.insert(codes, 'P0217 - Motor ueberhitzt aktuell') end
    if (data.fuel_leak or 0) > 10 then table.insert(codes, 'P0455 - Kraftstoffsystem undicht') end
    if (data.rust or 0) > 60 then table.insert(codes, 'B1500 - Rostbefall kritisch') end
    if (data.headlight_state or 100) < 40 or (data.rearlight_state or 100) < 40 then
        table.insert(codes, 'B2404 - Beleuchtung defekt')
    end
    return codes
end

-- Tiefer DTC-Deep-Dive: Beschreibung, Ursache, Fix-Empfehlung
-- Rueckgabe: { code=string, title=string, severity=1-3, cause=string, fix=string }[]
function HCM.util.explainDTC(data)
    local db = {
        { key='P0300', min=function(d) return (d.engine_health or 100) < 50 end,
          title='Zuendaussetzer', severity=2,
          cause='Defekte Zuendkerzen, abgenutzter Motor, zu mageres/fettes Gemisch',
          fix='Zuendkerzen tauschen, ECU zuruecksetzen, Motor ueberholen' },
        { key='P0217', min=function(d) return (d.coolant_temp or 85) > 105 or (d.engine_health or 100) < 25 end,
          title='Motor-Ueberhitzung', severity=3,
          cause='Kuehlmittel leer, Kuehler defekt, Thermostat klemmt',
          fix='Kuehlmittel nachfuellen, Kuehlsystem spuelen, Zahnriemen pruefen' },
        { key='P0234', min=function(d) return (d.turbo_health or 100) < 40 end,
          title='Turbo-Ueberdruck', severity=2,
          cause='Wastegate defekt, Ladedruckregler hin, Auspuff verstopft',
          fix='Turbo tauschen, Wastegate pruefen, ECU-Map neu laden' },
        { key='P0700', min=function(d) return (d.transmission_health or 100) < 40 end,
          title='Getriebesteuerung', severity=2,
          cause='Oelmangel, Magnetventil, Getriebeoel alt',
          fix='Getriebeoel wechseln, Steuergeraet pruefen' },
        { key='C1214', min=function(d) return (d.brake_health or 100) < 40 end,
          title='Bremsdruckverlust', severity=3,
          cause='Leck in Bremsleitung, Bremsbelaege verschlissen',
          fix='Bremsbelaege tauschen, Bremsfluessigkeit auffuellen' },
        { key='C0710', min=function(d) return (d.suspension_health or 100) < 30 end,
          title='Fahrwerkssensor', severity=1,
          cause='Stossdaempfer verschlissen, Federbein defekt',
          fix='Fahrwerk tauschen' },
        { key='P0172', min=function(d) local e=d.ecu_state or {} return e.afr and (e.afr<11.5 or e.afr>15.0) end,
          title='Gemisch-Toleranz', severity=2,
          cause='Unsichere ECU-Map, Luftfilter verstopft, Einspritzer alt',
          fix='ECU reset auf stock, Luftfilter tauschen' },
        { key='P0520', min=function(d) return (d.oil_quality or 100) < 30 end,
          title='Oeldruck niedrig', severity=2,
          cause='Oelstand, Oelpumpe, Oelfilter',
          fix='Oelwechsel, Oelpumpe pruefen' },
        { key='B1000', min=function(d) return (d.oil_km or 0) > 6000 end,
          title='Service faellig', severity=1,
          cause='Wartungsintervall ueberschritten',
          fix='Kompletten Service durchfuehren (Oel, Filter, Zuendkerzen)' },
        { key='P0301', min=function(d) return (d.spark_plug or 100) < 35 end,
          title='Zuendkerzenverschleiss', severity=2,
          cause='Kerzen abgenutzt nach hoher km-Leistung',
          fix='Zuendkerzensatz (alle 4) tauschen' },
        { key='P0562', min=function(d) return (d.battery or 100) < 30 end,
          title='Batteriespannung', severity=2,
          cause='Batterie alt, Lichtmaschine, Standzeit-Entladung',
          fix='Batterie laden oder tauschen' },
        { key='C1201', min=function(d) return (d.brake_fluid or 100) < 30 end,
          title='Bremsfluessigkeit', severity=3,
          cause='Leck im Bremskreis',
          fix='Bremskreis entlueften und auffuellen' },
        { key='P0128', min=function(d) return (d.coolant or 100) < 30 end,
          title='Kuehlmittelstand', severity=2,
          cause='Leck, Verdampfung, Ueberhitzung',
          fix='Kuehlmittel auffuellen, Leck suchen' },
        { key='P0455', min=function(d) return (d.fuel_leak or 0) > 10 end,
          title='Kraftstoff-Leck', severity=3,
          cause='Defekte Dichtung, Unfallschaden',
          fix='Tank-/Leitungsleck beheben' },
        { key='B1500', min=function(d) return (d.rust or 0) > 60 end,
          title='Rostbefall', severity=2,
          cause='Lange Standzeit im Regen, Lackschaeden',
          fix='Rostentferner + Lackversiegelung' },
    }
    local out = {}
    for _, entry in ipairs(db) do
        if entry.min(data) then
            out[#out+1] = {
                code = entry.key, title = entry.title, severity = entry.severity,
                cause = entry.cause, fix = entry.fix,
            }
        end
    end
    return out
end
