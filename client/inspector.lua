-- =============================================================================
--  clp_realtuner - 3D Vehicle Inspector (Batch 14a)
--
--  Orbit-Kamera ums Fahrzeug, Live-Preview von visuellen Mod-Slots,
--  Klick auf Bauteil-Bone, Outline-Glow, Confirm/Cancel mit Auto-Revert.
--
--  Slots werden dynamisch aus dem aktuellen Fahrzeug enumeriert
--  (GetNumVehicleMods) -> alle verfuegbaren Varianten kommen ins Menue.
--  Mod-Labels werden ueber GetModTextLabel + GetLabelText aufgeloest und
--  bei FiveM-Fallback via MOD_NAMES + Index ausgegeben.
-- =============================================================================

HCM_C = HCM_C or {}

local SLOT_DEFS = {
    -- Reihenfolge im Menue (Karosserie -> Glass -> Wheels -> Misc)
    { key = 'spoiler',      label = 'Spoiler',           modType = MOD.SPOILER,      bone = 'spoiler',       category = 'body' },
    { key = 'front_bumper', label = 'Frontstoßstange',   modType = MOD.FRONT_BUMPER, bone = 'bumper_f',      category = 'body' },
    { key = 'rear_bumper',  label = 'Heckstoßstange',    modType = MOD.REAR_BUMPER,  bone = 'bumper_r',      category = 'body' },
    { key = 'side_skirt',   label = 'Seitenschweller',   modType = MOD.SIDE_SKIRT,   bone = 'door_dside_f',  category = 'body' },
    { key = 'exhaust',      label = 'Auspuff',           modType = MOD.EXHAUST,      bone = 'exhaust',       category = 'body' },
    { key = 'frame',        label = 'Rahmen-Verstärkung',modType = MOD.FRAME,        bone = 'chassis',       category = 'body' },
    { key = 'grille',       label = 'Kühlergrill',       modType = MOD.GRILLE,       bone = 'bonnet',        category = 'body' },
    { key = 'hood',         label = 'Motorhaube',        modType = MOD.HOOD,         bone = 'bonnet',        category = 'body' },
    { key = 'fender',       label = 'Kotflügel (links)', modType = MOD.FENDER,       bone = 'wing_lf',       category = 'body' },
    { key = 'right_fender', label = 'Kotflügel (rechts)',modType = MOD.RIGHT_FENDER, bone = 'wing_rf',       category = 'body' },
    { key = 'roof',         label = 'Dach',              modType = MOD.ROOF,         bone = 'roof',          category = 'body' },
    { key = 'livery',       label = 'Livery / Wrap',     modType = MOD.LIVERY,       bone = 'chassis',       category = 'paint' },
    { key = 'trim_design',  label = 'Trim Design',       modType = MOD.TRIM_DESIGN,  bone = 'chassis',       category = 'interior' },
    { key = 'ornaments',    label = 'Ornamente',         modType = MOD.ORNAMENTS,    bone = 'chassis',       category = 'interior' },
    { key = 'dashboard',    label = 'Armaturenbrett',    modType = MOD.DASHBOARD,    bone = 'chassis',       category = 'interior' },
    { key = 'dial_design',  label = 'Tachometer',        modType = MOD.DIAL_DESIGN,  bone = 'chassis',       category = 'interior' },
    { key = 'door_speaker', label = 'Tür-Lautsprecher',  modType = MOD.DOOR_SPEAKER, bone = 'door_dside_f',  category = 'interior' },
    { key = 'seats',        label = 'Sitze',             modType = MOD.SEATS,        bone = 'seat_dside_f',  category = 'interior' },
    { key = 'steering',     label = 'Lenkrad',           modType = MOD.STEERING,     bone = 'steeringwheel', category = 'interior' },
    { key = 'shifter',      label = 'Schaltknauf',       modType = MOD.SHIFTER,      bone = 'chassis',       category = 'interior' },
    { key = 'plaques',      label = 'Plaketten',         modType = MOD.PLAQUES,      bone = 'chassis',       category = 'interior' },
    { key = 'speakers',     label = 'Lautsprecher',      modType = MOD.SPEAKERS,     bone = 'chassis',       category = 'interior' },
    { key = 'trunk',        label = 'Kofferraum-Mod',    modType = MOD.TRUNK,        bone = 'boot',          category = 'body' },
    { key = 'engine_block', label = 'Motorblock',        modType = MOD.ENGINE_BLOCK, bone = 'engine',        category = 'engine' },
    { key = 'air_filter',   label = 'Luftfilter',        modType = MOD.AIR_FILTER,   bone = 'engine',        category = 'engine' },
    { key = 'struts',       label = 'Domstrebe',         modType = MOD.STRUTS,       bone = 'engine',        category = 'engine' },
    { key = 'arch_cover',   label = 'Radlauf-Cover',     modType = MOD.ARCH_COVER,   bone = 'wing_lf',       category = 'body' },
    { key = 'aerial',       label = 'Antenne',           modType = MOD.AERIAL,       bone = 'roof',          category = 'body' },
    { key = 'trim',         label = 'Trim',              modType = MOD.TRIM,         bone = 'chassis',       category = 'body' },
    { key = 'tank',         label = 'Tank-Cover',        modType = MOD.TANK,         bone = 'chassis',       category = 'body' },
    { key = 'windows',      label = 'Scheiben-Tönung',   modType = MOD.WINDOWS,      bone = 'window_lf',     category = 'paint' },
    { key = 'plate_holder', label = 'Kennzeichen-Halter',modType = MOD.PLATE_HOLDER, bone = 'numberplate',   category = 'body' },
    { key = 'vanity_plates',label = 'Designer-Schilder', modType = MOD.VANITY_PLATES,bone = 'numberplate',   category = 'body' },
    { key = 'horn',         label = 'Hupe',              modType = MOD.HORNS,        bone = 'engine',        category = 'engine' },
    { key = 'front_wheels', label = 'Vorderräder',       modType = MOD.FRONT_WHEELS, bone = 'wheel_lf',      category = 'wheels' },
    { key = 'back_wheels',  label = 'Hinterräder',       modType = MOD.BACK_WHEELS,  bone = 'wheel_lr',      category = 'wheels' },
}

