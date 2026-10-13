-- =====================================================================
--  ELYZEA CONCESSION - serveur : catalogue global et catalogue de chaque concession
--  Trois niveaux :
--   1. Catalogue global (staff) : modèles et catégories, actifs ou non.
--   2. Configuration de chaque concession : catégories (activée, visible, vendable,
--      ordre) et modèles (activé, visible, vendable, exposable, prix propre).
--      Une concession ne modifie JAMAIS la configuration d'une autre.
--   3. En jeu : catalogue client (lecture seule), tablette, vente, exposition.
--  Règles (toutes vérifiées ici, jamais seulement cachées dans l'interface) :
--   · proposé   = modèle actif globalement (non retiré) + catégorie active globalement
--                 + catégorie activée dans la concession + modèle activé dans la concession ;
--   · visible   = proposé + catégorie visible + modèle visible ;
--   · vendable  = proposé + usage commercial (global) + catégorie vendable + modèle vendable + prix > 0 ;
--   · exposable = proposé + exposition autorisée (global) + modèle exposable.
--  Le prix d'une concession = son prix propre, sinon le prix de référence global.
-- =====================================================================
local P = Concess

P.cats = {}          -- [id] = catégorie globale
P.models = {}        -- [id] = modèle global
P.modelByName = {}   -- [nom de spawn] = id
P.shopCats = {}      -- [shop][cat] = { enabled, visible, sellable, sort }
P.shopModels = {}    -- [shop][model] = { enabled, visible, sellable, displayable, price }

local function b(v) return v == 1 or v == true end

function P.AddModelRow(r)
    P.models[r.id] = { id = r.id, model = r.model, label = r.label, brand = r.brand, categoryId = r.category_id, description = r.description, image = r.image,
        refPrice = tonumber(r.ref_price), commercial = b(r.commercial), displayable = b(r.displayable), enabled = b(r.enabled), removed = b(r.removed),
        vclass = tonumber(r.vclass), seats = tonumber(r.seats), validatedBy = r.validated_by }
    P.modelByName[r.model:lower()] = r.id
    return P.models[r.id]
end

function P.LoadCatalog()
    P.cats, P.models, P.modelByName, P.shopCats, P.shopModels = {}, {}, {}, {}, {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `cd_categories`') or {}) do
        P.cats[r.id] = { id = r.id, name = r.name, description = r.description, icon = r.icon, image = r.image, sort = tonumber(r.sort) or 0, enabled = b(r.enabled) }
    end
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `cd_models`') or {}) do P.AddModelRow(r) end
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `cd_shop_categories`') or {}) do
        P.shopCats[r.shop_id] = P.shopCats[r.shop_id] or {}
        P.shopCats[r.shop_id][r.category_id] = { enabled = b(r.enabled), visible = b(r.visible), sellable = b(r.sellable), sort = tonumber(r.sort) or 0 }
    end
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `cd_shop_models`') or {}) do
        P.shopModels[r.shop_id] = P.shopModels[r.shop_id] or {}
        P.shopModels[r.shop_id][r.model_id] = { enabled = b(r.enabled), visible = b(r.visible), sellable = b(r.sellable), displayable = b(r.displayable), price = tonumber(r.price) }
    end
end

-- Catégories de départ (une seule fois : ensuite elles se gèrent en jeu)
local function SeedCategories()
    if P.GetSetting('categoriesSeeded', false) then return end
    for i, c in ipairs(Config.DefaultCategories) do
        MySQL.insert.await('INSERT IGNORE INTO `cd_categories` (`name`, `icon`, `sort`) VALUES (?, ?, ?)', { c.name, c.icon, i * 10 })
    end
    P.SetSetting('categoriesSeeded', true)
    print('^2[CONCESS] Catégories de départ créées.^0')
end

P.OnReady[#P.OnReady + 1] = function()
    SeedCategories()
    P.LoadCatalog()
end

-- ---------------------------------------------------------------------
-- Règles
-- ---------------------------------------------------------------------
function P.ShopCat(D, catId) return (P.shopCats[D.id] or {})[catId] end
function P.ShopModel(D, modelId) return (P.shopModels[D.id] or {})[modelId] end
function P.PriceOf(D, m)
    local sm = P.ShopModel(D, m.id)
    return (sm and sm.price) or m.refPrice or 0
end

-- Renvoie la fiche du modèle dans la concession (avec ses droits), ou nil + raison
function P.Offer(D, m)
    if not D or not m then return nil, 'Modèle introuvable.' end
    if m.removed then return nil, 'Modèle retiré du catalogue.' end
    if not m.enabled then return nil, 'Modèle désactivé par le staff.' end
    local c = m.categoryId and P.cats[m.categoryId]
    if not c then return nil, 'Modèle sans catégorie.' end
    if not c.enabled then return nil, 'Catégorie désactivée par le staff.' end
    local sc, sm = P.ShopCat(D, c.id), P.ShopModel(D, m.id)
    if not sc or not sc.enabled then return nil, 'Catégorie non proposée par cette concession.' end
    if not sm or not sm.enabled then return nil, 'Modèle non proposé par cette concession.' end
    local price = P.PriceOf(D, m)
    local why
    if not m.commercial then why = 'Usage commercial interdit par le staff.'
    elseif not sc.sellable then why = 'Catégorie non vendable dans cette concession.'
    elseif not sm.sellable then why = 'Modèle non vendable dans cette concession.'
    elseif price <= 0 then why = 'Prix non défini.' end
    return {
        id = m.id, model = m.model, label = m.label, brand = m.brand, categoryId = c.id, category = c.name, categoryIcon = c.icon, catSort = sc.sort or c.sort,
        description = m.description, image = m.image, vclass = m.vclass, seats = m.seats,
        price = price, refPrice = m.refPrice, ownPrice = sm.price ~= nil,
        visible = sc.visible and sm.visible, sellable = why == nil, sellReason = why,
        displayable = m.displayable and sm.displayable,
    }
end

-- Liste des modèles proposés par une concession. filter : 'visible' | 'all'
function P.ShopOffers(D, filter)
    local list = {}
    for _, m in pairs(P.models) do
        local o = P.Offer(D, m)
        if o and (filter ~= 'visible' or o.visible) then list[#list + 1] = o end
    end
    table.sort(list, function(a, c)
        if a.catSort ~= c.catSort then return a.catSort < c.catSort end
        if a.price ~= c.price then return a.price < c.price end
        return a.label < c.label
    end)
    return list
end

-- Catégories de la concession (activées ; visibles seulement pour le client)
function P.ShopCategories(D, visibleOnly)
    local list = {}
    for id, c in pairs(P.cats) do
        local sc = P.ShopCat(D, id)
        if c.enabled and sc and sc.enabled and (not visibleOnly or sc.visible) then
            list[#list + 1] = { id = id, name = c.name, icon = c.icon, image = c.image, description = c.description, sort = sc.sort or c.sort,
                visible = sc.visible, sellable = sc.sellable }
        end
    end
    table.sort(list, function(a, c) if a.sort ~= c.sort then return a.sort < c.sort end return a.name < c.name end)
    return list
end

-- Modèles exposés par concession (présence en exposition dans le catalogue)
local function DisplayedSet(D)
    local set = {}
    for _, d in pairs(P.display and P.display[D.id] or {}) do set[d.model_id] = (set[d.model_id] or 0) + 1 end
    return set
end

-- ---------------------------------------------------------------------
-- Catalogue client : uniquement depuis le point de consultation de la concession
-- ---------------------------------------------------------------------
function P.NearPoint(src, pt, extra)
    local c, v = P.Coords(src), P.Vec(pt)
    return c ~= nil and v ~= nil and #(c - v) <= (tonumber(pt.r) or Config.Points.defaultRadius) + (extra or 3.0)
end

P.Pub.catalog = { fn = function(src, d)
    local D = P.shops[tonumber(d.shop) or 0]
    if not P.ShopOpen(D) then return { error = 'Cette concession est fermée.' } end
    local pt = D.points.catalog
    local member = P.ShopOf(src)
    -- Un employé de la concession peut l'ouvrir depuis le F6 / la tablette ; un client doit être au point
    local ticket = P.catalogTicket and P.catalogTicket[src]
    local viaNpc = ticket and ticket.shop == D.id and ticket.expires > os.time()
    if not viaNpc and not (member and member.id == D.id) and not (pt and pt.on ~= false and P.NearPoint(src, pt, 4.0)) then
        return { error = 'Rendez-vous au point de consultation du catalogue de la concession.' }
    end
    local shown = DisplayedSet(D)
    local items = {}
    for _, o in ipairs(P.ShopOffers(D, 'visible')) do
        local catVisible = true
        local sc = P.ShopCat(D, o.categoryId)
        if sc and not sc.visible then catVisible = false end
        if catVisible then
            o.displayed = shown[o.id] or 0
            o.ownPrice, o.refPrice = nil, nil   -- inutile au client
            items[#items + 1] = o
        end
    end
    return { shop = { id = D.id, name = D.name, address = D.address }, categories = P.ShopCategories(D, true), items = items,
        employee = member and member.id == D.id and { sell = P.Can(src, 'sell'), display = P.Can(src, 'display') } or nil }
end }

-- ---------------------------------------------------------------------
-- Tablette : catalogue de la concession (tous les modèles proposés, avec restrictions)
-- ---------------------------------------------------------------------
P.Actions.catalog = { perm = 'catalog', fn = function(src, _, D)
    local shown = DisplayedSet(D)
    local list = P.ShopOffers(D, 'all')
    for _, o in ipairs(list) do o.displayed = shown[o.id] or 0 end
    return { list = list, categories = P.ShopCategories(D, false), canPrices = P.Can(src, 'prices'), canSell = P.Can(src, 'sell'), canDisplay = P.Can(src, 'display'),
        maxDiscount = P.Opt(D, 'maxDiscount', 10), canDiscount = P.Can(src, 'discount') }
end }

-- Prix propre à la concession (la direction / grades autorisés). 0 ou vide = prix de référence
P.Actions.priceSet = { perm = 'prices', fn = function(src, d, D)
    local m = P.models[tonumber(d.id) or 0]
    local o = m and P.Offer(D, m)
    if not o then return { error = 'Ce modèle n\'est pas proposé par votre concession.' } end
    local new = d.price == '' and nil or P.Int(d.price, 1, Config.Sale.maxPrice, nil)
    if d.price ~= '' and not new then return { error = ('Prix invalide (1 à %d $).'):format(Config.Sale.maxPrice) } end
    local sm = P.ShopModel(D, m.id)
    local old = sm.price
    if old == new then return { ok = true } end
    MySQL.update.await('UPDATE `cd_shop_models` SET `price` = ? WHERE `shop_id` = ? AND `model_id` = ?', { new, D.id, m.id })
    sm.price = new
    MySQL.insert.await('INSERT INTO `cd_price_log` (`shop_id`, `model_id`, `model`, `old_price`, `new_price`, `actor_cid`, `actor_name`) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { D.id, m.id, m.model, old or m.refPrice, new or m.refPrice, P.Cid(src), P.Name(src) })
    P.Log(src, 'Prix modifié', ('%s · %s : %s → %s $'):format(D.name, m.label, tostring(old or m.refPrice or 0), tostring(new or m.refPrice or 0)))
    return { ok = true, message = ('%s : %d $ dans votre concession (les ventes déjà conclues ne changent pas).'):format(m.label, P.PriceOf(D, m)) }
end }

P.Actions.priceHistory = { perm = 'catalog', fn = function(_, d, D)
    local args, where = { D.id }, '`shop_id` = ?'
    if tonumber(d.id) then where = where .. ' AND `model_id` = ?' args[2] = tonumber(d.id) end
    local rows = MySQL.query.await(([[SELECT `model_id`, `model`, `old_price`, `new_price`, `actor_name`, UNIX_TIMESTAMP(`created_at`) AS t FROM `cd_price_log`
        WHERE %s ORDER BY `id` DESC LIMIT 100]]):format(where), args) or {}
    for _, r in ipairs(rows) do local m = P.models[r.model_id] r.label = m and m.label or r.model end
    return { list = rows }
end }

-- Configuration autorisée : lecture de ce que le staff a défini pour la concession
P.Actions.config = { perm = 'catalog', fn = function(_, _, D)
    local cats = {}
    for id, c in pairs(P.cats) do
        local sc = P.ShopCat(D, id)
        if sc then cats[#cats + 1] = { id = id, name = c.name, icon = c.icon, global = c.enabled, enabled = sc.enabled, visible = sc.visible, sellable = sc.sellable, sort = sc.sort } end
    end
    table.sort(cats, function(a, c) return (a.sort or 0) < (c.sort or 0) end)
    local slots = 0
    for _ in pairs(P.slots and P.slots[D.id] or {}) do slots = slots + 1 end
    return { shop = { name = D.name, address = D.address, job = D.job, society = D.society, requireDuty = P.Opt(D, 'requireDuty', true), maxDiscount = P.Opt(D, 'maxDiscount', 10) },
        categories = cats, slots = slots, exits = #(D.points.exits or {}), hasCatalog = D.points.catalog ~= nil }
end }
