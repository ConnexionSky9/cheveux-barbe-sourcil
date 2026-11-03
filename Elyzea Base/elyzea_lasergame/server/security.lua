-- =====================================================================
--  ELYZEA LASERGAME - SÉCURITÉ
--  Limite de fréquence par joueur et par action, verrous anti double appel,
--  événements suspects (journalisés, exclusion du LaserGame facultative).
--  Rappel : le serveur ne fait JAMAIS confiance aux montants, dégâts ou résultats envoyés par le client.
-- =====================================================================
Security = {}

local buckets = {}     -- [src][key] = { tokens, t }
local busy = {}        -- [src] = nom de l'action en cours
local strikes = {}     -- [src] = nombre d'événements suspects

-- Limites particulières (événements par seconde) ; les autres utilisent Config.Security.maxEventsPerSecond
local LIMITS = {
    ['shots'] = 40,          -- lots de tirs (le client en envoie ~10/s)
    ['rpc:lb:get'] = 4,
    ['rpc:admin:'] = 10,
}

local function limitFor(key)
    if LIMITS[key] then return LIMITS[key] end
    for k, v in pairs(LIMITS) do if k:sub(-1) == ':' and key:sub(1, #k) == k then return v end end
    return Config.Security.maxEventsPerSecond
end

-- Seau à jetons : autorise des rafales courtes sans dépasser la moyenne
function Security.Allow(src, key)
    local now = GetGameTimer()
    local lim = limitFor(key)
    local b = buckets[src]
    if not b then b = {} buckets[src] = b end
    local e = b[key]
    if not e then e = { tokens = lim, t = now } b[key] = e end
    e.tokens = math.min(lim, e.tokens + (now - e.t) * lim / 1000)
    e.t = now
    if e.tokens < 1 then
        e.drops = (e.drops or 0) + 1
        if e.drops % 50 == 1 then Security.Suspicious(src, 'flood', { key = key }) end
        return false
    end
    e.tokens = e.tokens - 1
    return true
end

-- Une action sensible à la fois par joueur (double clic, requêtes simultanées)
function Security.Locked(src, name, fn, ...)
    if busy[src] then return false, 'Action déjà en cours.' end
    busy[src] = name
    local res = table.pack(pcall(fn, ...))
    busy[src] = nil
    if not res[1] then
        Logs.Error(('%s : %s'):format(name, tostring(res[2])))
        return false, 'Erreur interne, réessaie.'
    end
    return table.unpack(res, 2, res.n)
end

function Security.Suspicious(src, reason, data)
    strikes[src] = (strikes[src] or 0) + 1
    Logs.Add('security', ('événement suspect : %s (n°%d)'):format(reason, strikes[src]), data, src)
    local lim = Config.Security.banAfterSuspicious or 0
    if lim > 0 and strikes[src] >= lim and Players and Players.Exclude then
        local id = Bridge.Identity(src)
        if id then Players.Exclude(id.cid, true, 'Exclusion automatique : ' .. reason, 0) end
    end
end

AddEventHandler('playerDropped', function()
    local s = source
    buckets[s], busy[s], strikes[s] = nil, nil, nil
end)
