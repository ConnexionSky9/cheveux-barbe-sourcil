-- =========================================================
--  PVP ARENA - simulation du serveur (hors jeu)
--  Le vrai code serveur tourne avec : base de données en mémoire, argent simulé, natives
--  simulées, horloge virtuelle (Wait / SetTimeout / os.time). Lancer : python3 tests/run_pvp_sim.py
-- =========================================================
local ROOT = ...
local PASS, FAIL = 0, 0
local function check(cond, label)
    if cond then PASS = PASS + 1 print('  ok   ' .. label) else FAIL = FAIL + 1 print('  ÉCHEC ' .. label) end
end
local function section(t) print('\n[' .. t .. ']') end

-- ---------------------------------------------------------------- horloge et fils
local NOW = 0
local threads = {}
function GetGameTimer() return NOW end
function CreateThread(fn) threads[#threads + 1] = { co = coroutine.create(fn), wake = NOW } end
function Wait(ms) coroutine.yield(ms or 0) end
function SetTimeout(ms, fn) threads[#threads + 1] = { co = coroutine.create(function() Wait(ms) fn() end), wake = NOW } end
local BASE_TIME = 1700000000
local realTime = os.time
os.time = function(t) if t then return realTime(t) end return BASE_TIME + math.floor(NOW / 1000) end
local function step()
    local list = threads
    threads = {}
    for _, t in ipairs(list) do
        if coroutine.status(t.co) ~= 'dead' then
            if t.wake <= NOW then
                local ok, ms = coroutine.resume(t.co)
                if not ok then print('  ERREUR fil : ' .. tostring(ms)) FAIL = FAIL + 1 end
                if coroutine.status(t.co) ~= 'dead' then t.wake = NOW + (ms or 0) threads[#threads + 1] = t end
            else threads[#threads + 1] = t end
        end
    end
end
local function run(ms)
    local stop = NOW + ms
    while NOW < stop do step() NOW = NOW + 50 end
    step()
end

-- ---------------------------------------------------------------- base de données en mémoire
local DB = { ledger = {}, pending = {}, restore = {}, matches = {} }
local autoid = 0
local function nid() autoid = autoid + 1 return autoid end
local function exec(sql, p)
    p = p or {}
    if sql:find('CREATE TABLE') then return true end
    if sql:find('INSERT INTO `pvp_ledger`') then
        local r = { id = nid(), match_uid = p[1], citizenid = p[2], name = p[3], kind = p[4], team = p[5], amount = p[6], account = p[7], status = 'held', payout = 0 }
        DB.ledger[#DB.ledger + 1] = r return r.id
    end
    if sql:find('UPDATE `pvp_ledger` SET `status`') then
        for _, r in ipairs(DB.ledger) do if r.id == p[3] and r.status == 'held' then r.status, r.payout = p[1], p[2] return 1 end end
        return 0
    end
    if sql:find('SELECT DISTINCT `match_uid` FROM `pvp_ledger`') then
        local seen, out = {}, {}
        for _, r in ipairs(DB.ledger) do if r.status == 'held' and not seen[r.match_uid] then seen[r.match_uid] = true out[#out + 1] = { match_uid = r.match_uid } end end
        return out
    end
    if sql:find('FROM `pvp_ledger` WHERE `match_uid`') then
        local out = {}
        for _, r in ipairs(DB.ledger) do if r.match_uid == p[1] and r.status == 'held' then out[#out + 1] = r end end
        return out
    end
    if sql:find('INSERT INTO `pvp_pending`') then DB.pending[#DB.pending + 1] = { id = nid(), citizenid = p[1], amount = p[2], reason = p[3] } return 1 end
    if sql:find('DELETE FROM `pvp_pending`') then
        for i, r in ipairs(DB.pending) do if r.id == p[1] then table.remove(DB.pending, i) return 1 end end return 0
    end
    if sql:find('FROM `pvp_pending` WHERE') then
        local out = {} for _, r in ipairs(DB.pending) do if r.citizenid == p[1] then out[#out + 1] = r end end return out
    end
    if sql:find('INSERT INTO `pvp_restore`') then DB.restore[p[1]] = { match_uid = p[2], data = p[3] } return 1 end
    if sql:find('DELETE FROM `pvp_restore`') then local had = DB.restore[p[1]] ~= nil DB.restore[p[1]] = nil return had and 1 or 0 end
    if sql:find('FROM `pvp_restore` WHERE') then local r = DB.restore[p[1]] return r and { data = r.data, match_uid = r.match_uid } or nil end
    if sql:find('INSERT INTO `pvp_matches`') then DB.matches[p[1]] = { status = 'running' } return 1 end
    if sql:find('UPDATE `pvp_matches`') then
        local uid = p[#p]
        if DB.matches[uid] then
            if sql:find("'finished'") then DB.matches[uid].status = 'finished' DB.matches[uid].winner = p[3]
            elseif sql:find("'cancelled'") then DB.matches[uid].status = 'cancelled'
            elseif sql:find("'aborted'") then DB.matches[uid].status = 'aborted' end
        end
        return 1
    end
    if sql:find('SELECT') then return {} end
    return 0
end
local function method()
    return setmetatable({ await = function(sql, p) return exec(sql, p) end }, { __call = function(_, sql, p, cb) local r = exec(sql, p) if cb then cb(r) end end })
end
MySQL = { query = method(), single = method(), scalar = method(), insert = method(), update = method(),
    ready = setmetatable({ await = function() return true end }, { __call = function(_, cb) cb() end }) }

-- ---------------------------------------------------------------- natives et joueurs simulés
function vector3(x, y, z)
    return setmetatable({ x = x, y = y, z = z }, { __sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end,
        __len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end })
end
function vector4(x, y, z, w) local v = vector3(x, y, z) v.w = w return v end
function vector2(x, y) return { x = x, y = y } end
function GetHashKey(s)
    s = tostring(s):lower()
    local h = 0
    for i = 1, #s do h = (h * 31 + s:byte(i)) % 4294967296 end
    if h >= 2147483648 then h = h - 4294967296 end
    return h
end
joaat = GetHashKey

local P = {}   -- [src] = { cid, name, bank, cash, online, pos, health, armor, bucket, state }
local function addPlayer(src, cid, bank)
    P[src] = { cid = cid, name = 'Joueur' .. src, bank = bank or 0, cash = 0, online = true, pos = vector3(500.0, 500.0, 30.0), heading = 90.0,
        health = 200, armor = 20, bucket = 0, state = {} }
end
function GetPlayerName(src) local p = P[src] return p and p.online and p.name or nil end
function GetPlayerPed(src) return P[src] and P[src].online and src or 0 end
function GetEntityCoords(ped) return P[ped] and P[ped].pos or vector3(0, 0, 0) end
function GetEntityHeading(ped) return P[ped] and P[ped].heading or 0.0 end
function GetEntityHealth(ped) return P[ped] and P[ped].health or 0 end
function GetPedArmour(ped) return P[ped] and P[ped].armor or 0 end
function SetEntityCoords(ped, x, y, z) if P[ped] then P[ped].pos = vector3(x, y, z) end end
function GetPlayers() local o = {} for s, p in pairs(P) do if p.online then o[#o + 1] = tostring(s) end end table.sort(o) return o end
function GetPlayerRoutingBucket(src) return P[src] and P[src].bucket or 0 end
function SetPlayerRoutingBucket(src, b) if P[src] then P[src].bucket = b end end
function SetRoutingBucketPopulationEnabled() end
function SetRoutingBucketEntityLockdownMode() end
function GetCurrentResourceName() return 'pvp_arena' end
local FILES = {}
function LoadResourceFile(_, f) return FILES[f] end
function SaveResourceFile(_, f, data) FILES[f] = data return true end
function Player(src)
    return { state = setmetatable({ set = function(self, k, v) if P[src] then P[src].state[k] = v end end },
        { __index = function(_, k) if k == 'set' then return nil end return P[src] and P[src].state[k] end }) }
end
-- entités : le ped d'un joueur a pour id réseau 1000 + src
function NetworkGetEntityFromNetworkId(n) return n - 1000 end
function DoesEntityExist(e) return P[e] ~= nil end
function IsPedAPlayer(e) return P[e] ~= nil end
function NetworkGetEntityOwner(e) return e end
local cancelled = false
function CancelEvent() cancelled = true end
local sent = {}
function TriggerClientEvent(name, target, ...)
    sent[#sent + 1] = { name = name, target = target, args = { ... } }
    -- le client réanime le joueur à chaque apparition et au retour au RP
    if (name == 'pvp_arena:spawn' or name == 'pvp_arena:exit') and P[target] then P[target].health = 200 end
end
local function lastSent(name, target)
    for i = #sent, 1, -1 do local s = sent[i] if s.name == name and (target == nil or s.target == target) then return s.args[1], s end end
end
local function countSent(name, target) local n = 0 for _, s in ipairs(sent) do if s.name == name and (target == nil or s.target == target) then n = n + 1 end end return n end
local handlers = {}
function RegisterNetEvent(name, fn) if fn then handlers[name] = handlers[name] or {} table.insert(handlers[name], fn) end end
function AddEventHandler(name, fn) handlers[name] = handlers[name] or {} table.insert(handlers[name], fn) end
function TriggerEvent(name, ...) for _, fn in ipairs(handlers[name] or {}) do fn(...) end end
local function fire(name, src, ...) source = src for _, fn in ipairs(handlers[name] or {}) do fn(...) end end
local COMMANDS = {}
function RegisterCommand(name, fn) COMMANDS[name] = fn end
json = { encode = function(t) return pyjson_encode(t) end, decode = function(s) return pyjson_decode(s) end }

local EXP = {}
EXP.elyzea_core = {
    GetPlayerData = function(_, src) local p = P[src] return p and p.online and { citizenid = p.cid, charinfo = { firstname = p.name, lastname = '' } } or nil end,
    GetMoney = function(_, src, kind) return P[src][kind] or 0 end,
    AddMoney = function(_, src, kind, n) if not P[src] or not P[src].online then return false end P[src][kind] = P[src][kind] + n return true end,
    RemoveMoney = function(_, src, kind, n) if P[src][kind] < n then return false end P[src][kind] = P[src][kind] - n return true end,
}
local ADMINS = { [99] = true }
EXP.admin_menu = { HasPermission = function(_, src) return ADMINS[src] == true end }
local exported = {}
exports = setmetatable({}, { __index = function(_, k) return EXP[k] end, __call = function(_, name, fn) exported[name] = fn end })

local CB = {}
Ely = { callback = { register = function(name, fn) CB[name] = fn end } }
local function call(name, src, ...) NOW = NOW + 130 return CB['pvp_arena:' .. name](src, ...) end   -- un clic humain prend du temps

-- ---------------------------------------------------------------- chargement du vrai code
local function loadFile(f)
    local fh = io.open(ROOT .. '/' .. f, 'r')
    local src = fh:read('a') fh:close()
    local fn, err = load_chunk(src, '@' .. f)
    if not fn then error(err) end
    fn()
end
local FILES_LIST = { 'config.lua', 'locales/fr.lua', 'shared/rules.lua', 'server/core.lua', 'server/lobby.lua', 'server/match.lua', 'server/admin.lua' }
local function boot()
    handlers, CB, COMMANDS, threads = {}, {}, {}, {}
    for _, f in ipairs(FILES_LIST) do loadFile(f) end
    run(300)
end

-- arène de test (dans data/arenas.json simulé)
FILES['data/arenas.json'] = pyjson_encode({ {
    id = 'test', label = 'Test',
    spawns = { A = { { x = -10, y = 0, z = 50, h = 270 }, { x = -10, y = 2, z = 50, h = 270 } }, B = { { x = 10, y = 0, z = 50, h = 90 }, { x = 10, y = 2, z = 50, h = 90 } } },
    zone = { points = { { x = -30, y = -30 }, { x = 30, y = -30 }, { x = 30, y = 30 }, { x = -30, y = 30 } }, minZ = 40, maxZ = 80 },
    safe = {}, center = { x = 0, y = 0, z = 50 },
} })
boot()
Config.Timers.weaponSelect = 5
local T = Config.Timers

local function bal(s) return P[s].bank end
local function ledger(uid, kind) local o = {} for _, r in ipairs(DB.ledger) do if r.match_uid == uid and (not kind or r.kind == kind) then o[#o + 1] = r end end return o end
local function damage(att, vic, weapon)
    cancelled = false
    fire('weaponDamageEvent', nil, att, { hitGlobalId = 1000 + vic, weaponType = GetHashKey(weapon) })
    return not cancelled
end
local function kill(att, vic)
    damage(att, vic, Arena.lobbies[Arena.byPlayer[att]].match.picks[att])
    P[vic].health = 0
    fire('pvp_arena:died', vic, att)
end

-- ================================================================== lobby
section('Lobby : création, entrée, sortie')
for i = 1, 6 do addPlayer(i, 'CID' .. i, 100000) end
addPlayer(7, 'CID7', 50)   -- pauvre
addPlayer(99, 'ADMIN', 0)
for i = 1, 7 do call('open', i) end
local ok, uid = call('create', 1, { mode = '2v2' })
check(ok and Arena.lobbies[uid], 'partie créée par le joueur 1 (2 contre 2)')
local L = Arena.lobbies[uid]
check(L.host == 1 and L.members[1] and L.members[1].team == 'A', 'le créateur est hôte et dans l\'équipe A')
ok = call('create', 1, { mode = '1v1' })
check(not ok, 'un joueur déjà dans une partie ne peut pas en créer une autre')
run(300)
check(countSent('pvp_arena:list', 5) >= 1, 'la liste des parties est envoyée aux écrans d\'accueil ouverts')
ok = call('join', 2, uid, 'A') check(ok and L.members[2].team == 'A', 'joueur 2 rejoint l\'équipe A')
ok = call('join', 3, uid, 'A') check(ok and L.members[3].team == 'B', 'équipe A complète : joueur 3 placé en B')
ok = call('join', 4, uid, 'B') check(ok and L.members[4].team == 'B', 'joueur 4 rejoint B')
ok = call('join', 5, uid) check(not ok, 'partie complète (4/4) : refusé')
ok = call('leave', 4) check(ok and not L.members[4], 'joueur 4 quitte le lobby')
ok = call('join', 4, uid, 'B') check(ok, 'joueur 4 revient')

section('Lobby : réglages réservés à l\'hôte')
ok = call('configure', 2, { wins = 2 }) check(not ok, 'un non-hôte ne peut pas changer les réglages')
ok = call('configure', 1, { wins = 2, stake = 1000, roundTime = 60, weapons = { 'WEAPON_PISTOL', 'WEAPON_SMG', 'WEAPON_INEXISTANTE' } })
check(ok and L.settings.wins == 2 and L.settings.stake == 1000, 'hôte : première équipe à 2, mise 1 000 $')
check(L.settings.weapons.WEAPON_PISTOL and L.settings.weapons.WEAPON_SMG and not L.settings.weapons.WEAPON_INEXISTANTE, 'arme inconnue ignorée, armes autorisées enregistrées')
ok = call('configure', 1, { wins = 4 }) check(not ok, 'nombre de manches hors des options : refusé')
ok = call('configure', 1, { stake = 99999999 }) check(not ok, 'mise au-delà du maximum : refusée')

section('Mises de participation')
ok = call('ready', 1, true) check(not ok, 'prêt refusé tant que la mise n\'est pas payée')
ok = call('stake', 1) check(ok and bal(1) == 99000, 'joueur 1 paie 1 000 $ (débité côté serveur)')
ok = call('stake', 1) check(not ok and bal(1) == 99000, 'double paiement refusé (rien débité deux fois)')
for _, s in ipairs({ 2, 3, 4 }) do call('stake', s) end
check(L.stakePot == 4000, 'pot des mises : 4 000 $')

section('Paris')
ok = call('bet', 7, uid, 'A', 1000) check(not ok and bal(7) == 50, 'solde insuffisant : pari refusé, rien débité')
ok = call('bet', 5, uid, 'A', 3000) check(ok and bal(5) == 97000, 'spectateur 5 parie 3 000 $ sur A')
ok = call('bet', 5, uid, 'B', 1000) check(not ok, 'un seul pari par personne et par partie')
ok = call('bet', 6, uid, 'B', 1000) check(ok, 'spectateur 6 parie 1 000 $ sur B')
ok = call('bet', 3, uid, 'A', 500) check(not ok, 'un participant ne peut pas parier sur l\'équipe adverse')
ok = call('bet', 3, uid, 'B', 500) check(ok and bal(3) == 98500, 'un participant parie sur sa propre équipe')
-- requêtes simultanées : le verrou n'autorise qu'une action à la fois
Arena.busy[6] = 'bet'
ok = call('unbet', 6, uid) check(not ok, 'action concurrente bloquée (double-clic)')
Arena.busy[6] = nil
ok = call('unbet', 6, uid) check(ok and bal(6) == 100000, 'pari annulé avant le lancement : remboursé')
ok = call('bet', 6, uid, 'B', 1000) check(ok, 'nouveau pari de 6 sur B')

section('Lancement')
ok = call('launch', 2) check(not ok, 'lancement par un non-hôte : refusé')
ok, err = call('launch', 1) check(not ok, 'joueurs pas prêts : refusé (' .. tostring(err) .. ')')
for _, s in ipairs({ 1, 2, 3, 4 }) do call('ready', s, true) end
P[4].bucket = 40001
ok, err = call('launch', 1) check(not ok, 'joueur dans une autre instance : refusé (' .. tostring(err) .. ')')
P[4].bucket = 0
ok = call('launch', 1)
check(ok and L.state == 'PREPARATION', 'partie lancée par l\'hôte')
local bucket = L.bucket
check(bucket == Config.BucketBase + L.slot and P[1].bucket == bucket and P[4].bucket == bucket and P[5].bucket == 0, 'joueurs déplacés dans l\'instance dédiée, spectateurs restés au RP')
check(P[1].state.pvpArena == uid and DB.restore.CID1 ~= nil, 'état RP sauvegardé (mémoire + base), joueur marqué « dans l\'arène »')
ok = call('bet', 5, uid, 'B', 500) check(not ok, 'paris fermés après le lancement')
ok = call('join', 6, uid) check(not ok, 'impossible de rejoindre une partie lancée')

section('Manche 1 : armes, décompte, éliminations')
run(1100)
check(L.state == 'WEAPON_SELECTION', 'choix des armes')
ok = call('pick', 1, 'WEAPON_CARBINERIFLE') check(not ok, 'arme non autorisée par l\'hôte : refusée')
ok = call('pick', 1, 'weapon_smg') check(ok, 'arme autorisée acceptée')
call('pick', 2, 'WEAPON_PISTOL') call('pick', 3, 'WEAPON_SMG')
run(T.weaponSelect * 1000 + 100)   -- le joueur 4 ne choisit pas
check(L.state == 'COUNTDOWN' and L.match.picks[4] == 'WEAPON_PISTOL', 'délai écoulé : arme par défaut pour le joueur 4')
local sp = lastSent('pvp_arena:spawn', 3)
check(sp and sp.weapon == 'WEAPON_SMG' and P[3].pos.x == 10, 'joueur 3 placé sur un point de l\'équipe B avec son arme')
check(not damage(1, 3, 'WEAPON_SMG'), 'aucun dégât pendant le décompte')
run((T.loading + T.countdown) * 1000 + 100)
check(L.state == 'IN_ROUND', 'décompte de 3 s puis début de la manche (piloté par le serveur)')
check(not damage(1, 2, 'WEAPON_SMG'), 'pas de dégâts entre coéquipiers')
check(not damage(1, 3, 'WEAPON_CARBINERIFLE'), 'arme non attribuée (triche) : dégâts annulés')
check(damage(1, 3, 'WEAPON_SMG'), 'dégâts valides entre adversaires')
check(not damage(5, 3, 'WEAPON_SMG'), 'un joueur hors de la partie ne peut pas toucher un participant')
kill(1, 3)
check(L.match.alive[3] == nil and L.match.stats[1].kills == 1 and L.match.stats[3].deaths == 1, 'élimination enregistrée, tueur désigné par les dégâts validés')
check(not damage(3, 1, 'WEAPON_SMG'), 'un joueur éliminé ne peut plus infliger de dégâts')
fire('pvp_arena:died', 3, 1)
check(L.match.stats[3].deaths == 1, 'mort signalée deux fois : comptée une seule fois')
kill(2, 4)
run(1000)
check(L.state == 'ROUND_END' and L.match.score.A == 1, 'équipe B éliminée : manche à A (1-0)')

section('Manche 2 : morts simultanées, zone')
run(T.roundEnd * 1000 + 200)
check(L.state == 'WEAPON_SELECTION' and L.match.round == 2, 'passage automatique à la manche 2')
for _, s in ipairs({ 1, 2, 3, 4 }) do call('pick', s, 'WEAPON_PISTOL') end
run(800 + (T.loading + T.countdown) * 1000 + 200)
check(L.state == 'IN_ROUND' and L.match.alive[3], 'manche 2 en cours, tout le monde revit')
-- sortie de zone (après la tolérance de téléportation)
run(T.teleportGrace * 1000 + 600)
P[2].pos = vector3(200, 200, 50)
run(700)
check(P[2].pos.x ~= 200 and L.match.exits[2] == 1, 'sortie de zone détectée par le serveur : joueur replacé dans l\'arène')
for _ = 1, Config.Zone.maxExitsPerRound do
    run(T.teleportGrace * 1000 + 100)
    P[2].pos = vector3(200, 200, 50)
    run(700)
end
check(L.match.alive[2] == nil, 'sorties de zone répétées : éliminé pour la manche')
-- 1 (A) contre 3 et 4 (B) : 1 tue 3, puis 1 et 4 meurent presque en même temps
kill(1, 3)
damage(4, 1, 'WEAPON_PISTOL') damage(1, 4, 'WEAPON_PISTOL')
P[1].health = 0 P[4].health = 0
fire('pvp_arena:died', 1, 4) fire('pvp_arena:died', 4, 1)
run(1000)
check(L.state == 'ROUND_END' and L.match.score.A == 1 and L.match.score.B == 0 and L.match.history[2].winner == nil, 'morts simultanées : manche nulle, score inchangé')

section('Manche 3 : victoire finale et gains')
run(T.roundEnd * 1000 + 200)
run(T.weaponSelect * 1000 + (T.loading + T.countdown) * 1000 + 400)
check(L.state == 'IN_ROUND' and L.match.round == 3, 'manche 3')
kill(1, 3) kill(2, 4)
run(1000)
check(L.match.score.A == 2, 'A atteint 2 manches gagnées')
local before = { bal(1), bal(2), bal(3), bal(4), bal(5), bal(6) }
run(T.roundEnd * 1000 + 600)
check(L.state == 'MATCH_END', 'fin de partie automatique dès que la condition de victoire est atteinte')
-- mises : 4 000 $ partagés entre 1 et 2 (2 000 chacun) ; paris : pot 3 000 + 1 000 + 500 = 4 500, gagnants (A) : 5 seul → 4 500
check(bal(1) - before[1] == 2000 and bal(2) - before[2] == 2000 and bal(3) == before[3] and bal(4) == before[4], 'pot des mises partagé à parts égales entre les gagnants')
check(bal(5) - before[5] == 4500 and bal(6) == before[6], 'paris : le parieur gagnant reçoit tout le pot des paris (prorata)')
local paidRows = 0 for _, r in ipairs(ledger(uid)) do if r.status ~= 'held' then paidRows = paidRows + 1 end end
check(paidRows == #ledger(uid), 'chaque ligne de mise / pari est réglée')
check(not Arena.Settle(ledger(uid)[1].id, 'CID1', 'paid', 2000, 'test') and bal(1) - before[1] == 2000, 'un règlement rejoué ne paie pas deux fois')
local sum = lastSent('pvp_arena:matchEnd', 1)
check(sum and sum.winner == 'A' and sum.score.A == 2 and #sum.players == 4, 'écran de fin : gagnant, score, statistiques des joueurs')
check(countSent('pvp_arena:betResult', 5) == 1, 'le spectateur parieur reçoit son résultat')
run(T.matchEnd * 1000 + 600)
check(not Arena.lobbies[uid] and P[1].bucket == 0 and P[4].bucket == 0, 'nettoyage : partie supprimée, joueurs remis dans leur instance RP')
check(lastSent('pvp_arena:exit', 1) and lastSent('pvp_arena:exit', 1).x == 500.0, 'retour à la position RP sauvegardée')
run(4500)
check(not P[1].state.pvpArena and DB.restore.CID1 == nil, 'marque « arène » retirée, sauvegarde temporaire supprimée')
check(DB.matches[uid].status == 'finished', 'historique de la partie enregistré')

-- ================================================================== déconnexions
section('Hôte qui quitte le lobby : transfert')
local ok2, uid2 = call('create', 1, { mode = '1v1' })
call('join', 2, uid2)
local L2 = Arena.lobbies[uid2]
fire('playerDropped', 1)
P[1].online = false
check(L2.host == 2 and L2.hostName == 'Joueur2', 'hôte déconnecté : le joueur suivant devient hôte')
call('leave', 2)
check(not Arena.lobbies[uid2], 'dernier joueur parti : lobby fermé')
P[1].online = true

section('Déconnexion en partie : forfait, retour au RP à la reconnexion')
local _, uid3 = call('create', 1, { mode = '1v1' })
local L3 = Arena.lobbies[uid3]
call('configure', 1, { stake = 500 })
call('join', 2, uid3)
call('stake', 1) call('stake', 2)
call('ready', 1, true) call('ready', 2, true)
local b1, b2 = bal(1), bal(2)
call('launch', 1)
run(1100 + T.weaponSelect * 1000 + (T.loading + T.countdown) * 1000 + 400)
check(L3.state == 'IN_ROUND', '1 contre 1 en cours')
fire('playerDropped', 2)
P[2].online = false
run(T.matchEnd * 1000 + 2000)
check(bal(1) - b1 == 1000 and not Arena.lobbies[uid3], 'adversaire déconnecté : victoire par forfait, pot versé au restant')
check(DB.restore.CID2 ~= nil, 'état RP du joueur déconnecté gardé en base')
P[2].online = true P[2].bucket = Config.BucketBase + 1 P[2].pos = vector3(10, 0, 50)
TriggerEvent('elyzea:server:playerLogin', 2)
run(5000)
check(P[2].bucket == 0 and DB.restore.CID2 == nil and lastSent('pvp_arena:exit', 2), 'reconnexion : renvoyé dans son monde RP')
check(bal(2) == b2, 'le joueur parti ne récupère pas sa mise (pas de remboursement par déconnexion)')

section('Annulation par le staff : remboursement')
local _, uid4 = call('create', 3, { mode = '1v1' })
local L4 = Arena.lobbies[uid4]
call('configure', 3, { stake = 700 })
call('join', 4, uid4)
call('stake', 3) call('stake', 4)
call('bet', 5, uid4, 'A', 200)
call('ready', 3, true) call('ready', 4, true)
local c3, c4, c5 = bal(3), bal(4), bal(5)
call('launch', 3)
run(1500)
COMMANDS[Config.Commands.cancel](3, { uid4 })
check(Arena.lobbies[uid4] ~= nil, 'commande refusée sans permission')
COMMANDS[Config.Commands.cancel](99, { uid4 })
run(4000)
check(bal(3) - c3 == 700 and bal(4) - c4 == 700 and bal(5) - c5 == 200, 'partie annulée : mises et paris remboursés')
check(not Arena.lobbies[uid4] and P[3].bucket == 0, 'joueurs renvoyés au RP')

section('Plusieurs parties en même temps')
run(4500)   -- la marque « arène » est retirée 4 s après le retour au RP
local _, ua = call('create', 1, { mode = '1v1' }) call('join', 2, ua)
local _, ub = call('create', 3, { mode = '1v1' }) call('join', 4, ub)
for _, s in ipairs({ 1, 2, 3, 4 }) do call('ready', s, true) end
call('launch', 1) call('launch', 3)
local La, Lb = Arena.lobbies[ua], Arena.lobbies[ub]
check(La.bucket ~= Lb.bucket and P[1].bucket == La.bucket and P[3].bucket == Lb.bucket, 'deux parties : deux instances différentes')
run(1100 + T.weaponSelect * 1000 + (T.loading + T.countdown) * 1000 + 400)
check(not damage(1, 3, La.match.picks[1] or 'WEAPON_PISTOL'), 'aucun dégât entre deux parties différentes')

section('Redémarrage de la ressource pendant une partie')
local _, uc = call('create', 5, { mode = '1v1' })
call('configure', 5, { stake = 300 })
call('join', 6, uc)
call('stake', 5) call('stake', 6)
local d5, d6 = bal(5), bal(6)
call('ready', 5, true) call('ready', 6, true)
call('launch', 5)
run(1500)
check(P[5].bucket ~= 0, 'partie en cours avant le redémarrage')
TriggerEvent('onResourceStop', 'pvp_arena')
check(P[5].bucket == 0 and P[6].bucket == 0, 'arrêt de la ressource : joueurs remis immédiatement dans leur instance RP')
boot()   -- nouveau démarrage : même base de données
run(500)
check(bal(5) - d5 == 300 and bal(6) - d6 == 300, 'au redémarrage : mises encore en jeu remboursées')
check(DB.matches[uc].status == 'aborted', 'partie marquée comme interrompue')
check(not P[5].state.pvpArena, 'marque « arène » retirée au redémarrage')

section('Règles de répartition')
local out = Rules.SplitStakes({ { id = 1, team = 'A', amount = 100 }, { id = 2, team = 'A', amount = 100 }, { id = 3, team = 'B', amount = 100 } }, 'A', 0, true)
check(out[1] + out[2] == 300 and math.abs(out[1] - out[2]) <= 1 and out[3] == 0, 'pot impair partagé sans perte d\'argent (150 / 150)')
out = Rules.SplitStakes({ { id = 1, team = 'A', amount = 100, left = true }, { id = 2, team = 'A', amount = 100 }, { id = 3, team = 'B', amount = 100 } }, 'A', 0, true)
check(out[1] == 0 and out[2] == 300, 'gagnant parti en cours de partie : sa part va aux gagnants restants')
local bo, _, refundAll = Rules.SplitBets({ { id = 1, team = 'B', amount = 100 }, { id = 2, team = 'B', amount = 50 } }, 'A', 0)
check(refundAll and bo[1] == 100 and bo[2] == 50, 'personne n\'a parié sur le gagnant : paris remboursés')
bo = Rules.SplitBets({ { id = 1, team = 'A', amount = 100 }, { id = 2, team = 'A', amount = 300 }, { id = 3, team = 'B', amount = 400 } }, 'A', 10)
check(bo[1] + bo[2] == 720 and bo[1] == 180 and bo[3] == 0, 'pari mutuel avec commission 10 % : 180 / 540 (au prorata)')
check(Rules.TimeoutWinner('most_alive', 2, 1) == 'A' and Rules.TimeoutWinner('most_alive', 1, 1, 50, 50) == nil and Rules.TimeoutWinner('draw', 3, 1) == nil, 'règle de fin de temps')
check(not Rules.CanGo('LOBBY', 'IN_ROUND') and Rules.CanGo('IN_ROUND', 'ROUND_END'), 'transitions incohérentes refusées')

print(('\nRésultat : %d réussis, %d échecs'):format(PASS, FAIL))
return FAIL
