-- Simulation serveur d'elyzea_drogues (lancée par run_server_sim.py, avec server_mocks.lua)
print = _PRINT
local fails, n = 0, 0
local function check(c, l) n = n + 1 if c then print('  ok   ' .. l) else fails = fails + 1 print('  ÉCHEC ' .. l) end end
local function last(ev, target) for i = #SENT, 1, -1 do if SENT[i].ev == ev and (target == nil or SENT[i].target == target) then return SENT[i] end end end
local function P(src, x, y, z, extra) PLAYERS[src] = { pos = { x, y, z }, cid = 'CID' .. src, inv = {}, hp = 200, state = {} } for k, v in pairs(extra or {}) do PLAYERS[src][k] = v end end
local AA = EXPORTED.AdminAction
local AD = EXPORTED.AdminData

P(1, 0, 0, 0, { admin = true }) P(2, 0, 0, 0) P(3, 500, 0, 0) P(4, 0, 0, 0, { police = true }) P(5, 0, 0, 0, { effects = true })

print('[Démarrage]')
check(DS.ready, 'base créée, réglages et installations chargés')
local usable = 0 for _ in pairs(USABLE) do usable = usable + 1 end
local products = 0 for _ in pairs(Config.Products) do products = products + 1 end
check(usable == products + 1 and USABLE.plant_pot and USABLE.joint_ww and USABLE.coke_premium and USABLE.opi_syringe, ('%d objets utilisables (toutes les drogues + le pot)'):format(usable))

print('[Installations (staff)]')
local ok, msg = AA(2, 'site_save', { type = 'coca_grind', model = 'prop_tool_box_04', x = 1, y = 0, z = 0 })
check(not ok, 'joueur sans permission : placement refusé')
ok = AA(1, 'site_save', { type = 'coca_grind', model = 'prop_inexistant', x = 1, y = 0, z = 0 })
check(not ok, 'modèle non autorisé pour ce type : refusé')
ok = AA(1, 'site_save', { type = 'n_importe', model = 'x', x = 1, y = 0, z = 0 })
check(not ok, 'type inconnu : refusé')
ok = AA(1, 'site_save', { type = 'coca_grind', model = 'prop_tool_box_04', x = 1000, y = 0, z = 0 })
check(not ok, 'position trop loin du staff : refusée')
ok = AA(1, 'site_save', { type = 'coca_grind', model = 'prop_tool_box_04', x = 1, y = 0, z = 0, h = 90 })
local grind = 1
check(ok and DS.sites[grind] and DB.sites[grind] and last('elyzea_drogues:sites', -1), 'broyeur placé, enregistré en base et envoyé à tous')
AA(1, 'site_save', { type = 'coca_process', model = 'bkr_prop_coke_table01a', x = 1, y = 1, z = 0 })
AA(1, 'site_save', { type = 'coca', model = 'h4_prop_bush_cocaplant_01', x = 0, y = 1, z = 0 })
AA(1, 'site_save', { type = 'buyer', model = 'g_m_y_famca_01', x = 0, y = -1, z = 0 })
AA(1, 'site_save', { type = 'supplier', model = 'a_m_m_mexlabor_01', x = 0, y = -2, z = 0 })
local process, coca, buyer, supplier = 2, 3, 4, 5
ok = AA(1, 'site_save', { id = grind, type = 'coca_grind', model = 'prop_barrel_01a', x = 2, y = 0, z = 0, h = 180 })
check(ok and DS.sites[grind].x == 2 and DS.sites[grind].model == 'prop_barrel_01a' and DB.sites[grind].x == 2, 'installation déplacée (même identifiant, pas de doublon)')

