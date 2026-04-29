-- =============================================================================
--  clp_realtuner - Lackierungssystem (Batch 14d - Paint FX Overhaul)
--
--  3-Layer Workflow:
--    1) Grundierung (Primer)         -> sichtbarer Grau-Cast, deckt schlecht
--    2) Basislack (Color)            -> Farbe wird sichtbar, Particle-Nebel
--    3) Klarlack (Clear)             -> Glanz/Reflex, GTA pearl-Channel
--
--  Zwischen jeder Phase: Drying-Phase mit eigenen Particle (leichter Dunst,
--  trocknendes Anschein), Quality-Calc.
--
--  Live-Quality-Tracking: waehrend des Spruehens wird permanent die Bewegung
--  des Mechanikers ausgewertet. Hektische Bewegung -> ungleichmaessig
--  (-quality). Auch der Abstand zum Fahrzeug zaehlt: zu nah -> Naselauf,
--  zu weit -> Overspray. Sweet-Spot 1.2..2.4m.
-- =============================================================================

HCM_C = HCM_C or {}

local ox = exports.ox_inventory

-- Particle Helpers ---------------------------------------------------------
local function loadParticle(dict)
    if HasNamedPtfxAssetLoaded(dict) then return true end
    RequestNamedPtfxAsset(dict)
    local deadline = GetGameTimer() + 5000
    while not HasNamedPtfxAssetLoaded(dict) and GetGameTimer() < deadline do Wait(50) end
    return HasNamedPtfxAssetLoaded(dict)
end

-- Spray-Gun-Bone: rechte Hand des Mechanikers; falls nicht verfuegbar
-- fallen wir auf Brust + Vorwaerts-Offset zurueck.
local function gunCoord(ped)
    local bi = GetPedBoneIndex(ped, 28422) -- IK_R_Hand
    if bi ~= -1 then
        local p = GetWorldPositionOfEntityBone(ped, bi)
        return p.x, p.y, p.z
    end
    local fwd = GetEntityForwardVector(ped)
    local p = GetEntityCoords(ped)
    return p.x + fwd.x * 0.4, p.y + fwd.y * 0.4, p.z + 0.6
end

-- Sweet-spot Distanzbewertung. Floor ist bewusst 0.3, damit ein
-- konsequentes Stehen ausserhalb des Sweet-Spots nicht ueber alle Phasen
-- multipliziert auf 0% Quality runterdrueckt. 0% wird durch Bewegung
-- (movementQuality) und sehr schlechte Skill-Mods erreicht.
local function distQuality(ped, veh)
    local pp = GetEntityCoords(ped)
    local vp = GetEntityCoords(veh)
    local dx = pp.x - vp.x; local dy = pp.y - vp.y
    local d = math.sqrt(dx * dx + dy * dy)
    if d < 0.8 or d > 3.0 then return 0.3 end
    if d >= 1.2 and d <= 2.4 then return 1.0 end
    return 0.6 -- Penalty-Zone
end

-- Bewegungs-Quality: stehen + Strafen langsam = perfekt; rennen = schlecht
local function movementQuality(ped)
    local v = GetEntityVelocity(ped) -- vector3
    local mag = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    if mag < 0.1  then return 1.0 end
    if mag < 0.6  then return 0.85 end
    if mag < 1.4  then return 0.6  end
    return 0.25
end

-- Eine Spray-Phase mit Live-Tracking
-- @param phase 'primer' | 'base' | 'clear'
-- @param duration ms
-- @param rgb { r, g, b }
-- @return {quality (0..1), avgDist, avgMove}
local function sprayPhase(veh, phase, duration, rgb)
    local dict = (phase == 'primer') and 'core' or 'core'
    local name = (phase == 'primer') and 'ent_amb_smoke_foundry'
              or (phase == 'clear')  and 'ent_amb_smoke_foundry'
              or 'ent_amb_aerosol_can_spray'
    if not loadParticle(dict) then return { quality = 0.5, avgDist = 0.0, avgMove = 0.0 } end

    -- Sound-Loop laenger durchspielen lassen
    local soundId = GetSoundId()
    PlaySoundFromEntity(soundId, 'Start_Spray', PlayerPedId(),
        Config.Paint.SoundSet or 'PAINT_DRIPS_SOUNDS', true, 0)

    -- Spray-Anim einmalig - lib.requestAnimDict blockiert bis geladen
    lib.requestAnimDict('weapons@projectile@', 5000)
    if HasAnimDictLoaded('weapons@projectile@') then
        TaskPlayAnim(PlayerPedId(), 'weapons@projectile@', 'throw_m_fb_stand',
            2.0, 2.0, -1, 49, 0, false, false, false)
    end

    local start = GetGameTimer()
    local samples = { dist = 0.0, move = 0.0, count = 0 }
    while GetGameTimer() - start < duration do
        local ped = PlayerPedId()
        local x, y, z = gunCoord(ped)
        UseParticleFxAssetNextCall(dict)
        if rgb and phase == 'base' then
            SetParticleFxNonLoopedColour(rgb[1]/255, rgb[2]/255, rgb[3]/255)
        elseif phase == 'primer' then
            SetParticleFxNonLoopedColour(0.6, 0.6, 0.6)  -- grau
        else
            SetParticleFxNonLoopedColour(0.95, 0.95, 1.0) -- klarlack-weiss
        end
        SetParticleFxNonLoopedAlpha(0.55)
        StartParticleFxNonLoopedAtCoord(name, x, y, z, 0.0, 0.0, 0.0, 0.55, false, false, false)
        samples.dist  = samples.dist + distQuality(ped, veh)
        samples.move  = samples.move + movementQuality(ped)
        samples.count = samples.count + 1
        Wait(150)
    end
    StopSound(soundId); ReleaseSoundId(soundId)
    ClearPedSecondaryTask(PlayerPedId())

    if samples.count == 0 then samples.count = 1 end
    local avgDist = samples.dist / samples.count
    local avgMove = samples.move / samples.count
    return { quality = math.max(0.1, avgDist * avgMove), avgDist = avgDist, avgMove = avgMove }
