-- =============================================================================
--  clp_realtuner - Audio-FX (Backfire, Turbo-Pfeifen, Getriebe-Scheppern,
--                           Brems-Kreischen, Auspuff-Pops)
-- =============================================================================

HCM_C = HCM_C or {}
HCM_C.audio = HCM_C.audio or {}

local function plateOfCurrent()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return nil, nil end
    return HCM_C.plateOf(veh), veh
end

local lastBoost = 0
local lastGear = 0
local backfireCooldown = 0

CreateThread(function()
    while true do
        Wait(250)
        if not (Config.AudioFX and Config.AudioFX.Enabled) then Wait(1500); goto cont end
        local plate, veh = plateOfCurrent()
        if plate and veh then
            local rec = HCM_C.records[plate]
            if rec then
                local afx = Config.AudioFX
                local rpm = GetVehicleCurrentRpm(veh) or 0
                local speed = GetEntitySpeed(veh) * 3.6
                local throttle = GetControlValue(0, 71) / 255.0
                local gear = GetVehicleCurrentGear(veh) or 1
                local engHealth = rec.engine_health or 100

                -- Backfire bei hoher RPM + schlechtem Motor + Lift-Off
                if engHealth < (afx.BackfireMinHealth or 40) and rpm > 0.6
                   and throttle < 0.05 and GetGameTimer() - backfireCooldown > 2500 then
                    backfireCooldown = GetGameTimer()
                    PlaySoundFromEntity(-1, 'Car_Horn', veh, 'HUD_MINI_GAME_SOUNDSET', false, 0)
                    UseParticleFxAssetNextCall('core')
                    StartParticleFxNonLoopedOnEntity('veh_exhaust_backfire', veh, 0, 0, 0, 0, 0, 0, 0.8, false, false, false)
                end

                -- Turbo-Pfeifen: wenn Turbo-Teil vorhanden + Vollgas
                local hasTurbo = IsToggleModOn(veh, 18)
                if hasTurbo and rpm > 0.7 and throttle > 0.7 then
                    local turboQ = (rec.turbo_health or 100) / 100
                    if math.random() < 0.2 then
                        PlaySoundFromEntity(-1, 'Hacking_Success', veh, 'DLC_HEIST_HACKING_SNAKE_SOUNDS', false, 0)
                    end
                    -- Turbo-Lag-Indicator: weniger Sound bei schlechtem Turbo
                    SetVehicleEnginePowerMultiplier(veh, (turboQ - 0.5) * 8)
                end

                -- Getriebe-Scheppern bei defektem Getriebe + Gangwechsel
                if (rec.transmission_health or 100) < (afx.GearboxRattleBelow or 50) and gear ~= lastGear then
                    lastGear = gear
                    PlaySoundFromEntity(-1, 'CLICK_BACK', veh, 'WEB_NAVIGATION_SOUNDS_PHONE', false, 0)
                end

                -- Brems-Kreischen bei defekten Bremsen + harte Bremse
                if (rec.brake_health or 100) < (afx.BrakeSqueakBelow or 45) then
                    local brake = GetControlValue(0, 72) / 255.0
                    if brake > 0.7 and speed > 20 then
                        if math.random() < 0.15 then
                            PlaySoundFromEntity(-1, 'Bicycle_Slide', veh, 'TAXI_RADIO_SOUNDSET', false, 0)
                        end
                    end
                end

                -- Auspuff-Pops bei Lift-Off mit offener Klappe
                if rec.exhaust_flap and afx.ExhaustPopsOnLiftoff and rpm > 0.5 and throttle < 0.05 then
                    if math.random() < 0.1 then
                        UseParticleFxAssetNextCall('core')
                        StartParticleFxNonLoopedOnEntity('veh_backfire', veh, 0, 0, 0, 0, 0, 0, 0.5, false, false, false)
                    end
                end
            end
        end
        ::cont::
    end
end)
