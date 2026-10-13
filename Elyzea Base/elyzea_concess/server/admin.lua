-- =====================================================================
--  ELYZEA CONCESSION - serveur : administration automobile (staff)
--  Accès : admin_menu, permission « dealer_manage » (vérifiée à chaque requête).
--  · Catalogue global : modèles (vérifiés en jeu par le staff), catégories.
--  · Concessions : création, configuration, métier, compte, points, sorties,
--    emplacements d'exposition, catalogue propre (catégories, modèles, prix).
--  · Supprimer / retirer ne touche JAMAIS aux véhicules achetés (player_vehicles),
--    aux clés, aux garages ni aux historiques : tout est désactivé, rien n'est effacé.
-- =====================================================================
local P = Concess
local core = exports.elyzea_core

local function b(v) return v == true or v == 1 end
local function CatalogLog(src, action, details, ids)
    ids = ids or {}
    MySQL.insert('INSERT INTO `cd_catalog_log` (`shop_id`, `model_id`, `category_id`, `action`, `details`, `actor_name`) VALUES (?, ?, ?, ?, ?, ?)',
        { ids.shop, ids.model, ids.cat, action, details and P.Clean(details, 255) or nil, type(src) == 'number' and P.Name(src) or src })
    if GetResourceState('admin_menu') == 'started' and type(src) == 'number' then
        pcall(function() exports.admin_menu:AddLog(src, '[Automobile] ' .. action, details or '') end)
    end
end
P.CatalogLog = CatalogLog

local function StaffPos(src)
    local ped = GetPlayerPed(src)
    local veh = GetVehiclePedIsIn(ped, false)
    local ent = veh ~= 0 and veh or ped
    local c = GetEntityCoords(ent)
    local r2 = function(v) return math.floor(v * 100 + 0.5) / 100 end
    return { x = r2(c.x), y = r2(c.y), z = r2(c.z), h = r2(GetEntityHeading(ent)) }
end