-- Reifen-Typ (Wheel Style) - nicht via SetVehicleMod sondern SetVehicleWheelType
local WHEEL_TYPES = {
    { id = 0,  label = 'Sport' },
    { id = 1,  label = 'Muscle' },
    { id = 2,  label = 'Lowrider' },
    { id = 3,  label = 'SUV' },
    { id = 4,  label = 'Offroad' },
    { id = 5,  label = 'Tuner' },
    { id = 6,  label = 'High End' },
    { id = 7,  label = 'Bike' },
    { id = 8,  label = 'High End' },
    { id = 9,  label = 'Open Wheel' },
    { id = 10, label = 'Street' },
    { id = 11, label = 'Track' },
}

-- Performance-Toggles (Turbo / Xenon / Tyre Smoke etc. ueber ToggleVehicleMod)
local TOGGLE_DEFS = {
    { key = 'turbo',        label = 'Turbolader',       modType = MOD.TURBO },
    { key = 'xenon',        label = 'Xenon-Scheinwerfer', modType = MOD.XENON },
    { key = 'tyre_smoke',   label = 'Reifenrauch',      modType = MOD.TYRE_SMOKE },
}

-- Lacke (Primary / Secondary / Pearl / Wheel / Interior / Dashboard) ----------
local PAINT_KINDS = {
    { id = 'primary',   label = 'Primärlack',     idx = 0 },
    { id = 'secondary', label = 'Sekundärlack',   idx = 1 },
    { id = 'pearl',     label = 'Perlglanz',      kind = 'pearl' },
    { id = 'wheel',     label = 'Felgen-Farbe',   kind = 'wheel' },
    { id = 'interior',  label = 'Innenraum',      kind = 'interior' },
    { id = 'dashboard', label = 'Dashboard',      kind = 'dashboard' },
}

