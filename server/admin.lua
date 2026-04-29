-- =============================================================================
--  clp_realtuner - Admin Commands
-- =============================================================================

local ESX = exports['es_extended']:getSharedObject()

local function isAdmin(xPlayer)
    return HCM.util.isAdmin(xPlayer)
end

local function usage(src, cmd)
    TriggerClientEvent('chat:addMessage', src, {
        args = { '[realtuner]', ('Usage: /%s <open|dump|reset|setvin|setstat> [args]'):format(cmd) }
    })
end

RegisterCommand(Config.AdminCommand, function(src, args)
    if src == 0 then
        print('[realtuner] admin command nur ingame.')
        return
    end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not isAdmin(xPlayer) then
        TriggerClientEvent('chat:addMessage', src, { args = { '[realtuner]', 'Keine Berechtigung.' } })
        return
    end
    local sub = args[1]
    if not sub then return usage(src, Config.AdminCommand) end

    if sub == 'dump' then
        local plate = HCM.util.normalizePlate(args[2] or '')
        local rec = HCM.server.loadRecord(plate)
        if not rec then
            TriggerClientEvent('chat:addMessage', src, { args = { '[realtuner]', 'Keine Daten für ' .. plate } })
            return
        end
        print('[realtuner] DUMP ' .. plate .. ': ' .. json.encode(rec))
        TriggerClientEvent('chat:addMessage', src, { args = { '[realtuner]', 'Dump in Server-Konsole.' } })

    elseif sub == 'reset' then
        local plate = HCM.util.normalizePlate(args[2] or '')
        if plate == '' then return usage(src, Config.AdminCommand) end
        HCM.server.applyPatch(plate, {
            engine_health = 100, transmission_health = 100, brake_health = 100,
            turbo_health = 100, suspension_health = 100, paint_quality = 100,
            last_service = os.time(),
        })
        HCM.server.log(xPlayer, 'admin:reset', plate, nil, {})
        TriggerClientEvent('chat:addMessage', src, { args = { '[realtuner]', 'Reset OK.' } })

    elseif sub == 'setstat' then
        local plate = HCM.util.normalizePlate(args[2] or '')
        local field = args[3]
        local value = tonumber(args[4])
        if plate == '' or not field or not value then return usage(src, Config.AdminCommand) end
        HCM.server.applyPatch(plate, { [field] = value })
        HCM.server.log(xPlayer, 'admin:setstat:' .. field, plate, nil, { value = value })
        TriggerClientEvent('chat:addMessage', src, { args = { '[realtuner]', ('Set %s = %s'):format(field, value) } })

    elseif sub == 'open' or sub == 'ui' then
        TriggerClientEvent('clp_realtuner:openAdmin', src)

    elseif sub == 'setvin' then
        local plate = HCM.util.normalizePlate(args[2] or '')
        if plate == '' then return usage(src, Config.AdminCommand) end
        local rec = HCM.server.loadRecord(plate)
        if not rec then return end
        local newVin = HCM.util.generateVIN(plate, rec.model, os.time() + math.random(1, 1e6))
        MySQL.update.await('UPDATE vehicles_data SET vin = ? WHERE plate = ?', { newVin, plate })
        rec.vin = newVin
        HCM.server.log(xPlayer, 'admin:setvin', plate, newVin, {})
        TriggerClientEvent('chat:addMessage', src, { args = { '[realtuner]', 'Neue VIN: ' .. newVin } })

    else
        usage(src, Config.AdminCommand)
    end
end, false)
