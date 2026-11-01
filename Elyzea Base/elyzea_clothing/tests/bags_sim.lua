-- Simulation des sacs de shopping (lancée par run_bags_sim.py après bags_mocks.lua et les vrais fichiers serveur)
local fails, passes = 0, 0
local function check(c, l) if c then passes = passes + 1 io.write('  ok   ', l, '\n') else fails = fails + 1 io.write('  ÉCHEC ', l, '\n') end end
local function section(t) io.write('\n[', t, ']\n') end
local function lastTo(ev, target)
    for i = #SENT, 1, -1 do if SENT[i].ev == ev and (not target or SENT[i].target == target) then return SENT[i] end end
end
local function notes(target)
    local t = {}
    for _, s in ipairs(SENT) do if s.ev == 'elyzea_clothing:notify' and s.target == target then t[#t + 1] = s.args[1] end end
    return table.concat(t, ' | ')
end
local function result() local r = lastTo('elyzea_clothing:result') return r and r.args[1], r and r.args[2], r and r.args[3] end
local function bagsOf(h)
    local out = {}
    for i = 1, (INVS[h] and INVS[h].size or 0) do
        local it = INVS[h].slots[i]
        if it and Bags.ITEM_COLOR[it.name] then out[#out + 1] = { item = it.name, id = it.metadata.bag, md = it.metadata } end
    end
    return out
end
local function clothesOf(h)
    local n = 0
    for i = 1, (INVS[h] and INVS[h].size or 0) do local it = INVS[h].slots[i] if it and it.name:sub(1, 4) == 'vet_' then n = n + 1 end end
    return n
end
local function dbRow(id) return py_single('SELECT * FROM `elyzea_shopping_bags` WHERE `id` = ?', { id }) end
local function dbCount() return py_scalar('SELECT COUNT(*) FROM `elyzea_shopping_bags`') end
local function open(src, color)
    Shop.sessions[src] = { shop = { name = 'Ponsonbys', multiplier = 100, categories = { 'tops', 'pants', 'shoes', 'hats' }, packs = 'all', bagColor = color }, coords = vector3(0, 0, 0) }
end
local price = function(cat) return Cat[cat].price end
Config.Items.enabled = true
math.randomseed(42)
local function step() NOW = NOW + 1000 end   -- anti-spam (400 ms) entre deux demandes

-- Joueurs
CID[1], CID[2], CID[3] = 'CIT001', 'CIT002', 'CIT003'
POS[1], POS[2], POS[3] = vector3(0, 0, 0), vector3(1, 0, 0), vector3(40, 0, 0)

-- =========================================================
section('Achat avec un sac')
MONEY[1] = 10000
open(1, 'rose')
local cart = {
    { cat = 'tops', drawable = 20, texture = 0 }, { cat = 'tops', drawable = 21, texture = 1 },
    { cat = 'pants', drawable = 4, texture = 0 },
}
FIRE('elyzea_clothing:buy', 1, cart, 'cash', false, {}, true)
local ok, msg, extra = result()
local cost = price('tops') * 2 + price('pants')
check(ok == true and MONEY[1] == 10000 - cost, ('payé : %d $ (%s)'):format(cost, tostring(msg)))
local bags = bagsOf(1)
check(#bags == 1 and bags[1].item == 'sac_shopping_rose', 'un sac ROSE (couleur de la boutique) dans l\'inventaire')
check(clothesOf(1) == 0, 'aucun vêtement directement dans l\'inventaire')
check(extra and extra.bags == 1 and tostring(msg):find('sac'), 'message : vêtements dans le sac')
local id = bags[1].id
local row = dbRow(id)
local items = row and json.decode(row.items) or {}
check(row and #items == 3 and row.owner == 'CIT001' and row.buyer == 'CIT001' and row.color == 'rose' and row.shop == 'Ponsonbys',
    'sac enregistré en base : 3 vêtements, propriétaire, acheteur, couleur, boutique')
check(items[1].name == 'vet_haut' and items[1].md.drawable == 20 and items[3].name == 'vet_pantalon', 'contenu : les vrais objets vêtements (modèle, coloris)')
check(bags[1].md.label:find('Sac rose') and bags[1].md.count == 3, 'nom du sac dans l\'inventaire : « ' .. tostring(bags[1].md.label) .. ' »')

section('Achat sans sac (inchangé)')
step()
MONEY[2] = 10000
open(2, 'rose')
FIRE('elyzea_clothing:buy', 2, { { cat = 'shoes', drawable = 3, texture = 0 } }, 'cash', false, {}, false)
ok = result()
check(ok and #bagsOf(2) == 0 and clothesOf(2) == 1, 'vêtement directement dans l\'inventaire, aucun sac')

section('Beaucoup d\'articles : plusieurs sacs')
step()
MONEY[3] = 100000
POS[3] = vector3(0, 0, 0)
open(3, nil)
local big = {}
for i = 1, 8 do big[#big + 1] = { cat = 'tops', drawable = 100 + i, texture = 0 } end
FIRE('elyzea_clothing:buy', 3, big, 'cash', false, {}, true)
ok, msg = result()
local b3 = bagsOf(3)
check(ok and #b3 == 2, ('8 vêtements → 2 sacs (%d par sac)'):format(Config.Bags.perBag))
check(b3[1].item == b3[2].item, 'même couleur pour les sacs d\'un même achat (' .. tostring(b3[1].item) .. ')')
local n1 = #json.decode(dbRow(b3[1].id).items)
local n2 = #json.decode(dbRow(b3[2].id).items)
check(n1 + n2 == 8 and b3[1].id ~= b3[2].id, ('contenus indépendants : %d + %d, identifiants uniques'):format(n1, n2))

section('Inventaire trop petit : refusé AVANT de payer')
step()
MONEY[4] = 5000
CID[4] = 'CIT004'
INVS[4] = { slots = {}, size = 1 }
INV.AddItem(nil, 4, 'pain', 1, {})
open(4, 'bleu')
FIRE('elyzea_clothing:buy', 4, { { cat = 'tops', drawable = 1, texture = 0 } }, 'cash', false, {}, true)
ok, msg = result()
check(ok == false and MONEY[4] == 5000 and dbCount() == 3, 'refusé, rien débité, aucun sac créé (' .. tostring(msg) .. ')')

-- =========================================================
section('Ouvrir un sac (objet utilisé)')
step()
USABLE.sac_shopping_rose(1, { name = 'sac_shopping_rose', metadata = { bag = id } })
local v = lastTo('elyzea_clothing:bagView', 1)
local view = v and v.args[1]
check(view and view.id == id and view.total == 3 and #view.items == 3, 'fenêtre : 3 vêtements listés')
check(view and view.items[1].label and view.items[1].qty == 1 and view.hex == Config.Bags.colors.rose.hex, 'nom, quantité et couleur du sac envoyés')
USABLE.sac_shopping_rose(2, { name = 'sac_shopping_rose', metadata = { bag = id } })
check(notes(2):find('plus sur toi'), 'un autre joueur ne peut pas ouvrir un sac qu\'il n\'a pas')

section('Récupérer un vêtement')
step()
FIRE('elyzea_clothing:bagTake', 1, id, 1, 1)
check(clothesOf(1) == 1 and #json.decode(dbRow(id).items) == 2, '1 vêtement sorti du sac → inventaire ; il en reste 2 en base')
check(bagsOf(1)[1].md.count == 2 and bagsOf(1)[1].md.label:find('%(2%)'), 'le sac affiche maintenant 2 vêtements')
local vv = lastTo('elyzea_clothing:bagView', 1).args[1]
check(vv.total == 2, 'fenêtre actualisée tout de suite (2)')

section('Anti-duplication : copie du sac')
step()
-- un tricheur obtient une 2e copie de l'objet sac (même identifiant)
INV.AddItem(nil, 1, 'sac_shopping_rose', 1, bagsOf(1)[1].md)
FIRE('elyzea_clothing:bagTake', 1, id, 'all')
local after = clothesOf(1)
check(after == 3, 'tout récupéré : 3 vêtements au total (le contenu n\'existe qu\'une fois)')
check(dbRow(id) == nil, 'sac vide : supprimé de la base')
step()
FIRE('elyzea_clothing:bagTake', 1, id, 'all')
USABLE.sac_shopping_rose(1, { name = 'sac_shopping_rose', metadata = { bag = id } })
check(clothesOf(1) == 3, 'la copie ne redonne rien')
check(#bagsOf(1) == 0, 'copie inutile retirée de l\'inventaire à l\'ouverture')

section('Demandes truquées')
step()
FIRE('elyzea_clothing:bagTake', 2, b3[1].id, 'all')
check(clothesOf(2) == 1 and #json.decode(dbRow(b3[1].id).items) == n1, 'vider le sac de quelqu\'un d\'autre : refusé')
step()
FIRE('elyzea_clothing:bagTake', 3, "x' OR 1=1 --", 'all')
step()
FIRE('elyzea_clothing:bagTake', 3, b3[1].id, 999)
check(#json.decode(dbRow(b3[1].id).items) == n1, 'identifiant ou n° de vêtement invalide : rien ne sort')

section('Inventaire plein pendant la récupération')
step()
INVS[3].size = #bagsOf(3) + 1   -- une seule place libre
FIRE('elyzea_clothing:bagTake', 3, b3[1].id, 'all')
check(clothesOf(3) == 1 and #json.decode(dbRow(b3[1].id).items) == n1 - 1, 'une place : 1 vêtement sorti, le reste reste dans le sac')
check(notes(3):find('plein'), 'message « inventaire plein »')
INVS[3].size = 20

-- =========================================================
section('Ranger dans le coffre (ALT)')
step()
VEH[10] = { plate = 'ELY 123', dist = 2.0, locked = false, size = 3 }
local bagA = b3[1].id
FIRE('elyzea_clothing:bagStore', 3, bagA, 10, 1)
check(#bagsOf(3) == 1 and #bagsOf('trunk:ELY 123') == 1 and bagsOf('trunk:ELY 123')[1].id == bagA, 'sac retiré des mains, présent dans le coffre « trunk:ELY 123 »')
check(dbRow(bagA).location == 'trunk:ELY 123', 'emplacement enregistré : coffre')
check(#json.decode(dbRow(bagA).items) == n1 - 1, 'contenu conservé')
step()
FIRE('elyzea_clothing:bagStore', 3, bagA, 10, 1)
check(notes(3):find('plus sur toi'), 'ranger un sac qu\'on n\'a plus : refusé')
step()
VEH[11] = { plate = 'LOCK 1', dist = 2.0, locked = true, keys = false }
FIRE('elyzea_clothing:bagStore', 3, b3[2].id, 11, 1)
check(#bagsOf(3) == 1 and notes(3):find('verrouillé'), 'véhicule verrouillé sans clés : refusé (règle du coffre existant)')
step()
VEH[12] = { plate = 'FAR 1', dist = 9.0, locked = false }
FIRE('elyzea_clothing:bagStore', 3, b3[2].id, 12, 1)
check(#bagsOf(3) == 1, 'trop loin du véhicule : refusé')
step()
VEH[13] = { plate = 'FULL 1', dist = 1.0, locked = false, size = 1 }
INV.AddItem(nil, 'trunk:FULL 1', 'jerrycan', 1, {})
FIRE('elyzea_clothing:bagStore', 3, b3[2].id, 13, 1)
check(#bagsOf(3) == 1 and #bagsOf('trunk:FULL 1') == 0 and notes(3):find('plein'), 'coffre plein (capacité du coffre) : le sac reste en main')

section('Reprendre du coffre (ALT)')
step()
FIRE('elyzea_clothing:bagTrunkList', 3, 10, 1)
local pick = lastTo('elyzea_clothing:bagPick', 3)
check(pick and #pick.args[1].bags == 1 and pick.args[1].bags[1].id == bagA, 'liste des sacs du coffre envoyée pour choisir')
step()
FIRE('elyzea_clothing:bagTrunkTake', 3, b3[2].id, 10, 1)
check(notes(3):find('pas dans ce coffre') and #bagsOf(3) == 1, 'reprendre un sac qui n\'est pas dans ce coffre : refusé')
step()
FIRE('elyzea_clothing:bagTrunkTake', 3, bagA, 10, 1)
check(#bagsOf(3) == 2 and #bagsOf('trunk:ELY 123') == 0, 'sac repris : de nouveau en main, plus dans le coffre')
check(dbRow(bagA).location == 'player:CIT003', 'emplacement enregistré : joueur')
step()
FIRE('elyzea_clothing:bagTrunkTake', 3, bagA, 10, 1)
check(#bagsOf(3) == 2, 'le reprendre une 2e fois : impossible (pas de duplication)')

section('Après un redémarrage (sauvegarde)')
step()
FIRE('elyzea_clothing:bagStore', 3, bagA, 10, 1)
-- le serveur redémarre : le cache des sacs est perdu, seule la base reste
assert(load(BAGS_SRC, '@server/bags.lua'))()
for item in pairs(Bags.ITEM_COLOR) do end
step()
FIRE('elyzea_clothing:bagTrunkTake', 3, bagA, 10, 1)
USABLE = USABLE   -- les objets utilisables sont ré-enregistrés au démarrage
step()
FIRE('elyzea_clothing:bagTake', 3, bagA, 'all')
check(dbRow(bagA) == nil and clothesOf(3) == n1, 'contenu relu en base après redémarrage et récupéré en entier')

-- =========================================================
section('Offrir un sac')
step()
local gid = b3[2].id
local gcount = #json.decode(dbRow(gid).items)
POS[2] = vector3(1, 0, 0)
FIRE('elyzea_clothing:bagGift', 3, gid, 2)
local ask = lastTo('elyzea_clothing:bagGiftAsk', 2)
check(ask and ask.args[1].from == 'Perso 3' and ask.args[1].count == gcount, 'le destinataire reçoit la demande avec le nom de celui qui offre')
step()
FIRE('elyzea_clothing:bagGift', 3, gid, 2)
check(notes(3):find('attends déjà'), 'pas deux cadeaux en même temps')
FIRE('elyzea_clothing:bagGiftAnswer', 2, false)
check(#bagsOf(3) == 1 and #bagsOf(2) == 0 and notes(3):find('refusé'), 'refusé : le sac reste au donneur, il est prévenu')
step()
FIRE('elyzea_clothing:bagGift', 3, gid, 2)
FIRE('elyzea_clothing:bagGiftAnswer', 2, true)
check(#bagsOf(3) == 0 and #bagsOf(2) == 1 and bagsOf(2)[1].id == gid, 'accepté : le sac complet passe chez le destinataire')
check(#json.decode(dbRow(gid).items) == gcount and dbRow(gid).owner == 'CIT002' and dbRow(gid).buyer == 'CIT003', 'contenu identique ; nouveau propriétaire, acheteur conservé')
check(lastTo('elyzea_clothing:bagGiftDone', 2) ~= nil, 'animation de remise des deux côtés')
step()
USABLE[bagsOf(2)[1].item](2, { name = bagsOf(2)[1].item, metadata = { bag = gid } })
FIRE('elyzea_clothing:bagTake', 2, gid, 'all')
check(clothesOf(2) == 1 + gcount and dbRow(gid) == nil, 'le destinataire ouvre le sac et récupère les vêtements sans les avoir achetés')

section('Cadeau : contrôles')
step()
MONEY[1] = 10000
open(1, 'violet')
FIRE('elyzea_clothing:buy', 1, { { cat = 'hats', drawable = 5, texture = 0 } }, 'cash', false, {}, true)
local hid = bagsOf(1)[1].id
step()
POS[2] = vector3(30, 0, 0)
FIRE('elyzea_clothing:bagGift', 1, hid, 2)
check(lastTo('elyzea_clothing:bagGiftAsk', 2) == ask or notes(1):find('Approche'), 'trop loin : pas de demande')
POS[2] = vector3(1, 0, 0)
step()
Player(2).state.cuffed = true
FIRE('elyzea_clothing:bagGift', 1, hid, 2)
check(notes(1):find('menotté'), 'destinataire menotté : refusé')
Player(2).state.cuffed = nil
step()
FIRE('elyzea_clothing:bagGift', 1, hid, 1)
step()
FIRE('elyzea_clothing:bagGift', 1, 'B000000', 2)
check(#bagsOf(2) == 0, 's\'offrir à soi-même ou offrir un sac qu\'on n\'a pas : refusé')
step()
FIRE('elyzea_clothing:bagGift', 1, hid, 2)
ADVANCE(Config.Bags.giftTimeout * 1000 + 10)
FIRE('elyzea_clothing:bagGiftAnswer', 2, true)
check(#bagsOf(1) == 1 and #bagsOf(2) == 0 and notes(1):find('Pas de réponse'), 'expiré : accepter trop tard ne fait rien')
step()
FIRE('elyzea_clothing:bagGift', 1, hid, 2)
-- inventaire du destinataire rempli (objets de remplissage dans chaque case libre)
local fill = {}
for i = 1, INVS[2].size do if not INVS[2].slots[i] then INVS[2].slots[i] = { name = 'caillou', count = 1, metadata = {} } fill[#fill + 1] = i end end
FIRE('elyzea_clothing:bagGiftAnswer', 2, true)
check(#bagsOf(1) == 1 and #bagsOf(2) == 0 and notes(1):find('plein'), 'inventaire du destinataire plein : le sac reste au donneur')
for _, i in ipairs(fill) do INVS[2].slots[i] = nil end
step()
FIRE('elyzea_clothing:bagGift', 1, hid, 2)
FIRE('playerDropped', 1)
FIRE('elyzea_clothing:bagGiftAnswer', 2, true)
check(#bagsOf(2) == 0 and lastTo('elyzea_clothing:bagGiftEnd', 2) ~= nil, 'donneur déconnecté : cadeau annulé, rien transféré')
step()
FIRE('elyzea_clothing:bagGift', 1, hid, 2)
INV.RemoveItem(nil, 1, bagsOf(1)[1].item, 1, { bag = hid })   -- le sac a quitté le donneur entre-temps
FIRE('elyzea_clothing:bagGiftAnswer', 2, true)
check(#bagsOf(2) == 0 and notes(2):find('plus disponible'), 'le sac a disparu avant l\'acceptation : rien n\'est créé')

io.write(('\n%d ok, %d échec(s)\n'):format(passes, fails))
return fails
