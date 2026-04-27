-- =============================================================================
--  clp_realtuner - lb-phone Bridge (Batch 11)
--   Registriert eine "Realtuner"-App die das Tablet via NUI-Nachrichten oeffnet.
--   Funktioniert auch wenn lb-phone nicht installiert ist (silent skip).
-- =============================================================================

CreateThread(function()
    Wait(5000)
    if GetResourceState('lb-phone') ~= 'started' then return end
    local ok, err = pcall(function()
        local ok2, AddCustomApp = pcall(function() return exports['lb-phone'].AddCustomApp end)
        if not ok2 or not AddCustomApp then return end
        exports['lb-phone']:AddCustomApp({
            identifier = 'realtuner',
            name       = 'Realtuner',
            description= 'Tuning / Wartung / Termine',
            developer  = 'clp_realtuner',
            defaultApp = false,
            size       = 80,
            ui         = 'https://cfx-nui-' .. GetCurrentResourceName() .. '/html/phone_app.html',
            icon       = 'https://cfx-nui-' .. GetCurrentResourceName() .. '/html/icon.png',
            onUse      = function() end,
        })
    end)
    if not ok then print('[clp_realtuner] lb-phone bridge error: ' .. tostring(err)) end
end)

-- NUI-Callbacks vom Phone-App
RegisterNUICallback('phone:openTablet', function(_, cb)
    if HCM_C and HCM_C.openTablet then HCM_C.openTablet({}) end
    cb({ ok = true })
end)
RegisterNUICallback('phone:emergency', function(_, cb)
    ExecuteCommand('hcmemergency')
    cb({ ok = true })
end)
RegisterNUICallback('phone:pickup', function(_, cb)
    ExecuteCommand('hcmpickup')
    cb({ ok = true })
end)
