-- =============================================================================
--  clp_realtuner - Kunden-Auftraege Client (Batch 8)
-- =============================================================================

local emergencyBlips = {}

local function askProblem(title)
    local d = lib.inputDialog(title, {
        { type = 'input', label = 'Was ist das Problem?', required = true, placeholder = 'z.B. Motor stottert' },
    })
    return d and d[1] or nil
end

-- Kunde: Notfall-Anruf
RegisterCommand('hcmemergency', function()
    local problem = askProblem('Notfall-Anruf an Werkstatt')
    if not problem then return end
    local ok = lib.callback.await('clp_realtuner:jobs:createEmergency', 5000, problem)
    lib.notify({ title = 'Notfall', description = ok and 'Mechaniker-Dispatch ausgeloest' or 'Fehler', type = ok and 'success' or 'error' })
end, false)
TriggerEvent('chat:addSuggestion', '/hcmemergency', 'Notfall-Anruf an Mechaniker ausloesen')

-- Kunde: Abhol-Service
RegisterCommand('hcmpickup', function()
    local problem = askProblem('Abhol-Service anfordern')
    if not problem then return end
    TriggerServerEvent('clp_realtuner:jobs:requestPickup', problem)
    lib.notify({ title = 'Abhol-Service', description = 'Angefordert – du wirst benachrichtigt', type = 'success' })
end, false)
TriggerEvent('chat:addSuggestion', '/hcmpickup', 'Abhol-Service anfordern')

-- Mechaniker: Auftraege-Liste
RegisterCommand('hcmjobs', function()
    local rows = lib.callback.await('clp_realtuner:jobs:list', 5000, nil, 30) or {}
    local opts = {}
    for _, j in ipairs(rows) do
        local title = ('#%d – %s [%s]'):format(j.id, j.plate or '—', j.status)
        local desc  = (j.problem or '') .. ' | Voranschlag $' .. (j.quote or 0)
        opts[#opts+1] = { title = title, description = desc, onSelect = function()
            lib.registerContext({ id = 'hcmjob_' .. j.id, title = title, options = {
                { title = 'Annehmen', onSelect = function()
                    local ok = lib.callback.await('clp_realtuner:jobs:assign', 5000, j.id)
                    lib.notify({ title = 'Auftrag', description = ok and 'Angenommen' or 'Fehler', type = ok and 'success' or 'error' })
                end },
                { title = 'Voranschlag setzen (fragt den Kunden)', onSelect = function()
                    local d = lib.inputDialog('Voranschlag', {
                        { type = 'number', label = 'Betrag $', required = true, min = 1, default = 500 },
                    })
                    if not d or not d[1] then return end
                    local ok = lib.callback.await('clp_realtuner:jobs:setQuote', 5000, j.id, d[1])
                    lib.notify({ title = 'Voranschlag', description = ok and 'An Kunden geschickt' or 'Fehler', type = ok and 'success' or 'error' })
                end },
                { title = 'Abschliessen (Rechnung + Rating)', onSelect = function()
                    local ok, msg = lib.callback.await('clp_realtuner:jobs:complete', 10000, j.id)
                    lib.notify({ title = 'Abschluss', description = msg or '?', type = ok and 'success' or 'error' })
                end },
            } })
            lib.showContext('hcmjob_' .. j.id)
        end }
    end
    if #opts == 0 then opts[1] = { title = 'Keine Auftraege', disabled = true } end
    lib.registerContext({ id = 'hcm_jobs', title = 'Kunden-Auftraege', options = opts })
    lib.showContext('hcm_jobs')
end, false)
TriggerEvent('chat:addSuggestion', '/hcmjobs', 'Kunden-Auftraege durchsehen')

-- Voranschlag-Antwort beim Kunden
RegisterNetEvent('clp_realtuner:jobs:quotePrompt', function(jobId, plate, amount, mechanicSrc)
    CreateThread(function()
        local ok = lib.alertDialog({
            header = 'Kosten-Voranschlag',
            content = ('Werkstatt hat für Auftrag #%d (%s) einen Betrag von $%s vorgeschlagen.\n\nAkzeptieren?')
                :format(jobId, plate or '—', amount or 0),
            centered = true, cancel = true,
            labels = { confirm = 'Akzeptieren', cancel = 'Ablehnen' },
        })
        TriggerServerEvent('clp_realtuner:jobs:quoteAnswer', jobId, ok == 'confirm', mechanicSrc)
    end)
end)

-- Rating-Prompt beim Kunden
RegisterNetEvent('clp_realtuner:jobs:ratePrompt', function(jobId, mechanicSrc)
    CreateThread(function()
        Wait(1000)
        local d = lib.inputDialog('Bewertung', {
            { type = 'slider', label = 'Sterne (1-5)', min = 1, max = 5, default = 5 },
            { type = 'number', label = 'Trinkgeld $ (0 = nichts)', min = 0, default = 0 },
        })
        if not d then return end
        TriggerServerEvent('clp_realtuner:jobs:rate', jobId, d[1], d[2])
    end)
end)

-- Neue Notfall/Pickup-Broadcasts: Blip setzen
local function setBlip(key, coords, color, name)
    if emergencyBlips[key] then RemoveBlip(emergencyBlips[key]); emergencyBlips[key] = nil end
    local b = AddBlipForCoord(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    SetBlipSprite(b, 280); SetBlipColour(b, color or 1); SetBlipScale(b, 1.2); SetBlipAsShortRange(b, false)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentString(name or 'Realtuner Auftrag'); EndTextCommandSetBlipName(b)
    emergencyBlips[key] = b
    SetTimeout(600000, function()
        if emergencyBlips[key] then RemoveBlip(emergencyBlips[key]); emergencyBlips[key] = nil end
    end)
end

RegisterNetEvent('clp_realtuner:jobs:newEmergency', function(payload)
    setBlip('e' .. (payload.id or 0), payload.coords, 1, ('Notfall: %s'):format(payload.plate or '—'))
end)
RegisterNetEvent('clp_realtuner:jobs:newPickup', function(payload)
    setBlip('p' .. tostring(payload.customer_id or 0), payload.coords, 5, ('Abhol: %s'):format(payload.plate or '—'))
end)
