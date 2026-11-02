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
local function consume(d)
    local r = BY_ID[type(d) == 'table' and d.cuisine or d]
    if not r then return false end
    if active then return false end
    local use = resolve(r)
    local anim = use.anim and D.Anims[use.anim] or nil
    local ped = PlayerPedId()
    active = { anim = anim, props = {} }
    local ok, res = pcall(function()
        active.props = attachAll(ped, use.props or {})
        return exports.elyzea_core:ProgressBar({
            duration = (type(d) == 'table' and tonumber(d.usetime)) or r.time or 5000,
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
exports('Consume', consume)
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
    if not BY_ID[id] then return print('[elyzea_cuisine] recette inconnue : ' .. tostring(id)) end
    CreateThread(function() consume({ cuisine = id }) end)
end)

AddEventHandler('onResourceStop', function(res) if res == RES then cleanup() end end)