local PAINT_TYPES = {
    { id = 0, label = 'Standard' },
    { id = 1, label = 'Metallic' },
    { id = 2, label = 'Pearl' },
    { id = 3, label = 'Matt' },
    { id = 4, label = 'Metall' },
    { id = 5, label = 'Chrom' },
}

-- ========================================================================
--  Snapshot fuer Cancel/Revert
-- ========================================================================
local function snapshotVehicle(veh)
    if not DoesEntityExist(veh) then return nil end
    SetVehicleModKit(veh, 0)
    local snap = {
        mods = {},
        toggles = {},
        wheelType = GetVehicleWheelType(veh),
        livery = GetVehicleLivery(veh),
        wheelVar = { GetVehicleModVariation(veh, MOD.FRONT_WHEELS), GetVehicleModVariation(veh, MOD.BACK_WHEELS) },
        windowTint = GetVehicleWindowTint(veh),
        neon = { GetVehicleNeonEnabled(veh, 0), GetVehicleNeonEnabled(veh, 1), GetVehicleNeonEnabled(veh, 2), GetVehicleNeonEnabled(veh, 3) },
        neonColor = { GetVehicleNeonColour(veh) },
        plateIndex = GetVehicleNumberPlateTextIndex(veh),
        primary = nil, secondary = nil, pearl = nil, wheel = nil,
        interior = GetVehicleInteriorColor(veh), dashboard = GetVehicleDashboardColor(veh),
        xenonColor = GetVehicleXenonLightsColor(veh),
        plateColor = GetVehicleNumberPlateText and 0 or 0,
    }
    snap.primary, snap.secondary = GetVehicleColours(veh)
    snap.pearl, snap.wheel = GetVehicleExtraColours(veh)
    for _, def in ipairs(SLOT_DEFS) do
        snap.mods[def.key] = GetVehicleMod(veh, def.modType)
    end
    for _, t in ipairs(TOGGLE_DEFS) do
        snap.toggles[t.key] = IsToggleModOn(veh, t.modType)
    end
    return snap
end

local function restoreSnapshot(veh, snap)
    if not snap or not DoesEntityExist(veh) then return end
    SetVehicleModKit(veh, 0)
    for _, def in ipairs(SLOT_DEFS) do
        local idx = snap.mods[def.key]
        if idx ~= nil then SetVehicleMod(veh, def.modType, idx, false) end
    end
    for _, t in ipairs(TOGGLE_DEFS) do
        ToggleVehicleMod(veh, t.modType, snap.toggles[t.key] and true or false)
    end
    if snap.wheelType then SetVehicleWheelType(veh, snap.wheelType) end
    if snap.livery and snap.livery >= 0 then SetVehicleLivery(veh, snap.livery) end
    if snap.windowTint then SetVehicleWindowTint(veh, snap.windowTint) end
    SetVehicleColours(veh, snap.primary or 0, snap.secondary or 0)
    SetVehicleExtraColours(veh, snap.pearl or 0, snap.wheel or 0)
    SetVehicleInteriorColor(veh, snap.interior or 0)
    SetVehicleDashboardColor(veh, snap.dashboard or 0)
end

-- ========================================================================
--  Mod-Label-Resolver (versucht GTA-internes Label, fallback auf MOD_NAMES)
-- ========================================================================
local function modLabel(veh, modType, modIndex)
    if modIndex < 0 then return 'Original' end
    local labelKey = GetModTextLabel(veh, modType, modIndex)
    if labelKey and labelKey ~= '' and labelKey ~= 'NULL' then
        local txt = GetLabelText(labelKey)
        if txt and txt ~= 'NULL' and txt ~= '' then return txt end
    end
    return ((MOD_NAMES and MOD_NAMES[modType]) or 'Mod') .. ' #' .. tostring(modIndex + 1)
