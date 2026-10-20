-- =====================================================================
--  ELYZEA CLOTHING · TENUES ENREGISTRÉES (serveur)
--  Une tenue = la pièce de chaque rayon (vêtements + accessoires) avec son coloris
--  et, pour un pack, sa collection + son n° dans le pack (comme les objets vêtements).
--  Rangées par personnage (citizenid) dans elyzea_outfits, catégories personnelles
--  dans elyzea_outfit_categories ; les catégories par défaut viennent de Config.Outfits.
--  Porter une tenue = « porter » chaque pièce depuis l'inventaire (même règle que
--  elyzea_clothing:equip) : une pièce qu'on ne possède pas n'est pas mise, ce qu'on
--  portait revient en objet. Rien n'est créé, rien n'est perdu.
-- =====================================================================
local CFG = Config.Outfits or {}
if CFG.enabled == false then return end

local core = exports.elyzea_core
local INV = 'elyzea_inventory'
local ITEM_OF = {}
for cat, name in pairs(Config.Items.names or {}) do ITEM_OF[cat] = name end
local DEFAULT_CAT = {}
for _, c in ipairs(CFG.categories or {}) do DEFAULT_CAT[c.id] = c.label end
local NAME_MAX = math.max(4, math.min(64, tonumber(CFG.nameMax) or 32))

local function notify(src, msg, kind) TriggerClientEvent('elyzea_clothing:notify', src, msg, kind or 'error') end
local function inv() return exports[INV] end

-- ---------------------------------------------------------------------
-- Base de données (créée au démarrage, voir aussi sql/outfits.sql)
-- ---------------------------------------------------------------------
local dbReady = false
CreateThread(function()
    local ok, err = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `elyzea_outfit_categories` (
                `id` INT NOT NULL AUTO_INCREMENT,
                `citizenid` VARCHAR(50) NOT NULL,
                `name` VARCHAR(64) NOT NULL,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`id`),
                UNIQUE KEY `citizen_name` (`citizenid`, `name`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]])
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `elyzea_outfits` (
                `id` INT NOT NULL AUTO_INCREMENT,
                `citizenid` VARCHAR(50) NOT NULL,
                `name` VARCHAR(64) NOT NULL,
                `category` VARCHAR(40) NOT NULL DEFAULT '',
                `sex` VARCHAR(6) NOT NULL,
                `pieces` LONGTEXT NOT NULL,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (`id`),
                UNIQUE KEY `citizen_name` (`citizenid`, `name`),
                KEY `citizenid` (`citizenid`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]])
    end)
    if ok then dbReady = true
    else print(('^1[elyzea_clothing] Tables des tenues non créées : %s^0'):format(tostring(err))) end
end)

-- ---------------------------------------------------------------------
-- Outils
-- ---------------------------------------------------------------------
local function citizenOf(src)
    local ok, cid = pcall(function() return core:GetCitizenId(src) end)
    return ok and cid and tostring(cid) or nil
end

