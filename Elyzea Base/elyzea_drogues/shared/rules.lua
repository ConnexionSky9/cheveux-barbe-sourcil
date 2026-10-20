-- =====================================================================
--  ELYZEA DROGUES · règles pures (serveur et tests hors jeu)
--  Réglages (valeurs par défaut issues de config/*.lua + nettoyage de ce qui vient du menu admin),
--  cumul des prises, objets → produits.
-- =====================================================================
DrugRules = {}

local function int(v, lo, hi, def)
    v = tonumber(v)
    if not v or v ~= v then return def end
    return math.max(lo, math.min(hi, math.floor(v)))
end
local function num(v, lo, hi, def)
    v = tonumber(v)
    if not v or v ~= v then return def end
    return math.max(lo, math.min(hi, v + 0.0))
end
DrugRules.int, DrugRules.num = int, num

local function copy(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = copy(v) end
    return o
end
DrugRules.copy = copy

local function itemName(v) return type(v) == 'string' and v:match('^[%w_%-]+$') and #v <= 50 and v or nil end
DrugRules.itemName = itemName

local function itemList(list, def, maxN)
    if type(list) ~= 'table' then return copy(def) end
    local out = {}
    for _, e in ipairs(list) do
        local it = type(e) == 'table' and itemName(e[1] or e.item) or nil
        local n = type(e) == 'table' and int(e[2] or e.count, 1, 100, nil) or nil
        if it and n and #out < (maxN or 6) then out[#out + 1] = { it, n } end
    end
    return out
end

local function color(c, def)
    if type(c) ~= 'table' then return copy(def) end
    return { int(c[1] or c.r, 0, 255, def[1]), int(c[2] or c.g, 0, 255, def[2]), int(c[3] or c.b, 0, 255, def[3]) }
end

-- ---------------------------------------------------------------- valeurs par défaut
function DrugRules.Defaults()
    local s = { drugs = {}, trip = {}, creatures = {}, recipes = {}, prices = {}, shop = {}, sale = {}, varieties = {}, culture = {}, harvest = {} }
    for id, d in pairs(Config.Drugs) do s.drugs[id] = { enabled = true, duration = d.duration, cooldown = d.cooldown, intensity = d.intensity or 100 } end
    local t = Config.Trip
    s.trip = { maxCreatures = t.maxCreatures, spawnEvery = t.spawnEvery, hitCooldown = t.hitCooldown, fallTime = t.fallTime, lifetime = t.lifetime }
    for _, c in ipairs(t.creatures) do s.creatures[c.model] = true end
    for id, r in pairs(Config.Recipes or {}) do
        s.recipes[id] = { enabled = r.enabled ~= false, duration = r.duration, loss = r.loss or 0, inputs = copy(r.inputs), outputs = copy(r.outputs) }
    end
    for it, p in pairs(Config.Prices or {}) do s.prices[it] = { price = p.price, max = p.max or 10 } end
    for i, e in ipairs(Config.Shop or {}) do s.shop[i] = { item = e.item, price = e.price } end
    local sa = Config.Sale or {}
    s.sale = { paymentType = (sa.payment or {}).type or 'item', paymentItem = (sa.payment or {}).item or 'black_money', paymentAccount = (sa.payment or {}).account or 'cash',
        cooldown = sa.cooldown or 4, hourlyLimit = sa.hourlyLimit or 0 }
    for id, v in pairs(Config.Varieties or {}) do
        s.varieties[id] = { label = v.label, color = copy(v.color), growMinutes = v.growMinutes, yieldMin = v.yield.min, yieldMax = v.yield.max,
            seedChance = v.seedChance, prepStep = v.prepStep ~= false }
    end
    local c = Config.Culture or { water = {} }
    s.culture = { maxPotsPerPlayer = c.maxPotsPerPlayer, minDistance = c.minDistance, ownerOnlyHarvest = c.ownerOnlyHarvest == true,
        waterPerUse = c.water.perUse, waterDecayPerHour = c.water.decayPerHour, waterNeedBelow = c.water.needBelow,
        healthLossPerHourDry = c.healthLossPerHourDry, lampFactor = c.lampFactor, noLampFactor = c.noLampFactor,
        fertilizerBoost = c.fertilizerBoost, deadRemoveHours = c.deadRemoveHours, policeCanDestroy = c.policeCanDestroy ~= false }
    for id, h in pairs(Config.Harvest or {}) do s.harvest[id] = { enabled = true, min = h.min, max = h.max, respawn = h.respawn, duration = h.duration } end
    return s
end

-- ---------------------------------------------------------------- nettoyage (menu admin / base)
-- Chaque section est bornée ; ce qui n'existe pas dans la config est ignoré. Renvoie la table ou nil + raison.
function DrugRules.Clean(input)
    local def = DrugRules.Defaults()
    if type(input) ~= 'table' then return def end
    local out = DrugRules.Defaults()
    local function sec(k) return type(input[k]) == 'table' and input[k] or {} end

    for id, d in pairs(def.drugs) do
        local x = type(sec('drugs')[id]) == 'table' and sec('drugs')[id] or {}
        out.drugs[id] = { enabled = x.enabled ~= false, duration = int(x.duration, 10, 3600, d.duration),
            cooldown = int(x.cooldown, 0, 3600, d.cooldown), intensity = int(x.intensity, 25, 200, d.intensity) }
    end
    local t = sec('trip')
    out.trip = { maxCreatures = int(t.maxCreatures, 1, 12, def.trip.maxCreatures), spawnEvery = int(t.spawnEvery, 2, 120, def.trip.spawnEvery),
        hitCooldown = int(t.hitCooldown, 1, 60, def.trip.hitCooldown), fallTime = int(t.fallTime, 1, 15, def.trip.fallTime),
        lifetime = int(t.lifetime, 5, 300, def.trip.lifetime) }
    local any = false
    for model in pairs(def.creatures) do
        local on = sec('creatures')[model] ~= false
        out.creatures[model] = on
        if on then any = true end
    end
    if not any then return nil, 'Garde au moins une créature pour les hallucinations.' end

    for id, r in pairs(def.recipes) do
        local x = type(sec('recipes')[id]) == 'table' and sec('recipes')[id] or {}
        local ins, outs = itemList(x.inputs, r.inputs), itemList(x.outputs, r.outputs)
        if #ins == 0 then return nil, ('Recette « %s » : au moins un ingrédient.'):format(id) end
        if #outs == 0 then return nil, ('Recette « %s » : au moins un produit obtenu.'):format(id) end
        out.recipes[id] = { enabled = x.enabled ~= false, duration = int(x.duration, 1, 600, r.duration), loss = int(x.loss, 0, 90, r.loss), inputs = ins, outputs = outs }
    end
    -- prix : objets de la config + objets ajoutés dans le menu (nom valide)
    local pr = sec('prices')
    for it, p in pairs(pr) do
        local name = itemName(it)
        if name and type(p) == 'table' then
            local d = def.prices[name] or { price = 0, max = 10 }
            out.prices[name] = { price = int(p.price, 0, 1000000, d.price), max = int(p.max, 1, 500, d.max) }
        end
    end
    if type(input.shop) == 'table' then
        out.shop = {}
        for _, e in ipairs(input.shop) do
            local name = type(e) == 'table' and itemName(e.item) or nil
            if name and #out.shop < 60 then out.shop[#out.shop + 1] = { item = name, price = int(e.price, 0, 1000000, 0) } end
        end
    end
    local sa = sec('sale')
    out.sale = { paymentType = (sa.paymentType == 'money' or sa.paymentType == 'item') and sa.paymentType or def.sale.paymentType,
        paymentItem = itemName(sa.paymentItem) or def.sale.paymentItem,
        paymentAccount = (sa.paymentAccount == 'cash' or sa.paymentAccount == 'bank') and sa.paymentAccount or def.sale.paymentAccount,
        cooldown = int(sa.cooldown, 0, 300, def.sale.cooldown), hourlyLimit = int(sa.hourlyLimit, 0, 100000, def.sale.hourlyLimit) }

    for id, v in pairs(def.varieties) do
        local x = type(sec('varieties')[id]) == 'table' and sec('varieties')[id] or {}
        local label = type(x.label) == 'string' and x.label:gsub('[%c<>]', ''):sub(1, 32) or ''
        local ymin = int(x.yieldMin, 1, 50, v.yieldMin)
        out.varieties[id] = { label = label ~= '' and label or v.label, color = color(x.color, v.color),
            growMinutes = int(x.growMinutes, 1, 10080, v.growMinutes), yieldMin = ymin, yieldMax = math.max(ymin, int(x.yieldMax, 1, 50, v.yieldMax)),
            seedChance = int(x.seedChance, 0, 100, v.seedChance), prepStep = x.prepStep ~= false }
    end
    local c, dc = sec('culture'), def.culture
    out.culture = { maxPotsPerPlayer = int(c.maxPotsPerPlayer, 0, 50, dc.maxPotsPerPlayer), minDistance = num(c.minDistance, 0.5, 20, dc.minDistance),
        ownerOnlyHarvest = c.ownerOnlyHarvest == nil and dc.ownerOnlyHarvest or c.ownerOnlyHarvest == true,
        waterPerUse = int(c.waterPerUse, 5, 100, dc.waterPerUse), waterDecayPerHour = num(c.waterDecayPerHour, 0, 100, dc.waterDecayPerHour),
        waterNeedBelow = int(c.waterNeedBelow, 5, 100, dc.waterNeedBelow), healthLossPerHourDry = num(c.healthLossPerHourDry, 0, 100, dc.healthLossPerHourDry),
        lampFactor = num(c.lampFactor, 0.1, 10, dc.lampFactor), noLampFactor = num(c.noLampFactor, 0, 10, dc.noLampFactor),
        fertilizerBoost = num(c.fertilizerBoost, 1, 5, dc.fertilizerBoost), deadRemoveHours = int(c.deadRemoveHours, 1, 720, dc.deadRemoveHours),
        policeCanDestroy = c.policeCanDestroy == nil and dc.policeCanDestroy or c.policeCanDestroy == true }
    for id, h in pairs(def.harvest) do
        local x = type(sec('harvest')[id]) == 'table' and sec('harvest')[id] or {}
        local mn = int(x.min, 1, 50, h.min)
        out.harvest[id] = { enabled = x.enabled ~= false, min = mn, max = math.max(mn, int(x.max, 1, 50, h.max)),
            respawn = int(x.respawn, 5, 86400, h.respawn), duration = int(x.duration, 1, 120, h.duration) }
    end
    return out
end

-- Recette effective (réglages + config) : nil si inconnue. L'étape « préparer » désactivée pour une variété
-- coupe la recette de préparation et fait rouler directement les têtes.
function DrugRules.Recipe(S, id)
    local base = Config.Recipes[id]
    local set = S.recipes[id]
    if not base or not set then return nil end
    local r = { id = id, label = base.label, drug = base.drug, step = base.step, station = base.station, variety = base.variety,
        enabled = set.enabled, duration = set.duration, loss = set.loss, inputs = copy(set.inputs), outputs = copy(set.outputs) }
    local v = base.variety and S.varieties[base.variety]
    if v and base.prepStep and not v.prepStep then r.enabled = false end
    if v and base.rollStep and not v.prepStep then
        local cv = Config.Varieties[base.variety]
        for _, e in ipairs(r.inputs) do if e[1] == cv.ground then e[1] = cv.bud end end
    end
    if S.drugs[base.drug] and not S.drugs[base.drug].enabled then r.enabled = false end
    return r
end

-- Produit consommable d'un objet (nil si l'objet ne se consomme pas)
function DrugRules.Product(item) return Config.Products[item] end
function DrugRules.DrugOfItem(item) local p = Config.Products[item] return p and p.drug or nil end

-- Fin de l'effet après une prise : la même drogue reprise prolonge, jusqu'à maxStack × la durée
function DrugRules.Extend(currentUntil, now, duration, maxStack)
    local base = math.max(currentUntil or 0, now)
    return math.min(base + duration, now + duration * (maxStack or 2))
end

-- Couleur de fumée d'un produit (variété : réglage du menu)
function DrugRules.SmokeColor(S, product)
    if not product or not product.smoke then return nil end
    if type(product.smoke) == 'table' then return product.smoke end
    local v = tostring(product.smoke):match('^variety:(.+)$')
    local set = v and S.varieties[v]
    return set and set.color or { 200, 200, 200 }
end
