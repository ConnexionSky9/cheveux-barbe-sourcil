-- =========================================================
--  Elyzea - Menu des animations (serveur)
--  Gère les demandes d'animations partagées entre joueurs.
-- =========================================================
local Config = {
    RequestTimeout = 15,   -- secondes pour accepter
    MaxDistance    = 3.0,  -- distance max entre les deux joueurs (rpemotes refuse au-delà de 3 m)
    Cooldown       = 3,    -- secondes entre deux demandes d'un même joueur
}

local Pending = {}   -- [cible] = { from, emote, label, token }
local lastRequest = {}

local function notify(id, text, kind)
    TriggerClientEvent('elyzea_anim:notify', id, text, kind)
end

local function distance(a, b)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if pa == 0 or pb == 0 then return 0.0 end -- sans OneSync : contrôle fait côté client
    return #(GetEntityCoords(pa) - GetEntityCoords(pb))
end

local function name(id) return GetPlayerName(id) or ('Joueur ' .. tostring(id)) end

RegisterNetEvent('elyzea_anim:request', function(target, emote, label)
    local src = source
    target = tonumber(target)
    if type(emote) ~= 'string' or #emote > 40 or not ElyzeaSharedPartners[emote] then return end
    label = type(label) == 'string' and label:sub(1, 60) or emote

    if not target or target == src or not GetPlayerName(target) then
        return notify(src, "Ce joueur n'est plus là", 'err')
    end
    local now = GetGameTimer()
    if (lastRequest[src] or 0) > now then
        return notify(src, 'Attends un peu avant une nouvelle demande', 'err')
    end
    if distance(src, target) > Config.MaxDistance then
        return notify(src, 'Ce joueur est trop loin', 'err')
    end
    if Pending[target] then
        return notify(src, 'Ce joueur a déjà une demande en cours', 'err')
    end

    lastRequest[src] = now + Config.Cooldown * 1000
    local token = math.random(1, 999999)
    Pending[target] = { from = src, emote = emote, label = label, token = token }

    TriggerClientEvent('elyzea_anim:incoming', target, {
        from = src, name = name(src), emote = emote, label = label, timeout = Config.RequestTimeout,
    })
    notify(src, ('Demande envoyée à %s'):format(name(target)))

    SetTimeout(Config.RequestTimeout * 1000, function()
        local p = Pending[target]
        if p and p.token == token then
            Pending[target] = nil
            TriggerClientEvent('elyzea_anim:requestEnd', target)
            if GetPlayerName(src) then notify(src, ("%s n'a pas répondu"):format(name(target)), 'err') end
        end
    end)
end)

RegisterNetEvent('elyzea_anim:respond', function(accept)
    local src = source
    local p = Pending[src]
    if not p then return end
    Pending[src] = nil
    local from = p.from
    if not GetPlayerName(from) then return notify(src, "Ce joueur n'est plus là", 'err') end

    if not accept then
        return notify(from, ('%s a refusé : %s'):format(name(src), p.label), 'err')
    end
    if distance(src, from) > Config.MaxDistance + 1.0 then
        notify(src, 'Vous êtes trop loin l\'un de l\'autre', 'err')
        return notify(from, 'Vous êtes trop loin l\'un de l\'autre', 'err')
    end

    -- Lancement par rpemotes : même logique que son propre système d'acceptation
    -- src = celui qui accepte, from = celui qui a demandé
    local other = ElyzeaSharedPartners[p.emote] or p.emote
    TriggerClientEvent('SyncPlayEmote', src, other, from)
    TriggerClientEvent('SyncPlayEmoteSource', from, p.emote, src)
    notify(from, ('%s a accepté : %s'):format(name(src), p.label), 'ok')
end)

AddEventHandler('playerDropped', function()
    local src = source
    Pending[src] = nil
    lastRequest[src] = nil
    for target, p in pairs(Pending) do
        if p.from == src then
            Pending[target] = nil
            TriggerClientEvent('elyzea_anim:requestEnd', target)
        end
    end
end)
