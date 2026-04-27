-- =============================================================================
--  clp_realtuner - Client Runtime Sync
--  Empfängt Live-Updates vom Server (Config / Parts / Locations) und patched die
--  lokalen Tabellen, ohne Rejoin. Bootstrap beim Laden.
-- =============================================================================

local function deepMerge(dst, src)
    if type(dst) ~= 'table' or type(src) ~= 'table' then return src end
    for k, v in pairs(src) do
        if type(v) == 'table' and type(dst[k]) == 'table' then
            deepMerge(dst[k], v)
        else
            dst[k] = v
        end
    end
    return dst
end

RegisterNetEvent('clp_realtuner:runtimeBootstrap', function(payload)
    if type(payload) ~= 'table' then return end
    if payload.config    then deepMerge(Config,    payload.config)    end
    if payload.parts     then
        for k, v in pairs(payload.parts)     do Parts[k]     = v end
        for k in pairs(Parts) do
            if payload.parts[k] == nil then Parts[k] = nil end
        end
    end
    if payload.locations then
        for k, v in pairs(payload.locations) do Locations[k] = v end
    end
end)

RegisterNetEvent('clp_realtuner:runtimeSync', function(msg)
    if type(msg) ~= 'table' then return end
    if msg.kind == 'config' then
        local parts = {}
        for p in (msg.keyPath or ''):gmatch('[^.]+') do parts[#parts+1] = p end
        local cur = Config
        for i = 1, #parts - 1 do
            cur[parts[i]] = cur[parts[i]] or {}
            cur = cur[parts[i]]
        end
        cur[parts[#parts]] = msg.value
    elseif msg.kind == 'part' then
        if msg.def == nil then
            Parts[msg.item] = nil
        else
            Parts[msg.item] = Parts[msg.item] or {}
            deepMerge(Parts[msg.item], msg.def)
        end
    elseif msg.kind == 'location' then
        Locations[msg.category] = msg.list
    elseif msg.kind == 'reset' then
        TriggerServerEvent('clp_realtuner:requestRuntime')
    end
end)

CreateThread(function()
    Wait(500)
    TriggerServerEvent('clp_realtuner:requestRuntime')
end)
