-- =============================================================================
--  clp_realtuner - Diagnose-Tools (Batch 2)
--   - OBD-Scanner (Live-Data-Stream)
--   - Endoskop (Motor-Inner-Kamera)
--   - Bremsenpruefstand (Prop-Station)
--   - Emissions-/TUeV-Test
--   - Motor-Anhoer-Modus (Sound-basiert)
--   - DTC-Deep-Dive
--   - Drehmoment-Schluessel
--   - Hebebuehne
-- =============================================================================

HCM_C = HCM_C or {}
HCM_C.diagTools = HCM_C.diagTools or {}

local function nearestVehicle(maxDist)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local veh = GetClosestVehicle(coords.x, coords.y, coords.z, maxDist or 5.0, 0, 71)
    if veh == 0 then
        veh = GetVehiclePedIsIn(ped, false)
    end
    return (veh ~= 0 and DoesEntityExist(veh)) and veh or nil
end

local function sendNui(action, data) SendNUIMessage({ action = action, data = data }) end

-- ============================================================================
-- OBD-Scanner: Live-Data-Stream
-- ============================================================================
local obdActive = false
local obdTargetVeh = nil

local function obdOpen(veh)
    obdActive = true
    obdTargetVeh = veh
    SetNuiFocus(true, true)
    sendNui('diag:obdOpen', {
        plate = HCM_C.plateOf(veh),
        model = GetDisplayNameFromVehicleModel(GetEntityModel(veh)),
    })
end

local function obdClose()
    obdActive = false
    obdTargetVeh = nil
    SetNuiFocus(false, false)
    sendNui('diag:obdClose', {})
end

CreateThread(function()
    while true do
        Wait(250)
        if obdActive and obdTargetVeh and DoesEntityExist(obdTargetVeh) then
            local veh = obdTargetVeh
            local rec = HCM_C.getRecord(veh)
            if rec then
                sendNui('diag:obdUpdate', {
                    rpm = math.floor((GetVehicleCurrentRpm(veh) or 0) * 8000),
                    rpmPct = GetVehicleCurrentRpm(veh) or 0,
                    speed = math.floor((GetEntitySpeed(veh) or 0) * 3.6),
                    coolantTemp = rec.coolant_temp or 85,
                    oilQuality = rec.oil_quality or 100,
                    oilKm = rec.oil_km or 0,
                    battery = rec.battery or 100,
                    sparkPlug = rec.spark_plug or 100,
                    brakeFluid = rec.brake_fluid or 100,
                    coolant = rec.coolant or 100,
                    fuelLeak = rec.fuel_leak or 0,
                    rust = rec.rust or 0,
                    engineHP = rec.engine_health or 100,
                    transmissionHP = rec.transmission_health or 100,
                    brakeHP = rec.brake_health or 100,
                    turboHP = rec.turbo_health or 100,
                    suspensionHP = rec.suspension_health or 100,
                    headlight = rec.headlight_state or 100,
                    rearlight = rec.rearlight_state or 100,
                    tcOn = rec.tc_enabled ~= false,
                    absOn = rec.abs_enabled ~= false,
                    flap = rec.exhaust_flap or false,
                    ecuMap = rec.ecu_map or 'stock',
                    dtc = HCM.util.generateDTC(rec) or {},
                    dtcDeep = HCM.util.explainDTC(rec) or {},
                })
            end
        end
    end
end)

RegisterNUICallback('diag:obdClose', function(_, cb) obdClose(); cb({ ok = true }) end)

exports('openOBD', function(veh) if veh then obdOpen(veh) end end)

-- Item-Use Hook: OBD-Scanner
RegisterNetEvent('clp_realtuner:useItem:obd', function()
    local veh = nearestVehicle(6.0)
    if not veh then
        lib.notify({ title = 'OBD', description = 'Kein Fahrzeug in Reichweite.', type = 'error' })
        return
    end
    obdOpen(veh)
end)

-- ============================================================================
-- Endoskop: Motor-Inner-Kamera (Render-Target Style)
-- ============================================================================
local endoscopeCam = nil

