-- =============================================================================
--  clp_realtuner - Admin-Live-View + Teleport Client (Batch 12)
-- =============================================================================

HCM_C = HCM_C or {}

local activePlate

RegisterCommand('hcmlive', function(_, args)
    local plate = (args[1] or ''):upper():gsub('%s+', '')
    if plate == '' then
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh == 0 then veh = GetClosestVehicle(GetEntityCoords(ped), 8.0, 0, 70) end
        if veh ~= 0 then plate = (GetVehicleNumberPlateText(veh) or ''):upper():gsub('%s+', '') end
    end
    if plate == '' then
        lib.notify({ title = 'Live-View', description = 'Plate angeben oder Fahrzeug waehlen', type = 'error' })
        return
    end
    local ok = lib.callback.await('clp_realtuner:admin:liveSubscribe', 3000, plate)
    if ok then
        activePlate = plate
        lib.notify({ title = 'Live-View', description = 'Abo fuer ' .. plate, type = 'success' })
    else
        lib.notify({ title = 'Live-View', description = 'Kein Admin / Fehler', type = 'error' })
    end
end, false)
TriggerEvent('chat:addSuggestion', '/hcmlive', 'Live-Abo fuer Fahrzeug-Record (Admin)', {
    { name = 'plate', help = 'Kennzeichen' },
})

RegisterCommand('hcmliveoff', function()
    lib.callback.await('clp_realtuner:admin:liveSubscribe', 2000, '')
    activePlate = nil
    lib.notify({ title = 'Live-View', description = 'Abo beendet', type = 'inform' })
end, false)

RegisterNetEvent('clp_realtuner:admin:liveUpdate', function(plate, rec)
    if activePlate ~= plate then return end
    -- Kurzes On-Screen-Preview ueber lib.showTextUI
    local txt = ('[LIVE %s]\nEngine %.0f  Brake %.0f  Turbo %.0f  Susp %.0f\nFluel %.0f%%  Coolant %.0f°  Battery %.0f%%  Rust %.0f'):format(
        plate,
        tonumber(rec.engine_health) or 0, tonumber(rec.brake_health) or 0,
        tonumber(rec.turbo_health) or 0, tonumber(rec.suspension_health) or 0,
        tonumber(rec.oil_quality) or 0, tonumber(rec.coolant_temp) or 0,
        tonumber(rec.battery) or 0, tonumber(rec.rust) or 0
    )
    lib.showTextUI(txt, { position = 'top-right' })
end)

RegisterCommand('hcmtp', function(_, args)
    local query = (args[1] or ''):upper():gsub('%s+', '')
    if query == '' then
        local d = lib.inputDialog('Teleport zu Fahrzeug', {
            { type = 'input', label = 'Plate / VIN', required = true },
        })
        if not d then return end
        query = d[1]:upper():gsub('%s+', '')
    end
    TriggerServerEvent('clp_realtuner:admin:teleport', query)
end, false)
TriggerEvent('chat:addSuggestion', '/hcmtp', 'Teleport zu Fahrzeug (Plate/VIN) (Admin)', {
    { name = 'query', help = 'Plate oder VIN' },
})
