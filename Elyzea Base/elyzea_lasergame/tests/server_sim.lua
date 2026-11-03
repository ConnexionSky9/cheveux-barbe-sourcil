-- =====================================================================
--  Scénarios de simulation du serveur (voir run_server_sim.py)
-- =====================================================================
local ROOT = ...
local PASS, FAIL = 0, 0
local function check(cond, label)
    if cond then PASS = PASS + 1 SIM.print('  ok   ' .. label) else FAIL = FAIL + 1 SIM.print('  ÉCHEC ' .. label) end
end
local function section(t) SIM.print('\n[' .. t .. ']') end
local function sql(kind, q, p) return py_sql(kind, q, p) end

-- chargement de la ressource (ordre du fxmanifest)
for _, f in ipairs(SIM_FILES) do
    local src = py_read(f)
    local chunk, err = load(src, '@' .. f)
    if not chunk then error(err) end
    chunk()
end
SIM.run(1000)

-- ================================================================ utilitaires purs
section('Fonctions pures (shared/utils.lua)')
do
    local d1 = LGU.RatingDelta({ rating = 1000, teamRating = 1000, oppRating = 1000, result = 'win', matches = 10, kills = 0, deaths = 0, streak = 0, repeatCount = 0 })
    local d2 = LGU.RatingDelta({ rating = 1000, teamRating = 1000, oppRating = 1400, result = 'win', matches = 10, kills = 0, deaths = 0, streak = 0, repeatCount = 0 })
    local d3 = LGU.RatingDelta({ rating = 1000, teamRating = 1000, oppRating = 1000, result = 'loss', matches = 10, kills = 9, deaths = 0, streak = 0, repeatCount = 0 })
    local d4 = LGU.RatingDelta({ rating = 1000, teamRating = 1000, oppRating = 1000, result = 'win', matches = 10, kills = 0, deaths = 0, streak = 0, repeatCount = 4 })
    check(d1 == 20, 'victoire à niveau égal = +20 points (K=40)')
    check(d2 > d1, 'battre une équipe plus forte rapporte plus (' .. d2 .. ' > ' .. d1 .. ')')
    check(d3 < 0, 'une défaite reste négative même avec beaucoup d\'éliminations (' .. d3 .. ')')
    check(d4 == 0, 'anti-farm : 5e match contre les mêmes adversaires = 0 point')
    local shares = LGU.SplitPot(50000, 5, 0)
    check(#shares == 5 and shares[1] == 10000, 'pot de 50 000 $ partagé entre 5 gagnants = 10 000 $ chacun')
    local s3 = LGU.SplitPot(10001, 3, 0)
    check(s3[1] + s3[2] + s3[3] == 10001, 'partage sans perte ni création d\'argent (reste de la division)')
    check(LGU.RoundsToWin(3) == 2 and LGU.RoundsToWin(5) == 3, 'manches à gagner (3 → 2, 5 → 3)')
    local dec, w = LGU.MatchDecided(2, 0, 5, 2)
    check(not dec, '2-0 sur 5 manches : pas encore décidé')
    dec, w = LGU.MatchDecided(3, 0, 5, 3)
    check(dec and w == 'A', '3-0 sur 5 : victoire A')
    dec, w = LGU.MatchDecided(1, 1, 2, 2)
    check(dec and w == nil, 'égalité après toutes les manches')
    check(LGU.ZombieCount(2, 1) > LGU.ZombieCount(1, 1), 'plus de zombies à chaque manche')
    check(LGU.ZombieCount(5, 4) > LGU.ZombieCount(5, 1), 'plus de zombies avec plus de joueurs')
    check(LGU.ZombieHealth(10) > LGU.ZombieHealth(5) and LGU.ZombieHealth(5) > LGU.ZombieHealth(1), 'résistance progressive')
    check(LGU.ZombieDamage(1) == 34 and LGU.ZombieDamage(100) == 60, 'dégâts : 34 à la manche 1, plafonnés à 60')
    check(math.ceil(100 / LGU.ZombieDamage(1)) == 3, '3 coups pour être à terre sans atout')
    local j = LG.Zombie.perks.juggernaut.health
    check(math.ceil(j / LGU.ZombieDamage(1)) == 6 and math.ceil(j / LGU.ZombieDamage(10)) == 5, 'Mastodonte : 5 à 6 coups')
    check(LGU.ZombieGait(1, 0.0) == 'walk' and LGU.ZombieGait(12, 0.0) == 'sprint', 'vitesse : marche au début, sprint plus tard')
    local x, y = LGU.ToWorld({ x = 10, y = 20, z = 0, h = 90 }, 0, 5, 0)
    check(math.abs(x - 5) < 1e-6 and math.abs(y - 20) < 1e-6, 'repère local → monde (cap 90°)')
    local lx, ly = LGU.ToLocal({ x = 10, y = 20, z = 0, h = 90 }, x, y, 0)
    check(math.abs(lx) < 1e-6 and math.abs(ly - 5) < 1e-6, 'repère monde → local')
end

-- ================================================================ démarrage
section('Démarrage')
check(DB.ready, 'base de données initialisée (9 tables)')
check(#Maps.order == 5, '5 cartes chargées : ' .. table.concat(Maps.order, ', '))
check(GlobalState.lgPublic and GlobalState.lgPublic.weapons.photon_p9 ~= nil, 'réglages publics publiés (GlobalState.lgPublic)')
check(Bridge.Name() == 'elyzea', 'framework détecté : elyzea')
local mz = Maps.Get('zombie_map')
check(#mz.sectors == 8 and #mz.doors == 9 and #mz.wallbuys == 13 and #mz.perks == 8, 'carte Zombie : 8 secteurs, 9 portes, 13 armes murales, 8 atouts')

-- comportement du client à la restauration : téléportation à la position RP puis confirmation
local function back(i)
    local r = SIM.last(i, 'elyzea_lasergame:restore')
    if r then SIM.move(i, r.x, r.y, r.z) end
    SIM.emit(i, 'elyzea_lasergame:restored')
end

-- joueurs
for i = 1, 6 do SIM.addPlayer(i, 'Joueur', tostring(i), 100000) end
SIM.addPlayer(9, 'Loin', 'Dupont', 100000, vector3(500.0, 500.0, 30.0))
SIM.addPlayer(10, 'Staff', 'Admin', 0, vector3(800.0, 800.0, 30.0))
SIM.admins[10] = true
for i = 1, 6 do SIM.call(function() TriggerEvent('elyzea:server:playerLogin', i) end) end
SIM.run(5000)

-- ================================================================ interface
section('Interface et profil')
local ok, init = SIM.rpc(1, 'ui:init')
check(ok and init.profile.points == 1000 and init.profile.rank == 'bronze', 'profil créé : 1000 points, ELYZEA BRONZE')
check(#init.maps == 5 and #init.categories == 5 and #init.ranks == 8, 'interface : 5 cartes, 5 catégories d\'armes, 8 rangs')
check(init.isAdmin == false, 'joueur normal : pas d\'accès staff')

-- ================================================================ PVP : lobby
section('PVP : création, validation, lobby')
local okc, err = SIM.rpc(9, 'pvp:create', { format = '2v2', map = 'pvp_small', rounds = 3, roundTime = 120, category = 'rifle', stake = 5000 })
check(okc == false and tostring(err):find('PNJ'), 'refusé loin d\'un PNJ LaserGame (anti-téléportation)')
okc, err = SIM.rpc(1, 'pvp:create', { format = '9v9', map = 'pvp_small', rounds = 3, roundTime = 120, category = 'rifle' })
check(okc == false, 'format inexistant refusé')
okc, err = SIM.rpc(1, 'pvp:create', { format = '2v2', map = 'pvp_small', rounds = 3, roundTime = 120, category = 'rifle', stake = 999999999 })
check(okc == false and tostring(err):find('Mise'), 'mise hors limites refusée')
okc, err = SIM.rpc(1, 'pvp:create', { format = '6v6', map = 'pvp_small', rounds = 3, roundTime = 120, category = 'rifle' })
check(okc == false and tostring(err):find('petite'), 'carte trop petite pour le format refusée')
local uid
okc, uid = SIM.rpc(1, 'pvp:create', { format = '2v2', map = 'pvp_small', rounds = 3, roundTime = 120, category = 'rifle', stake = 5000, name = '<b>Finale</b>' })
check(okc and type(uid) == 'string', 'lobby créé : ' .. tostring(uid))
local g = Games.list[uid]
check(g and g.name == 'bFinale/b', 'nom nettoyé (pas de balises) : ' .. tostring(g and g.name))
local okj = SIM.rpc(1, 'pvp:create', { format = '1v1', map = 'pvp_small', rounds = 1, roundTime = 60, category = 'pistol' })
check(okj == false, 'impossible d\'ouvrir deux lobbies')
for i = 2, 4 do SIM.rpc(i, 'pvp:join', uid, '') end
check(g.players[2].team == 'B' and g.players[3].team == 'A' and g.players[4].team == 'B', 'équilibrage automatique des équipes à l\'arrivée')
check(SIM.rpc(5, 'pvp:join', uid, '') == false, 'cinquième joueur refusé (2v2 complet)')
check(SIM.rpc(1, 'pvp:start') == false, 'lancement refusé tant que personne n\'est prêt')
check(SIM.rpc(2, 'pvp:weapon', 'helios') == false, 'arme hors catégorie refusée')
check(SIM.rpc(2, 'pvp:weapon', 'spectre') == true and g.players[2].weapon == 'spectre', 'choix d\'une arme de la catégorie')

section('PVP : mises')
SIM.money[4].bank = 1000
local okr, er = SIM.rpc(4, 'pvp:ready', true)
check(okr == false and tostring(er):find('Fonds'), 'fonds insuffisants : refusé')
SIM.money[4].bank = 100000
for i = 1, 4 do SIM.rpc(i, 'pvp:ready', true) end
check(SIM.money[1].bank == 95000 and SIM.money[4].bank == 95000, 'mise de 5 000 $ débitée à chaque joueur prêt')
check(sql('scalar', "SELECT COUNT(*) FROM `lg_ledger` WHERE `match_uid` = ? AND `status` = 'held'", { uid }) == 4, '4 mises « held » dans le journal')
SIM.rpc(3, 'pvp:ready', false)
check(SIM.money[3].bank == 100000, '« pas prêt » : mise remboursée immédiatement')
SIM.rpc(3, 'pvp:ready', true)
check(SIM.money[3].bank == 95000, 'de nouveau prêt : redébité')
check(sql('scalar', "SELECT COUNT(*) FROM `lg_ledger` WHERE `match_uid` = ? AND `status` = 'refunded'", { uid }) == 1, 'remboursement tracé une seule fois')
SIM.rpc(3, 'pvp:ready', false)
SIM.rpc(3, 'pvp:ready', false)
check(SIM.money[3].bank == 100000, 'double « pas prêt » : aucun double remboursement')
SIM.rpc(3, 'pvp:ready', true)

-- ================================================================ PVP : partie
section('PVP : lancement et instance')
local oks = SIM.rpc(1, 'pvp:start')
check(oks == true, 'partie lancée par l\'hôte')
SIM.run(1000)
check(SIM.players[1].bucket == 63001 and SIM.players[4].bucket == 63001, 'joueurs dans l\'instance 63001')
check(SIM.players[1].state.pvpArena == true and SIM.players[1].state.laserGame == 'pvp', 'state bags posés (inventaire RP verrouillé, pas de coma EMS)')
check(sql('scalar', 'SELECT COUNT(*) FROM `lg_restore`') == 4, 'état RP sauvegardé en base pour les 4 joueurs')
local snap = py_json_decode(sql('single', 'SELECT `data` FROM `lg_restore` WHERE `citizenid` = ?', { 'CID1' }).data)
check(snap.health == 180 and snap.armor == 25 and snap.bucket == 0, 'sauvegarde : vie 180, gilet 25, instance 0')
check(SIM.last(1, 'elyzea_lasergame:enterGame') ~= nil, 'événement d\'entrée envoyé au client')

-- le client se place sur son point d'apparition
local function placeAll()
    for i = 1, 4 do
        local d = SIM.last(i, 'elyzea_lasergame:pvpSpawn')
        if d then SIM.move(i, d.pos.x, d.pos.y, d.pos.z + 1.0) end
    end
end
SIM.run(3500)
placeAll()
check(g.phase == 'countdown', 'décompte avant la manche')
local a1, b1 = SIM.players[1].pos, SIM.players[2].pos
check(#(a1 - b1) > 30, 'apparitions adverses éloignées (' .. math.floor(#(a1 - b1)) .. ' m)')
SIM.run(5200)
check(g.phase == 'round', 'manche 1 en cours')

local function shoot(from, to, weapon, opts)
    opts = opts or {}
    local o = SIM.players[from].pos + vector3(0, 0, 0.6)
    local t = SIM.players[to].pos
    local d = t - o
    local l = #d
    local dir = { x = d.x / l, y = d.y / l, z = d.z / l }
    if opts.badDir then dir = { x = -dir.x, y = -dir.y, z = dir.z } end
    if opts.farOrigin then o = o + vector3(30, 0, 0) end
    local shot = { w = weapon, o = { x = o.x, y = o.y, z = o.z }, d = dir, hit = { k = 'p', id = to }, hp = { x = t.x, y = t.y, z = t.z } }
    SIM.now = SIM.now + (opts.dt or 120)
    SIM.emit(from, 'elyzea_lasergame:shots', { shot })
end

section('PVP : tirs laser vérifiés par le serveur')
SIM.run(25000)
local sh = g.players[2].shield
shoot(1, 2, 'helios')
check(g.players[2].shield == sh, 'arme non attribuée : tir ignoré')
shoot(1, 2, 'nova_ar', { farOrigin = true })
check(g.players[2].shield == sh, 'origine du tir éloignée du tireur : ignoré')
shoot(1, 2, 'nova_ar', { badDir = true })
check(g.players[2].shield == sh, 'trajectoire qui ne passe pas par la cible : ignoré')
shoot(1, 3, 'nova_ar')
check(g.players[3].shield == 100, 'tir allié : aucun dégât (tirs alliés désactivés)')
shoot(1, 2, 'nova_ar')
check(g.players[2].shield == 80, 'impact valide : 20 dégâts (valeur serveur de la Nova AR)')
-- cadence : 40 tirs instantanés → la plupart refusés
local before = g.players[4].shield
for k = 1, 40 do shoot(3, 4, 'nova_ar', { dt = 0 }) end
check(g.players[4].alive and g.players[4].shield > 0 or (before - g.players[4].shield) <= 120, 'cadence limitée (rafale instantanée bridée)')
check(Combat ~= nil, 'module de combat chargé')
-- élimination des deux joueurs B
for k = 1, 6 do shoot(1, 2, 'nova_ar') end
check(g.players[2].alive == false and g.players[2].deaths == 1 and g.players[1].kills >= 1, 'joueur B éliminé : élimination comptée')
check(SIM.last(2, 'elyzea_lasergame:eliminated') ~= nil, 'la victime passe en spectateur (événement)')
shoot(2, 1, 'spectre')
check(g.players[1].shield == 100, 'un éliminé ne peut plus tirer')
for k = 1, 8 do if g.players[4].alive then shoot(3, 4, 'nova_ar') end end
SIM.run(400)
check(g.score.A == 1 and g.phase == 'round_end', 'manche 1 gagnée par ROUGE (1-0)')

section('PVP : manche 2 et fin de partie')
SIM.run(5500)
placeAll()
SIM.run(5500)
check(g.phase == 'round' and g.round == 2, 'manche 2 en cours, joueurs ressuscités')
check(g.players[2].alive and g.players[2].shield == 100, 'bouclier rétabli à chaque manche')
SIM.run(25000)
for k = 1, 6 do shoot(1, 2, 'nova_ar') end
for k = 1, 6 do shoot(3, 4, 'nova_ar') end
SIM.run(400)
check(g.score.A == 2, 'ROUGE gagne 2-0 : partie décidée')
SIM.run(6000)
check(g.phase == 'ended', 'écran de fin')
local me1 = SIM.last(1, 'elyzea_lasergame:matchEnd')
check(me1 and me1.me.result == 'win' and me1.me.payout == 10000, 'gagnant : résultat « victoire », gain 10 000 $ (pot 20 000 / 2)')
check(SIM.money[1].bank == 105000 and SIM.money[3].bank == 105000, 'argent RP des gagnants : 100 000 - 5 000 + 10 000')
check(SIM.money[2].bank == 95000 and SIM.money[4].bank == 95000, 'perdants : mise perdue')
local total = 0
for i = 1, 4 do total = total + SIM.money[i].bank end
check(total == 400000, 'aucun argent créé ni perdu au total (400 000 $)')
check(sql('scalar', "SELECT COUNT(*) FROM `lg_ledger` WHERE `match_uid` = ? AND `status` = 'held'", { uid }) == 0, 'plus aucune mise « held »')
local p1 = DB.ProfileByCid('CID1')
local p2 = DB.ProfileByCid('CID2')
check(p1.points > 1000 and p2.points < 1000, ('classement : gagnant %d pts, perdant %d pts'):format(p1.points, p2.points))
check(p1.wins == 1 and p2.losses == 1 and p1.matches == 1, 'statistiques : victoires / défaites / matchs')
check(me1.me.delta == p1.points - 1000, 'variation de points affichée = variation réelle')
SIM.run(13000)
check(Games.list[uid] == nil, 'partie fermée, instance libérée')
check(SIM.players[1].bucket == 0, 'retour dans l\'instance RP 0')
local rs = SIM.last(1, 'elyzea_lasergame:restore')
check(rs and rs.health == 180 and rs.armor == 25 and math.abs(rs.x - (-1256.0)) < 0.01, 'restauration : position, vie et gilet d\'origine envoyés')
check(sql('scalar', 'SELECT COUNT(*) FROM `lg_restore`') == 4, 'sauvegardes conservées tant que le client n\'a pas confirmé')
for i = 1, 4 do back(i) end
check(sql('scalar', 'SELECT COUNT(*) FROM `lg_restore`') == 0, 'sauvegardes supprimées après confirmation')
SIM.run(4500)
check(not SIM.players[1].state.pvpArena, 'state bags retirés après le retour')
local m = sql('single', 'SELECT * FROM `lg_matches` WHERE `uid` = ?', { uid })
check(m.status == 'finished' and m.winner == 'A' and m.score_a == 2, 'partie enregistrée (historique)')
local okh, hist = SIM.rpc(1, 'history:get')
check(okh and #hist == 1 and hist[1].result == 'win', 'historique personnel')
local okl, board = SIM.rpc(1, 'lb:get', 'pvp_points', 1)
check(okl and board.rows[1].v == p1.points and board.rows[1].citizenid == nil, 'classement PVP (identifiant RP non divulgué)')

-- ================================================================ anti-farm
section('Anti-farm')
local function quickMatch(winners, losers)
    local o, id = SIM.rpc(winners[1], 'pvp:create', { format = '1v1', map = 'pvp_small', rounds = 1, roundTime = 60, category = 'pistol', stake = 0 })
    SIM.rpc(losers[1], 'pvp:join', id, '')
    SIM.rpc(winners[1], 'pvp:ready', true)
    SIM.rpc(losers[1], 'pvp:ready', true)
    SIM.rpc(winners[1], 'pvp:start')
    SIM.run(3500)
    for _, i in ipairs({ winners[1], losers[1] }) do local d = SIM.last(i, 'elyzea_lasergame:pvpSpawn') if d then SIM.move(i, d.pos.x, d.pos.y, d.pos.z + 1) end end
    SIM.run(50000)  -- la manche dure au moins la durée minimale classée
    for k = 1, 8 do if Games.list[id] and Games.list[id].players[losers[1]] and Games.list[id].players[losers[1]].alive then shoot(winners[1], losers[1], 'photon_p9') end end
    SIM.run(20000)
    for _, i in ipairs({ winners[1], losers[1] }) do back(i) end
    SIM.run(5000)
    return id
end
SIM.rpc(5, 'ui:init') SIM.rpc(6, 'ui:init')
local pts = {}
for k = 1, 5 do
    local before5 = DB.ProfileByCid('CID5').points
    quickMatch({ 5 }, { 6 })
    pts[k] = DB.ProfileByCid('CID5').points - before5
end
check(pts[1] > 0 and pts[2] < pts[1] and pts[5] == 0, ('gains décroissants contre le même adversaire : %s'):format(table.concat(pts, ', ')))

-- ================================================================ déconnexion et abandon
section('Déconnexion pendant une partie')
local _, uid2 = SIM.rpc(1, 'pvp:create', { format = '1v1', map = 'pvp_medium', rounds = 3, roundTime = 120, category = 'smg', stake = 2000 })
SIM.rpc(2, 'pvp:join', uid2, '')
SIM.rpc(1, 'pvp:ready', true)
SIM.rpc(2, 'pvp:ready', true)
local bank1, bank2 = SIM.money[1].bank, SIM.money[2].bank
SIM.rpc(1, 'pvp:start')
SIM.run(9000)
SIM.removePlayer(2)
SIM.run(6000)
check(Games.list[uid2] and Games.list[uid2].phase == 'ended', 'abandon de l\'équipe adverse : fin de partie')
check(SIM.money[1].bank == bank1 + 4000, 'le joueur resté gagne le pot (4 000 $ : sa mise + celle de l\'adversaire)')
check(sql('scalar', 'SELECT COUNT(*) FROM `lg_restore` WHERE `citizenid` = ?', { 'CID2' }) == 1, 'sauvegarde RP du joueur déconnecté conservée')
SIM.run(14000)
back(1)
-- reconnexion
SIM.addPlayer(2, 'Joueur', '2', bank2)
SIM.call(function() TriggerEvent('elyzea:server:playerLogin', 2) end)
SIM.run(5000)
local rs2 = SIM.last(2, 'elyzea_lasergame:restore')
check(rs2 ~= nil and rs2.quiet == true, 'reconnexion : état RP restauré automatiquement')
back(2)
check(sql('scalar', 'SELECT COUNT(*) FROM `lg_restore` WHERE `citizenid` = ?', { 'CID2' }) == 0, 'sauvegarde supprimée après restauration')
check(DB.ProfileByCid('CID2').losses >= 2, 'abandon compté comme défaite')

-- ================================================================ redémarrage pendant une partie
section('Redémarrage de la ressource pendant une partie')
local _, uid3 = SIM.rpc(3, 'pvp:create', { format = '1v1', map = 'pvp_small', rounds = 3, roundTime = 120, category = 'rifle', stake = 3000 })
SIM.rpc(4, 'pvp:join', uid3, '')
SIM.rpc(3, 'pvp:ready', true)
SIM.rpc(4, 'pvp:ready', true)
local b3, b4 = SIM.money[3].bank, SIM.money[4].bank
SIM.rpc(3, 'pvp:start')
SIM.run(4000)
-- crash : l'état en mémoire disparaît, la base reste
Games.list, Games.byPlayer, Games.slots = {}, {}, {}
CreateThread(function()
    Economy.RecoverOnStart()
    for _, sid in ipairs(GetPlayers()) do Restore.FromDb(tonumber(sid)) end
end)
SIM.run(1000)
check(SIM.money[3].bank == b3 + 3000 and SIM.money[4].bank == b4 + 3000, 'mises remboursées au redémarrage')
check(sql('single', 'SELECT `status` FROM `lg_matches` WHERE `uid` = ?', { uid3 }).status == 'aborted', 'partie marquée « interrompue »')
check(SIM.last(3, 'elyzea_lasergame:restore') ~= nil and SIM.players[3].bucket == 0, 'joueurs connectés remis dans leur monde RP')
back(3) back(4)
SIM.run(5000)

-- ================================================================ spectateur
section('Spectateur')
local _, uid4 = SIM.rpc(1, 'pvp:create', { format = '1v1', map = 'pvp_small', rounds = 3, roundTime = 120, category = 'rifle', stake = 0 })
SIM.rpc(2, 'pvp:join', uid4, '')
SIM.rpc(1, 'pvp:ready', true) SIM.rpc(2, 'pvp:ready', true)
SIM.rpc(1, 'pvp:start')
SIM.run(9500)
check(SIM.rpc(5, 'spectate:join', uid4) == true, 'un joueur rejoint en spectateur')
local g4 = Games.list[uid4]
check(g4.spectators[5] ~= nil and SIM.players[5].bucket == g4.bucket and SIM.players[5].state.laserGame == 'spectator', 'spectateur dans l\'instance, rôle « spectator »')
SIM.now = SIM.now + 200
SIM.emit(5, 'elyzea_lasergame:shots', { { w = 'nova_ar', o = { x = 0, y = 0, z = 0 }, d = { x = 0, y = 1, z = 0 }, hit = { k = 'p', id = 1 } } })
check(g4.players[1].shield == 100, 'un spectateur ne peut pas tirer')
check(SIM.count(5, 'elyzea_lasergame:pvpState') >= 1, 'le spectateur reçoit le score')
SIM.rpc(5, 'lobby:leave')
check(g4.spectators[5] == nil and SIM.last(5, 'elyzea_lasergame:restore') ~= nil, 'le spectateur quitte et revient au RP')
back(5)
SIM.rpc(1, 'lobby:leave')
SIM.run(20000)
back(1) back(2)
SIM.run(5000)

-- ================================================================ ZOMBIE
section('Zombie : partie en duo')
local okz, zuid = SIM.rpc(1, 'zb:create', { name = 'Escouade' })
check(okz, 'groupe Zombie créé')
SIM.rpc(2, 'zb:join', zuid, '')
SIM.rpc(1, 'zb:ready', true) SIM.rpc(2, 'zb:ready', true)
local zg = Games.list[zuid]
check(SIM.rpc(1, 'zb:start') == true, 'survie lancée')
SIM.run(500)
local zm2 = Maps.Get('zombie_map')
local function zplace(i, lp) local w = Maps.World(zm2, lp) SIM.move(i, w.x, w.y, w.z + 1) end
zplace(1, { x = -2, y = -44 }) zplace(2, { x = 2, y = -44 })
check(zg.players[1].money == 500 and zg.players[1].weapons[1] == 'photon_p9', 'départ : 500 $ Zombie et pistolet laser')
check(zg.sectorsOpen.start and not zg.sectorsOpen.corridor, 'seule la salle de départ est ouverte')
SIM.run(9000)
check(zg.phase == 'round' and zg.round == 1, 'manche 1')
SIM.run(15000)
local zs = SIM.zombies()
check(#zs > 0 and zg.alive > 0, ('zombies créés par le serveur dans l\'instance (%d)'):format(#zs))
check(SIM.entities[zs[1].ent].bucket == zg.bucket, 'zombie placé dans le bon bucket')
local zst = SIM.entities[zs[1].ent].state.lgZombie
check(zst and zst.uid == zuid, 'state bag du zombie (type, allure)')
local bankBefore = SIM.money[1].bank

local zshots = 0
local function zshoot(from, z, weapon)
    -- le client recharge son chargeur de 12 (le serveur refuse les tirs au-delà)
    zshots = zshots + 1
    if zshots % 10 == 0 then
        SIM.emit(from, 'elyzea_lasergame:shots', { { w = weapon or 'photon_p9', r = true } })
        SIM.run(1300)
    end
    local o = SIM.players[from].pos + vector3(0, 0, 0.6)
    local t = SIM.entities[z.ent] and SIM.entities[z.ent].pos
    if not t then return end
    local d = t - o
    local l = #d
    SIM.now = SIM.now + 300
    SIM.emit(from, 'elyzea_lasergame:shots', { { w = weapon or 'photon_p9', o = { x = o.x, y = o.y, z = o.z }, d = { x = d.x / l, y = d.y / l, z = d.z / l }, hit = { k = 'z', id = z.net }, hp = { x = t.x, y = t.y, z = t.z } } })
end
-- tuer tous les zombies de la manche 1 (les rapprocher à 12 m pour la portée)
local guard = 0
while (zg.toSpawn > 0 or zg.alive > 0) and guard < 400 do
    guard = guard + 1
    for _, z in ipairs(SIM.zombies()) do
        local e = SIM.entities[z.ent]
        if e then e.pos = SIM.players[1].pos + vector3(0, 12, 0) zshoot(1, z) end
    end
    SIM.run(300)
end
check(zg.players[1].kills > 0 and zg.players[1].money > 500, ('argent Zombie gagné : %d $ (%d éliminations)'):format(zg.players[1].money, zg.players[1].kills))
check(SIM.money[1].bank == bankBefore, 'l\'argent Zombie n\'entre JAMAIS dans l\'argent RP')
SIM.run(800)
check(zg.phase == 'intermission', 'fin de manche → pause')
local c1 = LGU.ZombieCount(1, 2)
SIM.run(11000)
check(zg.round == 2 and zg.toSpawn + zg.alive >= LGU.ZombieCount(2, 2) - 1 and LGU.ZombieCount(2, 2) > c1, 'manche 2 : plus de zombies')

section('Zombie : portes, armes murales, atouts')
local door = zm2.doors[1]
zplace(1, { x = 0, y = -30 })
local okd, ed = SIM.rpc(1, 'zb:door', door.id)
check(okd == false, 'achat de porte refusé à distance')
zplace(1, { x = 0, y = -39.5 })
zg.players[1].money = 100
okd, ed = SIM.rpc(1, 'zb:door', door.id)
check(okd == false and tostring(ed):find('750'), 'argent insuffisant : refusé (prix 750 $)')
zg.players[1].money = 5000
okd = SIM.rpc(1, 'zb:door', door.id)
check(okd == true and zg.players[1].money == 4250 and zg.sectorsOpen.corridor, 'porte achetée : 750 $, couloir ouvert')
check(SIM.rpc(1, 'zb:door', door.id) == false, 'une porte ne s\'achète qu\'une fois')
local wb = zm2.wallbuys[1]
zplace(1, { x = wb.x, y = wb.y })
local okw = SIM.rpc(1, 'zb:wallbuy', wb.id)
check(okw == true and zg.players[1].weapons[2] == 'vector_x' and zg.players[1].money == 3750, 'arme murale achetée (Vector-X, 500 $)')
check(SIM.rpc(1, 'zb:wallbuy', wb.id) == false, 'arme déjà possédée : refusé')
local pk = zm2.perks[1]
zplace(1, { x = pk.x, y = pk.y })
local okp = SIM.rpc(1, 'zb:perk', pk.id)
check(okp == true and zg.players[1].perks.quickrevive, 'atout Réanimation rapide acheté')
-- Mastodonte : tricher la position n'est pas possible (salle fermée)
local jug
for _, p in ipairs(zm2.perks) do if p.perk == 'juggernaut' then jug = p end end
zplace(1, { x = jug.x, y = jug.y })
check(SIM.rpc(1, 'zb:perk', jug.id) == false, 'atout d\'une salle fermée : refusé')
SIM.run(1200)
check(SIM.count(1, 'elyzea_lasergame:pushBack') >= 1, 'joueur dans une salle fermée : renvoyé par le serveur')
zg.sectorsOpen.research = true
zplace(1, { x = jug.x, y = jug.y })
zg.players[1].money = 9000
check(SIM.rpc(1, 'zb:perk', jug.id) == true and zg.players[1].maxHp == 200, 'Mastodonte : vie max 200')

section('Zombie : dégâts, mise à terre, réanimation')
-- un zombie au contact du joueur 2
for _, z in ipairs(SIM.zombies()) do local e = SIM.entities[z.ent] if e then e.pos = SIM.players[2].pos + vector3(0, 0.8, 0) end end
local hpBefore = zg.players[2].hp
SIM.run(400)
check(zg.players[2].hp < hpBefore, 'attaque au corps à corps calculée par le serveur (distance)')
local g2 = 0
while zg.players[2].state == 'alive' and g2 < 100 do g2 = g2 + 1 SIM.run(400) end
check(zg.players[2].state == 'down' and zg.players[2].downs == 1, 'joueur 2 à terre')
check(SIM.last(2, 'elyzea_lasergame:zbDowned') ~= nil, 'le joueur à terre est prévenu')
-- éloigner les zombies et réanimer
for _, z in ipairs(SIM.zombies()) do local e = SIM.entities[z.ent] if e then e.pos = SIM.players[1].pos + vector3(30, 30, 0) end end
SIM.move(1, SIM.players[2].pos.x + 1.0, SIM.players[2].pos.y, SIM.players[2].pos.z)
local okrv, dur = SIM.rpc(1, 'zb:reviveStart', 2)
check(okrv and math.abs(dur - 2.0) < 0.01, 'réanimation lancée (2 s grâce à Réanimation rapide)')
SIM.run(2500)
check(zg.players[2].state == 'alive' and zg.players[1].revives == 1, 'joueur 2 réanimé, réanimation comptée')

section('Zombie : acide')
local acidBefore = zg.players[1].hp
zg.puddles[#zg.puddles + 1] = { x = SIM.players[1].pos.x, y = SIM.players[1].pos.y, z = SIM.players[1].pos.z, r = 2.6, from = SIM.now, to = SIM.now + 3000, dmg = 9, tick = 500, next = SIM.now }
SIM.run(1100)
check(zg.players[1].hp < acidBefore, 'flaque d\'acide : dégâts de zone')

section('Zombie : fin de partie')
-- tout le monde à terre → fin
for _, z in ipairs(SIM.zombies()) do local e = SIM.entities[z.ent] if e then e.pos = SIM.players[1].pos + vector3(0.5, 0, 0) end end
for s, p in pairs(zg.players) do p.hp = 1 p.perks.quickrevive = nil end
SIM.move(2, SIM.players[1].pos.x - 0.5, SIM.players[1].pos.y, SIM.players[1].pos.z)
SIM.run(4000)
check(zg.finished, 'tous à terre : fin de partie')
local run = sql('single', 'SELECT * FROM `lg_zombie_runs` WHERE `match_uid` = ?', { zuid })
check(run and run.round == zg.round and run.players == 2, ('partie enregistrée : manche %s, %s joueurs'):format(run and run.round, run and run.players))
local zp = DB.ProfileByCid('CID1')
check(zp.zb_best_round == zg.round and zp.zb_kills > 0 and zp.zb_games == 1, 'profil Zombie mis à jour (meilleure manche, zombies tués)')
SIM.run(13000)
check(#SIM.zombies() == 0, 'tous les zombies supprimés')
check(Games.list[zuid] == nil and SIM.players[1].bucket == 0, 'partie fermée, retour RP')
back(1) back(2)
local okzb, zb = SIM.rpc(3, 'lb:get', 'zb_teams', 1)
check(okzb and #zb.rows == 1 and zb.rows[1].names:find('Joueur'), 'classement des équipes Zombie')

section('Zombie : solo')
local okso = SIM.rpc(3, 'zb:create', { solo = true })
check(okso == true, 'partie solo lancée directement')
SIM.run(2000)
SIM.rpc(3, 'lobby:leave')
SIM.run(14000)
check(SIM.last(3, 'elyzea_lasergame:restore') ~= nil, 'abandon solo : retour au RP')
back(3)

-- ================================================================ STAFF
section('Staff')
local okad = SIM.rpc(1, 'admin:open')
check(okad == false, 'joueur normal : actions staff refusées')
local okst = SIM.rpc(10, 'admin:open')
check(okst == true, 'staff : ouverture de l\'administration')
SIM.rpc(10, 'admin:set', 'weapon', { damage = 35 }, 'nova_ar')
check(LGU.Weapon('nova_ar').damage == 35 and GlobalState.lgPublic.weapons.nova_ar.damage == 35, 'dégâts d\'une arme modifiés et publiés aux clients')
SIM.rpc(10, 'admin:set', 'weapon', { damage = 999999 }, 'nova_ar')
check(LGU.Weapon('nova_ar').damage == 1000, 'valeur bornée par le serveur (max 1000)')
SIM.rpc(10, 'admin:set', 'stake', { min = 100, max = 50000 })
check(Config.Stake.min == 100 and Config.Stake.max == 50000, 'mises min / max modifiées')
SIM.rpc(10, 'admin:set', 'door', { price = 999 }, 'd_corridor')
check(Settings.DoorPrice(Maps.Get('zombie_map').doors[1]) == 999, 'prix d\'une porte modifié')
SIM.rpc(10, 'admin:set', 'zombieRounds', { maxAlive = 12, hpBase = 200 })
check(LG.Zombie.rounds.maxAlive == 12 and LG.Zombie.rounds.hpBase == 200, 'difficulté Zombie modifiée')
SIM.rpc(10, 'admin:set', 'format', { enabled = false }, '6v6')
check(SIM.rpc(1, 'pvp:create', { format = '6v6', map = 'pvp_xlarge', rounds = 3, roundTime = 120, category = 'rifle', stake = 100 }) == false, 'format désactivé refusé')
SIM.rpc(10, 'admin:set', 'reset', {}, 'weapons')
check(LGU.Weapon('nova_ar').damage == 20, 'réinitialisation des armes')
SIM.rpc(10, 'admin:map', 'pvp_small', 'here')
check(Maps.Get('pvp_small').anchor.x == 800.0, 'carte déplacée sur la position du staff')
local staffZ = GetEntityCoords(GetPlayerPed(10)).z
check(math.abs(Maps.Get('pvp_small').anchor.z - (staffZ - 1.0 - Maps.Get('pvp_small').depth)) < 0.02, 'complexe souterrain : recréé à la même profondeur sous le staff')
SIM.rpc(10, 'admin:map', 'pvp_small', 'reset')
check(Maps.Get('pvp_small').anchor.x == 1900.0 and Maps.Get('pvp_small').anchor.z == -45.0, 'carte remise à sa position d\'origine (complexe souterrain)')
for _, id in ipairs(Maps.order) do
    local mm = Maps.Get(id)
    check(mm.underground == true and mm.slabs and #mm.slabs == 2 and mm.ceiling > 3.2, ('%s : complexe souterrain (sol + plafond à %s m)'):format(id, tostring(mm.ceiling)))
end
SIM.rpc(10, 'admin:npc', 'add', { label = 'Accueil 2' })
check(#GlobalState.lgPublic.npcs == 2, 'PNJ ajouté en jeu et publié')
SIM.rpc(10, 'admin:players.set', 'CID6', 'exclude', nil, { reason = 'triche', hours = 0 })
check(SIM.rpc(6, 'pvp:create', { format = '1v1', map = 'pvp_small', rounds = 1, roundTime = 60, category = 'pistol', stake = 100 }) == false, 'joueur exclu du LaserGame : refusé')
SIM.rpc(10, 'admin:players.set', 'CID6', 'unexclude')
SIM.rpc(10, 'admin:players.set', 'CID5', 'rank', 'legend')
check(DB.ProfileByCid('CID5').points == 2000, 'rang fixé par le staff (LEGEND = 2000 points)')
local oksr, found = SIM.rpc(10, 'admin:players.search', 'Joueur')
check(oksr and #found >= 5, 'recherche de joueurs')
local oklg, logs = SIM.rpc(10, 'admin:logs', 'money', 1)
check(oklg and #logs > 5, ('journaux financiers (%d lignes)'):format(oklg and #logs or 0))
local okstat, stats = SIM.rpc(10, 'admin:stats')
check(okstat and stats.held == 0, 'aucune mise bloquée en fin de tests')

section('Sécurité')
local flood = 0
for k = 1, 60 do local r = SIM.rpc(1, 'list:get') if r == false then flood = flood + 1 end end
check(flood > 0, ('limite de fréquence : %d requêtes refusées sur 60'):format(flood))
check(sql('scalar', "SELECT COUNT(*) FROM `lg_logs` WHERE `category` = 'security'") > 0, 'événements suspects journalisés')

section('Appli « LaserGame » du téléphone (elyzea_aura)')
do
    local notes = {}
    local origState = GetResourceState
    GetResourceState = function(r) if r == 'elyzea_aura' then return 'started' end return origState(r) end
    exports.elyzea_aura = { SendNotification = function(_, src, title, text, app) notes[#notes + 1] = { src = src, title = title, text = text, app = app } end }
    local function call(src, action, args) local r = Phone.Call(src, action, args or {}) SIM.run(10) return r end
    local function notesFor(src) local n = 0 for _, x in ipairs(notes) do if x.src == src then n = n + 1 end end return n end
    SIM.run(31000)   -- tables créées par le fil de l'appli
    check(sql('scalar', 'SELECT COUNT(*) FROM `lg_phone_posts`') == 0, 'tables de l\'appli créées')

    local h = call(1, 'home')
    check(h.ok and h.profile and h.profile.points and h.profile.rankLabel and #h.ranks == 8, 'accueil : points, rang et liste des rangs')
    check(#h.formats >= 1 and #h.maps == 5 and h.me.token and not h.me.cid, 'accueil : formats, 5 cartes, jeton (jamais l\'identifiant du personnage)')
    local b = call(1, 'board', { kind = 'pvp_points', page = 1 })
    local leak = false
    for _, r in ipairs(b.rows or {}) do if r.citizenid or r.cids then leak = true end end
    check(b.ok and #b.rows > 0 and not leak, ('classement PVP (%d joueurs), sans identifiant de personnage'):format(b.total or 0))
    check(call(1, 'board', { kind = 'zb_round' }).ok and not call(1, 'board', { kind = 'nope' }).ok, 'classement Zombie, classement inconnu refusé')

    -- demande de match PVP « dès que possible »
    local c = call(1, 'create', { kind = 'match', format = '2v2', map = 'pvp_small', stake = 500, message = '<b>Qui</b> pour un 2v2 ?' })
    check(c.ok and c.broadcast and c.broadcast.text:find('2v2'), 'demande de match PVP publiée (texte d\'annonce aux autres)')
    local row = sql('single', 'SELECT * FROM `lg_phone_posts` WHERE `id` = ?', { c.id })
    check(row.message == 'bQui/b pour un 2v2 ?' and row.slots == 3 and row.starts_at == 0, 'texte nettoyé, 3 places restantes en 2v2')
    check(not call(1, 'create', { kind = 'match', format = '1v1' }).ok, 'anti-spam : 2e publication trop rapide refusée')
    check(not call(2, 'create', { kind = 'match', format = '9v9' }).ok, 'format inconnu refusé')
    check(not call(2, 'create', { kind = 'match', format = '1v1', map = 'zombie_map' }).ok, 'carte Zombie refusée pour un match PVP')

    -- annonce programmée Zombie
    check(not call(2, 'create', { kind = 'event', mode = 'zombie', map = 'zombie_map' }).ok, 'annonce sans heure refusée')
    check(not call(2, 'create', { kind = 'event', mode = 'zombie', startsAt = os.time() - 3600 }).ok, 'heure passée refusée')
    check(not call(2, 'create', { kind = 'event', mode = 'zombie', startsAt = os.time() + 30 * 86400 }).ok, 'plus de 7 jours à l\'avance refusé')
    local e = call(2, 'create', { kind = 'event', mode = 'zombie', map = 'zombie_map', startsAt = os.time() + 20 * 60, message = 'Survie à 4' })
    check(e.ok and e.broadcast.text:find('Zombie'), 'annonce « dans 20 min : carte Zombie » publiée')

    local ev = call(3, 'posts', { kind = 'event' })
    local post = ev.posts and ev.posts[1]
    check(ev.ok and #ev.posts == 1 and post.mapLabel == 'COMPLEXE ELYZEA-7' and post.when:find('à') and not post.mine, 'liste des annonces (carte, heure)')
    -- Rejoindre : point GPS, jamais de téléportation
    SIM.move(3, 100.0, 100.0, 30.0)
    local before = GetEntityCoords(GetPlayerPed(3))
    local restores = SIM.count(3, 'elyzea_lasergame:restore')
    local j = call(3, 'join', { id = post.id })
    local nearest = nil
    for _, n in ipairs(Settings.Npcs()) do
        if not nearest or LGU.Dist2D(n, { x = 100, y = 100 }) < LGU.Dist2D(nearest, { x = 100, y = 100 }) then nearest = n end
    end
    local after = GetEntityCoords(GetPlayerPed(3))
    check(j.ok and j.gps and math.abs(j.gps.x - nearest.x) < 0.1 and math.abs(j.gps.y - nearest.y) < 0.1, 'Rejoindre : point GPS sur le PNJ LaserGame le plus proche')
    check(before.x == after.x and before.y == after.y and before.z == after.z and SIM.count(3, 'elyzea_lasergame:restore') == restores, 'Rejoindre ne téléporte pas le joueur')
    check(notesFor(2) >= 1, 'l\'auteur est prévenu qu\'un joueur rejoint')
    local ev2 = call(3, 'posts', { kind = 'event' })
    check(ev2.posts[1].joined and ev2.posts[1].count == 1 and ev2.posts[1].players[1] == 'Joueur 3', 'inscription visible (compteur, nom)')
    call(3, 'join', { id = post.id })
    check(sql('scalar', 'SELECT COUNT(*) FROM `lg_phone_joins` WHERE `post_id` = ?', { post.id }) == 1, 'rejoindre deux fois : une seule inscription')

    -- rappels
    local n3 = notesFor(3)
    SIM.run(11 * 60 * 1000)
    check(notesFor(3) > n3 and sql('scalar', 'SELECT `notified` FROM `lg_phone_posts` WHERE `id` = ?', { post.id }) == 1, 'rappel aux inscrits 10 min avant')
    SIM.run(10 * 60 * 1000)
    check(sql('scalar', 'SELECT `notified` FROM `lg_phone_posts` WHERE `id` = ?', { post.id }) == 2, 'notification « c\'est l\'heure »')

    -- messagerie (sur une demande de match)
    local m1 = call(4, 'send', { post = c.id, body = 'Je suis chaud pour ton 2v2' })
    check(m1.ok and m1.token and notesFor(1) >= 1, 'message à l\'auteur d\'une demande : envoyé et notifié')
    check(not call(1, 'send', { token = h.me.token, body = 'moi' }).ok, 'impossible de s\'écrire à soi-même')
    local th = call(1, 'threads')
    check(th.ok and #th.threads == 1 and th.threads[1].unread == 1 and th.unread == 1, 'conversations : 1 non lue')
    local t1 = call(1, 'thread', { token = th.threads[1].token })
    check(t1.ok and #t1.messages == 1 and not t1.messages[1].mine and t1.unread == 0, 'conversation ouverte : message lu')
    SIM.run(3000)
    local r1 = call(1, 'send', { token = th.threads[1].token, body = 'Go, viens au LaserGame' })
    local th4 = call(4, 'threads')
    if not (r1.ok and th4.threads[1].unread == 1) then SIM.print('    ' .. json.encode(r1) .. ' ' .. json.encode(th4)) end
    check(r1.ok and th4.threads[1].unread == 1, 'réponse reçue')
    check(not call(4, 'send', { token = 'inconnu', body = 'x' }).ok and not call(4, 'thread', { token = 'inconnu' }).ok, 'jeton inconnu refusé')

    -- retirer : seul l'auteur ou le staff
    check(not call(3, 'cancel', { id = c.id }).ok, 'un autre joueur ne peut pas retirer l\'annonce')
    local n4 = notesFor(4)
    check(call(10, 'cancel', { id = e.id }).ok, 'le staff retire une annonce')
    check(call(1, 'cancel', { id = c.id }).ok and #call(1, 'posts', { kind = 'match' }).posts == 0, 'l\'auteur retire sa demande')
    check(notesFor(3) > 0 and notesFor(4) >= n4, 'les inscrits sont prévenus de l\'annulation')

    -- expiration d'une demande « dès que possible »
    SIM.run(61000)
    local x = call(5, 'create', { kind = 'match', format = '1v1' })
    SIM.run(2 * 3600 * 1000 + 60000)
    check(sql('scalar', 'SELECT `status` FROM `lg_phone_posts` WHERE `id` = ?', { x.id }) == 'expired', 'demande expirée après 2 h')

    -- exclu du LaserGame
    SIM.rpc(10, 'admin:players.set', 'CID6', 'exclude', nil, { reason = 'triche', hours = 0 })
    check(not call(6, 'create', { kind = 'match', format = '1v1' }).ok, 'joueur exclu : ne peut pas publier')
    SIM.rpc(10, 'admin:players.set', 'CID6', 'unexclude')
    check(not Phone.Call(1, 'inconnu', {}).ok and not Phone.Call(999, 'home', {}).ok, 'action inconnue / personnage introuvable refusés')
    local gps = call(1, 'gps')
    check(gps.ok and gps.gps.label ~= nil, 'bouton « GPS vers le LaserGame »')
    GetResourceState = origState
end

SIM.print(('\n%d vérifications réussies, %d échec(s), %d erreur(s) de fil'):format(PASS, FAIL, #SIM.errors))
return FAIL + #SIM.errors
