-- =========================================================
--  ELYZEA CASINO - simulation du serveur (hors jeu)
--  Le vrai code serveur tourne avec : base de données en mémoire, inventaire et argent simulés,
--  horloge virtuelle (Wait / SetTimeout). Lancer : python3 tests/run_casino_sim.py
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
Citizen = { Await = function(p) return p.value end }
promise = { new = function() return {} end }
local function step()
    local any = false
    local list = threads
    threads = {}
    for _, t in ipairs(list) do
        if coroutine.status(t.co) ~= 'dead' then
            if t.wake <= NOW then
                local ok, ms = coroutine.resume(t.co)
                if not ok then print('  ERREUR fil : ' .. tostring(ms)) FAIL = FAIL + 1 end
                if coroutine.status(t.co) ~= 'dead' then t.wake = NOW + (ms or 0) threads[#threads + 1] = t end
                any = true
            else threads[#threads + 1] = t end
        end
    end
    return any
end
local function run(ms)
    local stop = NOW + ms
    while NOW < stop do
        step()
        NOW = NOW + 50
    end
    step()
end

-- ---------------------------------------------------------------- base de données en mémoire
local DB = { settings = {}, log = {}, tx = {}, pending = {}, daily = {} }
local autoid = 0
local function nid() autoid = autoid + 1 return autoid end
local function exec(sql, p)
    p = p or {}
    if sql:find('CREATE TABLE') then return true end
    if sql:find('SELECT `v` FROM `casino_settings`') then local v = DB.settings[p[1]] return v and { v = v } or nil end
    if sql:find('INSERT INTO `casino_settings`') then DB.settings[p[1]] = p[2] return 1 end
    if sql:find('INSERT INTO `casino_log`') then local r = { id = nid(), kind = p[1], ref = p[2], cid = p[3], name = p[4], bet = p[5], won = p[6], detail = p[7], test = p[8] } DB.log[#DB.log + 1] = r return r.id end
    if sql:find('INSERT INTO `casino_tx`') then DB.tx[#DB.tx + 1] = { cid = p[1], kind = p[3], chips = p[4], money = p[5], fee = p[6] } return nid() end
    if sql:find('INSERT INTO `casino_pending`') then
        local r = { id = nid(), cid = p[1] }
        if sql:find('`chips`, `money`') then r.chips, r.money, r.reason = p[2], p[3], p[4]
        elseif sql:find('`money`') then r.chips, r.money, r.reason = 0, p[2], p[3]
        else r.chips, r.money, r.reason = p[2], 0, p[3] end
        DB.pending[#DB.pending + 1] = r return r.id
    end
    if sql:find('FROM `casino_pending` WHERE `citizenid`') then
        local out = {} for _, r in ipairs(DB.pending) do if r.cid == p[1] then out[#out + 1] = { id = r.id, chips = r.chips, money = r.money, reason = r.reason } end end return out
    end
    if sql:find('DELETE FROM `casino_pending`') then
        for i, r in ipairs(DB.pending) do if r.id == p[1] then table.remove(DB.pending, i) return 1 end end return 0
    end
    if sql:find('SELECT `spins` FROM `casino_wheel_daily`') then return DB.daily[p[1] .. ':' .. p[2]] end
    if sql:find('INSERT INTO `casino_wheel_daily`') then local k = p[1] .. ':' .. p[2] DB.daily[k] = (DB.daily[k] or 0) + 1 return 1 end
    if sql:find('DELETE FROM') then return 0 end
    if sql:find('SELECT') then return {} end
    return 0
end
local function method()
    return setmetatable({ await = function(sql, p) return exec(sql, p) end }, { __call = function(_, sql, p, cb) local r = exec(sql, p) if cb then cb(r) end end })
end
MySQL = { query = method(), single = method(), scalar = method(), insert = method(), update = method(),
    ready = setmetatable({ await = function() return true end }, { __call = function(_, cb) cb() end }) }

-- ---------------------------------------------------------------- joueurs, argent, inventaire
local P = {}   -- [src] = { cid, name, cash, bank, items = {}, online, pos, full }
local function addPlayer(src, cid, cash)
    P[src] = { cid = cid, name = 'Joueur ' .. src, cash = cash or 0, bank = 0, items = {}, online = true, pos = vector3(0.5, -1.2, 0.0) }
end
function vector3(x, y, z)
    return setmetatable({ x = x, y = y, z = z }, { __sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end,
        __add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end,
        __len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end })
end
function GetPlayerName(src) local p = P[src] return p and p.online and p.name or nil end
function GetPlayerPed(src) return P[src] and P[src].online and src or 0 end
function GetEntityCoords(ped) return P[ped] and P[ped].pos or vector3(0, 0, 0) end
function GetPlayers() local o = {} for s, p in pairs(P) do if p.online then o[#o + 1] = tostring(s) end end return o end
function GetCurrentResourceName() return 'elyzea_casino' end
function IsDuplicityVersion() return true end
local sent = {}
function TriggerClientEvent(name, target, ...) sent[#sent + 1] = { name = name, target = target, args = { ... } } end
local handlers = {}
function RegisterNetEvent(name, fn) if fn then handlers[name] = handlers[name] or {} table.insert(handlers[name], fn) end end
function AddEventHandler(name, fn) handlers[name] = handlers[name] or {} table.insert(handlers[name], fn) end
function TriggerEvent(name, ...) for _, fn in ipairs(handlers[name] or {}) do fn(...) end end
local function fire(name, src, ...) source = src for _, fn in ipairs(handlers[name] or {}) do fn(...) end end
json = { encode = function(t) return pyjson_encode(t) end, decode = function(s) return pyjson_decode(s) end }

local ITEMS = { jetons_casino = {}, water = {} }
local EXP = {}
EXP.elyzea_core = {
    GetPlayerData = function(_, src) local p = P[src] return p and p.online and { citizenid = p.cid, charinfo = { firstname = p.name, lastname = '' } } or nil end,
    GetMoney = function(_, src, kind) return P[src][kind] or 0 end,
    AddMoney = function(_, src, kind, n) if not P[src] or not P[src].online then return false end P[src][kind] = P[src][kind] + n return true end,
    RemoveMoney = function(_, src, kind, n) if P[src][kind] < n then return false end P[src][kind] = P[src][kind] - n return true end,
    Notify = function() end,
}
EXP.elyzea_inventory = {
    GetItemCount = function(_, src, item) return (P[src] and P[src].items[item]) or 0 end,
    RemoveItem = function(_, src, item, n) local p = P[src] if (p.items[item] or 0) < n then return false end p.items[item] = p.items[item] - n return true end,
    AddItem = function(_, src, item, n) local p = P[src] if not p or not p.online or p.full or not ITEMS[item] then return false end p.items[item] = (p.items[item] or 0) + n return true end,
    CanCarryItem = function(_, src) return not P[src].full end,
    GetItemList = function() return ITEMS end,
}
local POINTS = {
    { id = 1, name = 'Croupier', x = 0.0, y = 0.8, z = 0.0, h = 180.0, casino = { role = 'blackjack', name = 'BJ', table = { x = 0.0, y = 0.0, z = 0.0, h = 0.0 } } },
    { id = 2, name = 'Croupière', x = 10.0, y = 0.8, z = 0.0, h = 180.0, casino = { role = 'roulette', name = 'RL', table = { x = 10.0, y = 0.0, z = 0.0, h = 0.0 } } },
    { id = 3, name = 'Animatrice', x = 20.0, y = 0.8, z = 0.0, h = 180.0, casino = { role = 'wheel', name = 'Roue', wheel = 'lucky', table = { x = 20.0, y = 0.0, z = 0.0, h = 0.0 } } },
    { id = 4, name = 'Caissier', x = 0.5, y = -1.2, z = 0.0, h = 0.0, casino = { role = 'cashier', name = 'Caisse' } },
}
local ADMINS = { [1] = true }
EXP.admin_menu = {
    GetCasinoPoints = function() return POINTS end,
    HasPermission = function(_, src, perm) return ADMINS[src] == true end,
}
local exported = {}
exports = setmetatable({}, {
    __index = function(_, k) return EXP[k] end,
    __call = function(_, name, fn) exported[name] = fn end,
})

-- Ely.callback
local CB = {}
Ely = { callback = { register = function(name, fn) CB[name] = fn end } }
local function call(name, src, ...) return CB[name](src, ...) end

-- ---------------------------------------------------------------- chargement du vrai code
local function load(f)
    local fh = io.open(ROOT .. '/' .. f, 'r')
    local src = fh:read('a') fh:close()
    local fn, err = load_chunk(src, '@' .. f)
    if not fn then error(err) end
    fn()
end
load_chunk = load_chunk or load
for _, f in ipairs({ 'config.lua', 'shared/rules.lua', 'server/core.lua', 'server/seats.lua', 'server/cashier.lua', 'server/blackjack.lua',
    'server/roulette.lua', 'server/wheel.lua', 'server/admin.lua' }) do load(f) end
run(200)
local AdminAction = exported.AdminAction

-- Tirages imposés : math.random contrôlé
local realRandom = math.random
local forced = nil
math.random = function(a, b)
    if forced and #forced > 0 then return table.remove(forced, 1) end
    if a == nil then return realRandom() end
    return realRandom(a, b)
end

-- ================================================================== règles
section('Règles du blackjack')
local C = function(r, s) return { r = r, s = s or 's' } end
check(Rules.HandTotal({ C('A'), C('K') }) == 21 and Rules.IsBlackjack({ C('A'), C('K') }), 'As + Roi = blackjack')
local t, soft = Rules.HandTotal({ C('A'), C('6') })
check(t == 17 and soft, 'As + 6 = 17 souple')
check(Rules.HandTotal({ C('A'), C('A'), C('9') }) == 21, 'As + As + 9 = 21')
check(Rules.HandTotal({ C('K'), C('Q'), C('5') }) == 25, 'dépassement compté')
check(Rules.DealerShouldHit({ C('A'), C('6') }, true) and not Rules.DealerShouldHit({ C('A'), C('6') }, false), 'croupier : 17 souple selon la règle')
check(not Rules.DealerShouldHit({ C('10'), C('7') }, true), 'croupier reste sur 17 dur')
local r1, a1 = Rules.Settle({ cards = { C('A'), C('K') }, bet = 100 }, { C('10'), C('9') }, 1.5)
check(r1 == 'blackjack' and a1 == 250, 'blackjack payé 3:2 (100 → 250)')
local r2, a2 = Rules.Settle({ cards = { C('10'), C('9') }, bet = 100 }, { C('10'), C('9') }, 1.5)
check(r2 == 'push' and a2 == 100, 'égalité : mise rendue')
local r3, a3 = Rules.Settle({ cards = { C('10'), C('5'), C('9') }, bet = 100 }, { C('10'), C('6'), C('9') }, 1.5)
check(r3 == 'lose' and a3 == 0, 'joueur dépasse : perdu même si le croupier dépasse')
local r4, a4 = Rules.Settle({ cards = { C('10'), C('8') }, bet = 100 }, { C('10'), C('6'), C('9') }, 1.5)
check(r4 == 'win' and a4 == 200, 'croupier dépasse : gagné 1:1')
local r5 = Rules.Settle({ cards = { C('A'), C('K') }, bet = 100, split = true }, { C('10'), C('9') }, 1.5)
check(r5 == 'win', 'As + Roi après séparation = 21 (pas blackjack)')
check(Rules.CanSplit({ cards = { C('K'), C('10') } }, 1, Config.DefaultBlackjack), 'séparer deux cartes de valeur 10')
check(not Rules.CanDouble({ cards = { C('10'), C('8') } }, { allowDouble = true, doubleOn = '9-11' }), 'doubler interdit sur 18 si règle 9-11')

section('Règles de la roulette')
local b = Rules.NormalizeBet({ kind = 'straight', numbers = { 17 } }, 'eu')
check(b and b.pays == 35, 'plein payé 35:1')
check(Rules.NormalizeBet({ kind = 'split', numbers = { 17, 20 } }, 'eu').pays == 17, 'cheval vertical 17/20 payé 17:1')
check(Rules.NormalizeBet({ kind = 'split', numbers = { 3, 4 } }, 'eu') == nil, 'cheval 3/4 refusé (pas voisins sur le tapis)')
check(Rules.NormalizeBet({ kind = 'split', numbers = { 0, 37 } }, 'eu') == nil and Rules.NormalizeBet({ kind = 'split', numbers = { 0, 37 } }, 'us') ~= nil, '0/00 seulement en américaine')
check(Rules.NormalizeBet({ kind = 'corner', numbers = { 1, 2, 4, 5 } }, 'eu').pays == 8, 'carré payé 8:1')
check(Rules.NormalizeBet({ kind = 'corner', numbers = { 2, 3, 5, 6 } }, 'eu') ~= nil and Rules.NormalizeBet({ kind = 'corner', numbers = { 3, 4, 6, 7 } }, 'eu') == nil, 'carré : seulement 4 numéros en carré')
check(Rules.NormalizeBet({ kind = 'street', numbers = { 4, 5, 6 } }, 'eu').pays == 11, 'transversale payée 11:1')
check(Rules.NormalizeBet({ kind = 'sixline', numbers = { 1, 2, 3, 4, 5, 6 } }, 'eu').pays == 5, 'sixain payé 5:1')
check(Rules.NormalizeBet({ kind = 'dozen', n = 2 }, 'eu').pays == 2 and Rules.NormalizeBet({ kind = 'column', n = 1 }, 'eu').pays == 2, 'douzaine et colonne payées 2:1')
local red = Rules.NormalizeBet({ kind = 'red' }, 'eu')
check(red.pays == 1 and #red.numbers == 18 and not Rules.BetWins(red, 0), 'rouge payé 1:1, perd sur le 0')
check(Rules.NormalizeBet({ kind = 'straight', numbers = { 37 } }, 'eu') == nil, 'case 00 refusée en européenne')

section('Roue : chances')
local segs = { { weight = 10 }, { weight = 30 }, { weight = 60 } }
check(Rules.WeightsValid(segs), 'total 100 % accepté')
check(not Rules.WeightsValid({ { weight = 10 }, { weight = 30 } }), 'total 40 % refusé')
local n2 = Rules.Normalize({ { weight = 1 }, { weight = 1 }, { weight = 2 } })
check(math.abs(Rules.WeightsTotal(n2) - 100) < 0.001 and n2[3].weight == 50, 'normalisation garde les proportions (25/25/50)')
local counts = { 0, 0, 0 }
for _ = 1, 30000 do local i = Rules.Draw(segs, realRandom()) counts[i] = counts[i] + 1 end
check(math.abs(counts[1] / 300 - 10) < 1.5 and math.abs(counts[2] / 300 - 30) < 2 and math.abs(counts[3] / 300 - 60) < 2,
    ('30 000 tirages : %.1f / %.1f / %.1f %% (réglé 10 / 30 / 60)'):format(counts[1] / 300, counts[2] / 300, counts[3] / 300))

-- ================================================================== guichet
section('Guichet : achat et revente')
addPlayer(10, 'CID10', 1000)
P[10].pos = vector3(0.5, -1.2, 0.0)
local ok, msg = call('elyzea_casino:cashier:tx', 10, { pedId = 4, kind = 'buy', chips = 500, account = 'cash', nonce = 'n1' })
check(ok and P[10].items.jetons_casino == 500 and P[10].cash == 500, 'achat de 500 jetons : -500 $, +500 jetons')
ok = call('elyzea_casino:cashier:tx', 10, { pedId = 4, kind = 'buy', chips = 500, account = 'cash', nonce = 'n1' })
check(P[10].items.jetons_casino == 500 and P[10].cash == 500, 'même demande renvoyée : exécutée une seule fois')
ok, msg = call('elyzea_casino:cashier:tx', 10, { pedId = 4, kind = 'buy', chips = 900, account = 'cash', nonce = 'n2' })
check(not ok and P[10].cash == 500 and P[10].items.jetons_casino == 500, 'solde insuffisant : refusé, rien ne bouge (' .. tostring(msg) .. ')')
P[10].full = true
ok, msg = call('elyzea_casino:cashier:tx', 10, { pedId = 4, kind = 'buy', chips = 100, account = 'cash', nonce = 'n3' })
check(not ok and P[10].cash == 500, 'inventaire plein : refusé sans débit')
P[10].full = false
ok = call('elyzea_casino:cashier:tx', 10, { pedId = 4, kind = 'sell', chips = 200, account = 'cash', nonce = 'n4' })
check(ok and P[10].items.jetons_casino == 300 and P[10].cash == 700, 'revente de 200 jetons : +200 $')
ok = call('elyzea_casino:cashier:tx', 10, { pedId = 4, kind = 'sell', chips = 5000, account = 'cash', nonce = 'n5' })
check(not ok and P[10].items.jetons_casino == 300, 'revente de plus que ce qu\'on a : refusée')
P[10].pos = vector3(100, 100, 0)
ok, msg = call('elyzea_casino:cashier:tx', 10, { pedId = 4, kind = 'buy', chips = 10, account = 'cash', nonce = 'n6' })
check(not ok, 'loin du guichet : refusé (' .. tostring(msg) .. ')')
P[10].pos = vector3(0.5, -1.2, 0.0)
ok, msg = call('elyzea_casino:cashier:tx', 10, { pedId = 4, kind = 'buy', chips = 5, account = 'cash', nonce = 'n7' })
check(not ok, 'sous le minimum par transaction : refusé')
check(#DB.tx == 2, 'deux transactions journalisées')

-- Sabot imposé : les cartes données sont tirées dans l'ordre, au-dessus de 40 cartes de remplissage
local function impose(T, list)
    T.shoe = {}
    for _ = 1, 40 do T.shoe[#T.shoe + 1] = C('4', 'd') end
    for i = #list, 1, -1 do T.shoe[#T.shoe + 1] = list[i] end
end
-- ================================================================== blackjack
section('Blackjack : places')
addPlayer(11, 'CID11', 0) P[11].items.jetons_casino = 1000 P[11].pos = vector3(0.5, -1.0, 0)
addPlayer(12, 'CID12', 0) P[12].items.jetons_casino = 1000 P[12].pos = vector3(-0.5, -1.0, 0)
addPlayer(13, 'CID13', 0) P[13].items.jetons_casino = 1000 P[13].pos = vector3(0.0, -1.0, 0)
ok = call('elyzea_casino:sit', 11, 1, 2)
check(ok, 'joueur A assis place 2')
ok, msg = call('elyzea_casino:sit', 12, 1, 2)
check(not ok, 'joueur B refusé sur la même place (' .. tostring(msg) .. ')')
ok = call('elyzea_casino:sit', 12, 1, 3)
check(ok, 'joueur B assis place 3')
ok, msg = call('elyzea_casino:sit', 11, 1, 4)
check(not ok, 'joueur A ne peut pas prendre une 2e place')
ok, msg = call('elyzea_casino:sit', 13, 1, 5)
check(not ok, 'place 5 refusée (4 maximum)')
run(500)
check(Tables[1].phase == 'betting', 'table en phase de mises')

section('Blackjack : manche complète (cartes imposées)')
call('elyzea_casino:bj:action', 11, { pedId = 1, action = 'bet', amount = 100 })
call('elyzea_casino:bj:action', 12, { pedId = 1, action = 'bet', amount = 200 })
check(P[11].items.jetons_casino == 900 and P[12].items.jetons_casino == 800, 'mises bloquées (retirées de l\'inventaire)')
ok = call('elyzea_casino:bj:action', 11, { pedId = 1, action = 'bet', amount = 50 })
check(ok and P[11].items.jetons_casino == 950, 'mise réduite : différence rendue')
call('elyzea_casino:bj:action', 11, { pedId = 1, action = 'bet', amount = 100 })
-- Sabot imposé (tiré par la fin) : A=10♠,7 · B=A,K (blackjack) · croupier 9, 7 ; A tire un 2 (19) ; croupier 16 → tire 5 = 21
impose(Tables[1], { C('10'), C('A'), C('9'), C('7'), C('K'), C('7'), C('2'), C('5') })
-- tirages : A:10 · B:A · croupier:9 · A:7 · B:K · croupier:7 (caché) · A tire 2 · croupier tire 5
call('elyzea_casino:bj:action', 11, { pedId = 1, action = 'ready' })
call('elyzea_casino:bj:action', 12, { pedId = 1, action = 'ready' })
for _ = 1, 400 do
    if Tables[1].turn then break end
    run(50)
end
local T1 = Tables[1]
check(T1.phase == 'players' and T1.turn and T1.turn.seat == 2, 'au tour du joueur A (le blackjack de B est automatique)')
ok, msg = call('elyzea_casino:bj:action', 12, { pedId = 1, action = 'hit' })
check(not ok, 'B ne peut pas jouer pendant le tour de A (' .. tostring(msg) .. ')')
local dealerPublic = Casino.Games.blackjack.public(T1).dealer.cards[2]
check(dealerPublic.hidden == true and dealerPublic.r == nil, 'la carte cachée du croupier n\'est pas envoyée aux joueurs')
ok = call('elyzea_casino:bj:action', 11, { pedId = 1, action = 'hit' })
check(ok and Rules.HandTotal(T1.seats[2].hands[1].cards) == 19, 'A tire un 2 : 19')
call('elyzea_casino:bj:action', 11, { pedId = 1, action = 'stand' })
run(3500)
check(Rules.HandTotal(T1.dealer.cards) == 21, 'croupier : 9 + 7 + 5 = 21')
run(5500)
check(P[11].items.jetons_casino == 900, 'A (19) perd contre 21 : 900 jetons')
check(P[12].items.jetons_casino == 800 + 500, 'B blackjack payé 3:2 : 200 → 500 (1 300 jetons)')
run(8000)
check(T1.phase == 'betting' and not T1.seats[2].hands, 'manche suivante : mises ouvertes, mains vidées')

section('Blackjack : départ et déconnexion')
call('elyzea_casino:bj:action', 11, { pedId = 1, action = 'bet', amount = 100 })
call('elyzea_casino:leave', 11)
check(P[11].items.jetons_casino == 900 and not T1.seats[2], 'quitter pendant les mises : mise rendue, place libérée')
ok = call('elyzea_casino:sit', 13, 1, 2)
check(ok, 'la place libérée est reprise par un autre joueur')
call('elyzea_casino:bj:action', 13, { pedId = 1, action = 'bet', amount = 100 })
call('elyzea_casino:bj:action', 12, { pedId = 1, action = 'bet', amount = 100 })
-- C:10,10 (20) · B:9,7 (16) · croupier: 10, 8 (18)
impose(T1, { C('10'), C('9'), C('10'), C('10'), C('7'), C('8'), C('5') })
call('elyzea_casino:bj:action', 13, { pedId = 1, action = 'ready' })
call('elyzea_casino:bj:action', 12, { pedId = 1, action = 'ready' })
for _ = 1, 400 do if T1.turn then break end run(50) end
check(T1.turn and T1.turn.seat == 2, 'au tour de C (20)')
P[13].online = false
fire('playerDropped', 13)
run(400)
check(T1.seats[2] and T1.seats[2].left, 'C déconnecté : sa main reste (il « reste » automatiquement)')
for _ = 1, 200 do if T1.turn and T1.turn.seat == 3 then break end run(50) end
ok = call('elyzea_casino:bj:action', 12, { pedId = 1, action = 'stand' })
check(ok, 'puis au tour de B, qui reste')
run(4000)
local pend = 0
for _, r in ipairs(DB.pending) do if r.cid == 'CID13' then pend = pend + r.chips end end
check(pend == 200, 'C a gagné (20 contre 18) hors ligne : 200 jetons mis en attente')
check(P[12].items.jetons_casino == 1300 - 100, 'B (16) perd sa mise de 100')
P[13].online = true
TriggerEvent('elyzea:server:playerLogin', 13)
run(6000)
check(P[13].items.jetons_casino == 900 + 200 and #DB.pending == 0, 'à la reconnexion : 200 jetons rendus, une seule fois')
run(8000)
check(not T1.seats[2], 'place de C libérée après la manche')

section('Blackjack : remise à zéro par le staff pendant une manche')
ok = call('elyzea_casino:sit', 13, 1, 2)
call('elyzea_casino:bj:action', 13, { pedId = 1, action = 'bet', amount = 300 })
call('elyzea_casino:bj:action', 12, { pedId = 1, action = 'bet', amount = 100 })
local before13, before12 = P[13].items.jetons_casino, P[12].items.jetons_casino
impose(T1, { C('5'), C('6'), C('9'), C('5'), C('6'), C('8'), C('2'), C('3') })
call('elyzea_casino:bj:action', 13, { pedId = 1, action = 'ready' })
call('elyzea_casino:bj:action', 12, { pedId = 1, action = 'ready' })
for _ = 1, 400 do if T1.turn then break end run(50) end
ok, msg = call('elyzea_casino:bj:action', 13, { pedId = 1, action = 'double' })
if not ok then print('    (double : ' .. tostring(msg) .. ', tour ' .. tostring(T1.turn and T1.turn.seat) .. ')') end
check(ok and P[13].items.jetons_casino == before13 - 300, 'C double (5 + 5 = 10) : 300 jetons de plus bloqués')
ok, msg = AdminAction(2, 'table_reset', { id = 1 })
check(not ok, 'remise à zéro sans permission : refusée (' .. tostring(msg) .. ')')
ok = AdminAction(1, 'table_reset', { id = 1 })
run(10000)
check(P[13].items.jetons_casino == before13 + 300 and P[12].items.jetons_casino == before12 + 100, 'remise à zéro : mises (doublée comprise) rendues exactement')
check(not next(T1.seats) and T1.phase == 'idle', 'joueurs relevés, table libre, aucun paiement en plus')

-- ================================================================== roulette
section('Roulette')
addPlayer(21, 'CID21', 0) P[21].items.jetons_casino = 1000 P[21].pos = vector3(10.5, -1.0, 0)
addPlayer(22, 'CID22', 0) P[22].items.jetons_casino = 1000 P[22].pos = vector3(9.5, -1.0, 0)
call('elyzea_casino:sit', 21, 2, 1)
call('elyzea_casino:sit', 22, 2, 2)
run(500)
local T2 = Tables[2]
check(T2.phase == 'betting', 'mises ouvertes')
ok = call('elyzea_casino:rl:action', 21, { pedId = 2, action = 'bet', bet = { kind = 'straight', numbers = { 17 } }, amount = 10 })
ok = call('elyzea_casino:rl:action', 21, { pedId = 2, action = 'bet', bet = { kind = 'red' }, amount = 100 })
ok = call('elyzea_casino:rl:action', 21, { pedId = 2, action = 'bet', bet = { kind = 'dozen', n = 2 }, amount = 50 })
check(P[21].items.jetons_casino == 840, '3 mises de A : 160 jetons bloqués')
ok, msg = call('elyzea_casino:rl:action', 21, { pedId = 2, action = 'bet', bet = { kind = 'split', numbers = { 3, 4 } }, amount = 10 })
check(not ok and P[21].items.jetons_casino == 840, 'mise invalide refusée sans débit (' .. tostring(msg) .. ')')
call('elyzea_casino:rl:action', 22, { pedId = 2, action = 'bet', bet = { kind = 'black' }, amount = 200 })
call('elyzea_casino:rl:action', 22, { pedId = 2, action = 'bet', bet = { kind = 'straight', numbers = { 0 } }, amount = 20 })
call('elyzea_casino:rl:action', 22, { pedId = 2, action = 'unbet', key = 'straight:0' })
check(P[22].items.jetons_casino == 800, 'B retire une mise avant la fermeture : remboursée')
forced = { 17 }   -- la bille tombe sur le 17 (rouge, 2e douzaine)
run(31000)
check(T2.phase == 'spinning' and T2.result == 17, 'mises fermées, résultat tiré AVANT l\'animation : 17')
ok, msg = call('elyzea_casino:rl:action', 21, { pedId = 2, action = 'bet', bet = { kind = 'black' }, amount = 10 })
check(not ok, 'mise après la fermeture refusée (' .. tostring(msg) .. ')')
P[22].online = false
fire('playerDropped', 22)
run(11000)
-- A : plein 17 (10 → 360) + rouge (100 → 200) + 2e douzaine (50 → 150) = 710
-- 17 est NOIR (rouges : 1 3 5 7 9 12 14 16 18 19 21 23 25 27 30 32 34 36)
-- A : plein 17 (10 → 360) + 2e douzaine (50 → 150) = 510 ; son rouge perd
check(P[21].items.jetons_casino == 840 + 510, 'A gagne 510 jetons (plein 35:1, douzaine 2:1 ; le rouge perd sur le 17 noir)')
local pend22 = 0
for _, r in ipairs(DB.pending) do if r.cid == 'CID22' then pend22 = pend22 + r.chips end end
check(pend22 == 400, 'B (noir gagnant) déconnecté pendant la roue : 400 jetons mis en attente')
run(8000)
check(T2.phase == 'betting' and T2.history[1] == 17, 'nouveau tour, 17 dans l\'historique')

-- ================================================================== roue
section('Roue de la fortune')
addPlayer(31, 'CID31', 0) P[31].items.jetons_casino = 1000 P[31].pos = vector3(20.5, -1.0, 0)
forced = nil
local W = Casino.WheelById('lucky')
check(W and Rules.WeightsValid(W.segments), 'roue par défaut valide (100 %)')
ok = call('elyzea_casino:wheel:spin', 31, { pedId = 3, nonce = 'w1' })
check(ok and P[31].items.jetons_casino == 900, 'participation payée : 100 jetons')
ok, msg = call('elyzea_casino:wheel:spin', 31, { pedId = 3, nonce = 'w1' })
check(not ok and P[31].items.jetons_casino == 900, 'même demande renvoyée : refusée, rien de prélevé')
ok, msg = call('elyzea_casino:wheel:spin', 31, { pedId = 3, nonce = 'w2' })
check(not ok, 'roue déjà en train de tourner / attente : refusé (' .. tostring(msg) .. ')')
local before = P[31].items.jetons_casino
local logsBefore = #DB.log
run(10000)
local last = DB.log[#DB.log]
check(#DB.log == logsBefore + 1 and last.kind == 'wheel', 'résultat journalisé une seule fois : ' .. tostring(last.detail))
check(P[31].items.jetons_casino - before == last.won, 'lot en jetons remis exactement (' .. tostring(last.won) .. ')')
-- objet qui n'existe plus : participation remboursée
W.segments = { { label = 'Objet perdu', reward = 'item', item = 'objet_supprime', count = 1, weight = 100 }, { label = 'Rien', reward = 'none', weight = 0 } }
W.cooldown = 0
run(2000)
local b31 = P[31].items.jetons_casino
ok = call('elyzea_casino:wheel:spin', 31, { pedId = 3, nonce = 'w3' })
run(10000)
check(P[31].items.jetons_casino == b31, 'lot impossible (objet supprimé) : participation remboursée')
W.segments = { { label = 'A', reward = 'none', weight = 30 }, { label = 'B', reward = 'none', weight = 30 } }
ok, msg = call('elyzea_casino:wheel:spin', 31, { pedId = 3, nonce = 'w4' })
check(not ok, 'roue à 60 % : refusée aux joueurs (' .. tostring(msg) .. ')')

section('Admin')
ok, msg = AdminAction(1, 'wheel_save', { wheel = { id = 'test', name = 'Test', enabled = true, segments = { { label = 'A', weight = 30 }, { label = 'B', weight = 30 } } } })
check(ok and Casino.WheelById('test') and not Casino.WheelById('test').enabled, 'roue enregistrée mais désactivée (chances à 60 %) : ' .. tostring(msg))
ok = AdminAction(1, 'wheel_normalize', { id = 'test' })
check(ok and Rules.WeightsValid(Casino.WheelById('test').segments), 'normalisation explicite : 50 / 50')
ok, msg = AdminAction(1, 'wheel_save', { wheel = { id = 'test2', name = 'T2', segments = { { label = 'X', reward = 'item', item = 'n_existe_pas', weight = 50 }, { label = 'Y', weight = 50 } } } })
check(not ok, 'objet inconnu refusé à l\'enregistrement : ' .. tostring(msg))
ok, msg = AdminAction(1, 'cashier_save', { enabled = true, buyRate = 1, sellRate = 2, minTx = 1, maxTx = 10, accounts = { cash = true } })
check(not ok, 'revente plus chère que l\'achat refusée : ' .. tostring(msg))
ok, msg = AdminAction(1, 'table_save', { id = 1, cfg = { enabled = true, minBet = 500, maxBet = 100 } })
check(not ok, 'mise max < mise min refusée')
ok = AdminAction(1, 'table_save', { id = 1, cfg = { enabled = true, minBet = 20, maxBet = 2000, maxPlayers = 9 } })
check(ok and Casino.TableCfg(1, 'blackjack').maxPlayers == 4, 'joueurs ramenés à 4 maximum')
ok, msg = AdminAction(5, 'global_save', { enabled = false })
check(not ok and Casino.settings.global.enabled, 'joueur sans permission : refusé, rien ne change')
local sim = select(3, AdminAction(1, 'wheel_simulate', { id = 'test', n = 20000 }))
check(sim and sim.simulation and math.abs(sim.simulation[1].got - 50) < 2, ('simulation admin : %s %% / %s %% (réglé 50 / 50)'):format(sim and sim.simulation[1].got, sim and sim.simulation[2].got))

section('Table supprimée dans l\'éditeur pendant une partie')
addPlayer(41, 'CID41', 0) P[41].items.jetons_casino = 500 P[41].pos = vector3(10.5, -1.0, 0)
call('elyzea_casino:sit', 41, 2, 3)
run(300)
call('elyzea_casino:rl:action', 41, { pedId = 2, action = 'bet', bet = { kind = 'odd' }, amount = 100 })
check(P[41].items.jetons_casino == 400, 'mise posée')
table.remove(POINTS, 2)
TriggerEvent('adminmenu:pedsChanged')
run(1000)
check(P[41].items.jetons_casino == 500 and not Tables[2] and not SeatOf[41], 'PNJ / table supprimé : mise rendue, joueur relevé, autres tables intactes')
check(Tables[1] ~= nil or Casino.points[1] ~= nil, 'la table de blackjack existe toujours')

print(('\nRésultat : %d réussis, %d échecs'):format(PASS, FAIL))
return FAIL
