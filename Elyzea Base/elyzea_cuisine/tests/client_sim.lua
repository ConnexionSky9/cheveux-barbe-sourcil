-- ELYZEA CUISINE · test hors jeu du client (client.lua) + contrôle des 80 recettes
-- Natives imitées : on vérifie ce qui est DEMANDÉ au jeu (objets créés, os, positions, animation, nettoyage).
local fails, passes = 0, 0
local function check(ok, l) if ok then passes = passes + 1 print('  ok   ' .. l) else fails = fails + 1 print('  ÉCHEC ' .. l) end end
local function readFile(p) local f = io.open(p) if not f then return nil end local s = f:read('a') f:close() return s end
local D = load(readFile(ROOT .. '/data/recipes.lua'), '@recipes', 't', {})()

print('\n[Données des 80 recettes]')
local per, ids, errs = {}, {}, {}
for _, r in ipairs(D.Recipes) do
    per[r.cat] = per[r.cat] or { plat = 0, dessert = 0, boisson = 0, n = 0 }
    per[r.cat].n = per[r.cat].n + 1
    per[r.cat][r.kind] = per[r.cat][r.kind] + 1
    if ids[r.id] then errs[#errs + 1] = 'double ' .. r.id end
    ids[r.id] = true
    if not r.id:match('^[a-z][a-z0-9_]+$') or #r.id > 40 then errs[#errs + 1] = 'nom technique ' .. r.id end
    if r.kind == 'boisson' and not (r.thirst > r.hunger) then errs[#errs + 1] = r.id .. ' : boisson qui nourrit plus qu\'elle n\'hydrate' end
    if r.kind == 'plat' and not (r.hunger > r.thirst) then errs[#errs + 1] = r.id .. ' : plat qui hydrate plus qu\'il ne nourrit' end
    if r.kind == 'dessert' and (r.hunger < 8 or r.hunger > 20) then errs[#errs + 1] = r.id .. ' : dessert hors 8-20' end
    if r.hunger < 0 or r.hunger > 50 or r.thirst < 0 or r.thirst > 50 then errs[#errs + 1] = r.id .. ' : valeur hors limites' end
    if r.time < 3000 or r.time > 12000 then errs[#errs + 1] = r.id .. ' : durée' end
    if not r.desc or #r.desc < 10 or not r.label then errs[#errs + 1] = r.id .. ' : texte' end
    for _, use in ipairs({ { anim = r.anim, props = r.props }, r.fb }) do
        if use then
            if not D.Anims[use.anim] then errs[#errs + 1] = r.id .. ' : geste ' .. tostring(use.anim) end
            for _, p in ipairs(use.props) do if not D.Props[p] then errs[#errs + 1] = r.id .. ' : objet ' .. p end end
        end
    end
end
local catsOk = true
for _, c in ipairs({ 'italien', 'fastfood', 'japonais', 'mexicain' }) do
    local p = per[c]
    if not p or p.n ~= 20 or p.dessert < 3 or p.boisson ~= 2 then catsOk = false end
    print(('       %s : %d recettes (%d plats, %d desserts, %d boissons)'):format(c, p and p.n or 0, p and p.plat or 0, p and p.dessert or 0, p and p.boisson or 0))
end
check(#D.Recipes == 80 and catsOk, '80 recettes : 4 catégories de 20 (plats, desserts, boissons)')
check(#errs == 0, 'noms uniques, faim / soif cohérentes, durées, textes, objets et gestes connus' .. (#errs > 0 and (' : ' .. table.concat(errs, ' | ')) or ''))
-- Variété : nombre de couples (geste + objets) différents, et aucun plat « générique burger » hors des vrais burgers
local combos, burgerLike = {}, {}
for _, r in ipairs(D.Recipes) do
    combos[r.anim .. ':' .. table.concat(r.props, '+')] = true
    if r.props[1] == 'burger' and not r.id:find('burger') then burgerLike[#burgerLike + 1] = r.id end
end
local nCombos = 0 for _ in pairs(combos) do nCombos = nCombos + 1 end
local anims = {} for _, r in ipairs(D.Recipes) do anims[r.anim] = (anims[r.anim] or 0) + 1 end
local nAnims = 0 for _ in pairs(anims) do nAnims = nAnims + 1 end
check(nCombos >= 40 and nAnims >= 7, ('%d visuels différents (objets + geste), %d gestes utilisés'):format(nCombos, nAnims))
check(#burgerLike == 0, 'aucun aliment non-burger affiché comme un burger')
for _, c in ipairs({ 'italien', 'fastfood', 'japonais', 'mexicain' }) do
    local a = {}
    for _, r in ipairs(D.Recipes) do if r.cat == c then a[r.anim] = true end end
    local k = 0 for _ in pairs(a) do k = k + 1 end
    check(k >= 3, ('%s : %d gestes différents'):format(c, k))
end
local plates = 0
for _, r in ipairs(D.Recipes) do if r.anim == 'plate' then
    local hasUtensil = false
    for _, p in ipairs(r.props) do if p:find('spoon') or p == 'fork' then hasUtensil = true end end
    if hasUtensil or r.id == 'mx_nachos' then plates = plates + 1 end
end end
local platesAll = 0 for _, r in ipairs(D.Recipes) do if r.anim == 'plate' then platesAll = platesAll + 1 end end
check(plates == platesAll, 'tous les plats « à l\'assiette / au bol » ont un couvert dans l\'autre main')

-- =====================================================================
print('\n[Moteur client : objets en main, geste, nettoyage]')
setmetatable(_G, { __index = function(_, k) if type(k) == 'string' and k:match('^%u') then return function() end end end })
local MISSING_MODEL, MISSING_DICT = {}, {}
local W = { objects = {}, next = 1000, anim = nil, pb = nil, pbResult = true }
function GetHashKey(n) local h = 0 for i = 1, #n do h = (h * 31 + n:byte(i)) % 4294967296 end return h end
local NAME = {}
local realHash = GetHashKey
GetHashKey = function(n) local h = realHash(n) NAME[h] = n return h end
function IsModelInCdimage(h) return not MISSING_MODEL[NAME[h]] end
function DoesAnimDictExist(d) return not MISSING_DICT[d] end
function HasModelLoaded() return true end
function PlayerPedId() return 1 end
function GetGameTimer() return 0 end
function GetEntityCoords() return { x = 0, y = 0, z = 0 } end
function CreateObject(h) W.next = W.next + 1 W.objects[W.next] = { model = NAME[h] } return W.next end
function AttachEntityToEntity(o, ped, bone, x, y, z, rx, ry, rz) W.objects[o].bone = bone W.objects[o].pos = { x, y, z } W.objects[o].rot = { rx, ry, rz } end
function GetPedBoneIndex(_, b) return b end
function DoesEntityExist(o) return W.objects[o] ~= nil end
function DeleteEntity(o) W.objects[o] = nil end
function IsEntityPlayingAnim() return W.anim ~= nil end
function StopAnimTask() W.anim = nil end
function LoadResourceFile(_, path) return readFile(ROOT .. '/' .. path) end
function GetCurrentResourceName() return 'elyzea_cuisine' end
local EXP, EV = {}, {}
exports = setmetatable({ elyzea_core = { ProgressBar = function(_, d)
    W.pb = d
    W.anim = d.anim
    W.during = {}
    local ids = {} for o in pairs(W.objects) do ids[#ids + 1] = o end table.sort(ids)   -- ordre de création
    for _, o in ipairs(ids) do W.during[#W.during + 1] = W.objects[o] end
    if W.pbError then error('boom') end
    return W.pbResult
end } }, { __call = function(_, n, f) EXP[n] = f end })
function RegisterNetEvent(n, f) if f then EV[n] = f end end
function AddEventHandler(n, f) EV[n] = f end
function CreateThread(f) f() end
assert(load(readFile(ROOT .. '/client.lua'), '@client.lua'))()
local function count() local n = 0 for _ in pairs(W.objects) do n = n + 1 end return n end

local errs2, okCount = {}, 0
for _, r in ipairs(D.Recipes) do
    W.objects, W.anim, W.pb = {}, nil, nil
    local ok = EXP.Consume({ cuisine = r.id, usetime = r.time })
    local a = D.Anims[r.anim]
    local during = W.during or {}
    local good = ok == true and W.pb and W.pb.anim and W.pb.anim.dict == a.dict and W.pb.anim.clip == a.clip and W.pb.duration == r.time and #during == #r.props
    for i, key in ipairs(r.props) do
        local p = D.Props[key]
        local got = during[i]
        if not got or got.model ~= p.model or got.bone ~= p.bone or math.abs(got.pos[1] - p.pos[1]) > 1e-9 or math.abs(got.rot[3] - p.rot[3]) > 1e-9 then good = false end
    end
    if count() ~= 0 then good = false errs2[#errs2 + 1] = r.id .. ' : objet resté en main' end
    if W.anim ~= nil then errs2[#errs2 + 1] = r.id .. ' : animation pas arrêtée' good = false end
    if not W.pb.label:find(r.label, 1, true) then good = false end
    if good then okCount = okCount + 1 elseif #errs2 < 10 then errs2[#errs2 + 1] = r.id end
end
check(okCount == 80, ('80 recettes : bons objets (modèle, os, position), bon geste, bonne durée, tout retiré à la fin (%d/80)'):format(okCount) .. (#errs2 > 0 and (' : ' .. table.concat(errs2, ', ')) or ''))
local spa = nil
W.objects = {} EXP.Consume({ cuisine = 'it_spaghetti_bolo' })
local models = {} for _, o in ipairs(W.during) do models[#models + 1] = o.model .. '@' .. o.bone end
check(table.concat(models, ',') == 'scully_pho@60309,prop_cs_fork@28422' and W.pb.anim.dict == D.Anims.plate.dict, 'spaghetti : assiette de pâtes main gauche + FOURCHETTE main droite, geste « manger à l\'assiette »')
local function eat(id) W.objects = {} EXP.Consume({ cuisine = id }) local m = {} for _, o in ipairs(W.during) do m[#m + 1] = o.model end return table.concat(m, ','), W.pb.anim.dict end
local m1 = eat('it_lasagnes')
check(m1 == 'prop_cs_plate_01,prop_cs_fork', 'lasagnes : assiette + fourchette')
local m2 = eat('it_escalope_milanaise')
check(m2 == 'prop_cs_plate_01,prop_cs_steak,prop_cs_fork', 'escalope : assiette + viande dessus + fourchette')
local m3 = eat('jp_makis_saumon')
check(m3 == 'prop_cs_plate_01,prop_fish_slice_01,prop_cs_fork', 'makis : assiette + poisson dessus + fourchette')
local m4, d4 = eat('it_pizza_margherita')
check(m4 == 'knjgh_pizzaslice4' and d4 == 'mp_player_inteat@burger', 'pizza : part de pizza dans la main, geste « croquer »')
local m5, d5 = eat('jp_sushi_saumon')
check(m5 == 'prop_fish_slice_01' and d5 == 'mp_player_inteat@burger', 'sushi : tenu dans la main, geste « croquer »')
W.objects = {} EXP.Consume({ cuisine = 'jp_ramen_porc' })
check(W.during[1].model == 'scully_pho' and W.during[2].model == 'scully_spoon_pho', 'ramen : bol de nouilles + cuillère')
W.objects = {} EXP.Consume({ cuisine = 'ff_milkshake_fraise' })
check(W.during[1].model == 'brum_cherryshake_strawberry' and W.pb.anim.dict == 'smo@milkshake_idle', 'milkshake : gobelet + paille, geste « siroter »')

print('\n[Annulation, erreurs, replis]')
W.objects, W.pbResult = {}, false
local okC = EXP.Consume({ cuisine = 'it_lasagnes' })
check(okC == false and count() == 0 and W.anim == nil, 'annulé : renvoie « non », objets retirés, joueur libéré')
W.pbResult, W.pbError = true, true
W.objects = {}
okC = EXP.Consume({ cuisine = 'it_lasagnes' })
check(okC == false and count() == 0, 'erreur pendant la consommation : objets quand même retirés')
W.pbError = false
check(EXP.Consume({ cuisine = 'inconnu' }) == false and count() == 0, 'recette inconnue : rien')
-- rpemotes absent : objets personnalisés introuvables → repli du jeu de base
MISSING_MODEL.scully_pho = true
W.objects = {} EXP.Consume({ cuisine = 'jp_ramen_porc' })
check(W.during[1].model == 'prop_cs_plate_01' and W.during[2].model == 'h4_prop_h4_caviar_spoon_01a', 'bol de ramen absent : repli assiette + couvert')
MISSING_DICT['smo@milkshake_idle'] = true
W.objects = {} EXP.Consume({ cuisine = 'ff_soda' })
check(W.during[1].model == 'prop_cs_bs_cup' and W.pb.anim.dict == 'amb@world_human_drinking@coffee@male@idle_a', 'animation « paille » absente : gobelet du jeu de base, geste « boire »')
MISSING_MODEL.prop_fish_slice_01 = true
W.objects = {} EXP.Consume({ cuisine = 'jp_sushi_saumon' })
check(W.during[1].model == 'prop_cs_burger_01' and count() == 0, 'ni objet ni repli : secours du jeu de base, jamais d\'erreur')
MISSING_MODEL.prop_cs_burger_01 = true
W.objects = {} local okNone = EXP.Consume({ cuisine = 'jp_sushi_saumon' })
check(okNone == true and #W.during == 0, 'rien du tout disponible : consommation quand même possible, sans objet')
MISSING_MODEL, MISSING_DICT = {}, {}
-- Sans rpemotes : pizza → part de pizza du jeu de base, pâtes → assiette + fourchette
MISSING_MODEL.knjgh_pizzaslice4, MISSING_MODEL.scully_pho = true, true
local f1 = eat('it_pizza_margherita')
local f2 = eat('it_spaghetti_bolo')
check(f1 == 'ng_proc_pizza01a' and f2 == 'prop_cs_plate_01,prop_cs_fork', 'sans rpemotes : pizza du jeu de base, pâtes à l\'assiette + fourchette')
MISSING_MODEL = {}

print('\n[Autres aliments du serveur (pas des recettes)]')
local function item(name, label, hunger, thirst, usetime)
    W.objects, W.pb = {}, nil
    local ok = EXP.ConsumeItem({ name = name, label = label, usetime = usetime or 2500, status = { hunger = (hunger or 0) * 10000, thirst = (thirst or 0) * 10000 } })
    local m = {} for _, o in ipairs(W.during or {}) do m[#m + 1] = o.model end
    return ok, table.concat(m, ','), W.pb and W.pb.anim and W.pb.anim.dict, W.pb and W.pb.duration, count()
end
local ok1, a1, d1 = item('pizza', 'Part de pizza', 25, 0)
check(ok1 == true and a1 == 'knjgh_pizzaslice5' and d1 == 'mp_player_inteat@burger', 'pizza de l\'inventaire : part de pizza en main (plus un burger)')
local _, a2 = item('bs_frites', 'Frites', 15, 0)
check(a2 == 'prop_food_bs_chips', 'frites du Burger Shot : cornet de frites')
local _, a3, d3 = item('bs_drink_cola', 'Shot Cola', 0, 35)
check(a3 == 'rpemotesreborn_soda02' and d3 == 'smo@milkshake_idle', 'soda Burger Shot : gobelet à paille, on sirote')
local _, a4 = item('nc_mojito', 'Mojito', 0, 20)
check(a4 == 'prop_mojito', 'mojito de la boîte de nuit : verre de mojito')
local _, a5 = item('cola', 'eCola', 0, 20)
check(a5 == 'prop_ecola_can', 'eCola : canette')
local _, a6 = item('chips', 'Chips', 8, 0)
check(a6 == 'prop_cs_crisps_01', 'chips : paquet de chips')
-- reconnaissance par le nom (aliments ajoutés plus tard, sans configuration)
local _, g1, gd1, gt1 = item('plat_pates_maison', 'Assiette de pâtes', 30, 0)
check(g1 == 'scully_pho,prop_cs_fork' and gd1 == D.Anims.plate.dict and gt1 >= 7000, 'nouvel aliment « Assiette de pâtes » : reconnu, assiette + fourchette, durée d\'un vrai repas')
local _, g2 = item('sushi_box', 'Sushi saumon', 10, 0)
check(g2 == 'prop_fish_slice_01', 'nouvel aliment « Sushi » : tenu en main')
local _, g3 = item('pizza_royale', 'Pizza Royale', 25, 0)
check(g3 == 'knjgh_pizzaslice5', 'nouvel aliment « Pizza Royale » : part de pizza')
local _, g4 = item('steak_frites', 'Steak frites', 40, 0)
check(g4 == 'prop_cs_plate_01,prop_cs_steak,prop_cs_fork', 'nouvel aliment « Steak frites » : assiette + viande + fourchette')
local _, g5 = item('salade_cesar', 'Salade César', 20, 2)
check(g5 == 'prop_cs_plate_01,prop_cs_fork', 'nouvel aliment « Salade César » : assiette + fourchette')
local _, g6 = item('biere_pisswasser', 'Pisswasser', 0, 15)
check(g6 == 'prop_amb_beer_bottle', 'nouvelle boisson « Pisswasser » : bouteille de bière')
local _, g7 = item('cafe_noir', 'Café noir', 0, 10)
check(g7 == 'p_amb_coffeecup_01', 'nouvelle boisson « Café » : tasse')
local _, g8 = item('fish_burger', 'Fish Burger', 20, 0)
check(g8 == 'prop_cs_burger_01', 'mots mélangés (« Fish Burger ») : burger, pas assiette de poisson')
local _, g9 = item('tagliatelles_saumon', 'Tagliatelles au saumon', 30, 0)
check(g9 == 'scully_pho,prop_cs_fork', '« Tagliatelles au saumon » : pâtes, pas sushis')
local _, g10 = item('ragout', 'Ragoût du chef', 35, 0)
check(g10 == 'prop_cs_plate_01,prop_cs_fork', 'plat inconnu et consistant : assiette + fourchette par défaut')
local _, g11 = item('truc', 'Barre de céréales', 6, 0)
check(g11 == 'prop_choc_ego', 'petit en-cas inconnu (« barre ») : tenu en main')
local okN = EXP.ConsumeItem({ name = 'joint', label = 'Joint', status = {} })
check(okN == nil, 'objet sans faim ni soif (drogue, soin…) : pas touché')
local _, _, _, t1 = item('bs_burger_classic', 'Le Classic Shot', 35, 0, 2500)
check(t1 == 4500, 'burger : durée réaliste (4,5 s au lieu de 2,5 s)')
W.pbResult = false
local okCancel, _, _, _, left = item('pizza', 'Part de pizza', 25, 0)
check(okCancel == false and left == 0, 'aliment annulé : renvoie « non », rien ne reste en main')
W.pbResult = true
-- Chaque aliment déclaré a des objets et un geste connus
local bad = {}
local function okUse(u) if not u then return true end if not D.Anims[u.anim] then return false end for _, k in ipairs(u.props) do if not D.Props[k] then return false end end return true end
for n, e in pairs(D.Items) do if not okUse(e.use) or not okUse(e.fb) then bad[#bad + 1] = n end end
for i, g in ipairs(D.Guess) do if not okUse(g.use) or not okUse(g.fb) then bad[#bad + 1] = 'règle ' .. i end end
local nItems = 0 for _ in pairs(D.Items) do nItems = nItems + 1 end
check(#bad == 0 and nItems >= 40, ('%d aliments du serveur + %d règles de reconnaissance : objets et gestes connus'):format(nItems, #D.Guess) .. (#bad > 0 and (' : ' .. table.concat(bad, ', ')) or ''))
-- =====================================================================
print('\n[Inventaire (elyzea_inventory/client/use.lua) : quel aliment passe par ces animations ?]')
do
    local inv = readFile(ROOT .. '/../elyzea_inventory/client/use.lua')
    if inv then inv = inv:gsub('`([%w_]+)`', "GetHashKey('%1')") end   -- syntaxe FiveM des empreintes
    if not inv then
        check(true, 'elyzea_inventory absent à côté : contrôle ignoré')
    else
        local H, sent, calls, pbCalls = {}, {}, {}, 0
        local saveReg, saveTrig, saveState = RegisterNetEvent, TriggerServerEvent, GetResourceState
        RegisterNetEvent = function(n, f) if f then H[n] = f end end
        TriggerServerEvent = function(n, ...) sent[#sent + 1] = { n, ... } end
        GetResourceState = function(r) return (r == 'elyzea_cuisine' or r == 'elyzea_core') and 'started' or 'missing' end
        local saveCI, saveC, savePB = EXP.ConsumeItem, EXP.Consume, exports.elyzea_core.ProgressBar
        exports.elyzea_cuisine = {
            ConsumeItem = function(_, d) calls[#calls + 1] = 'item:' .. d.name return EXP.ConsumeItem(d) end,
            Consume = function(_, d) calls[#calls + 1] = 'recette:' .. d.cuisine return EXP.Consume(d) end,
        }
        exports.elyzea_inventory = { closeInventory = function() end }
        local realPB = exports.elyzea_core.ProgressBar
        exports.elyzea_core.ProgressBar = function(self, d) pbCalls = pbCalls + 1 return realPB(self, d) end
        exports.elyzea_core.Notify = function() end
        function vec3(x, y, z) return { x = x, y = y, z = z } end
        function joaat(n) return GetHashKey(n) end
        local saveStop = EV.onResourceStop   -- l'inventaire a aussi son gestionnaire d'arrêt
        local saveCT = CreateThread
        CreateThread = function() end   -- boucles de suivi des armes : pas lancées ici
        assert(load(inv, '@use.lua'))()
        CreateThread = saveCT
        local function use(d) calls, sent, W.objects = {}, {}, {} H['elyzea_inv:consume'](d) return calls[1], sent[1] and sent[1][3] end
        local c1, ok1 = use({ token = 1, name = 'pizza', label = 'Part de pizza', usetime = 2500, status = { hunger = 250000, thirst = 0 },
            anim = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger_fp' } })
        check(c1 == 'item:pizza' and ok1 == true and W.during[1].model == 'knjgh_pizzaslice5', 'pizza utilisée dans l\'inventaire : part de pizza en main, validée au serveur')
        local c2 = use({ token = 2, name = 'it_spaghetti_bolo', cuisine = 'it_spaghetti_bolo', label = 'Spaghetti', status = { hunger = 380000 } })
        check(c2 == 'recette:it_spaghetti_bolo' and W.during[2] and W.during[2].model == 'prop_cs_fork', 'recette : toujours par elyzea_cuisine (pâtes + fourchette)')
        local before = pbCalls
        local c3, ok3 = use({ token = 3, name = 'joint', label = 'Joint', usetime = 3000, anim = { dict = 'amb@world_human_smoking@male@male_a@enter', clip = 'enter' } })
        check(c3 == nil and ok3 == true and pbCalls == before + 1, 'objet qui n\'est pas un aliment (drogue…) : animation d\'origine, inchangée')
        RegisterNetEvent, TriggerServerEvent, GetResourceState = saveReg, saveTrig, saveState
        EV.onResourceStop = saveStop
        exports.elyzea_core.ProgressBar = savePB
    end
end

-- Deux consommations en même temps : la seconde est refusée
local inner
exports.elyzea_core.ProgressBar = function() inner = EXP.Consume({ cuisine = 'ff_donut' }) return true end
W.objects = {} EXP.Consume({ cuisine = 'ff_hotdog' })
check(inner == false and count() == 0, 'manger deux choses à la fois : refusé')
-- arrêt de la ressource pendant un repas
exports.elyzea_core.ProgressBar = function() EV.onResourceStop('elyzea_cuisine') W.left = count() return true end
W.objects = {} EXP.Consume({ cuisine = 'it_tiramisu' })
check(W.left == 0, 'ressource arrêtée pendant un repas : objets retirés tout de suite')

print(('\n%d ok, %d échec(s)'):format(passes, fails))
return fails
