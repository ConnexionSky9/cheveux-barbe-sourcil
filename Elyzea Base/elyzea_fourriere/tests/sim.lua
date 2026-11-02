-- =====================================================================
--  Scénarios elyzea_fourriere (vrais fichiers serveur, vraie base)
-- =====================================================================
local CH = loadResource('elyzea_change', { 'elyzea_change/config.lua', 'elyzea_change/server_payment.lua' })
local FR = loadResource('elyzea_fourriere', { 'elyzea_fourriere/config.lua', 'elyzea_fourriere/server/main.lua' })
local F, C = FR.F, FR.Config
local function q1(sql, a) return py_single(sql, a) end
local function stateOf(plate) local r = q1('SELECT state FROM player_vehicles WHERE plate = ?', { plate }) return r and r.state end

print('— Base de données')
FR.F.setup()
FR.F.setup()   -- deux fois : rien ne casse
check(py_scalar("SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME='player_vehicles' AND COLUMN_NAME='vclass'") == 1, 'colonne player_vehicles.vclass ajoutée')
check(py_scalar("SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME='elyzea_fourriere'") == 1, 'table elyzea_fourriere créée')

-- Joueurs : A (propriétaire), B (autre joueur)
local NPC_LAND, NPC_AIR, NPC_SEA = vector3(100, 0, 0), vector3(500, 0, 0), vector3(900, 0, 0)
addPlayer(1, 'CID_A', 5000, 20000, 0, NPC_LAND)
addPlayer(2, 'CID_B', 5000, 20000, 0, NPC_LAND)
local function veh(plate, model, state, cls)
    py_insert('INSERT INTO player_vehicles (citizenid, vehicle, hash, mods, plate, garage, state, vclass) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { 'CID_A', model, model, '{"plate":"' .. plate .. '","color1":12,"engineHealth":640,"bodyHealth":700,"_deform":[[0,1,0,0.2]],"tyres":{"0":1}}', plate, 'public', state, cls })
end
veh('CAR001', 'sultan', 0) veh('MOTO01', 'bati', 0) veh('HELI01', 'frogger', 0) veh('BOAT01', 'dinghy', 0)
veh('PLANE1', 'dodo', 0) veh('OLD001', 'speeder', 2)   -- ancien véhicule en fourrière, catégorie inconnue (vraiment un bateau)
REAL_TYPE.bati, REAL_TYPE.frogger, REAL_TYPE.dinghy, REAL_TYPE.dodo, REAL_TYPE.speeder = 'bike', 'heli', 'boat', 'plane', 'boat'

print('— Mise en fourrière (police) et épaves')
local e1 = spawnWorld('sultan', 'CAR001', vector3(10, 10, 0))
local ok, destroyed = F.impound(e1, nil, 'police')
DeleteEntity(e1)   -- comme elyzea_police après l'export
check(ok and not destroyed and stateOf('CAR001') == 2, 'voiture enlevée par la police : state 2, non détruite')
local fr = q1('SELECT * FROM elyzea_fourriere WHERE plate = ?', { 'CAR001' })
check(fr and fr.vclass == 'car' and fr.reason == 'police' and fr.status == 'impound', 'ligne fourrière : catégorie car relevée sur le véhicule, raison police')
check(q1('SELECT vclass FROM player_vehicles WHERE plate = ?', { 'CAR001' }).vclass == 'car', 'catégorie enregistrée dans player_vehicles.vclass')
local e2 = spawnWorld('bati', 'MOTO01', vector3(10, 20, 0)) F.impound(e2, nil, 'police') DeleteEntity(e2)
local e3 = spawnWorld('frogger', 'HELI01', vector3(10, 30, 0), -4000.0, 0.0)
local _, d3 = F.impound(e3, nil, 'police') DeleteEntity(e3)
check(d3 == true and q1('SELECT destroyed FROM elyzea_fourriere WHERE plate = ?', { 'HELI01' }).destroyed == 1, 'hélico explosé : marqué détruit')
check(lastSent('fourriere:client:notify', 1) and lastSent('fourriere:client:notify', 1).args[1]:find('aérienne'), 'propriétaire prévenu (fourrière aérienne)')

-- Épave dans le monde : bateau sorti, détruit
local e4 = spawnWorld('dinghy', 'BOAT01', vector3(105, 0, 0), -4000.0, 0.0)
fire('fourriere:server:wreck', 2, NetworkGetNetworkIdFromEntity(e4))
check(stateOf('BOAT01') == 2 and q1('SELECT destroyed, reason, vclass FROM elyzea_fourriere WHERE plate = ?', { 'BOAT01' }).vclass == 'boat', 'épave de bateau signalée par un autre joueur : fourrière maritime, détruit')
check(#Timeouts >= 1, 'épave supprimée du monde après le délai')
Timeouts[1]() check(not DoesEntityExist(e4), 'épave bien supprimée')
local e5 = spawnWorld('dodo', 'PLANE1', vector3(110, 0, 0), 900.0, 900.0)
fire('fourriere:server:wreck', 2, NetworkGetNetworkIdFromEntity(e5))
check(stateOf('PLANE1') == 0, 'véhicule en bon état signalé comme épave : ignoré (vérifié par le serveur)')
local e6 = spawnWorld('blista', 'NOBODY', vector3(110, 5, 0), -4000.0, 0.0)
fire('fourriere:server:wreck', 2, NetworkGetNetworkIdFromEntity(e6))
check(q1('SELECT plate FROM elyzea_fourriere WHERE plate = ?', { 'NOBODY' }) == nil, 'épave sans propriétaire : ignorée')

print('— Ouverture et liste')
local SPOTS_LAND = { { x = 120, y = 0, z = 0, h = 90, cls = 'car' }, { x = 130, y = 0, z = 0, h = 90, cls = 'moto' } }
F.openFor(1, { kind = 'land', name = 'Fourrière Davis', spots = SPOTS_LAND, npc = { x = 100, y = 0, z = 0 } })
local open = lastSent('fourriere:client:open', 1).args[1]
local byPlate = {} for _, v in ipairs(open.list) do byPlate[v.plate] = v end
check(#open.list == 5, 'liste : les 5 véhicules du joueur à la fourrière (toutes catégories)')
check(byPlate.CAR001.price == C.Prices.car.impound and byPlate.CAR001.kind == 'land', 'prix voiture et fourrière terrestre')
check(byPlate.HELI01.price == C.Prices.heli.destroyed and byPlate.HELI01.destroyed, 'hélico détruit : prix de réparation')
check(byPlate.OLD001.cls == nil, 'ancien véhicule : catégorie inconnue avant vérification')
check(table.concat(open.methods, ',') == 'cash,bank,pesos', 'monnaie non imposée : liquide, banque et pesos proposés')

print('— Sécurité')
Players[2].pos = NPC_LAND
F.openFor(2, { kind = 'land', spots = SPOTS_LAND, npc = { x = 100, y = 0, z = 0 } })
local okB, msgB = F.retrieve(2, 'CAR001', 'cash')
check(not okB and msgB:find('appartient') and Players[2].money.cash == 5000, 'un autre joueur ne peut pas récupérer le véhicule (rien débité)')
local okH, msgH = F.retrieve(1, 'HELI01', 'cash')
check(not okH and msgH:find('aérienne'), 'hélico à la fourrière terrestre : refusé, renvoyé vers la fourrière aérienne')
Players[1].pos = vector3(300, 0, 0)
local okD, msgD = F.retrieve(1, 'CAR001', 'cash')
check(not okD and msgD:find('Rapproche'), 'trop loin du PNJ : refusé')
Players[1].pos = NPC_LAND
local okM, msgM = F.retrieve(1, 'CAR001', 'item')
check(not okM and Players[1].money.cash == 5000, 'moyen de paiement inventé : refusé')

print('— Place de sortie')
local blocker = spawnWorld('blista', 'XX', vector3(121, 0, 0))
local okS, msgS = F.retrieve(1, 'CAR001', 'cash')
check(not okS and msgS:find('occupée') and Players[1].money.cash == 5000 and stateOf('CAR001') == 2, 'place occupée : message, rien débité, toujours en fourrière')
DeleteEntity(blocker)
Sent = {}
local okR, msgR, spawned = F.retrieve(1, 'CAR001', 'cash')
check(okR and spawned and Players[1].money.cash == 4500, 'paiement 500 $ en liquide et sortie immédiate')
check(stateOf('CAR001') == 0 and q1('SELECT plate FROM elyzea_fourriere WHERE plate = ?', { 'CAR001' }) == nil, 'state 0 (sorti) et ligne fourrière supprimée')
local sp = lastSent('garage:client:spawned', 1)
local ent = NetworkGetEntityFromNetworkId(sp.args[1])
check(Ents[ent].plate == 'CAR001' and Ents[ent].spawnType == 'automobile' and Ents[ent].pos.x == 120, 'véhicule créé sur la place « voiture » avec sa plaque')
check(sp.args[2].color1 == 12, 'propriétés enregistrées envoyées (couleurs, pièces…)')
check(Society.police == 500, 'argent versé à la police (fourrière police)')
check(F.sessions[1] == nil, 'interface fermée après la sortie')
F.openFor(1, { kind = 'land', spots = SPOTS_LAND, npc = { x = 100, y = 0, z = 0 } })
local okR2, msgR2 = F.retrieve(1, 'CAR001', 'cash')
check(not okR2 and msgR2:find('n\'est pas à la fourrière') and Players[1].money.cash == 4500, 'deuxième paiement : refusé, rien débité')

print('— Pesos')
F.openFor(1, { kind = 'land', spots = SPOTS_LAND, npc = { x = 100, y = 0, z = 0 } })
Players[1].items.pesos = 100
local okP, msgP = F.retrieve(1, 'MOTO01', 'pesos')
check(not okP and msgP:find('pesos') and Players[1].items.pesos == 100 and stateOf('MOTO01') == 2, 'pas assez de pesos : refus expliqué, rien retiré, moto toujours en fourrière')
Players[1].items.pesos = 1000
local okP2 = F.retrieve(1, 'MOTO01', 'pesos')
check(okP2 and Players[1].items.pesos == 1000 - C.Prices.moto.impound and Players[1].money.cash == 4500, 'payé en pesos (300), dollars intacts')
local mEnt for e, v in pairs(Ents) do if v.plate == 'MOTO01' then mEnt = e end end
check(mEnt and Ents[mEnt].pos.x == 130 and Ents[mEnt].spawnType == 'bike', 'moto sortie sur la place « moto »')

-- Monnaie imposée : fourrière maritime en pesos uniquement
CH.Config.Payment.Businesses.FourriereBateau = { Currency = 'pesos', ForceCurrency = true }
Players[1].pos = NPC_SEA
F.openFor(1, { kind = 'sea', spots = { { x = 950, y = 0, z = 0, h = 0, cls = 'boat' } }, npc = { x = 900, y = 0, z = 0 } })
local seaOpen = lastSent('fourriere:client:open', 1).args[1]
check(#seaOpen.methods == 1 and seaOpen.methods[1] == 'pesos' and seaOpen.forced, 'ForceCurrency : seuls les pesos sont proposés')
local okF, msgF = F.retrieve(1, 'BOAT01', 'cash')
check(not okF and msgF:find('que les pesos') and Players[1].money.cash == 4500, 'paiement en dollars refusé quand les pesos sont imposés')
-- Réglage du PNJ ignoré quand le commerce impose sa monnaie
F.openFor(1, { kind = 'sea', spots = {}, npc = { x = 900, y = 0, z = 0 }, currency = 'money', currencyForce = true })
check(lastSent('fourriere:client:open', 1).args[1].methods[1] == 'pesos', 'monnaie imposée par le commerce : le PNJ ne peut pas la changer')
CH.Config.Payment.Businesses.FourriereBateau = { Currency = 'money', ForceCurrency = false }
-- Réglage du PNJ appliqué sinon
F.openFor(1, { kind = 'sea', spots = {}, npc = { x = 900, y = 0, z = 0 }, currency = 'pesos', currencyForce = true })
check(table.concat(lastSent('fourriere:client:open', 1).args[1].methods, ',') == 'pesos', 'PNJ réglé « pesos uniquement » : appliqué')

print('— Véhicule détruit : réparation')
F.openFor(1, { kind = 'sea', spots = { { x = 950, y = 0, z = 0, h = 0, cls = 'boat' } }, npc = { x = 900, y = 0, z = 0 } })
Players[1].items.pesos = 5000
local okB1, msgB1, spB = F.retrieve(1, 'BOAT01', 'pesos')
check(okB1 and not spB and msgB1:find('Réparation'), 'bateau détruit : payé, pas de sortie, réparation lancée')
check(stateOf('BOAT01') == 4, 'state 4 (en réparation)')
local rep = q1("SELECT status, paid_amount, paid_currency, TIMESTAMPDIFF(SECOND, NOW(), repair_until) AS r FROM elyzea_fourriere WHERE plate = 'BOAT01'")
check(rep.status == 'repair' and rep.paid_currency == 'pesos' and rep.paid_amount == C.Prices.boat.destroyed, 'paiement enregistré (montant, monnaie)')
check(rep.r >= C.RepairMinutes * 60 - 5 and rep.r <= C.RepairMinutes * 60, ('fin de réparation enregistrée en base : dans %d s'):format(rep.r))
local okB2, msgB2 = F.retrieve(1, 'BOAT01', 'pesos')
check(not okB2 and msgB2:find('en réparation') and msgB2:find('min'), 'pendant la réparation : refus avec le temps restant')
local lst = F.list('CID_A')
local b for _, v in ipairs(lst) do if v.plate == 'BOAT01' then b = v end end
check(b and b.status == 'repair' and b.remain > 3500, 'liste : statut « en réparation » et temps restant')
check(F.repairDue() == 0 and stateOf('BOAT01') == 4, 'pas encore fini : rien ne change')

-- Hélico détruit à la fourrière aérienne (dollars, banque)
Players[1].pos = NPC_AIR
F.openFor(1, { kind = 'air', spots = {}, npc = { x = 500, y = 0, z = 0 } })
local okHe = F.retrieve(1, 'HELI01', 'bank')
check(okHe and stateOf('HELI01') == 4 and Players[1].money.bank == 20000 - C.Prices.heli.destroyed, 'hélico détruit : réparation payée en banque, aucune place de sortie nécessaire')

print('— Catégorie vérifiée sur le véhicule')
for e, v in pairs(Ents) do if v.plate == 'CAR001' or v.plate == 'MOTO01' then Ents[e] = nil end end   -- partis des places de sortie
Players[1].pos = NPC_LAND
F.openFor(1, { kind = 'land', spots = SPOTS_LAND, npc = { x = 100, y = 0, z = 0 } })
fire('fourriere:server:classify', 1, { OLD001 = 'car', CAR001 = 'boat' })
check(q1("SELECT vclass FROM player_vehicles WHERE plate = 'OLD001'").vclass == 'car', 'catégorie donnée par le client enregistrée seulement si elle manquait')
check(q1("SELECT vclass FROM player_vehicles WHERE plate = 'CAR001'").vclass == 'car', 'catégorie connue : le client ne peut pas la changer')
local cash0 = Players[1].money.cash
local okO, msgO = F.retrieve(1, 'OLD001', 'cash')
check(not okO and msgO:find('bateau') and msgO:find('remboursé') and Players[1].money.cash == cash0, 'catégorie fausse : véhicule réel = bateau, refusé et remboursé')
check(stateOf('OLD001') == 2 and q1("SELECT vclass FROM player_vehicles WHERE plate = 'OLD001'").vclass == 'boat', 'reste en fourrière, catégorie corrigée (boat)')
local nOld = 0 for _, v in pairs(Ents) do if v.model == 'speeder' then nOld = nOld + 1 end end
check(nOld == 0, 'le véhicule créé par erreur a été supprimé')

print('— Modèle absent du serveur')
veh('GONE01', 'modsupprime', 2, 'car')
py_insert("INSERT INTO elyzea_fourriere (plate, citizenid, model, vclass, destroyed, reason) VALUES ('GONE01', 'CID_A', 'modsupprime', 'car', 0, 'police')")
MISSING.modsupprime = true
local okG, msgG = F.retrieve(1, 'GONE01', 'cash')
check(okG and msgG:find('garage') and stateOf('GONE01') == 1, 'modèle introuvable : payé, véhicule rangé au garage (pas perdu)')

print('— Tirs en rafale (double clic)')
veh('FAST01', 'sultan', 2, 'car')
Players[1].money.cash = 600
F.openFor(1, { kind = 'land', spots = { { x = 140, y = 0, z = 0, h = 0, cls = 'car' }, { x = 150, y = 0, z = 0, h = 0, cls = 'car' } }, npc = { x = 100, y = 0, z = 0 } })
fire('fourriere:server:pay', 1, 'FAST01', 'cash')
F.openFor(1, { kind = 'land', spots = { { x = 160, y = 0, z = 0, h = 0, cls = 'car' } }, npc = { x = 100, y = 0, z = 0 } })
fire('fourriere:server:pay', 1, 'FAST01', 'cash')
check(Players[1].money.cash == 100, 'un seul paiement pour deux demandes')

print(('\nsim : %d ok, %d échec(s)'):format(Oks, Fails))
return Fails
