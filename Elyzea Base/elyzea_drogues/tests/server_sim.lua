-- Simulation serveur d'elyzea_drogues (lancée par run_server_sim.py, avec server_mocks.lua)
print = _PRINT
local fails, n = 0, 0
local function check(c, l) n = n + 1 if c then print('  ok   ' .. l) else fails = fails + 1 print('  ÉCHEC ' .. l) end end
local function last(ev, target) for i = #SENT, 1, -1 do if SENT[i].ev == ev and (target == nil or SENT[i].target == target) then return SENT[i] end end end
local function P(src, x, y, z, extra) PLAYERS[src] = { pos = { x, y, z }, cid = 'CID' .. src, inv = {}, hp = 200, state = {} } for k, v in pairs(extra or {}) do PLAYERS[src][k] = v end end
local AA = EXPORTED.AdminAction
local AD = EXPORTED.AdminData

-- Les étapes renvoient un défi (mini-jeu) : un joueur qui « joue » renvoie un résultat réussi à la fin.
-- Un appel de fin explicite avec un 2e argument garde ce résultat (tests de triche / d'échec plus bas).
local RAW_CALL, GAMES = CALL, {}
CALL = function(name, src, ...)
    local args = table.pack(...)
    if name:find('Finish$') and args.n < 2 and GAMES[src] then
        local g = GAMES[src]
        args[2], args.n = { id = g.id, ok = true, done = g.count, mistakes = 0 }, 2
    end
    local r = RAW_CALL(name, src, table.unpack(args, 1, args.n))
    if name:find('Start$') and type(r) == 'table' then GAMES[src] = r.game end
    return r
end

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

print('[Gâteaux aux champignons (four)]')
AA(1, 'site_save', { type = 'shroom_prep', model = 'prop_table_04', x = 1, y = 2, z = 0 })
ok = AA(1, 'site_save', { type = 'shroom_oven', model = 'prop_cooker_03', x = 0, y = 2, z = 0 })
local oven, prep
for id, st in pairs(DS.sites) do if st.type == 'shroom_oven' then oven = id elseif st.type == 'shroom_prep' then prep = id end end
check(ok and oven and prep, 'plan de travail et four placés par le staff')
P(7, 0, 1, 0) P(8, 0, 1, 0) P(9, 0, 1, 0)
local inv7 = PLAYERS[7].inv
inv7.dried_mushroom, inv7.cake_flour, inv7.cake_sugar, inv7.cake_yeast, inv7.cake_milk = 10, 12, 6, 4, 6
r = CALL('craftStart', 7, prep, 'shroom_batter_s', 1)
check(r.ok and r.game and r.game.type == 'batter' and #r.game.extra.ingredients == 5 and r.game.extra.ingredients[1].grams == 200 and r.game.count == 5,
    'pâte à petit gâteau : mini-jeu de dosage (5 ingrédients, farine 200 g)')
NOW = NOW + 10
f = CALL('craftFinish', 7, r.token)
check(f.ok and inv7.shroom_batter_s == 1 and inv7.cake_flour == 10 and inv7.cake_sugar == 5 and inv7.cake_yeast == 3 and inv7.cake_milk == 5 and inv7.dried_mushroom == 9,
    'pâte : 2 farine + 1 sucre + 1 levure + 1 lait + 1 champignon retirés')
r = CALL('craftStart', 7, prep, 'shroom_batter_m', 1) NOW = NOW + 14
check(CALL('craftFinish', 7, r.token).ok and inv7.shroom_batter_m == 1, 'pâte à gâteau moyen (4 farine, 2 sucre, 1 levure, 2 lait, 3 champignons)')
r = CALL('craftStart', 7, prep, 'shroom_batter_l', 1) NOW = NOW + 18
check(CALL('craftFinish', 7, r.token).ok and inv7.shroom_batter_l == 1 and inv7.cake_flour == 0 and inv7.dried_mushroom == 0, 'pâte à gros gâteau : tout est utilisé')
check((CALL('craftStart', 7, prep, 'shroom_batter_s', 1).error or ''):find('manque'), 'plus d\'ingrédients : refusé')
r = CALL('craftStart', 7, oven, 'shroom_cake_s', 1)
check(r.ok and r.game.type == 'oven' and r.game.extra.target == 180 and r.game.extra.bake == 10, 'four : mini-jeu de température (petit gâteau : 180 °C, 10 s de cuisson)')
NOW = NOW + 12
f = CALL('craftFinish', 7, r.token)
check(f.ok and inv7.shroom_cake_s == 1 and inv7.shroom_batter_s == 0, 'pâte cuite : petit gâteau obtenu')
r = CALL('craftStart', 7, oven, 'shroom_cake_l', 1) NOW = NOW + 20
f = RAW_CALL('craftFinish', 7, r.token, { id = r.game.id, ok = false, done = 0, mistakes = 4, reason = 'mistakes' })
check(f.error and inv7.shroom_batter_l == 1 and not inv7.shroom_cake_l, 'gâteau brûlé (trop d\'erreurs) : rien obtenu, la pâte est gardée')
r = CALL('craftStart', 7, oven, 'shroom_cake_l', 1) NOW = NOW + 20
check(CALL('craftFinish', 7, r.token).ok and inv7.shroom_cake_l == 1, 'gros gâteau bien cuit')
r = CALL('craftStart', 7, oven, 'shroom_cake_m', 1) NOW = NOW + 16
check(CALL('craftFinish', 7, r.token).ok and inv7.shroom_cake_m == 1, 'gâteau moyen bien cuit')
check((CALL('craftStart', 7, prep, 'shroom_cake_s', 1).error) ~= nil, 'cuire sur le plan de travail : refusé (il faut le four)')
-- manger : la taille change la durée et la force
local base = DS.S.drugs.mushrooms
check(USABLE.shroom_cake_s(7) == true, 'petit gâteau mangé')
local t1 = last('elyzea_drogues:take', 7)
check(t1.args[1] == 'mushrooms' and t1.args[2] == math.floor(base.duration * 0.7 + 0.5) and math.abs(t1.args[6] - base.intensity * 0.7) < 0.01,
    ('petit : effet des champignons %d s, force %d %%'):format(t1.args[2], math.floor(t1.args[6])))
PLAYERS[8].inv.shroom_cake_m = 1 PLAYERS[9].inv.shroom_cake_l = 1
USABLE.shroom_cake_m(8) USABLE.shroom_cake_l(9)
local t2, t3 = last('elyzea_drogues:take', 8), last('elyzea_drogues:take', 9)
check(t2.args[2] > t1.args[2] and t2.args[6] > t1.args[6], ('moyen : plus long et plus fort (%d s, %d %%)'):format(t2.args[2], math.floor(t2.args[6])))
check(t3.args[2] > t2.args[2] and t3.args[6] > t2.args[6], ('gros : encore plus long et plus fort (%d s, %d %%)'):format(t3.args[2], math.floor(t3.args[6])))
check(EMS[#EMS][2] == 'psilocybin', 'prise enregistrée pour le laboratoire EMS (psilocybine)')
check(USABLE.shroom_cake_m(7) == false, 'délai des champignons respecté entre deux gâteaux')
-- réglage des effets dans le menu admin (onglet Effets) : durée × et force × par produit
check(DS.S.products.shroom_cake_l.mult == 2.2 and DS.S.products.shroom_cake_l.power == 1.6, 'menu : valeurs de départ du gros gâteau (×2,2 durée, ×1,6 force)')
ok = AA(5, 'settings_save', { sections = { products = { shroom_cake_l = { mult = 3, power = 2 }, shroom_cake_s = { mult = 99, power = -4 } } } })
check(ok and DS.S.products.shroom_cake_l.mult == 3 and DS.S.products.shroom_cake_l.power == 2, 'permission « effets » : durée et force du gros gâteau modifiées')
check(DS.S.products.shroom_cake_s.mult == 5 and DS.S.products.shroom_cake_s.power == 0.25, 'valeurs hors limites bornées (durée ×5 max, force ×0,25 min)')
P(10, 0, 1, 0) PLAYERS[10].inv.shroom_cake_l = 1
USABLE.shroom_cake_l(10)
local t4 = last('elyzea_drogues:take', 10)
check(t4.args[2] == math.floor(base.duration * 3 + 0.5) and math.abs(t4.args[6] - base.intensity * 2) < 0.01, ('le gros gâteau suit le menu : %d s, force %d %%'):format(t4.args[2], math.floor(t4.args[6])))
check(not AA(2, 'settings_save', { sections = { products = { shroom_cake_l = { mult = 1 } } } }), 'joueur sans permission : refusé')
AA(1, 'settings_reset', { section = 'drugs' })
check(DS.S.products.shroom_cake_l.mult == 2.2, '« Revenir à config.lua » : valeurs des gâteaux remises')

print('[Four et plan de travail posés avec l\'éditeur de map (E)]')
local oldTimeout = SetTimeout
SetTimeout = function(_, fn) fn() end   -- les mises à jour différées s'exécutent tout de suite ici
EDITOR_PROPS = { { id = 12, role = 'cake_oven', model = 'prop_cooker_03', x = 3, y = 1, z = 0, h = 90 }, { id = 13, role = 'cake_prep', model = 'prop_table_04', x = 3, y = 2, z = 0, h = 0 },
    { id = 14, role = 'police_pc', model = 'prop_laptop_01a', x = 9, y = 9, z = 0 } }
FIRE('adminmenu:propsChanged', 0) NOW = NOW + 1
local eOven, ePrep = DS.EXT_BASE + 12, DS.EXT_BASE + 13
check(DS.sites[eOven] and DS.sites[eOven].type == 'shroom_oven' and DS.sites[eOven].ext and DS.sites[ePrep] and DS.sites[ePrep].type == 'shroom_prep' and not DS.sites[DS.EXT_BASE + 14],
    'props de l\'éditeur (rôle four / plan de travail) : deviennent des postes à gâteaux, les autres props sont ignorés')
local sent = last('elyzea_drogues:sites', -1)
local seen = false
for _, x in ipairs(sent and sent.args[1] or {}) do if x.id == eOven and x.ext then seen = true end end
check(seen, 'envoyés aux joueurs comme « prop de l\'éditeur » (le jeu réutilise l\'objet déjà posé)')
P(11, 3, 1.5, 0)   -- un joueur ordinaire, sans métier ni permission
local i11 = PLAYERS[11].inv
i11.cake_flour, i11.cake_sugar, i11.cake_yeast, i11.cake_milk, i11.dried_mushroom = 2, 1, 1, 1, 1
r = CALL('craftStart', 11, ePrep, 'shroom_batter_s', 1) NOW = NOW + 10
check(r.ok and CALL('craftFinish', 11, r.token).ok and i11.shroom_batter_s == 1, 'tout le monde : pâte faite au plan de travail posé avec l\'éditeur')
r = CALL('craftStart', 11, eOven, 'shroom_cake_s', 1) NOW = NOW + 12
check(r.ok and CALL('craftFinish', 11, r.token).ok and i11.shroom_cake_s == 1, 'tout le monde : gâteau cuit au four posé avec l\'éditeur')
check(not AA(1, 'site_delete', { id = eOven }) and DS.sites[eOven], 'il ne se supprime pas depuis Gestion des drogues (c\'est l\'éditeur qui le gère)')
check(not AA(1, 'site_save', { id = eOven, type = 'shroom_oven', model = 'prop_cooker_03', x = 1, y = 1, z = 0 }), 'ni ne se déplace depuis Gestion des drogues')
local listed = false
for _, x in ipairs(AD(1).sites) do if x.id == eOven then listed = true end end
check(not listed, 'absent de la liste « Installations » (géré dans l\'éditeur › Pâtisserie)')
EDITOR_PROPS = { { id = 12, role = 'cake_oven', model = 'prop_cooker_03', x = 5, y = 1, z = 0, h = 90 } }
FIRE('adminmenu:propsChanged', 0) NOW = NOW + 1
check(DS.sites[eOven] and DS.sites[eOven].x == 5 and not DS.sites[ePrep], 'four déplacé / plan de travail supprimé dans l\'éditeur : suivi tout de suite')
EDITOR_PROPS = {}
FIRE('adminmenu:propsChanged', 0) NOW = NOW + 1
SetTimeout = oldTimeout

print('[Menu admin]')
local d = AD(1)
check(d.available and d.full and #d.sites == 7 and #d.recipes > 40 and d.labels.joint_ww, 'données du menu : installations, recettes, libellés')
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
print('[Étapes immersives (mini-jeux)]')
-- profils : chaque recette et chaque point de récolte a un mini-jeu ; nombre d'objectifs cohérent
local missingP = {}
for id in pairs(Config.Recipes) do if not DrugSteps.Key(id) then missingP[#missingP + 1] = id end end
check(#missingP == 0, 'toutes les recettes ont un mini-jeu' .. (#missingP > 0 and (' (manque : ' .. table.concat(missingP, ', ') .. ')') or ''))
local noAnim, withGame = {}, {}
for id in pairs(Config.Harvest) do
    if not Config.HarvestSceneOf(id) then noAnim[#noAnim + 1] = id end
    if DrugSteps.Challenge(DrugSteps.HarvestKey(id) or '', 1) then withGame[#withGame + 1] = id end
end
check(#noAnim == 0 and #withGame == 0 and not DrugSteps.Challenge('pot:harvest', 1), 'récolte (champs et pots) : pas de mini-jeu, une animation adaptée pour chaque plante')
local GAMES_OK = { trim = 1, harvest = 1, pick = 1, hang = 1, grind = 1, roll = 1, scale = 1, count = 1, pour = 1, heat = 1, shake = 1, cut = 1, smash = 1, press = 1, sort = 1, syringe = 1, batter = 1, oven = 1 }
local badG = {}
for k, p in pairs(Config.Steps) do
    if not GAMES_OK[p.game] then badG[#badG + 1] = k end
    if p.game == 'pour' and (p.per % #p.extra.reagents ~= 0 or p.cap % #p.extra.reagents ~= 0 or p.min % #p.extra.reagents ~= 0) then badG[#badG + 1] = k .. ' (réactifs)' end
    if p.game == 'batter' and (p.per % #p.extra.ingredients ~= 0 or p.cap % #p.extra.ingredients ~= 0 or p.min % #p.extra.ingredients ~= 0) then badG[#badG + 1] = k .. ' (ingrédients)' end
    if p.game == 'oven' and not (p.extra and p.extra.target and p.extra.bake) then badG[#badG + 1] = k .. ' (four)' end
    if p.game == 'roll' and (p.per % 3 ~= 0 or p.cap % 3 ~= 0 or p.min % 3 ~= 0) then badG[#badG + 1] = k .. ' (3 objectifs par joint)' end
end
check(#badG == 0, 'profils valides (mini-jeu connu, dosage et roulage complets)' .. (#badG > 0 and (' : ' .. table.concat(badG, ', ')) or ''))
local ch = DrugSteps.Challenge('weed_trim', 2, 'weed', 'weed_trim_classic')
check(ch.count == 12 and ch.type == 'trim' and ch.limit >= 30 and ch.maxMistakes == 3, 'défi : effeuillage ×2 = 12 feuilles, temps et erreurs bornés')
check(DrugSteps.Challenge('weed_dry', 1).count == 4 and DrugSteps.Challenge('weed_trim', 99).count == 30, 'séchage : objets + réglage final ; plafond respecté')
check(DrugSteps.Challenge('xtc_press', 1, 'ecstasy', 'xtc_press_blue').extra.color == 'blue' and DrugSteps.Key('xtc_pack_yellow') == 'xtc_pack', 'couleur des comprimés reprise de la recette')
check(DrugSteps.Key('weed_trim_whitewidow') == 'weed_trim' and DrugSteps.Key('weed_dry_custom') == 'weed_dry' and DrugSteps.Challenge('weed_trim', 1, 'weed', 'weed_trim_purplehaze').extra.tint == 'purple', 'profil retrouvé depuis la recette ; fleur violacée pour la Purple Haze')
-- validation serveur
local okC = DrugSteps.Check(ch, { id = ch.id, ok = true, done = ch.count, mistakes = 1 }, 30)
local b1, w1 = DrugSteps.Check(ch, { id = ch.id, ok = true, done = ch.count - 1, mistakes = 0 }, 30)
local b2, w2 = DrugSteps.Check(ch, { id = ch.id + 1, ok = true, done = ch.count, mistakes = 0 }, 30)
local b3, w3 = DrugSteps.Check(ch, { id = ch.id, ok = true, done = ch.count, mistakes = 9 }, 30)
local b4, w4 = DrugSteps.Check(ch, { id = ch.id, ok = true, done = ch.count, mistakes = 0 }, 0.2)
local b5, w5 = DrugSteps.Check(ch, { id = ch.id, ok = false, done = 3, mistakes = 4 }, 30)
local b6, w6 = DrugSteps.Check(ch, { id = ch.id, cancelled = true }, 30)
local b7, w7 = DrugSteps.Check(ch, nil, 30)
check(okC and not b1 and w1 == 'invalid' and not b2 and not b3 and not b4 and w4 == 'invalid', 'résultat accepté seulement s\'il est complet, du bon défi, plausible')
check(not b5 and w5 == 'fail' and not b6 and w6 == 'cancel' and not b7 and w7 == 'invalid', 'échec, annulation et absence de résultat distingués')
-- fabrication réelle avec mini-jeu
local dc = DrugRules.copy(DS.S.drugs) dc.cocaine.enabled = true
AA(1, 'settings_save', { sections = { drugs = dc } })
AA(1, 'site_save', { type = 'coca_grind', model = 'prop_tool_box_04', x = 1, y = 0, z = 0 })
local g2 = 0 for id, st in pairs(DS.sites) do if st.type == 'coca_grind' then g2 = id end end
PLAYERS[2].inv.coca_leaf = 4 PLAYERS[2].inv.coca_ground = 0 NOW = NOW + 30
r = CALL('craftStart', 2, g2, 'coca_grind', 1)
check(r.ok and r.game and r.game.type == 'grind' and r.game.count == 3, 'début de fabrication : le serveur envoie le défi (broyage)')
NOW = NOW + 10
f = RAW_CALL('craftFinish', 2, r.token, { id = r.game.id, ok = false, done = 1, mistakes = 4, reason = 'mistakes' })
check(f.error and f.error:find('Raté') and PLAYERS[2].inv.coca_leaf == 4 and not DS.stationBusy[g2], 'mini-jeu raté : rien n\'est retiré, poste libéré')
r = CALL('craftStart', 2, g2, 'coca_grind', 1) NOW = NOW + 10
f = RAW_CALL('craftFinish', 2, r.token, { id = r.game.id, ok = true, done = 999, mistakes = 0 })
local alert = false for _, l in ipairs(DB.logs or {}) do if tostring(l.detail or l[3] or ''):find('mini%-jeu') then alert = true end end
check(f.error and PLAYERS[2].inv.coca_leaf == 4, 'résultat falsifié : refusé, ingrédients gardés')
r = CALL('craftStart', 2, g2, 'coca_grind', 1) NOW = NOW + 10
f = RAW_CALL('craftFinish', 2, r.token, { id = r.game.id, ok = true, done = r.game.count, mistakes = 0 })
local rcg = DrugRules.Recipe(DS.S, 'coca_grind')
check(f.ok and PLAYERS[2].inv.coca_leaf == 4 - rcg.inputs[1][2] and PLAYERS[2].inv.coca_ground == rcg.outputs[1][2], ('mini-jeu réussi : quantités de la recette inchangées (%d feuilles → %d broyées)'):format(rcg.inputs[1][2], rcg.outputs[1][2]))
PLAYERS[2].inv.coca_leaf = 0
r = CALL('craftStart', 2, g2, 'coca_grind', 1)
check(not r.ok, 'plus d\'ingrédients : refusé (rien en double)')
-- durée minimale de la recette conservée même si le mini-jeu est fini vite
PLAYERS[2].inv.coca_leaf = 4 NOW = NOW + 5
r = CALL('craftStart', 2, g2, 'coca_grind', 1) NOW = NOW + 1
f = RAW_CALL('craftFinish', 2, r.token, { id = r.game.id, ok = true, done = r.game.count, mistakes = 0 })
check(f.error and PLAYERS[2].inv.coca_leaf == 4, 'mini-jeu fini en 1 s : la durée de la recette reste exigée')
-- mini-jeux désactivés : retour à la barre de progression
Config.Minigames.enabled = false
NOW = NOW + 30
r = CALL('craftStart', 2, g2, 'coca_grind', 1) NOW = NOW + 10
check(r.ok and r.game == nil and RAW_CALL('craftFinish', 2, r.token).ok, 'mini-jeux désactivés : ancienne barre de progression, fabrication normale')
Config.Minigames.enabled = true
-- séchage du cannabis
local vv = DrugRules.copy(DS.S.varieties) vv.classic.dryStep = true
AA(1, 'settings_save', { sections = { varieties = vv } })
local trim = DrugRules.Recipe(DS.S, 'weed_trim_classic')
local dry = DrugRules.Recipe(DS.S, 'weed_dry_classic')
check(trim.outputs[1][1] == 'weed_bud_wet' and trim.outputs[1][2] == 2 and dry.enabled and dry.inputs[1][1] == 'weed_bud_wet' and dry.outputs[1][1] == 'weed_bud' and dry.outputs[1][2] == 1,
    'séchage actif : manucure → 2 têtes fraîches, séchoir 1 → 1 tête (quantités inchangées)')
vv.classic.dryStep = false
AA(1, 'settings_save', { sections = { varieties = vv } })
check(DrugRules.Recipe(DS.S, 'weed_trim_classic').outputs[1][1] == 'weed_bud' and not DrugRules.Recipe(DS.S, 'weed_dry_classic').enabled, 'séchage désactivé : la manucure donne directement les têtes, séchoir coupé')
check(DrugRules.Clean({ varieties = { classic = {} } }).varieties.classic.dryStep == true, 'réglage absent : valeur de la config (séchage actif)')
-- assise réglée par le staff
local okS = CB['elyzea_drogues:saveSeat'](1, 'weed_trim', { x = 0.1, y = -0.05, z = 9, h = 10 })
local noS = CB['elyzea_drogues:saveSeat'](2, 'weed_trim', { x = 0.1 })
check(okS.ok and DS.S.sceneOffsets.weed_trim.z == 1.5 and DS.S.sceneOffsets.weed_trim.x == 0.1 and noS.error, 'réglage de l\'assise : staff seulement, valeurs bornées, enregistré')
-- objets temporaires : seuls ceux du joueur et de modèles de scène sont suivis
ENTS = { [11] = { owner = 2, type = 3, model = 'prop_cs_scissors' }, [12] = { owner = 3, type = 3, model = 'prop_cs_scissors' }, [13] = { owner = 2, type = 2, model = 'adder' }, [14] = { owner = 2, type = 3, model = 'prop_bigbomb' } }
NetworkGetEntityFromNetworkId = function(id) return ENTS[id] and id or 0 end
DoesEntityExist = function(e) return ENTS[e] ~= nil end
GetEntityType = function(e) return ENTS[e].type end
NetworkGetEntityOwner = function(e) return ENTS[e].owner end
GetEntityModel = function(e) return ENTS[e].model end
DeleteEntity = function(e) ENTS[e] = nil end
FIRE('elyzea_drogues:sceneProps', 2, { 11, 12, 13, 14 })
check(DS.sceneProps[2] and #DS.sceneProps[2] == 1 and DS.sceneProps[2][1] == 11, 'objets de scène : seuls les siens et de modèles connus sont acceptés')
FIRE('playerDropped', 2)
check(ENTS[11] == nil and ENTS[12] and ENTS[13] and ENTS[14] and DS.sceneProps[2] == nil, 'déconnexion en pleine étape : ses objets temporaires supprimés, rien d\'autre')
print(('Résultat : %d/%d réussis'):format(n - fails, n))
return fails
