-- =====================================================================
--  Danses : invitations, consentement et groupes en attente (serveur)
--  - une invitation n'existe que côté serveur, avec un identifiant aléatoire
--  - seul son destinataire peut y répondre, une seule fois, avant expiration
--  - à l'acceptation, les conditions sont vérifiées une nouvelle fois
--  - un joueur n'a jamais plus d'une invitation en attente, ni ne peut être dans deux danses
-- =====================================================================
local Sec, S = Danse.Sec, Danse.Sessions
local notify = Danse.Notify
local I = { list = {}, byTarget = {}, lastSent = {} }
local L = { list = {}, of = {}, nextId = 0 }
Danse.Invites, Danse.Lobbies = I, L

function Danse.Label(src)
    return ('Une personne (ID %d)'):format(src)
end
local label = Danse.Label

-- Occupé : dans une danse, ou dans un groupe qui attend son départ
function Danse.Busy(src) return S.of[src] ~= nil or L.of[src] ~= nil end

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
    if Sec.Online(inv.to) then TriggerClientEvent('elyzea_danse:cl:inviteEnd', inv.to, id, reason) end
    return inv
end
I.Close = close

-- Envoi commun : l'invitation part vers target, expire toute seule
local function send(kind, from, target, entry, extra)
    local id = newId()
    local inv = { id = id, kind = kind, from = from, to = target, anim = entry.id,
        expires = GetGameTimer() + DanseConfig.Invite.Timeout * 1000 }
    for k, v in pairs(extra or {}) do inv[k] = v end
    I.list[id], I.byTarget[target] = inv, id
    TriggerClientEvent('elyzea_danse:cl:invite', target, {
        id = id, kind = kind, anim = entry.id, label = entry.label, from = label(from), timeout = DanseConfig.Invite.Timeout,
        count = extra and extra.count or nil,
    })
    SetTimeout(DanseConfig.Invite.Timeout * 1000, function()
        if I.list[id] == inv then
            close(id, 'expiree')
            notify(target, 'Invitation expirée', 'info')
            if kind == 'duo' then
                notify(from, 'Pas de réponse : invitation expirée', 'err')
            else
                L.Answered(inv.lobby, target, false, 'expiree')
            end
        end
    end)
    return inv
end

-- Peut-on inviter ce joueur ? (message d'erreur pour l'auteur, ou nil)
local function targetProblem(from, target, maxDist)
    if not Sec.Online(target) then return 'Cette personne n\'est plus là' end
    if target == from then return 'Choisis une autre personne' end
    local b = Sec.Blocker(target)
    if b then return 'Cette personne ' .. Sec.BlockerText[b] end
    if Danse.Busy(target) then return 'Cette personne danse déjà' end
    if I.byTarget[target] then return 'Cette personne a déjà une invitation en attente' end
    local mine = I.byTarget[from] and I.list[I.byTarget[from]]
    if mine and mine.from == target then return 'Cette personne t\'a déjà invité(e) : réponds à son invitation' end
    if Sec.Distance(from, target) > maxDist then return 'Cette personne est trop loin' end
    return nil
end

local function senderProblem(src)
    if not Sec.Allow(src, 'invite', DanseConfig.Invite.MaxPerMinute, 60000) then return 'Trop d\'invitations : patiente un peu' end
    local b = Sec.Blocker(src)
    if b then return Sec.SelfText[b] end
    if Danse.Busy(src) then return 'Arrête d\'abord ta danse en cours' end
    if (I.lastSent[src] or 0) > GetGameTimer() then return 'Attends quelques secondes avant une nouvelle invitation' end
    for _, inv in pairs(I.list) do
        if inv.from == src and inv.kind == 'duo' then return 'Tu as déjà une invitation en attente' end
    end
    return nil
end

-- ── Duo ────────────────────────────────────────────────────────────────
function I.SendDuo(src, target, animId, role)
    local entry = DanseCatalog.Get(animId)
    target = tonumber(target)
    if not entry or entry.type ~= 'duo' or not DanseCatalog.IsPlayable(entry) or not target or (role ~= 'A' and role ~= 'B') then return end
    target = math.floor(target)
    local err = senderProblem(src) or targetProblem(src, target, DanseConfig.Invite.MaxDistance)
    if err then return notify(src, err, 'err') end
    I.lastSent[src] = GetGameTimer() + DanseConfig.Invite.Cooldown * 1000
    send('duo', src, target, entry, { fromRole = role })
    notify(src, ('Invitation envoyée à %s : %s'):format(label(target), entry.label), 'info')
end

