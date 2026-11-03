-- Scénarios de simulation du serveur d'elyzea_pier (voir run_server_sim.py)
local PASS, FAIL = 0, 0
local function check(c, label) if c then PASS = PASS + 1 SIM.print('  ok   ' .. label) else FAIL = FAIL + 1 SIM.print('  ÉCHEC ' .. label) end end
local function section(t) SIM.print('\n[' .. t .. ']') end
for _, f in ipairs(SIM_FILES) do
    local chunk, err = load(py_read(f), '@' .. f)
    if not chunk then error(err) end
    chunk()
end
SIM.run(1000)

local TW, TC = Config.Tickets.wheel.item, Config.Tickets.coaster.item
local NPC = vector3(Config.Npc.coords.x, Config.Npc.coords.y, Config.Npc.coords.z)
local WE, CE = Config.Wheel.entry, Config.Coaster.entry
local function tickets(id, item) return SIM.items[id][item] or 0 end

-- ================================================================ calculs
section('Calculs (formules du jeu original)')
local C, W = PierRide.Coaster, PierRide.Wheel
check(C.n == 224 and math.abs(C.total - 549.2) < 0.5, ('rail original : %d nœuds, %.1f m'):format(C.n, C.total))
check(C.natural > 50 and C.natural < 75, ('durée réelle du parcours : %.1f s'):format(C.natural))
check(C.maxSpeed > 15 and C.maxSpeed < 20, ('vitesse maximale : %.1f m/s (%.0f km/h)'):format(C.maxSpeed, C.maxSpeed * 3.6))
local maxStep, maxRail, prev = 0, 0, nil
for i = 0, math.floor(C.natural * 30) do
    local d = C.CarDistance(1, C.TravelAt(i / 30), 2.55)
    local x, y, z, s, f = C.PosAt(d)
    if prev then maxStep = math.max(maxStep, math.sqrt((x - prev[1]) ^ 2 + (y - prev[2]) ^ 2 + (z - prev[3]) ^ 2)) end
    prev = { x, y, z }
    -- le wagon est-il sur la ligne du rail ? (distance au segment)
    local a, b = C.nodes[s], C.nodes[s + 1]
    local ex, ey, ez = a.x + (b.x - a.x) * f, a.y + (b.y - a.y) * f, a.z + (b.z - a.z) * f
    maxRail = math.max(maxRail, math.sqrt((x - ex) ^ 2 + (y - ey) ^ 2 + (z - ez) ^ 2))
end
check(maxStep < 0.7, ('mouvement fluide : %.2f m au plus entre deux images (pas de téléportation)'):format(maxStep))
check(maxRail < 1e-6, 'les wagons restent exactement sur le rail original')
local ex, ey, ez = C.PosAt(C.CarDistance(1, C.TravelAt(C.natural), 2.55))
local sx, sy, sz = C.PosAt(C.station)
check(math.sqrt((ex - sx) ^ 2 + (ey - sy) ^ 2 + (ez - sz) ^ 2) < 0.01, 'le train revient exactement en gare')
local up, down = false, false
for i = 1, math.floor(C.natural) do
    local _, _, z1 = C.PosAt(C.CarDistance(1, C.TravelAt(i - 1), 2.55))
    local _, _, z2 = C.PosAt(C.CarDistance(1, C.TravelAt(i), 2.55))
    if z2 > z1 + 0.5 then up = true end
    if z2 < z1 - 2 then down = true end
end
check(up and down, 'montées et descentes')
local okQ = true
for i = 0, 600 do local qx, qy, qz, qw = C.QuatAt(C.station + i * 0.9) if math.abs(qx * qx + qy * qy + qz * qz + qw * qw - 1) > 1e-6 then okQ = false end end
check(okQ, 'orientation (quaternions) valide sur tout le rail')
check(math.abs(C.Duration(120) - 120) < 1e-6 and math.abs(C.TravelAt(120, C.Scale(120)) - C.total) < 0.01, 'durée configurable (120 s : même parcours, plus lent)')
local okW = true
for c = 1, 16 do local _, _, z = W.CabinWorld(Config.Wheel.center, 15.3, c, W.BoardAngle(c, 0)) if math.abs(z - 15.4) > 1e-6 then okW = false end end
check(okW, 'roue : chaque cabine arrive exactement en bas à son angle d\'arrêt')

