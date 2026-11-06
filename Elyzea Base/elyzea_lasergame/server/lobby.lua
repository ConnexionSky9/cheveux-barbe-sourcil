-- =====================================================================
--  ELYZEA LASERGAME - LOBBIES PVP
--  Rejoindre, quitter, mot de passe, invitations, expulsion, transfert d'hôte,
--  liste des parties diffusée aux joueurs qui ont l'interface ouverte (limitée à 2 envois / s).
-- =====================================================================
Lobby = { watchers = {} }

local INVITE_TTL = 120

function Lobby.New(mode, src, id, opts)
    local g = {
        uid = Games.NewUid('PVP'),
        mode = mode,
        name = opts.name,
        host = src, hostCid = id.cid, hostName = id.name,
        private = opts.private == true,
        password = (opts.password and opts.password ~= '') and opts.password or nil,
        createdAt = os.time(), lastActivity = os.time(),
        phase = LG.Phase.LOBBY,
        players = {}, order = {}, spectators = {}, invites = {},
        map = opts.map,
    }
    Games.list[g.uid] = g
    return g
end

-- Ajoute un joueur (les contrôles de place / équipe sont faits par le mode)
function Lobby.Add(g, src, id, extra)
    local p = { src = src, cid = id.cid, name = id.name, firstname = id.firstname, lastname = id.lastname, ready = false, joinedAt = os.time() }
    for k, v in pairs(extra or {}) do p[k] = v end
    g.players[src] = p
    g.order[#g.order + 1] = src
    g.lastActivity = os.time()
    Games.Attach(g, src, 'player')
    return p
end

-- Retire un joueur du lobby (la mise éventuelle est remboursée par l'appelant)
function Lobby.Remove(g, src)
    g.players[src] = nil
    for i, s in ipairs(g.order) do if s == src then table.remove(g.order, i) break end end
    Games.Detach(src)
    g.lastActivity = os.time()
    if g.host == src then
        local nextHost = g.order[1]
        if nextHost and g.players[nextHost] then
            g.host, g.hostCid, g.hostName = nextHost, g.players[nextHost].cid, g.players[nextHost].name
            Games.Notify(nextHost, 'Tu es maintenant l\'hôte de la partie.', 'info')
        end
    end
end

function Lobby.Count(g)
    local n = 0
    for _ in pairs(g.players) do n = n + 1 end
    return n
end

-- Accès : partie publique, mot de passe correct, ou invitation valide
function Lobby.CheckAccess(g, id, password)
    local inv = g.invites[id.cid]
    if inv and inv > os.time() then return true end
    if g.password and g.password ~= tostring(password or '') then return false, 'Mot de passe incorrect.' end
    if g.private and not g.password then return false, 'Partie privée : sur invitation seulement.' end
    return true
end

-- Invitation par l'hôte d'un joueur connecté (id serveur)
function Lobby.Invite(g, src, target)
    if g.host ~= src then return false, 'Seul l\'hôte peut inviter.' end
    target = tonumber(target)
    if not target or not GetPlayerName(target) or target == src then return false, 'Joueur introuvable.' end
    local tid = Bridge.Identity(target)
    if not tid then return false, 'Joueur introuvable.' end
    if Games.ByPlayer(target) then return false, 'Ce joueur est déjà dans une partie.' end
    g.invites[tid.cid] = os.time() + INVITE_TTL
    TriggerClientEvent('elyzea_lasergame:invite', target, { uid = g.uid, mode = g.mode, name = g.name, host = g.hostName, ttl = INVITE_TTL })
    return true
end

-- Joueurs proches de l'hôte (pour l'écran d'invitation) : seulement l'id serveur et le nom RP
function Lobby.Nearby(src, radius)
    local out = {}
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return out end
    local c = GetEntityCoords(ped)
    for _, sid in ipairs(GetPlayers()) do
        local s = tonumber(sid)
        if s ~= src and GetPlayerRoutingBucket(s) == GetPlayerRoutingBucket(src) then
            local p2 = GetPlayerPed(s)
            if p2 and p2 ~= 0 and #(GetEntityCoords(p2) - c) <= (radius or 40.0) and not Games.ByPlayer(s) then
                local id = Bridge.Identity(s)
                if id then out[#out + 1] = { id = s, name = id.name } end
            end
        end
    end
    return out
end

-- ---------------------------------------------------------------- diffusion
-- Vue détaillée du lobby à ses membres
function Lobby.Push(g)
    local h = Games.handlers[g.mode]
    for _, s in ipairs(Games.PlayerList(g)) do
        TriggerClientEvent('elyzea_lasergame:lobby', s, h.lobbyView(g, s))
    end
    Lobby.PushList()
end

-- Liste des parties à ceux qui ont l'interface ouverte (regroupée : 2 envois / s au plus)
local listDirty = false
function Lobby.PushList() listDirty = true end

function Lobby.PublicList(src)
    local out = {}
    for _, g in pairs(Games.list) do
        if not g.closed then
            local v = Games.PublicView(g)
            if v and (not g.private or (src and g.players[src])) then out[#out + 1] = v end
        end
    end
    table.sort(out, function(a, b) return (a.createdAt or 0) > (b.createdAt or 0) end)
    return out
end

CreateThread(function()
    while true do
        Wait(500)
        if listDirty then
            listDirty = false
            local list = Lobby.PublicList()
            for s in pairs(Lobby.watchers) do
                if GetPlayerName(s) then TriggerClientEvent('elyzea_lasergame:list', s, list) else Lobby.watchers[s] = nil end
            end
        end
    end
end)

-- L'interface est ouverte / fermée (inscription à la liste en direct)
RPC.Register('ui:watch', function(src, on)
    Lobby.watchers[src] = on == true or nil
    return true
end)
AddEventHandler('playerDropped', function() Lobby.watchers[source] = nil end)

-- Lobbies inactifs fermés (et remboursés) automatiquement
CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()
        for _, g in pairs(Games.list) do
            if g.phase == LG.Phase.LOBBY and not g.closed then
                local limit = Config.PvP.lobbyIdleTimeout
                if now - g.lastActivity > limit or Lobby.Count(g) == 0 then
                    local h = Games.handlers[g.mode]
                    if h and h.cancel then h.cancel(g, 'lobby inactif') end
                end
            end
        end
    end
end)