end

-- ========================================================================
--  Zustand
-- ========================================================================
local State = {
    open = false,
    veh = nil,
    cam = nil,
    snapshot = nil,
    pending = {}, -- { [slotKey] = { type='mod'|'toggle'|'paint'|'wheelType'|'livery'|'tint', value=... } }
    yaw = 0.0,
    pitch = -8.0,
    zoom = 6.0,
}

-- Outline auf das Fahrzeug - sanftes Pulsieren waehrend ein Slot gehovert wird
local function setOutline(veh, on)
    if not DoesEntityExist(veh) then return end
    SetEntityDrawOutline(veh, on)
    if on then
        SetEntityDrawOutlineColor(80, 200, 255, 220)
        SetEntityDrawOutlineShader(0)
    end
end

-- ========================================================================
--  Kamera-Handling
-- ========================================================================
local function destroyCam()
    if State.cam then
        RenderScriptCams(false, true, 600, true, true)
        DestroyCam(State.cam, false)
        State.cam = nil
    end
end

local function makeCam(veh)
    destroyCam()
    local cx, cy, cz = table.unpack(GetEntityCoords(veh))
    State.cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', cx, cy, cz + 1.0, 0.0, 0.0, 0.0, 50.0, false, 0)
    SetCamActive(State.cam, true)
    RenderScriptCams(true, true, 500, true, true)
end

local function tickCam(veh)
    if not State.cam or not DoesEntityExist(veh) then return end
    local center = GetEntityCoords(veh)
    local rad = math.rad(State.yaw)
    local pitchRad = math.rad(State.pitch)
    local r = State.zoom
    local cosP = math.cos(pitchRad)
    local x = center.x + math.sin(rad) * r * cosP
    local y = center.y + math.cos(rad) * r * cosP
    local z = center.z + math.sin(pitchRad) * r + 0.6
    SetCamCoord(State.cam, x, y, z)
    PointCamAtCoord(State.cam, center.x, center.y, center.z + 0.4)
end

-- Tastatur / Maus / Wheel
-- LMB(176)=use, RMB(177)=cancel; mouse axis 1/2 via GetDisabledControlNormal
local function pollControls()
    DisableControlAction(0, 1, true)  -- look LR
    DisableControlAction(0, 2, true)  -- look UD
    DisableControlAction(0, 30, true) -- move LR
    DisableControlAction(0, 31, true) -- move FB
    DisableControlAction(0, 71, true) -- accel
    DisableControlAction(0, 72, true) -- brake
    DisableControlAction(0, 75, true) -- exit veh
    DisableControlAction(0, 24, true) -- attack
    DisableControlAction(0, 25, true) -- aim
    DisableControlAction(0, 142, true) -- melee2
    -- MouseRightButton (RMB) hold for orbit drag
    if IsDisabledControlPressed(0, 25) then -- RMB
        local dx = GetDisabledControlNormal(0, 1) * 4.0
        local dy = GetDisabledControlNormal(0, 2) * 4.0
        State.yaw = (State.yaw + dx) % 360
        State.pitch = math.max(-65.0, math.min(60.0, State.pitch - dy))
    end
    -- Wheel zoom
    local wheelUp   = IsDisabledControlPressed(0, 241) -- mouse wheel up
    local wheelDown = IsDisabledControlPressed(0, 242)
    if wheelUp then State.zoom = math.max(2.5, State.zoom - 0.25) end
    if wheelDown then State.zoom = math.min(15.0, State.zoom + 0.25) end
    -- WSAD orbit fallback
    if IsDisabledControlPressed(0, 32) then State.pitch = math.min(60.0, State.pitch + 0.6) end
    if IsDisabledControlPressed(0, 33) then State.pitch = math.max(-65.0, State.pitch - 0.6) end
    if IsDisabledControlPressed(0, 34) then State.yaw = (State.yaw - 1.0) % 360 end
    if IsDisabledControlPressed(0, 35) then State.yaw = (State.yaw + 1.0) % 360 end
    if IsControlJustPressed(0, 322) then -- ESC
        HCM_C.closeInspector(false)
    end
