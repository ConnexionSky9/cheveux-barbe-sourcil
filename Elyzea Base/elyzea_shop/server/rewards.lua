-- =====================================================================
--  Livraison des produits.
--  · Une livraison = une ligne elyzea_shop_deliveries (transaction, produit, action) : clé unique,
--    donc une même transaction ne peut jamais être livrée deux fois.
--  · Les récompenses d'un produit sont exécutées une par une ; la progression est enregistrée après
--    chacune. Une exécution interrompue (arrêt du serveur) n'est PAS refaite : elle passe « échouée »
--    pour vérification par un admin (/shopadmin status / retry).
--  · Les récompenses « compte » (coins, grades, avantages) sont livrées même si le joueur est hors ligne ;
--    les récompenses « personnage » (véhicule, objet, argent, commande) attendent sa connexion.
-- =====================================================================
Shop = { fw = nil }
local processing = {}      -- [id livraison] = true pendant l'exécution
local applied = {}         -- [src] = { account, groups = { nom = true } }
Perks = {}                 -- [src] = { nom = true }

local function now() return os.time() end
local function safe(v) return (tostring(v or ''):gsub('[^%w_]', '')) end

function Shop.accountOf(src)
    local id = GetPlayerIdentifierByType(src, 'fivem')
    return id and id:match('^fivem:(%d+)$') or nil
end

--- Joueur connecté ET personnage chargé pour ce compte (nil sinon)
function Shop.playerOf(account)
    for _, s in ipairs(GetPlayers()) do
        local src = tonumber(s)
        if Shop.accountOf(src) == account and Shop.fw and Shop.fw.isLoaded(src) then return src end
    end
    return nil
end

local function decode(s) if not s or s == '' then return {} end local ok, t = pcall(json.decode, s) return ok and type(t) == 'table' and t or {} end
local function encode(t) return json.encode(t) end

-- ------------------------------------------------------------------ Grades / avantages (ACE)
local function principal(account, name) return ('identifier.fivem:%s group.%s'):format(account, safe(name)) end

function Shop.refreshEntitlements(src)
    local account = Shop.accountOf(src)
    if not account then return end
    local rows = Db.query([[SELECT `kind`, `name` FROM `elyzea_shop_entitlements`
        WHERE `account` = ? AND `active` = 1 AND (`expires_at` IS NULL OR `expires_at` > UTC_TIMESTAMP())]], { account })
    local groups, perks = {}, {}
    for _, r in ipairs(rows) do
        perks[r.name] = true
        if r.kind == 'group' then groups[r.name] = true end
    end
    local cur = applied[src] or { account = account, groups = {} }
    for name in pairs(cur.groups) do if not groups[name] then ExecuteCommand('remove_principal ' .. principal(account, name)) end end
    for name in pairs(groups) do if not cur.groups[name] then ExecuteCommand('add_principal ' .. principal(account, name)) end end
    applied[src] = { account = account, groups = groups }
    Perks[src] = perks
end

function Shop.clearPlayer(src)
    local a = applied[src]
    if a then for name in pairs(a.groups) do ExecuteCommand('remove_principal ' .. principal(a.account, name)) end end
    applied[src], Perks[src] = nil, nil
end

-- ------------------------------------------------------------------ Plaques
local CHARS = 'ABCDEFGHJKLMNPRSTUVWXYZ0123456789'
local function newPlate()
    for _ = 1, 30 do
        local p = Config.PlatePrefix
        while #p < 8 do local i = math.random(1, #CHARS) p = p .. CHARS:sub(i, i) end
        if not Shop.fw.plateTaken(p) then return p end
    end
    return nil
end

-- ------------------------------------------------------------------ Commandes prédéfinies
local function commandTemplate(name, phase)
    local def = Config.Commands[name]
    if type(def) == 'string' then return phase == 'grant' and def or nil end
    return type(def) == 'table' and def[phase] or nil
end
local function runCommand(src, account, name, phase)
    if not Config.Commands[name] then return false, ('Commande « %s » absente de Config.Commands'):format(tostring(name)) end
    local tpl = commandTemplate(name, phase)
    if not tpl then return true end
    if (tpl:find('{source}') or tpl:find('{char}')) and not src then return nil end   -- attend le joueur
    local char = src and safe(Shop.fw.characterId(src) or '') or ''
    ExecuteCommand((tpl:gsub('{source}', tostring(src or '')):gsub('{account}', safe(account)):gsub('{char}', char)))
    return true
end

-- ------------------------------------------------------------------ Exécution d'une récompense
-- Renvoie : true, meta  (fait)   |   false, erreur (échec)   |   nil (attend la connexion du joueur)
local NEEDS_PLAYER = { vehicle = true, item = true, money = true }

