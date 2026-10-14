--[[
    NOIR X — Client : relais NUI ↔ serveur
    Le client ne prend aucune décision : il transmet les requêtes NUI au serveur avec
    le jeton de session et un numéro de requête strictement croissant, puis renvoie
    la réponse à la NUI. Les « pushs » serveur sont relayés tels quels à la NUI.
]]

local pending = {}  -- [reqId] = { cb = fn, at = GetGameTimer() }
local seq = 0
local TIMEOUT = 10000

RegisterNUICallback('rpc', function(data, cb)
    local token = NoirX.ClientToken()
    if not token or type(data) ~= 'table' or type(data.name) ~= 'string' then
        cb({ ok = false, error = 'session', message = 'Terminal verrouillé.' })
        return
    end
    seq = seq + 1
    pending[seq] = { cb = cb, at = GetGameTimer() }
    TriggerServerEvent('noirx:server:rpc', token, seq, data.name, type(data.args) == 'table' and data.args or {})
end)

RegisterNetEvent('noirx:client:rpc', function(reqId, result)
    local p = pending[reqId]
    if not p then return end
    pending[reqId] = nil
    p.cb(result or { ok = false, error = 'empty' })
end)

RegisterNetEvent('noirx:client:push', function(event, payload)
    SendNUIMessage({ action = 'push', event = event, payload = payload })
end)

-- Point GPS : coordonnées fournies par le serveur (info Ratline achetée).
RegisterNUICallback('waypoint', function(data, cb)
    local x, y = tonumber(data and data.x), tonumber(data and data.y)
    if x and y then
        SetNewWaypoint(x + 0.0, y + 0.0)
        cb({ ok = true })
    else
        cb({ ok = false })
    end
end)

-- Expiration des requêtes sans réponse.
CreateThread(function()
    while true do
        Wait(1000)
        local now = GetGameTimer()
        for id, p in pairs(pending) do
            if now - p.at > TIMEOUT then
                pending[id] = nil
                p.cb({ ok = false, error = 'timeout', message = 'Le réseau ne répond pas.' })
            end
        end
    end
end)