end

-- ========================================================================
--  Apply preview helpers (mutiert das Fahrzeug, persistiert NICHT)
-- ========================================================================
local function previewMod(veh, modType, idx)
    SetVehicleModKit(veh, 0)
    if idx == nil or idx < -1 then return end
    local maxIdx = (GetNumVehicleMods(veh, modType) or 1) - 1
    if idx > maxIdx then idx = maxIdx end
    SetVehicleMod(veh, modType, idx, false)
end

local function previewToggle(veh, modType, on)
    SetVehicleModKit(veh, 0)
    ToggleVehicleMod(veh, modType, on and true or false)
end

local function previewWheelType(veh, t)
    SetVehicleWheelType(veh, tonumber(t) or 0)
    -- Wheel-Index zuruecksetzen, sonst zeigt das alte Wheel falsch an
    SetVehicleMod(veh, MOD.FRONT_WHEELS, 0, false)
    SetVehicleMod(veh, MOD.BACK_WHEELS,  0, false)
end

local function previewLivery(veh, idx)
    if idx and idx >= 0 then SetVehicleLivery(veh, idx) end
end

local function previewWindowTint(veh, idx) SetVehicleWindowTint(veh, tonumber(idx) or 0) end
local function previewPaint(veh, kind, value)
    if kind == 'primary' then
        local _, sec = GetVehicleColours(veh); SetVehicleColours(veh, tonumber(value) or 0, sec or 0)
    elseif kind == 'secondary' then
        local pri = GetVehicleColours(veh); SetVehicleColours(veh, pri or 0, tonumber(value) or 0)
    elseif kind == 'pearl' then
        local _, w = GetVehicleExtraColours(veh); SetVehicleExtraColours(veh, tonumber(value) or 0, w or 0)
    elseif kind == 'wheel' then
        local p = GetVehicleExtraColours(veh); SetVehicleExtraColours(veh, p or 0, tonumber(value) or 0)
    elseif kind == 'interior' then
        SetVehicleInteriorColor(veh, tonumber(value) or 0)
    elseif kind == 'dashboard' then
        SetVehicleDashboardColor(veh, tonumber(value) or 0)
    end
end

