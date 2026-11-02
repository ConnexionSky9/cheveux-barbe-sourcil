-- =====================================================================
--  ELYZEA RESTAURANT - recettes de elyzea_cuisine dans le catalogue
--  Lit elyzea_cuisine/data/recipes.lua (même fichier que l'inventaire) et
--  ajoute chaque recette à Config.Products :
--    id = item = identifiant de la recette (objet déjà créé par elyzea_inventory)
--    catégorie = cuisine (italien, fastfood, japonais, mexicain)
--    mini-jeu + station = première règle de Config.Cuisine.rules qui correspond
--  Rien n'est ajouté à la carte d'un restaurant tant que le staff ne l'autorise
--  pas (default = false) : admin_menu › Restaurants › Produits vendus.
-- =====================================================================
RSCuisine = { count = 0, error = nil, resource = nil }

local C = Config.Cuisine or {}

-- Fichier des recettes : d'abord la ressource de config.lua, sinon on la cherche
-- (dossier renommé, ex. « elyzea_cuisine-main ») parmi toutes les ressources du serveur
local function FindRecipes()
    local want = C.resource or 'elyzea_cuisine'
    local function try(res)
        local raw = res and LoadResourceFile(res, 'data/recipes.lua')
        if raw and raw:find('D.Recipes', 1, true) then return raw end
    end
    local raw = try(want)
    if raw then return raw, want end
    local others = {}
    for i = 0, (GetNumResources and GetNumResources() or 0) - 1 do
        local r = GetResourceByFindIndex(i)
        if r and r ~= want then
            if r:lower():find('cuisine', 1, true) then table.insert(others, 1, r) else others[#others + 1] = r end
        end
    end
    for _, r in ipairs(others) do
        raw = try(r)
        if raw then return raw, r end
    end
    local state = GetResourceState and GetResourceState(want) or '?'
    if state == 'missing' then
        return nil, nil, ('la ressource « %s » est absente du serveur : copiez le dossier %s dans resources, puis « ensure %s » AVANT elyzea_inventory dans server.cfg, et redémarrez le serveur'):format(want, want, want)
    end
    return nil, nil, ('fichier data/recipes.lua introuvable dans « %s » (état : %s) : vérifiez que le dossier contient bien data/recipes.lua'):format(want, state)
end

local function loadRecipes()
    local raw, res, why = FindRecipes()
    if not raw then return nil, why end
    local chunk, err = load(raw, '@' .. res .. '/data/recipes.lua', 't', {
        ipairs = ipairs, pairs = pairs, type = type, tostring = tostring, tonumber = tonumber, math = math, string = string, table = table,
    })
    if not chunk then return nil, err end
    local ok, D = pcall(chunk)
    if not ok or type(D) ~= 'table' or type(D.Recipes) ~= 'table' then return nil, ok and 'données invalides' or D end
    return D, res
end

-- Règle de préparation d'une recette
function RSCuisine.Rule(r)
    for _, rule in ipairs(C.rules or {}) do
        local hit = true
        if rule.kind and rule.kind ~= r.kind then hit = false end
        if hit and rule.match then
            hit = false
            for _, m in ipairs(rule.match) do if tostring(r.id):find(m, 1, true) then hit = true break end end
        end
        if hit then return rule end
    end
    return { game = 'plat', station = 'stove' }
end

-- Prix de départ : base du type + un peu selon ce que la recette rend (faim + soif)
function RSCuisine.Price(r)
    local base = (C.prices or {})[r.kind] or 10
    return math.floor(base + ((tonumber(r.hunger) or 0) + (tonumber(r.thirst) or 0)) / 4 + 0.5)
end

-- Ajoute les recettes au catalogue (sans doublon). Renvoie le nombre ajouté.
-- Rappelée par le serveur si elyzea_cuisine n'était pas encore là au démarrage.
function RSCuisine.Load()
    if C.enabled == false then return 0 end
    local D, res = loadRecipes()
    if not D then
        RSCuisine.error = tostring(res)
        return 0
    end
    RSCuisine.error, RSCuisine.resource = nil, res
    local have = {}
    for _, p in ipairs(Config.Products) do have[p.id] = true end
    local catSeen = {}
    for _, c in ipairs(Config.Categories) do catSeen[c.id] = true end
    for _, c in ipairs(D.Categories or {}) do
        if not catSeen[c.id] then
            catSeen[c.id] = true
            Config.Categories[#Config.Categories + 1] = { id = c.id, label = c.label, icon = (C.categories or {})[c.id] or '🍽️', color = c.color, cuisine = true }
        end
    end
    local added = 0
    for _, r in ipairs(D.Recipes) do
        if type(r) == 'table' and type(r.id) == 'string' and not have[r.id] then
            have[r.id] = true
            local rule = RSCuisine.Rule(r)
            local heavy = ((tonumber(r.hunger) or 0) + (tonumber(r.thirst) or 0)) >= 34
            Config.Products[#Config.Products + 1] = {
                id = r.id, item = r.id, cat = r.cat, label = r.label, desc = r.desc, price = RSCuisine.Price(r), image = r.id .. '.png',
                game = rule.game, station = rule.station, difficulty = heavy and 2 or 1, duration = rule.game == 'plat' and 35 or 25,
                steps = rule.game == 'plat' and (heavy and 4 or 3) or (rule.game == 'drink' and 1 or 4),
                cook = rule.cook ~= false, kind = r.kind, cuisine = true,
            }
            added = added + 1
        end
    end
    RSCuisine.count = RSCuisine.count + added
    return added
end

RSCuisine.Load()
if IsDuplicityVersion() then
    if RSCuisine.error then print(('^3[RESTO] Recettes elyzea_cuisine non chargées : %s^0'):format(RSCuisine.error))
    elseif RSCuisine.resource ~= (C.resource or 'elyzea_cuisine') then print(('^3[RESTO] Recettes trouvées dans la ressource « %s ».^0'):format(RSCuisine.resource)) end
end
