-- =====================================================================
--  Après « redémarrage » : nouvel état Lua, même base. La réparation
--  continue et se termine d'après la date enregistrée.
-- =====================================================================
loadResource('elyzea_change', { 'elyzea_change/config.lua', 'elyzea_change/server_payment.lua' })
local FR = loadResource('elyzea_fourriere', { 'elyzea_fourriere/config.lua', 'elyzea_fourriere/server/main.lua' })
local F, C = FR.F, FR.Config
local function stateOf(plate) local r = py_single('SELECT state FROM player_vehicles WHERE plate = ?', { plate }) return r and r.state end
print('\n— Redémarrage du serveur')
F.setup()
check(F.repairDue() == 0 and stateOf('BOAT01') == 4 and stateOf('HELI01') == 4, 'après redémarrage : toujours en réparation (temps non écoulé)')
local r = py_single("SELECT TIMESTAMPDIFF(SECOND, NOW(), repair_until) AS r FROM elyzea_fourriere WHERE plate = 'BOAT01'")
check(r.r > 3500, 'le temps restant est conservé en base')

-- 60 min plus tard (on avance la date de fin, comme si le temps était passé, joueur déconnecté)
py_update("UPDATE elyzea_fourriere SET repair_until = NOW() - INTERVAL 5 SECOND WHERE plate = 'BOAT01'")
check(F.repairDue() == 1, 'réparation terminée détectée (joueur hors ligne)')
check(stateOf('BOAT01') == 1, 'bateau rangé au garage (state 1)')
local pv = py_single("SELECT garage, engine, body, fuel, mods FROM player_vehicles WHERE plate = 'BOAT01'")
local m = json.decode(pv.mods)
check(pv.garage == C.ReturnGarage and m._garageName == C.ReturnGarageLabel.boat, 'retour au garage habituel (' .. m._garageName .. ')')
check(m.engineHealth == 1000 and m.bodyHealth == 1000 and m._deform == nil and next(m.tyres) == nil and m.color1 == 12, 'réparé à 100 % (moteur, carrosserie, déformations, pneus), couleurs gardées')
check(py_single("SELECT plate FROM elyzea_fourriere WHERE plate = 'BOAT01'") == nil, 'ligne de réparation supprimée')

-- Connexion du propriétaire : la réparation finie de l'hélico est appliquée et il est prévenu
py_update("UPDATE elyzea_fourriere SET repair_until = NOW() - INTERVAL 1 SECOND WHERE plate = 'HELI01'")
addPlayer(7, 'CID_A', 0, 0, 0, vector3(0, 0, 0))
TriggerEvent('elyzea:server:playerLoaded', 7)
check(stateOf('HELI01') == 1, 'à la connexion : hélico réparé et rangé')
local n = lastSent('fourriere:client:notify', 7)
check(n and n.args[1]:find('Réparation terminée'), 'joueur prévenu à la connexion')

-- Règles de paiement des autres commerces (elyzea_change)
print('\n— Règle de paiement des autres commerces')
local CH = Envs.elyzea_change
local P = CH.Pay
CH.Config.Payment.Businesses.Tatoueur = { Currency = 'pesos', ForceCurrency = true }
check(table.concat(P.methods(P.rule('Tatoueur'), { 'cash', 'bank' }), ',') == 'pesos', 'tatoueur forcé en pesos : pesos uniquement')
check(table.concat(P.methods(P.rule('Superette', { npcCurrency = 'pesos' }), { 'cash' }), ',') == 'pesos,cash', 'supérette : PNJ en pesos (non imposé) → pesos d\'abord, liquide accepté')
check(table.concat(P.methods(P.rule('Coiffeur'), { 'cash', 'bank' }), ',') == 'cash,bank,pesos', 'coiffeur par défaut : dollars + pesos')
check(table.concat(P.methods(P.rule('Vetements', { npcCurrency = 'money', npcForce = true }), { 'cash', 'bank' }), ',') == 'cash,bank', 'PNJ « dollars uniquement » : pas de pesos')
CH.Config.Payment.Enabled = false
check(table.concat(P.methods(P.rule('Tatoueur'), { 'cash' }), ',') == 'cash', 'système désactivé : dollars seulement')
CH.Config.Payment.Enabled = true
CH.Config.Payment.PesosRate = 1.5
check(P.priceIn('pesos', 101) == 152 and P.priceIn('cash', 101) == 101, 'taux pesos appliqué (arrondi au-dessus)')
addPlayer(8, 'CID_C', 50, 0, 10, vector3(0, 0, 0))
local ok, err = P.charge(8, 'Tatoueur', 10, 'cash')
check(not ok and err:find('que les pesos') and Players[8].money.cash == 50, 'tatoueur en pesos : paiement en liquide refusé')
ok, err = P.charge(8, 'Tatoueur', 10, 'pesos')
check(not ok and err:find('bureau de change') and Players[8].items.pesos == 10, 'pesos insuffisants (15 demandés) : refus, rien retiré')
Players[8].items.pesos = 20
local recu
ok, err, recu = P.charge(8, 'Tatoueur', 10, 'pesos')
check(ok and recu.paid == 15 and Players[8].items.pesos == 5, 'payé 15 pesos')
P.refund(8, recu)
check(Players[8].items.pesos == 20, 'remboursement exact')