end

-- Drying-Phase ---
local function dryingPhase(veh, seconds)
    local dict = 'core'
    if not loadParticle(dict) then Wait(seconds * 1000); return end
    -- Particles parallel zum progressCircle laufen lassen.
    local total = seconds * 1000
    local stop = false
    CreateThread(function()
        local start = GetGameTimer()
        while not stop and GetGameTimer() - start < total do
            if DoesEntityExist(veh) then
                local center = GetEntityCoords(veh)
                UseParticleFxAssetNextCall(dict)
                SetParticleFxNonLoopedColour(0.85, 0.85, 0.9)
                SetParticleFxNonLoopedAlpha(0.18)
                StartParticleFxNonLoopedAtCoord('ent_amb_smoke_foundry',
                    center.x + math.random() - 0.5, center.y + math.random() - 0.5, center.z + 0.6,
                    0.0, 0.0, 0.0, 0.4, false, false, false)
            end
            Wait(300)
        end
    end)
    lib.progressCircle({
        label = 'Trocknet...',
        duration = total,
        useWhileDead = false, canCancel = false,
        disable = { car = true, move = false, combat = true },
    })
    stop = true
end

-- ===========================================================================
--  Lack-Type-Tabelle
-- ===========================================================================
local PAINT_TYPES = {
    matte    = { primerS = 12, baseS = 18, clearS = 0,  drying = 5,  baseScore = 0.85 },
    metallic = { primerS = 12, baseS = 22, clearS = 8,  drying = 6,  baseScore = 0.90 },
    pearl    = { primerS = 14, baseS = 24, clearS = 12, drying = 8,  baseScore = 1.00 },
}

local COLOR_MAP = {
    { label = 'Schwarz', rgb = { 0, 0, 0 } },
    { label = 'Weiß',    rgb = { 240, 240, 240 } },
    { label = 'Rot',     rgb = { 190, 25, 25 } },
    { label = 'Blau',    rgb = { 25, 70, 190 } },
    { label = 'Grün',    rgb = { 25, 150, 70 } },
    { label = 'Gelb',    rgb = { 230, 200, 30 } },
    { label = 'Orange',  rgb = { 230, 120, 30 } },
    { label = 'Lila',    rgb = { 130, 50, 170 } },
    { label = 'Grau',    rgb = { 90, 90, 95 } },
    { label = 'Gold',    rgb = { 200, 170, 60 } },
    { label = 'Cyan',    rgb = { 30, 200, 220 } },
    { label = 'Pink',    rgb = { 240, 80, 160 } },
}

-- Tool-Items pro Lackart -----------------------------------------------------
local TOOL_REQ = {
    matte    = { Config.Paint.Tool, 'paint_can_matt' },
    metallic = { Config.Paint.Tool, 'paint_can_metallic', 'paint_clearcoat' },
    pearl    = { Config.Paint.Tool, 'paint_can_pearl', 'paint_clearcoat', 'paint_primer' },
}

local function checkTools(req)
    for _, item in ipairs(req) do
        if (ox:GetItemCount(item) or 0) < 1 then
            return false, 'Du brauchst: ' .. item
        end
    end
    return true
end

