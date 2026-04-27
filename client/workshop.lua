-- =============================================================================
--  clp_realtuner - Werkstatt-Client (Batch 7)
--   - /hcmworkshop commands
--   - Food-Bar + Boombox Props + Buff
--   - Trinkgeld-Prompt
-- =============================================================================

local function dialogInput(heading, fields)
    return lib.inputDialog(heading, fields) or {}
end

RegisterCommand('hcmworkshop', function()
    local list = lib.callback.await('clp_realtuner:workshop:list', 3000) or {}
    local opts = {}
    for _, w in ipairs(list) do
        opts[#opts+1] = { title = ('%s (Tier %s)'):format(w.name, w.tool_tier or 1),
                          description = w.owner and ('Besitzer: ' .. w.owner) or 'Verfuegbar',
                          onSelect = function()
                              lib.registerContext({
                                  id = 'hcmws_' .. w.id,
                                  title = w.name,
                                  options = {
                                      { title = 'Info anzeigen', onSelect = function()
                                            local ws = lib.callback.await('clp_realtuner:workshop:get', 3000, w.id)
                                            if not ws then return end
                                            lib.alertDialog({
                                                header = ws.name,
                                                content = ('Besitzer: %s\nBank: $%s\nTier: %s\nMitarbeiter: %d\nPreise: %d eingestellt\nLager: %d Artikel')
                                                    :format(ws.owner or '—', ws.bank or 0, ws.tool_tier or 1,
                                                            #ws.employees, #ws.prices, #ws.stock),
                                                centered = true, cancel = false,
                                            })
                                        end },
                                      { title = 'Kaufen (Preis 500k)', onSelect = function()
                                            local ok, msg = lib.callback.await('clp_realtuner:workshop:buy', 10000, w.id, 500000)
                                            lib.notify({ title = 'Werkstatt', description = msg or '?', type = ok and 'success' or 'error' })
                                        end },
                                      { title = 'Mitarbeiter einstellen (ID + Rolle)', onSelect = function()
                                            local d = dialogInput('Einstellen', {
                                                { type = 'number', label = 'Server-ID', required = true },
                                                { type = 'select', label = 'Rolle', options = {
                                                    { value = 'employee', label = 'Mitarbeiter' },
                                                    { value = 'manager',  label = 'Manager' },
                                                }, default = 'employee' },
                                            })
                                            if not d[1] then return end
                                            local ok, msg = lib.callback.await('clp_realtuner:workshop:hireEmployee', 5000, w.id, d[1], d[2])
                                            lib.notify({ title = 'Werkstatt', description = msg or (ok and 'Eingestellt' or 'Fehler'), type = ok and 'success' or 'error' })
                                        end },
                                      { title = 'Preis setzen', onSelect = function()
                                            local d = dialogInput('Preis', {
                                                { type = 'input',  label = 'Service', required = true, placeholder = 'z.B. oil_change' },
                                                { type = 'number', label = 'Preis $',  required = true, min = 0 },
                                            })
                                            if not d[1] then return end
                                            local ok = lib.callback.await('clp_realtuner:workshop:setPrice', 5000, w.id, d[1], d[2])
                                            lib.notify({ title = 'Werkstatt', description = ok and 'Preis gesetzt' or 'Fehler', type = ok and 'success' or 'error' })
                                        end },
                                      { title = 'Teile nachbestellen', onSelect = function()
                                            local d = dialogInput('Nachbestellung (zahlt vom Werkstattkonto)', {
                                                { type = 'input',  label = 'Item-Name',   required = true },
                                                { type = 'number', label = 'Menge',        required = true, default = 10, min = 1 },
                                                { type = 'number', label = 'Preis/Stueck', required = true, default = 150, min = 1 },
                                            })
                                            if not d[1] then return end
                                            local ok, msg = lib.callback.await('clp_realtuner:workshop:orderStock', 7000, w.id, d[1], d[2], d[3])
                                            lib.notify({ title = 'Werkstatt', description = msg or (ok and 'Bestellt' or 'Fehler'), type = ok and 'success' or 'error' })
                                        end },
                                      { title = 'Auszahlung vom Konto (nur Owner)', onSelect = function()
                                            local d = dialogInput('Auszahlung', {
                                                { type = 'number', label = 'Betrag', required = true, min = 1 },
                                            })
                                            if not d[1] then return end
                                            local ok, msg = lib.callback.await('clp_realtuner:workshop:withdraw', 5000, w.id, d[1])
                                            lib.notify({ title = 'Werkstatt', description = msg or (ok and 'Ausgezahlt' or 'Fehler'), type = ok and 'success' or 'error' })
                                        end },
                                  }
                              })
                              lib.showContext('hcmws_' .. w.id)
                          end }
    end
    if #opts == 0 then opts[1] = { title = 'Keine Werkstaetten gefunden', disabled = true } end
    lib.registerContext({ id = 'hcm_workshops', title = 'Werkstaetten', options = opts })
    lib.showContext('hcm_workshops')
end, false)
TriggerEvent('chat:addSuggestion', '/hcmworkshop', 'Werkstatt-Verwaltung')

-- Rechnung generieren (Mechaniker an Kunde)
RegisterCommand('hcmbill', function()
    local d = dialogInput('Rechnung an Kunden', {
        { type = 'number', label = 'Werkstatt-ID',     required = true, default = 1 },
        { type = 'input',  label = 'Kennzeichen',       required = true },
        { type = 'number', label = 'Kunden-Server-ID', required = true },
        { type = 'input',  label = 'Leistung',          required = true, placeholder = 'z.B. Oelwechsel' },
        { type = 'number', label = 'Betrag $',          required = true, min = 1 },
    })
    if not d[1] then return end
    TriggerServerEvent('clp_realtuner:workshop:invoice', d[1], d[2], { { name = d[4], price = d[5] } }, d[3])
end, false)
TriggerEvent('chat:addSuggestion', '/hcmbill', 'Rechnung an Kunden stellen')

-- Trinkgeld-Prompt beim Kunden nach Zahlung
RegisterNetEvent('clp_realtuner:workshop:promptTip', function(wsId, mechanicId, total)
    CreateThread(function()
        Wait(1500)
        local d = dialogInput('Trinkgeld geben?', {
            { type = 'number', label = 'Betrag $ (0 = kein Trinkgeld)', required = true, default = 0, min = 0 },
            { type = 'slider', label = 'Bewertung (Sterne)', min = 1, max = 5, default = 5 },
        })
        if not d then return end
        if (d[1] or 0) > 0 then
            TriggerServerEvent('clp_realtuner:workshop:tip', wsId, mechanicId, d[1])
        end
        if d[2] then
            TriggerServerEvent('clp_realtuner:workshop:rate', 0, d[2])
        end
    end)
end)

-- Food-Bar / Boombox Buffs ---------------------------------------------------
--  Einfacher Buff-System: Kaffee/Food drin = 5 min -10% Fehlerchance bei Einbau
HCM_C = HCM_C or {}
HCM_C.workshopBuffs = HCM_C.workshopBuffs or { untilTs = 0, foodBonus = 0, radioBonus = 0 }

local function applyBuff(kind, seconds, strength)
    HCM_C.workshopBuffs.untilTs = math.max(HCM_C.workshopBuffs.untilTs, os.time() + seconds)
    if kind == 'food' then HCM_C.workshopBuffs.foodBonus  = strength end
    if kind == 'radio' then HCM_C.workshopBuffs.radioBonus = strength end
end

function HCM_C.getWorkshopBuffPenaltyMult()
    if os.time() > (HCM_C.workshopBuffs.untilTs or 0) then return 1.0 end
    local m = 1.0
    m = m * (1.0 - (HCM_C.workshopBuffs.foodBonus or 0))
    m = m * (1.0 - (HCM_C.workshopBuffs.radioBonus or 0))
    return math.max(0.2, m)
end

RegisterNetEvent('clp_realtuner:workshop:consumeFood', function(kind)
    local label = 'Snack'
    if kind == 'coffee' then
        applyBuff('food', 300, 0.10); label = 'Kaffee'
    elseif kind == 'snack' then
        applyBuff('food', 180, 0.06); label = 'Snack'
    elseif kind == 'energy' then
        applyBuff('food', 600, 0.15); label = 'Energy Drink'
    end
    lib.notify({ title = 'Werkstatt-Buff',
        description = ('%s – 5-10 min weniger Fehler'):format(label),
        type = 'success' })
end)

RegisterCommand('hcmcoffee', function() TriggerEvent('clp_realtuner:workshop:consumeFood', 'coffee') end, false)
RegisterCommand('hcmsnack',  function() TriggerEvent('clp_realtuner:workshop:consumeFood', 'snack') end, false)
RegisterCommand('hcmenergy', function() TriggerEvent('clp_realtuner:workshop:consumeFood', 'energy') end, false)

-- Boombox: einfacher Lautsprecher an Player, Radio-Buff
local boomboxActive, boomboxObj = false, nil
RegisterCommand('hcmboombox', function()
    if boomboxActive then
        if boomboxObj and DoesEntityExist(boomboxObj) then DeleteObject(boomboxObj) end
        boomboxObj, boomboxActive = nil, false
        applyBuff('radio', 0, 0)
        lib.notify({ title = 'Boombox', description = 'aus', type = 'inform' })
    else
        local model = GetHashKey('prop_boombox_01')
        RequestModel(model); while not HasModelLoaded(model) do Wait(10) end
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        boomboxObj = CreateObject(model, coords.x, coords.y, coords.z, true, false, false)
        AttachEntityToEntity(boomboxObj, ped, GetPedBoneIndex(ped, 60309),
            0.45, -0.15, 0.0, 0.0, 270.0, 60.0, false, false, false, false, 2, true)
        applyBuff('radio', 3600, 0.05)
        boomboxActive = true
        lib.notify({ title = 'Boombox', description = 'Musik laeuft', type = 'success' })
    end
end, false)
TriggerEvent('chat:addSuggestion', '/hcmboombox', 'Boombox an/aus')