local function endoscopeStart(veh)
    if endoscopeCam then return end
    if not veh or not DoesEntityExist(veh) then return end
    -- Motorhaube muss offen sein
    if GetVehicleDoorAngleRatio(veh, 4) < 0.5 then
        SetVehicleDoorOpen(veh, 4, false, false)
        Wait(500)
    end
    local engineBone = GetEntityBoneIndexByName(veh, 'engine')
    if engineBone == -1 then engineBone = GetEntityBoneIndexByName(veh, 'bonnet') end
    local pos = engineBone ~= -1 and GetWorldPositionOfEntityBone(veh, engineBone)
        or (GetEntityCoords(veh) + vector3(0.0, 1.5, 0.8))
    endoscopeCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(endoscopeCam, pos.x, pos.y, pos.z + 0.1)
    PointCamAtEntity(endoscopeCam, veh, 0.0, 0.0, 0.0, true)
    SetCamFov(endoscopeCam, 80.0)
    SetCamActive(endoscopeCam, true)
    RenderScriptCams(true, true, 500, true, true)
    sendNui('diag:endoscopeOpen', { plate = HCM_C.plateOf(veh) })
    SetNuiFocusKeepInput(true)
    SetNuiFocus(true, false)
    -- Live-Stream: Innen-Zustand
    local rec = HCM_C.getRecord(veh)
    if rec then
        sendNui('diag:endoscopeReport', {
            carbon = math.min(100, (100 - (rec.engine_health or 100)) * 0.8),
            oilSludge = math.min(100, (100 - (rec.oil_quality or 100))),
            sparkPlugWear = 100 - (rec.spark_plug or 100),
            turboBlades = math.min(100, (100 - (rec.turbo_health or 100))),
            leak = rec.fuel_leak or 0,
            coolantResidue = math.min(100, (100 - (rec.coolant or 100))),
            rust = rec.rust or 0,
        })
    end
end

local function endoscopeStop()
    if endoscopeCam then
        RenderScriptCams(false, true, 400, true, true)
        DestroyCam(endoscopeCam, false)
        endoscopeCam = nil
    end
    sendNui('diag:endoscopeClose', {})
    SetNuiFocus(false, false)
end

RegisterNUICallback('diag:endoscopeClose', function(_, cb) endoscopeStop(); cb({ ok = true }) end)

RegisterNetEvent('clp_realtuner:useItem:endoscope', function()
    local veh = nearestVehicle(5.0)
    if not veh then
        lib.notify({ title = 'Endoskop', description = 'Kein Fahrzeug in Reichweite.', type = 'error' })
        return
    end
    endoscopeStart(veh)
end)

-- ============================================================================
-- Bremsenpruefstand: Prop-Station
-- ============================================================================
local function brakeStandRun(veh)
    if not veh or not DoesEntityExist(veh) then return end
    local rec = HCM_C.getRecord(veh)
    if not rec then return end
    lib.progressBar({
        label = 'Bremsenpruefstand laeuft...',
        duration = 8000,
        canCancel = false,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'amb@world_human_clipboard@male@base', clip = 'base' },
    })
    -- Ergebnis
    local bh = rec.brake_health or 100
    local bf = rec.brake_fluid or 100
    local leftKN = (bh / 100) * (6.0 + math.random() * 0.5) - math.random() * 0.3
    local rightKN = (bh / 100) * (6.0 + math.random() * 0.5) - math.random() * 0.3
    local imbalance = math.abs(leftKN - rightKN) / math.max(leftKN, rightKN) * 100
    local grade = bh > 80 and 'A' or bh > 60 and 'B' or bh > 40 and 'C' or bh > 20 and 'D' or 'F'
    local report = {
        plate = HCM_C.plateOf(veh),
        leftKN = math.floor(leftKN * 10) / 10,
        rightKN = math.floor(rightKN * 10) / 10,
        imbalance = math.floor(imbalance * 10) / 10,
        brakeFluid = bf,
        grade = grade,
        legal = bh >= 45 and bf >= 25 and imbalance < 25,
    }
    sendNui('diag:brakeStandResult', report)
    SetNuiFocus(true, true)
    TriggerServerEvent('clp_realtuner:diag:logBrakeStand', report)
end

exports('runBrakeStand', brakeStandRun)

RegisterNUICallback('diag:brakeStandClose', function(_, cb) SetNuiFocus(false, false); cb({ ok = true }) end)

