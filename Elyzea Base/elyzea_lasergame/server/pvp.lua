-- =====================================================================
--  ELYZEA LASERGAME - MODE PVP ARENA (serveur)
--  Lobby (formats 1v1 à 6v6, public / privé / mot de passe, invitations, équipes, prêt),
--  mises RP, lancement en instance, manches, éliminations, zone, abandon, fin de partie,
--  classement, paiement, retour au RP. Le serveur est la seule autorité.
-- =====================================================================
Pvp = {}

local T = Config.Teams

local function formatOf(id)
    for _, f in ipairs(Config.PvP.formats) do
        if f.id == id and not (Config.PvP.disabledFormats or {})[f.id] then return f end
    end
end

local function inList(list, v)
    for _, x in ipairs(list) do if x == v then return true end end
    return false
end

local function teamCount(g, team)
    local n = 0
    for _, p in pairs(g.players) do if p.team == team then n = n + 1 end end
    return n
end

local function firstWeapon(cat)
    for _, w in ipairs(LGU.WeaponsOfCategory(cat)) do if not w.disabled then return w.id end end
end

-- ---------------------------------------------------------------- vues
local function lobbyView(g, viewer)
    local teams = { A = {}, B = {} }
    for _, s in ipairs(Games.PlayerList(g)) do
        local p = g.players[s]
        local prof = p.profile or {}
        teams[p.team][#teams[p.team] + 1] = { id = s, name = p.name, ready = p.ready, weapon = p.weapon, paid = p.paid ~= nil,
            host = s == g.host, rank = prof.rank, points = prof.points, me = s == viewer }
    end
    local m = Maps.Get(g.map)
    local weapons = {}
    for _, w in ipairs(LGU.WeaponsOfCategory(g.category)) do
        if not w.disabled then weapons[#weapons + 1] = { id = w.id, label = w.label, damage = w.damage, range = w.range, rpm = w.rpm, mag = w.mag } end
    end
    return {
        uid = g.uid, mode = 'pvp', name = g.name, host = g.hostName, isHost = viewer == g.host, private = g.private, hasPassword = g.password ~= nil,
        format = g.format, size = g.size, map = g.map, mapLabel = m and m.label or g.map, rounds = g.rounds, roundTime = g.roundTime,
        category = g.category, stake = g.stake, pot = g.stake * Lobby.Count(g), phase = g.phase, teams = teams, weapons = weapons,
        ranked = Pvp.IsRanked(g), teamNames = { A = T.A.name, B = T.B.name }, teamColors = { A = T.A.hex, B = T.B.hex },
    }
end

local function publicView(g)
    local m = Maps.Get(g.map)
    local names = {}
    for _, s in ipairs(Games.PlayerList(g)) do names[#names + 1] = { name = g.players[s].name, team = g.players[s].team, alive = g.players[s].alive } end
    local spectators = 0
    for _ in pairs(g.spectators) do spectators = spectators + 1 end
    return {
        uid = g.uid, mode = 'pvp', name = g.name, host = g.hostName, private = g.private, hasPassword = g.password ~= nil,
        format = g.format, size = g.size, map = g.map, mapLabel = m and m.label or g.map, rounds = g.rounds, roundTime = g.roundTime,
        category = g.category, stake = g.stake, players = Lobby.Count(g), max = g.size * 2, phase = g.phase,
        score = g.score, round = g.round or 0, timeLeft = g.roundEndsAt and math.max(0, g.roundEndsAt - os.time()) or nil,
        roster = names, spectators = spectators, createdAt = g.createdAt, ranked = Pvp.IsRanked(g),
    }
end

function Pvp.IsRanked(g)
    local r = Config.PvP.ranked
    return (g.private and r.private or (not g.private and r.public)) == true
end

-- ---------------------------------------------------------------- création / réglages
local function cleanOptions(opts, src, id)
    if type(opts) ~= 'table' then return nil, 'Options invalides.' end
    local f = formatOf(opts.format)
    if not f then return nil, 'Format indisponible.' end
    local ok, m = Maps.Usable(tostring(opts.map or ''), 'pvp')
    if not ok then return nil, m end
    if (m.maxPerTeam or 6) < f.size then return nil, ('%s est trop petite pour du %s.'):format(m.label, f.label) end
    local rounds = tonumber(opts.rounds)
    if not inList(Config.PvP.roundsOptions, rounds) then return nil, 'Nombre de manches invalide.' end
    local rt = tonumber(opts.roundTime)
    if not inList(Config.PvP.roundTimeOptions, rt) then return nil, 'Durée de manche invalide.' end
    local cat = tostring(opts.category or '')
    if not firstWeapon(cat) then return nil, 'Catégorie d\'arme indisponible.' end
    local stake = math.floor(tonumber(opts.stake) or 0)
    if not Config.Stake.enabled then stake = 0 end
    if stake ~= 0 then
        if stake < Config.Stake.min or stake > Config.Stake.max then return nil, ('Mise entre %d $ et %d $.'):format(Config.Stake.min, Config.Stake.max) end
        if stake % (Config.Stake.step or 1) ~= 0 then return nil, ('La mise doit être un multiple de %d $.'):format(Config.Stake.step) end
    elseif Config.Stake.min > 0 and Config.Stake.enabled then
        return nil, ('Mise minimale : %d $.'):format(Config.Stake.min)
    end
    local name = LGU.CleanText(opts.name, Config.PvP.matchNameMaxLength)
    if name == '' then name = ('Partie de %s'):format(id.firstname ~= '' and id.firstname or id.name) end
    local pw = LGU.CleanText(opts.password, Config.PvP.passwordMaxLength)
    return { name = name, format = f.id, size = f.size, map = m.id, rounds = rounds, roundTime = rt, category = cat, stake = stake,
        private = opts.private == true, password = pw ~= '' and pw or nil }
end

local function joinTeam(g, wanted)
    if wanted == 'A' or wanted == 'B' then
        if teamCount(g, wanted) < g.size then return wanted end
        return nil
    end
    local a, b = teamCount(g, 'A'), teamCount(g, 'B')
    if a <= b and a < g.size then return 'A' end
    if b < g.size then return 'B' end
    if a < g.size then return 'A' end
    return nil
end

local function addPlayer(g, src, id, team)
    local prof = DB.Profile(id)
    local rank = LGU.RankFor(prof.points)
    return Lobby.Add(g, src, id, { team = team, weapon = firstWeapon(g.category), kills = 0, deaths = 0, roundsWon = 0,
        profile = { points = prof.points, rank = rank.id, matches = prof.matches } })
end

RPC.Register('pvp:create', function(src, opts)
    if not Config.PvP.enabled then return false, 'Le mode PVP est désactivé.' end
    local can, id = Games.CanJoin(src)
    if not can then return false, id end
    local lobbies = Games.Count()
    if lobbies >= Config.MaxParallelGames * 2 then return false, 'Trop de lobbies ouverts, réessaie plus tard.' end
    local o, err = cleanOptions(opts, src, id)
    if not o then return false, err end
    local g = Lobby.New(LG.Mode.PVP, src, id, o)
    for k, v in pairs(o) do g[k] = v end
    g.score = { A = 0, B = 0 }
    g.round = 0
    addPlayer(g, src, id, 'A')
    Logs.Add('pvp', ('lobby créé « %s » (%s, %s, mise %d $)'):format(g.name, g.format, g.map, g.stake), { uid = g.uid }, src)
    Lobby.Push(g)
    return true, g.uid
end)

-- Modification des réglages par l'hôte (rembourse les mises si le montant change)
RPC.Register('pvp:update', function(src, opts)
    local g = Games.ByPlayer(src)
    if not g or g.mode ~= 'pvp' or g.phase ~= LG.Phase.LOBBY then return false, 'Aucun lobby.' end
    if g.host ~= src then return false, 'Seul l\'hôte peut modifier la partie.' end
    local id = Bridge.Identity(src)
    local o, err = cleanOptions(opts, src, id)
    if not o then return false, err end
    if o.size < math.max(teamCount(g, 'A'), teamCount(g, 'B')) then return false, 'Trop de joueurs pour ce format.' end
    return Security.Locked(src, 'pvp:update', function()
        local stakeChanged = o.stake ~= g.stake
        local catChanged = o.category ~= g.category
        for k, v in pairs(o) do g[k] = v end
        for _, p in pairs(g.players) do
            if stakeChanged and p.paid then Economy.RefundRow(p.paid, 'mise modifiée') p.paid = nil end
            if stakeChanged then p.ready = false end
            if catChanged then p.weapon = firstWeapon(g.category) end
        end
        Lobby.Push(g)
        return true
    end)
end)

RPC.Register('pvp:join', function(src, uid, password, team)
    local g = Games.list[tostring(uid or '')]
    if not g or g.mode ~= 'pvp' then return false, 'Partie introuvable.' end
    if g.phase ~= LG.Phase.LOBBY then return false, 'La partie a déjà commencé (tu peux la regarder en spectateur).' end
    local can, id = Games.CanJoin(src)
    if not can then return false, id end
    local ok, err = Lobby.CheckAccess(g, id, password)
    if not ok then return false, err end
    local t = joinTeam(g, team)
    if not t then return false, 'La partie est complète.' end
    g.invites[id.cid] = nil
    addPlayer(g, src, id, t)
    Lobby.Push(g)
    return true, g.uid
end)

-- Matchmaking : rejoint la partie publique la plus remplie du format choisi, sinon en crée une
RPC.Register('pvp:quick', function(src, formatId, stake)
    if not Config.PvP.enabled then return false, 'Le mode PVP est désactivé.' end
    local can, id = Games.CanJoin(src)
    if not can then return false, id end
    stake = math.floor(tonumber(stake) or 0)
    local best, bestN
    for _, g in pairs(Games.list) do
        if g.mode == 'pvp' and g.phase == LG.Phase.LOBBY and not g.private and not g.password and g.format == formatId and g.stake == stake then
            local n = Lobby.Count(g)
            if n < g.size * 2 and (not bestN or n > bestN) then best, bestN = g, n end
        end
    end
    if best then
        local t = joinTeam(best)
        addPlayer(best, src, id, t)
        Lobby.Push(best)
        return true, best.uid, false
    end
    local mapId
    local f = formatOf(formatId)
    if not f then return false, 'Format indisponible.' end
    for _, mid in ipairs(Maps.order) do
        local m = Maps.Get(mid)
        if m.mode == 'pvp' and m.enabled and (m.maxPerTeam or 6) >= f.size and (m.recommended or {})[f.id] then mapId = mid break end
    end
    if not mapId then
        for _, mid in ipairs(Maps.order) do
            local m = Maps.Get(mid)
            if m.mode == 'pvp' and m.enabled and (m.maxPerTeam or 6) >= f.size then mapId = mid break end
        end
    end
    if not mapId then return false, 'Aucune carte disponible.' end
    local o, err = cleanOptions({ format = formatId, map = mapId, rounds = Config.PvP.defaultRounds, roundTime = Config.PvP.defaultRoundTime,
        category = 'rifle', stake = stake, name = ('Matchmaking %s'):format(f.label) }, src, id)
    if not o then return false, err end
    local g = Lobby.New(LG.Mode.PVP, src, id, o)
    for k, v in pairs(o) do g[k] = v end
    g.score, g.round, g.matchmaking = { A = 0, B = 0 }, 0, true
    addPlayer(g, src, id, 'A')
    Lobby.Push(g)
    return true, g.uid, true
end)

RPC.Register('pvp:team', function(src, team)
    local g = Games.ByPlayer(src)
    if not g or g.mode ~= 'pvp' or g.phase ~= LG.Phase.LOBBY then return false, 'Aucun lobby.' end
    local p = g.players[src]
    if team ~= 'A' and team ~= 'B' then return false, 'Équipe invalide.' end
    if p.ready then return false, 'Retire ton « prêt » avant de changer d\'équipe.' end
    if p.team == team then return true end
    if teamCount(g, team) >= g.size then return false, 'Cette équipe est complète.' end
    p.team = team
    Lobby.Push(g)
    return true
end)

RPC.Register('pvp:weapon', function(src, weaponId)
    local g = Games.ByPlayer(src)
    if not g or g.mode ~= 'pvp' or g.phase ~= LG.Phase.LOBBY then return false, 'Aucun lobby.' end
    local w = LGU.Weapon(tostring(weaponId or ''))
    if not w or w.zombieOnly or w.disabled or w.cat ~= g.category then return false, 'Arme indisponible.' end
    g.players[src].weapon = w.id
    Lobby.Push(g)
    return true
end)

-- Prêt : la mise est débitée à ce moment-là (et rendue si le joueur se remet « pas prêt » ou quitte)
RPC.Register('pvp:ready', function(src, ready)
    local g = Games.ByPlayer(src)
    if not g or g.mode ~= 'pvp' or g.phase ~= LG.Phase.LOBBY then return false, 'Aucun lobby.' end
    return Security.Locked(src, 'pvp:ready', function()
        local p = g.players[src]
        if not p then return false, 'Aucun lobby.' end
        if ready and not p.ready then
            if g.stake > 0 and not p.paid then
                local id = Bridge.Identity(src)
                local row = Economy.Hold(src, id, g.uid, p.team, g.stake)
                if not row then return false, ('Fonds insuffisants : il faut %d $ (%s).'):format(g.stake, Config.Account == 'cash' and 'liquide' or 'banque') end
                p.paid = row
            end
            p.ready = true
        elseif not ready and p.ready then
            if p.paid then Economy.RefundRow(p.paid, 'pas prêt') p.paid = nil end
            p.ready = false
        end
        g.lastActivity = os.time()
        Lobby.Push(g)
        return true
    end)
end)

RPC.Register('pvp:invite', function(src, target)
    local g = Games.ByPlayer(src)
    if not g or g.phase ~= LG.Phase.LOBBY then return false, 'Aucun lobby.' end
    return Lobby.Invite(g, src, target)
end)

RPC.Register('lobby:nearby', function(src) return true, Lobby.Nearby(src, 40.0) end)

RPC.Register('pvp:kick', function(src, target)
    local g = Games.ByPlayer(src)
    if not g or g.mode ~= 'pvp' or g.phase ~= LG.Phase.LOBBY then return false, 'Aucun lobby.' end
    if g.host ~= src then return false, 'Seul l\'hôte peut expulser.' end
    target = tonumber(target)
    if not target or target == src or not g.players[target] then return false, 'Joueur introuvable.' end
    Pvp.LeaveLobby(g, target, 'expulsé par l\'hôte')
    Games.Notify(target, 'Tu as été expulsé du lobby.', 'error')
    return true
end)

RPC.Register('lobby:leave', function(src)
    local g = Games.ByPlayer(src)
    if not g then return true end
    Games.ForceLeave(src, 'a quitté')
    return true
end)

-- ---------------------------------------------------------------- départ / annulation
function Pvp.LeaveLobby(g, src, reason)
    local p = g.players[src]
    if not p then return end
    if p.paid then Economy.RefundRow(p.paid, reason or 'départ du lobby') end
    Lobby.Remove(g, src)
    TriggerClientEvent('elyzea_lasergame:lobbyClosed', src, g.uid, reason)
    if Lobby.Count(g) == 0 then return Pvp.Cancel(g, 'lobby vide') end
    Lobby.Push(g)
end

function Pvp.Cancel(g, reason)
    if g.closed then return end
    Economy.RefundMatch(g.uid, reason)
    for _, s in ipairs(Games.PlayerList(g)) do TriggerClientEvent('elyzea_lasergame:lobbyClosed', s, g.uid, reason) end
    if g.phase ~= LG.Phase.LOBBY then
        for _, s in ipairs(Games.Members(g)) do Games.ExitInstance(g, s, true) end
        MySQL.update('UPDATE `lg_matches` SET `status` = \'cancelled\', `ended_at` = NOW() WHERE `uid` = ?', { g.uid })
    end
    Logs.Add('pvp', ('partie %s annulée : %s'):format(g.uid, reason or '?'))
    Games.Close(g)
    Lobby.PushList()
end

-- ---------------------------------------------------------------- lancement
RPC.Register('pvp:start', function(src)
    local g = Games.ByPlayer(src)
    if not g or g.mode ~= 'pvp' or g.phase ~= LG.Phase.LOBBY then return false, 'Aucun lobby.' end
    if g.host ~= src then return false, 'Seul l\'hôte peut lancer la partie.' end
    if not Config.PvP.enabled then return false, 'Le mode PVP est désactivé.' end
    local a, b = teamCount(g, 'A'), teamCount(g, 'B')
    if a < Config.PvP.minPlayersPerTeam or b < Config.PvP.minPlayersPerTeam then return false, 'Il faut au moins un joueur dans chaque équipe.' end
    if Config.PvP.requireEqualTeams and a ~= b then return false, ('Équipes déséquilibrées (%d contre %d).'):format(a, b) end
    if Config.PvP.requireFullTeams and (a < g.size or b < g.size) then return false, 'Les deux équipes doivent être complètes.' end
    for _, p in pairs(g.players) do
        if not p.ready then return false, ('%s n\'est pas prêt.'):format(p.name) end
        if g.stake > 0 and not p.paid then return false, ('%s n\'a pas payé sa mise.'):format(p.name) end
    end
    local slot = Games.AllocSlot()
    if not slot then return false, 'Toutes les arènes sont occupées, réessaie dans un instant.' end
    g.slot, g.bucket = slot, Games.Bucket(slot)
    g.phase = LG.Phase.LOADING
    Lobby.PushList()
    CreateThread(function()
        local ok, err = pcall(Pvp.Run, g)
        if not ok then
            Logs.Error(('partie %s : %s'):format(g.uid, tostring(err)))
            Pvp.Cancel(g, 'erreur interne')
        end
    end)
    return true
end)

local function aliveCount(g, team)
    local n, shield = 0, 0
    for _, p in pairs(g.players) do
        if p.team == team and p.alive then n = n + 1 shield = shield + (p.shield or 0) end
    end
    return n, shield
end

local function connectedCount(g, team)
    local n = 0
    for _, p in pairs(g.players) do if p.team == team then n = n + 1 end end
    return n
end

local function sendState(g)
    local players = {}
    for _, s in ipairs(Games.PlayerList(g)) do
        local p = g.players[s]
        players[#players + 1] = { id = s, name = p.name, team = p.team, alive = p.alive, shield = p.shield, kills = p.kills, deaths = p.deaths }
    end
    local aA, aB = aliveCount(g, 'A'), aliveCount(g, 'B')
    Games.Send(g, 'pvpState', { score = g.score, round = g.round, rounds = g.rounds, endsAt = g.roundEndsAt, phase = g.phase,
        alive = { A = aA, B = aB }, players = players, serverTime = os.time() })
end
Pvp.SendState = sendState

function Pvp.Run(g)
    local m = Maps.Get(g.map)
    SetRoutingBucketPopulationEnabled(g.bucket, false)
    SetRoutingBucketEntityLockdownMode(g.bucket, 'strict')
    g.startedAt = os.time()
    g.playSeconds = 0
    MySQL.insert.await('INSERT INTO `lg_matches` (`uid`, `mode`, `name`, `map`, `format`, `status`, `pot`, `ranked`) VALUES (?, \'pvp\', ?, ?, ?, \'running\', ?, ?)',
        { g.uid, g.name, g.map, g.format, g.stake * Lobby.Count(g), Pvp.IsRanked(g) and 1 or 0 })
    g.startTeams = { A = connectedCount(g, 'A'), B = connectedCount(g, 'B') }
    g.leavers = {}
    -- entrée dans l'instance : sauvegarde RP avant tout changement
    for _, s in ipairs(Games.PlayerList(g)) do
        local p = g.players[s]
        local ok = Games.EnterInstance(g, s, 'player')
        if not ok then
            Logs.Add('pvp', 'entrée impossible (personnage introuvable) : mise remboursée', nil, s)
            if p.paid then Economy.RefundRow(p.paid, 'entrée impossible') end
            Lobby.Remove(g, s)
        else
            p.alive, p.shield = true, Config.PvP.shield
            TriggerClientEvent('elyzea_lasergame:enterGame', s, {
                uid = g.uid, mode = 'pvp', role = 'player', team = p.team, map = Maps.ClientInfo(m), weapon = p.weapon,
                shield = Config.PvP.shield, rounds = g.rounds, roundTime = g.roundTime, name = g.name, format = g.format,
                teamNames = { A = T.A.name, B = T.B.name }, teamColors = { A = T.A.color, B = T.B.color },
            })
        end
    end
    if connectedCount(g, 'A') == 0 or connectedCount(g, 'B') == 0 then return Pvp.Cancel(g, 'joueurs manquants') end
    Logs.Add('pvp', ('partie %s lancée (%s, %s, %d joueurs, pot %d $)'):format(g.uid, g.format, g.map, Lobby.Count(g), g.stake * Lobby.Count(g)))
    Wait(Config.PvP.timers.loading * 1000)

    while not g.closed do
        -- manche suivante
        g.round = g.round + 1
        local spawnsA = Maps.Spawns(m, 'A', g.size)
        local spawnsB = Maps.Spawns(m, 'B', g.size)
        local ia, ib = 0, 0
        for _, s in ipairs(Games.PlayerList(g)) do
            local p = g.players[s]
            p.alive, p.shield, p.roundKills = true, Config.PvP.shield, 0
            p.ammo, p.reloadUntil, p.exits = {}, {}, 0
            local pos
            if p.team == 'A' then ia = ia + 1 pos = spawnsA[ia] else ib = ib + 1 pos = spawnsB[ib] end
            p.spawn, p.lastValid = pos, pos
            TriggerClientEvent('elyzea_lasergame:pvpSpawn', s, { pos = pos, weapon = p.weapon, shield = p.shield, round = g.round })
        end
        g.phase = LG.Phase.COUNTDOWN
        g.roundEndsAt = nil
        sendState(g)
        Games.Send(g, 'countdown', { seconds = Config.PvP.timers.countdown, round = g.round, rounds = g.rounds })
        Wait(Config.PvP.timers.countdown * 1000)
        if g.closed then return end

        g.phase = LG.Phase.ROUND
        g.roundStartedAt = os.time()
        g.roundEndsAt = os.time() + g.roundTime
        Games.Send(g, 'roundStart', { round = g.round, endsAt = g.roundEndsAt, duration = g.roundTime })
        sendState(g)

        local winner, reason
        local lastZone = 0
        while not g.closed do
            Wait(250)
            local aA, sA = aliveCount(g, 'A')
            local aB, sB = aliveCount(g, 'B')
            if connectedCount(g, 'A') == 0 or connectedCount(g, 'B') == 0 then
                winner = connectedCount(g, 'A') > 0 and 'A' or (connectedCount(g, 'B') > 0 and 'B' or nil)
                reason = 'abandon'
                break
            end
            if aA == 0 and aB == 0 then winner, reason = nil, 'double' break end
            if aA == 0 then winner, reason = 'B', 'elimination' break end
            if aB == 0 then winner, reason = 'A', 'elimination' break end
            if os.time() >= g.roundEndsAt then
                winner = LGU.TimeoutWinner(Config.PvP.timeoutRule, { A = aA, B = aB }, { A = sA, B = sB })
                reason = 'temps'
                break
            end
            -- contrôle de la zone toutes les 0,5 s (le client a aussi un mur invisible)
            local now = GetGameTimer()
            if now - lastZone >= 500 then
                lastZone = now
                for _, s in ipairs(Games.PlayerList(g)) do
                    local p = g.players[s]
                    local ped = GetPlayerPed(s)
                    if p.alive and ped and ped ~= 0 then
                        local c = GetEntityCoords(ped)
                        local w = { x = c.x, y = c.y, z = c.z }
                        if Maps.InBounds(m, w) then p.lastValid = w
                        else
                            p.exits = (p.exits or 0) + 1
                            TriggerClientEvent('elyzea_lasergame:pushBack', s, p.lastValid or p.spawn)
                            if p.exits == 6 then Security.Suspicious(s, 'sorties répétées de la zone', { map = g.map }) end
                        end
                    end
                end
            end
        end
        if g.closed then return end
        g.playSeconds = g.playSeconds + (os.time() - g.roundStartedAt)
        if winner then g.score[winner] = g.score[winner] + 1 end
        for _, p in pairs(g.players) do if winner and p.team == winner then p.roundsWon = (p.roundsWon or 0) + 1 end end
        g.phase = LG.Phase.ROUND_END
        g.roundEndsAt = nil
        Games.Send(g, 'roundEnd', { round = g.round, winner = winner, reason = reason, score = g.score })
        sendState(g)
        local decided, matchWinner = LGU.MatchDecided(g.score.A, g.score.B, g.rounds, g.round)
        if reason == 'abandon' then decided, matchWinner = true, winner end
        if g.round >= (g.rounds + 6) then decided = true end   -- sécurité contre une partie sans fin
        Wait(Config.PvP.timers.roundEnd * 1000)
        if decided then return Pvp.Finish(g, matchWinner, reason == 'abandon' and 'abandon' or 'score') end
    end
end

-- ---------------------------------------------------------------- fin de partie
function Pvp.Finish(g, winner, why)
    if g.closed or g.finished then return end
    g.finished = true
    g.phase = LG.Phase.ENDED
    local list = {}
    local winnersCids = {}
    for _, s in ipairs(Games.PlayerList(g)) do
        local p = g.players[s]
        local result = winner == nil and 'draw' or (p.team == winner and 'win' or 'loss')
        list[#list + 1] = { src = s, cid = p.cid, name = p.name, team = p.team, result = result, kills = p.kills, deaths = p.deaths }
        if result == 'win' then winnersCids[#winnersCids + 1] = p.cid end
    end
    for _, l in ipairs(g.leavers) do
        list[#list + 1] = { cid = l.cid, name = l.name, team = l.team, result = 'left', kills = l.kills, deaths = l.deaths }
        if winner and l.team == winner and not Config.LeaverForfeitsShare then winnersCids[#winnersCids + 1] = l.cid end
    end
    -- argent : pot partagé entre les gagnants, ou tout est remboursé (égalité)
    local payouts, pot = {}, 0
    if g.stake > 0 then
        if winner then payouts, pot = Economy.PayWinners(g.uid, winnersCids)
        else Economy.RefundMatch(g.uid, 'égalité') end
    end
    for _, l in ipairs(list) do l.payout = payouts[l.cid] or 0 end
    -- classement
    local ranked = Pvp.IsRanked(g) and g.playSeconds >= Config.PvP.minRankedDuration and g.startTeams.A > 0 and g.startTeams.B > 0
    local ranking = {}
    local ok, err = pcall(function() ranking = Ranking.ApplyPvP(g, list, ranked) end)
    if not ok then Logs.Error('classement : ' .. tostring(err)) end
    -- MVP : plus d'éliminations, puis moins de morts
    local mvp
    for _, l in ipairs(list) do
        if l.result ~= 'left' and (not mvp or l.kills > mvp.kills or (l.kills == mvp.kills and l.deaths < mvp.deaths)) then mvp = l end
    end
    MySQL.update('UPDATE `lg_matches` SET `status` = \'finished\', `score_a` = ?, `score_b` = ?, `winner` = ?, `round` = ?, `pot` = ?, `ranked` = ?, `data` = ?, `ended_at` = NOW() WHERE `uid` = ?',
        { g.score.A, g.score.B, winner, g.round, pot, ranked and 1 or 0, json.encode({ players = list, why = why }), g.uid })
    Logs.Add('pvp', ('partie %s terminée : %s (%d-%d), pot %d $'):format(g.uid, winner and ('victoire ' .. T[winner].name) or 'égalité', g.score.A, g.score.B, pot))
    -- écran de fin (chacun reçoit ses propres chiffres)
    local summary = {}
    for _, l in ipairs(list) do summary[#summary + 1] = { name = l.name, team = l.team, kills = l.kills, deaths = l.deaths, result = l.result } end
    for _, s in ipairs(Games.Members(g)) do
        local p = g.players[s]
        local mine
        if p then
            for _, l in ipairs(list) do if l.cid == p.cid then mine = l break end end
        end
        local r = mine and ranking[mine.cid] or nil
        TriggerClientEvent('elyzea_lasergame:matchEnd', s, {
            winner = winner, score = g.score, why = why, ranked = ranked, players = summary, mvp = mvp and mvp.name or nil,
            teamNames = { A = T.A.name, B = T.B.name },
            me = mine and { result = mine.result, team = mine.team, kills = mine.kills, deaths = mine.deaths, payout = mine.payout,
                delta = r and r.delta or 0, points = r and r.points or nil, rank = r and r.rank or nil, rankLabel = r and r.rankLabel or nil,
                rankUp = r and r.rankUp or false, rankDown = r and r.rankDown or false } or nil,
        })
    end
    Wait(Config.PvP.timers.matchEnd * 1000)
    for _, s in ipairs(Games.Members(g)) do Games.ExitInstance(g, s, false) end
    Games.Close(g)
    Lobby.PushList()
end

-- Arrêt forcé (staff) : tout est remboursé, aucun point
function Pvp.Stop(g, reason)
    if g.phase == LG.Phase.LOBBY then return Pvp.Cancel(g, reason) end
    g.finished = true
    Games.Send(g, 'notify', ('Partie arrêtée par le staff : %s'):format(reason or ''), 'error')
    Pvp.Cancel(g, reason or 'arrêt staff')
end

-- ---------------------------------------------------------------- départs en cours de partie
local function leaveRunning(g, src, reason, dropped)
    local p = g.players[src]
    if not p then return end
    g.leavers[#g.leavers + 1] = { cid = p.cid, name = p.name, team = p.team, kills = p.kills, deaths = p.deaths }
    Logs.Add('pvp', ('%s quitte la partie %s en cours (%s)'):format(p.name, g.uid, reason or '?'), nil, dropped and nil or src)
    -- retour au RP AVANT de retirer le joueur (la sauvegarde est attachée à son entrée)
    if not dropped then Games.ExitInstance(g, src, false) end
    g.players[src] = nil
    for i, s in ipairs(g.order) do if s == src then table.remove(g.order, i) break end end
    Games.Detach(src)
    Games.Send(g, 'killfeed', { victim = p.name, victimTeam = p.team, left = true })
    if g.phase == LG.Phase.ENDED then return end
    sendState(g)
end

Games.Register(LG.Mode.PVP, {
    view = publicView,
    lobbyView = lobbyView,
    cancel = function(g, reason) Pvp.Cancel(g, reason) end,
    leave = function(g, src, reason)
        if g.phase == LG.Phase.LOBBY then return Pvp.LeaveLobby(g, src, reason) end
        leaveRunning(g, src, reason, false)
    end,
    drop = function(g, src, reason)
        if g.phase == LG.Phase.LOBBY then return Pvp.LeaveLobby(g, src, 'déconnexion') end
        leaveRunning(g, src, 'déconnexion', true)
    end,
})

-- ---------------------------------------------------------------- combat PVP
local function eliminate(g, victimSrc, killerSrc, w)
    local v = g.players[victimSrc]
    if not v or not v.alive then return end
    v.alive, v.shield = false, 0
    v.deaths = v.deaths + 1
    local k = killerSrc and g.players[killerSrc]
    if k then k.kills = k.kills + 1 k.roundKills = (k.roundKills or 0) + 1 end
    TriggerClientEvent('elyzea_lasergame:eliminated', victimSrc, { by = k and k.name or nil, byId = killerSrc, weapon = w and w.label })
    Games.Send(g, 'killfeed', { killer = k and k.name, killerTeam = k and k.team, victim = v.name, victimTeam = v.team, weapon = w and w.label,
        killerId = killerSrc, victimId = victimSrc })
    sendState(g)
end
Pvp.Eliminate = eliminate

Combat.Register(LG.Mode.PVP, {
    owns = function(g, p, wid) return p.weapon == wid end,
    canShoot = function(g, p) return g.phase == LG.Phase.ROUND and p.alive end,
    apply = function(g, src, p, w, shot)
        if shot.hit.k ~= 'p' then return end
        local target = tonumber(shot.hit.id)
        local t = target and g.players[target]
        if not t or not t.alive or target == src then return end
        if t.team == p.team and not Config.PvP.friendlyFire then return end
        local ped = GetPlayerPed(target)
        if not ped or ped == 0 then return end
        local c = GetEntityCoords(ped)
        local ok, why = Combat.CheckHit(shot.o, shot.d, shot.hp, { x = c.x, y = c.y, z = c.z }, w.range)
        if not ok then
            p.badHits = (p.badHits or 0) + 1
            if p.badHits % 10 == 0 then Security.Suspicious(src, 'impacts PVP invalides (' .. why .. ')', { n = p.badHits }) end
            return
        end
        local dmg = Config.PvP.oneHitElimination and t.shield or w.damage
        t.shield = math.max(0, t.shield - dmg)
        p.hits = (p.hits or 0) + 1
        TriggerClientEvent('elyzea_lasergame:hitConfirm', src, { target = target, dmg = dmg, kill = t.shield <= 0 })
        TriggerClientEvent('elyzea_lasergame:damaged', target, { shield = t.shield, from = src, dir = shot.o })
        if t.shield <= 0 then eliminate(g, target, src, w) end
    end,
})

-- ---------------------------------------------------------------- spectateurs
RPC.Register('spectate:join', function(src, uid)
    if not Config.Spectator.enabled then return false, 'Le mode spectateur est désactivé.' end
    local g = Games.list[tostring(uid or '')]
    if not g or g.phase == LG.Phase.LOBBY or g.phase == LG.Phase.ENDED or g.closed then return false, 'Partie introuvable ou pas encore lancée.' end
    local can, id = Games.CanJoin(src)
    if not can then return false, id end
    for _, l in ipairs(g.leavers or {}) do if l.cid == id.cid then return false, 'Tu as quitté cette partie : impossible de la regarder.' end end
    local n = 0
    for _ in pairs(g.spectators) do n = n + 1 end
    if n >= Config.Spectator.maxPerMatch then return false, 'Trop de spectateurs.' end
    Games.Attach(g, src, 'spectator')
    g.spectators[src] = { cid = id.cid, name = id.name }
    local ok, snap = Games.EnterInstance(g, src, 'spectator')
    if not ok then g.spectators[src] = nil Games.Detach(src) return false, 'Entrée impossible.' end
    g.spectators[src].snap = snap
    local m = Maps.Get(g.map)
    TriggerClientEvent('elyzea_lasergame:enterGame', src, { uid = g.uid, mode = g.mode, role = 'spectator', map = Maps.ClientInfo(m), name = g.name,
        teamNames = { A = T.A.name, B = T.B.name }, teamColors = { A = T.A.color, B = T.B.color }, rounds = g.rounds })
    if g.mode == 'pvp' then sendState(g) elseif Zombie and Zombie.SendState then Zombie.SendState(g) end
    Logs.Add(g.mode, ('regarde la partie %s'):format(g.uid), nil, src)
    return true
end)
