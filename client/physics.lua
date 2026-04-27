-- =============================================================================
--  clp_realtuner - Physik-Toggles (TC, ABS, Aero/Downforce, Auspuffklappe)
-- =============================================================================

HCM_C = HCM_C or {}
HCM_C.physics = HCM_C.physics or {}

local function plateOfCurrent()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return nil, nil end
    return HCM_C.plateOf(veh), veh
end

local function toggle(key, label)
    local plate, veh = plateOfCurrent()
    if not plate then return end
    local rec = HCM_C.records[plate]
    if not rec then return end
    local field = key == 'tc' and 'tc_enabled' or key == 'abs' and 'abs_enabled' or 'exhaust_flap'
    local new = not rec[field]
    rec[field] = new
    TriggerServerEvent('clp_realtuner:physics:toggle', plate, key, new)
    lib.notify({ title = label, description = new and 'AN' or 'AUS', type = new and 'success' or 'inform' })
end

RegisterCommand('hcmtc',  function() toggle('tc',   'Traction Control') end, false)
RegisterCommand('hcmabs', function() toggle('abs',  'ABS') end, false)
RegisterCommand('hcmflap',function() toggle('flap', 'Auspuff-Klappe') end, false)

lib.addKeybind({ name = 'hcm_tc',   description = 'Traction Control toggle',  defaultKey = '', onPressed = function() toggle('tc',  'Traction Control') end })
lib.addKeybind({ name = 'hcm_abs',  description = 'ABS toggle',               defaultKey = '', onPressed = function() toggle('abs', 'ABS') end })
lib.addKeybind({ name = 'hcm_flap', description = 'Auspuff-Klappe toggle',    defaultKey = '', onPressed = function() toggle('flap','Auspuff-Klappe') end })

RegisterNetEvent('clp_realtuner:physics:synced', function(plate, key, value)
    local rec = HCM_C.records and HCM_C.records[plate]
    if not rec then return end
    if key == 'tc' then rec.tc_enabled = value
    elseif key == 'abs' then rec.abs_enabled = value
    elseif key == 'flap' then rec.exhaust_flap = value end
end)

-- Anwendungs-Tick: wendet Werte aufs eigene Fahrzeug an --------------------
-- Wir speichern den *original* fTractionLossMult pro NetId, sonst multipliziert sich
-- der Wert jeden Tick weiter und das Fahrzeug wird innerhalb weniger Sekunden unfahrbar.
local baseTractionLoss = {}
CreateThread(function()
    while true do
        Wait(500)
        local plate, veh = plateOfCurrent()
        if plate and veh and DoesEntityExist(veh) then
            local rec = HCM_C.records[plate]
            if rec then
                -- 1) Traction Control / ABS
                local traction = 1.0
                if rec.tc_enabled == false then
                    traction = traction - (Config.Physics.TC_TractionDropOff or 0.15)
                end
                local netId = NetworkGetNetworkIdFromEntity(veh)
                if netId and netId ~= 0 then
                    if baseTractionLoss[netId] == nil then
                        baseTractionLoss[netId] = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionLossMult') or 1.0
                    end
                    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionLossMult',
                        baseTractionLoss[netId] * (2 - traction))
                end
                -- ABS: echte Wirkung nur bei harter Bremse simulieren - bloßer Hint
                if rec.abs_enabled == false and GetControlValue(0, 72) / 255.0 > 0.9 then
                    -- Wheels blockieren lassen: leicht reduzierten Bremsdruck
                    SetVehicleBrakeLights(veh, true)
                end

                -- 2) Aerodynamik: Downforce aus Spoiler + Bodykit
                local spoilerIdx = GetVehicleMod(veh, 0) -- 0 = spoiler
                local aero = Config.Physics.Aero
                local spMult = aero.SpoilerMult[spoilerIdx] or 1.0
                local body   = GetVehicleMod(veh, 1) -- 1 = bodykit / bumper-front
                local bodyMult = aero.BodyKitMult[body] or 1.0
                -- Downforce bei Speed > 40 km/h
                local speed = GetEntitySpeed(veh) * 3.6
                if speed > 40 then
                    local dfMult = spMult * bodyMult
                    -- Kraft nach unten (negative Z)
                    ApplyForceToEntity(veh, 1, 0.0, 0.0, -0.5 * (dfMult - 1) * math.min(1.5, speed / 80),
                        0.0, 0.0, 0.0, 0, true, true, true, false, true)
                end

                -- 3) Auspuff-Klappe: Volume + leichter Torque-Gewinn + Backfire bei Lift-Off
                if rec.exhaust_flap then
                    SetVehicleEnginePowerMultiplier(veh, (Config.Physics.ExhaustFlap.TorqueMult - 1.0) * 100.0)
                    -- Lift-Off detection: war throttle > 0.8, jetzt unter 0.1
                    local throttle = GetControlValue(0, 71) / 255.0
                    if HCM_C.physics._lastThrottle and HCM_C.physics._lastThrottle > 0.8 and throttle < 0.1 then
                        if math.random() < Config.Physics.ExhaustFlap.BackfireChance then
                            -- Backfire particle + sound
                            UseParticleFxAssetNextCall('core')
                            local bone = GetEntityBoneIndexByName(veh, 'exhaust')
                            if bone == -1 then bone = GetEntityBoneIndexByName(veh, 'exhaust_2') end
                            StartParticleFxNonLoopedOnEntity('veh_backfire', veh, 0, 0, 0, 0, 0, 0, 1.0, false, false, false)
                            PlaySoundFromEntity(-1, 'Unarmed_Melee_Punch', veh, 'RESPAWN_ONLINE_SOUNDSET', false, 0)
                        end
                    end
                    HCM_C.physics._lastThrottle = throttle
                else
                    SetVehicleEnginePowerMultiplier(veh, 0.0)
                end
            end
        end
    end
end)