-- ===========================================================================
--  Public API: openPaint -> performPaint
-- ===========================================================================
function HCM_C.openPaint(entity)
    if (ox:GetItemCount(Config.Paint.Tool) or 0) < 1 then
        lib.notify({ title = 'Lack', description = 'Du brauchst: ' .. Config.Paint.Tool, type = 'error' })
        return
    end
    local typeInput = lib.inputDialog('Lackierung', {
        { type = 'select', label = 'Lackart', required = true, options = {
            { value = 'matte',    label = 'Matt' },
            { value = 'metallic', label = 'Metallic (mit Klarlack)' },
            { value = 'pearl',    label = 'Pearlescent (Profi, mit Grundierung)' },
        }},
    })
    if not typeInput then return end
    local colorType = typeInput[1]
    local ok, msg = checkTools(TOOL_REQ[colorType] or {})
    if not ok then lib.notify({ title = 'Lack', description = msg, type = 'error' }); return end

    local opts = {}
    for _, c in ipairs(COLOR_MAP) do
        opts[#opts+1] = {
            title = c.label,
            icon  = 'palette',
            onSelect = function() HCM_C.performPaint(entity, colorType, c.rgb) end,
        }
    end
    lib.registerContext({ id = 'clp_realtuner_paintcolor', title = 'Farbe wählen', options = opts })
    lib.showContext('clp_realtuner_paintcolor')
end

function HCM_C.performPaint(entity, colorType, primaryRGB)
    local plate = HCM_C.plateOf(entity)
    if not plate then return end
    local def = PAINT_TYPES[colorType] or PAINT_TYPES.matte

    local results = { primer = nil, base = nil, clear = nil }

    -- Phasen-Anzahl dynamisch (matte hat z.B. keinen Klarlack)
    local totalPhases = 1 -- base ist immer da
    if def.primerS > 0 then totalPhases = totalPhases + 1 end
    if def.clearS  > 0 then totalPhases = totalPhases + 1 end
    local phaseNum = 0

    -- Verbrauchsmaterial vor jedem Schritt verbrauchen (lokal optimistisch,
    -- der Server entfernt es ueber den paint:apply Callback nochmal sicher).
    if def.primerS > 0 then
        phaseNum = phaseNum + 1
        lib.notify({ title = 'Lack', description = ('Phase %d/%d: Grundierung'):format(phaseNum, totalPhases), type = 'inform' })
        results.primer = sprayPhase(entity, 'primer', def.primerS * 1000, nil)
        dryingPhase(entity, math.floor(def.drying * 0.6))
    end

    phaseNum = phaseNum + 1
    lib.notify({ title = 'Lack', description = ('Phase %d/%d: Basislack'):format(phaseNum, totalPhases), type = 'inform' })
    results.base = sprayPhase(entity, 'base', def.baseS * 1000, primaryRGB)
    -- Farbe sofort anwenden
    SetVehicleModColor_1(entity, 3, 0, 0)
    SetVehicleCustomPrimaryColour(entity, primaryRGB[1], primaryRGB[2], primaryRGB[3])
    if colorType == 'matte' then SetVehicleModColor_1(entity, 3, 3, 0) end

    if def.clearS > 0 then
        dryingPhase(entity, math.floor(def.drying))
        phaseNum = phaseNum + 1
        lib.notify({ title = 'Lack', description = ('Phase %d/%d: Klarlack'):format(phaseNum, totalPhases), type = 'inform' })
        results.clear = sprayPhase(entity, 'clear', def.clearS * 1000, nil)
        if colorType == 'pearl' then SetVehicleExtraColours(entity, 0, 150) end
        dryingPhase(entity, math.floor(def.drying))
    else
        dryingPhase(entity, math.floor(def.drying))
    end

    -- Gesamt-Quality-Score: gewichteter Mittelwert der durchgefuehrten Phasen
    -- (base haelt das hoechste Gewicht). Multiplikation wuerde drei knappe
    -- 0.3-Werte auf ~0% drucken obwohl der Vorgang vollstaendig erfolgte.
    local sum, weight = 0.0, 0.0
    if results.primer then sum = sum + results.primer.quality * 0.25; weight = weight + 0.25 end
    if results.base   then sum = sum + results.base.quality   * 0.55; weight = weight + 0.55 end
    if results.clear  then sum = sum + results.clear.quality  * 0.20; weight = weight + 0.20 end
    if weight <= 0 then weight = 1 end
    local q = (sum / weight) * def.baseScore
    local quality = math.floor(math.max(0, math.min(1, q)) * 100 + 0.5)

    local ok, result = lib.callback.await('clp_realtuner:paint', 4000,
        plate, colorType, primaryRGB, nil, quality)
    if ok then
        local desc = ('Quality %d%% · %s · D=%.0f%% · M=%.0f%%'):format(
            (result and result.quality) or quality, colorType,
            ((results.base and results.base.avgDist) or 0) * 100,
            ((results.base and results.base.avgMove) or 0) * 100)
        lib.notify({
            title = 'Lack',
            description = desc,
            type = ((result and result.quality or quality) >= 80) and 'success' or 'warning',
        })
    end
end