print('[Fabrication]')
PLAYERS[2].inv.coca_leaf = 8
local r = CALL('craftStart', 2, grind, 'coca_paste', 1)
check(r.error ~= nil, 'recette d\'un autre poste : refusée')
r = CALL('craftStart', 3, grind, 'coca_grind', 1)
check(r.error and r.error:find('loin'), 'trop loin du poste : refusé')
r = CALL('craftStart', 2, grind, 'coca_grind', 1)
check(r.ok and r.duration == 8, 'broyage lancé (8 s)')
local r2 = CALL('craftStart', 2, grind, 'coca_grind', 1)
check(r2.error and r2.error:find('déjà'), 'double déclenchement : refusé')
PLAYERS[6] = { pos = { 2, 0, 0 }, cid = 'CID6', inv = { coca_leaf = 4 }, hp = 200, state = {} }
check((CALL('craftStart', 6, grind, 'coca_grind', 1).error or ''):find('utilise'), 'poste occupé par un autre joueur : refusé')
local f = CALL('craftFinish', 2, r.token)
check(f.error and PLAYERS[2].inv.coca_leaf == 8 and not PLAYERS[2].inv.coca_ground, 'fin trop rapide : refusée, rien retiré ni donné')
r = CALL('craftStart', 2, grind, 'coca_grind', 1)
NOW = NOW + 8
f = CALL('craftFinish', 2, r.token)
check(f.ok and PLAYERS[2].inv.coca_leaf == 4 and PLAYERS[2].inv.coca_ground == 2, '4 feuilles → 2 feuilles broyées')
check(CALL('craftFinish', 2, r.token).error ~= nil, 'même jeton réutilisé : refusé (pas de duplication)')
r = CALL('craftStart', 2, grind, 'coca_grind', 2)
check(r.error and r.error:find('manque'), 'série ×2 sans assez d\'ingrédients : refusée')
r = CALL('craftStart', 2, grind, 'coca_grind', 1)
FIRE('elyzea_drogues:cancel', 2, r.token)
check(not DS.playerBusy[2] and not DS.stationBusy[grind] and PLAYERS[2].inv.coca_leaf == 4, 'annulation : poste libéré, rien perdu')
PLAYERS[2].full = true
r = CALL('craftStart', 2, grind, 'coca_grind', 1) NOW = NOW + 8
f = CALL('craftFinish', 2, r.token)
check(f.error and PLAYERS[2].inv.coca_leaf == 4, 'inventaire plein : refusé, ingrédients gardés')
PLAYERS[2].full = false
PLAYERS[2].inv.drg_solvent = 1
r = CALL('craftStart', 2, process, 'coca_paste', 1) NOW = NOW + 12
RAND = function(a, b) if a == 1 and b == 100 then return 1 end return a end   -- toutes les pertes tombent
f = CALL('craftFinish', 2, r.token)
RAND = nil
check(f.ok and f.message:find('raté') and PLAYERS[2].inv.coca_ground == 0 and PLAYERS[2].inv.drg_solvent == 0 and not PLAYERS[2].inv.coca_paste, 'perte (5 %) tirée par le serveur : ingrédients consommés, rien obtenu')

print('[Récolte]')
r = CALL('harvestStart', 2, coca) NOW = NOW + 6
RAND = function(a, b) return b end
f = CALL('harvestFinish', 2, r.token)
RAND = nil
check(f.ok and PLAYERS[2].inv.coca_leaf == 8 and last('elyzea_drogues:node', -1), 'récolte de coca : +4 feuilles, plant caché pour tous')
check((CALL('harvestStart', 2, coca).error or ''):find('repousse'), 'récolte immédiate : « ça repousse »')
NOW = NOW + 301
check(CALL('harvestStart', 2, coca).ok, 'après la repousse : récoltable')
DS.playerBusy[2] = nil DS.stationBusy[coca] = nil

