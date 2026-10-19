-- =========================================================
--  Elyzea - Menu des animations (serveur)
--  Gère les demandes d'animations partagées entre joueurs (menu K et menu ALT),
--  les animations à deux en cours (arrêt des deux côtés) et « Copier l'animation ».
--  Rien n'est lancé sans l'accord de l'autre ; tout est revérifié ici.
-- =========================================================
local Config = {
    RequestTimeout = 15,   -- secondes pour accepter
    MaxDistance    = 3.0,  -- distance max entre les deux joueurs (rpemotes refuse au-delà de 3 m)
    Cooldown       = 3,    -- secondes entre deux demandes d'un même joueur
}
local IX = ElyzeaInteractions

local Pending = {}    -- [cible] = { from, emote, label, mode, token }
local Outgoing = {}   -- [demandeur] = cible
local Sessions = {}   -- [joueur] = { partner, emote, mode, token, since }
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
local function online(id) return id and GetPlayerName(id) ~= nil end

-- Raison pour laquelle un joueur ne peut pas faire d'animation à deux maintenant (nil = disponible)
local function busyReason(id)
    local st = Player(id).state
    if st.cuffed then return 'menotté' end
    if st.carriedBy or st.escortedBy then return 'porté ou escorté' end
    if st.emsDown then return 'à terre' end
    local ped = GetPlayerPed(id)
    if ped ~= 0 and GetVehiclePedIsIn(ped, false) ~= 0 then return 'dans un véhicule' end
    if Sessions[id] then return 'déjà dans une animation à deux' end
end

-- Animation demandée valable ? mode 'shared' (rpemotes, deux rôles) ou 'together' (même animation solo)
local function validEmote(emote, mode)
    if type(emote) ~= 'string' or #emote > 40 then return false end
    if mode == 'together' then
        local info = IX.ByCmd[emote]
        return info ~= nil and info.mode == 'together' and ElyzeaAnims[emote] ~= nil and ElyzeaAnims[emote].k == 'e'
    end
    return ElyzeaSharedPartners[emote] ~= nil
end

-- Fin d'une invitation : on prévient les deux (bandeau du demandeur, fenêtre de la cible)
local function clearPending(target, fromMsg, targetMsg)
    local p = Pending[target]
    if not p then return end
    Pending[target] = nil
    if Outgoing[p.from] == target then Outgoing[p.from] = nil end
    if online(target) then
        TriggerClientEvent('elyzea_anim:requestEnd', target)
        if targetMsg then notify(target, targetMsg, 'err') end
    end
    if online(p.from) then
        TriggerClientEvent('elyzea_anim:outgoingEnd', p.from)
        if fromMsg then notify(p.from, fromMsg, 'err') end
    end
end

RegisterNetEvent('elyzea_anim:request', function(target, emote, label, mode)
    local src = source
    target = tonumber(target)
    mode = mode == 'together' and 'together' or 'shared'
    if not validEmote(emote, mode) then return end
    label = type(label) == 'string' and label:sub(1, 60) or emote

    if not target or target == src or not online(target) then
        return notify(src, "Ce joueur n'est plus là", 'err')
    end
    local now = GetGameTimer()
    if (lastRequest[src] or 0) > now then
        return notify(src, 'Attends un peu avant une nouvelle demande', 'err')
    end
    if distance(src, target) > Config.MaxDistance then
        return notify(src, ('Ce joueur est trop loin (%d m maximum)'):format(math.floor(Config.MaxDistance)), 'err')
    end
    if Outgoing[src] then
        return notify(src, 'Tu as déjà une invitation en cours : annule-la d\'abord', 'err')
    end
    if Pending[src] then
        return notify(src, 'Réponds d\'abord à l\'invitation que tu as reçue', 'err')
    end
    if Pending[target] or Outgoing[target] then
        return notify(src, 'Ce joueur a déjà une invitation en cours', 'err')
    end
    local why = busyReason(src)
    if why then return notify(src, ('Impossible : tu es %s'):format(why), 'err') end
    why = busyReason(target)
    if why then return notify(src, ('Impossible : ce joueur est %s'):format(why), 'err') end

    lastRequest[src] = now + Config.Cooldown * 1000
    local token = math.random(1, 999999)
    Pending[target] = { from = src, emote = emote, label = label, mode = mode, token = token }
    Outgoing[src] = target

    TriggerClientEvent('elyzea_anim:incoming', target, {
        from = src, name = name(src), emote = emote, label = label, mode = mode, timeout = Config.RequestTimeout,
    })
    TriggerClientEvent('elyzea_anim:outgoing', src, { target = target, name = name(target), label = label, timeout = Config.RequestTimeout })
    notify(src, ('Demande envoyée à %s'):format(name(target)))

    SetTimeout(Config.RequestTimeout * 1000, function()
        local p = Pending[target]
        if p and p.token == token then
            clearPending(target, ("%s n'a pas répondu : invitation expirée"):format(name(target)), 'Invitation expirée')
        end
    end)
end)

