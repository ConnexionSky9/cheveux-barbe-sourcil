-- =========================================================
--  PVP ARENA - lobbies : création, entrée / sortie, équipes, réglages de l'hôte,
--  mises de participation, paris, transfert d'hôte, diffusion de l'état.
-- =========================================================
local T = Arena.T
local Lobbies, byPlayer = Arena.lobbies, Arena.byPlayer
local viewers = {}       -- [src] = true : écran d'accueil ouvert (reçoit la liste des parties)
local watching = {}      -- [src] = uid : regarde le détail d'une partie (paris de spectateur)
Arena.viewers, Arena.watching = viewers, watching

local MODES = {}
for _, m in ipairs(Config.Modes) do MODES[m.id] = m end
local function isIn(list, v) for _, x in ipairs(list) do if x == v then return true end end return false end

local function countTeam(L, t)
    local n = 0
    for _, m in pairs(L.members) do if m.team == t then n = n + 1 end end
    return n
end
Arena.CountTeam = countTeam

local function memberCount(L) local n = 0 for _ in pairs(L.members) do n = n + 1 end return n end
Arena.MemberCount = memberCount

local function slotFree()
    local used = {}
    for _, L in pairs(Lobbies) do used[L.slot] = true end
    for i = 1, Config.MaxLobbies do if not used[i] then return i end end
end

local function defaultWeapons()
    local w = {}
    for name in pairs(Arena.weapons) do w[name] = true end
    return w
end

-- ---------------------------------------------------------------- vues envoyées aux clients
local function summary(L)
    return { uid = L.uid, name = L.name, host = L.hostName, state = L.state, players = memberCount(L), max = L.settings.teamSize * 2,
        teamSize = L.settings.teamSize, mode = L.settings.mode, wins = L.settings.wins, stake = L.settings.stake,
        arena = (Arena.arenas[L.settings.arena] or {}).label or L.settings.arena,
        a = countTeam(L, 'A'), b = countTeam(L, 'B'), betPot = L.betPot or 0 }
end

