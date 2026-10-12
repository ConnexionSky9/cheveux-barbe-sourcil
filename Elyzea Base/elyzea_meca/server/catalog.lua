-- =====================================================================
--  ELYZEA MÉCANO - serveur : catalogue et tarifs (direction)
--  · Tous les articles vendus sont en base (meca_catalog) : prix, activation,
--    grade minimum, pièce de stock consommée, compatibilité.
--  · Au premier démarrage, Config.DefaultCatalog est copié en base ; ensuite
--    tout se règle dans la tablette › Direction › Catalogue et tarifs.
--  · Le prix d'un devis est copié dans le devis : un changement de tarif ne
--    touche que les nouveaux devis.
-- =====================================================================
local P = Meca

P.catalog = {}          -- [code] = article

P.KINDS = { service = true, perf = true, cosmetic = true, carplay = true, custom = true }
P.CATEGORIES = { service = 'Prestations', perf = 'Performances', cosmetic = 'Carrosserie', paint = 'Peinture et vitres', wheels = 'Roues',
    lights = 'Éclairage', interior = 'Intérieur', carplay = 'CarPlay' }
-- Améliorations de performance gérées (mod GTA) et esthétiques (groupes de pièces)
P.PERF_MODS = { engine = 11, brakes = 12, transmission = 13, suspension = 15, armor = 16, turbo = 18 }
P.COSMETIC = { body = true, paint = true, pearl = true, livery = true, tint = true, plate = true, wheels = true, wheelcolor = true,
    smoke = true, neon = true, xenon = true, interior = true }
-- Permission nécessaire pour vendre / installer chaque type
P.KIND_PERM = { service = 'quotes', custom = 'quotes', perf = 'perf', cosmetic = 'cosmetic', carplay = 'carplay' }

local function Row(r)
    return { id = r.id, code = r.code, name = r.name, description = r.description, category = r.category, kind = r.kind,
        mod = r.mod_key, level = tonumber(r.level), price = tonumber(r.price) or 0, enabled = r.enabled == 1 or r.enabled == true,
        minLevel = tonumber(r.min_level) or 1, part = r.part_code, partQty = tonumber(r.part_qty) or 1, compat = r.compat, sort = tonumber(r.sort) or 0 }
end

