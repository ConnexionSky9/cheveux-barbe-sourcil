-- =====================================================================
--  elyzea_shop — administration depuis l'admin menu (onglet « Boutique »)
--  · Exports AdminData / AdminAction : appelables UNIQUEMENT par la ressource Config.AdminMenuResource
--    (vérifié avec GetInvokingResource). L'admin menu vérifie le grade (Fondateur pour toute modification).
--  · Le catalogue modifié est enregistré dans elyzea_shop_catalog et remplace les valeurs de config.lua.
--  · Chaque valeur est revalidée ici (types, bornes, formats) : rien n'est enregistré tel quel.
-- =====================================================================
Catalog = {}
local DEFAULT_PRODUCTS, DEFAULT_CATEGORIES = {}, {}
local REWARD_TYPES = { group = true, perk = true, coins = true, vehicle = true, item = true, money = true, command = true }
local ICONS = { crown = true, coin = true, car = true, star = true, gift = true }

local function deepcopy(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = deepcopy(v) end
    return o
end

-- ------------------------------------------------------------------ Chargement
function Catalog.load()
    if next(DEFAULT_PRODUCTS) == nil then
        DEFAULT_PRODUCTS = deepcopy(Config.Products)
        DEFAULT_CATEGORIES = deepcopy(Config.Categories)
    end
    local rows = Db.query('SELECT `key`, `data` FROM `elyzea_shop_catalog`')
    local n = 0
    for _, r in ipairs(rows) do
        local ok, d = pcall(json.decode, r.data)
        if ok and type(d) == 'table' then
            if r.key == '__categories' then
                if #d > 0 then Config.Categories = d end
            elseif d.deleted then
                Config.Products[r.key] = nil
            else
                Config.Products[r.key] = d
            end
            n = n + 1
        end
    end
    if n > 0 then print(('[elyzea_shop] catalogue : %d modification(s) de l\'admin menu appliquée(s)'):format(n)) end
end

-- ------------------------------------------------------------------ Validation
local function str(v, max, pattern)
    if type(v) ~= 'string' then v = v == nil and '' or tostring(v) end
    v = v:gsub('[%c]', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if #v > max then v = v:sub(1, max) end
    if pattern and v ~= '' and not v:match(pattern) then return nil end
    return v
end
local function int(v, min, max)
    if v == nil or v == '' or v == json.null then return nil end
    local n = tonumber(v)
    if not n or n ~= math.floor(n) or n < min or n > max then return false end
    return n
end
local IDENT = '^[%w_]+$'

local function cleanReward(r)
    if type(r) ~= 'table' or not REWARD_TYPES[r.type] then return nil, 'Type de récompense inconnu.' end
    local t = r.type
    if t == 'group' or t == 'perk' then
        local name = str(r.name, 32, IDENT)
        if not name or name == '' then return nil, 'Nom de grade / avantage : lettres, chiffres et _ (32 max).' end
        return { type = t, name = name }
    elseif t == 'coins' then
        local a = int(r.amount, 1, 10000000)
        if not a then return nil, 'Montant de coins invalide (1 à 10 000 000).' end
        return { type = t, amount = a }
    elseif t == 'vehicle' then
        local model = str(r.model, 32, IDENT)
        if not model or model == '' then return nil, 'Modèle de véhicule invalide.' end
        local garage = str(r.garage, 32, IDENT)
        return { type = t, model = model:lower(), garage = (garage and garage ~= '') and garage or nil }
    elseif t == 'item' then
        local name, count = str(r.name, 48, IDENT), int(r.count, 1, 1000)
        if not name or name == '' or not count then return nil, 'Objet : nom (lettres, chiffres, _) et quantité 1 à 1000.' end
        return { type = t, name = name, count = count }
    elseif t == 'money' then
        local account, amount = str(r.account, 16, '^[%a_]+$'), int(r.amount, 1, 100000000)
        if not account or account == '' or not amount then return nil, 'Argent : compte (bank, cash…) et montant.' end
        return { type = t, account = account, amount = amount }
    elseif t == 'command' then
        local name = str(r.name, 32, IDENT)
        if not name or not Config.Commands[name] then return nil, ('Commande « %s » absente de Config.Commands (config.lua).'):format(tostring(r.name)) end
        return { type = t, name = name }
    end
end

local function cleanProduct(d)
    local p = {}
    p.label = str(d.label, 60)
    if not p.label or #p.label < 2 then return nil, 'Nom du produit : 2 à 60 caractères.' end
    p.category = str(d.category, 32, IDENT)
    local catOk = false
    for _, c in ipairs(Config.Categories) do if c.id == p.category then catOk = true end end
    if not catOk then return nil, 'Catégorie inconnue.' end
    p.description = str(d.description, 600) or ''
    p.image = str(d.image, 400)
    local imgId = tonumber(p.image:match('^img:(%d+)$'))
    if imgId and not Images.get(imgId) then return nil, 'Image collée introuvable : recolle-la (Ctrl+V).' end
    if p.image ~= '' and not (imgId or p.image:match('^assets/[%w_%-/]+%.%a+$') or p.image:match('^https://[%w%-%.]+/[^%s"\'<>]*$')) then
        return nil, 'Image : colle une capture (Ctrl+V), un chemin assets/… de la ressource ou une adresse https://'
    end
    if p.image == '' then p.image = nil end
    p.perks = {}
    for _, line in ipairs(type(d.perks) == 'table' and d.perks or {}) do
        local s = str(line, 120)
        if s and s ~= '' and #p.perks < 12 then p.perks[#p.perks + 1] = s end
    end
    p.displayPrice = str(d.displayPrice, 24)
    if p.displayPrice == '' then p.displayPrice = nil end
    p.tebexPackageId = int(d.tebexPackageId, 1, 99999999999)
    if p.tebexPackageId == false then return nil, 'ID du paquet Tebex : nombre entier.' end
    p.coinsPrice = int(d.coinsPrice, 1, 10000000)
    if p.coinsPrice == false then return nil, 'Prix en coins : entier de 1 à 10 000 000 (vide = non achetable en coins).' end
    p.durationDays = int(d.durationDays, 1, 3650)
    if p.durationDays == false then return nil, 'Durée : 1 à 3650 jours (vide = permanent).' end
    p.sort = int(d.sort, -9999, 9999) or 0
    p.enabled = d.enabled ~= false
    p.rewards = {}
    if type(d.rewards) ~= 'table' or #d.rewards == 0 then return nil, 'Ajoutez au moins une récompense (ce que le produit donne en jeu).' end
    if #d.rewards > 15 then return nil, '15 récompenses maximum.' end
    for _, r in ipairs(d.rewards) do
        local c, err = cleanReward(r)
        if not c then return nil, err end
        p.rewards[#p.rewards + 1] = c
    end
    return p
end

local function cleanCategory(d)
    local c = {}
    c.id = str(d.id, 32, '^[%l%d_]+$')
    if not c.id or #c.id < 2 then return nil, 'Identifiant de catégorie : minuscules, chiffres et _ (2 à 32).' end
    c.label = str(d.label, 40)
    if not c.label or #c.label < 2 then return nil, 'Nom de catégorie : 2 à 40 caractères.' end
    c.description = str(d.description, 200) or ''
    c.icon = ICONS[d.icon] and d.icon or 'star'
    c.enabled = d.enabled ~= false
    return c
end

local function save(key, data, actor)
    Db.query('INSERT INTO `elyzea_shop_catalog` (`key`, `data`, `updated_by`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `data` = VALUES(`data`), `updated_by` = VALUES(`updated_by`)',
        { key, json.encode(data), tostring(actor or 'admin'):sub(1, 96) })
end

local function refreshPlayers()
    for _, s in ipairs(GetPlayers()) do TriggerClientEvent('elyzea_shop:refresh', tonumber(s)) end
end

-- ------------------------------------------------------------------ Données pour l'onglet
local function adminProducts()
    local out = {}
    for key, p in pairs(Config.Products) do
        local c = deepcopy(p)
        c.key = key
        c.enabled = p.enabled ~= false
        c.fromConfig = DEFAULT_PRODUCTS[key] ~= nil
        out[#out + 1] = c
    end
    table.sort(out, function(a, b)
        if a.category ~= b.category then return tostring(a.category) < tostring(b.category) end
        if (a.sort or 0) ~= (b.sort or 0) then return (a.sort or 0) < (b.sort or 0) end
        return tostring(a.label) < tostring(b.label)
    end)
    return out
end

local function caller()
    local inv = GetInvokingResource()
    return inv == Config.AdminMenuResource
end

exports('AdminData', function()
    if not caller() then return nil end
    local stats = Db.single([[SELECT SUM(`status` = 'pending') AS pending, SUM(`status` = 'failed') AS failed,
        SUM(`status` = 'delivered' AND `action` = 'grant' AND `source` = 'tebex') AS tebex, SUM(`status` = 'delivered' AND `source` = 'coins') AS coins
        FROM `elyzea_shop_deliveries`]]) or {}
    local deliveries = Db.query([[SELECT `id`, `transaction_id`, `product_key`, `action`, `account`, `source`, `status`, `attempts`, `last_error`, `created_at`, `delivered_at`
        FROM `elyzea_shop_deliveries` ORDER BY (`status` = 'failed') DESC, `id` DESC LIMIT 80]])
    for _, d in ipairs(deliveries) do local p = Config.Products[d.product_key] d.label = p and p.label or d.product_key end
    local logs = Db.query("SELECT `level`, `action`, `account`, `ref`, `details`, `created_at` FROM `elyzea_shop_logs` WHERE `level` <> 'info' OR `action` LIKE 'admin%' ORDER BY `id` DESC LIMIT 60")
    return {
        available = true,
        products = adminProducts(),
        categories = deepcopy(Config.Categories),
        rewardTypes = { 'group', 'perk', 'coins', 'vehicle', 'item', 'money', 'command' },
        commands = (function() local o = {} for k in pairs(Config.Commands) do o[#o + 1] = k end table.sort(o) return o end)(),
        coins = { enabled = Config.Coins.enabled, label = Config.Coins.label, short = Config.Coins.short,
            total = tonumber(Db.scalar('SELECT COALESCE(SUM(`balance`), 0) FROM `elyzea_shop_coins`')) or 0 },
        integrations = Config.Integrations,
        tebex = (function()
            local st = TebexAPI.state
            return { storeUrl = Config.Tebex.storeUrl, secretSet = GetConvar('sv_tebexSecret', '') ~= '',
                connected = st.connected, syncing = st.syncing, error = st.error, account = st.account,
                lastSync = st.lastSync > 0 and (os.time() - st.lastSync) or nil, packages = st.list,
                directCheckout = Config.Tebex.directCheckout ~= false }
        end)(),
        stats = { pending = tonumber(stats.pending) or 0, failed = tonumber(stats.failed) or 0, tebex = tonumber(stats.tebex) or 0, coins = tonumber(stats.coins) or 0 },
        deliveries = deliveries,
        logs = logs,
    }
end)

-- ------------------------------------------------------------------ Actions
-- Renvoie : ok (bool), message, données éventuelles
local A = {}

A.product_save = function(d, actor)
    local key = str(d.key, 40, '^[%l%d_]+$')
    if not key or #key < 2 then return false, 'Clé du produit : minuscules, chiffres et _ (2 à 40). Elle sert dans la commande Tebex.' end
    if d.isNew and Config.Products[key] then return false, 'Cette clé existe déjà.' end
    if not d.isNew and not Config.Products[key] then return false, 'Produit introuvable.' end
    local p, err = cleanProduct(type(d.product) == 'table' and d.product or {})
    if not p then return false, err end
    if p.tebexPackageId then
        for k, o in pairs(Config.Products) do
            if k ~= key and tonumber(o.tebexPackageId) == p.tebexPackageId then return false, ('Paquet Tebex déjà utilisé par « %s ».'):format(o.label or k) end
        end
    end
    Config.Products[key] = p
    save(key, p, actor)
    Db.log('info', 'admin_product_save', nil, key, ('%s par %s'):format(p.label, actor))
    refreshPlayers()
    return true, ('« %s » enregistré.'):format(p.label)
end

A.product_toggle = function(d, actor)
    local key = tostring(d.key or '')
    local p = Config.Products[key]
    if not p then return false, 'Produit introuvable.' end
    p.enabled = p.enabled == false
    save(key, p, actor)
    Db.log('info', 'admin_product_toggle', nil, key, ('%s par %s'):format(p.enabled and 'activé' or 'masqué', actor))
    refreshPlayers()
    return true, p.enabled and 'Produit visible dans la boutique.' or 'Produit masqué (les achats Tebex déjà payés restent livrés).'
end

A.product_delete = function(d, actor)
    local key = tostring(d.key or '')
    local p = Config.Products[key]
    if not p then return false, 'Produit introuvable.' end
    local used = tonumber(Db.scalar('SELECT COUNT(*) FROM `elyzea_shop_deliveries` WHERE `product_key` = ?', { key })) or 0
    if used > 0 then return false, ('Produit déjà acheté (%d livraison(s)) : masquez-le plutôt (il doit rester connu pour les livraisons et retraits).'):format(used) end
    Config.Products[key] = nil
    save(key, { deleted = true }, actor)
    Db.log('info', 'admin_product_delete', nil, key, actor)
    refreshPlayers()
    return true, ('« %s » supprimé.'):format(p.label or key)
end

A.product_reset = function(d, actor)
    local key = tostring(d.key or '')
    if not DEFAULT_PRODUCTS[key] then return false, 'Ce produit n\'existe pas dans config.lua.' end
    Db.query('DELETE FROM `elyzea_shop_catalog` WHERE `key` = ?', { key })
    Config.Products[key] = deepcopy(DEFAULT_PRODUCTS[key])
    Db.log('info', 'admin_product_reset', nil, key, actor)
    refreshPlayers()
    return true, 'Produit remis aux valeurs de config.lua.'
end

A.categories_save = function(d, actor)
    if type(d.categories) ~= 'table' or #d.categories == 0 or #d.categories > 12 then return false, '1 à 12 catégories.' end
    local list, seen = {}, {}
    for _, c in ipairs(d.categories) do
        local cc, err = cleanCategory(type(c) == 'table' and c or {})
        if not cc then return false, err end
        if seen[cc.id] then return false, ('Catégorie « %s » en double.'):format(cc.id) end
        seen[cc.id] = true
        list[#list + 1] = cc
    end
    for key, p in pairs(Config.Products) do
        if not seen[p.category] then return false, ('La catégorie « %s » contient encore « %s » : déplacez-le d\'abord.'):format(tostring(p.category), p.label or key) end
    end
    Config.Categories = list
    save('__categories', list, actor)
    Db.log('info', 'admin_categories', nil, nil, actor)
    refreshPlayers()
    return true, 'Catégories enregistrées.'
end

local function account(v)
    v = tostring(v or '')
    local id = v:match('^fivem:(%d+)$') or v:match('^(%d+)$')
    if id and #id > 6 then return id end                -- identifiant Cfx.re
    local src = tonumber(v)
    if src and GetPlayerName(src) then return Shop.accountOf(src) end   -- id serveur d'un joueur connecté
    return nil
end

A.account_lookup = function(d)
    local acc = account(d.account)
    if not acc then return false, 'Joueur introuvable : id serveur d\'un joueur connecté ou fivem:XXXX.' end
    return true, nil, {
        account = acc, coins = Coins.balance(acc), coinHistory = Coins.history(acc, 30),
        deliveries = Db.query('SELECT `id`, `transaction_id`, `product_key`, `action`, `source`, `status`, `last_error`, `created_at` FROM `elyzea_shop_deliveries` WHERE `account` = ? ORDER BY `id` DESC LIMIT 40', { acc }),
        vip = Db.query('SELECT `name`, `expires_at`, `transaction_id` FROM `elyzea_shop_entitlements` WHERE `account` = ? AND `active` = 1 AND (`expires_at` IS NULL OR `expires_at` > UTC_TIMESTAMP())', { acc }),
    }
end

A.coins_adjust = function(d, actor)
    local acc = account(d.account)
    local amount = int(d.amount, -10000000, 10000000)
    if not acc or not amount or amount == 0 then return false, 'Joueur ou montant invalide.' end
    local reason = str(d.reason, 48) or ''
    local ref = ('admin-%s-%d-%d'):format(acc, os.time(), math.random(1e6))
    local ok, err
    if amount > 0 then ok, err = Coins.credit(acc, amount, 'Admin : ' .. (reason ~= '' and reason or 'ajustement'), ref, actor)
    else ok, err = Coins.debit(acc, -amount, 'Admin : ' .. (reason ~= '' and reason or 'ajustement'), ref, actor) end
    Db.log(ok and 'info' or 'warn', 'admin_coins', acc, ref, ('%s %+d par %s'):format(ok and 'ok' or tostring(err), amount, actor))
    if not ok then return false, err end
    return true, ('Nouveau solde : %d %s'):format(Coins.balance(acc), Config.Coins.short)
end

-- Don d'Elyzea Coins à soi-même ou à un autre joueur (id serveur d'un joueur connecté, ou fivem:ID même hors ligne)
A.coins_give = function(d, actor)
    if not Config.Coins.enabled then return false, 'Les Elyzea Coins sont désactivés (config.lua).' end
    local target = tostring(d.target or '')
    local acc = account(target)
    if not acc then
        local src = tonumber(target)
        if src and GetPlayerName(src) then return false, ('%s n\'est pas connecté à un compte Cfx.re dans FiveM : impossible de lui donner des coins.'):format(GetPlayerName(src)) end
        return false, 'Joueur introuvable : choisissez un joueur connecté ou saisissez fivem:XXXX.'
    end
    local amount = int(d.amount, 1, 1000000)
    if not amount then return false, 'Montant : nombre entier de 1 à 1 000 000.' end
    local reason = str(d.reason, 48) or ''
    local ref = ('admin-give-%s-%d-%d'):format(acc, os.time(), math.random(1e6))
    local ok, err = Coins.credit(acc, amount, 'Don admin' .. (reason ~= '' and (' : ' .. reason) or ''), ref, actor)
    Db.log(ok and 'info' or 'warn', 'admin_coins_give', acc, ref, ('%s +%d par %s%s'):format(ok and 'ok' or tostring(err), amount, actor, reason ~= '' and (' (' .. reason .. ')') or ''))
    if not ok then return false, err end
    local src = Shop.playerOf and Shop.playerOf(acc)
    if not src then
        for _, s in ipairs(GetPlayers()) do if Shop.accountOf(tonumber(s)) == acc then src = tonumber(s) break end end
    end
    if src then
        Shop.fw.notify(src, ('Vous avez reçu %d %s.'):format(amount, Config.Coins.label), 'success')
        TriggerClientEvent('elyzea_shop:refresh', src)
    end
    return true, ('+%d %s → %s (nouveau solde : %d %s)'):format(amount, Config.Coins.short, src and (GetPlayerName(src) or ('fivem:' .. acc)) or ('fivem:' .. acc .. ', hors ligne'), Coins.balance(acc), Config.Coins.short)
end

A.give = function(d, actor)
    local acc, key = account(d.account), tostring(d.key or '')
    if not acc or not Config.Products[key] then return false, 'Joueur ou produit invalide.' end
    local tx = ('admin-%s-%d-%d'):format(acc, os.time(), math.random(1e6))
    Db.log('info', 'admin_give', acc, tx, ('%s par %s'):format(key, actor))
    local st = Shop.enqueue(tx, key, 'grant', acc, 'admin')
    return true, ('%s → fivem:%s : %s'):format(Config.Products[key].label, acc, st == 'delivered' and 'livré' or 'en attente de connexion')
end

A.delivery_retry = function(d, actor)
    local id = int(d.id, 1, 2147483647)
    local row = id and Db.single('SELECT * FROM `elyzea_shop_deliveries` WHERE `id` = ?', { id })
    if not row then return false, 'Livraison introuvable.' end
    if row.status == 'delivered' then return false, 'Déjà livrée.' end
    local ok, progress = pcall(json.decode, row.progress or '{}')
    progress = ok and type(progress) == 'table' and progress or {}
    progress.started = nil
    Db.update("UPDATE `elyzea_shop_deliveries` SET `status` = 'pending', `attempts` = 0, `progress` = ? WHERE `id` = ?", { json.encode(progress), id })
    Db.log('info', 'admin_retry', row.account, row.transaction_id, actor)
    row = Db.single('SELECT * FROM `elyzea_shop_deliveries` WHERE `id` = ?', { id })
    local st = Shop.process(row)
    return true, ('Livraison #%d : %s'):format(id, st == 'delivered' and 'livrée' or st == 'pending' and 'en attente (joueur hors ligne)' or tostring(st))
end

A.delivery_cancel = function(d, actor)
    local id = int(d.id, 1, 2147483647)
    local n = id and Db.update("UPDATE `elyzea_shop_deliveries` SET `status` = 'cancelled' WHERE `id` = ? AND `status` IN ('pending','failed')", { id }) or 0
    if n == 0 then return false, 'Rien à annuler (déjà livrée ?).' end
    Db.log('info', 'admin_cancel', nil, tostring(id), actor)
    return true, 'Livraison annulée.'
end

-- Image collée dans l'admin menu (data URL) : enregistrée, renvoie son id (le produit l'utilise via « img:<id> »)
A.image_save = function(d, actor)
    local id, err = Images.save(d.data, actor)
    if not id then return false, err end
    Db.log('info', 'admin_image', nil, tostring(id), ('%d Ko par %s'):format(math.floor(#d.data * 3 / 4 / 1024), actor))
    return true, 'Image ajoutée : clique sur « Enregistrer » pour l\'utiliser.', { id = id }
end

-- Relire tout de suite les paquets, prix et images sur Tebex
A.tebex_sync = function(d, actor)
    if GetConvar('sv_tebexSecret', '') == '' then return false, 'sv_tebexSecret absent de server.cfg.' end
    TebexAPI.sync()
    return true, 'Synchronisation avec Tebex lancée (quelques secondes).'
end

-- Actions qui ne modifient rien (consultation)
local READ_ONLY = { account_lookup = true }

exports('AdminAction', function(src, name, data, actor, canEdit)
    if not caller() then return false, 'Appel refusé.' end
    local fn = A[tostring(name)]
    if not fn then return false, 'Action inconnue.' end
    if not READ_ONLY[name] and canEdit ~= true then return false, 'Réservé aux Fondateurs.' end
    local ok, a, b, c = pcall(fn, type(data) == 'table' and data or {}, tostring(actor or ('joueur ' .. tostring(src))))
    if not ok then
        Db.log('error', 'admin_crash', nil, tostring(name), tostring(a))
        return false, 'Erreur interne (voir la console).'
    end
    return a, b, c
end)
