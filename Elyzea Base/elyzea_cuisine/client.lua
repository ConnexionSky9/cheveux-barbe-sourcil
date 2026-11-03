-- =====================================================================
--  ELYZEA CUISINE · client : consommation avec objets en main + animation propres à chaque recette
--  Appelé par elyzea_inventory (client/use.lua) quand un objet de recette est utilisé :
--    exports.elyzea_cuisine:Consume(d) → true (fini) / false (annulé)
--  Le serveur d'elyzea_inventory garde la main : jeton, objet revérifié, retrait, faim / soif.
--  Ici : objets et animation choisis, vérifiés (le modèle / l'animation existe-t-il chez ce joueur ?),
--  repli automatique sinon, barre de progression d'elyzea_core (annulable), nettoyage garanti.
-- =====================================================================
local RES = GetCurrentResourceName()
local D = (function()
    local src = LoadResourceFile(RES, 'data/recipes.lua')
    local fn = src and load(src, '@' .. RES .. '/data/recipes.lua', 't', {})
    local ok, data = pcall(fn or error)
    if not ok or type(data) ~= 'table' then print('^1[elyzea_cuisine] data/recipes.lua illisible^0') return { Recipes = {}, Props = {}, Anims = {} } end
    return data
end)()

local BY_ID = {}
for _, r in ipairs(D.Recipes) do BY_ID[r.id] = r end

local active = nil   -- consommation en cours : { props = {...} }

local function hasModel(name) return IsModelInCdimage(GetHashKey(name)) end
local function hasAnim(a) return a and DoesAnimDictExist(a.dict) end

-- Une façon de consommer est-elle jouable chez ce joueur (tous les objets + l'animation existent) ?
local function playable(use)
    if not use or not hasAnim(D.Anims[use.anim]) then return false end
    for _, key in ipairs(use.props or {}) do
        local p = D.Props[key]
        if not p or not hasModel(p.model) then return false end
    end
    return true
end

-- Façon choisie pour une recette : la sienne, sinon son repli, sinon le repli général (burger / bouteille)
local function resolve(r)
    local own = { anim = r.anim, props = r.props }
    if playable(own) then return own, 'recette' end
    if r.fb and playable(r.fb) then return r.fb, 'repli' end
    local last = D.LastResort[r.kind == 'boisson' and 'drink' or 'food']
    if playable(last) then return last, 'secours' end
    return { anim = nil, props = {} }, 'aucun'
end

-- ---------------------------------------------------------------------
-- Autres aliments du serveur (pas des recettes) : D.Items, sinon reconnaissance par le nom (D.Guess)
-- ---------------------------------------------------------------------
local ACCENTS = { ['à'] = 'a', ['â'] = 'a', ['ä'] = 'a', ['é'] = 'e', ['è'] = 'e', ['ê'] = 'e', ['ë'] = 'e', ['î'] = 'i', ['ï'] = 'i',
    ['ô'] = 'o', ['ö'] = 'o', ['ù'] = 'u', ['û'] = 'u', ['ü'] = 'u', ['ç'] = 'c', ['œ'] = 'oe', ['À'] = 'a', ['É'] = 'e', ['È'] = 'e', ['Ê'] = 'e', ['Ç'] = 'c' }
local function norm(t)
    t = tostring(t or '')
    for a, b in pairs(ACCENTS) do t = t:gsub(a, b) end
    return ' ' .. t:lower():gsub('[%-_]', ' ') .. ' '
end

-- d = { name, label, status = { hunger, thirst } } → recette « virtuelle » { label, kind, anim, props, fb } ou nil
local function itemSpec(d)
    if type(d) ~= 'table' or not d.name then return nil end
    local st = type(d.status) == 'table' and d.status or {}
    local hunger, thirst = tonumber(st.hunger) or 0, tonumber(st.thirst) or 0
    if hunger <= 0 and thirst <= 0 then return nil end      -- ni faim ni soif : pas un aliment (drogue, soin…)
    local isDrink = thirst > hunger
    local entry, how = (D.Items or {})[d.name], 'objet'
    if not entry then
        local text = norm((d.label or '') .. ' ' .. d.name)
        for _, g in ipairs(D.Guess or {}) do
            if (g.drink == true) == isDrink or (g.drink == nil and not isDrink) then
                for _, w in ipairs(g.words) do
                    if text:find(w, 1, true) then entry, how = g, 'nom' break end
                end
            end
            if entry then break end
        end
    end
    if not entry then
        local def = D.Default or {}
        entry = isDrink and def.drink or (hunger >= 250000 and def.meal or def.snack)
        how = 'défaut'
    end
    if not entry or not entry.use then return nil end
    -- Durée réaliste selon le geste (une assiette ne se mange pas en 2 s) ; jamais plus courte que celle de l'objet
    local minTime = ({ plate = 7000, snack = 5000, bite = 4500, bite_fp = 4500, straw = 4500, cup = 4000, bottle = 4000 })[entry.use.anim] or 4000
    return { id = d.name, label = d.label or d.name, kind = isDrink and 'boisson' or 'plat', anim = entry.use.anim, props = entry.use.props, fb = entry.fb, how = how,
        time = math.max(minTime, tonumber(d.usetime) or 0) }
end

local function loadModel(h)
    RequestModel(h)
    local t = GetGameTimer() + 3000
    while not HasModelLoaded(h) and GetGameTimer() < t do Wait(0) end
    return HasModelLoaded(h)
end

local function attachAll(ped, keys)
    local out = {}
    local c = GetEntityCoords(ped)
    for _, key in ipairs(keys) do
        local p = D.Props[key]
        local h = GetHashKey(p.model)
        if loadModel(h) then
            local obj = CreateObject(h, c.x, c.y, c.z + 0.2, true, true, false)
            SetModelAsNoLongerNeeded(h)
            if obj and obj ~= 0 then
                SetEntityCollision(obj, false, false)
                AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, p.bone), p.pos[1] + 0.0, p.pos[2] + 0.0, p.pos[3] + 0.0,
                    p.rot[1] + 0.0, p.rot[2] + 0.0, p.rot[3] + 0.0, true, true, false, true, 1, true)
                out[#out + 1] = obj
            end
        end
    end
    return out
end

local function cleanup()
    local a = active
    active = nil
    if not a then return end
    for _, obj in ipairs(a.props or {}) do
        if DoesEntityExist(obj) then
            DetachEntity(obj, true, false)
            SetEntityAsMissionEntity(obj, true, true)
            DeleteEntity(obj)
        end
    end
    local ped = PlayerPedId()
    if a.anim and IsEntityPlayingAnim(ped, a.anim.dict, a.anim.clip, 3) then StopAnimTask(ped, a.anim.dict, a.anim.clip, 1.0) end
end

-- Consommer une recette (bloquant). d = données envoyées par elyzea_inventory (d.cuisine = id de la recette)
local function consume(d, spec)
    local r = spec or BY_ID[type(d) == 'table' and d.cuisine or d]
    if not r then return false end
    if active then return false end
    local use = resolve(r)
    local anim = use.anim and D.Anims[use.anim] or nil
    local ped = PlayerPedId()
    active = { anim = anim, props = {} }
    local ok, res = pcall(function()
        active.props = attachAll(ped, use.props or {})
        return exports.elyzea_core:ProgressBar({
            duration = (spec and spec.time) or (type(d) == 'table' and tonumber(d.usetime)) or r.time or 5000,
            label = (r.kind == 'boisson' and 'Tu bois : %s' or 'Tu manges : %s'):format(r.label),
            canCancel = true,
            disable = { car = false, combat = true },
            anim = anim and { dict = anim.dict, clip = anim.clip, flag = anim.flag, blendIn = 3.0, blendOut = 2.0 } or nil,
        })
    end)
    cleanup()    -- toujours : aucun objet ne reste en main, même en cas d'erreur
    if not ok then print('^1[elyzea_cuisine] ' .. tostring(res) .. '^0') return false end
    return res == true
end
exports('Consume', function(d) return consume(d) end)
-- Aliment qui n'est pas une recette (burger, pizza, boissons du bar…) : true / false, ou nil si rien d'adapté
exports('ConsumeItem', function(d)
    local spec = itemSpec(d)
    if not spec then return nil end
    return consume(d, spec)
end)
exports('DescribeItem', function(d) return itemSpec(d) end)
exports('GetRecipe', function(id) return BY_ID[id] end)
exports('IsEating', function() return active ~= nil end)

-- ---------------------------------------------------------------------
-- Outils staff : vérifier les objets / animations chez soi, essayer une recette (visuel seul)
-- ---------------------------------------------------------------------
RegisterNetEvent('elyzea_cuisine:check', function()
    local miss, fb = {}, 0
    for key, p in pairs(D.Props) do if not hasModel(p.model) then miss[#miss + 1] = 'objet ' .. key .. ' (' .. p.model .. ')' end end
    for key, a in pairs(D.Anims) do if not hasAnim(a) then miss[#miss + 1] = 'animation ' .. key .. ' (' .. a.dict .. ')' end end
    for _, r in ipairs(D.Recipes) do local _, how = resolve(r) if how ~= 'recette' then fb = fb + 1 print(('  %s : %s'):format(r.id, how)) end end
    table.sort(miss)
    print(('[elyzea_cuisine] %d recettes, %d en repli chez toi ; éléments absents (%d) :'):format(#D.Recipes, fb, #miss))
    for _, m in ipairs(miss) do print('  - ' .. m) end
end)

RegisterNetEvent('elyzea_cuisine:preview', function(id)
    if BY_ID[id] then return CreateThread(function() consume({ cuisine = id }) end) end
    -- autre aliment du serveur (pizza, bs_frites, nc_mojito…) ou nom libre (« pâtes », « sushi »…)
    local spec = itemSpec({ name = tostring(id), label = tostring(id), status = { hunger = 300000 } })
    if not spec then return print('[elyzea_cuisine] aliment inconnu : ' .. tostring(id)) end
    print(('[elyzea_cuisine] %s : %s + %s (%s)'):format(id, tostring(spec.anim), table.concat(spec.props or {}, ', '), spec.how))
    CreateThread(function() consume({}, spec) end)
end)

AddEventHandler('onResourceStop', function(res) if res == RES then cleanup() end end)