-- ================================================================ joueurs
for i = 1, 10 do SIM.addPlayer(i, NPC, 1000, 10000) end
SIM.addPlayer(20, vector3(0, 0, 70), 1000, 10000)

section('Billetterie')
local ok, msg = SIM.rpc(20, 'buy', 'wheel', 1, 'cash')
check(ok == false and tostring(msg):find('billetterie'), 'achat refusé loin du PNJ')
check(SIM.rpc(1, 'buy', 'wheel', 0, 'cash') == false, 'quantité invalide refusée (0)')
check(SIM.rpc(1, 'buy', 'wheel', 99, 'cash') == false, 'quantité invalide refusée (99 > max)')
check(SIM.rpc(1, 'buy', 'licorne', 1, 'cash') == false, 'ticket inconnu refusé')
SIM.money[2].cash = 100
ok, msg = SIM.rpc(2, 'buy', 'wheel', 1, 'cash')
check(ok == false and tostring(msg):find('manque'), 'argent insuffisant : refusé')
check(SIM.money[2].cash == 100 and tickets(2, TW) == 0, 'rien n\'est débité ni donné')
ok, msg = SIM.rpc(1, 'buy', 'wheel', 2, 'cash')
check(ok == true and SIM.money[1].cash == 700 and tickets(1, TW) == 2, 'achat de 2 tickets grande roue en liquide (2 × 150 $)')
ok = SIM.rpc(1, 'buy', 'coaster', 1, 'bank')
check(ok == true and SIM.money[1].bank == 9750 and tickets(1, TC) == 1, 'achat d\'un ticket montagnes russes par carte (250 $)')
SIM.addFails = true
local before = SIM.money[3].cash
ok, msg = SIM.rpc(3, 'buy', 'coaster', 1, 'cash')
SIM.addFails = false
check(ok == false and SIM.money[3].cash == before and tickets(3, TC) == 0, 'objet impossible à donner : remboursement automatique')
SIM.full = true
ok, msg = SIM.rpc(3, 'buy', 'coaster', 1, 'cash')
SIM.full = false
check(ok == false and tostring(msg):find('place'), 'inventaire plein : refusé avant tout débit')
local total = 0
for i = 1, 10 do total = total + SIM.money[i].cash + SIM.money[i].bank end
check(total == 10 * 11000 - 900 - 100 + 100 - 900 + 900 - 550, 'aucun argent créé : seuls les tickets achetés ont été payés') -- (joueur 2 à 100 $)
for i = 2, 10 do
    SIM.money[i].cash = 5000
    SIM.rpc(i, 'buy', 'wheel', 1, 'cash')
    SIM.rpc(i, 'buy', 'coaster', 1, 'cash')
end
check(tickets(5, TW) == 1 and tickets(5, TC) == 1, 'chaque joueur a ses tickets (inventaire, persistant)')
local okI, info = SIM.rpc(1, 'info')
check(okI and info.rides.wheel.owned == 2 and info.rides.coaster.price == 250 and info.rides.wheel.capacity == 32 and info.rides.coaster.capacity == 8,
    'informations : tickets possédés, prix, places (32 / 8)')

