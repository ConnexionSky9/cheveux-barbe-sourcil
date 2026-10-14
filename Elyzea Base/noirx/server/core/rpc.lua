--[[
    NOIR X — Appels NUI → serveur (RPC) et notifications serveur → NUI (Push)

    Chaîne d'un appel :
      NUI fetch('rpc') → client Lua → TriggerServerEvent('noirx:server:rpc', token, reqId, name, args)
      → serveur : jeton de session, reqId strictement croissant (anti-rejeu), limite de fréquence,
        application activée, base disponible → handler → réponse 'noirx:client:rpc'

    Déclarer un handler :
      Rpc.Register('chat.send', { app = 'darkchat', rate = { 8, 10 } }, function(src, ctx, args)
          return { ok = true, ... }          -- ou  return Rpc.Fail('code', 'Message lisible')
      end)
    ctx = { charId = ..., session = ... }

    Le handler ne reçoit QUE des données du client : tout doit y être revalidé.
]]

Rpc = { handlers = {} }
Push = {}

local Buckets = {} -- [src] = { [name] = { t1, t2, ... } }

function Rpc.Fail(code, message)
    return { ok = false, error = code, message = message }
end

--- @param opts table { app = 'id'|nil, rate = { count, perSeconds }|nil, db = boolean (défaut true), phone = boolean (défaut true) }
function Rpc.Register(name, opts, fn)
    Rpc.handlers[name] = { opts = opts or {}, fn = fn }
end

local function appEnabled(id)
    for _, a in ipairs(Config.Apps) do
        if a.id == id then return a.enabled == true end
    end
    return false
end
Rpc.AppEnabled = appEnabled

local function rateOk(src, name, rate)
    if not rate then rate = { 20, 5 } end
    local now = GetGameTimer()
    Buckets[src] = Buckets[src] or {}
    local b = Buckets[src][name] or {}
    local windowMs = rate[2] * 1000
    local kept = {}
    for _, t in ipairs(b) do
        if now - t < windowMs then kept[#kept + 1] = t end
    end
    if #kept >= rate[1] then
        Buckets[src][name] = kept
        return false
    end
    kept[#kept + 1] = now
    Buckets[src][name] = kept
    return true
end

--- Exécute un handler (utilisé par l'événement réseau et par les tests).
function Rpc.Dispatch(src, token, reqId, name, args)
    local h = type(name) == 'string' and Rpc.handlers[name] or nil
    if not h then
        Rpc.unknownWarned = Rpc.unknownWarned or {}
        if type(name) == 'string' and not Rpc.unknownWarned[name] then
            Rpc.unknownWarned[name] = true
            print(('^1[NOIR X] Action « %s » inconnue du serveur : le fichier server/apps de cette application n\'est pas chargé.^0'):format(name))
            print('^1[NOIR X] Après une mise à jour de noirx, tape « refresh » PUIS « restart noirx » (sinon FiveM garde l\'ancienne liste de fichiers).^0')
        end
        return Rpc.Fail('unknown', 'Module serveur absent : le staff doit taper « refresh » puis « restart noirx ».')
    end
    local opts = h.opts

    local session = Phone.GetSession(src)
    if opts.phone ~= false then
        if not session or type(token) ~= 'string' or session.token ~= token then
            return Rpc.Fail('session', 'Terminal verrouillé.')
        end
        local rid = type(reqId) == 'number' and math.tointeger(reqId) or nil
        if not rid or rid <= (session.lastReqId or 0) then
            Audit.Log(src, 'rpc.replay', { name = name })
            return Rpc.Fail('replay', 'Requête rejetée.')
        end
        session.lastReqId = rid
    end

    if opts.app and not appEnabled(opts.app) then
        return Rpc.Fail('disabled', 'Ce nœud est désactivé.')
    end
    if opts.db ~= false and DB.driver == 'none' then
        return Rpc.Fail('no_database', 'Réseau indisponible (base de données absente).')
    end
    if not rateOk(src, name, opts.rate) then
        return Rpc.Fail('rate', 'Trop de requêtes. Patiente un instant.')
    end
    if args ~= nil and type(args) ~= 'table' then
        return Rpc.Fail('bad_args', 'Requête invalide.')
    end

    local charId = Players.CharOf(src)
    if not charId then return Rpc.Fail('identity', 'Identité introuvable.') end

    local ok, result = pcall(h.fn, src, { charId = charId, session = session }, args or {})
    if not ok then
        NoirX.Error(('RPC %s : %s'):format(name, tostring(result)))
        return Rpc.Fail('internal', 'Erreur du réseau.')
    end
    if type(result) ~= 'table' then result = { ok = true, data = result } end
    if result.ok == nil then result.ok = true end
    return result
end

RegisterNetEvent('noirx:server:rpc', function(token, reqId, name, args)
    local src = source
    local result = Rpc.Dispatch(src, token, reqId, name, args)
    TriggerClientEvent('noirx:client:rpc', src, reqId, result)
end)

AddEventHandler('playerDropped', function()
    Buckets[source] = nil
end)

-- ─── Push ───────────────────────────────────────────────────────

function Push.ToSrc(src, event, payload)
    if not src then return end
    TriggerClientEvent('noirx:client:push', src, event, payload or {})
end

function Push.ToChar(charId, event, payload)
    local src = Players.SrcOf(charId)
    if src then Push.ToSrc(src, event, payload) end
    return src
end

--- Notification visible même téléphone rangé (le joueur doit posséder l'item).
function Push.Notify(src, title, body, kind)
    if not src or not Inventory.HasItem(src, Config.Item.name) then return false end
    TriggerClientEvent('noirx:client:notify', src, tostring(title):sub(1, 40), tostring(body):sub(1, 200), kind)
    return true
end
