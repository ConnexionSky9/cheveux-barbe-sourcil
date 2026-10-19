-- =========================================================
--  PVP ARENA - partie : machine à états, instance (routing bucket), manches, armes,
--  éliminations validées par le serveur, zone, fin de partie, gains, retour au RP.
--
--  LOBBY → PREPARATION → WEAPON_SELECTION → COUNTDOWN → IN_ROUND → ROUND_END
--        → (WEAPON_SELECTION …) → MATCH_END → CLEANUP → CLOSED
--  Chaque transition passe par go() (vérifiée par Rules.CanGo) ; chaque minuterie porte un jeton
--  (L.tick) : une minuterie périmée (partie annulée, manche déjà finie) ne fait plus rien.
-- =========================================================
local T = Arena.T
local Lobbies, byPlayer = Arena.lobbies, Arena.byPlayer
local TM = Config.Timers

local function go(L, state)
    if not Rules.CanGo(L.state, state) then
        Arena.Log(('Transition refusée %s → %s (%s)'):format(L.state, state, L.uid))
        return false
    end
    L.state = state
    L.tick = (L.tick or 0) + 1
    Arena.Touch(L)
    return true
end

-- Minuterie liée à l'état courant : ignorée si la partie a changé d'état entre-temps
local function after(L, sec, fn)
    local tok = L.tick
    SetTimeout(math.floor(sec * 1000), function()
        if Lobbies[L.uid] == L and L.tick == tok then
            local ok, err = pcall(fn)
            if not ok then
                print(('^1[pvp_arena] %s : %s^0'):format(L.uid, tostring(err)))
                Arena.Cancel(L, 'erreur interne')
            end
        end
    end)
end