function Arena.LobbyView(L, src)
    local members = {}
    for _, s in ipairs(L.order) do
        local m = L.members[s]
        if m then members[#members + 1] = { id = s, name = m.name, team = m.team, ready = m.ready, paid = m.stakePaid, host = s == L.host } end
    end
    local betA, betB, myBet = 0, 0, nil
    local p = src and Arena.Player(src)
    for cid, b in pairs(L.bets) do
        if b.pending then -- écriture en cours : pas encore compté
        elseif b.team == 'A' then betA = betA + b.amount else betB = betB + b.amount end
        if p and p.cid == cid and not b.pending then myBet = { team = b.team, amount = b.amount } end
    end
    local weapons = {}
    for name in pairs(L.settings.weapons) do weapons[#weapons + 1] = name end
    return {
        uid = L.uid, name = L.name, state = L.state, host = L.host, hostName = L.hostName, me = src,
        settings = { mode = L.settings.mode, teamSize = L.settings.teamSize, wins = L.settings.wins, stake = L.settings.stake,
            arena = L.settings.arena, roundTime = L.settings.roundTime, friendlyFire = L.settings.friendlyFire, weapons = weapons },
        members = members, a = countTeam(L, 'A'), b = countTeam(L, 'B'),
        bets = { A = betA, B = betB, pot = betA + betB, mine = myBet, open = L.state == 'LOBBY' },
        stakePot = L.stakePot or 0,
        member = src and L.members[src] ~= nil or false,
    }
end

-- Diffusion groupée (au plus toutes les 150 ms) : liste aux écrans d'accueil, détail aux membres et spectateurs
local dirtyList, dirtyLobby = false, {}
function Arena.Touch(L)
    dirtyList = true
    if L then dirtyLobby[L.uid] = true end
end
CreateThread(function()
    while true do
        Wait(150)
        if dirtyList then
            dirtyList = false
            local list = {}
            for _, L in pairs(Lobbies) do list[#list + 1] = summary(L) end
            table.sort(list, function(a, b) return a.uid < b.uid end)
            for s in pairs(viewers) do TriggerClientEvent('pvp_arena:list', s, list) end
        end
        for uid in pairs(dirtyLobby) do
            dirtyLobby[uid] = nil
            local L = Lobbies[uid]
            if L then
                for s in pairs(L.members) do TriggerClientEvent('pvp_arena:lobby', s, Arena.LobbyView(L, s)) end
                for s, w in pairs(watching) do if w == uid and not L.members[s] then TriggerClientEvent('pvp_arena:lobby', s, Arena.LobbyView(L, s)) end end
            end
        end
    end
end)

-- ---------------------------------------------------------------- création / entrée / sortie
local function mustLobby(src, uid)
    local L = Lobbies[uid]
    if not L then return nil, T('lobby_not_found') end
    return L
end

function Arena.CreateLobby(src, d)
    if not Arena.ready then return false, T('error') end
    if byPlayer[src] then return false, T('already_in_lobby') end
    local p = Arena.Player(src)
    if not p then return false, T('not_loaded') end
    local slot = slotFree()
    if not slot then return false, T('too_many_lobbies') end
    local mode = MODES[d and d.mode] or Config.Modes[1]
    local firstArena = nil
    for _, id in ipairs(Arena.arenaOrder) do if Arena.ArenaValid(Arena.arenas[id]) then firstArena = id break end end
    if not firstArena then return false, T('launch_arena') end
    local uid = Arena.NewUid()
    local L = {
        uid = uid, slot = slot, name = ('Partie de %s'):format(p.name), host = src, hostName = p.name, state = 'LOBBY',
        created = os.time(), activity = os.time(),
        settings = { mode = mode.id, teamSize = mode.teamSize, wins = Config.DefaultWins, stake = 0, arena = firstArena,
            weapons = defaultWeapons(), roundTime = Config.DefaultRoundTime, friendlyFire = false },
        members = {}, order = {}, bets = {}, betPot = 0, stakePot = 0,
    }
    Lobbies[uid] = L
    local ok, err = Arena.JoinLobby(src, uid)
    if not ok then Lobbies[uid] = nil return false, err end
    Arena.Log(('Partie %s créée par %s (%s).'):format(uid, p.name, p.cid))
    return true, uid
end

function Arena.JoinLobby(src, uid, team)
    if byPlayer[src] then return false, T('already_in_lobby') end
    local L, err = mustLobby(src, uid)
    if not L then return false, err end
    if L.state ~= 'LOBBY' then return false, T('lobby_started') end
    local p = Arena.Player(src)
    if not p then return false, T('not_loaded') end
    local size = L.settings.teamSize
    if memberCount(L) >= size * 2 then return false, T('lobby_full') end
    if team ~= 'A' and team ~= 'B' then team = countTeam(L, 'A') <= countTeam(L, 'B') and 'A' or 'B' end
    if countTeam(L, team) >= size then team = team == 'A' and 'B' or 'A' end
    if countTeam(L, team) >= size then return false, T('lobby_full') end
    -- un participant ne peut pas garder un pari sur l'équipe adverse
    local b = L.bets[p.cid]
    if b and (Config.ParticipantBets == 'none' or (Config.ParticipantBets == 'own' and b.team ~= team)) then
        return false, Config.ParticipantBets == 'none' and T('bet_none') or T('bet_own_team')
    end
    L.members[src] = { src = src, cid = p.cid, name = p.name, team = team, ready = false, stakePaid = false }
    L.order[#L.order + 1] = src
    byPlayer[src] = uid
    watching[src] = nil
    L.activity = os.time()
    for s in pairs(L.members) do if s ~= src then Arena.Notify(s, T('joined', p.name), 'info') end end
    Arena.Touch(L)
    return true, uid
end

local function removeOrder(L, src)
    for i, s in ipairs(L.order) do if s == src then table.remove(L.order, i) break end end
end

-- Fermeture d'un lobby non lancé : mises et paris remboursés
function Arena.CloseLobby(L, why)
    if not Lobbies[L.uid] then return end
    L.state = 'CLOSED'
    Lobbies[L.uid] = nil
    for s in pairs(L.members) do
        byPlayer[s] = nil
        TriggerClientEvent('pvp_arena:closed', s, L.uid)
        Arena.Notify(s, T('lobby_closed', L.name), 'info')
    end
    for s, w in pairs(watching) do if w == L.uid then watching[s] = nil TriggerClientEvent('pvp_arena:closed', s, L.uid) end end
    CreateThread(function() Arena.RefundMatch(L.uid, why or 'partie fermée') end)
    Arena.Touch(nil)
    Arena.Log(('Partie %s fermée (%s).'):format(L.uid, why or '-'))
end

-- Sortie d'un lobby (avant le lancement) : la mise est rendue, l'hôte est transmis
function Arena.LeaveLobby(src, why)
    local uid = byPlayer[src]
    local L = uid and Lobbies[uid]
    if not L then byPlayer[src] = nil return false, T('not_member') end
    if L.state ~= 'LOBBY' then return Arena.LeaveMatch(src, why) end
    local m = L.members[src]
    L.members[src] = nil
    removeOrder(L, src)
    byPlayer[src] = nil
    if m and m.stakePaid and m.ledgerId then
        CreateThread(function()
            if Arena.Settle(m.ledgerId, m.cid, 'refunded', L.settings.stake, 'mise rendue (sortie du lobby)') then
                L.stakePot = math.max(0, (L.stakePot or 0) - L.settings.stake)
                if GetPlayerName(src) then Arena.Notify(src, T('stake_refund', L.settings.stake), 'info') end
                Arena.Touch(L)
            end
        end)
    end
    if GetPlayerName(src) then TriggerClientEvent('pvp_arena:closed', src, L.uid) end
    if memberCount(L) == 0 then Arena.CloseLobby(L, why or 'plus aucun joueur') return true end
    if L.host == src then
        L.host = L.order[1]
        L.hostName = L.members[L.host].name
        for s in pairs(L.members) do Arena.Notify(s, T('host_left', L.hostName), 'info') end
    else
        for s in pairs(L.members) do Arena.Notify(s, T('left', m and m.name or '?'), 'info') end
    end
    -- la composition a changé : tout le monde doit reconfirmer
    for _, mm in pairs(L.members) do mm.ready = false end
    Arena.Touch(L)
    return true
end

-- ---------------------------------------------------------------- équipes, prêt, réglages
function Arena.SetTeam(src, team)
    local L = Lobbies[byPlayer[src] or '']
    if not L then return false, T('not_member') end
    if L.state ~= 'LOBBY' then return false, T('cant_now') end
    if team ~= 'A' and team ~= 'B' then return false, T('bad_value') end
    local m = L.members[src]
    if m.team == team then return true end
    if countTeam(L, team) >= L.settings.teamSize then return false, T('team_full') end
    local b = L.bets[m.cid]
    if b and Config.ParticipantBets == 'own' and b.team ~= team then return false, T('bet_own_team') end
    m.team, m.ready = team, false
    Arena.Touch(L)
    return true
end

function Arena.SetReady(src, ready)
    local L = Lobbies[byPlayer[src] or '']
    if not L then return false, T('not_member') end
    if L.state ~= 'LOBBY' then return false, T('cant_now') end
    local m = L.members[src]
    if ready and L.settings.stake > 0 and not m.stakePaid then return false, T('launch_stake', L.settings.stake) end
    m.ready = ready == true
    Arena.Touch(L)
    return true
end

-- Équilibrage automatique par l'hôte (ordre d'arrivée, alterné)
function Arena.Shuffle(src)
    local L = Lobbies[byPlayer[src] or '']
    if not L then return false, T('not_member') end
    if L.host ~= src then return false, T('not_host') end
    if L.state ~= 'LOBBY' then return false, T('cant_now') end
    for i, s in ipairs(L.order) do
        local m = L.members[s]
        local want = (i % 2 == 1) and 'A' or 'B'
        local b = L.bets[m.cid]
        if not (b and Config.ParticipantBets == 'own' and b.team ~= want) then m.team = want end
        m.ready = false
    end
    Arena.Touch(L)
    return true
end

function Arena.Configure(src, d)
    local L = Lobbies[byPlayer[src] or '']
    if not L then return false, T('not_member') end
    if L.host ~= src then return false, T('not_host') end
    if L.state ~= 'LOBBY' then return false, T('cant_now') end
    if type(d) ~= 'table' then return false, T('bad_value') end
    local S = L.settings
    local changedStake = false
    if d.mode ~= nil then
        local m = MODES[d.mode]
        if not m then return false, T('bad_value') end
        if memberCount(L) > m.teamSize * 2 then return false, T('lobby_full') end
        if countTeam(L, 'A') > m.teamSize or countTeam(L, 'B') > m.teamSize then return false, T('team_full') end
        S.mode, S.teamSize = m.id, m.teamSize
    end
    if d.wins ~= nil then
        local w = math.floor(tonumber(d.wins) or 0)
        if not isIn(Config.WinsOptions, w) then return false, T('bad_value') end
        S.wins = w
    end
    if d.roundTime ~= nil then
        local r = math.floor(tonumber(d.roundTime) or 0)
        if not isIn(Config.RoundTimes, r) then return false, T('bad_value') end
        S.roundTime = r
    end
    if d.arena ~= nil then
        local a = Arena.arenas[tostring(d.arena)]
        if not a or not Arena.ArenaValid(a) then return false, T('launch_arena') end
        S.arena = a.id
    end
    if d.friendlyFire ~= nil then S.friendlyFire = Config.AllowFriendlyFireOption and d.friendlyFire == true or false end
    if d.weapons ~= nil then
        if type(d.weapons) ~= 'table' then return false, T('bad_value') end
        local set, n = {}, 0
        for _, name in ipairs(d.weapons) do
            local key = tostring(name):upper()
            if Arena.weapons[key] and not set[key] then set[key] = true n = n + 1 end
        end
        if n == 0 then return false, T('weapon_bad') end
        S.weapons = set
    end
    if d.stake ~= nil then
        local st = math.floor(tonumber(d.stake) or -1)
        if st < Config.Stake.min or st > Config.Stake.max then return false, T('bad_value') end
        if st ~= S.stake then
            -- changer la mise rembourse celles déjà payées (chacun repaie le nouveau montant)
            if (L.stakePot or 0) > 0 then
                for _, m in pairs(L.members) do
                    if m.stakePaid and m.ledgerId then
                        local id, cid, amt = m.ledgerId, m.cid, S.stake
                        CreateThread(function() Arena.Settle(id, cid, 'refunded', amt, 'mise modifiée par l\'hôte') end)
                    end
                end
            end
            for _, m in pairs(L.members) do m.stakePaid, m.ledgerId = false, nil end
            L.stakePot = 0
            S.stake = st
            changedStake = true
        end
    end
    for _, m in pairs(L.members) do m.ready = false end
    L.activity = os.time()
    Arena.Touch(L)
    return true, changedStake
end

-- ---------------------------------------------------------------- mise de participation
function Arena.PayStake(src)
    local L = Lobbies[byPlayer[src] or '']
    if not L then return false, T('not_member') end
    if L.state ~= 'LOBBY' then return false, T('cant_now') end
    local m = L.members[src]
    local amount = L.settings.stake
    if amount <= 0 then return true end
    if m.stakePaid then return false, T('stake_already') end
    local p = Arena.Player(src)
    if not p or p.cid ~= m.cid then return false, T('not_loaded') end
    local id = Arena.Hold(src, p, L.uid, 'stake', m.team, amount)
    if not id then return false, T('no_funds', amount) end
    -- la partie a pu changer pendant l'écriture : si la mise n'est plus la même ou le joueur parti, on rend
    if not Lobbies[L.uid] or L.members[src] ~= m or L.settings.stake ~= amount or L.state ~= 'LOBBY' then
        Arena.Settle(id, p.cid, 'refunded', amount, 'mise annulée')
        return false, T('cant_now')
    end
    m.stakePaid, m.ledgerId = true, id
    L.stakePot = (L.stakePot or 0) + amount
    Arena.Notify(src, T('stake_paid', amount), 'success')
    Arena.Touch(L)
    return true
end

-- ---------------------------------------------------------------- paris (joueurs et spectateurs)
function Arena.PlaceBet(src, uid, team, amount)
    if not Config.Bet.enabled then return false, T('bet_closed') end
    local L = Lobbies[uid or '']
    if not L then return false, T('lobby_not_found') end
    if L.state ~= 'LOBBY' then return false, T('bet_closed') end
    if team ~= 'A' and team ~= 'B' then return false, T('bad_value') end
    amount = math.floor(tonumber(amount) or 0)
    if amount < Config.Bet.min or amount > Config.Bet.max then return false, T('bet_range', Config.Bet.min, Config.Bet.max) end
    local p = Arena.Player(src)
    if not p then return false, T('not_loaded') end
    if L.bets[p.cid] then return false, T('bet_already') end
    local m = L.members[src]
    if m then
        if Config.ParticipantBets == 'none' then return false, T('bet_none') end
        if Config.ParticipantBets == 'own' and team ~= m.team then return false, T('bet_own_team') end
    end
    L.bets[p.cid] = { pending = true, team = team, amount = amount, cid = p.cid, name = p.name }   -- réservé avant l'écriture
    local id = Arena.Hold(src, p, L.uid, 'bet', team, amount)
    if not id then L.bets[p.cid] = nil return false, T('no_funds', amount) end
    if not Lobbies[L.uid] or L.state ~= 'LOBBY' then
        L.bets[p.cid] = nil
        Arena.Settle(id, p.cid, 'refunded', amount, 'paris fermés')
        return false, T('bet_closed')
    end
    L.bets[p.cid] = { team = team, amount = amount, cid = p.cid, name = p.name, ledgerId = id, src = src }
    L.betPot = (L.betPot or 0) + amount
    Arena.Notify(src, T('bet_placed', amount, Config.Teams[team].name), 'success')
    Arena.Touch(L)
    return true
end

function Arena.CancelBet(src, uid)
    local L = Lobbies[uid or '']
    if not L then return false, T('lobby_not_found') end
    if L.state ~= 'LOBBY' then return false, T('bet_closed') end
    local p = Arena.Player(src)
    local b = p and L.bets[p.cid]
    if not b or b.pending then return false, T('bad_value') end
    L.bets[p.cid] = nil
    L.betPot = math.max(0, (L.betPot or 0) - b.amount)
    if Arena.Settle(b.ledgerId, p.cid, 'refunded', b.amount, 'pari annulé') then Arena.Notify(src, T('bet_cancelled', b.amount), 'info') end
    Arena.Touch(L)
    return true
end

-- ---------------------------------------------------------------- appels du client
local function cb(name, fn)
    Ely.callback.register('pvp_arena:' .. name, function(src, ...)
        return Arena.Locked(src, name, fn, src, ...)
    end)
end

cb('open', function(src)
    viewers[src] = true
    local list = {}
    for _, L in pairs(Lobbies) do list[#list + 1] = summary(L) end
    table.sort(list, function(a, b) return a.uid < b.uid end)
    local uid = byPlayer[src]
    return true, {
        list = list, mine = uid and Lobbies[uid] and Arena.LobbyView(Lobbies[uid], src) or nil,
        config = { modes = Config.Modes, wins = Config.WinsOptions, roundTimes = Config.RoundTimes, stake = Config.Stake, bet = Config.Bet,
            teams = Config.Teams, arenas = Arena.PublicArenas(), weapons = Arena.PublicWeapons(), ff = Config.AllowFriendlyFireOption,
            participantBets = Config.ParticipantBets, account = Config.Account, fee = Config.HouseFeePct, leaverForfeits = Config.LeaverForfeitsShare,
            abandon = Config.AbandonPolicy, ui = Config.UI },
    }
end)
cb('close', function(src) viewers[src] = nil watching[src] = nil return true end)
cb('create', function(src, d) return Arena.CreateLobby(src, d) end)
cb('join', function(src, uid, team) return Arena.JoinLobby(src, tostring(uid or ''), team) end)
cb('leave', function(src) return Arena.LeaveLobby(src, 'quitté') end)
cb('team', function(src, team) return Arena.SetTeam(src, team) end)
cb('ready', function(src, r) return Arena.SetReady(src, r) end)
cb('shuffle', function(src) return Arena.Shuffle(src) end)
cb('configure', function(src, d) return Arena.Configure(src, d) end)
cb('stake', function(src) return Arena.PayStake(src) end)
cb('bet', function(src, uid, team, amount) return Arena.PlaceBet(src, tostring(uid or ''), team, amount) end)
cb('unbet', function(src, uid) return Arena.CancelBet(src, tostring(uid or '')) end)
cb('watch', function(src, uid)
    local L = Lobbies[tostring(uid or '')]
    if not L then return false, T('lobby_not_found') end
    watching[src] = L.uid
    return true, Arena.LobbyView(L, src)
end)
cb('launch', function(src) return Arena.Launch(src) end)

-- Lobbies abandonnés trop longtemps : fermés et remboursés
CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()
        for _, L in pairs(Lobbies) do
            if L.state == 'LOBBY' and now - (L.activity or L.created) > Config.LobbyIdleTimeout then Arena.CloseLobby(L, 'inactivité') end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    viewers[src], watching[src] = nil, nil
    if byPlayer[src] then
        local L = Lobbies[byPlayer[src]]
        if L and L.state == 'LOBBY' then Arena.LeaveLobby(src, 'déconnexion') elseif L then Arena.LeaveMatch(src, 'déconnexion', true) end
    end
end)