-- ============================================================================
-- Emissions/TUeV-Test
-- ============================================================================
local function emissionsTest(veh)
    if not veh or not DoesEntityExist(veh) then return end
    local rec = HCM_C.getRecord(veh)
    if not rec then return end
    lib.progressBar({
        label = 'Emissionen werden gemessen...',
        duration = 10000,
        canCancel = false,
        disable = { move = true, car = true, combat = true },
    })
    -- CO/HC/NOx-Werte aus Motor-/Turbo-/ECU-Zustand ableiten
    local eh = rec.engine_health or 100
    local ecuMap = rec.ecu_map or 'stock'
    local co = math.max(0.1, (100 - eh) / 20 + (ecuMap == 'race' and 1.2 or 0))
    local hc = math.max(50, 300 * (100 - eh) / 100 + math.random(20))
    local nox = math.max(100, 500 * (100 - eh) / 120 + math.random(40))
    local thresholds = Config.TUeV and Config.TUeV.FailThresholds or {}
    local failures = {}
    if eh < (thresholds.engine_health or 40) then failures[#failures+1] = 'Motor unter Grenzwert' end
    if (rec.brake_health or 100) < (thresholds.brake_health or 45) then failures[#failures+1] = 'Bremsen unter Grenzwert' end
    if (rec.suspension_health or 100) < (thresholds.suspension_health or 40) then failures[#failures+1] = 'Fahrwerk unter Grenzwert' end
    if (rec.brake_fluid or 100) < (thresholds.brake_fluid or 25) then failures[#failures+1] = 'Bremsfluessigkeit' end
    if (rec.coolant or 100) < (thresholds.coolant or 25) then failures[#failures+1] = 'Kuehlmittel' end
    if (rec.rust or 0) > (thresholds.rust or 70) then failures[#failures+1] = 'Rost kritisch' end
    if (rec.headlight_state or 100) < (thresholds.headlight_state or 40) then failures[#failures+1] = 'Scheinwerfer' end
    if (rec.rearlight_state or 100) < (thresholds.rearlight_state or 40) then failures[#failures+1] = 'Ruecklichter' end
    if rec.windshield_broken then failures[#failures+1] = 'Windschutzscheibe' end
    if co > 3.0 then failures[#failures+1] = 'CO zu hoch (' .. math.floor(co*100)/100 .. '%)' end
    local passed = #failures == 0
    local report = {
        plate = HCM_C.plateOf(veh),
        co = math.floor(co * 100) / 100,
        hc = math.floor(hc),
        nox = math.floor(nox),
        ecuMap = ecuMap,
        failures = failures,
        passed = passed,
    }
    sendNui('diag:emissionsResult', report)
    SetNuiFocus(true, true)
    if passed then
        TriggerServerEvent('clp_realtuner:diag:tuevPass', HCM_C.plateOf(veh))
    end
end
exports('runEmissionsTest', emissionsTest)

RegisterNUICallback('diag:emissionsClose', function(_, cb) SetNuiFocus(false, false); cb({ ok = true }) end)

-- ============================================================================
-- Motor-Anhoer-Modus (Sound mit Zustand)
-- ============================================================================
local function listenMode(veh)
    if not veh or not DoesEntityExist(veh) then return end
    local rec = HCM_C.getRecord(veh)
    if not rec then return end
    local eh = rec.engine_health or 100
    local th = rec.transmission_health or 100
    local tu = rec.turbo_health or 100
    local desc
    if eh < 30 then desc = 'Motor klopft stark und laeuft unregelmaessig.'
    elseif eh < 60 then desc = 'Motor laeuft rau, Fehlzuendungen hoerbar.'
    else desc = 'Motor laeuft ruhig und gleichmaessig.' end
    if th < 40 then desc = desc .. ' Getriebe scheppert beim Leerlauf.' end
    if tu < 40 then desc = desc .. ' Turbo pfeift und zischt, moeglicher Lagerschaden.' end
    if (rec.spark_plug or 100) < 30 then desc = desc .. ' Motor spottert, Zuendkerzen wahrscheinlich defekt.' end
    if (rec.coolant or 100) < 30 then desc = desc .. ' Gluckerndes Geraeusch - Kuehlmittel zu niedrig.' end
    SetVehicleEngineOn(veh, true, false, false)
    lib.progressBar({
        label = 'Motor anhoeren...',
        duration = 6000,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })
    lib.notify({ title = 'Motor-Analyse', description = desc, type = 'inform', duration = 12000 })
end
exports('runListenMode', listenMode)

-- ============================================================================
-- DTC-Deep-Dive (erweiterte Code-Erklaerung)
-- ============================================================================
local function dtcDeep(veh)
    if not veh or not DoesEntityExist(veh) then return end
    local rec = HCM_C.getRecord(veh)
    if not rec then return end
    sendNui('diag:dtcDeep', {
        plate = HCM_C.plateOf(veh),
        codes = HCM.util.explainDTC(rec) or {},
    })
    SetNuiFocus(true, true)
end
exports('runDtcDeep', dtcDeep)

RegisterNUICallback('diag:dtcDeepClose', function(_, cb) SetNuiFocus(false, false); cb({ ok = true }) end)

-- ============================================================================
-- Hebebuehne (Prop + Animation, nutzt nearest Workshop station)
-- ============================================================================
local liftActive = {}

exports('toggleLift', function(veh)
    if not veh or not DoesEntityExist(veh) then return end
    if liftActive[veh] then
        -- absenken
        local pos = GetEntityCoords(veh)
        SetVehicleOnGroundProperly(veh)
        FreezeEntityPosition(veh, false)
        SetEntityCoords(veh, pos.x, pos.y, pos.z - 1.2, false, false, false, false)
        liftActive[veh] = nil
        lib.notify({ title = 'Hebebuehne', description = 'Abgesenkt.', type = 'inform' })
    else
        local pos = GetEntityCoords(veh)
        FreezeEntityPosition(veh, true)
        SetEntityCoords(veh, pos.x, pos.y, pos.z + 1.2, false, false, false, false)
        liftActive[veh] = true
        lib.notify({ title = 'Hebebuehne', description = 'Fahrzeug oben. Unterboden zugaenglich.', type = 'success' })
    end
end)

-- ============================================================================
-- Drehmoment-Schluessel (Skill-Buff beim Einbau)
-- ============================================================================
-- Wird von client/install.lua eingelesen wenn Item vorhanden ist
HCM_C.hasTorqueWrench = function()
    local count = exports.ox_inventory:Search('count', 'torque_wrench') or 0
    return (type(count) == 'number' and count > 0)
end

-- ============================================================================
-- ox_target Registrierung (Aktionen an Fahrzeug-Zonen)
-- ============================================================================
CreateThread(function()
    -- globale Fahrzeug-Aktionen fuer Diagnose-Tools
    local ok, target = pcall(function() return exports.ox_target end)
    if not ok or not target then return end
    exports.ox_target:addGlobalVehicle({
        {
            name = 'clp_realtuner_obd',
            label = 'OBD-Scanner anschliessen',
            icon = 'fa-solid fa-plug',
            distance = 2.0,
            items = { 'obd_scanner' },
            canInteract = function(entity) return HCM_C.hasJob and HCM_C.hasJob() or true end,
            onSelect = function(data) obdOpen(data.entity) end,
        },
        {
            name = 'clp_realtuner_endo',
            label = 'Endoskop ansetzen',
            icon = 'fa-solid fa-camera',
            distance = 2.0,
            items = { 'endoscope' },
            onSelect = function(data) endoscopeStart(data.entity) end,
            canInteract = function(entity)
                return GetVehicleDoorAngleRatio(entity, 4) > 0.2
            end,
        },
        {
            name = 'clp_realtuner_listen',
            label = 'Motor anhoeren',
            icon = 'fa-solid fa-headphones',
            distance = 2.0,
            onSelect = function(data) listenMode(data.entity) end,
            canInteract = function(entity)
                return GetVehicleDoorAngleRatio(entity, 4) > 0.2
            end,
        },
        {
            name = 'clp_realtuner_dtc',
            label = 'DTC Deep-Dive lesen',
            icon = 'fa-solid fa-code',
            distance = 2.0,
            items = { 'obd_scanner' },
            onSelect = function(data) dtcDeep(data.entity) end,
        },
        {
            name = 'clp_realtuner_brake',
            label = 'Bremsenpruefstand starten',
            icon = 'fa-solid fa-gauge-high',
            distance = 2.5,
            onSelect = function(data) brakeStandRun(data.entity) end,
            canInteract = function(entity)
                -- Nur bei Workshop-Station / Admin-Zone
                return HCM_C.inWorkshopZone and HCM_C.inWorkshopZone() or Config.Debug
            end,
        },
        {
            name = 'clp_realtuner_emissions',
            label = 'Emissionen / TUeV pruefen',
            icon = 'fa-solid fa-smog',
            distance = 2.5,
            onSelect = function(data) emissionsTest(data.entity) end,
            canInteract = function(entity)
                return HCM_C.inWorkshopZone and HCM_C.inWorkshopZone() or Config.Debug
            end,
        },
        {
            name = 'clp_realtuner_lift',
            label = 'Hebebuehne toggle',
            icon = 'fa-solid fa-elevator',
            distance = 3.0,
            onSelect = function(data) exports[GetCurrentResourceName()]:toggleLift(data.entity) end,
            canInteract = function(entity)
                return HCM_C.inWorkshopZone and HCM_C.inWorkshopZone() or Config.Debug
            end,
        },
    })
end)

-- Stub fuer Workshop-Zone-Check (Batch 7 implementiert das richtig)
HCM_C.inWorkshopZone = HCM_C.inWorkshopZone or function() return true end
HCM_C.hasJob = HCM_C.hasJob or function() return true end