-- ========================================================================
--  NUI <-> Lua Bruecke
-- ========================================================================
local function buildSlotsForVehicle(veh)
    SetVehicleModKit(veh, 0)
    local out = { mods = {}, toggles = {}, wheelTypes = WHEEL_TYPES, paint = PAINT_KINDS, paintTypes = PAINT_TYPES }
    for _, def in ipairs(SLOT_DEFS) do
        local count = GetNumVehicleMods(veh, def.modType) or 0
        if count > 0 then
            local current = GetVehicleMod(veh, def.modType)
            local options = {{ idx = -1, label = 'Original' }}
            for i = 0, count - 1 do
                options[#options + 1] = { idx = i, label = modLabel(veh, def.modType, i) }
            end
            out.mods[#out.mods + 1] = {
                key = def.key, label = def.label, category = def.category,
                modType = def.modType, current = current, options = options,
            }
        end
    end
    for _, t in ipairs(TOGGLE_DEFS) do
        out.toggles[#out.toggles + 1] = {
            key = t.key, label = t.label, modType = t.modType,
            on = IsToggleModOn(veh, t.modType),
        }
    end
    out.currentWheelType = GetVehicleWheelType(veh)
    out.currentLivery    = GetVehicleLivery(veh)
    out.liveryCount      = GetVehicleLiveryCount(veh)
    out.currentTint      = GetVehicleWindowTint(veh)
    local pri, sec = GetVehicleColours(veh)
    local pearl, wheel = GetVehicleExtraColours(veh)
    out.currentPaint = {
        primary = pri, secondary = sec, pearl = pearl, wheel = wheel,
        interior = GetVehicleInteriorColor(veh),
        dashboard = GetVehicleDashboardColor(veh),
    }
    out.plate = HCM_C.plateOf(veh) or ''
    out.modelName = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
    return out
end

-- Server-Persistenz nach Confirm
local function persistVisualMods(veh)
    if not DoesEntityExist(veh) then return end
    local plate = HCM_C.plateOf(veh)
    if not plate then return end
    SetVehicleModKit(veh, 0)
    local payload = {
        mods = {},
        toggles = {},
        wheelType = GetVehicleWheelType(veh),
        livery = GetVehicleLivery(veh),
        windowTint = GetVehicleWindowTint(veh),
    }
    for _, def in ipairs(SLOT_DEFS) do
        payload.mods[def.key] = { modType = def.modType, idx = GetVehicleMod(veh, def.modType) }
    end
    for _, t in ipairs(TOGGLE_DEFS) do
        payload.toggles[t.key] = { modType = t.modType, on = IsToggleModOn(veh, t.modType) }
    end
    local pri, sec = GetVehicleColours(veh); local pearl, wheel = GetVehicleExtraColours(veh)
    payload.colors = {
        primary = pri, secondary = sec, pearl = pearl, wheel = wheel,
        interior = GetVehicleInteriorColor(veh),
        dashboard = GetVehicleDashboardColor(veh),
    }
    local ok, msg = lib.callback.await('clp_realtuner:visual:apply', 5000, plate, payload)
    if ok then
        lib.notify({ title = 'Tuning', description = 'Visuelles Tuning gespeichert.', type = 'success' })
    else
        lib.notify({ title = 'Tuning', description = 'Server: ' .. tostring(msg or 'Fehler'), type = 'error' })
    end
end

-- ========================================================================
--  Public API
-- ========================================================================
function HCM_C.openInspector(veh)
    if State.open then return end
    if not veh or veh == 0 then
        local p = GetEntityCoords(PlayerPedId())
        veh = GetClosestVehicle(p.x, p.y, p.z, 8.0, 0, 70)
    end
    if not veh or veh == 0 or not DoesEntityExist(veh) then
        lib.notify({ title = 'Inspector', description = 'Kein Fahrzeug in der Nähe.', type = 'error' })
        return
    end
    if GetIsVehicleEngineRunning(veh) and (Config.Install and Config.Install.RequireEngineOff) then
        lib.notify({ title = 'Inspector', description = 'Motor muss aus sein.', type = 'error' })
        return
    end
    HCM_C.getRecord(veh) -- preload
    State.open = true
    State.veh = veh
    State.snapshot = snapshotVehicle(veh)
    State.yaw, State.pitch, State.zoom = 25.0, -10.0, 6.5
    setOutline(veh, true)
    makeCam(veh)
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true) -- damit Maus-Drag und Wheel an Lua kommen
    SendNUIMessage({
        type = 'inspector:open',
        slots = buildSlotsForVehicle(veh),
    })
    -- Hauptloop
    CreateThread(function()
        while State.open do
            tickCam(State.veh)
            pollControls()
            Wait(0)
        end
    end)
end

function HCM_C.closeInspector(commit)
    if not State.open then return end
    local veh = State.veh
    if not commit and State.snapshot then restoreSnapshot(veh, State.snapshot) end
    State.open = false
    setOutline(veh, false)
    destroyCam()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ type = 'inspector:close' })
    if commit then persistVisualMods(veh) end
    State.veh, State.snapshot = nil, nil
end

-- NUI Callbacks ---------------------------------------------------------------
RegisterNUICallback('inspector:setMod', function(data, cb)
    local veh = State.veh
    if not veh or not data then cb({}); return end
    if data.modType ~= nil and data.idx ~= nil then
        previewMod(veh, tonumber(data.modType), tonumber(data.idx))
    end
    cb({ ok = true })
end)

