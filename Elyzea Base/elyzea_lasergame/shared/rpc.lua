-- =====================================================================
--  ELYZEA LASERGAME - APPELS CLIENT -> SERVEUR AVEC RÉPONSE
--  Client : local ok, data = RPC.Call('pvp:create', { ... })
--  Serveur : RPC.Register('pvp:create', function(src, opts) return true, data end)
--  Chaque appel passe par la limite de fréquence (server/security.lua) et une erreur Lua
--  côté serveur renvoie (false, 'error') au lieu de bloquer le client.
-- =====================================================================
RPC = RPC or {}
local RES = GetCurrentResourceName()
local IS_SERVER = IsDuplicityVersion()

if IS_SERVER then
    local handlers = {}
    function RPC.Register(name, fn) handlers[name] = fn end

    RegisterNetEvent(RES .. ':rpc', function(name, id, ...)
        local src = source
        if type(name) ~= 'string' or type(id) ~= 'number' then return end
        local fn = handlers[name]
        if not fn then return TriggerClientEvent(RES .. ':rpcr', src, id, false, 'unknown') end
        if Security and not Security.Allow(src, 'rpc:' .. name) then
            return TriggerClientEvent(RES .. ':rpcr', src, id, false, 'Trop de requêtes, patiente un instant.')
        end
        local res = table.pack(pcall(fn, src, ...))
        if not res[1] then
            if Logs then Logs.Error(('RPC %s (joueur %s) : %s'):format(name, src, tostring(res[2]))) else print(res[2]) end
            return TriggerClientEvent(RES .. ':rpcr', src, id, false, 'Erreur interne, réessaie.')
        end
        TriggerClientEvent(RES .. ':rpcr', src, id, table.unpack(res, 2, res.n))
    end)
else
    local pending, seq = {}, 0
    RegisterNetEvent(RES .. ':rpcr', function(id, ...)
        local p = pending[id]
        if not p then return end
        pending[id] = nil
        p:resolve(table.pack(...))
    end)

    function RPC.Call(name, ...)
        seq = seq + 1
        local id = seq
        local p = promise.new()
        pending[id] = p
        TriggerServerEvent(RES .. ':rpc', name, id, ...)
        SetTimeout(15000, function()
            if pending[id] then pending[id] = nil p:resolve(table.pack(false, 'Le serveur ne répond pas.')) end
        end)
        local res = Citizen.Await(p)
        return table.unpack(res, 1, res.n)
    end
end
