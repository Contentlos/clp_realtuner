-- =============================================================================
--  clp_realtuner - Polizei Client (Batch 10)
--   - Polizei-Scanner Item-Hook (police_scanner)
--   - /hcmscan Command
--   - Mechaniker-Command /hcmetch fuer VIN-Etching
-- =============================================================================

HCM_C = HCM_C or {}

local function getNearestVehicle()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then return veh end
    local handle = GetClosestVehicle(coords.x, coords.y, coords.z, 6.0, 0, 70)
    if handle ~= 0 then return handle end
    return 0
end

local function statusLabel(status)
    return ({
        valid   = { text = 'GUeLTIG',    type = 'success' },
        grace   = { text = 'KULANZ',     type = 'warning' },
        expired = { text = 'ABGELAUFEN', type = 'error'   },
        missing = { text = 'KEINE',      type = 'error'   },
        unknown = { text = 'UNBEKANNT',  type = 'inform'  },
    })[status] or { text = status or '?', type = 'inform' }
end

local function showScanResult(data)
    if not data then
        lib.notify({ title = 'Scanner', description = 'Kein Datensatz fuer dieses Kennzeichen', type = 'error' })
        return
    end
    local tuev = statusLabel(data.tuev_status)
    local tuevDate = data.tuev_expires and data.tuev_expires > 0
        and HCM.util.formatTs(data.tuev_expires, '%d.%m.%Y') or '—'
    local mismatch = data.vin_mismatch and ' \u{26a0} VIN-MISMATCH' or ''
    local ownerTxt = (data.owner_name and data.owner_name ~= ' ')
        and data.owner_name or 'Unbekannt / nicht registriert'

    lib.registerContext({
        id = 'hcm_police_scan',
        title = ('Scanner %s%s'):format(data.plate or '', mismatch),
        options = {
            { title = 'Kennzeichen', description = data.plate or '—', disabled = true },
            { title = 'VIN (Datenbank)', description = data.vin or '—', disabled = true },
            { title = 'VIN (Rahmen, eingeschlagen)', description = data.etched_vin or 'nicht graviert', disabled = true },
            { title = 'TUeV', description = ('%s (%s)'):format(tuev.text, tuevDate), disabled = true },
            { title = 'Halter', description = ownerTxt, disabled = true },
            { title = 'Modell', description = tostring(data.model or '—'), disabled = true },
            { title = 'Kilometerstand', description = ('%.1f km'):format(tonumber(data.odometer) or 0), disabled = true },
            { title = 'Motor-Zustand', description = ('%.0f%%'):format(tonumber(data.engine_health) or 0), disabled = true },
            { title = 'Letzte Log-Eintraege', description = (#(data.logs or {})) .. ' Eintraege', disabled = true },
        },
    })
    lib.showContext('hcm_police_scan')
    if data.vin_mismatch then
        lib.notify({ title = 'SCANNER', description = 'VIN-Mismatch erkannt!', type = 'error', duration = 6000 })
    end
    if data.tuev_status == 'expired' then
        lib.notify({ title = 'SCANNER', description = 'TUeV ABGELAUFEN', type = 'error', duration = 5000 })
    elseif data.tuev_status == 'grace' then
        lib.notify({ title = 'SCANNER', description = 'TUeV in Kulanzzeit', type = 'warning' })
    end
end

local function scan()
    local veh = getNearestVehicle()
    if veh == 0 then
        lib.notify({ title = 'Scanner', description = 'Kein Fahrzeug in der Naehe', type = 'error' })
        return
    end
    local plate = (GetVehicleNumberPlateText(veh) or ''):gsub('%s+', '')
    local data = lib.callback.await('clp_realtuner:police:scan', 5000, plate)
    showScanResult(data)
end

RegisterCommand('hcmscan', scan, false)
TriggerEvent('chat:addSuggestion', '/hcmscan', 'Polizei-Scanner (Fahrzeug-Info)')

-- ox_inventory Item-Hook: police_scanner
CreateThread(function()
    if not exports.ox_inventory then return end
    while GetResourceState('ox_inventory') ~= 'started' do Wait(500) end
    pcall(function()
        exports.ox_inventory:registerHook('usingItem', function(payload)
            if payload and payload.name == 'police_scanner' then
                scan()
                return false -- cancel consumption
            end
        end, { print = false, itemFilter = { police_scanner = true } })
    end)
end)

-- VIN-Etching (Mechaniker)
RegisterCommand('hcmetch', function()
    local veh = getNearestVehicle()
    if veh == 0 then
        lib.notify({ title = 'VIN-Etch', description = 'Kein Fahrzeug', type = 'error' })
        return
    end
    local plate = (GetVehicleNumberPlateText(veh) or ''):gsub('%s+', '')
    local done = lib.progressCircle({
        label = 'VIN in Rahmen schlagen...', duration = 12000, position = 'bottom',
        disable = { car = true, move = true, combat = true },
    })
    if not done then return end
    local ok, vin = lib.callback.await('clp_realtuner:police:etchVin', 5000, plate)
    if ok then
        lib.notify({ title = 'VIN-Etch', description = 'Graviert: ' .. tostring(vin), type = 'success' })
    else
        lib.notify({ title = 'VIN-Etch', description = 'Fehler (kein Mechaniker / kein Fahrzeug)', type = 'error' })
    end
end, false)
TriggerEvent('chat:addSuggestion', '/hcmetch', 'VIN in Fahrzeugrahmen eingravieren (Mechaniker)')