print('[Culture du cannabis]')
PLAYERS[2].inv.plant_pot = 2
check(USABLE.plant_pot(2) == false and last('elyzea_drogues:placePot', 2), 'utiliser le pot : placement lancé (objet retiré seulement à la pose)')
r = CALL('potPlace', 2, 1, 1, 0, 90)
check(r.ok and PLAYERS[2].inv.plant_pot == 1, 'pot posé, 1 pot retiré')
local pid = 1
check((CALL('potPlace', 2, 1.3, 1, 0, 0).error or ''):find('près'), 'deuxième pot collé au premier : refusé')
check((CALL('potPlace', 2, 50, 1, 0, 0).error or '') ~= '', 'pot loin du joueur : refusé')
r = CALL('potStart', 2, pid, 'plant', 'whitewidow')
check(r.error and r.error:find('Il te faut'), 'planter sans graine : refusé')
PLAYERS[2].inv['weed_white-widow_seed'] = 1
r = CALL('potStart', 2, pid, 'plant', 'whitewidow') NOW = NOW + 5
f = CALL('potFinish', 2, r.token)
check(f.ok and DS.plants[pid].variety == 'whitewidow' and PLAYERS[2].inv['weed_white-widow_seed'] == 0, 'graine White Widow → plante White Widow')
check((CALL('potStart', 3, pid, 'lamp_on').error or '') ~= '', 'un autre joueur loin : refusé')
PLAYERS[7] = { pos = { 1, 1, 0 }, cid = 'CID7', inv = { grow_lamp = 1 }, hp = 200, state = {} }
check((CALL('potStart', 7, pid, 'lamp_on').error or ''):find('pas ton pot'), 'lampe sur le pot d\'un autre : refusée')
check((CALL('potStart', 2, pid, 'harvest').error or ''):find('mature'), 'récolter une plante pas mûre : refusé')
PLAYERS[2].inv.grow_lamp = 1
r = CALL('potStart', 2, pid, 'lamp_on') NOW = NOW + 4
check(CALL('potFinish', 2, r.token).ok and DS.plants[pid].lamp, 'lampe installée')
check((CALL('potStart', 2, pid, 'water').error or ''):find('arrosoir'), 'arroser sans arrosoir : refusé')
PLAYERS[2].inv.watering_can, PLAYERS[2].inv.water = 1, 2
r = CALL('potStart', 2, pid, 'water') NOW = NOW + 4
check(CALL('potFinish', 2, r.token).ok and DS.plants[pid].water == 50 and PLAYERS[2].inv.water == 1, 'arrosage : eau 50 %, une bouteille utilisée')
NOW = NOW + 3600
local info = CALL('potInfo', 2, pid).info
check(info.pct >= 49 and info.pct <= 51 and info.water <= 31 and info.lamp, ('après 1 h : %d %% (calculé sur 120 min), eau %d %%'):format(info.pct, info.water))
check(info.timeLeft and info.timeLeft > 3000 and info.variety == 'White Widow', ('temps restant estimé : %d s'):format(info.timeLeft or -1))
-- redémarrage du serveur : rechargé depuis la base, la progression continue
DS.SavePlant(DS.plants[pid])
for k in pairs(DS.plants) do DS.plants[k] = nil end
NOW = NOW + 1800
DS.LoadPlants()
info = CALL('potInfo', 2, pid).info
check(DS.plants[pid] and info.pct >= 74 and info.pct <= 76, ('après un redémarrage + 30 min hors ligne : %d %%'):format(info.pct))
r = CALL('potStart', 2, pid, 'water') NOW = NOW + 4 CALL('potFinish', 2, r.token)
NOW = NOW + 1800
info = CALL('potInfo', 2, pid).info
check(info.pct == 100, 'mature à 100 %')
RAND = function(a, b) if a == 1 and b == 100 then return 1 end return b end
r = CALL('potStart', 2, pid, 'harvest') NOW = NOW + 8
f = CALL('potFinish', 2, r.token)
RAND = nil
check(f.ok and PLAYERS[2].inv.weed_leaf_ww == 6 and PLAYERS[2].inv['weed_white-widow_seed'] == 1 and not PLAYERS[2].inv.weed_leaf,
    'récolte : 6 feuilles de White Widow + 1 graine White Widow (jamais de mélange)')