-- ================================================================ grande roue
section('Grande roue : file, embarquement à plusieurs')
for i = 1, 5 do SIM.move(i, WE) end
SIM.move(6, vector3(WE.x + 30, WE.y, WE.z))
ok, msg = SIM.rpc(6, 'wheelJoin')
check(ok == false and tostring(msg):find('entrée'), 'embarquement refusé à distance de l\'entrée')
SIM.items[5][TW] = 0
ok, msg = SIM.rpc(5, 'wheelJoin')
check(ok == false and tostring(msg):find('ticket'), 'impossible de monter sans ticket')
SIM.items[5][TW] = 1
SIM.players[5].state.emsDown = true
check(SIM.rpc(5, 'wheelJoin') == false, 'impossible de monter en étant à terre')
SIM.players[5].state.emsDown = nil
local ticketsBefore = tickets(1, TW)
for i = 1, 4 do ok = SIM.rpc(i, 'wheelJoin') check(ok == true, ('joueur %d dans la file'):format(i)) end
check(SIM.rpc(1, 'wheelJoin') == false, 'pas deux fois dans la file')
check(SIM.rpc(1, 'coasterJoin') == false, 'impossible de s\'inscrire à deux attractions en même temps')
check(tickets(1, TW) == ticketsBefore, 'le ticket n\'est pas consommé dans la file d\'attente')
local S = Wheel._S
SIM.run(13000)
check(S.stopped and S.stopCabin ~= nil, ('la roue s\'arrête avec une cabine en gare (cabine %s)'):format(tostring(S.stopCabin)))
local c1 = S.riders[1] and S.riders[1].c
check(c1 and S.riders[2] and S.riders[2].c == c1, ('joueurs 1 et 2 ensemble dans la cabine %s'):format(tostring(c1)))
check(tickets(1, TW) == ticketsBefore - 1 and tickets(2, TW) == 0, 'un seul ticket consommé à l\'embarquement effectif')
check(SIM.last(1, 'elyzea_pier:wheelBoard') ~= nil, 'le client reçoit l\'ordre d\'embarquer (cabine, place)')
check(S.riders[3] == nil, 'cabine pleine (2 places) : joueur 3 attend la suivante')
check(GlobalState.pierWheel.speed == 0, 'état publié à tous : roue arrêtée')
check(SIM.rpc(1, 'wheelSeated', { x = 1.2, y = 0.3, z = -1.7 }, 90) == true, 'position assise transmise (pour l\'afficher chez les autres)')
check(SIM.rpc(2, 'wheelSeated', { x = 50, y = 0, z = 0 }, 0) == false, 'position assise farfelue refusée')
check(SIM.rpc(7, 'wheelSeated', { x = 1, y = 0, z = 0 }, 0) == false, 'un non-passager ne peut rien déclarer')
check(GlobalState.pierWheelSeats['1'] and GlobalState.pierWheelSeats['1'].c == c1, 'places publiées pour tous les clients')
SIM.run(14000 + 12000)
check(S.riders[3] and S.riders[4] and S.riders[3].c == S.riders[4].c and S.riders[3].c ~= c1, ('joueurs 3 et 4 ensemble dans la cabine suivante (%s)'):format(tostring(S.riders[3] and S.riders[3].c)))
check(SIM.rpc(1, 'leave') == false, 'impossible de descendre pendant le tour')

section('Grande roue : tour complet, déconnexion, téléportation')
SIM.removePlayer(4)
check(S.riders[4] == nil and GlobalState.pierWheelSeats['4'] == nil, 'joueur déconnecté pendant le tour : place libérée')
local tStart = SIM.now
local guard = 0
while S.riders[1] and S.riders[1].state ~= 'arriving' and guard < 400 do SIM.run(1000) guard = guard + 1 end
local elapsed = (SIM.now - tStart) / 1000
check(SIM.last(1, 'elyzea_pier:wheelArrive') ~= nil, ('tour complet puis arrivée en gare (≈ %.0f s)'):format(elapsed + 26))
check(SIM.last(2, 'elyzea_pier:wheelArrive') ~= nil, 'les deux passagers de la cabine descendent ensemble')
check(math.abs((W.RotAt(S, SIM.now) - (S.riders[1] and S.riders[1].done or 0))) < 0.01 or S.stopped, 'arrêt exact de la cabine en gare après 360°')
SIM.run(6000)
check(S.riders[1] == nil and Pier.busy[1] == nil, 'place libérée, joueur libre')
SIM.move(3, vector3(500, 500, 50))
SIM.run(2000)
check(S.riders[3] == nil and SIM.last(3, 'elyzea_pier:rideCancelled') == 'wheel', 'passager téléporté loin : retiré du tour')
SIM.move(5, WE)
ok = SIM.rpc(5, 'wheelJoin')
SIM.move(5, vector3(WE.x + 20, WE.y, WE.z))
SIM.run(2000)
check(Pier.busy[5] == nil and tickets(5, TW) == 1, 's\'éloigner de l\'entrée fait quitter la file (ticket conservé)')

