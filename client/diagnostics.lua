-- =============================================================================
--  clp_realtuner - Diagnose (Status, DTC Codes)
-- =============================================================================

HCM_C = HCM_C or {}

-- Public API ----------------------------------------------------------------
function HCM_C.diagnose(veh, asAdmin)
    local rec = HCM_C.getRecord(veh)
    if not rec then return nil end
    local isAdmin = asAdmin or (HCM_C.me and HCM_C.me.isAdmin) or false
    local fields = { 'engine_health', 'transmission_health', 'brake_health', 'turbo_health', 'suspension_health' }
    local out = { vin = rec.vin, plate = plateOf and plateOf(veh) or GetVehicleNumberPlateText(veh), model = rec.model }
    local stats = {}
    for _, f in ipairs(fields) do
        local v = rec[f] or 100.0
        stats[f] = {
            label  = HCM.util.statusLabel(v),
            value  = isAdmin and HCM.util.round(v, 1) or nil,
        }
    end
    out.stats = stats
    out.dtc   = HCM.util.generateDTC(rec)
    out.last_service = rec.last_service
    out.paint_quality = isAdmin and rec.paint_quality or HCM.util.statusLabel(rec.paint_quality or 100)
    out.installed_parts = rec.installed_parts or {}
    out.ecu_state = isAdmin and rec.ecu_state or nil
    return out
end
