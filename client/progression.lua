-- =============================================================================
--  clp_realtuner - Progression Client (Batch 6)
--   - Tutorial beim ersten Mal
--   - Rank-Up-Button (Pruefung versuchen)
--   - Portfolio-Liste abrufbar
-- =============================================================================

HCM_C = HCM_C or {}

local TUTORIAL_STEPS = {
    { title = 'Willkommen beim Realtuner',
      text  = 'Als Mechaniker/Lehrling lernst du hier die Grundlagen kennen. Druecke JETZT weiter, um durchzugehen.' },
    { title = 'Fahrzeug analysieren',
      text  = 'Ziele mit ox_target auf eine Motorhaube oder das Fahrzeug und waehle "Fahrzeug analysieren". Das scannt alle installierten Teile und zeigt moegliche Upgrades.' },
    { title = 'Teile einbauen',
      text  = 'Oeffne die Motorhaube, ziele darauf und waehle "Teil einbauen". Du brauchst die entsprechenden Inventar-Items (z.B. engine_block_forged, turbo_stage2). Der Motor muss aus sein, Fahrzeug darf sich nicht bewegen.' },
    { title = 'ECU Flash',
      text  = 'Mit dem ECU-Flasher-Item kannst du AFR, Drehmoment und Fuel Map einstellen. Unsichere Werte -> Motorschaden!' },
    { title = 'Wartung',
      text  = 'Oel, Kuehlmittel, Bremsfluessigkeit und Zuendkerzen muessen regelmaessig gewechselt werden. Ignorieren fuehrt zu Schaeden.' },
    { title = 'Diagnose-Tools',
      text  = 'OBD-Scanner (Live-Daten), Endoskop (Motorinnenraum), Bremsenpruefstand, Emissions-Test, DTC Deep-Dive - alles im Werkzeug-Set.' },
    { title = 'Tablet',
      text  = 'Das Mechaniker-Tablet zeigt Diagnose, Teile, Upgrades, Historie. Nutze es bei jeder Arbeit.' },
    { title = 'Rank-Up',
      text  = 'Mit genug Arbeiten und Spezialisierungs-Punkten kannst du zu Geselle und Meister aufsteigen. Siehe Tablet -> Profil.' },
}

local function runTutorial()
    for i, step in ipairs(TUTORIAL_STEPS) do
        local ok = lib.alertDialog({
            header = ('Tutorial (%d/%d) – %s'):format(i, #TUTORIAL_STEPS, step.title),
            content = step.text,
            centered = true,
            cancel = true,
            labels = { confirm = 'Weiter', cancel = 'Abbrechen' },
        })
        if ok ~= 'confirm' then break end
    end
    TriggerServerEvent('clp_realtuner:progression:markTutorial')
end

CreateThread(function()
    Wait(5000)
    local done = lib.callback.await('clp_realtuner:progression:getTutorialDone', 5000)
    if not done then
        Wait(4000)
        lib.notify({ title = 'Realtuner Tutorial',
            description = 'Befehl /hcmtutorial fuer die Anleitung.', type = 'inform', duration = 8000 })
    end
end)

RegisterCommand('hcmtutorial', runTutorial, false)
TriggerEvent('chat:addSuggestion', '/hcmtutorial', 'Startet das Realtuner Tutorial')

-- Rank-Up UI
RegisterCommand('hcmrank', function()
    local ok, msg = lib.callback.await('clp_realtuner:progression:attemptRankUp', 5000)
    lib.notify({ title = 'Beförderung', description = msg or '?', type = ok and 'success' or 'error', duration = 8000 })
end, false)
TriggerEvent('chat:addSuggestion', '/hcmrank', 'Beförderung beantragen (Lehrling -> Geselle -> Meister)')

-- Portfolio-Abruf fuer Tablet
RegisterNUICallback('tablet:portfolio', function(_, cb)
    local rows = lib.callback.await('clp_realtuner:progression:portfolio', 3000, 100) or {}
    cb({ items = rows })
end)

RegisterNUICallback('tablet:certificates', function(_, cb)
    local rows = lib.callback.await('clp_realtuner:progression:certificates', 3000) or {}
    cb({ items = rows })
end)
