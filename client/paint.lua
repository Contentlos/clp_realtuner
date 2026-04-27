-- =============================================================================
--  clp_realtuner - Lackierungssystem mit FX
-- =============================================================================

HCM_C = HCM_C or {}

local ox = exports.ox_inventory

-- FX helper -----------------------------------------------------------------
local function loadParticle(dict)
    if HasNamedPtfxAssetLoaded(dict) then return true end
    RequestNamedPtfxAsset(dict)
    local deadline = GetGameTimer() + 5000
    while not HasNamedPtfxAssetLoaded(dict) and GetGameTimer() < deadline do Wait(50) end
    return HasNamedPtfxAssetLoaded(dict)
end

local function sprayFX(entity, duration, rgb)
    local dict = Config.Paint.ParticleDict
    local name = Config.Paint.ParticleName
    if not loadParticle(dict) then return end

    local start = GetGameTimer()
    RequestAnimDict('timetable@floyd@cryingonbed@base')
    TaskPlayAnim(PlayerPedId(), 'timetable@floyd@cryingonbed@base', 'base', 2.0, 2.0, -1, 1, 0, false, false, false)

    PlaySoundFromEntity(-1, Config.Paint.SoundName or 'Start_Spray', PlayerPedId(), Config.Paint.SoundSet, true, 0)

    while GetGameTimer() - start < duration do
        -- Nebel an mehreren Stellen um das Fahrzeug erzeugen
        local bones = { 'chassis', 'bonnet', 'boot', 'roof', 'door_dside_f', 'door_pside_f' }
        for _, b in ipairs(bones) do
            local bi = GetEntityBoneIndexByName(entity, b)
            if bi ~= -1 then
                local pos = GetWorldPositionOfEntityBone(entity, bi)
                UseParticleFxAssetNextCall(dict)
                if rgb then SetParticleFxNonLoopedColour(rgb[1]/255, rgb[2]/255, rgb[3]/255) end
                StartParticleFxNonLoopedAtCoord(name, pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, 0.6, false, false, false)
            end
        end
        Wait(400)
    end
    ClearPedTasks(PlayerPedId())
end

-- UI zur Farbauswahl --------------------------------------------------------
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
}

function HCM_C.openPaint(entity)
    if (ox:GetItemCount(Config.Paint.Tool) or 0) < 1 then
        lib.notify({ title = 'Lack', description = 'Du brauchst: ' .. Config.Paint.Tool, type = 'error' })
        return
    end

    local typeInput = lib.inputDialog('Lackierung', {
        { type = 'select', label = 'Lackart', required = true, options = {
            { value = 'matte',    label = 'Matt' },
            { value = 'metallic', label = 'Metallic' },
            { value = 'pearl',    label = 'Pearlescent' },
        }},
    })
    if not typeInput then return end
    local colorType = typeInput[1]

    local opts = {}
    for i, c in ipairs(COLOR_MAP) do
        opts[#opts+1] = {
            title = c.label,
            icon = 'palette',
            onSelect = function()
                HCM_C.performPaint(entity, colorType, c.rgb)
            end,
        }
    end
    lib.registerContext({ id = 'clp_realtuner_paintcolor', title = 'Farbe wählen', options = opts })
    lib.showContext('clp_realtuner_paintcolor')
end

function HCM_C.performPaint(entity, colorType, primaryRGB)
    local plate = HCM_C.plateOf(entity)
    if not plate then return end
    local done = lib.progressCircle({
        label = 'Lackiere Fahrzeug...',
        duration = Config.Paint.Duration,
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, move = true, combat = true },
    })
    if not done then return end

    -- FX Thread parallel (nicht blockierend, weil progressCircle vorher schon beendet ist)
    CreateThread(function()
        sprayFX(entity, Config.Paint.Duration, primaryRGB)
    end)

    -- Farbe direkt anwenden
    SetVehicleModColor_1(entity, 3, 0, 0) -- custom primary
    SetVehicleCustomPrimaryColour(entity, primaryRGB[1], primaryRGB[2], primaryRGB[3])
    if colorType == 'matte' then
        SetVehicleModColor_1(entity, 3, 3, 0)
    elseif colorType == 'pearl' then
        SetVehicleExtraColours(entity, 0, 150)
    end

    local ok, result = lib.callback.await('clp_realtuner:paint', 3000, plate, colorType, primaryRGB, nil, nil)
    if ok then
        lib.notify({
            title = 'Lack',
            description = result.perfect and ('Perfekte Lackierung (%d%%)'):format(result.quality) or ('Lackierung mit Schönheitsfehlern (%d%%)'):format(result.quality),
            type = result.perfect and 'success' or 'warning',
        })
    end
end