-- ================================================================ montagnes russes
section('Montagnes russes : embarquement, départ, trajet, arrivée')
local K = Coaster._S
for i = 5, 10 do SIM.move(i, CE) end
SIM.items[1][TC] = 1
SIM.move(1, CE)
local tk = tickets(5, TC)
ok, msg = SIM.rpc(5, 'coasterJoin')
check(ok == true and type(msg) == 'table' and msg.boarded, 'joueur 5 embarque directement (train en gare)')
check(tickets(5, TC) == tk - 1, 'ticket consommé à l\'embarquement')
check(K.phase == 'boarding' and K.departAt > SIM.now, 'compte à rebours avant le départ')
for i = 6, 8 do SIM.rpc(i, 'coasterJoin') end
check(K.riders[6].seat == 2 and K.riders[7].seat == 3 and K.riders[8].seat == 4, 'places attribuées dans l\'ordre (wagons 1 et 2 : le groupe est ensemble)')
check(SIM.rpc(8, 'coasterSeated', { x = 0.3, y = -0.9, z = 0.6 }, 180) == true, 'position assise transmise')
-- descendre avant le départ : ticket rendu
ok = SIM.rpc(8, 'leave')
check(ok == true and K.riders[8] == nil and tickets(8, TC) == 1, 'descendre avant le départ : place libérée, ticket rendu')
SIM.rpc(8, 'coasterJoin')
SIM.run(Config.Coaster.boardingTime * 1000 + 500)
check(K.phase == 'running', 'départ après le temps d\'embarquement')
check(SIM.last(5, 'elyzea_pier:coasterDepart') ~= nil and GlobalState.pierCoaster.phase == 'running', 'départ annoncé aux passagers et publié à tous')
check(SIM.rpc(5, 'leave') == false, 'impossible de descendre pendant le trajet')
-- pendant le trajet : nouvelle inscription → file (ticket conservé)
ok, msg = SIM.rpc(9, 'coasterJoin')
check(ok == true and msg.boarded == false and tickets(9, TC) == 1, 'train parti : file d\'attente, ticket conservé')
-- passagers suivant leur wagon (le client attache le joueur au wagon)
local function follow()
    local st = GlobalState.pierCoaster
    for src, r in pairs(K.riders) do
        local car = math.ceil(r.seat / 2)
        local x, y, z = C.PosAt(C.CarDistance(car, C.TravelAt(math.max(0, (SIM.now - st.t0) / 1000), st.scale), 2.55))
        if SIM.players[src] then SIM.move(src, vector3(x, y, z)) end
    end
end
local mid = false
while K.phase == 'running' do
    follow()
    SIM.run(500)
    if not mid and K.phase == 'running' and SIM.now > K.t0 + 20000 then
        mid = true
        SIM.removePlayer(7)
        check(K.riders[7] == nil and GlobalState.pierCoasterSeats['7'] == nil, 'passager déconnecté pendant le trajet : place libérée')
        SIM.players[6].health = 0
    end
end
check(K.phase == 'unloading', ('arrivée en gare après %.0f s de trajet'):format((K.unloadAt - Config.Coaster.unloadTime * 1000 - K.t0) / 1000))
check(SIM.last(5, 'elyzea_pier:coasterArrive') ~= nil and SIM.last(8, 'elyzea_pier:coasterArrive') ~= nil, 'tous les passagers descendent ensemble')
check(SIM.last(6, 'elyzea_pier:coasterArrive') ~= nil, 'un passager mort pendant le trajet reste attaché et est déposé en gare')
SIM.players[6].health = 200
SIM.run(Config.Coaster.unloadTime * 1000 + 600)
check(K.riders[9] and K.riders[9].seat == 1 and tickets(9, TC) == 0, 'train suivant : la file embarque (ticket consommé à ce moment)')
check(Pier.busy[5] == nil, 'les passagers précédents sont libres')

section('Sécurité')
check(SIM.rpc(1, 'coasterSeated', { x = 0, y = 0, z = 0 }, 0) == false, 'impossible de déclarer une place sans être passager')
local refused = 0
SIM.burst = true
for i = 1, 40 do local r = SIM.rpc(1, 'info') if r == false then refused = refused + 1 end end
SIM.burst = false
check(refused > 0, ('limite de fréquence active (%d requêtes refusées sur 40)'):format(refused))
local evts = 0
for name in pairs(SIM.events) do if name:find('elyzea_pier') and not name:find('__elycb') then evts = evts + 1 end end
check(evts == 0, 'aucun événement réseau client → serveur ne peut lancer ou finir un trajet')
SIM.players[2].admin = true
SIM.call(function() SIM.commands.pier_reset(2, {}) end)
check(next(Wheel._S.riders) == nil and next(Coaster._S.riders) == nil, 'remise à zéro par le staff')

SIM.print(('\n%d vérifications réussies, %d échec(s), %d erreur(s)'):format(PASS, FAIL, #SIM.errors))
return FAIL + #SIM.errors