local function grantOne(src, row, product, rw)
    local t, account = rw.type, row.account
    if NEEDS_PLAYER[t] and not src then return nil end
    if t == 'group' or t == 'perk' then
        local days = tonumber(product.durationDays)
        if days and days > 0 then
            -- Rachat : la nouvelle période commence à la fin de la précédente
            Db.query([[INSERT IGNORE INTO `elyzea_shop_entitlements` (`account`, `kind`, `name`, `product_key`, `transaction_id`, `expires_at`)
                SELECT ?, ?, ?, ?, ?, DATE_ADD(GREATEST(UTC_TIMESTAMP(), COALESCE(MAX(`expires_at`), UTC_TIMESTAMP())), INTERVAL ? DAY)
                FROM `elyzea_shop_entitlements` WHERE `account` = ? AND `name` = ? AND `active` = 1 AND `expires_at` > UTC_TIMESTAMP()]],
                { account, t, rw.name, row.product_key, row.transaction_id, math.floor(days), account, rw.name })
        else
            Db.query('INSERT IGNORE INTO `elyzea_shop_entitlements` (`account`, `kind`, `name`, `product_key`, `transaction_id`) VALUES (?, ?, ?, ?, ?)',
                { account, t, rw.name, row.product_key, row.transaction_id })
        end
        return true, { name = rw.name }
    elseif t == 'coins' then
        if not Config.Coins.enabled then return false, 'Elyzea Coins désactivés' end
        local ok, err = Coins.credit(account, tonumber(rw.amount) or 0, 'Achat : ' .. (product.label or row.product_key), ('%s:%s:grant'):format(row.transaction_id, row.product_key), row.source)
        if not ok then return false, err end
        return true, { amount = rw.amount }
    elseif t == 'vehicle' then
        if not Config.Integrations.vehicles then return false, 'Livraison de véhicules désactivée' end
        local plate = newPlate()
        if not plate then return false, 'Aucune plaque libre' end
        return Shop.fw.giveVehicle(src, rw.model, rw.garage, plate)
    elseif t == 'item' then
        if not Config.Integrations.items then return false, 'Livraison d\'objets désactivée' end
        local ok, err = Shop.fw.giveItem(src, rw.name, tonumber(rw.count) or 1)
        return ok, ok and { count = rw.count } or err
    elseif t == 'money' then
        if not Config.Integrations.money then return false, 'Livraison d\'argent de jeu désactivée (Config.Integrations.money)' end
        local ok, err = Shop.fw.giveMoney(src, rw.account or 'bank', tonumber(rw.amount) or 0)
        return ok, ok and { amount = rw.amount } or err
    elseif t == 'command' then
        return runCommand(src, account, rw.name, 'grant')
    end
    return false, 'Type de récompense inconnu : ' .. tostring(t)
end

local function revokeOne(src, row, product, rw, grantMeta)
    local t, account = rw.type, row.account
    if t == 'group' or t == 'perk' then
        Db.query('UPDATE `elyzea_shop_entitlements` SET `active` = 0 WHERE `transaction_id` = ? AND `product_key` = ? AND `name` = ?', { row.transaction_id, row.product_key, rw.name })
        return true, {}
    elseif t == 'coins' then
        if not Config.Coins.revokeOnRefund then return true, { note = 'coins conservés (Config.Coins.revokeOnRefund = false)' } end
        local ok, taken = Coins.takeUpTo(account, tonumber(rw.amount) or 0, 'Remboursement : ' .. (product.label or row.product_key), ('%s:%s:revoke'):format(row.transaction_id, row.product_key))
        if not ok then return false, taken end
        if taken < (tonumber(rw.amount) or 0) then Db.log('warn', 'coins_revoke_partial', account, row.transaction_id, ('%d/%d coins retirés (solde insuffisant)'):format(taken, rw.amount)) end
        return true, { taken = taken }
    elseif t == 'vehicle' then
        return Shop.fw.removeVehicle(grantMeta)
    elseif t == 'command' then
        return runCommand(src, account, rw.name, 'revoke')
    end
    Db.log('warn', 'revoke_manual', account, row.transaction_id, ('%s (%s) non retirable automatiquement'):format(row.product_key, t))
    return true, { note = 'non retirable automatiquement' }
end

