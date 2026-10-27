-- =====================================================================
--  Tests hors jeu : serveur complet (installations, parties, bowling, billard, golf)
--  Vrais fichiers : config, shared/*, server/*. FiveM, MySQL, elyzea_core et le temps sont imités.
-- =====================================================================
local root = ...
local P = print
local passes, fails = 0, 0
local function check(c, label)
    if c then passes = passes + 1 P('  ok   ' .. label) else fails = fails + 1 P('  ÉCHEC ' .. label) end
end

-- ---------------------------------------------------------------- monde imité
local NOW, GT = 1800000000, 0
os.time = function(t) if t then return 0 end return NOW end
GetGameTimer = function() return GT end
local timers = {}
function SetTimeout(ms, fn) timers[#timers + 1] = { at = GT + ms, fn = fn } end
local threads = {}
function CreateThread(fn) local co = coroutine.create(fn) threads[#threads + 1] = { co = co, wake = GT } end
Citizen = { Await = function(p) return p.value end }
promise = { new = function() local p = {} function p:resolve(v) self.value = v end return p end }
function Wait(ms) coroutine.yield(ms or 0) end
local function run(ms)
    local stop = GT + (ms or 0)
    repeat
        for _, t in ipairs(threads) do
            if coroutine.status(t.co) ~= 'dead' and t.wake <= GT then
                local ok, w = coroutine.resume(t.co)
                if not ok then error(w) end
                t.wake = GT + (w or 0)
            end
        end
        for i = #timers, 1, -1 do local t = timers[i] if t.at <= GT then table.remove(timers, i) t.fn() end end
        if GT >= stop then break end
        GT = GT + 100
        if GT % 1000 == 0 then NOW = NOW + 1 end
    until false
end
vector3 = function(x, y, z)
    return setmetatable({ x = x, y = y, z = z }, { __sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end,
        __len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end })
end
vec3 = vector3
json = { encode = function(t) return t end, decode = function(t) return t end }   -- la base imitée garde les tables
function print() end

local players, sentClient = {}, {}
local function addPlayer(id, name, x, y, z, money)
    players[id] = { name = name, cid = 'CID' .. id, pos = vector3(x, y, z + 1.0), h = 0.0, health = 200, money = money or 1000, state = {} }
end
function GetPlayerName(s) local p = players[tonumber(s) or -1] return p and not p.gone and p.name or nil end
function GetPlayers() local t = {} for id, p in pairs(players) do if not p.gone then t[#t + 1] = tostring(id) end end return t end
function GetPlayerPed(s) return players[s] and not players[s].gone and s or 0 end
function GetEntityCoords(ped) return players[ped].pos end
function GetEntityHeading(ped) return players[ped].h end
function GetEntityHealth(ped) return players[ped].health end
function SetEntityCoords(ped, x, y, z) players[ped].pos = vector3(x, y, z) end
function Player(s) return { state = players[s] and players[s].state or {} } end
local events, handlers = {}, {}
function RegisterNetEvent(n, fn) if fn then events[n] = fn end end
function AddEventHandler(n, fn) handlers[n] = handlers[n] or {} table.insert(handlers[n], fn) end
function TriggerEvent(n, ...) for _, fn in ipairs(handlers[n] or {}) do fn(...) end end
function TriggerClientEvent(n, target, ...) sentClient[#sentClient + 1] = { n = n, t = target, a = { ... } } end
function TriggerLatentClientEvent(n, target, _, ...) TriggerClientEvent(n, target, ...) end
function GetCurrentResourceName() return 'elyzea_loisirs' end
local exported = {}
local core = {
    GetPlayer = function(_, s)
        local p = players[s]
        if not p or p.gone or p.unloaded then return nil end
        return { PlayerData = { charinfo = { firstname = p.name, lastname = '', gender = 0 } }, Functions = {
            RemoveMoney = function(_, amount) if p.money < amount then return false end p.money = p.money - amount return true end,
            AddMoney = function(_, amount) p.money = p.money + amount return true end } }
    end,
    GetCitizenId = function(_, s) local p = players[s] return p and not p.gone and not p.unloaded and p.cid or nil end,
}
exports = setmetatable({ elyzea_core = core }, { __call = function(_, n, fn) exported[n] = fn end })
-- base de données imitée
local DB, dbseq = {}, 0
MySQL = {
    query = { await = function(sql) if sql:find('^SELECT') then local t = {} for _, r in pairs(DB) do t[#t + 1] = r end return t end return {} end },
    insert = { await = function(_, a) dbseq = dbseq + 1 DB[dbseq] = { id = dbseq, kind = a[1], name = a[2], data = a[3] } return dbseq end },
    update = { await = function(sql, a)
        if sql:find('^DELETE') then DB[a[1]] = nil return 1 end
        local r = DB[a[3]] if r then r.name, r.data = a[1], a[2] end return 1 end },
}
-- rappels Ely imités
local cbs = {}
Ely = { callback = { register = function(n, fn) cbs[n] = fn end } }
local function call(src, name, ...) return cbs[name](src, ...) end

-- ---------------------------------------------------------------- chargement
local function boot()
    threads, timers = {}, {}
    events, handlers, cbs = {}, {}, {}
    for _, f in ipairs({ 'config.lua', 'shared/utils.lua', 'shared/bowling.lua', 'shared/billiards.lua', 'shared/golf.lua',
        'server/main.lua', 'server/sessions.lua', 'server/bowling.lua', 'server/billiards.lua', 'server/golf.lua' }) do
        local h = assert(io.open(root .. '/' .. f, 'r'))
        local src = h:read('a') h:close()
        assert(load(src, '@' .. f))()
    end
    Config.Sessions.startDelay = 1
    run(500)
end
boot()
check(LS.ready, 'démarrage : base prête, table créée')

local function lastTo(src, name)
    for i = #sentClient, 1, -1 do local e = sentClient[i] if e.n == name and (e.t == src or e.t == -1) then return e.a end end
end
local function count(name, src) local n = 0 for _, e in ipairs(sentClient) do if e.n == name and (not src or e.t == src) then n = n + 1 end end return n end

-- staff : pose des installations (une action par seconde, comme un humain)
local function adm(src, name, data) run(1000) return exported.AdminAction(src, name, data) end
addPlayer(1, 'Alice', 100, 100, 30, 1000)
addPlayer(2, 'Bruno', 100, 101, 30, 1000)
addPlayer(3, 'Chloé', 100, 102, 30, 1000)
addPlayer(4, 'David', 500, 500, 30, 1000)
local ok, msg = adm(1, 'add_bowling', { name = 'Piste 1' })
check(ok and LS.inst[1] and LS.inst[1].kind == 'bowling', 'admin : piste de bowling posée à la position du staff')
players[1].pos = vector3(200, 200, 31)
ok = adm(1, 'add_bowling', { name = 'Piste 2' })
players[1].pos = vector3(300, 300, 31)
ok = adm(1, 'add_billiards', { name = 'Table' })
check(ok and LS.inst[3].kind == 'billiards' and LS.inst[3].data.spawn, 'admin : table de billard posée devant le staff')
players[1].pos = vector3(1000, 1000, 51) players[1].h = 0
adm(1, 'add_course', { name = 'Golf' })
local cid = 4
ok, msg = adm(1, 'hole_tee', { id = cid })
players[1].pos = vector3(1000, 1150, 51)
ok, msg = adm(1, 'hole_flag', { id = cid, hole = 1 })
adm(1, 'hole_set', { id = cid, hole = 1, par = 3, greenR = 14, fairwayW = 40 })
players[1].pos = vector3(1000, 1200, 51)
adm(1, 'hole_tee', { id = cid })
players[1].pos = vector3(1000, 1330, 51)
adm(1, 'hole_flag', { id = cid, hole = 2 })
players[1].pos = vector3(1000, 1260, 51)
adm(1, 'hole_hazard', { id = cid, hole = 2, type = 'water', radius = 25 })
check(#LS.inst[4].data.holes == 2 and LS.inst[4].data.holes[2].hazards[1].type == 'water', 'admin : parcours de 2 trous avec une zone d\'eau')
check(count('elyzea_loisirs:client:installations') > 0, 'installations envoyées aux clients')

-- =====================================================================
P('\n[Parties : socle commun]')
-- joueurs à la piste 1 (ligne de faute en 100,100, cap 0 : la piste part vers +y)
players[1].pos = vector3(100, 99, 31) players[2].pos = vector3(100.3, 99, 31) players[3].pos = vector3(99.7, 99, 31)
local r = call(1, 'loisirs:create', 1, { name = 'Soirée', max = 2 })
check(r.ok and r.session.state == 'WAITING' and r.session.max == 2, 'création d\'une partie (hôte, 2 places)')
r = call(1, 'loisirs:create', 2, {})
check(r.error, 'un joueur ne peut pas créer une 2e partie')
r = call(2, 'loisirs:create', 1, {})
check(r.error, 'la piste est déjà occupée : création refusée')
r = call(4, 'loisirs:join', 1)
check(r.error and r.error:find('Approche'), 'rejoindre de loin : refusé')
r = call(2, 'loisirs:join', 1)
check(r.ok and #r.session.players == 2, 'Bruno rejoint la partie')
r = call(2, 'loisirs:join', 1)
check(r.error, 'double inscription refusée')
r = call(3, 'loisirs:join', 1)
check(r.error and r.error:find('complète'), 'partie complète : Chloé refusée')
r = call(2, 'loisirs:start')
check(r.error, 'seul l\'hôte peut lancer')
-- départ de l'hôte avant le début : transfert à Bruno
call(1, 'loisirs:leave')
local s1 = LS.Sessions.all[1]
check(s1 and s1.host == 2 and #s1.order == 1, 'l\'hôte quitte avant le début : Bruno devient hôte')
r = call(1, 'loisirs:join', 1)
r = call(2, 'loisirs:start')
check(r.ok and s1.state == 'STARTING', 'lancement : compte à rebours')
run(1500)
check(s1.state == 'IN_PROGRESS' and s1.turn == 2, 'partie en cours, l\'ordre d\'inscription donne le premier tour (Bruno)')
r = call(3, 'loisirs:join', 1)
check(r.error, 'inscription refusée après le début')

-- deuxième partie simultanée sur la piste 2
players[3].pos = vector3(200, 199, 31)
r = call(3, 'loisirs:create', 2, {})
check(r.ok, 'deux parties en même temps sur deux pistes')
call(3, 'loisirs:start')
run(1500)
local s2 = LS.Sessions.all[2]
check(s2.state == 'IN_PROGRESS', 'partie solo de Chloé lancée (elle ne joue plus : test d\'inactivité)')

P('\n[Bowling]')
r = call(1, 'loisirs:play', { type = 'throw', seq = s1.seq, x = 0, angle = 0, power = 0.8, hook = 0 })
check(r.error and r.error:find('tour'), 'lancer hors tour refusé')
r = call(2, 'loisirs:play', { type = 'throw', seq = s1.seq, x = 5, angle = 0, power = 0.8, hook = 0 })
check(r.error, 'lancer aux paramètres impossibles refusé')
players[2].pos = vector3(100, 110, 31)
r = call(2, 'loisirs:play', { type = 'throw', seq = s1.seq, x = 0, angle = 0, power = 0.8, hook = 0 })
check(r.error and r.error:find('ligne de faute'), 'lancer depuis la piste (au-delà de la ligne) refusé')
players[2].pos = vector3(100.2, 98.5, 31)
local seq = s1.seq
r = call(2, 'loisirs:play', { type = 'throw', seq = seq, x = 0, angle = 0, power = 0.8, hook = 0 })
check(r.ok, 'lancer de Bruno accepté')
local rolls = #s1.data.players[2].rolls
r = call(2, 'loisirs:play', { type = 'throw', seq = seq, x = 0, angle = 0, power = 0.8, hook = 0 })
check(r.error and #s1.data.players[2].rolls == rolls, 'même lancer renvoyé deux fois : ignoré (pas de double comptage)')
check(count('elyzea_loisirs:client:shot', 1) >= 1 and count('elyzea_loisirs:client:shot', 2) >= 1, 'résultat du lancer envoyé aux deux joueurs')
-- on joue toute la partie
local guard = 0
while s1.state == 'IN_PROGRESS' and guard < 80 do
    guard = guard + 1
    run(12000)
    local who = s1.turn
    if who then
        players[who].pos = vector3(100 + (who == 1 and 0.2 or -0.2), 98.5, 31)
        call(who, 'loisirs:play', { type = 'throw', seq = s1.seq, x = -0.40, angle = 1.25, power = 0.85, hook = 0.5 })
    end
end
run(3000)
check(s1.state == 'FINISHED', ('partie de bowling terminée (%d lancers)'):format(guard))
local p1, p2 = s1.data.players[1].rolls, s1.data.players[2].rolls
local _, done1 = select(4, Bowling.Position(p1)), select(4, Bowling.Position(p2))
check(select(4, Bowling.Position(p1)) and select(4, Bowling.Position(p2)), '10 frames complètes pour chaque joueur')
local res = s1.results
local _, t1 = Bowling.Score(p1)
local _, t2 = Bowling.Score(p2)
check(res and #res.ranking == 2 and res.ranking[1].score == math.max(t1, t2), ('classement final correct (%d / %d)'):format(t1, t2))
check(res.ranking[1].strikes ~= nil and res.ranking[1].frames[10] ~= nil, 'détail des frames et nombre de strikes fournis')
check(LS.Sessions.byInst[1] == nil, 'piste libérée dès la fin de la partie')
r = call(1, 'loisirs:create', 1, {})
check(r.ok, 'nouvelle partie possible sur la piste libérée')
call(1, 'loisirs:leave')

P('\n[Temps écoulé, inactivité, déconnexion]')
local zeros = 0
for _, v in ipairs(s2.data.players[3].rolls) do if v == 0 then zeros = zeros + 1 end end
check(zeros >= 1, 'temps écoulé : le lancer est compté 0')
check(s2.state == 'FINISHED' and s2.players[3].status == 'left' and s2.players[3].leftReason == 'inactif', 'inactive deux fois de suite : Chloé retirée, partie fermée')
check(LS.Sessions.byInst[2] == nil, 'piste 2 libérée')
P('\n[Annulation et remboursement]')
Config.Games.bowling.price = 50
players[1].pos = vector3(100, 99, 31) players[2].pos = vector3(100.3, 99, 31)
local m1, m2 = players[1].money, players[2].money
r = call(1, 'loisirs:create', 1, {})
call(2, 'loisirs:join', r.session.id)
check(players[1].money == m1 - 50 and players[2].money == m2 - 50, 'droits d\'entrée payés à l\'inscription')
run(1000) ok = exported.AdminAction(1, 'cancel_session', { session = r.session.id })
check(ok and players[1].money == m1 and players[2].money == m2 and LS.Sessions.byInst[1] == nil, 'annulation par le staff : remboursés, piste libérée')
Config.Games.bowling.price = 0

P('\n[Billard]')
players[1].pos = vector3(300, 301.6, 31) players[2].pos = vector3(300.5, 301.6, 31)
r = call(1, 'loisirs:create', 3, {})
call(2, 'loisirs:join', r.session.id)
local sb = LS.Sessions.all[r.session.id]
call(1, 'loisirs:start')
run(1500)
check(sb.state == 'IN_PROGRESS' and sb.turn == 1 and sb.data.game.ballInHand == 'kitchen', 'billard lancé : Alice casse, blanche en main derrière la ligne de tête')
r = call(2, 'loisirs:play', { type = 'shot', seq = sb.seq, angle = 0, power = 1 })
check(r.error, 'tir de Bruno pendant le tour d\'Alice : refusé')
r = call(1, 'loisirs:play', { type = 'shot', seq = sb.seq, angle = 0, power = 1, cx = 0.9, cy = 0 })
check(r.error and r.error:find('Blanche'), 'blanche placée hors de la zone de tête : refusée')
local d = sb.data.dims
r = call(1, 'loisirs:play', { type = 'shot', seq = sb.seq, angle = 0, power = 1, cx = Billiards.HeadX(d) - 0.1, cy = 0.0 })
check(r.ok and sb.data.game.breakDone, 'casse jouée')
r = call(1, 'loisirs:play', { type = 'shot', seq = sb.seq - 1, angle = 0, power = 1 })
check(r.error, 'tir renvoyé deux fois : ignoré')
-- on joue jusqu'à la fin (tirs vers la boule la plus proche)
guard = 0
while sb.state == 'IN_PROGRESS' and guard < 300 do
    guard = guard + 1
    run(30000)
    local who = sb.turn
    if not who then break end
    local g = sb.data.game
    local cue = g.balls[0] or { x = Billiards.HeadX(d) - 0.1, y = 0 }
    local myIdx = sb.data.seat[1] == who and 1 or 2
    local grp = g.groups[myIdx]
    local target, bd
    for n, b in pairs(g.balls) do
        local ok2 = n ~= 0 and (g.open and n ~= 8 or (grp and (Billiards.Group(n) == grp or (Billiards.Remaining(g, grp) == 0 and n == 8))))
        if ok2 then local dd = LU.dist2(cue.x, cue.y, b.x, b.y) if not bd or dd < bd then target, bd = b, dd end end
    end
    target = target or g.balls[8] or { x = 0, y = 0 }
    local payload = { type = 'shot', seq = sb.seq, angle = math.atan(target.y - cue.y, target.x - cue.x), power = 0.55 }
    if g.ballInHand then
        local x, y = Billiards.FreeSpot(d, g.balls, -0.3, 0.2, g.ballInHand == 'kitchen')
        payload.cx, payload.cy = x, y
        payload.angle = math.atan(target.y - y, target.x - x)
    end
    call(who, 'loisirs:play', payload)
end
run(5000)
check(sb.state == 'FINISHED' and sb.results.winner ~= nil, ('partie de billard terminée avec un vainqueur (%d tirs)'):format(sb.data.game.shots))
check(LS.Sessions.byInst[3] == nil, 'table libérée')

P('\n[Golf]')
players[1].pos = vector3(1000, 1000, 51) players[2].pos = vector3(1001, 1000, 51)
r = call(1, 'loisirs:create', 4, { holes = 2 })
call(2, 'loisirs:join', r.session.id)
local sg = LS.Sessions.all[r.session.id]
call(1, 'loisirs:start')
run(1500)
check(sg.state == 'IN_PROGRESS' and sg.turn == 1 and sg.data.hole == 1, 'golf lancé : trou 1, Alice joue en premier')
players[1].pos = vector3(1010, 1000, 51)
r = call(1, 'loisirs:play', { type = 'swing', seq = sg.seq, club = 'iron7', power = 0.8, dir = 0 })
check(r.error and r.error:find('balle'), 'coup loin de sa balle : refusé')
r = call(1, 'loisirs:play', { type = 'swing', seq = sg.seq, club = 'bazooka', power = 0.8, dir = 0 })
check(r.error, 'club inconnu : refusé')
local function golfTurn(power, club, dir)
    local who = sg.turn
    local b = sg.data.players[who].ball
    players[who].pos = vector3(b.x + 0.5, b.y, b.z + 1.0)
    local h = sg.data.holes[sg.data.hole]
    local ang = dir or math.deg(math.atan(-(h.flag.x - b.x), h.flag.y - b.y))
    local dist = Golf.DistToFlag(h, b.x, b.y)
    if not club then
        if b.lie == 'green' then club, power = 'putter', math.min(1, math.sqrt(2 * 0.75 * dist) / Config.Golf.clubs[9].speed)
        elseif dist > 120 then club, power = 'iron7', 0.9 elseif dist > 60 then club, power = 'pw', 0.75 else club, power = 'sw', math.max(0.3, dist / 90) end
    end
    return call(who, 'loisirs:play', { type = 'swing', seq = sg.seq, club = club, power = power, dir = ang, spin = 0 }), who
end
r = golfTurn(0.8, 'iron7')
check(r.ok and sg.turn == 2, 'coup d\'Alice joué, au tour de Bruno (départ)')
local tee2 = golfTurn(0.8, 'iron7')
local s1st = sg.data.players[1].strokes[1]
check(s1st == 1, '1 coup compté pour Alice')
-- ordre : la balle la plus loin du trou joue
local d1 = Golf.DistToFlag(sg.data.holes[1], sg.data.players[1].ball.x, sg.data.players[1].ball.y)
local d2 = Golf.DistToFlag(sg.data.holes[1], sg.data.players[2].ball.x, sg.data.players[2].ball.y)
check(sg.turn == (d1 >= d2 and 1 or 2) or sg.data.players[d1 >= d2 and 1 or 2].done, 'après les départs : la balle la plus éloignée joue')
guard = 0
while sg.state == 'IN_PROGRESS' and sg.data.hole == 1 and guard < 40 do guard = guard + 1 run(35000) golfTurn() end
check(sg.data.hole == 2, ('trou 1 terminé (Alice %d, Bruno %d) : passage au trou 2'):format(sg.data.players[1].strokes[1] or 0, sg.data.players[2].strokes[1] or 0))
-- trou 2 : un coup dans l'eau
run(35000)
local who = sg.turn
local before2 = sg.data.players[who].strokes[2] or 0
local wr = golfTurn(0.55, 'iron5')
local pen = sg.data.players[who].penalties
check(wr.ok and (sg.data.players[who].strokes[2] - before2 == 1 or pen >= 1), 'coup au trou 2 joué (pénalité appliquée si la balle est dans l\'eau)')
-- déconnexion de Bruno pendant le trou
run(35000)
players[2].gone = true
source = 2 TriggerEvent('playerDropped')
run(3000)
check(sg.players[2].status == 'left', 'déconnexion pendant un trou : Bruno retiré, la partie continue')
guard = 0
while sg.state == 'IN_PROGRESS' and guard < 40 do guard = guard + 1 run(35000) if sg.turn then golfTurn() end end
run(3000)
check(sg.state == 'FINISHED' and sg.results.ranking[1].id == 1 and sg.results.ranking[2].left, 'golf terminé : Alice classée, Bruno marqué abandon')
check(sg.results.ranking[1].total >= 2 and sg.results.parTotal == 3 + Config.Golf.defaultPar, ('carte finale : %d coups, par %d'):format(sg.results.ranking[1].total, sg.results.parTotal))

P('\n[Redémarrage de la ressource]')
local instBefore = 0 for _ in pairs(LS.inst) do instBefore = instBefore + 1 end
boot()
local instAfter = 0 for _ in pairs(LS.inst) do instAfter = instAfter + 1 end
check(instAfter == instBefore and next(LS.Sessions.all) == nil, ('redémarrage : %d installations rechargées, aucune partie fantôme'):format(instAfter))

P(('\nRésultat : %d réussis, %d échecs'):format(passes, fails))
return fails