function P.LoadCatalog()
    P.catalog = {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `meca_catalog`') or {}) do P.catalog[r.code] = Row(r) end
end

local function Seed()
    for i, c in ipairs(Config.DefaultCatalog) do
        MySQL.insert.await([[INSERT IGNORE INTO `meca_catalog` (`code`, `name`, `description`, `category`, `kind`, `mod_key`, `level`, `price`, `enabled`, `min_level`, `part_code`, `sort`, `updated_by`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'Installation')]], { c.code, c.name, c.description, c.category, c.kind, c.mod, c.level, c.price,
            c.enabled == false and 0 or 1, c.minLevel or 1, c.part, i })
    end
    print('^2[MECA] Catalogue de départ créé.^0')
end

P.OnReady = P.OnReady or {}
P.OnReady[#P.OnReady + 1] = function()
    if (tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `meca_catalog`')) or 0) == 0 then Seed() end
    P.LoadCatalog()
end

function P.SortedCatalog()
    local list = {}
    for _, c in pairs(P.catalog) do list[#list + 1] = c end
    table.sort(list, function(a, b)
        if a.category ~= b.category then return a.category < b.category end
        if a.sort ~= b.sort then return a.sort < b.sort end
        return a.code < b.code
    end)
    return list
end

-- Un employé peut-il vendre cet article ?
function P.CanSell(src, item)
    if not item or not item.enabled then return false, 'Article indisponible.' end
    local g = P.Grade(src)
    if not g or g.level < (item.minLevel or 1) then return false, ('« %s » demande un grade plus élevé.'):format(item.name) end
    local perm = P.KIND_PERM[item.kind] or 'quotes'
    if not P.Can(src, perm) then return false, ('Votre grade ne permet pas de vendre « %s ».'):format(item.name) end
    return true
end

P.Actions.catalog = { perm = 'tablet', fn = function(src)
    local list = P.SortedCatalog()
    local parts = {}
    for _, r in ipairs(MySQL.query.await('SELECT `code`, `label`, `qty` FROM `meca_stock` ORDER BY `label`') or {}) do parts[#parts + 1] = r end
    local carplay = MySQL.single.await([[SELECT COUNT(*) AS n,
        (SELECT COALESCE(SUM(`price`), 0) FROM `meca_carplay`) AS total FROM `meca_carplay`]]) or {}
    return { list = list, categories = P.CATEGORIES, parts = parts, canEdit = P.Can(src, 'catalog_manage'), maxPrice = Config.Catalog.maxPrice,
        perfMods = P.PERF_MODS, cosmetic = P.COSMETIC, carplay = { count = tonumber(carplay.n) or 0, revenue = tonumber(carplay.total) or 0 },
        grades = (function() local l = {} for _, g in ipairs(P.SortedGrades()) do l[#l + 1] = { level = g.level, name = g.name } end return l end)() }
end }

P.Actions.catalogSave = { perm = 'catalog_manage', fn = function(src, d)
    local code = tostring(d.code or ''):lower():gsub('[^%w_]', ''):sub(1, 40)
    local existing = P.catalog[code]
    if code == '' then return { error = 'Code invalide (lettres, chiffres, _).' } end
    if d.isNew and existing then return { error = 'Ce code existe déjà.' } end
    if not d.isNew and not existing then return { error = 'Article introuvable.' } end
    local name = P.Clean(d.name, 80)
    if #name < 2 then return { error = 'Nom trop court.' } end
    local kind = existing and existing.kind or tostring(d.kind or 'custom')
    if not P.KINDS[kind] then return { error = 'Type inconnu.' } end
    local category = tostring(d.category or (existing and existing.category) or 'service')
    if not P.CATEGORIES[category] then return { error = 'Catégorie inconnue.' } end
    local price = P.Int(d.price, 0, Config.Catalog.maxPrice, nil)
    if not price then return { error = ('Prix invalide (0 à %d $).'):format(Config.Catalog.maxPrice) } end
    local minLevel = P.Int(d.minLevel, 1, 99, 1)
    local mod, level = existing and existing.mod or nil, existing and existing.level or nil
    if d.isNew then
        -- Nouveaux articles : prestations libres, ou un niveau de performance / une pièce esthétique gérés par l'atelier
        if kind == 'perf' then
            mod = tostring(d.mod or '')
            if not P.PERF_MODS[mod] then return { error = 'Amélioration inconnue.' } end
            level = P.Int(d.level, 1, 10, nil)
            if not level then return { error = 'Niveau invalide.' } end
            category = 'perf'
        elseif kind == 'cosmetic' then
            mod = tostring(d.mod or '')
            if not P.COSMETIC[mod] then return { error = 'Groupe esthétique inconnu.' } end
        elseif kind == 'carplay' then
            return { error = 'Les articles CarPlay sont fixes (Installation / Réinstallation) : modifiez leur prix.' }
        end
    end
    local part = d.part and tostring(d.part):lower():gsub('[^%w_]', ''):sub(1, 30) or nil
    if part == '' then part = nil end
    if part and (tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `meca_stock` WHERE `code` = ?', { part })) or 0) == 0 then
        return { error = 'Pièce de stock inconnue.' }
    end
    local partQty = P.Int(d.partQty, 1, 50, 1)
    local enabled = d.enabled ~= false
    local desc = P.Clean(d.description, 255)
    local compat = P.Clean(d.compat, 120)
    if d.isNew then
        MySQL.insert.await([[INSERT INTO `meca_catalog` (`code`, `name`, `description`, `category`, `kind`, `mod_key`, `level`, `price`, `enabled`, `min_level`, `part_code`, `part_qty`, `compat`, `sort`, `updated_by`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 999, ?)]], { code, name, desc ~= '' and desc or nil, category, kind, mod, level, price, enabled and 1 or 0, minLevel,
            part, partQty, compat ~= '' and compat or nil, P.Name(src) })
    else
        MySQL.update.await([[UPDATE `meca_catalog` SET `name` = ?, `description` = ?, `category` = ?, `price` = ?, `enabled` = ?, `min_level` = ?, `part_code` = ?, `part_qty` = ?,
            `compat` = ?, `updated_by` = ? WHERE `code` = ?]], { name, desc ~= '' and desc or nil, (kind == 'perf' or kind == 'carplay') and existing.category or category,
            price, enabled and 1 or 0, minLevel, part, partQty, compat ~= '' and compat or nil, P.Name(src), code })
    end
    local old = existing and existing.price
    P.LoadCatalog()
    P.AddLog(src, nil, nil, d.isNew and 'Article créé' or 'Article modifié', nil, name,
        old and old ~= price and ('%d $ → %d $ (nouveaux devis)'):format(old, price) or ('%d $'):format(price))
    return { ok = true, message = d.isNew and ('« %s » ajouté au catalogue.'):format(name) or ('« %s » enregistré (prochains devis).'):format(name) }
end }

-- Suppression : seulement les articles créés par la direction (prestations libres) ; les autres se désactivent
P.Actions.catalogDelete = { perm = 'catalog_manage', fn = function(src, d)
    local c = P.catalog[tostring(d.code or '')]
    if not c then return { error = 'Article introuvable.' } end
    if c.kind ~= 'custom' then return { error = 'Cet article fait partie du système : désactivez-le plutôt.' } end
    MySQL.update.await('DELETE FROM `meca_catalog` WHERE `code` = ?', { c.code })
    P.LoadCatalog()
    P.AddLog(src, nil, nil, 'Article supprimé', nil, c.name, nil)
    return { ok = true, message = ('« %s » supprimé du catalogue (les anciennes factures le gardent).'):format(c.name) }
end }
