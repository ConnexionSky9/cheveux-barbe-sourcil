-- =====================================================================
--  ELYZEA RESTAURANT - mini-jeux de cuisine : défis et validation (SERVEUR)
--  Chaque mini-jeu a deux fonctions :
--    gen(difficulty, steps, rnd)  → paramètres envoyés au joueur (zones, recette…)
--    check(params, result, ms)    → true, ou false + raison
--  Le serveur garde les paramètres ; le joueur ne renvoie que ses réponses.
--  Ajouter un mini-jeu : une entrée ici + un module dans html/kitchen.js
--  (même nom), puis « game = 'nom' » dans un produit de config.lua.
-- =====================================================================
RSGames = {}

local function clampDiff(d) d = math.floor(tonumber(d) or 1) return d < 1 and 1 or (d > 3 and 3 or d) end
local function num(v) v = tonumber(v) if not v or v ~= v or v == math.huge or v == -math.huge then return nil end return v end

-- Jauge : zone verte [from, to] sur 0-100, vitesse (aller-retours par seconde)
local GAUGE_W = { 22, 15, 10 }
local GAUGE_SPEED = { 0.55, 0.75, 1.0 }
local function gauge(diff, rnd)
    local w = GAUGE_W[diff]
    local c = rnd(20 + w // 2, 80 - w // 2)
    return { from = c - w / 2, to = c + w / 2, speed = GAUGE_SPEED[diff] }
end
local function inGauge(z, v)
    v = num(v)
    return v ~= nil and v >= z.from - 0.5 and v <= z.to + 0.5
end
local function shuffle(list, rnd)
    for i = #list, 2, -1 do local j = rnd(1, i) list[i], list[j] = list[j], list[i] end
    return list
end

-- ---------------------------------------------------------------------
-- Burger : cuisson (jauge, 1 ou 2 steaks) puis montage dans l'ordre de la recette
-- ---------------------------------------------------------------------
local BURGER_MID = { 'patty', 'cheese', 'salad', 'tomato', 'onion', 'bacon', 'sauce', 'pickles' }
RSGames.burger = {
    gen = function(diff, steps, rnd)
        diff = clampDiff(diff)
        local cook = {}
        for i = 1, (diff >= 3 and 2 or 1) do cook[i] = gauge(diff, rnd) end
        local mid = math.max(2, math.min(#BURGER_MID, (tonumber(steps) or 4) - 2))
        local pool = shuffle({ table.unpack(BURGER_MID) }, rnd)
        local recipe = { 'bun_bottom' }
        local hasPatty = false
        for i = 1, mid do recipe[#recipe + 1] = pool[i] if pool[i] == 'patty' then hasPatty = true end end
        if not hasPatty then recipe[2] = 'patty' end
        recipe[#recipe + 1] = 'bun_top'
        local palette = { 'bun_bottom', 'bun_top' }
        for _, k in ipairs(BURGER_MID) do palette[#palette + 1] = k end
        return { cook = cook, recipe = recipe, palette = shuffle(palette, rnd) }
    end,
    check = function(p, r)
        if type(r.gauge) ~= 'table' or #r.gauge ~= #p.cook then return false, 'Cuisson incomplète.' end
        for i, z in ipairs(p.cook) do if not inGauge(z, r.gauge[i]) then return false, 'Steak mal cuit.' end end
        if type(r.seq) ~= 'table' or #r.seq ~= #p.recipe then return false, 'Montage incomplet.' end
        for i, k in ipairs(p.recipe) do if r.seq[i] ~= k then return false, 'Ingrédients dans le mauvais ordre.' end end
        return true
    end,
}

-- ---------------------------------------------------------------------
-- Pizza : poser la garniture sur les repères, puis cuisson (jauge)
-- ---------------------------------------------------------------------
local PIZZA_TOL = { 9, 7, 5 }
RSGames.pizza = {
    gen = function(diff, steps, rnd)
        diff = clampDiff(diff)
        local n = math.max(2, math.min(8, tonumber(steps) or 4))
        local spots = {}
        local tries = 0
        while #spots < n and tries < 200 do
            tries = tries + 1
            local a, d = rnd(0, 359) * math.pi / 180, rnd(8, 34)
            local s = { x = math.floor(50 + math.cos(a) * d + 0.5), y = math.floor(50 + math.sin(a) * d + 0.5) }
            local ok = true
            for _, o in ipairs(spots) do if (o.x - s.x) ^ 2 + (o.y - s.y) ^ 2 < 144 then ok = false break end end
            if ok then spots[#spots + 1] = s end
        end
        return { spots = spots, tol = PIZZA_TOL[diff], bake = gauge(diff, rnd) }
    end,
    check = function(p, r)
        if type(r.spots) ~= 'table' or #r.spots ~= #p.spots then return false, 'Garniture incomplète.' end
        local used = {}
        for _, s in ipairs(p.spots) do
            local hit = false
            for j, c in ipairs(r.spots) do
                local x, y = num(type(c) == 'table' and c.x), num(type(c) == 'table' and c.y)
                if not used[j] and x and y and (x - s.x) ^ 2 + (y - s.y) ^ 2 <= (p.tol + 0.5) ^ 2 then used[j] = true hit = true break end
            end
            if not hit then return false, 'Garniture mal placée.' end
        end
        if not inGauge(p.bake, r.gauge) then return false, 'Pizza mal cuite.' end
        return true
    end,
}

-- ---------------------------------------------------------------------
-- Boisson : remplir jusqu'au trait (bande cible)
-- ---------------------------------------------------------------------
local DRINK_W = { 14, 10, 7 }
local DRINK_RATE = { 22, 28, 34 }   -- % par seconde
RSGames.drink = {
    gen = function(diff, _, rnd)
        diff = clampDiff(diff)
        local w = DRINK_W[diff]
        local c = rnd(55 + w // 2, 92 - w // 2)
        return { from = c - w / 2, to = c + w / 2, rate = DRINK_RATE[diff] }
    end,
    check = function(p, r, ms)
        local v = num(r.level)
        if not v or v < p.from - 0.5 or v > p.to + 0.5 then return false, 'Verre mal rempli.' end
        -- Remplir jusqu'à v prend au moins v / rate secondes
        if ms and ms < (v / p.rate) * 1000 * 0.85 then return false, 'Remplissage trop rapide.' end
        return true
    end,
}

-- ---------------------------------------------------------------------
-- Dessert : choisir exactement les ingrédients de la fiche parmi des leurres
-- ---------------------------------------------------------------------
local DESSERT = { 'cream', 'caramel', 'chocolate', 'strawberry', 'nuts', 'vanilla', 'sprinkles', 'mint', 'biscuit', 'honey', 'banana', 'coconut' }
local DESSERT_DECOYS = { 3, 5, 7 }
RSGames.dessert = {
    gen = function(diff, steps, rnd)
        diff = clampDiff(diff)
        local pool = shuffle({ table.unpack(DESSERT) }, rnd)
        local n = math.max(2, math.min(6, tonumber(steps) or 3))
        local need, shown = {}, {}
        for i = 1, n do need[i] = pool[i] shown[#shown + 1] = pool[i] end
        for i = n + 1, math.min(#pool, n + DESSERT_DECOYS[diff]) do shown[#shown + 1] = pool[i] end
        return { need = need, shown = shuffle(shown, rnd), ordered = diff >= 3 }
    end,
    check = function(p, r)
        if type(r.picked) ~= 'table' or #r.picked ~= #p.need then return false, 'Mauvais ingrédients.' end
        if p.ordered then
            for i, k in ipairs(p.need) do if r.picked[i] ~= k then return false, 'Ingrédients dans le mauvais ordre.' end end
            return true
        end
        local want = {}
        for _, k in ipairs(p.need) do want[k] = true end
        local seen = {}
        for _, k in ipairs(r.picked) do
            if not want[k] or seen[k] then return false, 'Mauvais ingrédients.' end
            seen[k] = true
        end
        return true
    end,
}

-- ---------------------------------------------------------------------
-- Frites : sortir le panier quand elles sont dorées (fenêtre de temps)
-- ---------------------------------------------------------------------
local FRIES_W = { 18, 12, 8 }
RSGames.fries = {
    gen = function(diff, _, rnd)
        diff = clampDiff(diff)
        local w = FRIES_W[diff]
        local s = rnd(45, 70 - w // 2)
        return { from = s, to = s + w, cookMs = 7000 }
    end,
    check = function(p, r, ms)
        local t = num(r.t)
        if not t or t < p.from - 0.5 or t > p.to + 0.5 then return false, t and t > p.to and 'Frites brûlées.' or 'Frites pas assez cuites.' end
        if ms and ms < (t / 100) * p.cookMs * 0.85 then return false, 'Cuisson trop rapide.' end
        return true
    end,
}

-- ---------------------------------------------------------------------
-- Plat (recettes elyzea_cuisine) : cuisson (jauge, sauf plats froids) puis
-- dressage avec les bons ingrédients de la cuisine du produit, parmi des leurres
-- (dans l'ordre en difficile). Les noms / emojis sont envoyés avec le défi.
-- ---------------------------------------------------------------------
local PLAT_DECOYS = { 3, 4, 6 }
RSGames.plat = {
    gen = function(diff, steps, rnd, product)
        diff = clampDiff(diff)
        local ings = ((Config.Cuisine or {}).ingredients or {})[product and product.cat or ''] or ((Config.Cuisine or {}).ingredients or {}).fastfood or {}
        local keys = {}
        for k in pairs(ings) do keys[#keys + 1] = k end
        table.sort(keys)
        local pool = shuffle(keys, rnd)
        local n = math.max(2, math.min(6, tonumber(steps) or 3, #pool))
        local need, shown, labels = {}, {}, {}
        for i = 1, n do need[i] = pool[i] shown[#shown + 1] = pool[i] end
        for i = n + 1, math.min(#pool, n + PLAT_DECOYS[diff]) do shown[#shown + 1] = pool[i] end
        for _, k in ipairs(shown) do labels[k] = ings[k] end
        return { cook = (not product or product.cook ~= false) and gauge(diff, rnd) or nil, need = need, shown = shuffle(shown, rnd),
            labels = labels, ordered = diff >= 3 }
    end,
    check = function(p, r)
        if p.cook and not inGauge(p.cook, r.gauge) then return false, 'Cuisson ratée.' end
        if type(r.picked) ~= 'table' or #r.picked ~= #p.need then return false, 'Mauvais ingrédients.' end
        if p.ordered then
            for i, k in ipairs(p.need) do if r.picked[i] ~= k then return false, 'Ingrédients dans le mauvais ordre.' end end
            return true
        end
        local want, seen = {}, {}
        for _, k in ipairs(p.need) do want[k] = true end
        for _, k in ipairs(r.picked) do
            if not want[k] or seen[k] then return false, 'Mauvais ingrédients.' end
            seen[k] = true
        end
        return true
    end,
}

-- Défi d'un produit : paramètres prêts à envoyer (product : fiche du produit, pour les jeux qui en ont besoin)
function RSGames.Generate(game, difficulty, steps, rnd, product)
    local g = RSGames[game]
    if type(g) ~= 'table' or not g.gen then return nil end
    return g.gen(difficulty, steps, rnd or math.random, product)
end
function RSGames.Check(game, params, result, ms)
    local g = RSGames[game]
    if type(g) ~= 'table' or not g.check or type(result) ~= 'table' then return false, 'Résultat invalide.' end
    local ok, a, b = pcall(g.check, params, result, ms)
    if not ok then return false, 'Résultat invalide.' end
    return a == true, b
end
