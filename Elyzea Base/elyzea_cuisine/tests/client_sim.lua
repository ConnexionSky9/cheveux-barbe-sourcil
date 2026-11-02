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
    for _, p in ipairs(r.props) do if p:find('spoon') then hasUtensil = true end end
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
    for o, info in pairs(W.objects) do W.during[#W.during + 1] = info end
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
check(table.concat(models, ',') == 'prop_cs_plate_01@60309,h4_prop_h4_caviar_spoon_01a@28422', 'spaghetti : assiette main gauche + couvert main droite, geste « manger à l\'assiette »')
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