local function members(L) local o = {} for s in pairs(L.members) do o[#o + 1] = s end return o end
local function sendAll(L, ev, ...) for s in pairs(L.members) do TriggerClientEvent(ev, s, ...) end end

local function teamAlive(L, team)
    local n = 0
    for s, m in pairs(L.members) do if m.team == team and L.match.alive[s] then n = n + 1 end end
    return n
end

-- État de partie envoyé au HUD (pas de données sensibles : positions et vie des adversaires absentes)
local function hud(L)
    local M = L.match
    local roster = {}
    for s, st in pairs(M.stats) do
        roster[#roster + 1] = { id = s, name = st.name, team = st.team, alive = M.alive[s] == true, kills = st.kills, deaths = st.deaths, left = st.left }
    end
    return { uid = L.uid, state = L.state, round = M.round, score = M.score, wins = L.settings.wins,
        aliveA = teamAlive(L, 'A'), aliveB = teamAlive(L, 'B'), roster = roster, history = M.history,
        roundEndsAt = M.roundEnds and (M.roundEnds - os.time()) or nil, teams = Config.Teams }
end
local function pushHud(L) sendAll(L, 'pvp_arena:hud', hud(L)) end

-- ---------------------------------------------------------------- lancement
function Arena.Launch(src)
    local L = Lobbies[byPlayer[src] or '']
    if not L then return false, T('not_member') end
    if L.host ~= src then return false, T('not_host') end
    if L.state ~= 'LOBBY' then return false, T('cant_now') end
    local S = L.settings
    local a, b = Arena.CountTeam(L, 'A'), Arena.CountTeam(L, 'B')
    if a == 0 or a ~= b or (Config.RequireFullTeams and a ~= S.teamSize) then
        return false, T('launch_teams', Config.RequireFullTeams and T('launch_full', S.teamSize, S.teamSize) or '')
    end
    for _, m in pairs(L.members) do
        if S.stake > 0 and not m.stakePaid then return false, T('launch_stake', S.stake) end
        if not m.ready then return false, T('launch_ready') end
    end
    local arena = Arena.arenas[S.arena]
    if not Arena.ArenaValid(arena) then return false, T('launch_arena') end
    -- chaque joueur doit être connecté, dans le monde RP (instance 0) et debout
    for s, m in pairs(L.members) do
        local ped = GetPlayerPed(s)
        local st = Player(s).state
        if not GetPlayerName(s) or ped == 0 or GetPlayerRoutingBucket(s) ~= 0 or GetEntityHealth(ped) <= 0
            or st.emsDown or st.isDead or st.dead or st.pvpArena then
            return false, T('launch_player', m.name)
        end
    end
    -- paris fermés, partie réservée
    if not go(L, 'PREPARATION') then return false, T('cant_now') end
    L.bucket = Config.BucketBase + L.slot
    L.arena = arena
    L.match = { round = 0, score = { A = 0, B = 0 }, history = {}, alive = {}, stats = {}, picks = {}, lastHit = {}, grace = {}, exits = {}, snaps = {} }
    SetRoutingBucketPopulationEnabled(L.bucket, false)
    SetRoutingBucketEntityLockdownMode(L.bucket, 'strict')
    local stakePot, betPot = L.stakePot or 0, 0
    for _, bt in pairs(L.bets) do betPot = betPot + (bt.pending and 0 or bt.amount) end
    MySQL.insert('INSERT INTO `pvp_matches` (`uid`, `arena`, `mode`, `wins`, `status`, `stake_pot`, `bet_pot`) VALUES (?, ?, ?, ?, \'running\', ?, ?)',
        { L.uid, arena.id, S.mode, S.wins, stakePot, betPot })
    -- sauvegarde de l'état RP de chaque joueur (mémoire + base, pour les déconnexions / redémarrages)
    for s, m in pairs(L.members) do
        local ped = GetPlayerPed(s)
        local c = GetEntityCoords(ped)
        local snap = { bucket = GetPlayerRoutingBucket(s), x = c.x, y = c.y, z = c.z, h = GetEntityHeading(ped),
            health = GetEntityHealth(ped), armor = GetPedArmour(ped) }
        L.match.snaps[s] = snap
        Arena.SaveRestore(m.cid, L.uid, snap)
        L.match.stats[s] = { name = m.name, cid = m.cid, team = m.team, kills = 0, deaths = 0, rounds = 0 }
        Player(s).state:set('pvpArena', L.uid, true)
        SetPlayerRoutingBucket(s, L.bucket)
        TriggerClientEvent('pvp_arena:enter', s, { uid = L.uid, team = m.team, teams = Config.Teams, arena = { id = arena.id, label = arena.label,
            zone = arena.zone, time = arena.time, weather = arena.weather }, ff = S.friendlyFire, health = Config.Health, armor = Config.Armor })
    end
    Arena.Log(('Partie %s lancée : %s, %s, première équipe à %d, mise %d $, arène %s.'):format(L.uid, S.mode, #members(L) .. ' joueurs', S.wins, S.stake, arena.id))
    after(L, 1.0, function() Arena.WeaponSelection(L) end)
    return true
end

-- ---------------------------------------------------------------- manches
function Arena.WeaponSelection(L)
    if not go(L, 'WEAPON_SELECTION') then return end
    local M = L.match
    M.round = M.round + 1
    M.picks, M.exits = {}, {}
    M.roundEnds = nil
    for s in pairs(L.members) do M.alive[s] = true end
    local allowed = {}
    for name in pairs(L.settings.weapons) do if Arena.weapons[name] then allowed[#allowed + 1] = name end end
    table.sort(allowed)
    sendAll(L, 'pvp_arena:weaponSelect', { round = M.round, seconds = TM.weaponSelect, allowed = allowed })
    pushHud(L)
    after(L, TM.weaponSelect, function() Arena.Deploy(L) end)
end

-- Choix d'arme (validé : partie, phase, arme autorisée par l'hôte et connue de la config)
Ely.callback.register('pvp_arena:pick', function(src, weapon)
    local L = Lobbies[byPlayer[src] or '']
    if not L or not L.match or L.state ~= 'WEAPON_SELECTION' or not L.members[src] then return false, T('cant_now') end
    local key = tostring(weapon or ''):upper()
    if not Arena.weapons[key] or not L.settings.weapons[key] then
        Arena.Log(('Arme refusée pour %s : %s (partie %s)'):format(GetPlayerName(src) or src, key, L.uid))
        return false, T('weapon_bad')
    end
    L.match.picks[src] = key
    -- tout le monde a choisi : on n'attend pas la fin du décompte
    local all = true
    for s in pairs(L.members) do if not L.match.picks[s] then all = false break end end
    if all then
        local tok = L.tick
        SetTimeout(600, function() if Lobbies[L.uid] == L and L.tick == tok and L.state == 'WEAPON_SELECTION' then Arena.Deploy(L) end end)
    end
    return true, key
end)

local function defaultWeapon(L)
    local d = Config.DefaultWeapon:upper()
    if L.settings.weapons[d] and Arena.weapons[d] then return d end
    local list = {}
    for name in pairs(L.settings.weapons) do if Arena.weapons[name] then list[#list + 1] = name end end
    if #list == 0 then return d end
    table.sort(list)
    return list[1]
end

-- Point d'apparition n° i d'une équipe (décalé si plus de joueurs que de points)
local function spawnFor(arena, team, i)
    local list = arena.spawns[team]
    local n = #list
    local base = list[((i - 1) % n) + 1]
    local ring = math.floor((i - 1) / n)
    if ring == 0 then return base end
    local ang = (ring * 72) * math.pi / 180
    return { x = base.x + math.cos(ang) * 1.3 * ring, y = base.y + math.sin(ang) * 1.3 * ring, z = base.z, h = base.h }
end

-- Téléportation aux points d'apparition, arme validée, puis décompte
function Arena.Deploy(L)
    if L.state ~= 'WEAPON_SELECTION' then return end
    if not go(L, 'COUNTDOWN') then return end
    local M = L.match
    local idx = { A = 0, B = 0 }
    for _, s in ipairs(L.order) do
        local m = L.members[s]
        if m then
            idx[m.team] = idx[m.team] + 1
            local sp = spawnFor(L.arena, m.team, idx[m.team])
            local weapon = M.picks[s] or defaultWeapon(L)
            M.picks[s] = weapon
            M.stats[s].weapon = weapon
            M.grace[s] = os.time() + TM.teleportGrace + TM.loading + TM.countdown
            local ped = GetPlayerPed(s)
            if ped ~= 0 then SetEntityCoords(ped, sp.x, sp.y, sp.z, false, false, false, false) end
            TriggerClientEvent('pvp_arena:spawn', s, { pos = sp, weapon = weapon, ammo = Config.Ammo, team = m.team,
                health = Config.Health, armor = Config.Armor, round = M.round })
        end
    end
    pushHud(L)
    after(L, TM.loading, function()
        sendAll(L, 'pvp_arena:countdown', { seconds = TM.countdown, round = M.round })
        after(L, TM.countdown, function() Arena.StartRound(L) end)
    end)
end

function Arena.StartRound(L)
    if not go(L, 'IN_ROUND') then return end
    local M = L.match
    M.roundEnds = os.time() + L.settings.roundTime
    M.roundStarted = GetGameTimer()
    sendAll(L, 'pvp_arena:roundStart', { round = M.round, seconds = L.settings.roundTime })
    pushHud(L)
    after(L, L.settings.roundTime, function() Arena.RoundTimeout(L) end)
end

-- Fin de manche (winner = 'A' | 'B' | nil pour nulle)
function Arena.EndRound(L, winner, reason)
    if L.state ~= 'IN_ROUND' then return end
    if not go(L, 'ROUND_END') then return end
    local M = L.match
    if winner then M.score[winner] = M.score[winner] + 1 end
    M.history[#M.history + 1] = { round = M.round, winner = winner, reason = reason }
    sendAll(L, 'pvp_arena:roundEnd', { round = M.round, winner = winner, reason = reason, score = M.score })
    pushHud(L)
    if (winner and M.score[winner] >= L.settings.wins) then
        after(L, TM.roundEnd, function() Arena.EndMatch(L, winner, 'score') end)
    elseif M.round >= Config.MaxRounds then
        local w = M.score.A > M.score.B and 'A' or (M.score.B > M.score.A and 'B' or nil)
        after(L, TM.roundEnd, function()
            if w then Arena.EndMatch(L, w, 'limite de manches') else Arena.Cancel(L, 'égalité après le nombre maximum de manches') end
        end)
    else
        after(L, TM.roundEnd, function() Arena.WeaponSelection(L) end)
    end
end

function Arena.RoundTimeout(L)
    if L.state ~= 'IN_ROUND' then return end
    local hp = { A = 0, B = 0 }
    for s, m in pairs(L.members) do
        if L.match.alive[s] then
            local ped = GetPlayerPed(s)
            if ped ~= 0 then hp[m.team] = hp[m.team] + math.max(0, GetEntityHealth(ped) - 100) + GetPedArmour(ped) end
        end
    end
    local w = Rules.TimeoutWinner(Config.TimeoutRule, teamAlive(L, 'A'), teamAlive(L, 'B'), hp.A, hp.B)
    Arena.EndRound(L, w, 'temps écoulé')
end

-- Une équipe n'a plus personne en vie ? (jugé après un court délai : morts presque simultanées)
local function checkRound(L)
    if L.state ~= 'IN_ROUND' or L.match.judging then return end
    if teamAlive(L, 'A') > 0 and teamAlive(L, 'B') > 0 then return end
    L.match.judging = true
    local tok = L.tick
    SetTimeout(math.floor(TM.deathSettle * 1000), function()
        if Lobbies[L.uid] ~= L or L.tick ~= tok then return end
        L.match.judging = false
        local a, b = teamAlive(L, 'A'), teamAlive(L, 'B')
        if a > 0 and b > 0 then return end
        Arena.EndRound(L, (a > 0 and 'A') or (b > 0 and 'B') or nil, (a == 0 and b == 0) and 'élimination mutuelle' or 'élimination')
    end)
end
Arena.CheckRound = checkRound

-- ---------------------------------------------------------------- éliminations
-- Élimination enregistrée par le serveur. Le tueur vient d'abord des dégâts validés par le serveur
-- (weaponDamageEvent), sinon de l'indication du client si elle est cohérente (adversaire vivant).
function Arena.Eliminate(L, victim, claimedKiller, cause)
    local M = L.match
    if L.state ~= 'IN_ROUND' or not M.alive[victim] then return false end
    M.alive[victim] = nil
    local vs = M.stats[victim]
    vs.deaths = vs.deaths + 1
    local killer = nil
    local lh = M.lastHit[victim]
    if lh and GetGameTimer() - lh.t < 10000 then killer = lh.by end
    if not killer and claimedKiller then
        local k = tonumber(claimedKiller)
        if k and L.members[k] and M.alive[k] and L.members[k].team ~= L.members[victim].team then killer = k end
    end
    M.lastHit[victim] = nil
    local friendly = killer and L.members[killer] and L.members[killer].team == L.members[victim].team
    if killer and M.stats[killer] and not friendly then M.stats[killer].kills = M.stats[killer].kills + 1 end
    sendAll(L, 'pvp_arena:killfeed', { victim = vs.name, victimTeam = vs.team, killer = killer and M.stats[killer] and M.stats[killer].name or nil,
        killerTeam = killer and M.stats[killer] and M.stats[killer].team or nil, weapon = killer and M.picks[killer] or nil, cause = cause })
    TriggerClientEvent('pvp_arena:eliminated', victim, { spectate = Config.UI.spectate })
    pushHud(L)
    checkRound(L)
    return true
end

-- La victime signale sa mort (seule la victime peut se déclarer morte : aucun avantage à tricher)
RegisterNetEvent('pvp_arena:died', function(killer)
    local src = source
    local L = Lobbies[byPlayer[src] or '']
    if L and L.match then Arena.Eliminate(L, src, killer, 'mort') end
end)

-- Dégâts d'arme : bloqués hors manche, entre coéquipiers (sauf dégâts alliés), par un joueur éliminé
-- ou avec une arme qui n'est pas celle attribuée par le serveur. Les dégâts valides désignent le tueur.
local function playerOfEntity(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) or not IsPedAPlayer(ent) then return nil end
    return NetworkGetEntityOwner(ent)
end
AddEventHandler('weaponDamageEvent', function(sender, data)
    local src = tonumber(sender)
    local uidA = byPlayer[src]
    local netId = data and (data.hitGlobalId or (data.hitGlobalIds and data.hitGlobalIds[1]))
    local target = netId and playerOfEntity(NetworkGetEntityFromNetworkId(netId))
    local uidB = target and byPlayer[target]
    local LA, LB = uidA and Lobbies[uidA], uidB and Lobbies[uidB]
    local inA = LA and LA.match ~= nil
    local inB = LB and LB.match ~= nil
    if not inA and not inB then return end
    if not inA or not inB or LA ~= LB then return CancelEvent() end   -- jamais entre l'arène et le RP
    local L, M = LA, LA.match
    if L.state ~= 'IN_ROUND' or not M.alive[src] or not M.alive[target] then return CancelEvent() end
    if src ~= target and L.members[src].team == L.members[target].team and not L.settings.friendlyFire then return CancelEvent() end
    local w = M.picks[src]
    if not w or Rules.Hash(data.weaponType) ~= Rules.Hash(w) then
        if Rules.Hash(data.weaponType) ~= Rules.Hash('WEAPON_UNARMED') then
            Arena.Log(('Dégâts refusés : %s a tiré avec une arme non attribuée (%s) dans la partie %s.'):format(GetPlayerName(src) or src, tostring(data.weaponType), L.uid))
        end
        return CancelEvent()
    end
    if src ~= target then M.lastHit[target] = { by = src, t = GetGameTimer() } end
end)

-- ---------------------------------------------------------------- zone et santé (contrôle serveur)
CreateThread(function()
    while true do
        Wait(Config.Zone.checkInterval)
        local now = os.time()
        for _, L in pairs(Lobbies) do
            local M = L.match
            if M and (L.state == 'IN_ROUND' or L.state == 'COUNTDOWN') then
                for s, m in pairs(L.members) do
                    local ped = GetPlayerPed(s)
                    if ped ~= 0 and M.alive[s] then
                        -- mort non signalée par le client : le serveur la constate lui-même
                        if L.state == 'IN_ROUND' and GetEntityHealth(ped) <= 0 then
                            Arena.Eliminate(L, s, nil, 'mort')
                        elseif (M.grace[s] or 0) < now then
                            local c = GetEntityCoords(ped)
                            if not Rules.InZone(L.arena.zone, c.x, c.y, c.z) then
                                M.exits[s] = (M.exits[s] or 0) + 1
                                M.grace[s] = now + Config.Timers.teleportGrace
                                if L.state == 'IN_ROUND' and (Config.Zone.maxExitsPerRound or 0) > 0 and M.exits[s] > Config.Zone.maxExitsPerRound then
                                    Arena.Notify(s, T('zone_eliminated'), 'error')
                                    Arena.Eliminate(L, s, nil, 'zone')
                                else
                                    local list = (#L.arena.safe > 0) and L.arena.safe or L.arena.spawns[m.team]
                                    local sp = list[math.random(1, #list)]
                                    SetEntityCoords(ped, sp.x, sp.y, sp.z, false, false, false, false)
                                    TriggerClientEvent('pvp_arena:zoneBack', s, sp)
                                    Arena.Notify(s, T('zone_exit'), 'error')
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------- fin de partie et gains
local function settleMoney(L, winner)
    local rows = MySQL.query.await('SELECT `id`, `citizenid`, `name`, `kind`, `team`, `amount` FROM `pvp_ledger` WHERE `match_uid` = ? AND `status` = \'held\'', { L.uid }) or {}
    local stakes, bets = {}, {}
    local leftCids = {}
    for _, st in pairs(L.match.stats) do if st.left then leftCids[st.cid] = true end end
    for _, r in ipairs(rows) do
        local row = { id = r.id, cid = r.citizenid, name = r.name, team = r.team, amount = tonumber(r.amount) or 0, left = leftCids[r.citizenid] }
        if r.kind == 'stake' then stakes[#stakes + 1] = row else bets[#bets + 1] = row end
    end
    local result = { stakes = {}, bets = {}, stakePot = 0, betPot = 0, stakeFee = 0, betFee = 0, betRefunded = false }
    local sOut, sFee, sPot = Rules.SplitStakes(stakes, winner, Config.HouseFeePct.stake, Config.LeaverForfeitsShare)
    result.stakePot, result.stakeFee = sPot, sFee
    for _, r in ipairs(stakes) do
        local g = sOut[r.id] or 0
        Arena.Settle(r.id, r.cid, g > 0 and 'paid' or 'lost', g, ('victoire arène %s'):format(L.uid))
        result.stakes[#result.stakes + 1] = { name = r.name, team = r.team, stake = r.amount, won = g, cid = r.cid }
    end
    local bOut, bFee, refundAll, bPot = Rules.SplitBets(bets, winner, Config.HouseFeePct.bet)
    result.betPot, result.betFee, result.betRefunded = bPot or 0, bFee, refundAll
    for _, r in ipairs(bets) do
        local g = bOut[r.id] or 0
        Arena.Settle(r.id, r.cid, refundAll and 'refunded' or (g > 0 and 'paid' or 'lost'), g,
            refundAll and 'pari remboursé (personne sur le gagnant)' or ('pari gagnant arène %s'):format(L.uid))
        result.bets[#result.bets + 1] = { name = r.name, team = r.team, bet = r.amount, won = g, cid = r.cid }
    end
    return result
end

local function notifyBettors(L, result)
    -- les parieurs connectés (spectateurs compris) voient leur résultat
    for _, b in ipairs(result.bets) do
        for _, sid in ipairs(GetPlayers()) do
            local s = tonumber(sid)
            local p = Arena.Player(s)
            if p and p.cid == b.cid and not L.members[s] then
                TriggerClientEvent('pvp_arena:betResult', s, { match = L.name, team = b.team, bet = b.bet, won = b.won, refunded = result.betRefunded,
                    winner = L.match.winner })
            end
        end
    end
end

function Arena.EndMatch(L, winner, reason)
    if L.state == 'MATCH_END' or L.state == 'CLEANUP' or L.state == 'CLOSED' then return end
    if not go(L, 'MATCH_END') then return end
    local M = L.match
    M.winner = winner
    CreateThread(function()
        local result = settleMoney(L, winner)
        local players = {}
        for s, st in pairs(M.stats) do
            local won = 0
            for _, r in ipairs(result.stakes) do if r.cid == st.cid then won = r.won end end
            players[#players + 1] = { name = st.name, team = st.team, kills = st.kills, deaths = st.deaths, left = st.left, won = won, id = s }
        end
        local summary = { uid = L.uid, winner = winner, reason = reason, score = M.score, rounds = M.round, players = players, teams = Config.Teams,
            stake = L.settings.stake, stakePot = result.stakePot, stakeFee = result.stakeFee, betPot = result.betPot, betFee = result.betFee,
            betRefunded = result.betRefunded, bets = { A = 0, B = 0 }, seconds = TM.matchEnd }
        for _, b in ipairs(result.bets) do summary.bets[b.team] = summary.bets[b.team] + b.bet end
        for s in pairs(L.members) do
            local mine = { stake = 0, won = 0, bet = 0, betWon = 0 }
            for _, r in ipairs(result.stakes) do if r.cid == L.members[s].cid then mine.stake, mine.won = r.stake, r.won end end
            for _, r in ipairs(result.bets) do if r.cid == L.members[s].cid then mine.bet, mine.betWon = r.bet, r.won end end
            summary.mine = mine
            TriggerClientEvent('pvp_arena:matchEnd', s, summary)
            if mine.won + mine.betWon > 0 then Arena.Notify(s, T('payout', mine.won + mine.betWon, L.name), 'success') end
        end
        summary.mine = nil
        notifyBettors(L, result)
        MySQL.update('UPDATE `pvp_matches` SET `score_a` = ?, `score_b` = ?, `winner` = ?, `status` = \'finished\', `data` = ? WHERE `uid` = ?',
            { M.score.A, M.score.B, winner, json.encode(summary), L.uid })
        Arena.Log(('Partie %s terminée : %s gagne %d-%d (%s). Pot mises %d $, paris %d $.'):format(L.uid, Config.Teams[winner].name, M.score.A, M.score.B, reason, result.stakePot, result.betPot))
    end)
    after(L, TM.matchEnd, function() Arena.Cleanup(L) end)
end

-- Annulation (admin, erreur, égalité impossible à départager, abandon avec la règle « cancel ») : tout est remboursé
function Arena.Cancel(L, why)
    if not Lobbies[L.uid] then return end
    if L.state == 'LOBBY' then return Arena.CloseLobby(L, why) end
    if L.state == 'CLEANUP' or L.state == 'CLOSED' then return end
    L.state = 'MATCH_END'   -- forcé : une annulation peut arriver à n'importe quelle étape
    L.tick = (L.tick or 0) + 1
    CreateThread(function()
        Arena.RefundMatch(L.uid, why)
        MySQL.update('UPDATE `pvp_matches` SET `status` = \'cancelled\' WHERE `uid` = ?', { L.uid })
    end)
    for s in pairs(L.members) do
        Arena.Notify(s, T('match_cancelled'), 'info')
        TriggerClientEvent('pvp_arena:matchEnd', s, { uid = L.uid, cancelled = true, reason = why, score = L.match and L.match.score or { A = 0, B = 0 },
            players = {}, teams = Config.Teams, seconds = 3 })
    end
    Arena.Log(('Partie %s annulée : %s'):format(L.uid, tostring(why)))
    after(L, 3, function() Arena.Cleanup(L) end)
end

-- Retour au RP de tous les joueurs encore connectés, libération de l'instance
function Arena.Cleanup(L)
    if L.state ~= 'MATCH_END' then return end
    L.state = 'CLEANUP'
    L.tick = (L.tick or 0) + 1
    for s, m in pairs(L.members) do
        local snap = L.match and L.match.snaps[s]
        if snap and GetPlayerName(s) then
            Arena.ApplyRestore(s, snap, false)
            Arena.DropRestore(m.cid)
        end
        byPlayer[s] = nil
    end
    L.state = 'CLOSED'
    Lobbies[L.uid] = nil
    Arena.Touch(nil)
end

-- ---------------------------------------------------------------- départs pendant la partie
-- dropped = déconnexion (l'état RP sera rendu à la reconnexion grâce à pvp_restore)
function Arena.LeaveMatch(src, why, dropped)
    local L = Lobbies[byPlayer[src] or '']
    if not L or not L.match then byPlayer[src] = nil return false, T('not_member') end
    local m = L.members[src]
    local M = L.match
    if not m then byPlayer[src] = nil return false end
    if M.stats[src] then M.stats[src].left = true end
    local wasAlive = M.alive[src]
    M.alive[src] = nil
    L.members[src] = nil
    for i, s in ipairs(L.order) do if s == src then table.remove(L.order, i) break end end
    byPlayer[src] = nil
    if not dropped and M.snaps[src] then
        Arena.ApplyRestore(src, M.snaps[src], false)
        Arena.DropRestore(m.cid)
    end
    if L.host == src and L.order[1] then L.host = L.order[1] L.hostName = L.members[L.host].name end
    for s in pairs(L.members) do Arena.Notify(s, T('left', m.name), 'info') end
    Arena.Log(('%s a quitté la partie %s (%s).'):format(m.name, L.uid, why or '-'))
    if L.state == 'MATCH_END' or L.state == 'CLEANUP' then return true end
    -- une équipe vide : forfait ou annulation selon la règle
    local a, b = Arena.CountTeam(L, 'A'), Arena.CountTeam(L, 'B')
    if a == 0 or b == 0 then
        if a == 0 and b == 0 then
            Arena.Cancel(L, 'tous les joueurs sont partis')
        elseif Config.AbandonPolicy == 'cancel' then
            Arena.Cancel(L, 'abandon d\'une équipe')
        else
            Arena.EndMatch(L, a > 0 and 'A' or 'B', 'forfait')
        end
        return true
    end
    if wasAlive then pushHud(L) checkRound(L) end
    return true
end

Ely.callback.register('pvp_arena:quit', function(src)
    return Arena.Locked(src, 'quit', function()
        local L = Lobbies[byPlayer[src] or '']
        if not L then return false, T('not_member') end
        if L.state == 'LOBBY' then return Arena.LeaveLobby(src, 'quitté') end
        return Arena.LeaveMatch(src, 'abandon')
    end)
end)

-- Arrêt de la ressource : chacun retrouve immédiatement son monde RP ; les mises seront remboursées au redémarrage
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, L in pairs(Lobbies) do
        if L.match then
            for s, m in pairs(L.members) do
                local snap = L.match.snaps[s]
                if snap and GetPlayerName(s) then
                    Player(s).state:set('pvpArena', false, true)
                    SetPlayerRoutingBucket(s, tonumber(snap.bucket) or 0)
                    local ped = GetPlayerPed(s)
                    if ped ~= 0 then SetEntityCoords(ped, snap.x, snap.y, snap.z, false, false, false, false) end
                    MySQL.query('DELETE FROM `pvp_restore` WHERE `citizenid` = ?', { m.cid })   -- déjà rendu
                end
            end
        end
    end
end)