-- Nom propre : sans balises ni caractères de contrôle, coupé sans casser un caractère accentué
local function cleanName(n)
    n = tostring(n or ''):gsub('[%c<>]', ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if utf8.len(n) and utf8.len(n) > NAME_MAX then n = n:sub(1, utf8.offset(n, NAME_MAX + 1) - 1) end
    return n
end

-- Pièces reçues du client : seulement les rayons connus, nombres propres
local function cleanPieces(raw)
    if type(raw) ~= 'table' then return nil end
    local out, n = {}, 0
    for _, c in ipairs(Config.Categories) do
        local p = raw[c.id]
        if type(p) == 'table' then
            local clean = Items.cleanPiece(p)
            if clean.drawable >= -1 and clean.drawable <= 5000 and clean.texture <= 200 then
                out[c.id] = clean
                n = n + 1
            end
        end
    end
    return n > 0 and out or nil
end

local function decodePieces(raw)
    local ok, t = pcall(json.decode, raw or '')
    return ok and cleanPieces(t) or {}
end

-- Anti double-clic ; refusé = réponse quand même, pour réactiver les boutons du panneau
local busy = {}
local function refuse(src, msg)
    TriggerClientEvent('elyzea_clothing:outfits', src, nil, msg or 'Doucement : réessaie dans un instant.', 'error')
    return false
end
local function throttle(src)
    if not dbReady then return refuse(src, 'Base de données indisponible : réessaie plus tard.') end
    local now = GetGameTimer()
    if busy[src] and busy[src] > now then return refuse(src) end
    busy[src] = now + 400
    return true
end
AddEventHandler('playerDropped', function() busy[source] = nil end)

-- Catégorie valable pour ce personnage : '' (aucune), id par défaut ou 'c<n°>' personnelle
local function validCategory(cid, cat)
    cat = tostring(cat or '')
    if cat == '' or DEFAULT_CAT[cat] then return cat end
    local id = tonumber(cat:match('^c(%d+)$'))
    if not id then return nil end
    local row = MySQL.scalar.await('SELECT `id` FROM `elyzea_outfit_categories` WHERE `id` = ? AND `citizenid` = ?', { id, cid })
    return row and cat or nil
end

-- ---------------------------------------------------------------------
-- Inventaire : quelles pièces le joueur possède en objet
-- ---------------------------------------------------------------------
local function ownedIndex(src, sex)
    local idx = {}
    if not Items.enabled() then return idx end
    for cat, name in pairs(ITEM_OF) do
        local ok, slots = pcall(function() return inv():Search(src, 'slots', name) end)
        local list = {}
        if ok and type(slots) == 'table' then
            for _, it in ipairs(slots) do
                local md = it.metadata or {}
                if md.cat == cat and (not md.sex or md.sex == sex) then
                    list[#list + 1] = { slot = it.slot, name = it.name, metadata = md, piece = Items.cleanPiece(md) }
                end
            end
        end
        idx[cat] = list
    end
    return idx
end

local function findOwned(list, target)
    for i, it in ipairs(list or {}) do
        if Items.same(it.piece, target) then return it, i end
    end
end

-- Pièces de la tenue qui ne sont ni portées ni dans l'inventaire
local function missingOf(sex, pieces, worn, owned)
    local miss = {}
    if not Items.enabled() then return miss end
    for _, c in ipairs(Config.Categories) do
        local p = pieces[c.id]
        if p and not Items.isNaked(sex, c.id, p.drawable) then
            local w = worn and worn[c.id]
            if not (w and Items.same(w, p)) and not findOwned(owned[c.id], p) then miss[#miss + 1] = c.id end
        end
    end
    return miss
end

-- ---------------------------------------------------------------------
-- Liste envoyée au panneau
-- ---------------------------------------------------------------------
local function payload(src, worn)
    local cid = citizenOf(src)
    if not cid then return { error = 'Aucun personnage chargé.' } end
    if not dbReady then return { error = 'Base de données indisponible : les tenues ne peuvent pas être chargées.' } end
    local sex = Items.sexOf(src)
    local cats = {}
    for _, c in ipairs(CFG.categories or {}) do cats[#cats + 1] = { id = c.id, label = c.label, default = true } end
    local customs = MySQL.query.await('SELECT `id`, `name` FROM `elyzea_outfit_categories` WHERE `citizenid` = ? ORDER BY `name`', { cid }) or {}
    for _, r in ipairs(customs) do cats[#cats + 1] = { id = 'c' .. r.id, label = r.name } end
    local known = {}
    for _, c in ipairs(cats) do known[c.id] = true end

    local rows = MySQL.query.await('SELECT `id`, `name`, `category`, `sex`, `pieces`, UNIX_TIMESTAMP(`updated_at`) AS `ts` FROM `elyzea_outfits` WHERE `citizenid` = ? ORDER BY `name`', { cid }) or {}
    local owned = sex and ownedIndex(src, sex) or {}
    worn = cleanPieces(worn) or {}
    local list = {}
    for _, r in ipairs(rows) do
        local pieces = decodePieces(r.pieces)
        local count = 0
        for cat, p in pairs(pieces) do if not Items.isNaked(r.sex, cat, p.drawable) then count = count + 1 end end
        list[#list + 1] = {
            id = r.id, name = r.name, category = known[r.category] and r.category or '', sex = r.sex, ts = tonumber(r.ts) or 0,
            pieces = pieces, count = count, wrongSex = sex ~= nil and r.sex ~= sex or nil,
            missing = (sex == r.sex) and missingOf(sex, pieces, worn, owned) or {},
        }
    end
    return { outfits = list, categories = cats, max = CFG.max or 40, maxCategories = CFG.maxCategories or 12,
        nameMax = NAME_MAX, itemsMode = Items.enabled() }
end

local function send(src, worn, msg, kind)
    TriggerClientEvent('elyzea_clothing:outfits', src, payload(src, worn), msg, kind)
end

-- Événement protégé : une erreur (base de données…) renvoie quand même une réponse au panneau
local function handle(name, fn)
    RegisterNetEvent(name, function(...)
        local src = source
        local ok, err = pcall(fn, src, ...)
        if not ok then
            print(('^1[elyzea_clothing] %s (joueur %d) : %s^0'):format(name, src, tostring(err)))
            TriggerClientEvent('elyzea_clothing:outfits', src, nil, 'Action impossible pour le moment, réessaie.', 'error')
        end
    end)
end

handle('elyzea_clothing:outfitsList', function(src, worn) send(src, worn) end)

-- ---------------------------------------------------------------------
-- Enregistrer / remplacer / renommer / classer / supprimer
-- ---------------------------------------------------------------------
local function ownOutfit(cid, id)
    id = tonumber(id)
    if not id then return nil end
    return MySQL.single.await('SELECT * FROM `elyzea_outfits` WHERE `id` = ? AND `citizenid` = ?', { id, cid })
end

local function nameTaken(cid, name, exceptId)
    local id = MySQL.scalar.await('SELECT `id` FROM `elyzea_outfits` WHERE `citizenid` = ? AND `name` = ?', { cid, name })
    return id ~= nil and id ~= exceptId
end

handle('elyzea_clothing:outfitSave', function(src, name, category, pieces)
    if not throttle(src) then return end
    local cid, sex = citizenOf(src), Items.sexOf(src)
    if not cid or not sex then return notify(src, 'Personnage non compatible.') end
    name, pieces = cleanName(name), cleanPieces(pieces)
    if name == '' then return send(src, pieces, 'Donne un nom à ta tenue.', 'error') end
    if not pieces then return send(src, nil, 'Tenue illisible : réessaie.', 'error') end
    category = validCategory(cid, category)
    if not category then return send(src, pieces, 'Catégorie inconnue.', 'error') end
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM `elyzea_outfits` WHERE `citizenid` = ?', { cid }) or 0
    if count >= (CFG.max or 40) then return send(src, pieces, ('Limite atteinte : %d tenues au maximum.'):format(CFG.max or 40), 'error') end
    if nameTaken(cid, name) then return send(src, pieces, ('Une tenue s\'appelle déjà « %s » : choisis un autre nom ou utilise « Remplacer ».'):format(name), 'error') end
    local ok = pcall(MySQL.insert.await, 'INSERT INTO `elyzea_outfits` (`citizenid`, `name`, `category`, `sex`, `pieces`) VALUES (?, ?, ?, ?, ?)',
        { cid, name, category, sex, json.encode(pieces) })
    send(src, pieces, ok and ('Tenue « %s » enregistrée.'):format(name) or 'Enregistrement impossible.', ok and 'success' or 'error')
end)

handle('elyzea_clothing:outfitReplace', function(src, id, pieces)
    if not throttle(src) then return end
    local cid, sex = citizenOf(src), Items.sexOf(src)
    if not cid or not sex then return end
    local row = ownOutfit(cid, id)
    pieces = cleanPieces(pieces)
    if not row then return send(src, pieces, 'Tenue introuvable.', 'error') end
    if not pieces then return send(src, nil, 'Tenue illisible : réessaie.', 'error') end
    MySQL.update.await('UPDATE `elyzea_outfits` SET `pieces` = ?, `sex` = ? WHERE `id` = ? AND `citizenid` = ?', { json.encode(pieces), sex, row.id, cid })
    send(src, pieces, ('« %s » remplacée par ta tenue actuelle.'):format(row.name), 'success')
end)

handle('elyzea_clothing:outfitEdit', function(src, id, name, category, worn)
    if not throttle(src) then return end
    local cid = citizenOf(src)
    if not cid then return end
    local row = ownOutfit(cid, id)
    if not row then return send(src, worn, 'Tenue introuvable.', 'error') end
    name = cleanName(name)
    if name == '' then return send(src, worn, 'Le nom ne peut pas être vide.', 'error') end
    if nameTaken(cid, name, row.id) then return send(src, worn, ('Une tenue s\'appelle déjà « %s ».'):format(name), 'error') end
    category = validCategory(cid, category)
    if not category then return send(src, worn, 'Catégorie inconnue.', 'error') end
    MySQL.update.await('UPDATE `elyzea_outfits` SET `name` = ?, `category` = ? WHERE `id` = ? AND `citizenid` = ?', { name, category, row.id, cid })
    send(src, worn, 'Tenue modifiée.', 'success')
end)

handle('elyzea_clothing:outfitDelete', function(src, id, worn)
    if not throttle(src) then return end
    local cid = citizenOf(src)
    if not cid then return end
    local row = ownOutfit(cid, id)
    if not row then return send(src, worn, 'Tenue introuvable.', 'error') end
    MySQL.update.await('DELETE FROM `elyzea_outfits` WHERE `id` = ? AND `citizenid` = ?', { row.id, cid })
    send(src, worn, ('Tenue « %s » supprimée (les vêtements restent dans ton inventaire).'):format(row.name), 'success')
end)

-- ---------------------------------------------------------------------
-- Catégories personnelles
-- ---------------------------------------------------------------------
local function defaultLabelTaken(name)
    local low = name:lower()
    for _, label in pairs(DEFAULT_CAT) do if label:lower() == low then return true end end
    return false
end

handle('elyzea_clothing:outfitCategory', function(src, action, id, name, worn)
    if not throttle(src) then return end
    local cid = citizenOf(src)
    if not cid then return end
    if action == 'create' or action == 'rename' then
        name = cleanName(name)
        if name == '' then return send(src, worn, 'Donne un nom à la catégorie.', 'error') end
        if defaultLabelTaken(name) then return send(src, worn, 'Cette catégorie existe déjà.', 'error') end
        local same = MySQL.scalar.await('SELECT `id` FROM `elyzea_outfit_categories` WHERE `citizenid` = ? AND `name` = ?', { cid, name })
        if action == 'create' then
            if same then return send(src, worn, 'Cette catégorie existe déjà.', 'error') end
            local n = MySQL.scalar.await('SELECT COUNT(*) FROM `elyzea_outfit_categories` WHERE `citizenid` = ?', { cid }) or 0
            if n >= (CFG.maxCategories or 12) then return send(src, worn, ('Limite atteinte : %d catégories personnelles.'):format(CFG.maxCategories or 12), 'error') end
            MySQL.insert.await('INSERT INTO `elyzea_outfit_categories` (`citizenid`, `name`) VALUES (?, ?)', { cid, name })
            return send(src, worn, ('Catégorie « %s » créée.'):format(name), 'success')
        end
        local num = tonumber(tostring(id or ''):match('^c(%d+)$'))
        if not num then return send(src, worn, 'Les catégories par défaut ne se renomment pas.', 'error') end
        if same and same ~= num then return send(src, worn, 'Cette catégorie existe déjà.', 'error') end
        local n = MySQL.update.await('UPDATE `elyzea_outfit_categories` SET `name` = ? WHERE `id` = ? AND `citizenid` = ?', { name, num, cid })
        return send(src, worn, (n or 0) > 0 and 'Catégorie renommée.' or 'Catégorie introuvable.', (n or 0) > 0 and 'success' or 'error')
    elseif action == 'delete' then
        local num = tonumber(tostring(id or ''):match('^c(%d+)$'))
        if not num then return send(src, worn, 'Les catégories par défaut ne se suppriment pas.', 'error') end
        local n = MySQL.update.await('DELETE FROM `elyzea_outfit_categories` WHERE `id` = ? AND `citizenid` = ?', { num, cid })
        if (n or 0) == 0 then return send(src, worn, 'Catégorie introuvable.', 'error') end
        -- Les tenues de cette catégorie restent, sans catégorie
        MySQL.update.await('UPDATE `elyzea_outfits` SET `category` = \'\' WHERE `citizenid` = ? AND `category` = ?', { cid, 'c' .. num })
        return send(src, worn, 'Catégorie supprimée (ses tenues sont gardées, sans catégorie).', 'success')
    end
end)

-- ---------------------------------------------------------------------
-- Porter une tenue
--   worn        : ce que le personnage porte (lu par le client, comme pour elyzea_clothing:equip)
--   unavailable : rayons dont la pièce vient d'un pack absent chez le joueur (non appliqués)
-- ---------------------------------------------------------------------
local REASON = {
    pack = 'pack absent du serveur',
    missing = 'pas dans ton inventaire',
    full = 'inventaire plein',
    bag = 'sac trop chargé pour être retiré',
}

handle('elyzea_clothing:outfitWear', function(src, id, worn, unavailable)
    if not throttle(src) then return end
    if not Items.lock(src) then return refuse(src) end
    if Items.inUniform(src) then return notify(src, Items.UNIFORM_MSG) end
    local cid, sex = citizenOf(src), Items.sexOf(src)
    if not cid or not sex then return notify(src, 'Personnage non compatible.') end
    local row = ownOutfit(cid, id)
    if not row then return send(src, worn, 'Tenue introuvable.', 'error') end
    if row.sex ~= sex then return send(src, worn, ('Cette tenue est pour un personnage %s.'):format(row.sex == 'male' and 'homme' or 'femme'), 'error') end
    local pieces = decodePieces(row.pieces)
    worn = cleanPieces(worn) or {}
    unavailable = type(unavailable) == 'table' and unavailable or {}

    local apply, skipped = {}, {}
    local itemsMode = Items.enabled()
    local owned = itemsMode and ownedIndex(src, sex) or {}
    local names = {}   -- [rayon] = { piece, label } ou false (nom à effacer), appliqué à la fin

    for _, c in ipairs(Config.Categories) do
        local cat, target = c.id, pieces[c.id]
        local cur = worn[cat] or { drawable = -1, texture = 0 }
        if not target then
            -- rayon absent de la tenue (ancienne tenue) : on ne touche à rien
        elseif unavailable[cat] then
            skipped[#skipped + 1] = { cat = cat, reason = REASON.pack }
        elseif Items.same(cur, target) then
            -- déjà porté
        elseif not itemsMode then
            apply[cat] = target
        else
            local targetNaked, curNaked = Items.isNaked(sex, cat, target.drawable), Items.isNaked(sex, cat, cur.drawable)
            if targetNaked then
                -- Retirer la pièce portée : elle revient en objet
                local ok, reason = true, nil
                if not curNaked then
                    if cat == 'bags' then
                        local bagOk = Items.setBag(src, false)
                        if not bagOk then ok, reason = false, REASON.bag end
                    end
                    if ok and not Items.give(src, sex, cat, cur) then
                        if cat == 'bags' then Items.setBag(src, true) end
                        ok, reason = false, REASON.full
                    end
                end
                if ok then
                    apply[cat] = target
                    names[cat] = false
                else
                    skipped[#skipped + 1] = { cat = cat, reason = reason }
                end
            else
                local it, pos = findOwned(owned[cat], target)
                if not it then
                    skipped[#skipped + 1] = { cat = cat, reason = REASON.missing }
                elseif inv():RemoveItem(src, it.name, 1, nil, it.slot) then
                    table.remove(owned[cat], pos)
                    local ok = true
                    if not curNaked and not Items.give(src, sex, cat, cur) then
                        inv():AddItem(src, it.name, 1, it.metadata, it.slot)   -- on rend l'objet à sa place : rien ne change
                        ok = false
                    end
                    if ok then
                        if cat == 'bags' then Items.setBag(src, true) end
                        apply[cat] = target
                        names[cat] = it.metadata.custom and { piece = target, label = it.metadata.label } or false
                    else
                        skipped[#skipped + 1] = { cat = cat, reason = REASON.full }
                    end
                else
                    skipped[#skipped + 1] = { cat = cat, reason = REASON.missing }
                end
            end
        end
    end
    -- Noms donnés aux pièces portées : relus maintenant (Items.give les met aussi à jour)
    if next(names) then
        local current = Items.wornNames(src)
        for cat, v in pairs(names) do current[cat] = v or nil end
        Items.saveWornNames(src, current)
    end
    for _, s in ipairs(skipped) do s.label = Cat[s.cat] and Cat[s.cat].single or s.cat end
    TriggerClientEvent('elyzea_clothing:outfitApply', src, row.name, apply, skipped)
end)
