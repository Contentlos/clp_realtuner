-- =============================================================================
--  clp_realtuner - Versicherung Client (Batch 11)
-- =============================================================================

local function getPlate()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then return nil end
    return (GetVehicleNumberPlateText(veh) or ''):gsub('%s+', '')
end

RegisterCommand('hcminsure', function()
    local plate = getPlate()
    if not plate then
        lib.notify({ title = 'Versicherung', description = 'Setz dich in das Fahrzeug', type = 'error' })
        return
    end
    local d = lib.inputDialog('Versicherung abschliessen - ' .. plate, {
        { type = 'select', label = 'Tarif', required = true, options = {
            { label = 'Basic ($250/30d, Coverage $15k, SB $1500)',  value = 'basic'   },
            { label = 'Comfort ($750/30d, Coverage $45k, SB $750)', value = 'comfort' },
            { label = 'Premium ($1800/30d, Coverage $90k, SB $250)',value = 'premium' },
        } },
    })
    if not d or not d[1] then return end
    local ok, msg = lib.callback.await('clp_realtuner:insurance:buy', 5000, plate, d[1])
    lib.notify({ title = 'Versicherung', description = msg or '?', type = ok and 'success' or 'error' })
end, false)
TriggerEvent('chat:addSuggestion', '/hcminsure', 'Versicherung fuer aktuelles Fahrzeug abschliessen')

RegisterCommand('hcminsurances', function()
    local rows = lib.callback.await('clp_realtuner:insurance:list', 5000) or {}
    local opts = {}
    for _, r in ipairs(rows) do
        opts[#opts+1] = {
            title = ('%s - %s'):format(r.plate, r.policy_type),
            description = ('Coverage $%d, SB $%d, bis %s'):format(
                r.coverage, r.deductible, HCM.util.formatTs(tonumber(r.valid_until) or 0, '%d.%m.%Y')),
            disabled = true,
        }
    end
    if #opts == 0 then opts[1] = { title = 'Keine aktiven Policen', disabled = true } end
    lib.registerContext({ id = 'hcm_insure_list', title = 'Meine Versicherungen', options = opts })
    lib.showContext('hcm_insure_list')
end, false)
TriggerEvent('chat:addSuggestion', '/hcminsurances', 'Eigene Versicherungs-Policen anzeigen')

RegisterCommand('hcmclaim', function()
    local plate = getPlate()
    if not plate then
        lib.notify({ title = 'Schadenmeldung', description = 'Setz dich in das Fahrzeug', type = 'error' })
        return
    end
    local d = lib.inputDialog('Schadenmeldung - ' .. plate, {
        { type = 'number', label = 'Geschaetzter Schaden $', min = 100, required = true, default = 1500 },
        { type = 'input',  label = 'Beschreibung', required = true },
    })
    if not d then return end
    local ok, msg = lib.callback.await('clp_realtuner:insurance:claim', 8000, plate, d[1], d[2])
    lib.notify({ title = 'Schadenmeldung', description = msg or '?', type = ok and 'success' or 'error' })
end, false)
TriggerEvent('chat:addSuggestion', '/hcmclaim', 'Versicherungsschaden melden')
