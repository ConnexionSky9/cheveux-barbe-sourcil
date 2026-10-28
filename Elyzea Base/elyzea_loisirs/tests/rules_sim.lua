-- =====================================================================
--  Tests hors jeu : règles et physique (fichiers partagés réels)
--  Lancement : python3 tests/run_tests.py   (depuis elyzea_loisirs/)
-- =====================================================================
local root = ...
assert(loadfile(root .. '/tests/env.lua'))(root)
local passes, fails = 0, 0
local function check(c, label)
    if c then passes = passes + 1 print('  ok   ' .. label) else fails = fails + 1 print('  ÉCHEC ' .. label) end
end
local function rep(v, n) local t = {} for i = 1, n do t[i] = v end return t end
local function concat(...) local t = {} for _, a in ipairs({ ... }) do for _, v in ipairs(a) do t[#t + 1] = v end end return t end

print('[Bowling : score]')
local _, total = Bowling.Score(rep(10, 12))
check(total == 300, 'partie parfaite (12 strikes) = 300')
_, total = Bowling.Score(rep(5, 21))
check(total == 150, 'que des spares 5/5 + 5 = 150')
_, total = Bowling.Score(concat(rep(9, 1), { 0 }, rep(0, 18)))
check(total == 9, 'frame ouverte 9-0 puis rien = 9')
local r = concat({ 10, 10, 10 }, rep(0, 14))
local cum
cum, total = Bowling.Score(r)
check(total == 60 and cum[1] == 30 and cum[2] == 50 and cum[3] == 60, ('3 strikes consécutifs : 30, 50, 60 (obtenu %s)'):format(total))
_, total = Bowling.Score(concat({ 7, 3, 4, 0 }, rep(0, 16)))
check(total == 18, 'spare 7/3 puis 4 : 14 + 4 = 18')
cum, total = Bowling.Score({ 10, 7 })
check(cum[1] == nil and total == 0, 'strike dont le bonus n\'est pas encore connu : pas de score affiché')
_, total = Bowling.Score(concat(rep(0, 18), { 10, 10, 10 }))
check(total == 30, '10e frame : 3 strikes = 30')
_, total = Bowling.Score(concat(rep(0, 18), { 6, 4, 7 }))
check(total == 17, '10e frame : spare + lancer bonus = 17')
_, total = Bowling.Score(concat(rep(0, 18), { 6, 3 }))
check(total == 9, '10e frame ouverte : 2 lancers seulement')
local f, roll, standing, done = Bowling.Position(concat(rep(0, 18), { 10, 4 }))
check(f == 10 and roll == 3 and standing == 6 and not done, '10e frame strike + 4 : 3e lancer sur 6 quilles')
f, roll, standing, done = Bowling.Position(concat(rep(0, 18), { 6, 3 }))
check(done, '10e frame ouverte : partie terminée')
f, roll, standing = Bowling.Position({ 7 })
check(f == 1 and roll == 2 and standing == 3, 'après 7 quilles : 2e lancer sur 3 quilles')
local s, sp = Bowling.Stats(concat(rep(10, 9), { 10, 10, 10 }))
check(s == 12 and sp == 0, 'statistiques : 12 strikes')
s, sp = Bowling.Stats(rep(5, 21))
check(s == 0 and sp == 10, 'statistiques : 10 spares')

print('\n[Bowling : physique]')
local all = {} for n = 1, 10 do all[n] = true end
local a = Bowling.Simulate(all, { x = 0.0, angle = 0.0, power = 1.0, hook = 0.0 }, 11)
local b = Bowling.Simulate(all, { x = 0.0, angle = 0.0, power = 1.0, hook = 0.0 }, 11)
check(#a.down == #b.down and #a.ball == #b.ball and a.duration == b.duration, 'déterministe : même lancer + même graine = même résultat')
local g = Bowling.Simulate(all, { x = 0.40, angle = 2.8, power = 0.6, hook = 0.0 }, 3)
check(g.gutter and #g.down == 0, 'lancer vers le bord : gouttière, 0 quille')
local strikes = 0
for seed = 1, 20 do if #Bowling.Simulate(all, { x = -0.40, angle = 1.25, power = 0.85, hook = 0.5 }, seed).down == 10 then strikes = strikes + 1 end end
check(strikes >= 10, ('lancer dans la poche : strike souvent (%d/20)'):format(strikes))
local two = { [7] = true, [10] = true }
local split = Bowling.Simulate(two, { x = 0.0, angle = 0.0, power = 0.8, hook = 0.0 }, 5)
check(#split.down == 0, 'split 7-10 visé au centre : la boule passe entre les deux')
local onlyStanding = true
for _, n in ipairs(Bowling.Simulate(two, { x = -0.40, angle = -0.2, power = 0.8, hook = 0.0 }, 2).down) do if not two[n] then onlyStanding = false end end
check(onlyStanding, '2e lancer : seules les quilles debout peuvent tomber (pas de double comptage)')
check(Bowling.CleanThrow({ x = 5, angle = 0, power = 1, hook = 0 }) == nil and Bowling.CleanThrow({ x = 0, angle = 0, power = 1.5, hook = 0 }) == nil,
    'paramètres de lancer hors bornes refusés')

print('\n[Billard : physique]')
local d = Billiards.Dims('prop_pooltable_02')
local st = Billiards.NewGame(d, 1)
local fx = Billiards.FootSpot(d)
local cue = st.balls[0]
local res = Billiards.Simulate(d, st.balls, math.atan(-cue.y, fx - cue.x), 1.0, 4)
local res2 = Billiards.Simulate(d, st.balls, math.atan(-cue.y, fx - cue.x), 1.0, 4)
check(res.firstHit == 1, 'casse : la blanche touche d\'abord la n°1')
check(#res.frames == #res2.frames and res.duration == res2.duration, 'simulation déterministe (mêmes images pour tous les clients)')
local overlap = false
for n1, p in pairs(res.final) do for n2, q in pairs(res.final) do
    if n1 < n2 and LU.dist2(p.x, p.y, q.x, q.y) < 2 * Config.Billiards.ballRadius - 0.002 then overlap = true end end end
check(not overlap, 'aucune boule ne se chevauche à la fin du coup')
local inside = true
for _, p in pairs(res.final) do if math.abs(p.x) > d.L / 2 or math.abs(p.y) > d.W / 2 then inside = false end end
check(inside, 'toutes les boules restantes sont sur la table')
local miss = Billiards.Simulate(d, { [0] = { x = -0.5, y = 0.3 }, [4] = { x = 0.5, y = -0.3 } }, 0.0, 0.3, 1)
check(miss.firstHit == nil and #miss.pocketed == 0, 'tir à côté : aucune boule touchée, aucune empochée')
local pot = Billiards.Simulate(d, { [0] = { x = 0.6, y = 0.25 }, [3] = { x = 0.85, y = 0.40 } }, math.atan(0.15, 0.25), 0.4, 1)
check(pot.firstHit == 3 and pot.pocketed[1] and pot.pocketed[1][1] == 3, 'empochée de la n°3 dans la poche de coin')
local multi = Billiards.Simulate(d, { [0] = { x = -0.6, y = 0.0 }, [2] = { x = 0.0, y = 0.0 }, [3] = { x = 0.06, y = 0.0 }, [4] = { x = 0.12, y = 0.0 } }, 0.0, 0.7, 2)
check(multi.firstHit == 2 and multi.final[4] and multi.final[4].x > 0.15, 'chocs en chaîne : l\'énergie passe à la dernière boule')
check(multi.duration < Config.Billiards.maxTime, 'toutes les boules s\'arrêtent avant la limite de temps')

print('\n[Billard : règles 8-ball]')
local function game(balls, groups, turn, breakDone)
    return { balls = balls, groups = groups or {}, open = groups == nil, breakDone = breakDone ~= false, turn = turn or 1,
        pocketed = { [1] = {}, [2] = {} }, shots = 0 }
end
local function fake(opts)
    return { firstHit = opts.first, railAfterHit = opts.rail or false, pocketed = opts.pocketed or {}, offTable = opts.off or {},
        railBalls = opts.railBalls or {}, final = opts.final }
end
-- casse réglementaire avec une boule empochée : table ouverte, on garde la main
st = game(Billiards.Rack(d), nil, 1, false)
local final = LU.copy(st.balls) final[5] = nil
local rp = Billiards.Apply(d, st, fake({ first = 1, pocketed = { { 5, 1.0 } }, railBalls = { [2] = true }, final = final }))
check(not rp.foul and rp.keep and st.open and st.turn == 1, 'casse avec empochée : table ouverte, le joueur garde la main')
-- casse sans empochée et < 4 bandes : faute
st = game(Billiards.Rack(d), nil, 1, false)
rp = Billiards.Apply(d, st, fake({ first = 1, railBalls = { [2] = true }, final = LU.copy(st.balls) }))
check(rp.foul and st.turn == 2 and st.ballInHand, 'casse non réglementaire : faute, main à l\'adversaire, blanche en main')
-- attribution du groupe
st = game({ [0] = { x = 0, y = 0 }, [3] = { x = 0.3, y = 0 }, [11] = { x = 0.5, y = 0.2 }, [8] = { x = -0.5, y = 0.2 } }, nil, 1)
rp = Billiards.Apply(d, st, fake({ first = 3, pocketed = { { 3, 1 } }, final = { [0] = { x = 0, y = 0 }, [11] = { x = 0.5, y = 0.2 }, [8] = { x = -0.5, y = 0.2 } } }))
check(rp.assigned == 'solids' and st.groups[1] == 'solids' and st.groups[2] == 'stripes' and rp.keep, 'table ouverte, pleine empochée : pleines au joueur 1, rayées au joueur 2')
-- empochée de la blanche
st = game({ [0] = { x = 0, y = 0 }, [3] = { x = 0.3, y = 0 }, [8] = { x = -0.5, y = 0.2 } }, { 'solids', 'stripes' }, 1)
rp = Billiards.Apply(d, st, fake({ first = 3, pocketed = { { 0, 1 } }, final = { [3] = { x = 0.3, y = 0 }, [8] = { x = -0.5, y = 0.2 } } }))
check(rp.foul and rp.reason == 'blanche empochée' and st.turn == 2 and st.ballInHand == 'anywhere', 'blanche empochée : faute, blanche en main n\'importe où pour l\'adversaire')
-- mauvaise première boule
st = game({ [0] = { x = 0, y = 0 }, [3] = { x = 0.3, y = 0 }, [12] = { x = 0.4, y = 0 }, [8] = { x = -0.5, y = 0.2 } }, { 'solids', 'stripes' }, 1)
rp = Billiards.Apply(d, st, fake({ first = 12, rail = true, final = LU.copy(st.balls) }))
check(rp.foul and st.turn == 2, 'première boule touchée hors de son groupe : faute')
-- aucune bande après contact
st = game({ [0] = { x = 0, y = 0 }, [3] = { x = 0.3, y = 0 }, [8] = { x = -0.5, y = 0.2 } }, { 'solids', 'stripes' }, 1)
rp = Billiards.Apply(d, st, fake({ first = 3, rail = false, final = LU.copy(st.balls) }))
check(rp.foul and rp.reason == 'aucune bande touchée après le contact', 'aucune boule empochée et aucune bande : faute')
-- coup sans empochée mais légal : main à l'adversaire, pas de faute
st = game({ [0] = { x = 0, y = 0 }, [3] = { x = 0.3, y = 0 }, [8] = { x = -0.5, y = 0.2 } }, { 'solids', 'stripes' }, 1)
rp = Billiards.Apply(d, st, fake({ first = 3, rail = true, final = LU.copy(st.balls) }))
check(not rp.foul and not rp.keep and st.turn == 2 and not st.ballInHand, 'coup légal sans empochée : simple changement de joueur')
-- victoire légale à la noire
st = game({ [0] = { x = 0, y = 0 }, [8] = { x = 0.3, y = 0 }, [12] = { x = -0.5, y = 0.2 } }, { 'solids', 'stripes' }, 1)
rp = Billiards.Apply(d, st, fake({ first = 8, pocketed = { { 8, 1 } }, final = { [0] = { x = 0.1, y = 0 }, [12] = { x = -0.5, y = 0.2 } } }))
check(rp.win and st.winner == 1, 'groupe terminé puis noire empochée : victoire')
-- noire empochée trop tôt
st = game({ [0] = { x = 0, y = 0 }, [8] = { x = 0.3, y = 0 }, [2] = { x = 0.2, y = 0.2 }, [12] = { x = -0.5, y = 0.2 } }, { 'solids', 'stripes' }, 1)
rp = Billiards.Apply(d, st, fake({ first = 2, pocketed = { { 8, 1 } }, final = { [0] = { x = 0.1, y = 0 }, [2] = { x = 0.2, y = 0.2 }, [12] = { x = -0.5, y = 0.2 } } }))
check(rp.lose and st.winner == 2, 'noire empochée avant la fin du groupe : défaite')
-- noire + blanche sur le dernier coup
st = game({ [0] = { x = 0, y = 0 }, [8] = { x = 0.3, y = 0 }, [12] = { x = -0.5, y = 0.2 } }, { 'solids', 'stripes' }, 1)
rp = Billiards.Apply(d, st, fake({ first = 8, pocketed = { { 8, 1 }, { 0, 2 } }, final = { [12] = { x = -0.5, y = 0.2 } } }))
check(rp.lose and st.winner == 2, 'noire empochée avec la blanche : défaite')
-- noire empochée à la casse : on recommence
st = game(Billiards.Rack(d), nil, 1, false)
final = LU.copy(st.balls) final[8] = nil
rp = Billiards.Apply(d, st, fake({ first = 1, pocketed = { { 8, 1 } }, final = final }))
check(rp.rerack and st.balls[8] and not st.breakDone and st.turn == 1, 'noire à la casse : triangle reformé, même joueur recasse')
-- placement de la blanche
check(Billiards.ValidPlacement(d, { [3] = { x = 0, y = 0 } }, 0.3, 0.1, false) and not Billiards.ValidPlacement(d, { [3] = { x = 0, y = 0 } }, 0.01, 0.0, false)
    and not Billiards.ValidPlacement(d, {}, 0.3, 0.0, true), 'blanche en main : sur une autre boule ou hors zone de tête refusée')

print('\n[Golf]')
local hole = { tee = { x = 0, y = 0, z = 50, h = 0 }, flag = { x = 0, y = 380, z = 50 }, par = 4, hazards = {} }
local drive = Golf.Simulate(hole, { x = 0, y = 0, lie = 'tee' }, { club = 'driver', power = 0.95, dir = 0, spin = 0 }, 1)
check(drive.distance > 200 and drive.distance < 290 and drive.outcome == 'rest', ('drive : %.0f m (200-290 attendu)'):format(drive.distance))
local wedge = Golf.Simulate(hole, { x = 0, y = 0, lie = 'fairway' }, { club = 'sw', power = 0.95, dir = 0, spin = 0 }, 1)
check(wedge.distance < drive.distance * 0.5, 'le club change la distance (sand wedge bien plus court que le driver)')
local rough = Golf.Simulate(hole, { x = 0, y = 0, lie = 'rough' }, { club = 'iron7', power = 0.9, dir = 0, spin = 0 }, 1)
local fair = Golf.Simulate(hole, { x = 0, y = 0, lie = 'fairway' }, { club = 'iron7', power = 0.9, dir = 0, spin = 0 }, 1)
check(rough.distance < fair.distance, 'depuis le rough, la balle va moins loin')
local d1 = Golf.Simulate(hole, { x = 0, y = 0, lie = 'tee' }, { club = 'driver', power = 0.9, dir = 0, spin = 1 }, 1)
local d2 = Golf.Simulate(hole, { x = 0, y = 0, lie = 'tee' }, { club = 'driver', power = 0.9, dir = 0, spin = -1 }, 1)
check((d1.x - d2.x) * (d1.x > d2.x and 1 or -1) > 10, 'l\'effet courbe la trajectoire (draw / fade)')
local green = { tee = { x = 0, y = 0, z = 50, h = 0 }, flag = { x = 0, y = 3, z = 50 }, par = 3, greenR = 14, hazards = {} }
local putt = Golf.Simulate(green, { x = 0, y = 0, lie = 'green' }, { club = 'putter', power = 0.25, dir = 0, spin = 0 }, 3)
check(putt.outcome == 'holed', 'putt de 3 m bien dosé : dans le trou')
local short = Golf.Simulate(green, { x = 0, y = 0, lie = 'green' }, { club = 'putter', power = 0.10, dir = 0, spin = 0 }, 3)
check(short.outcome == 'rest' and Golf.DistToFlag(green, short.x, short.y) > 1, 'putt trop court : la balle s\'arrête avant le trou')
local strong = Golf.Simulate(green, { x = 0, y = 0, lie = 'green' }, { club = 'putter', power = 0.6, dir = 0, spin = 0 }, 3)
check(strong.outcome == 'rest', 'putt trop fort : la balle passe sur le trou sans tomber')
local wet = { tee = { x = 0, y = 0, z = 50, h = 0 }, flag = { x = 0, y = 380, z = 50 }, par = 4,
    hazards = { { type = 'water', x = 0, y = 200, r = 60 } } }
local w = Golf.Simulate(wet, { x = 0, y = 0, lie = 'tee' }, { club = 'driver', power = 0.95, dir = 0, spin = 0 }, 1)
check(w.outcome == 'water' and w.entry, 'balle dans l\'eau détectée (point d\'entrée connu)')
local dx, dy = Golf.WaterDrop(wet, w.entry, { x = 0, y = 0 })
check(Golf.Lie(wet, dx, dy) ~= 'water' and dy < w.entry.y, 'replacement après l\'eau : hors de l\'eau, en arrière du point d\'entrée')
local ob = Golf.Simulate(hole, { x = 0, y = 0, lie = 'tee' }, { club = 'driver', power = 0.95, dir = 90, spin = 0 }, 1)
check(ob.outcome == 'ob', 'coup à 90° du trou : hors limites')
local lost = { tee = { x = 0, y = 0, z = 50, h = 0 }, flag = { x = 0, y = 380, z = 50 }, par = 4, hazards = { { type = 'lost', x = 0, y = 230, r = 50 } } }
check(Golf.Simulate(lost, { x = 0, y = 0, lie = 'tee' }, { club = 'driver', power = 0.95, dir = 0, spin = 0 }, 1).outcome == 'lost', 'balle dans une zone de balle perdue')
local bunk = { tee = { x = 0, y = 0, z = 50, h = 0 }, flag = { x = 0, y = 380, z = 50 }, par = 4, hazards = { { type = 'bunker', x = 0, y = 190, r = 40 } } }
local bk = Golf.Simulate(bunk, { x = 0, y = 0, lie = 'tee' }, { club = 'driver', power = 0.95, dir = 0, spin = 0 }, 1)
check(bk.lie == 'bunker', 'balle qui s\'arrête dans le bunker (freinage fort)')
local ux, uy = Golf.UnplayableDrop(hole, { x = 0, y = 200 })
check(Golf.DistToFlag(hole, ux, uy) > Golf.DistToFlag(hole, 0, 200), 'balle injouable : replacée plus loin du trou, jamais plus près')
check(Golf.CleanSwing({ club = 'driver', power = 3, dir = 0 }) == nil and Golf.CleanSwing({ club = 'bazooka', power = 1, dir = 0 }) == nil,
    'coup hors bornes ou club inconnu refusé')
local hill = { tee = { x = 0, y = 0, z = 50, h = 0 }, flag = { x = 0, y = 300, z = 65 }, par = 4, hazards = {} }
local uphill = Golf.Simulate(hill, { x = 0, y = 100, lie = 'fairway' }, { club = 'putter', power = 0.5, dir = 0, spin = 0 }, 3)
local downhill = Golf.Simulate(hill, { x = 0, y = 100, lie = 'fairway' }, { club = 'putter', power = 0.5, dir = 180, spin = 0 }, 3)
check(uphill.distance < downhill.distance, ('pente : la balle roule moins loin en montée (%.1f m) qu\'en descente (%.1f m)'):format(uphill.distance, downhill.distance))
check(downhill.outcome == 'rest' and downhill.duration < Config.Golf.maxTime, 'en descente, la balle finit par s\'arrêter')
local onG = Golf.Simulate(hill, { x = 0, y = 296, lie = 'green' }, { club = 'putter', power = 0.06, dir = 0, spin = 0 }, 3)
check(onG.outcome == 'rest' and onG.distance < 3, 'le green est plat : un putt doux ne redescend pas la pente du trou')

print('[Chocs pour les sons]')
do
    local function kinds(h) local k = {} for _, e in ipairs(h or {}) do k[e[2]] = (k[e[2]] or 0) + 1 end return k end
    local bd = Billiards.Dims('prop_pooltable_02')
    local rack = Billiards.Rack(bd)
    local bb = {} for n, b in pairs(rack) do bb[n] = { x = b.x, y = b.y } end
    bb[0] = { x = Billiards.HeadX(bd) - 0.10, y = 0.0 }
    local brk = Billiards.Simulate(bd, bb, 0.0, 1.0, 7)
    local k = kinds(brk.hits)
    check(k.cue == 1 and (k.ball or 0) >= 5 and (k.rail or 0) >= 4, ('casse : coup de queue, %d chocs de boules, %d chocs de bande'):format(k.ball or 0, k.rail or 0))
    local sorted = true for i = 2, #brk.hits do if brk.hits[i][1] < brk.hits[i - 1][1] then sorted = false end end
    check(sorted and #brk.hits <= 160, 'chocs dans l\'ordre du temps et en nombre limité')
    local full = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
    local st = Bowling.Simulate(full, { x = -0.40, angle = 1.25, power = 0.85, hook = 0.5 }, 2)
    local kb = kinds(st.hits)
    check((kb.pin or 0) >= 1 and (kb.pinpin or 0) >= 3, ('bowling : %d choc(s) boule-quille, %d quille-quille'):format(kb.pin or 0, kb.pinpin or 0))
    local gt = Bowling.Simulate(full, { x = 0.42, angle = -3.0, power = 0.5, hook = 1.0 }, 5)
    check(not gt.gutter or kinds(gt.hits).gutter == 1, 'gouttière : un seul son de gouttière')
    local hole = { tee = { x = 0, y = 0, z = 50, h = 0 }, flag = { x = 0, y = 140, z = 50 }, par = 3, greenR = 14, fairwayW = 40, hazards = {} }
    local putt = Golf.Simulate(hole, { x = 0, y = 137, z = 50, lie = 'green' }, Golf.CleanSwing({ type = 'swing', club = 'putter', power = 0.25, dir = 0, spin = 0 }), 1)
    check(putt.outcome == 'holed' and putt.hits[#putt.hits][2] == 'cup', 'golf : putt rentré → son de la balle dans le trou')
    local drive = Golf.Simulate(hole, { x = 0, y = 0, z = 50, lie = 'tee' }, Golf.CleanSwing({ type = 'swing', club = 'iron9', power = 0.9, dir = 0, spin = 0 }), 4)
    check(kinds(drive.hits).land and kinds(drive.hits).land >= 1, 'golf : rebonds de la balle à l\'atterrissage')
end

print(('\nRésultat : %d réussis, %d échecs'):format(passes, fails))
return fails