-- ------------------------------------------------------------------ Traitement d'une livraison
function Shop.process(row)
    if processing[row.id] then return 'busy' end
    processing[row.id] = true
    local ok, res = pcall(function()
        local product = Config.Products[row.product_key]
        if not product then
            Db.update("UPDATE `elyzea_shop_deliveries` SET `status` = 'failed', `last_error` = ? WHERE `id` = ?", { 'Produit inconnu dans config.lua', row.id })
            Db.log('error', 'unknown_product', row.account, row.transaction_id, row.product_key)
            return 'failed'
        end
        local progress = decode(row.progress)
        progress.done = progress.done or {}
        if progress.started then
            Db.update("UPDATE `elyzea_shop_deliveries` SET `status` = 'failed', `last_error` = ? WHERE `id` = ?",
                { ('Exécution interrompue à la récompense %d : vérifier en jeu puis /shopadmin retry %d'):format(progress.started, row.id), row.id })
            return 'failed'
        end
        local src = Shop.playerOf(row.account)
        local grantMeta = {}
        if row.action == 'revoke' then
            local g = Db.single("SELECT `progress` FROM `elyzea_shop_deliveries` WHERE `transaction_id` = ? AND `product_key` = ? AND `action` = 'grant'", { row.transaction_id, row.product_key })
            grantMeta = g and decode(g.progress).done or {}
        end
        local waiting = false
        for i, rw in ipairs(product.rewards or {}) do
            local k = tostring(i)
            if not progress.done[k] then
                progress.started = i
                Db.update('UPDATE `elyzea_shop_deliveries` SET `progress` = ? WHERE `id` = ?', { encode(progress), row.id })
                local done, info
                if row.action == 'grant' then done, info = grantOne(src, row, product, rw)
                else done, info = revokeOne(src, row, product, rw, type(grantMeta[k]) == 'table' and grantMeta[k] or nil) end
                progress.started = nil
                if done == true then
                    progress.done[k] = type(info) == 'table' and info or true
                    Db.update('UPDATE `elyzea_shop_deliveries` SET `progress` = ? WHERE `id` = ?', { encode(progress), row.id })
                elseif done == nil then
                    waiting = true
                    Db.update('UPDATE `elyzea_shop_deliveries` SET `progress` = ? WHERE `id` = ?', { encode(progress), row.id })
                else
                    local attempts = (tonumber(row.attempts) or 0) + 1
                    local status = attempts >= Config.Delivery.maxAttempts and 'failed' or 'pending'
                    Db.update('UPDATE `elyzea_shop_deliveries` SET `progress` = ?, `attempts` = ?, `status` = ?, `last_error` = ? WHERE `id` = ?',
                        { encode(progress), attempts, status, tostring(info):sub(1, 250), row.id })
                    Db.log(status == 'failed' and 'error' or 'warn', 'delivery_' .. row.action .. '_error', row.account, row.transaction_id, row.product_key .. ' : ' .. tostring(info))
                    return status
                end
            end
        end
        if waiting then return 'pending' end
        Db.update("UPDATE `elyzea_shop_deliveries` SET `status` = 'delivered', `delivered_at` = UTC_TIMESTAMP(), `last_error` = NULL WHERE `id` = ?", { row.id })
        Db.log('info', 'delivery_' .. row.action, row.account, row.transaction_id, row.product_key)
        if src then
            Shop.refreshEntitlements(src)
            if Config.Delivery.notify then
                Shop.fw.notify(src, (row.action == 'grant' and Config.Locale.delivered or Config.Locale.revoked):format(product.label or row.product_key), 'success')
            end
            TriggerClientEvent('elyzea_shop:refresh', src)
        end
        return 'delivered'
    end)
    processing[row.id] = nil
    if not ok then
        Db.log('error', 'delivery_crash', row.account, row.transaction_id, tostring(res))
        return 'error'
    end
    return res
end

--- Crée (une seule fois) puis traite une livraison. Renvoie le statut et si elle existait déjà.
function Shop.enqueue(tx, productKey, action, account, source)
    Db.query('INSERT IGNORE INTO `elyzea_shop_deliveries` (`transaction_id`, `product_key`, `action`, `account`, `source`) VALUES (?, ?, ?, ?, ?)',
        { tx, productKey, action, account, source })
    local row = Db.single('SELECT * FROM `elyzea_shop_deliveries` WHERE `transaction_id` = ? AND `product_key` = ? AND `action` = ?', { tx, productKey, action })
    if not row then return 'error' end
    if row.account ~= account then
        Db.log('error', 'account_mismatch', account, tx, ('livraison existante pour %s'):format(row.account))
        return 'error'
    end
    if row.status ~= 'pending' then return row.status, true end
    return Shop.process(row), false
end

--- Livraisons en attente d'un compte (connexion, nouvel essai périodique)
function Shop.processPending(account)
    local rows = Db.query("SELECT * FROM `elyzea_shop_deliveries` WHERE `account` = ? AND `status` = 'pending' AND `attempts` < ? ORDER BY `id`", { account, Config.Delivery.maxAttempts })
    for _, row in ipairs(rows) do Shop.process(row) end
end

--- Fin des grades / avantages à durée
function Shop.expire()
    local rows = Db.query('SELECT `id`, `account`, `name` FROM `elyzea_shop_entitlements` WHERE `active` = 1 AND `expires_at` IS NOT NULL AND `expires_at` <= UTC_TIMESTAMP() LIMIT 200')
    local accounts = {}
    for _, r in ipairs(rows) do
        Db.update('UPDATE `elyzea_shop_entitlements` SET `active` = 0 WHERE `id` = ?', { r.id })
        accounts[r.account] = true
        Db.log('info', 'entitlement_expired', r.account, nil, r.name)
    end
    for account in pairs(accounts) do
        for _, s in ipairs(GetPlayers()) do
            local src = tonumber(s)
            if Shop.accountOf(src) == account then Shop.refreshEntitlements(src) end
        end
    end
end

exports('HasPerk', function(src, name) local p = Perks[tonumber(src)] return p ~= nil and p[name] == true end)
exports('GetPerks', function(src) local out = {} for k in pairs(Perks[tonumber(src)] or {}) do out[#out + 1] = k end return out end)