RegisterNUICallback('inspector:setToggle', function(data, cb)
    local veh = State.veh
    if not veh or not data then cb({}); return end
    previewToggle(veh, tonumber(data.modType), data.on and true or false)
    cb({ ok = true })
end)

RegisterNUICallback('inspector:setWheelType', function(data, cb)
    if State.veh and data then previewWheelType(State.veh, tonumber(data.id) or 0) end
    cb({ ok = true })
end)

RegisterNUICallback('inspector:setLivery', function(data, cb)
    if State.veh and data then previewLivery(State.veh, tonumber(data.idx) or -1) end
    cb({ ok = true })
end)

RegisterNUICallback('inspector:setTint', function(data, cb)
    if State.veh and data then previewWindowTint(State.veh, tonumber(data.idx) or 0) end
    cb({ ok = true })
end)

RegisterNUICallback('inspector:setPaint', function(data, cb)
    if State.veh and data then previewPaint(State.veh, tostring(data.kind or ''), tonumber(data.value) or 0) end
    cb({ ok = true })
end)

RegisterNUICallback('inspector:confirm', function(_, cb)
    HCM_C.closeInspector(true)
    cb({ ok = true })
end)

RegisterNUICallback('inspector:cancel', function(_, cb)
    HCM_C.closeInspector(false)
    cb({ ok = true })
end)

-- Command + ox_target Action
RegisterCommand('hcminspect', function()
    HCM_C.openInspector()
end, false)

-- ========================================================================
--  Re-Apply: Visual-Mods aus tuning_data.visualMods nach Spawn anwenden.
--  Wird vom periodischen apply-Loop in client/tune_advanced.lua aufgerufen.
-- ========================================================================
function HCM_C.applyVisualMods(veh, rec)
    if not veh or not DoesEntityExist(veh) then return end
    local td = rec and rec.tuning_data
    local v  = td and td.visualMods
    if type(v) ~= 'table' then return end
    SetVehicleModKit(veh, 0)
    if type(v.mods) == 'table' then
        for _, def in ipairs(SLOT_DEFS) do
            local entry = v.mods[def.key]
            if entry and tonumber(entry.idx) then
                local maxIdx = (GetNumVehicleMods(veh, def.modType) or 1) - 1
                local idx = entry.idx
                if idx > maxIdx then idx = maxIdx end
                if idx >= -1 then SetVehicleMod(veh, def.modType, idx, false) end
            end
        end
    end
    if type(v.toggles) == 'table' then
        for _, t in ipairs(TOGGLE_DEFS) do
            local entry = v.toggles[t.key]
            if entry then ToggleVehicleMod(veh, t.modType, entry.on and true or false) end
        end
    end
    if v.wheelType then SetVehicleWheelType(veh, v.wheelType) end
    if v.livery and v.livery >= 0 and GetVehicleLiveryCount(veh) > 0 then SetVehicleLivery(veh, v.livery) end
    if v.windowTint then SetVehicleWindowTint(veh, v.windowTint) end
    if type(v.colors) == 'table' then
        local pri = tonumber(v.colors.primary)   or select(1, GetVehicleColours(veh)) or 0
        local sec = tonumber(v.colors.secondary) or select(2, GetVehicleColours(veh)) or 0
        SetVehicleColours(veh, pri, sec)
        local pearl = tonumber(v.colors.pearl) or select(1, GetVehicleExtraColours(veh)) or 0
        local wcol  = tonumber(v.colors.wheel) or select(2, GetVehicleExtraColours(veh)) or 0
        SetVehicleExtraColours(veh, pearl, wcol)
        if v.colors.interior  then SetVehicleInteriorColor(veh,  v.colors.interior) end
        if v.colors.dashboard then SetVehicleDashboardColor(veh, v.colors.dashboard) end
    end
end

-- Sicherheits-Cleanup bei Resource Stop
AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() and State.open then
        HCM_C.closeInspector(false)
    end
end)