-- Boutiques PNJ de admin_menu (supérette, armurerie, tatoueur, coiffeur, boutique, garage PNJ)
print('\n— admin_menu : paiement des PNJ commerçants (ShopPay)')
CH.Config.Payment.PesosRate = 1.0
CH.Config.Payment.Businesses.Tatoueur = { Currency = 'money', ForceCurrency = false }
local AM = setmetatable({}, { __index = _G })
AM.Bridge = {
    GetMoney = function(src, kind, item) if kind == 'item' then return Players[src].items[item] or 0 end return Players[src].money[kind] or 0 end,
    RemoveMoney = function(src, kind, item, n) if kind == 'item' then return Registry.elyzea_inventory.RemoveItem(src, item, n) end return Registry.elyzea_core.RemoveMoney(src, kind, n) end,
    AddMoney = function(src, kind, item, n) if kind == 'item' then return Registry.elyzea_inventory.AddItem(src, item, n) end return Registry.elyzea_core.AddMoney(src, kind, n) end,
    GetLabel = function(i) return ({ black_money = 'Argent sale', pesos = 'Pesos' })[i] or i end,
}
AM.exports = setmetatable({}, { __index = function(_, res) return setmetatable({}, { __index = function(_, f) return function(_, ...) return Registry[res][f](...) end end }) end })
assert(load(py_read('admin_menu/server/payment.lua'), '@payment.lua', 't', AM))()
local SP = AM.ShopPay
addPlayer(9, 'CID_D', 100, 1000, 50, vector3(0, 0, 0))
local npcCash = { payment = 'cash' }
local c1 = SP.ctx(9, 'Superette', npcCash, true)
check(table.concat(c1.methods, ',') == 'cash,bank,pesos', 'supérette (choix liquide/banque) : + pesos')
local okA, errA = SP.take(9, c1, 'pesos', 80, 'superette')
check(not okA and errA:find('pesos') and Players[9].items.pesos == 50, 'supérette : pesos insuffisants, refus, rien retiré')
local okB, _, paidB = SP.take(9, c1, 'pesos', 40, 'superette')
check(okB and paidB == 40 and Players[9].items.pesos == 10, 'supérette : payé 40 pesos')
local paidAfter = SP.refundPart(9, c1, 'pesos', 40, 25, 'remb')
check(paidAfter == 25 and Players[9].items.pesos == 25, 'inventaire plein pour une partie : 15 pesos rendus')
local c2 = SP.ctx(9, 'Tatoueur', { payment = 'cash', currency = 'pesos', currencyForce = true }, true)
check(table.concat(c2.methods, ',') == 'pesos' and SP.pick(c2, 'cash') == nil and SP.pick(c2, nil) == 'pesos', 'tatoueur réglé « pesos uniquement » sur le PNJ : liquide refusé')
local c3 = SP.ctx(9, 'BoutiquePNJ', { payment = 'item', paymentItem = 'black_money' }, false)
check(c3.legacy and c3.methods[1] == 'item', 'PNJ payé en argent sale : ancien fonctionnement conservé')
local c4 = SP.ctx(9, 'GaragePNJ', { payment = 'item', paymentItem = 'pesos' }, false)
check(table.concat(c4.methods, ',') == 'pesos', 'PNJ dont la monnaie objet est « pesos » : pesos uniquement via elyzea_change')
Started.elyzea_change = false
local c5 = SP.ctx(9, 'Coiffeur', npcCash, true)
check(c5.legacy and table.concat(c5.methods, ',') == 'cash,bank', 'elyzea_change arrêtée : liquide / banque comme avant')
local okC = SP.take(9, c5, 'bank', 300, 'coiffeur')
check(okC and Players[9].money.bank == 700, 'paiement banque sans elyzea_change')
Started.elyzea_change = true
CH.Config.Payment.Businesses.Armurerie = { Currency = 'pesos', ForceCurrency = true }
local c6 = SP.ctx(9, 'Armurerie', { payment = 'cash', currency = 'money', currencyForce = true }, true)
check(table.concat(c6.methods, ',') == 'pesos', 'armurerie imposée en pesos : le réglage du PNJ ne l\'emporte pas')
local pl = SP.payload(9, c1)
check(pl.payChoice and pl.wallet.pesos == 25 and pl.wallet.cash == 100, 'données envoyées à l\'interface : moyens + soldes')

print(('\nredémarrage : %d ok, %d échec(s)'):format(Oks, Fails))
return Fails
