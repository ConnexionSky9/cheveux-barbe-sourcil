-- =====================================================================
--  rp_animations : invitations et consentement (serveur)
--  - une invitation n'existe que côté serveur, avec un identifiant aléatoire
--  - seul son destinataire peut y répondre, une seule fois, avant expiration
--  - à l'acceptation, toutes les conditions sont vérifiées une nouvelle fois
-- =====================================================================
local Sec, S = RPA.Sec, RPA.Sessions
local notify = RPA.Notify
local I = { list = {}, byTarget = {}, byFrom = {}, lastSent = {}, prefs = {} }
RPA.Invites = I

local function label(src)
    if Config.Invite.ShowNames then
        local ok, name = pcall(function() return exports.elyzea_core:GetCharName(src) end)
        if ok and type(name) == 'string' and name ~= '' then return ('%s (ID %d)'):format(name, src) end
    end
    return ('Une personne (ID %d)'):format(src)
end
RPA.Label = label

function I.Prefs(src) return I.prefs[src] or {} end

local function newId()
    local id
    repeat id = math.random(100000, 999999999) until not I.list[id]
    return id
end

local function close(id, reason)
    local inv = I.list[id]
    if not inv then return nil end
    I.list[id] = nil
    if I.byTarget[inv.to] == id then I.byTarget[inv.to] = nil end
    if I.byFrom[inv.from] == id then I.byFrom[inv.from] = nil end
    if Sec.Online(inv.to) then TriggerClientEvent('rp_animations:cl:inviteEnd', inv.to, id, reason) end
    if Sec.Online(inv.from) then TriggerClientEvent('rp_animations:cl:outgoingEnd', inv.from, id, reason) end
    return inv
end
I.Close = close

-- Vérifications communes à l'envoi et à l'acceptation. Renvoie un message d'erreur pour from, ou nil.
local function check(from, to, entry, maxDist)
    if not Catalog.IsPlayable(entry) or entry.type ~= 'duo' then return 'Cette animation n\'est pas disponible' end
    if from == to then return 'Choisis une autre personne' end
    local b = Sec.Blocker(from)
    if b then return Sec.SelfText[b] end
    b = Sec.Blocker(to)
    if b then return 'Cette personne ' .. Sec.BlockerText[b] end
    if S.Busy(from) then return 'Arrête d\'abord ton animation en cours' end
    if S.Busy(to) then return 'Cette personne est déjà occupée' end
    if Sec.Distance(from, to) > maxDist then return 'Cette personne est trop loin' end
    if entry.adult then
        if not Config.Adult.Enabled then return 'Les animations adultes sont désactivées sur ce serveur' end
        if not I.Prefs(from).adult then return 'Active d\'abord les animations adultes dans tes réglages' end
        if not I.Prefs(to).adult then return 'Cette personne n\'accepte pas ce type d\'invitation' end
    end
    return nil
end

function I.Send(src, target, animId, role)
    if not Sec.Allow(src, 'invite', Config.Invite.MaxPerMinute, 60000) then
        return notify(src, 'Trop d\'invitations : patiente un peu', 'err')
    end
    target = tonumber(target)
    local entry = Catalog.Get(animId)
    if not target or not entry or (role ~= 'A' and role ~= 'B') then return end
    target = math.floor(target)
    if not Sec.Online(target) then return notify(src, 'Cette personne n\'est plus là', 'err') end

    local now = GetGameTimer()
    if (I.lastSent[src] or 0) > now then return notify(src, 'Attends quelques secondes avant une nouvelle invitation', 'err') end
    if I.byFrom[src] then return notify(src, 'Tu as déjà une invitation en attente', 'err') end
    if I.byTarget[target] then return notify(src, 'Cette personne a déjà une invitation en attente', 'err') end
    if I.Prefs(target).dnd then return notify(src, 'Cette personne n\'accepte pas d\'invitation pour le moment', 'err') end

    local err = check(src, target, entry, Config.Invite.MaxDistance)
    if err then return notify(src, err, 'err') end

    I.lastSent[src] = now + Config.Invite.Cooldown * 1000
    local id = newId()
    local inv = { id = id, from = src, to = target, anim = entry.id, fromRole = role, expires = now + Config.Invite.Timeout * 1000 }
    I.list[id], I.byTarget[target], I.byFrom[src] = inv, id, id

    local targetRole = role == 'A' and 'B' or 'A'
    TriggerClientEvent('rp_animations:cl:invite', target, {
        id = id, anim = entry.id, label = entry.label, from = label(src), timeout = Config.Invite.Timeout,
        adult = entry.adult == true, fade = entry.fade == true and Config.Adult.FadeAllowed,
        role = targetRole, roleLabel = entry.roles and entry.roles[targetRole] or targetRole,
    })
    TriggerClientEvent('rp_animations:cl:outgoing', src, { id = id, label = entry.label, to = label(target), timeout = Config.Invite.Timeout })

    SetTimeout(Config.Invite.Timeout * 1000, function()
        local cur = I.list[id]
        if cur and cur == inv then
            close(id, 'expiree')
            notify(src, 'Pas de réponse : invitation expirée', 'err')
            notify(target, 'Invitation expirée', 'info')
        end
    end)
end

-- Réponse : seul le destinataire de CETTE invitation peut répondre, une seule fois
function I.Respond(src, id, accept, confirmAdult)
    if not Sec.Allow(src, 'respond', 10, 10000) then return end
    id = tonumber(id)
    local inv = id and I.list[id]
    if not inv then return end
    if inv.to ~= src then
        print(('[rp_animations] %s (%d) a tenté de répondre à une invitation qui ne lui est pas destinée'):format(GetPlayerName(src) or '?', src))
        return
    end
    close(id, accept and 'acceptee' or 'refusee')

    local from, entry = inv.from, Catalog.Get(inv.anim)
    if GetGameTimer() > inv.expires then return notify(src, 'Invitation expirée', 'err') end
    if accept ~= true then
        -- Refuser n'a aucune conséquence : simple message à l'auteur
        return notify(from, 'Invitation déclinée', 'info')
    end
    if entry.adult and confirmAdult ~= true then
        notify(from, 'Invitation non confirmée', 'info')
        return notify(src, 'Une confirmation explicite est nécessaire pour ce type d\'animation', 'err')
    end
    if not Sec.Online(from) then return notify(src, 'Cette personne n\'est plus là', 'err') end

    -- Nouvelle vérification complète au moment de l'acceptation
    local err = check(from, src, entry, Config.Invite.StartDistance)
    if err then
        notify(from, err, 'err')
        return notify(src, 'Impossible de commencer : conditions non réunies', 'err')
    end

    local a, b = from, src
    if inv.fromRole == 'B' then a, b = src, from end
    notify(from, 'Invitation acceptée : ' .. entry.label, 'ok')
    S.Create(entry, a, b)
end

function I.Cancel(src)
    local id = I.byFrom[src]
    if id then close(id, 'annulee') end
end

function I.Dropped(src)
    for id, inv in pairs(I.list) do
        if inv.from == src or inv.to == src then
            close(id, 'deconnexion')
            local other = inv.from == src and inv.to or inv.from
            notify(other, 'Invitation annulée : la personne s\'est déconnectée', 'info')
        end
    end
    I.lastSent[src], I.prefs[src] = nil, nil
end
