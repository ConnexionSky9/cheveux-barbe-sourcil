-- =====================================================================
--  ELYZEA LASERGAME - REGISTRE DES PARTIES (PVP + Zombie)
--  Lobbies, instances (routing buckets), entrée / sortie des joueurs, spectateurs,
--  diffusion ciblée des événements (seulement aux membres d'une partie).
-- =====================================================================
Games = { list = {}, byPlayer = {}, slots = {}, handlers = {} }

local seq = 0
function Games.NewUid(prefix)
    seq = (seq + 1) % 1000
    return ('%s%s%03d'):format(prefix, os.time(), seq)
end

-- Gestionnaires par mode : Games.handlers[mode] = { leave = fn(g, src, reason), drop = fn(g, src), view = fn(g, src) }
function Games.Register(mode, h) Games.handlers[mode] = h end

function Games.ByPlayer(src)
    local r = Games.byPlayer[src]
    if not r then return nil end
    local g = Games.list[r.uid]
    if not g then Games.byPlayer[src] = nil return nil end
    return g, r.role
end

function Games.Count()
    local lobbies, running = 0, 0
    for _, g in pairs(Games.list) do
        if g.phase == LG.Phase.LOBBY then lobbies = lobbies + 1 else running = running + 1 end
    end
    return lobbies, running
end

-- Emplacement d'instance (bucket) réservé au lancement d'une partie
function Games.AllocSlot()
    for i = 1, Config.MaxParallelGames do
        if not Games.slots[i] then Games.slots[i] = true return i end
    end
    return nil
end
function Games.FreeSlot(i) if i then Games.slots[i] = nil end end

function Games.Bucket(slot) return Config.BucketBase + slot end

-- Joueurs d'une partie (ordre d'arrivée), membres (joueurs + spectateurs)
function Games.PlayerList(g)
    local out = {}
    for _, s in ipairs(g.order) do if g.players[s] then out[#out + 1] = s end end
    return out
end
function Games.Members(g)
    local out = Games.PlayerList(g)
    for s in pairs(g.spectators or {}) do out[#out + 1] = s end
    return out
end

function Games.Send(g, event, ...)
    for _, s in ipairs(Games.Members(g)) do TriggerClientEvent('elyzea_lasergame:' .. event, s, ...) end
end
function Games.SendPlayers(g, event, ...)
    for _, s in ipairs(Games.PlayerList(g)) do TriggerClientEvent('elyzea_lasergame:' .. event, s, ...) end
end
function Games.Notify(src, msg, kind) TriggerClientEvent('elyzea_lasergame:notify', src, msg, kind or 'info') end

-- Ajout / retrait d'un joueur dans le registre
function Games.Attach(g, src, role)
    Games.byPlayer[src] = { uid = g.uid, role = role or 'player' }
end
function Games.Detach(src) Games.byPlayer[src] = nil end

-- Entrée dans l'instance (au lancement) : sauvegarde de l'état RP AVANT tout changement, verrous RP
function Games.EnterInstance(g, src, role)
    local p = g.players[src]
    local cid = p and p.cid or (Bridge.Identity(src) or {}).cid
    if not cid then return false end
    local snap = Restore.Save(src, cid, g.uid)
    if not snap then return false end
    if p then p.snap = snap end
    -- même contrat que pvp_arena : inventaire RP verrouillé, pas de coma EMS, pas de réapparition hôpital
    Player(src).state:set(LG.StateArena, true, true)
    Player(src).state:set(LG.StateGame, role == 'spectator' and 'spectator' or g.mode, true)
    SetPlayerRoutingBucket(src, g.bucket)
    return true, snap
end

-- Sortie de l'instance : retour au RP (position, vie, gilet, tenue, instance d'origine)
function Games.ExitInstance(g, src, quiet)
    local p = g.players[src]
    local snap = p and p.snap or (g.spectators and g.spectators[src] and g.spectators[src].snap)
    local id = Bridge.Identity(src)
    TriggerClientEvent('elyzea_lasergame:leaveGame', src)
    if snap and id then
        Restore.Apply(src, id.cid, snap, quiet)
    elseif id then
        Restore.FromDb(src)
    end
end

-- Quitter pour n'importe quelle raison (bouton, staff, restauration forcée)
function Games.ForceLeave(src, reason)
    local g, role = Games.ByPlayer(src)
    if not g then return false end
    if role == 'spectator' then return Games.LeaveSpectator(g, src, false) end
    local h = Games.handlers[g.mode]
    if h and h.leave then h.leave(g, src, reason or 'quitte') end
    return true
end

-- Départ d'un spectateur (bouton, déconnexion, fin de partie)
function Games.LeaveSpectator(g, src, dropped)
    if not g.spectators[src] then Games.Detach(src) return true end
    if not dropped then Games.ExitInstance(g, src, false) end
    g.spectators[src] = nil
    Games.Detach(src)
    return true
end

-- Fermeture d'une partie : libère l'instance
function Games.Close(g)
    if g.closed then return end
    g.closed = true
    g.phase = LG.Phase.CLOSED
    for _, s in ipairs(Games.Members(g)) do
        local r = Games.byPlayer[s]
        if r and r.uid == g.uid then Games.byPlayer[s] = nil end
    end
    Games.FreeSlot(g.slot)
    Games.list[g.uid] = nil
    TriggerClientEvent('elyzea_lasergame:gameClosed', -1, g.uid)
end

-- Déconnexion : le mode gère la partie ; la sauvegarde RP reste en base et sera rejouée à la reconnexion
AddEventHandler('playerDropped', function(reason)
    local src = source
    local g, role = Games.ByPlayer(src)
    if not g then return end
    if role == 'spectator' then return Games.LeaveSpectator(g, src, true) end
    local h = Games.handlers[g.mode]
    if h and h.drop then
        local ok, err = pcall(h.drop, g, src, reason)
        if not ok then Logs.Error('déconnexion en partie : ' .. tostring(err)) end
    end
    Games.byPlayer[src] = nil
end)

-- Vérifie qu'un joueur peut rejoindre une partie (identité, exclusion, déjà occupé)
function Games.CanJoin(src)
    if Games.ByPlayer(src) then return false, 'Tu es déjà dans une partie ou un lobby.' end
    local id = Bridge.Identity(src)
    if not id then return false, 'Personnage introuvable.' end
    if Players.IsExcluded(id.cid) then return false, 'Tu es exclu du LaserGame.' end
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 and GetEntityHealth(ped) <= 0 then return false, 'Impossible en étant à terre.' end
    if GetPlayerRoutingBucket(src) ~= 0 then return false, 'Impossible depuis une instance (intérieur, autre activité).' end
    return true, id
end

-- Vue publique d'une partie pour la liste (aucune donnée sensible)
function Games.PublicView(g)
    local h = Games.handlers[g.mode]
    return h and h.view and h.view(g) or nil
end