-- Le demandeur annule son invitation
RegisterNetEvent('elyzea_anim:cancel', function()
    local src = source
    local target = Outgoing[src]
    if not target then return end
    local p = Pending[target]
    if not p or p.from ~= src then Outgoing[src] = nil return TriggerClientEvent('elyzea_anim:outgoingEnd', src) end
    clearPending(target, nil, ('%s a annulé son invitation'):format(name(src)))
    notify(src, 'Invitation annulée')
end)

-- Animation à deux lancée : les deux joueurs sont liés jusqu'à l'arrêt
local function startSession(a, b, emoteA, emoteB, mode)
    local token = math.random(1, 999999)
    local now = os.time()
    Sessions[a] = { partner = b, emote = emoteA, mode = mode, token = token, since = now }
    Sessions[b] = { partner = a, emote = emoteB, mode = mode, token = token, since = now }
    TriggerClientEvent('elyzea_anim:session', a, { partner = b, emote = emoteA, mode = mode })
    TriggerClientEvent('elyzea_anim:session', b, { partner = a, emote = emoteB, mode = mode })
    -- Sécurité : une animation à deux n'est jamais gardée indéfiniment
    SetTimeout(IX.SessionMaxDuration * 1000, function()
        if Sessions[a] and Sessions[a].token == token then Sessions[a] = nil end
        if Sessions[b] and Sessions[b].token == token then Sessions[b] = nil end
    end)
end

RegisterNetEvent('elyzea_anim:respond', function(accept, reason)
    local src = source
    local p = Pending[src]
    if not p then return end
    local from = p.from
    Pending[src] = nil
    if Outgoing[from] == src then Outgoing[from] = nil end
    if online(from) then TriggerClientEvent('elyzea_anim:outgoingEnd', from) end
    if not online(from) then return notify(src, "Ce joueur n'est plus là", 'err') end

    if not accept then
        local why = type(reason) == 'string' and (' (' .. reason:sub(1, 80) .. ')') or ''
        return notify(from, ('%s a refusé : %s%s'):format(name(src), p.label, why), 'err')
    end
    -- Conditions revérifiées au moment d'accepter
    if distance(src, from) > Config.MaxDistance + 1.0 then
        notify(src, 'Vous êtes trop loin l\'un de l\'autre', 'err')
        return notify(from, 'Vous êtes trop loin l\'un de l\'autre', 'err')
    end
    for _, id in ipairs({ src, from }) do
        local why = busyReason(id)
        if why then
            local msg = ('Animation annulée : %s est %s'):format(name(id), why)
            notify(src, msg, 'err')
            return notify(from, msg, 'err')
        end
    end

    -- src = celui qui accepte, from = celui qui a demandé
    if p.mode == 'together' then
        startSession(from, src, p.emote, p.emote, 'together')
        TriggerClientEvent('elyzea_anim:together', from, { partner = src, emote = p.emote, label = p.label })
        TriggerClientEvent('elyzea_anim:together', src, { partner = from, emote = p.emote, label = p.label })
    else
        -- Lancement par rpemotes : même logique que son propre système d'acceptation (il place les deux joueurs)
        local other = ElyzeaSharedPartners[p.emote] or p.emote
        startSession(from, src, p.emote, other, 'shared')
        TriggerClientEvent('SyncPlayEmote', src, other, from)
        TriggerClientEvent('SyncPlayEmoteSource', from, p.emote, src)
    end
    notify(from, ('%s a accepté : %s'):format(name(src), p.label), 'ok')
end)

