-- =============================================================================
--  clp_realtuner - Fahrtenbuch Client (Batch 9)
--   - Tracked pro aktiver Fahrt: startX/Y/Z, endX/Y/Z, km, maxKmh, avgKmh
--   - Schickt Trip beim Aussteigen / Motor-Aus
-- =============================================================================

HCM_C = HCM_C or {}

local current = nil -- { plate, model, startTs, startX, startY, startZ, lastX, lastY, lastZ, km, maxKmh, sumKmh, samples }

local function startTrip(veh)
    if not veh or veh == 0 then return end
    local plate = (GetVehicleNumberPlateText(veh) or ''):gsub('%s+', '')
    local coords = GetEntityCoords(veh)
    current = {
        plate = plate, model = GetEntityModel(veh),
        startTs = HCM.util.now(), startX = coords.x, startY = coords.y, startZ = coords.z,
        lastX = coords.x, lastY = coords.y, lastZ = coords.z,
        km = 0.0, maxKmh = 0.0, sumKmh = 0.0, samples = 0,
    }
end

local function endTrip()
    if not current then return end
    if current.samples < 5 or current.km < 0.05 then current = nil; return end
    local avg = current.sumKmh / math.max(1, current.samples)
    TriggerServerEvent('clp_realtuner:trip:end', {
        plate   = current.plate, model = current.model,
        startTs = current.startTs, endTs = HCM.util.now(),
        km      = current.km, maxKmh = current.maxKmh, avgKmh = avg,
        startX  = current.startX, startY = current.startY, startZ = current.startZ,
        endX    = current.lastX, endY  = current.lastY,  endZ  = current.lastZ,
    })
    current = nil
end

CreateThread(function()
    while true do
        Wait(3000)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
            if not current then startTrip(veh)
            else
                local c = GetEntityCoords(veh)
                local dx, dy, dz = c.x - current.lastX, c.y - current.lastY, c.z - current.lastZ
                local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
                current.km = current.km + (dist / 1000.0)
                current.lastX, current.lastY, current.lastZ = c.x, c.y, c.z
                local speed = GetEntitySpeed(veh) * 3.6
                if speed > current.maxKmh then current.maxKmh = speed end
                current.sumKmh = current.sumKmh + speed
                current.samples = current.samples + 1
            end
        else
            if current then endTrip() end
        end
    end
end)

AddEventHandler('onResourceStop', function(resName)
    if resName == GetCurrentResourceName() and current then endTrip() end
end)

RegisterCommand('hcmtrips', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    local plate
    if veh ~= 0 then plate = (GetVehicleNumberPlateText(veh) or ''):gsub('%s+', '') end
    local rows = lib.callback.await('clp_realtuner:trip:history', 5000, plate, 20) or {}
    local opts = {}
    for _, t in ipairs(rows) do
        opts[#opts+1] = {
            title = ('%s – %.1f km'):format(HCM.util.formatTs(tonumber(t.start_ts) or 0, '%d.%m. %H:%M'), tonumber(t.km) or 0),
            description = ('max %.0f km/h, avg %.0f km/h'):format(tonumber(t.max_kmh) or 0, tonumber(t.avg_kmh) or 0),
            disabled = true,
        }
    end
    if #opts == 0 then opts[1] = { title = 'Keine Fahrten gespeichert', disabled = true } end
    lib.registerContext({ id = 'hcm_trips', title = 'Fahrtenbuch' .. (plate and (' – ' .. plate) or ''), options = opts })
    lib.showContext('hcm_trips')
end, false)
TriggerEvent('chat:addSuggestion', '/hcmtrips', 'Fahrtenbuch anzeigen')
