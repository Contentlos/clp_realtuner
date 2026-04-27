-- =============================================================================
--  clp_realtuner - Hardcore Schadenssystem
--
--  Realistische Verschleiß- und Ausfall-Simulation. Läuft nur auf dem
--  Besitzer-Client des Fahrzeugs und pusht Deltas an den Server.
-- =============================================================================

HCM_C = HCM_C or {}

local lastDamageTick = {}  -- netId -> { engine=timestamp, ... }

-- Smoke / Backfire / Stall --------------------------------------------------
local function emitSmoke(veh)
    if not HasNamedPtfxAssetLoaded('core') then
        RequestNamedPtfxAsset('core')
        repeat Wait(50) until HasNamedPtfxAssetLoaded('core')
    end
    UseParticleFxAssetNextCall('core')
    SetPtfxAssetNextCall('core')
    StartParticleFxLoopedOnEntity('ent_amb_smoke_foundry', veh, 0.0, 0.9, 0.8, 0.0, 0.0, 0.0, 0.6, false, false, false)
end

local function backfire(veh)
    -- Visuelle / akustische Fehlzündung (kein Fahrzeugschaden)
    local bone = GetEntityBoneIndexByName(veh, 'exhaust')
    if bone == -1 then bone = 0 end
    if HasNamedPtfxAssetLoaded('core') then
        UseParticleFxAssetNextCall('core')
        StartParticleFxNonLoopedOnEntityBone('exp_air_vehicle_bullet_fx', veh, 0.0, -2.0, 0.2, 0.0, 0.0, 0.0, bone, 1.0, false, false, false)
    end
    PlaySoundFromEntity(-1, 'Vehicle_Backfire', veh, 'DLC_Gunrunning_Explosions_Sounds', true, 0)
end

-- Ticker --------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(Config.Damage.Interval or 2000)
        if not Config.Damage.Enabled then goto cont end

        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped, false) then goto cont end
        local veh = GetVehiclePedIsIn(ped, false)
        if GetPedInVehicleSeat(veh, -1) ~= ped then goto cont end
        if NetworkGetEntityOwner(veh) ~= PlayerId() then goto cont end

        local plate = HCM_C.plateOf(veh)
        local rec   = HCM_C.getRecord(veh)
        if not plate or not rec then goto cont end

        local netId = NetworkGetNetworkIdFromEntity(veh)
        lastDamageTick[netId] = lastDamageTick[netId] or {}

        local rpm      = GetVehicleCurrentRpm(veh)        -- 0..1
        local engine   = GetVehicleEngineHealth(veh)      -- -4000..1000
        local engineN  = math.max(0, engine) / 1000       -- 0..1

        -- 1) Überhitzung
        if engineN < Config.Damage.OverheatThreshold and rpm > 0.8 then
            TriggerServerEvent('clp_realtuner:damage', plate, 'engine', 0.4)
        end

        -- 2) Turbo Überdruck
        local turboHealth = (rec.turbo_health or 100) / 100
        if turboHealth < 0.6 and rpm > Config.Damage.TurboBoostDamageAbove then
            TriggerServerEvent('clp_realtuner:damage', plate, 'turbo', 0.5)
            if math.random() < 0.15 then backfire(veh) end
        end

        -- 3) Getriebe Redline
        if rpm > Config.Damage.TransmissionRedline then
            TriggerServerEvent('clp_realtuner:damage', plate, 'transmission', 0.3)
        end

        -- 4) Bremsen Hitze
        if GetEntitySpeed(veh) > 20 and IsControlPressed(0, 72) then -- LShift/Brake
            TriggerServerEvent('clp_realtuner:damage', plate, 'brakes', 0.2)
        end

        -- 5) Aufhängung Sprünge (GetEntityVelocity -> vector3)
        local vel = GetEntityVelocity(veh)
        if vel and math.abs(vel.z or 0.0) > 6.0 then
            TriggerServerEvent('clp_realtuner:damage', plate, 'suspension', 0.8)
        end

        -- Visuelle Effekte basierend auf aktuellem Zustand
        if (rec.engine_health or 100) < Config.Damage.SmokeParticleMinHealth then
            if math.random() < 0.3 then emitSmoke(veh) end
        end

        -- Hardcore: komplettes Abwürgen bei sehr niedrigem Motorzustand
        if (rec.engine_health or 100) < Config.Damage.StallMinHealth then
            if math.random() < 0.25 then
                SetVehicleEngineOn(veh, false, true, true)
                lib.notify({ title = 'Motor', description = 'Motor abgewürgt!', type = 'error' })
            end
        end

        ::cont::
    end
end)

-- Collision Events -> Komponenten-Schaden -----------------------------------
CreateThread(function()
    local lastEngine
    while true do
        Wait(500)
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if NetworkGetEntityOwner(veh) == PlayerId() then
                local eh = GetVehicleEngineHealth(veh)
                if lastEngine and eh < lastEngine - 25 then
                    local plate = HCM_C.plateOf(veh)
                    if plate then
                        TriggerServerEvent('clp_realtuner:damage', plate, 'engine', (lastEngine - eh) * 0.02)
                    end
                end
                lastEngine = eh
            end
        else
            lastEngine = nil
        end
    end
end)