check(DS.plants[pid].variety == nil and DS.plants[pid].lamp, 'pot réutilisable (vide, lampe gardée)')
-- plante oubliée : meurt sans eau
PLAYERS[2].inv.weed_seed = 1
r = CALL('potStart', 2, pid, 'plant', 'classic') NOW = NOW + 5 CALL('potFinish', 2, r.token)
NOW = NOW + 3600 * 10
info = CALL('potInfo', 2, pid).info
check(info.dead and info.condition == 'morte', 'sans eau pendant des heures : plante morte')
r = CALL('potStart', 2, pid, 'clear') NOW = NOW + 4
check(CALL('potFinish', 2, r.token).ok and DS.plants[pid].variety == nil, 'plante morte retirée')
-- police
PLAYERS[2].inv.weed_seed = 1
r = CALL('potStart', 2, pid, 'plant', 'classic') NOW = NOW + 5 CALL('potFinish', 2, r.token)
check((CALL('potStart', 2, pid, 'destroy').error or ''):find('police'), 'destruction réservée à la police en service')
r = CALL('potStart', 4, pid, 'destroy') NOW = NOW + 6
check(CALL('potFinish', 4, r.token).ok and not DS.plants[pid] and not DB.plants[pid], 'police en service : plante détruite, pot saisi (supprimé en base)')
-- reprendre un pot vide
r = CALL('potPlace', 2, 2, 2, 0, 0)
local pid2 = DB.nextPlant - 1
PLAYERS[2].inv.grow_lamp = 1
r = CALL('potStart', 2, pid2, 'lamp_on') NOW = NOW + 4 CALL('potFinish', 2, r.token)
r = CALL('potStart', 2, pid2, 'pickup') NOW = NOW + 3
check(CALL('potFinish', 2, r.token).ok and PLAYERS[2].inv.plant_pot == 1 and PLAYERS[2].inv.grow_lamp == 1 and not DS.plants[pid2], 'pot repris : pot et lampe rendus')
local saved = DS.S.culture.maxPotsPerPlayer
DS.S.culture.maxPotsPerPlayer = 0
check(USABLE.plant_pot(2) == false and (NOTES[#NOTES] or ''):find('maximum'), 'limite de pots par joueur')
DS.S.culture.maxPotsPerPlayer = saved

print('[Vente et fournisseur]')
PLAYERS[2].inv.joint_ww = 15
r = CALL('sell', 2, buyer, 'joint_ww')
check(r.ok and PLAYERS[2].inv.joint_ww == 5 and PLAYERS[2].inv.black_money == 400, 'vente : 10 joints White Widow (max par vente) × 40 = 400 d\'argent sale')
check((CALL('sell', 2, buyer, 'joint_ww').error or ''):find('attends'), 'délai entre deux ventes')
NOW = NOW + 5
check((CALL('sell', 2, buyer, 'coca_leaf').error or ''):find('achète pas'), 'objet sans prix : refusé')
PLAYERS[2].full = true
r = CALL('sell', 2, buyer, 'joint_ww')
check(r.error and PLAYERS[2].inv.joint_ww == 5, 'paiement impossible : vente annulée, produits rendus')
PLAYERS[2].full = false
NOW = NOW + 5
check(CALL('sell', 2, grind, 'joint_ww').error ~= nil, 'vendre à un poste qui n\'est pas un acheteur : refusé')
check(CALL('shopOpen', 2, supplier).ok and OPENED and OPENED[3] == 'drogues_supply' and #SHOP.inventory > 10, 'fournisseur : boutique ouverte avec le matériel (prix des réglages)')

print('[Consommation]')
PLAYERS[2].inv.joint_ww = 1
check(USABLE.joint_ww(2) == true, 'joint White Widow fumé (1 consommé)')
local tk = last('elyzea_drogues:take', 2)
check(tk.args[1] == 'weed' and tk.args[2] == 180 and tk.args[5][1] == 170 and tk.args[5][3] == 230, 'effet cannabis 180 s, fumée violette (couleur de la variété, décidée par le serveur)')
check(EMS[#EMS][2] == 'thc', 'prise enregistrée pour le laboratoire EMS (THC)')
check(USABLE.joint_ww(2) == false, 'délai avant d\'en reprendre')
SENT = {}
FIRE('elyzea_drogues:puff', 2)
check(last('elyzea_drogues:puff', 1) and not last('elyzea_drogues:puff', 3), 'fumée relayée aux joueurs proches seulement')
SENT = {} FIRE('elyzea_drogues:puff', 2)
check(not last('elyzea_drogues:puff'), 'pas plus d\'une bouffée par seconde')
USABLE.coke_premium(2)
check(last('elyzea_drogues:take', 2).args[2] == 225, 'cocaïne pure : effet ×1,5 (225 s)')
PLAYERS[2].state.pvpArena = true
check(USABLE.meth(2) == false, 'pendant une arène PvP : refusé')
PLAYERS[2].state.pvpArena = nil

print('[Menu admin]')
local d = AD(1)
check(d.available and d.full and #d.sites == 5 and #d.recipes > 40 and d.labels.joint_ww, 'données du menu : installations, recettes, libellés')
check(AD(2).denied, 'joueur sans permission : rien')
check(AD(5).available and not AD(5).full, 'permission « effets » : accès limité')
local rec = DrugRules.copy(DS.S.recipes)
rec.coca_grind.duration = 3
rec.coca_grind.outputs = { { 'coca_ground', 5 } }
ok = AA(1, 'settings_save', { sections = { recipes = rec } })
check(ok and DS.S.recipes.coca_grind.duration == 3 and DS.S.recipes.coca_grind.outputs[1][2] == 5 and last('elyzea_drogues:settings', -1), 'recette modifiée (durée, quantité) et appliquée tout de suite')
rec.coca_grind.inputs = { { 'nope_item', 1 } }
ok, msg = AA(1, 'settings_save', { sections = { recipes = rec } })
check(not ok and msg:find('inconnu'), 'objet inexistant dans une recette : refusé')
ok = AA(5, 'settings_save', { sections = { recipes = DS.S.recipes } })
check(not ok, 'permission « effets » : recettes refusées')
local drugs = DrugRules.copy(DS.S.drugs) drugs.weed.duration = 90
check(AA(5, 'settings_save', { sections = { drugs = drugs } }) and DS.S.drugs.weed.duration == 90, 'permission « effets » : durée de défonce modifiée')
local prices = DrugRules.copy(DS.S.prices) prices.joint_ww.price = 55
AA(1, 'settings_save', { sections = { prices = prices } })
PLAYERS[2].inv.joint_ww = 1 NOW = NOW + 10
CALL('sell', 2, buyer, 'joint_ww')
check(PLAYERS[2].inv.black_money == 455, 'nouveau prix appliqué sans redémarrage (55)')
local vars = DrugRules.copy(DS.S.varieties) vars.classic.prepStep = false
AA(1, 'settings_save', { sections = { varieties = vars } })
local roll = DrugRules.Recipe(DS.S, 'weed_roll_classic')
check(not DrugRules.Recipe(DS.S, 'weed_grind_classic').enabled and roll.inputs[1][1] == 'weed_bud', 'étape « préparer » désactivée pour la weed : on roule directement les têtes')
local dg = DrugRules.copy(DS.S.drugs) dg.cocaine.enabled = false
AA(1, 'settings_save', { sections = { drugs = dg } })
NOW = NOW + 10
check((CALL('craftStart', 2, grind, 'coca_grind', 1).error or ''):find('désactivée'), 'drogue désactivée : fabrication refusée')
ok = AA(1, 'site_delete', { id = grind })
check(ok and not DS.sites[grind] and not DB.sites[grind], 'installation supprimée (base + clients)')
-- persistance des réglages
JSON_STORE = { json = JSON_LAST }
check(DB.kv.settings == 'json' and DrugRules.Clean(JSON_LAST).prices.joint_ww.price == 55, 'réglages gardés en base et relisibles')
print(('Résultat : %d/%d réussis'):format(n - fails, n))
return fails