-- ---------------------------------------------------------------------
-- Lecture
-- ---------------------------------------------------------------------
local function ModelView(m)
    local shops = {}
    for sid, list in pairs(P.shopModels) do
        if list[m.id] and list[m.id].enabled and P.shops[sid] and not P.shops[sid].deleted then shops[#shops + 1] = P.shops[sid].name end
    end
    local c = m.categoryId and P.cats[m.categoryId]
    return { id = m.id, model = m.model, label = m.label, brand = m.brand, categoryId = m.categoryId, category = c and c.name or nil, description = m.description,
        image = m.image, refPrice = m.refPrice, commercial = m.commercial, displayable = m.displayable, enabled = m.enabled, removed = m.removed,
        vclass = m.vclass, seats = m.seats, validatedBy = m.validatedBy, shops = shops }
end
local function CatView(c)
    local models, shops = 0, {}
    for _, m in pairs(P.models) do if m.categoryId == c.id and not m.removed then models = models + 1 end end
    for sid, list in pairs(P.shopCats) do
        if list[c.id] and list[c.id].enabled and P.shops[sid] and not P.shops[sid].deleted then shops[#shops + 1] = P.shops[sid].name end
    end
    return { id = c.id, name = c.name, description = c.description, icon = c.icon, image = c.image, sort = c.sort, enabled = c.enabled, models = models, shops = shops }
end
local function ShopView(D)
    local emp, slots, shown = 0, 0, 0
    for _ in pairs(P.ShopEmployees(D.id)) do emp = emp + 1 end
    for _ in pairs(P.slots and P.slots[D.id] or {}) do slots = slots + 1 end
    for _ in pairs(P.display and P.display[D.id] or {}) do shown = shown + 1 end
    local offered, sellable = 0, 0
    for _, o in ipairs(P.ShopOffers(D, 'all')) do offered = offered + 1 if o.sellable then sellable = sellable + 1 end end
    return { id = D.id, name = D.name, address = D.address, job = D.job, jobLabel = D.jobLabel, society = D.society, matPrefix = D.matPrefix,
        enabled = D.enabled, deleted = D.deleted, options = D.options, points = D.points, employees = emp, slots = slots, shown = shown,
        offered = offered, sellable = sellable, balance = P.Balance(D) }
end

P.Admin.data = { fn = function()
    local cats, models, shops = {}, {}, {}
    for _, c in pairs(P.cats) do cats[#cats + 1] = CatView(c) end
    table.sort(cats, function(a, c) if a.sort ~= c.sort then return a.sort < c.sort end return a.name < c.name end)
    for _, m in pairs(P.models) do models[#models + 1] = ModelView(m) end
    table.sort(models, function(a, c) return a.label < c.label end)
    for _, D in pairs(P.shops) do shops[#shops + 1] = ShopView(D) end
    table.sort(shops, function(a, c) return a.id < c.id end)
    return { categories = cats, models = models, shops = shops, imageUrl = Config.ImageUrl, maxPrice = Config.Sale.maxPrice }
end }

P.Admin.log = { fn = function(_, d)
    local where, args = {}, {}
    if tonumber(d.shop) then where[#where + 1] = '`shop_id` = ?' args[#args + 1] = tonumber(d.shop) end
    if tonumber(d.model) then where[#where + 1] = '`model_id` = ?' args[#args + 1] = tonumber(d.model) end
    if tonumber(d.cat) then where[#where + 1] = '`category_id` = ?' args[#args + 1] = tonumber(d.cat) end
    return { list = MySQL.query.await([[SELECT `shop_id`, `model_id`, `category_id`, `action`, `details`, `actor_name`, UNIX_TIMESTAMP(`created_at`) AS t FROM `cd_catalog_log`]]
        .. (#where > 0 and (' WHERE ' .. table.concat(where, ' AND ')) or '') .. ' ORDER BY `id` DESC LIMIT 150', args) or {} }
end }

-- ---------------------------------------------------------------------
-- Catégories globales
-- ---------------------------------------------------------------------
P.Admin.catSave = { fn = function(src, d)
    local id = tonumber(d.id)
    local c = id and P.cats[id]
    if id and not c then return { error = 'Catégorie introuvable.' } end
    local name = P.Clean(d.name, 50)
    if #name < 2 then return { error = 'Nom trop court.' } end
    for _, o in pairs(P.cats) do if o.id ~= id and o.name:lower() == name:lower() then return { error = 'Une catégorie porte déjà ce nom.' } end end
    local desc, icon, image = P.Clean(d.description, 255), P.Clean(d.icon, 16), P.Clean(d.image, 255)
    local sort = P.Int(d.sort, -999, 9999, c and c.sort or 0)
    local enabled = d.enabled ~= false
    if c then
        MySQL.update.await('UPDATE `cd_categories` SET `name` = ?, `description` = ?, `icon` = ?, `image` = ?, `sort` = ?, `enabled` = ? WHERE `id` = ?',
            { name, desc ~= '' and desc or nil, icon ~= '' and icon or nil, image ~= '' and image or nil, sort, enabled and 1 or 0, id })
        local changes = {}
        if c.name ~= name then changes[#changes + 1] = ('nom : %s → %s'):format(c.name, name) end
        if c.enabled ~= enabled then changes[#changes + 1] = enabled and 'activée' or 'désactivée' end
        c.name, c.description, c.icon, c.image, c.sort, c.enabled = name, desc, icon, image, sort, enabled
        CatalogLog(src, 'Catégorie modifiée', ('%s%s'):format(name, #changes > 0 and (' · ' .. table.concat(changes, ', ')) or ''), { cat = id })
    else
        id = MySQL.insert.await('INSERT INTO `cd_categories` (`name`, `description`, `icon`, `image`, `sort`, `enabled`) VALUES (?, ?, ?, ?, ?, ?)',
            { name, desc ~= '' and desc or nil, icon ~= '' and icon or nil, image ~= '' and image or nil, sort, enabled and 1 or 0 })
        if not id then return { error = 'Création impossible.' } end
        P.cats[id] = { id = id, name = name, description = desc, icon = icon, image = image, sort = sort, enabled = enabled }
        CatalogLog(src, 'Catégorie créée', name, { cat = id })
    end
    P.Touch()
    return { ok = true, id = id, message = 'Catégorie enregistrée.' }
end }

-- Associer / retirer des modèles d'une catégorie
P.Admin.catAssign = { fn = function(src, d)
    local c = P.cats[tonumber(d.id) or 0]
    if not c then return { error = 'Catégorie introuvable.' } end
    local n = 0
    for _, mid in ipairs(type(d.models) == 'table' and d.models or {}) do
        local m = P.models[tonumber(mid) or 0]
        if m then
            local target = d.remove == true and (m.categoryId == c.id and nil or m.categoryId) or c.id
            if target ~= m.categoryId then
                MySQL.update.await('UPDATE `cd_models` SET `category_id` = ? WHERE `id` = ?', { target, m.id })
                m.categoryId = target
                n = n + 1
            end
        end
    end
    CatalogLog(src, d.remove and 'Modèles retirés de la catégorie' or 'Modèles associés à la catégorie', ('%s · %d modèle(s)'):format(c.name, n), { cat = c.id })
    P.Touch()
    return { ok = true, message = ('%d modèle(s) %s.'):format(n, d.remove and 'retiré(s) (sans catégorie : plus proposés)' or 'associé(s)') }
end }

-- ---------------------------------------------------------------------
-- Modèles globaux. Le modèle est VÉRIFIÉ dans le jeu du staff (existe et est un véhicule) :
-- le serveur FiveM ne peut pas le savoir seul. Le nom saisi seul n'est jamais accepté.
-- ---------------------------------------------------------------------
P.Admin.modelSave = { fn = function(src, d)
    local id = tonumber(d.id)
    local m = id and P.models[id]
    if id and not m then return { error = 'Modèle introuvable.' } end
    local model = m and m.model or tostring(d.model or ''):lower():gsub('[^%w_%-]', ''):sub(1, 50)
    if not m then
        if model == '' then return { error = 'Nom de spawn invalide.' } end
        if P.modelByName[model] then return { error = ('« %s » est déjà dans le catalogue global.'):format(model) } end
        if type(d.check) ~= 'table' or d.check.ok ~= true or tostring(d.check.model or ''):lower() ~= model then
            return { error = 'Modèle non vérifié : utilisez « Vérifier dans le jeu » (le modèle doit exister et être un véhicule).' }
        end
    end
    local label = P.Clean(d.label, 80)
    if #label < 2 then return { error = 'Nom commercial trop court.' } end
    local cat = d.categoryId ~= nil and d.categoryId ~= '' and tonumber(d.categoryId) or nil
    if cat and not P.cats[cat] then return { error = 'Catégorie introuvable.' } end
    local ref = d.refPrice ~= nil and d.refPrice ~= '' and P.Int(d.refPrice, 0, Config.Sale.maxPrice, nil) or nil
    local brand, desc, image = P.Clean(d.brand, 50), P.Clean(d.description, 500), P.Clean(d.image, 255)
    local commercial, displayable, enabled = d.commercial ~= false, d.displayable ~= false, d.enabled ~= false
    if m then
        local changes = {}
        if m.label ~= label then changes[#changes + 1] = ('nom : %s → %s'):format(m.label, label) end
        if m.categoryId ~= cat then changes[#changes + 1] = ('catégorie : %s → %s'):format(m.categoryId and P.cats[m.categoryId] and P.cats[m.categoryId].name or '—', cat and P.cats[cat].name or '—') end
        if m.refPrice ~= ref then changes[#changes + 1] = ('prix de référence : %s → %s'):format(tostring(m.refPrice or '—'), tostring(ref or '—')) end
        if m.enabled ~= enabled then changes[#changes + 1] = enabled and 'activé' or 'désactivé' end
        if m.commercial ~= commercial then changes[#changes + 1] = commercial and 'vente autorisée' or 'vente interdite' end
        if m.displayable ~= displayable then changes[#changes + 1] = displayable and 'exposition autorisée' or 'exposition interdite' end
        MySQL.update.await([[UPDATE `cd_models` SET `label` = ?, `brand` = ?, `category_id` = ?, `description` = ?, `image` = ?, `ref_price` = ?, `commercial` = ?,
            `displayable` = ?, `enabled` = ? WHERE `id` = ?]], { label, brand ~= '' and brand or nil, cat, desc ~= '' and desc or nil, image ~= '' and image or nil, ref,
            commercial and 1 or 0, displayable and 1 or 0, enabled and 1 or 0, m.id })
        m.label, m.brand, m.categoryId, m.description, m.image, m.refPrice = label, brand, cat, desc, image, ref
        m.commercial, m.displayable, m.enabled = commercial, displayable, enabled
        CatalogLog(src, 'Modèle modifié', ('%s (%s)%s'):format(label, m.model, #changes > 0 and (' · ' .. table.concat(changes, ', ')) or ''), { model = m.id })
        if not enabled or not displayable then P.ClearDisplayOf(m.id, enabled and 'exposition interdite' or 'modèle désactivé') end
    else
        local ck = d.check
        id = MySQL.insert.await([[INSERT INTO `cd_models` (`model`, `label`, `brand`, `category_id`, `description`, `image`, `ref_price`, `commercial`, `displayable`, `enabled`,
            `vclass`, `seats`, `validated_by`, `created_by`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], { model, label, brand ~= '' and brand or nil, cat,
            desc ~= '' and desc or nil, image ~= '' and image or nil, ref, commercial and 1 or 0, displayable and 1 or 0, enabled and 1 or 0,
            P.Int(ck.class, 0, 30, nil), P.Int(ck.seats, 0, 64, nil), P.Name(src), P.Name(src) })
        if not id then return { error = 'Ajout impossible.' } end
        P.models[id] = { id = id, model = model, label = label, brand = brand, categoryId = cat, description = desc, image = image, refPrice = ref,
            commercial = commercial, displayable = displayable, enabled = enabled, removed = false, vclass = P.Int(ck.class, 0, 30, nil), seats = P.Int(ck.seats, 0, 64, nil),
            validatedBy = P.Name(src) }
        P.modelByName[model] = id
        CatalogLog(src, 'Modèle ajouté', ('%s (%s) · vérifié en jeu'):format(label, model), { model = id })
    end
    P.Touch()
    return { ok = true, id = id, message = 'Modèle enregistré dans le catalogue global.' }
end }

-- Retirer du catalogue (ou remettre) : jamais de suppression des véhicules achetés ni des ventes
P.Admin.modelRemove = { fn = function(src, d)
    local m = P.models[tonumber(d.id) or 0]
    if not m then return { error = 'Modèle introuvable.' } end
    local removed = d.restore ~= true
    MySQL.update.await('UPDATE `cd_models` SET `removed` = ? WHERE `id` = ?', { removed and 1 or 0, m.id })
    m.removed = removed
    if removed then P.ClearDisplayOf(m.id, 'modèle retiré du catalogue') end
    CatalogLog(src, removed and 'Modèle retiré du catalogue' or 'Modèle remis au catalogue', ('%s (%s)'):format(m.label, m.model), { model = m.id })
    P.Touch()
    return { ok = true, message = removed and 'Modèle retiré : il n\'est plus proposé nulle part. Les véhicules déjà vendus, leurs clés et l\'historique restent intacts.'
        or 'Modèle remis au catalogue global.' }
end }

-- ---------------------------------------------------------------------
-- Concessions
-- ---------------------------------------------------------------------
local function ValidJob(job, exceptId)
    job = tostring(job or ''):lower():gsub('[^%w_]', ''):sub(1, 40)
    if #job < 3 then return nil, 'Nom de métier invalide (3 à 40 caractères : lettres, chiffres, _).' end
    for _, D in pairs(P.shops) do if D.id ~= exceptId and D.job == job then return nil, ('Le métier « %s » est déjà utilisé par « %s ».'):format(job, D.name) end end
    if job == 'unemployed' then return nil, 'Nom de métier réservé.' end
    -- Un métier existant d'un autre script ne doit pas être écrasé
    local existing = core:GetJob(job)
    if existing and not exceptId and not P.GetSetting('ownJobs', {})[job] then
        return nil, ('Le métier « %s » existe déjà dans elyzea_core (autre script) : choisissez un autre nom.'):format(job)
    end
    return job
end

P.Admin.shopSave = { fn = function(src, d)
    local id = tonumber(d.id)
    local D = id and P.shops[id]
    if id and not D then return { error = 'Concession introuvable.' } end
    local name = P.Clean(d.name, 80)
    if #name < 2 then return { error = 'Nom trop court.' } end
    local job, why = ValidJob(d.job ~= nil and d.job or (D and D.job), id)
    if not job then return { error = why } end
    if D and D.job ~= job then
        for _ in pairs(P.ShopEmployees(D.id)) do return { error = 'Des employés ont le métier actuel : retirez-les avant de changer le nom du métier.' } end
    end
    local society = tostring(d.society or ''):lower():gsub('[^%w_]', ''):sub(1, 40)
    if society == '' then society = job end
    local prefix = P.Clean(d.matPrefix, 8):upper()
    if prefix == '' then prefix = 'CD-' end
    local opts = D and D.options or {}
    opts.requireDuty = d.requireDuty ~= false
    opts.maxDiscount = P.Int(d.maxDiscount, 0, 50, opts.maxDiscount or 10)
    opts.blip = d.blip ~= false
    opts.blipSprite = P.Int(d.blipSprite, 1, 900, opts.blipSprite or 326)
    opts.blipColor = P.Int(d.blipColor, 0, 85, opts.blipColor or 3)
    local address, jobLabel = P.Clean(d.address, 120), P.Clean(d.jobLabel, 60)
    if jobLabel == '' then jobLabel = name end
    if D then
        D.name, D.address, D.job, D.jobLabel, D.society, D.matPrefix, D.options = name, address, job, jobLabel, society, prefix, opts
        P.SaveShop(D)
        CatalogLog(src, 'Concession modifiée', ('%s · métier %s · compte %s'):format(name, job, society), { shop = D.id })
    else
        id = MySQL.insert.await([[INSERT INTO `cd_shops` (`name`, `address`, `job`, `job_label`, `society`, `mat_prefix`, `enabled`, `points`, `options`, `created_by`)
            VALUES (?, ?, ?, ?, ?, ?, 0, '{}', ?, ?)]], { name, address, job, jobLabel, society, prefix, json.encode(opts), P.Name(src) })
        if not id then return { error = 'Création impossible.' } end
        D = { id = id, name = name, address = address, job = job, jobLabel = jobLabel, society = society, matPrefix = prefix, enabled = false, deleted = false, points = {}, options = opts }
        P.shops[id] = D
        local own = P.GetSetting('ownJobs', {})
        own[job] = true
        P.SetSetting('ownJobs', own)
        P.SeedGrades(id)
        CatalogLog(src, 'Concession créée', ('%s · métier %s · compte %s'):format(name, job, society), { shop = id })
    end
    -- Compte de société créé s'il n'existe pas (elyzea_core), métier déclaré
    pcall(function() core:GetSocietyMoney(society) end)
    P.SyncCoreJob(D)
    P.Touch()
    P.PushShop(D.id)
    return { ok = true, id = D.id, message = id == tonumber(d.id) and 'Concession enregistrée.' or 'Concession créée (fermée tant que vous ne l\'ouvrez pas). Configurez son catalogue et ses points.' }
end }

P.Admin.shopEnable = { fn = function(src, d)
    local D = P.shops[tonumber(d.id) or 0]
    if not D or D.deleted then return { error = 'Concession introuvable.' } end
    local on = d.enabled == true
    if on and not D.points.catalog then return { error = 'Placez d\'abord le point de consultation du catalogue.' } end
    if on and #(D.points.exits or {}) == 0 then return { error = 'Placez d\'abord au moins une place de sortie des véhicules achetés.' } end
    D.enabled = on
    P.SaveShop(D)
    CatalogLog(src, on and 'Concession ouverte' or 'Concession fermée', D.name, { shop = D.id })
    P.Touch()
    P.PushShop(D.id)
    if P.PublishDisplay then P.PublishDisplay() end
    return { ok = true, message = on and 'Concession ouverte.' or 'Concession fermée : catalogue, ventes et exposition suspendus (rien n\'est supprimé).' }
end }

-- Suppression = désactivation définitive. Véhicules vendus, clés, garages, ventes, transactions : intacts.
P.Admin.shopDelete = { fn = function(src, d)
    local D = P.shops[tonumber(d.id) or 0]
    if not D or D.deleted then return { error = 'Concession introuvable.' } end
    if d.confirm ~= D.name then return { error = 'Confirmation incorrecte : tapez exactement le nom de la concession.' } end
    local n = 0
    for cid in pairs(P.ShopEmployees(D.id)) do P.Remove(cid) n = n + 1 end
    D.enabled, D.deleted = false, true
    P.SaveShop(D)
    if P.ClearShopDisplay then P.ClearShopDisplay(D.id) end
    pcall(function() core:RemoveJob(D.job) end)
    local own = P.GetSetting('ownJobs', {})
    own[D.job] = nil
    P.SetSetting('ownJobs', own)
    CatalogLog(src, 'Concession supprimée', ('%s · %d employé(s) retiré(s) du métier'):format(D.name, n), { shop = D.id })
    P.Touch()
    return { ok = true, message = ('« %s » supprimée : %d employé(s) retiré(s). Les véhicules vendus, les clés, les ventes et les finances sont conservés.'):format(D.name, n) }
end }

-- Nommer un responsable : le joueur (ID serveur) reçoit le plus haut grade de la concession
P.Admin.setBoss = { fn = function(src, d)
    local D = P.shops[tonumber(d.id) or 0]
    if not D or D.deleted then return { error = 'Concession introuvable.' } end
    local t = tonumber(d.target)
    local cid = t and P.Cid(t)
    if not cid then return { error = 'Joueur introuvable (ID serveur).' } end
    local top = P.TopGrade(D.id)
    if not top then return { error = 'Aucun grade dans cette concession.' } end
    local cur = P.employees[cid]
    if cur and cur.shop_id ~= D.id then return { error = 'Ce joueur travaille dans une autre concession : il doit d\'abord la quitter.' } end
    if cur then P.ApplyGrade(cid, top) else
        local ok, why = P.Hire(D, cid, P.Name(t), top)
        if not ok then return { error = why } end
    end
    P.AddLog(D.id, src, cid, P.Name(t), 'Nommé par le staff', nil, top.name, nil)
    CatalogLog(src, 'Responsable nommé', ('%s · %s (%s)'):format(D.name, P.Name(t), top.name), { shop = D.id })
    P.Notify(t, ('Vous êtes %s de %s.'):format(top.name, D.name), 'success')
    return { ok = true, message = ('%s est maintenant %s de %s.'):format(P.Name(t), top.name, D.name) }
end }

-- ---------------------------------------------------------------------
-- Points : manage (gestion), catalog (consultation client), preview (aperçu du véhicule),
-- exits (places de sortie des véhicules achetés, plusieurs)
-- ---------------------------------------------------------------------
local KEYS = { manage = 'Point de gestion', catalog = 'Consultation du catalogue', preview = 'Aperçu du véhicule' }
P.Admin.point = { fn = function(src, d)
    local D = P.shops[tonumber(d.id) or 0]
    if not D or D.deleted then return { error = 'Concession introuvable.' } end
    local key = tostring(d.key or '')
    D.points = D.points or {}
    if key == 'exit' then
        D.points.exits = D.points.exits or {}
        if d.remove then
            local i = P.Int(d.index, 1, #D.points.exits, nil)
            if not i then return { error = 'Place introuvable.' } end
            table.remove(D.points.exits, i)
        else
            if #D.points.exits >= 12 then return { error = '12 places de sortie au maximum.' } end
            local p = StaffPos(src)
            for i, e in ipairs(D.points.exits) do if #(vector3(e.x, e.y, e.z) - vector3(p.x, p.y, p.z)) < 3.0 then return { error = ('Trop près de la place %d.'):format(i) } end end
            p.on = true
            D.points.exits[#D.points.exits + 1] = p
        end
    elseif KEYS[key] then
        if d.remove then D.points[key] = nil
        else
            local p = StaffPos(src)
            p.r = math.max(0.6, math.min(10.0, tonumber(d.r) or (D.points[key] and D.points[key].r) or Config.Points.defaultRadius))
            p.on = true
            D.points[key] = p
        end
    else return { error = 'Point inconnu.' } end
    P.SaveShop(D)
    CatalogLog(src, d.remove and 'Point retiré' or 'Point placé', ('%s · %s'):format(D.name, KEYS[key] or 'Sortie des véhicules'), { shop = D.id })
    P.Touch()
    return { ok = true, message = d.remove and 'Point retiré.' or 'Point placé à votre position (orientation comprise).' }
end }

-- Rayon, orientation, activation d'un point existant
P.Admin.pointSet = { fn = function(src, d)
    local D = P.shops[tonumber(d.id) or 0]
    if not D then return { error = 'Concession introuvable.' } end
    local key = tostring(d.key or '')
    local pt = key == 'exit' and (D.points.exits or {})[P.Int(d.index, 1, 99, 0)] or (KEYS[key] and D.points[key])
    if not pt then return { error = 'Point non placé.' } end
    if d.r ~= nil then pt.r = math.max(0.6, math.min(10.0, tonumber(d.r) or pt.r or 1.5)) end
    if d.h ~= nil then pt.h = (tonumber(d.h) or pt.h or 0) % 360 end
    if d.on ~= nil then pt.on = d.on == true end
    P.SaveShop(D)
    P.Touch()
    return { ok = true, message = 'Point mis à jour.' }
end }

-- ---------------------------------------------------------------------
-- Catalogue d'une concession
-- ---------------------------------------------------------------------
P.Admin.shopData = { fn = function(_, d)
    local D = P.shops[tonumber(d.id) or 0]
    if not D then return { error = 'Concession introuvable.' } end
    local cats, models = {}, {}
    for id, c in pairs(P.cats) do
        local sc = P.ShopCat(D, id)
        cats[#cats + 1] = { id = id, name = c.name, icon = c.icon, global = c.enabled, configured = sc ~= nil, enabled = sc and sc.enabled or false,
            visible = sc and sc.visible or false, sellable = sc and sc.sellable or false, sort = sc and sc.sort or c.sort }
    end
    table.sort(cats, function(a, c) return (a.sort or 0) < (c.sort or 0) end)
    for id, m in pairs(P.models) do
        if not m.removed then
            local sm = P.ShopModel(D, id)
            local o = P.Offer(D, m)
            models[#models + 1] = { id = id, model = m.model, label = m.label, categoryId = m.categoryId, global = m.enabled, commercial = m.commercial,
                globalDisplay = m.displayable, refPrice = m.refPrice, configured = sm ~= nil, enabled = sm and sm.enabled or false, visible = sm and sm.visible or false,
                sellable = sm and sm.sellable or false, displayable = sm and sm.displayable or false, price = sm and sm.price or nil,
                effective = o and { visible = o.visible, sellable = o.sellable, displayable = o.displayable, price = o.price, reason = o.sellReason } or nil }
        end
    end
    table.sort(models, function(a, c) return a.label < c.label end)
    local slots = {}
    for _, s in pairs(P.slots and P.slots[D.id] or {}) do
        local dd = P.display and P.display[D.id] and P.display[D.id][s.id]
        slots[#slots + 1] = { id = s.id, label = s.label, x = s.x, y = s.y, z = s.z, h = s.h, enabled = s.enabled, model = dd and dd.model or nil }
    end
    table.sort(slots, function(a, c) return a.id < c.id end)
    local grades = {}
    for _, g in ipairs(P.SortedGrades(D.id)) do grades[#grades + 1] = { id = g.id, name = g.name, level = g.level } end
    return { shop = ShopView(D), categories = cats, models = models, slots = slots, grades = grades }
end }

local function UpsertCat(D, catId, f)
    local cur = P.ShopCat(D, catId) or { enabled = false, visible = true, sellable = true, sort = P.cats[catId].sort }
    local v = { enabled = f.enabled == nil and cur.enabled or b(f.enabled), visible = f.visible == nil and cur.visible or b(f.visible),
        sellable = f.sellable == nil and cur.sellable or b(f.sellable), sort = P.Int(f.sort, -999, 9999, cur.sort or 0) }
    MySQL.query.await([[INSERT INTO `cd_shop_categories` (`shop_id`, `category_id`, `enabled`, `visible`, `sellable`, `sort`) VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE `enabled` = VALUES(`enabled`), `visible` = VALUES(`visible`), `sellable` = VALUES(`sellable`), `sort` = VALUES(`sort`)]],
        { D.id, catId, v.enabled and 1 or 0, v.visible and 1 or 0, v.sellable and 1 or 0, v.sort })
    P.shopCats[D.id] = P.shopCats[D.id] or {}
    P.shopCats[D.id][catId] = v
    return v
end

local function UpsertModel(src, D, m, f)
    local cur = P.ShopModel(D, m.id) or { enabled = false, visible = true, sellable = true, displayable = true }
    local price = cur.price
    if f.price ~= nil then
        if f.price == '' or f.price == false then price = nil
        else
            price = P.Int(f.price, 1, Config.Sale.maxPrice, nil)
            if not price then return nil, ('Prix invalide pour %s.'):format(m.label) end
        end
    end
    local v = { enabled = f.enabled == nil and cur.enabled or b(f.enabled), visible = f.visible == nil and cur.visible or b(f.visible),
        sellable = f.sellable == nil and cur.sellable or b(f.sellable), displayable = f.displayable == nil and cur.displayable or b(f.displayable), price = price }
    MySQL.query.await([[INSERT INTO `cd_shop_models` (`shop_id`, `model_id`, `enabled`, `visible`, `sellable`, `displayable`, `price`) VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE `enabled` = VALUES(`enabled`), `visible` = VALUES(`visible`), `sellable` = VALUES(`sellable`), `displayable` = VALUES(`displayable`), `price` = VALUES(`price`)]],
        { D.id, m.id, v.enabled and 1 or 0, v.visible and 1 or 0, v.sellable and 1 or 0, v.displayable and 1 or 0, v.price })
    if cur.price ~= v.price then
        MySQL.insert('INSERT INTO `cd_price_log` (`shop_id`, `model_id`, `model`, `old_price`, `new_price`, `actor_cid`, `actor_name`) VALUES (?, ?, ?, ?, ?, ?, ?)',
            { D.id, m.id, m.model, cur.price or m.refPrice, v.price or m.refPrice, nil, 'Staff · ' .. P.Name(src) })
    end
    P.shopModels[D.id] = P.shopModels[D.id] or {}
    P.shopModels[D.id][m.id] = v
    if not v.enabled or not v.displayable then P.ClearDisplayOf(m.id, 'retiré de l\'exposition par le staff', D.id) end
    return v
end

P.Admin.shopCats = { fn = function(src, d)
    local D = P.shops[tonumber(d.id) or 0]
    if not D or D.deleted then return { error = 'Concession introuvable.' } end
    local n = 0
    for _, f in ipairs(type(d.list) == 'table' and d.list or {}) do
        local cid = tonumber(f.id)
        if cid and P.cats[cid] then UpsertCat(D, cid, f) n = n + 1 end
    end
    CatalogLog(src, 'Catégories de la concession', ('%s · %d catégorie(s) réglée(s)'):format(D.name, n), { shop = D.id })
    P.Touch()
    return { ok = true, message = ('%d catégorie(s) enregistrée(s) pour %s.'):format(n, D.name) }
end }

P.Admin.shopModels = { fn = function(src, d)
    local D = P.shops[tonumber(d.id) or 0]
    if not D or D.deleted then return { error = 'Concession introuvable.' } end
    local n = 0
    for _, f in ipairs(type(d.list) == 'table' and d.list or {}) do
        local m = P.models[tonumber(f.id) or 0]
        if m then
            local ok, why = UpsertModel(src, D, m, f)
            if not ok then return { error = why } end
            n = n + 1
        end
    end
    CatalogLog(src, 'Modèles de la concession', ('%s · %d modèle(s) réglé(s)'):format(D.name, n), { shop = D.id })
    P.Touch()
    return { ok = true, message = ('%d modèle(s) enregistré(s) pour %s (les autres concessions ne changent pas).'):format(n, D.name) }
end }

-- Ajouter d'un coup tous les modèles d'une catégorie à une concession (activés, prix de référence)
P.Admin.shopAddCategory = { fn = function(src, d)
    local D = P.shops[tonumber(d.id) or 0]
    local c = P.cats[tonumber(d.cat) or 0]
    if not D or D.deleted or not c then return { error = 'Concession ou catégorie introuvable.' } end
    UpsertCat(D, c.id, { enabled = true })
    local n = 0
    for _, m in pairs(P.models) do
        if m.categoryId == c.id and not m.removed and not P.ShopModel(D, m.id) then UpsertModel(src, D, m, { enabled = true }) n = n + 1 end
    end
    CatalogLog(src, 'Catégorie ajoutée à la concession', ('%s · %s · %d modèle(s)'):format(D.name, c.name, n), { shop = D.id, cat = c.id })
    P.Touch()
    return { ok = true, message = ('%s : catégorie « %s » activée, %d modèle(s) ajouté(s) au prix de référence.'):format(D.name, c.name, n) }
end }

-- ---------------------------------------------------------------------
-- Emplacements d'exposition
-- ---------------------------------------------------------------------
P.Admin.slot = { fn = function(src, d)
    local D = P.shops[tonumber(d.id) or 0]
    if not D or D.deleted then return { error = 'Concession introuvable.' } end
    P.slots[D.id] = P.slots[D.id] or {}
    if d.remove then
        local s = P.slots[D.id][tonumber(d.slot) or 0]
        if not s then return { error = 'Emplacement introuvable.' } end
        P.ClearSlot(D.id, s.id)
        MySQL.update.await('DELETE FROM `cd_slots` WHERE `id` = ?', { s.id })
        P.slots[D.id][s.id] = nil
        CatalogLog(src, 'Emplacement supprimé', ('%s · %s'):format(D.name, s.label or ('#' .. s.id)), { shop = D.id })
    elseif tonumber(d.slot) then
        local s = P.slots[D.id][tonumber(d.slot)]
        if not s then return { error = 'Emplacement introuvable.' } end
        if d.move then local p = StaffPos(src) s.x, s.y, s.z, s.h = p.x, p.y, p.z, p.h end
        if d.h ~= nil then s.h = (tonumber(d.h) or s.h) % 360 end
        if d.enabled ~= nil then s.enabled = d.enabled == true end
        if d.label ~= nil then s.label = P.Clean(d.label, 40) end
        MySQL.update.await('UPDATE `cd_slots` SET `label` = ?, `x` = ?, `y` = ?, `z` = ?, `h` = ?, `enabled` = ? WHERE `id` = ?', { s.label, s.x, s.y, s.z, s.h, s.enabled and 1 or 0, s.id })
        if not s.enabled then P.ClearSlot(D.id, s.id) end
    else
        local p = StaffPos(src)
        for _, s in pairs(P.slots[D.id]) do
            if #(vector3(s.x, s.y, s.z) - vector3(p.x, p.y, p.z)) < 3.5 then return { error = ('Trop près de l\'emplacement « %s ».'):format(s.label or ('#' .. s.id)) } end
        end
        local label = P.Clean(d.label, 40)
        local id = MySQL.insert.await('INSERT INTO `cd_slots` (`shop_id`, `label`, `x`, `y`, `z`, `h`) VALUES (?, ?, ?, ?, ?, ?)', { D.id, label ~= '' and label or nil, p.x, p.y, p.z, p.h })
        if not id then return { error = 'Création impossible.' } end
        P.slots[D.id][id] = { id = id, shop_id = D.id, label = label ~= '' and label or nil, x = p.x, y = p.y, z = p.z, h = p.h, enabled = true }
        CatalogLog(src, 'Emplacement créé', ('%s · %s'):format(D.name, label ~= '' and label or ('#' .. id)), { shop = D.id })
    end
    P.PublishDisplay()
    P.Touch()
    return { ok = true, message = 'Emplacements d\'exposition mis à jour.' }
end }

-- Aller à un point (aperçu en jeu)
P.Admin.teleport = { fn = function(src, d)
    local D = P.shops[tonumber(d.id) or 0]
    if not D then return { error = 'Concession introuvable.' } end
    local pt
    if d.key == 'exit' then pt = (D.points.exits or {})[P.Int(d.index, 1, 99, 1)]
    elseif d.key == 'slot' then pt = P.slots[D.id] and P.slots[D.id][tonumber(d.slot) or 0]
    else pt = D.points[tostring(d.key or '')] end
    if not pt then return { error = 'Point non placé.' } end
    local ped = GetPlayerPed(src)
    SetEntityCoords(ped, pt.x + 0.0, pt.y + 0.0, pt.z + 0.0, false, false, false, false)
    return { ok = true, message = 'Téléporté.' }
end }
