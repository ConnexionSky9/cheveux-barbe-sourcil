local P = BHS
SIM.run(1000)
local b = P.S.banks[1]
local chk = SIM.check
chk(GlobalState.bhCfg ~= nil and GlobalState.bhBanks ~= nil, 'réglages publiés (bhCfg, bhBanks)')
chk(type(GlobalState.bhHour) == 'number', 'heure serveur publiée (bhHour)')
local function at(p, dx) return { x = p.x + (dx or 0), y = p.y, z = p.z } end
local ARMED = joaat('WEAPON_PISTOL')

-- ===== Guichet =====
print('\n# Guichet du banquier')
SIM.addPlayer(1, b.banker.x + 1, b.banker.y, b.banker.z, { cash = 10000, bank = 5000, name = 'Alice' })
SIM.addPlayer(2, 0, 0, 0, { cash = 0, bank = 100, name = 'Bob' })
local r = SIM.req(1, 'bankOpen', { bank = b.id })
chk(r.ok and r.balance == 5000 and r.cash == 10000 and r.account:find('FR76 ELYZ') and r.phone == '5550001', 'ouverture : solde, liquide, numéro de compte, téléphone')
r = SIM.req(1, 'bankDeposit', { bank = b.id, amount = 3000 })
chk(r.ok and r.balance == 8000 and r.cash == 7000 and r.message, 'dépôt 3 000 $ → compte 8 000 $, liquide 7 000 $')
chk(#r.history >= 1 and r.history[1].amount == 3000, 'historique : dépôt enregistré')
r = SIM.req(1, 'bankWithdraw', { bank = b.id, amount = 99999 })
chk(r.error == 'Solde insuffisant.', 'retrait supérieur au solde refusé')
r = SIM.req(1, 'bankWithdraw', { bank = b.id, amount = -50 })
chk(r.error ~= nil and SIM.players[1].bank == 8000, 'montant négatif refusé')
r = SIM.req(1, 'bankWithdraw', { bank = b.id, amount = 1000 })
chk(r.ok and r.balance == 7000 and r.cash == 8000, 'retrait 1 000 $')
r = SIM.req(1, 'bankTransfer', { bank = b.id, amount = 500, number = '555 0002' })
chk(r.ok and SIM.players[2].bank == 600 and SIM.players[1].bank == 6500, 'virement 500 $ vers un joueur en ligne (numéro avec espace)')
r = SIM.req(1, 'bankTransfer', { bank = b.id, amount = 500, number = '5550001' })
chk(r.error and SIM.players[1].bank == 6500, 'virement à soi-même refusé')
r = SIM.req(1, 'bankTransfer', { bank = b.id, amount = 500, number = '0000000' })
chk(r.error == 'Aucun compte à ce numéro.', 'numéro inconnu refusé')
SIM.move(2, { x = 500, y = 500, z = 0 })
r = SIM.req(2, 'bankOpen', { bank = b.id })
chk(r.error == 'Approchez-vous du guichet.', 'guichet à distance refusé')

-- ===== Indic =====
print('\n# Indic')
local n = P.S.informants[1]
SIM.move(1, at(n.ped, 1))
r = SIM.req(1, 'infoTalk', { id = n.id })
chk(r.ok and r.price == 750 and r.hasMerchant == true and r.greeting, 'dialogue : prix, accueil, marchand disponible')
local cashBefore = SIM.players[1].cash
r = SIM.req(1, 'infoPay', { id = n.id })
chk(r.ok and r.merchant and r.merchant.x == P.S.merchants[1].ped.x and r.minutes == n.blipMinutes and SIM.players[1].cash == cashBefore - 750, 'paiement 750 $ → position du marchand + durée du repère')
r = SIM.req(1, 'infoPay', { id = n.id })
chk(r.error and r.error:find('Reviens dans') and SIM.players[1].cash == cashBefore - 750, 'deuxième paiement : délai, rien débité')
SIM.players[1].police = true
r = SIM.req(1, 'infoTalk', { id = n.id })
chk(r.error and r.error:find('flics'), 'policier en service : refusé')
SIM.players[1].police = false

-- ===== Marchand =====
print('\n# Marchand')
local m = P.S.merchants[1]
SIM.move(1, at(m.ped, 1))
SIM.players[1].cash = 100000
r = SIM.req(1, 'shopData', { merchant = m.id })
local hasDrill = false
for _, it in ipairs(r.list or {}) do if it.id == 'drill' then hasDrill = true end end
chk(r.ok and hasDrill, 'boutique : la perceuse est en vente')
r = SIM.req(1, 'shopBuy', { merchant = m.id, item = 'drill' })
chk(r.ok and SIM.players[1].inv.bank_drill == 1 and SIM.players[1].cash == 100000 - 18000, 'achat de la perceuse (18 000 $)')
r = SIM.req(1, 'shopBuy', { merchant = m.id, item = 'drill' })
chk(r.error and SIM.players[1].inv.bank_drill == 1, 'possession max. respectée')

-- ===== Braquage =====
print('\n# Braquage (banquier, alarme, police)')
for i = 11, 13 do SIM.addPlayer(i, 3000, 3000, 0, { police = true, name = 'Flic' .. i }) end
SIM.players[1].inv.bank_laptop = 1 SIM.players[1].inv.bank_bag = 1 SIM.players[1].inv.bank_c4 = 1
SIM.move(1, at(b.banker, 1.5))
SIM.addPlayer(3, b.banker.x + 2, b.banker.y + 1, b.banker.z, { name = 'Chloé' })
SIM.players[3].inv.bank_bag = 1
r = SIM.req(1, 'rob', { bank = b.id })
chk(r.error == 'Il vous faut une arme en main.', 'sans arme : refusé')
SIM.players[1].weapon = ARMED
SIM.players[11].pos = vector3(b.banker.x + 1, b.banker.y + 1, b.banker.z)
SIM.players[11].weapon = ARMED
r = SIM.req(11, 'rob', { bank = b.id })
chk(r.error == 'Pas en service de police.', 'policier : refusé')
SIM.players[11].pos = vector3(3000, 3000, 0)
local alerts = #SIM.alerts
r = SIM.req(1, 'rob', { bank = b.id })
chk(r.ok, 'BRAQUER LA BANQUE : lancé')
local s = P.sessions[b.id]
chk(s and s.participants[1] and s.participants[3] and not s.participants[11], 'braqueurs : Alice + Chloé (pas les policiers)')
chk(#SIM.alerts == alerts + 1 and SIM.alerts[#SIM.alerts].c.x == b.doorPoint.x, 'police prévenue avec la position de la banque')
chk(SIM.evt('bh:client:robStart', 1) ~= nil and SIM.evt('bh:client:robStart', 3) ~= nil, 'bandeau « braquage en cours » envoyé aux braqueurs')
local hb = GlobalState.bhBanks[b.id]
chk(hb.phase == 'active' and hb.alarm == true and hb.door == 'locked' and hb.handsUp == true, 'état public : actif, alarme, porte verrouillée, banquier mains en l\'air')
local hud = SIM.evt('bh:client:hud', 1)
chk(hud and hud.args[1].alarm == true and hud.args[1].total == 0, 'HUD envoyé (alarme, butin 0)')
r = SIM.req(2, 'bankOpen', { bank = b.id })
chk(r.error and r.error:find('braquage'), 'guichet fermé pendant le braquage')
r = SIM.req(1, 'rob', { bank = b.id })
chk(r.error ~= nil, 'deuxième lancement refusé')

-- ===== Décryptage =====
print('\n# Porte : décryptage')
SIM.move(1, at(b.doorPoint, 0.5))
r = SIM.req(1, 'hackStart', { bank = b.id })
chk(r.error == 'Le banquier n\'est pas encore à terre.', 'décryptage avant que le banquier soit à terre : refusé')
SIM.run(b.threatTime * 1000 + 1500)
chk(GlobalState.bhBanks[b.id].handsUp ~= true, 'banquier à genoux après le délai')
for _, g in ipairs(Config.GameList) do P.S.hack.games[g].enabled = (g == 'sequence') end
r = SIM.req(1, 'hackStart', { bank = b.id })
chk(r.ok and r.game == 'sequence' and r.attemptsLeft == 2, 'décryptage lancé (tentative consommée : 2/3)')
chk(GlobalState.bhBanks[b.id].door == 'hacking', 'porte : décryptage en cours')
r = SIM.req(1, 'hackSubmit', { answer = { seq = { 0 } } })
chk(r.done and r.success == false and P.sessions[b.id].door == 'locked', 'mauvaise réponse : échec, porte verrouillée')
r = SIM.req(1, 'hackStart', { bank = b.id })
chk(r.error and r.error:find('redémarre'), 'délai entre deux tentatives')
SIM.run(P.S.hack.retryDelay * 1000 + 1000)
r = SIM.req(1, 'hackStart', { bank = b.id })
chk(r.ok and r.attemptsLeft == 1, 'deuxième tentative (1/3)')
local secret = P.hacks[1].secret
r = SIM.req(1, 'hackSubmit', { answer = { seq = secret.seq } })
chk(r.done and r.success == true, 'bonne réponse : réussi')
s = P.sessions[b.id]
chk(s.door == 'open' and s.initialPool > 0, ('porte ouverte · butin tiré : %d $'):format(s.initialPool or 0))
chk(SIM.evt('bh:client:doorOpen', 1) ~= nil, 'effet « coffre ouvert » envoyé')
local okPts = true
for i, p in ipairs(b.loot) do local sp = s.points[i] if sp.left < p.min * 0.69 or sp.left > p.max * 1.31 then okPts = false end end
chk(okPts, 'chaque point a son montant (min/max, bonus/malus)')

-- ===== Alarme =====
print('\n# Alarme (fils)')
SIM.move(3, at(b.alarm, 0.5))
r = SIM.req(3, 'alarmStart', { bank = b.id })
chk(r.ok and r.game and #r.game.wires == 5 and r.game.target, 'boîtier : 5 fils + étiquette')
local function solve(g)
  local green, col = {}, {}
  for i, w in ipairs(g.wires) do if w.led == 'verte' then green[#green + 1] = i elseif w.color == g.target then col[#col + 1] = i end end
  table.sort(green, function(a, c) return g.wires[a].num < g.wires[c].num end)
  table.sort(col, function(a, c) return g.wires[a].num > g.wires[c].num end)
  local o = {} for _, i in ipairs(green) do o[#o + 1] = i end for _, i in ipairs(col) do o[#o + 1] = i end return o
end
local good = solve(r.game)
local bad = { table.unpack(good) } bad[1], bad[#bad] = bad[#bad], bad[1]
if #bad == 1 then bad[1] = (bad[1] % 5) + 1 end
alerts = #SIM.alerts
r = SIM.req(3, 'alarmSubmit', { cuts = bad })
chk(r.done and r.success == false and P.sessions[b.id].alarm == true and #SIM.alerts == alerts + 1, 'mauvais fil : échec + nouvelle alerte police')
r = SIM.req(3, 'alarmStart', { bank = b.id })
r = SIM.req(3, 'alarmSubmit', { cuts = solve(r.game) })
chk(r.done and r.success == true and P.sessions[b.id].alarm == false, 'règle appliquée (même que l\'interface) : alarme coupée')
chk(GlobalState.bhBanks[b.id].alarm == false, 'état public : alarme coupée (sirène arrêtée chez les clients)')

-- ===== Butin =====
print('\n# Butin (chariots, perceuse, sac)')
local p1 = b.loot[1]
SIM.move(1, at(p1, 0.4))
r = SIM.req(1, 'collectStart', { bank = b.id, point = 1 })
chk(r.ok and r.anim == 'trolley' and SIM.players[1].bag and SIM.players[1].inv.bank_bag == 0, 'chariot : collecte lancée, sac sorti de l\'inventaire')
SIM.move(3, at(p1, 0.6))
r = SIM.req(3, 'collectStart', { bank = b.id, point = 1 })
chk(r.error and r.error:find('déjà'), 'même chariot par un 2e braqueur : refusé')
SIM.run(3200)
local bag = SIM.players[1].bag
chk(bag.money >= 3 * P.S.loot.perTick and bag.money <= 4 * P.S.loot.perTick and bag.money % P.S.loot.perTick == 0, ('~3 s → %d $ dans le sac (tranches de 5 000 $)'):format(bag.money))
local g = SIM.evt('bh:client:grabbed', 1)
chk(g and g.args[1] == P.S.loot.perTick, 'événement « +5 000 $ » (HUD)')
hud = SIM.evt('bh:client:hud', 1)
print('    HUD', hud.args[1].total, hud.args[1].mine, bag.money)
chk(hud and hud.args[1].total == bag.money and hud.args[1].mine == bag.money and hud.args[1].door == 'open', 'HUD : butin de l\'équipe = ma part = sac')
local p3 = b.loot[3]
SIM.move(3, at(p3, 0.4))
r = SIM.req(3, 'collectStart', { bank = b.id, point = 3 })
chk(r.error and r.error:find('Percez'), 'coffres individuels : perceuse d\'abord')
r = SIM.req(3, 'drillStart', { bank = b.id, point = 3 })
chk(r.error and r.error:find('Perceuse'), 'sans perceuse : refusé')
SIM.players[3].inv.bank_drill = 1
r = SIM.req(3, 'drillStart', { bank = b.id, point = 3 })
chk(r.ok and r.time == P.S.drill.time, 'perçage lancé')
SIM.run(3000)
r = SIM.req(3, 'drillDone', {})
chk(r.error and r.error:find('pas terminé'), 'perçage terminé trop vite : refusé (anti-triche)')
r = SIM.req(3, 'drillStart', { bank = b.id, point = 3 })
SIM.run(P.S.drill.time * 1000 + 200)
r = SIM.req(3, 'drillDone', {})
chk(r.ok, 'perçage terminé après la durée réglée')
r = SIM.req(3, 'collectStart', { bank = b.id, point = 3 })
chk(r.ok and r.anim == 'drill', 'coffres percés : collecte possible')
SIM.run(60000)
s = P.sessions[b.id]
local tot = 0
for id in pairs(SIM.players) do local bg = SIM.players[id].bag if bg then tot = tot + bg.money end end
if s then chk(s.distributed == tot, ('total ramassé = contenu des sacs (%d $)'):format(tot)) end
chk(tot <= (s and s.initialPool or tot), 'jamais plus que le butin tiré')

-- ===== Encaissement =====
print('\n# Encaissement')
local dp = P.S.deposits[1]
local money1 = SIM.players[1].bag.money
SIM.move(1, at(dp, 0.5))
r = SIM.req(1, 'deposit', { deposit = dp.id })
chk(r.ok and SIM.players[1].black == money1 and SIM.players[1].bag == nil, ('sac encaissé : %d $ d\'argent sale'):format(money1))

-- ===== Fin, abandon =====
SIM.move(3, { x = 4000, y = 4000, z = 0 })
SIM.run((P.S.general.abandonMinutes + 1) * 60000)
chk(P.sessions[b.id] == nil, 'braquage terminé (coffre vidé, refermé ou abandonné)')
hud = SIM.evt('bh:client:hud', 3)
chk(hud and hud.args[1] == false, 'HUD retiré à la fin')
chk(GlobalState.bhBanks[b.id].phase == 'cooldown', 'banque en délai après le braquage')

-- ===== C4 =====
print('\n# Porte : C4')
P.cooldown[b.id] = 0 P.globalUntil = 0
SIM.players[1].inv.bank_bag = 1
SIM.move(1, at(b.banker, 1)) SIM.move(3, at(b.banker, 2))
r = SIM.req(1, 'rob', { bank = b.id })
chk(r.ok, 'nouveau braquage lancé')
SIM.move(1, at(b.doorPoint, 0.3))
r = SIM.req(1, 'c4Plant', { bank = b.id })
chk(r.ok and r.delay == P.S.c4.delay and SIM.players[1].inv.bank_c4 == 0, 'C4 posée (consommée)')
chk(GlobalState.bhBanks[b.id].door == 'c4', 'porte : charge armée (bips côté client)')
r = SIM.req(1, 'hackStart', { bank = b.id })
chk(r.error and r.error:find('C4'), 'décryptage impossible pendant la charge')
alerts = #SIM.alerts
SIM.run(P.S.c4.delay * 1000 + 1500)
chk(SIM.evt('bh:client:explode', -1) ~= nil, 'explosion envoyée à tous (effet, fumée, secousse)')
chk(P.sessions[b.id] and P.sessions[b.id].door == 'open', 'porte soufflée : coffre ouvert')
chk(#SIM.alerts == alerts + 1, 'explosion : 2e alerte police')

-- ===== Police coupe l'alarme =====
SIM.move(11, at(b.alarm, 0.3))
r = SIM.req(11, 'alarmStart', { bank = b.id })
chk(r.ok and r.done and P.sessions[b.id].alarm == false, 'policier en service : alarme coupée directement')

-- ===== Admin =====
print('\n# Admin')
local data = SIM.exportsT.AdminData()
chk(data.available and data.banks[b.id].session and data.banks[b.id].session.door == 'open' and data.lootTypeList and #data.defaults.informants == 1, 'AdminData : session (porte), types de butin, défauts (indics)')
local draft = BH.Copy(P.S)
SIM.move(1, { x = 150.0, y = -1048.0, z = 29.35 })
local ok, msg = SIM.exportsT.AdminAction(1, 'place', { draft = draft, target = 'bank', what = 'loot', index = 1, lootType = 'trolley_gold' })
chk(ok and #P.S.banks[1].loot == 4 and P.S.banks[1].loot[4].type == 'trolley_gold', 'admin : point de butin « chariot de lingots » ajouté à la position')
draft = BH.Copy(P.S)
SIM.move(1, { x = 151.0, y = -1049.0, z = 29.35 })
ok = SIM.exportsT.AdminAction(1, 'place', { draft = draft, target = 'bank', what = 'loot', index = 1, lootIndex = 4 })
chk(ok and math.abs(P.S.banks[1].loot[4].x - 151.0) < 0.01, 'admin : point déplacé')
draft = BH.Copy(P.S)
draft.banks[1].loot[4].type = 'hack'
draft.banks[1].loot[4].min = -5
draft.banks[1].required.tool = 'nimportequoi'
draft.door.openTime = 9999
SIM.exportsT.AdminAction(1, 'save', draft)
chk(P.S.banks[1].loot[4].type ~= 'hack' and P.S.banks[1].loot[4].min >= 0 and P.S.banks[1].required.tool == 'any' and P.S.door.openTime <= 30, 'admin : valeurs invalides corrigées par le serveur')
draft = BH.Copy(P.S)
SIM.move(1, { x = 10, y = 20, z = 30 })
ok = SIM.exportsT.AdminAction(1, 'place', { draft = draft, target = 'informant', what = 'ped', index = 1 })
chk(ok and P.S.informants[1].ped.x == 10, 'admin : indic placé')
ok = SIM.exportsT.AdminAction(1, 'cancel', { bank = b.id })
chk(ok and P.sessions[b.id] == nil, 'admin : braquage annulé')
