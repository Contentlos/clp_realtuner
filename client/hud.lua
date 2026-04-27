-- =============================================================================
--  clp_realtuner - Cockpit HUD (OBD Live-Daten)
-- =============================================================================

HCM_C = HCM_C or {}

local hudOpen = false
local focus = false

local function sendNui(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function openHUD()
    hudOpen = true
    sendNui('hud:show', {})
end

local function closeHUD()
    hudOpen = false
    sendNui('hud:hide', {})
end

RegisterCommand('hcmhud', function()
    if hudOpen then closeHUD() else openHUD() end
end, false)

lib.addKeybind({
    name = 'hcm_hud',
    description = 'Cockpit-HUD Toggle',
    defaultKey = (Config.HUD and Config.HUD.Key) or 'F7',
    onPressed = function() if hudOpen then closeHUD() else openHUD() end end,
})

-- Initial: wenn Config.HUD.DefaultEnabled true, beim Spawn starten
CreateThread(function()
    Wait(2000)
    if Config.HUD and Config.HUD.Enabled and Config.HUD.DefaultEnabled then
        openHUD()
    end
end)

CreateThread(function()
    while true do
        Wait((Config.HUD and Config.HUD.Refresh) or 250)
        if hudOpen then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and DoesEntityExist(veh) then
                local plate = HCM_C.plateOf(veh)
                local rec = plate and HCM_C.records[plate] or nil
                local rpm = GetVehicleCurrentRpm(veh) or 0
                local speed = (GetEntitySpeed(veh) or 0) * 3.6
                local gear = GetVehicleCurrentGear(veh) or 0
                local fuel = GetVehicleFuelLevel(veh) or 0
                local data = {
                    rpm = math.floor(rpm * 8000),
                    rpmPct = rpm,
                    speed = math.floor(speed),
                    gear = gear,
                    fuel = math.floor(fuel),
                    boost = (rec and rec.turbo_health) and (rpm * (rec.turbo_health / 100) * 1.2) or 0,
                    coolantTemp = rec and rec.coolant_temp or 85,
                    oilPressure = rec and math.max(0, (rec.oil_quality or 100)) or 100,
                    battery = rec and rec.battery or 100,
                    engineHP = rec and rec.engine_health or 100,
                    brakeHP = rec and rec.brake_health or 100,
                    -- Default: ON, wenn kein Record vorhanden oder Feld nil. Bei explizit false -> off.
                    tcOn = (not rec) or rec.tc_enabled ~= false,
                    absOn = (not rec) or rec.abs_enabled ~= false,
                    flap = rec and rec.exhaust_flap or false,
                    ecuMap = rec and rec.ecu_map or 'stock',
                    position = (Config.HUD and Config.HUD.Position) or 'bottom-right',
                }
                sendNui('hud:update', data)
            else
                sendNui('hud:update', nil)
            end
        end
    end
end)