-- ── Groupe : création et attente des réponses ──────────────────────────
function L.Create(src, animId, formation, targets)
    local entry = DanseCatalog.Get(animId)
    if not entry or entry.type ~= 'groupe' or not DanseCatalog.IsPlayable(entry) or type(targets) ~= 'table' then return end
    local allowed = entry.formations or { 'ligne' }
    local okForm = false
    for _, f in ipairs(allowed) do if f == formation then okForm = true end end
    if not okForm then formation = allowed[1] end

    local err = senderProblem(src)
    if err then return notify(src, err, 'err') end

    local list, seen = {}, {}
    for _, t in ipairs(targets) do
        t = tonumber(t)
        if t and not seen[t] and #list < DanseConfig.Group.MaxMembers - 1 then
            seen[t] = true
            list[#list + 1] = math.floor(t)
        end
    end
    if #list == 0 then return notify(src, 'Choisis au moins une personne', 'err') end

    L.nextId = L.nextId + 1
    local lobby = { id = L.nextId, host = src, entry = entry, formation = formation, accepted = { src }, pending = {}, created = GetGameTimer() }
    local skipped = 0
    for _, t in ipairs(list) do
        if targetProblem(src, t, DanseConfig.Group.InviteDistance) then
            skipped = skipped + 1
        else
            local inv = send('groupe', src, t, entry, { lobby = lobby.id, count = #list + 1 })
            lobby.pending[t] = inv.id
        end
    end
    if not next(lobby.pending) then return notify(src, 'Personne n\'est disponible à proximité', 'err') end
    L.list[lobby.id], L.of[src] = lobby, lobby.id
    I.lastSent[src] = GetGameTimer() + DanseConfig.Invite.Cooldown * 1000
    local n = 0 for _ in pairs(lobby.pending) do n = n + 1 end
    notify(src, ('Groupe « %s » : %d invitation(s) envoyée(s)%s. La danse démarre quand tout le monde a répondu (%s pour arrêter).')
        :format(entry.label, n, skipped > 0 and (', ' .. skipped .. ' personne(s) indisponible(s)') or '', 'X'), 'info')
    Danse.EnsureMonitor()
end

local function lobbyStatus(lobby)
    local p = 0 for _ in pairs(lobby.pending) do p = p + 1 end
    TriggerClientEvent('elyzea_danse:cl:lobby', lobby.host, { label = lobby.entry.label, accepted = #lobby.accepted - 1, pending = p })
end

local function dissolve(lobby, text)
    L.list[lobby.id] = nil
    for t, id in pairs(lobby.pending) do close(id, 'annulee') lobby.pending[t] = nil end
    for _, p in ipairs(lobby.accepted) do
        if L.of[p] == lobby.id then L.of[p] = nil end
        if text then notify(p, text, 'info') end
    end
end

-- Départ : avec les membres encore disponibles, s'ils sont au moins deux
function L.Start(lid)
    local lobby = L.list[lid]
    if not lobby then return end
    for t, id in pairs(lobby.pending) do close(id, 'annulee') lobby.pending[t] = nil end
    local members = {}
    for _, p in ipairs(lobby.accepted) do
        local ok = Sec.Online(p) and not Sec.Blocker(p)
            and (p == lobby.host or Sec.Distance(lobby.host, p) <= DanseConfig.Group.InviteDistance + 2.0)
        if p == lobby.host and not ok then return dissolve(lobby, 'Le meneur n\'est plus disponible : groupe annulé') end
        if ok then members[#members + 1] = p elseif Sec.Online(p) then notify(p, 'Tu n\'es plus disponible : tu ne participes pas', 'err') end
    end
    dissolve(lobby, nil)
    if #members < 2 then return notify(lobby.host, 'Personne n\'a rejoint ton groupe', 'err') end
    S.Create(lobby.entry, members, lobby.formation)
end

-- Réponse (ou expiration) d'un invité de groupe
function L.Answered(lid, target, accepted, why)
    local lobby = L.list[lid]
    if not lobby then return end
    lobby.pending[target] = nil
    if accepted then
        lobby.accepted[#lobby.accepted + 1] = target
        L.of[target] = lid
        notify(target, ('Tu as rejoint « %s » : départ quand tout le monde a répondu'):format(lobby.entry.label), 'ok')
        notify(lobby.host, ('%s a accepté'):format(label(target)), 'ok')
    elseif why ~= 'expiree' then
        notify(lobby.host, ('%s a décliné'):format(label(target)), 'info')
    end
    lobbyStatus(lobby)
    if not next(lobby.pending) then L.Start(lid) end
end

-- Le meneur lance tout de suite, sans attendre les réponses restantes
function L.StartNow(src)
    local lid = L.of[src]
    local lobby = lid and L.list[lid]
    if lobby and lobby.host == src then L.Start(lid) end
end

-- Quitter un groupe avant son départ (le meneur annule tout)
function L.Leave(src, why)
    local lid = L.of[src]
    local lobby = lid and L.list[lid]
    if not lobby then return false end
    if lobby.host == src then
        dissolve(lobby, why == 'deconnexion' and 'Le meneur s\'est déconnecté : groupe annulé' or 'Le meneur a annulé la danse de groupe')
        return true
    end
    for i = #lobby.accepted, 1, -1 do if lobby.accepted[i] == src then table.remove(lobby.accepted, i) end end
    L.of[src] = nil
    if why ~= 'deconnexion' then notify(src, 'Tu as quitté le groupe', 'info') end
    notify(lobby.host, ('%s a quitté le groupe'):format(label(src)), 'info')
    lobbyStatus(lobby)
    return true
end

-- Filet de sécurité (appelé par la surveillance) : un groupe ne reste jamais bloqué en attente
function L.Check()
    local limit = (DanseConfig.Invite.Timeout + 5) * 1000
    for lid, lobby in pairs(L.list) do
        if not Sec.Online(lobby.host) then dissolve(lobby, 'Le meneur s\'est déconnecté : groupe annulé')
        elseif GetGameTimer() - lobby.created > limit then L.Start(lid) end
    end
end

-- ── Réponse à une invitation (duo ou groupe) ───────────────────────────
function I.Respond(src, id, accept)
    if not Sec.Allow(src, 'respond', 10, 10000) then return end
    id = tonumber(id)
    local inv = id and I.list[id]
    if not inv then return end
    if inv.to ~= src then
        print(('[Elyzea danses] %s (%d) a tenté de répondre à une invitation qui ne lui est pas destinée'):format(GetPlayerName(src) or '?', src))
        return
    end
    close(id, accept and 'acceptee' or 'refusee')
    local from, entry = inv.from, DanseCatalog.Get(inv.anim)
    if GetGameTimer() > inv.expires then return notify(src, 'Invitation expirée', 'err') end

    if inv.kind == 'groupe' then
        if not accept then return L.Answered(inv.lobby, src, false, 'refusee') end
        local lobby = L.list[inv.lobby]
        if not lobby then return notify(src, 'Ce groupe n\'existe plus', 'err') end
        local b = Sec.Blocker(src)
        local problem = (b and Sec.SelfText[b]) or (Danse.Busy(src) and 'Tu danses déjà')
            or (Sec.Distance(lobby.host, src) > DanseConfig.Group.InviteDistance + 2.0 and 'Tu es trop loin du meneur')
            or (#lobby.accepted >= DanseConfig.Group.MaxMembers and 'Le groupe est complet')
        if problem then
            notify(src, problem, 'err')
            return L.Answered(inv.lobby, src, false, 'refusee')
        end
        return L.Answered(inv.lobby, src, true)
    end

    -- Duo
    if not accept then return notify(from, 'Invitation déclinée', 'info') end
    if not Sec.Online(from) then return notify(src, 'Cette personne n\'est plus là', 'err') end
    local b = Sec.Blocker(src)
    local problem = (b and Sec.SelfText[b]) or (Danse.Busy(src) and 'Tu danses déjà')
    local fromProblem = (Sec.Blocker(from) and 'Ton ou ta partenaire n\'est plus disponible')
        or (Danse.Busy(from) and 'Ton ou ta partenaire danse déjà')
        or (Sec.Distance(from, src) > DanseConfig.Invite.StartDistance and 'Vous êtes trop loin l\'un de l\'autre')
    if problem or fromProblem then
        notify(src, problem or fromProblem, 'err')
        return notify(from, fromProblem or 'Impossible de commencer : ta ou ton partenaire n\'est pas disponible', 'err')
    end
    local a, bb = from, src
    if inv.fromRole == 'B' then a, bb = src, from end
    notify(from, 'Invitation acceptée : ' .. entry.label, 'ok')
    S.Create(entry, { a, bb }, nil)
end

function I.Dropped(src)
    for id, inv in pairs(I.list) do
        if inv.to == src then
            close(id, 'deconnexion')
            if inv.kind == 'groupe' then L.Answered(inv.lobby, src, false, 'expiree')
            else notify(inv.from, 'Invitation annulée : la personne s\'est déconnectée', 'info') end
        elseif inv.from == src and inv.kind == 'duo' then
            close(id, 'deconnexion')
            notify(inv.to, 'Invitation annulée : la personne s\'est déconnectée', 'info')
        end
    end
    L.Leave(src, 'deconnexion')
    I.lastSent[src] = nil
end