-- Un des deux arrête (X, mort, menottes, éloignement) ou l'animation est finie
local STOP_TEXT = {
    stopped = '%s a arrêté l\'animation',
    dead = 'Animation arrêtée : %s est à terre',
    cuffed = 'Animation arrêtée : %s a été menotté',
    distance = 'Animation arrêtée : vous êtes trop loin l\'un de l\'autre',
}
local function endSession(src, reason, silentPartner)
    local s = Sessions[src]
    if not s then return end
    Sessions[src] = nil
    local partner = s.partner
    local ps = Sessions[partner]
    if ps and ps.token == s.token then
        Sessions[partner] = nil
        if online(partner) then
            if silentPartner then
                TriggerClientEvent('elyzea_anim:sessionClear', partner)
            else
                TriggerClientEvent('elyzea_anim:partnerStop', partner, (STOP_TEXT[reason] or STOP_TEXT.stopped):format(name(src)))
            end
        end
    end
end

RegisterNetEvent('elyzea_anim:sessionEnd', function(reason)
    local src = source
    reason = STOP_TEXT[reason] and reason or (reason == 'finished' and 'finished' or 'stopped')
    endSession(src, reason, reason == 'finished')
end)

-- ---------------------------------------------------------
--  Copier l'animation : on demande au jeu de la personne visée ce qu'elle joue vraiment
-- ---------------------------------------------------------
local CopyAsks = {}   -- [token] = { from, target, timer }
local lastCopy = {}

RegisterNetEvent('elyzea_anim:copyAsk', function(target)
    local src = source
    target = tonumber(target)
    if not target or target == src or not online(target) then return notify(src, "Cette personne n'est plus là", 'err') end
    local now = GetGameTimer()
    if (lastCopy[src] or 0) > now then return notify(src, 'Attends un peu avant de copier à nouveau', 'err') end
    lastCopy[src] = now + IX.Copy.Cooldown * 1000
    if distance(src, target) > IX.Copy.MaxDistance then return notify(src, 'Cette personne est trop loin', 'err') end
    local token
    repeat token = math.random(1, 99999999) until not CopyAsks[token]
    CopyAsks[token] = { from = src, target = target }
    TriggerClientEvent('elyzea_anim:copyProbe', target, token)
    SetTimeout(IX.Copy.ReplyTimeout, function()
        if CopyAsks[token] then
            CopyAsks[token] = nil
            if online(src) then notify(src, 'Impossible de savoir quelle animation fait cette personne (pas de réponse)', 'err') end
        end
    end)
end)

RegisterNetEvent('elyzea_anim:copyReply', function(token, info)
    local src = source
    local ask = CopyAsks[tonumber(token) or -1]
    if not ask or ask.target ~= src then return end   -- seule la personne interrogée peut répondre
    CopyAsks[tonumber(token)] = nil
    if not online(ask.from) then return end
    info = type(info) == 'table' and info or {}
    local out = { kind = 'unknown' }
    if info.kind == 'none' or info.kind == 'unknown' or info.kind == 'shared' then
        out.kind = info.kind
    elseif info.kind == 'emote' then
        local e = type(info.cmd) == 'string' and info.cmd:sub(1, 7) ~= 'nearby_' and ElyzeaAnims[info.cmd]
        if e and e.k == 'e' then
            out = { kind = 'emote', cmd = info.cmd }
            local ph = tonumber(info.phase)
            if ph and ph >= 0 and ph <= 1 then out.phase = ph end
        end
    end
    if out.kind == 'emote' and distance(ask.from, src) > IX.Copy.MaxDistance + 2.0 then
        return notify(ask.from, 'Cette personne est trop loin', 'err')
    end
    TriggerClientEvent('elyzea_anim:copyResult', ask.from, out, name(src))
end)

-- ---------------------------------------------------------
--  Déconnexion : invitations et animations à deux nettoyées, l'autre est prévenu
-- ---------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    local who = name(src)
    lastRequest[src], lastCopy[src] = nil, nil
    if Pending[src] then clearPending(src, ('%s s\'est déconnecté'):format(who), nil) end
    local target = Outgoing[src]
    if target and Pending[target] and Pending[target].from == src then
        clearPending(target, nil, ('%s s\'est déconnecté : invitation annulée'):format(who))
    end
    Outgoing[src] = nil
    local s = Sessions[src]
    if s then
        Sessions[src] = nil
        local ps = Sessions[s.partner]
        if ps and ps.token == s.token then
            Sessions[s.partner] = nil
            if online(s.partner) then TriggerClientEvent('elyzea_anim:partnerStop', s.partner, ('%s s\'est déconnecté'):format(who)) end
        end
    end
    for token, ask in pairs(CopyAsks) do
        if ask.from == src or ask.target == src then CopyAsks[token] = nil end
    end
end)
