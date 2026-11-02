-- =====================================================================
--  ELYZEA CUISINE · serveur : contrôle des données au démarrage + commandes staff
--  La consommation elle-même est validée par elyzea_inventory (jeton, objet présent, retrait, faim / soif).
-- =====================================================================
local RES = GetCurrentResourceName()
local src = LoadResourceFile(RES, 'data/recipes.lua')
local fn, err = src and load(src, '@' .. RES .. '/data/recipes.lua', 't', {})
local ok, D = pcall(fn or function() error(err or 'fichier absent') end)
if not ok or type(D) ~= 'table' then
    print('^1[elyzea_cuisine] data/recipes.lua illisible : ' .. tostring(D) .. '^0')
    return
end

-- Contrôle : ids uniques, valeurs cohérentes, objets et gestes connus
local problems, seen, perCat = {}, {}, {}
for _, r in ipairs(D.Recipes) do
    if seen[r.id] then problems[#problems + 1] = 'id en double : ' .. r.id end
    seen[r.id] = true
    perCat[r.cat] = (perCat[r.cat] or 0) + 1
    for _, use in ipairs({ { anim = r.anim, props = r.props }, r.fb }) do
        if use then
            if not D.Anims[use.anim] then problems[#problems + 1] = r.id .. ' : geste inconnu ' .. tostring(use.anim) end
            for _, p in ipairs(use.props or {}) do if not D.Props[p] then problems[#problems + 1] = r.id .. ' : objet inconnu ' .. tostring(p) end end
        end
    end
end
for _, p in ipairs(problems) do print('^1[elyzea_cuisine] ' .. p .. '^0') end
print(('[elyzea_cuisine] %d recettes chargées (italien %d, fast-food %d, japonais %d, mexicain %d)%s'):format(#D.Recipes,
    perCat.italien or 0, perCat.fastfood or 0, perCat.japonais or 0, perCat.mexicain or 0, #problems > 0 and (' · ^1' .. #problems .. ' problème(s)^0') or ''))
if GetResourceState('elyzea_inventory') == 'started' then
    print('^3[elyzea_cuisine] elyzea_inventory était déjà démarré : redémarre-le (ou démarre elyzea_cuisine avant) pour créer les 80 objets.^0')
end

-- /cuisine_check : liste, chez toi, les objets / animations absents et les recettes en repli (console F8)
-- /cuisine_essai <id> : joue le visuel d'une recette sans objet ni effet (réglage des positions)
RegisterCommand('cuisine_check', function(s) if s > 0 then TriggerClientEvent('elyzea_cuisine:check', s) end end, true)
RegisterCommand('cuisine_essai', function(s, args) if s > 0 and args[1] then TriggerClientEvent('elyzea_cuisine:preview', s, tostring(args[1])) end end, true)
