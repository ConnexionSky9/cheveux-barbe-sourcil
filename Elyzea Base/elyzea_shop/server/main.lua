-- =====================================================================
--  elyzea_shop — serveur : boutique NUI, achats en coins, administration.
--  Rien de ce qui vient du client ne décide d'un prix, d'un compte ou d'un paiement.
-- =====================================================================
local ready = false

CreateThread(function()
    Wait(1500)
    Shop.fw = PickFramework()
    if not Shop.fw then print('^1[elyzea_shop] Aucun framework détecté (es_extended ou elyzea_core) : boutique désactivée.^0') return end
    local ok, err = pcall(Db.install)
    if not ok then print('^1[elyzea_shop] Base de données : ' .. tostring(err) .. '^0') return end
    -- Catalogue modifié depuis l'admin menu (remplace les valeurs de config.lua)
    local okc, errc = pcall(Catalog.load)
    if not okc then print('^1[elyzea_shop] Catalogue : ' .. tostring(errc) .. '^0') end
    if GetConvar('sv_tebexSecret', '') == '' then print('^3[elyzea_shop] sv_tebexSecret absent de server.cfg : les paiements Tebex ne seront pas livrés.^0') end
    ready = true
    print(('^2[elyzea_shop] prêt (framework : %s, base : %s)^0'):format(Shop.fw.name, Db.driver() or '?'))
    Shop.fw.onLoaded(function(src) SetTimeout(2500, function() OnPlayerReady(src) end) end)
    for _, s in ipairs(GetPlayers()) do OnPlayerReady(tonumber(s)) end
end)

function OnPlayerReady(src)
    if not ready or not src or not GetPlayerName(src) then return end
    local account = Shop.accountOf(src)
    if not account then return end
    CreateThread(function()
        Shop.refreshEntitlements(src)
        Shop.processPending(account)
    end)
end

-- Nouveaux essais périodiques (joueurs connectés) + fin des avantages à durée
CreateThread(function()
    while true do
        Wait(Config.Delivery.retrySeconds * 1000)
        if ready then
            pcall(Shop.expire)
            for _, s in ipairs(GetPlayers()) do
                local src = tonumber(s)
                local account = Shop.accountOf(src)
                if account and Shop.fw.isLoaded(src) then pcall(Shop.processPending, account) end
            end
        end
    end
end)

AddEventHandler('playerDropped', function() Shop.clearPlayer(source) end)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, s in ipairs(GetPlayers()) do Shop.clearPlayer(tonumber(s)) end
end)

-- ------------------------------------------------------------------ Anti-abus
local last = {}
local function allow(src, kind, ms)
    last[src] = last[src] or {}
    local t = GetGameTimer()
    if last[src][kind] and t - last[src][kind] < ms then return false end
    last[src][kind] = t
    return true
end
AddEventHandler('playerDropped', function() last[source] = nil end)

-- ------------------------------------------------------------------ Catalogue envoyé à la NUI (sans les récompenses)
local function publicCatalog()
    local products = {}
    for key, p in pairs(Config.Products) do
      if p.enabled ~= false then
        products[#products + 1] = {
            key = key, category = p.category, label = p.label, description = p.description, image = p.image,
            perks = p.perks or {}, displayPrice = p.displayPrice, durationDays = p.durationDays,
            tebex = p.tebexPackageId ~= nil,
            coinsPrice = (Config.Coins.enabled and tonumber(p.coinsPrice)) or nil,
            sort = p.sort or 0,
        }
      end
    end
    table.sort(products, function(a, b) if a.sort ~= b.sort then return a.sort < b.sort end return a.label < b.label end)
    local cats = {}
    for _, c in ipairs(Config.Categories) do if c.enabled ~= false and (c.id ~= 'coins' or Config.Coins.enabled) then cats[#cats + 1] = c end end
    return { categories = cats, products = products }
end

local function playerData(src, account)
    local data = { account = account }
    if not account then return data end
    if Config.Coins.enabled then
        data.coins = Coins.balance(account)
        data.coinHistory = Coins.history(account, 30)
    end
    data.history = Db.query([[SELECT `id`, `transaction_id`, `product_key`, `action`, `source`, `status`, `created_at`, `delivered_at`
        FROM `elyzea_shop_deliveries` WHERE `account` = ? ORDER BY `id` DESC LIMIT 50]], { account })
    for _, h in ipairs(data.history) do
        local p = Config.Products[h.product_key]
        h.label = p and p.label or h.product_key
        h.transaction_id = h.source == 'tebex' and h.transaction_id or nil   -- seule la référence Tebex est utile au joueur
    end
    data.vip = Db.query([[SELECT `name`, MAX(`expires_at`) AS `expires_at`, MAX(`expires_at` IS NULL) AS `permanent` FROM `elyzea_shop_entitlements`
        WHERE `account` = ? AND `active` = 1 AND (`expires_at` IS NULL OR `expires_at` > UTC_TIMESTAMP()) GROUP BY `name`]], { account })
    -- nom affiché : celui du produit qui donne ce grade / avantage (config.lua)
    for _, v in ipairs(data.vip) do
        for _, p in pairs(Config.Products) do
            for _, rw in ipairs(p.rewards or {}) do if (rw.type == 'group' or rw.type == 'perk') and rw.name == v.name then v.label = p.label end end
        end
    end
    return data
end

RegisterNetEvent('elyzea_shop:open', function()
    local src = source
    if not allow(src, 'open', 1500) then return end
    if not ready then return TriggerClientEvent('elyzea_shop:data', src, { error = 'La boutique démarre, réessayez dans un instant.' }) end
    local account = Shop.accountOf(src)
    local payload = {
        serverName = Config.ServerName, catalog = publicCatalog(),
        coins = { enabled = Config.Coins.enabled, label = Config.Coins.label, short = Config.Coins.short },
        player = playerData(src, account), noAccount = account == nil,
    }
    TriggerClientEvent('elyzea_shop:data', src, payload)
end)

-- Lien Tebex d'un produit (ouvert dans le navigateur du joueur). N'accorde rien.
RegisterNetEvent('elyzea_shop:tebex', function(key)
    local src = source
    if not allow(src, 'tebex', 1500) then return end
    local p = type(key) == 'string' and Config.Products[key]
    if not p or not p.tebexPackageId or p.enabled == false then return TriggerClientEvent('elyzea_shop:result', src, 'tebex', { error = 'Ce produit n\'est pas vendu sur Tebex.' }) end
    if not Shop.accountOf(src) then return TriggerClientEvent('elyzea_shop:result', src, 'tebex', { error = Config.Locale.no_account }) end
    TriggerClientEvent('elyzea_shop:result', src, 'tebex', { url = Tebex.packageUrl(p.tebexPackageId), key = key })
end)

-- Achat en Elyzea Coins : prix lu dans config.lua, débit + création de la livraison dans la même transaction SQL
local buying = {}
RegisterNetEvent('elyzea_shop:buyCoins', function(key)
    local src = source
    local function reply(d) TriggerClientEvent('elyzea_shop:result', src, 'coins', d) end
    if not allow(src, 'buy', 3000) or buying[src] then return reply({ error = Config.Locale.wait }) end
    if not ready or not Config.Coins.enabled then return reply({ error = 'Les Elyzea Coins sont désactivés.' }) end
    local p = type(key) == 'string' and Config.Products[key]
    local price = p and tonumber(p.coinsPrice)
    if not p or p.enabled == false or not price or price <= 0 or price ~= math.floor(price) then return reply({ error = 'Ce produit ne s\'achète pas en coins.' }) end
    local account = Shop.accountOf(src)
    if not account then return reply({ error = Config.Locale.no_account }) end
    if not Shop.fw.isLoaded(src) then return reply({ error = 'Personnage non chargé.' }) end
    buying[src] = true
    local tx = ('coins-%s-%d-%d'):format(account, os.time(), math.random(100000, 999999))
    local ok, err = Coins.debit(account, price, 'Achat : ' .. p.label, tx, 'joueur', {
        { query = 'INSERT INTO `elyzea_shop_deliveries` (`transaction_id`, `product_key`, `action`, `account`, `source`) VALUES (?, ?, ?, ?, ?)',
          values = { tx, key, 'grant', account, 'coins' } },
    })
    if not ok then buying[src] = nil return reply({ error = err }) end
    Db.log('info', 'coins_purchase', account, tx, ('%s (%d)'):format(key, price))
    local row = Db.single('SELECT * FROM `elyzea_shop_deliveries` WHERE `transaction_id` = ?', { tx })
    local status = row and Shop.process(row) or 'error'
    buying[src] = nil
    reply({ ok = true, status = status, label = p.label, coins = Coins.balance(account) })
end)
AddEventHandler('playerDropped', function() buying[source] = nil end)

-- ------------------------------------------------------------------ Administration
local function isAdmin(src)
    if src == 0 then return true end
    return IsPlayerAceAllowed(src, Config.AdminAce) or (Shop.fw and Shop.fw.isAdmin(src)) or false
end

local function targetAccount(arg)
    local s = tostring(arg or '')
    local direct = s:match('^fivem:(%d+)$')
    if direct then return direct end
    local id = tonumber(s)
    if id and GetPlayerName(id) then return Shop.accountOf(id) end
    return nil
end

local function say(src, msg)
    if src == 0 then print('[elyzea_shop] ' .. msg) else TriggerClientEvent('chat:addMessage', src, { args = { 'Boutique', msg } }) end
end

RegisterCommand('shopadmin', function(src, args)
    if not isAdmin(src) then return say(src, 'Permission refusée.') end
    local sub = args[1]
    local actor = src == 0 and 'console' or ('%s (%s)'):format(GetPlayerName(src) or '?', Shop.accountOf(src) or src)
    CreateThread(function()
        if sub == 'coins' then
            local account, amount = targetAccount(args[2]), math.floor(tonumber(args[3]) or 0)
            local reason = table.concat(args, ' ', 4)
            if not account or amount == 0 then return say(src, 'Usage : /shopadmin coins <id joueur | fivem:ID> <+/-montant> [raison]') end
            local ref = ('admin-%s-%d-%d'):format(account, os.time(), math.random(1e6))
            local ok, err
            if amount > 0 then ok, err = Coins.credit(account, amount, 'Admin : ' .. (reason ~= '' and reason or 'ajustement'), ref, actor)
            else ok, err = Coins.debit(account, -amount, 'Admin : ' .. (reason ~= '' and reason or 'ajustement'), ref, actor) end
            Db.log(ok and 'info' or 'warn', 'admin_coins', account, ref, ('%s %+d par %s'):format(ok and 'ok' or tostring(err), amount, actor))
            say(src, ok and ('Solde de %s : %d'):format(account, Coins.balance(account)) or ('Refusé : %s'):format(err))
        elseif sub == 'balance' then
            local account = targetAccount(args[2])
            if not account then return say(src, 'Usage : /shopadmin balance <id joueur | fivem:ID>') end
            say(src, ('Solde de %s : %d %s'):format(account, Coins.balance(account), Config.Coins.short))
        elseif sub == 'status' then
            local tx = tostring(args[2] or '')
            local rows = Db.query('SELECT `id`, `product_key`, `action`, `account`, `status`, `attempts`, `last_error`, `delivered_at` FROM `elyzea_shop_deliveries` WHERE `transaction_id` = ?', { tx })
            if #rows == 0 then return say(src, 'Aucune livraison pour cette transaction (la commande Tebex est-elle arrivée ? voir la console).') end
            for _, r in ipairs(rows) do
                say(src, ('#%d %s %s → %s (compte %s, %d essai(s))%s'):format(r.id, r.action, r.product_key, r.status, r.account, r.attempts, r.last_error and (' : ' .. r.last_error) or ''))
            end
        elseif sub == 'retry' then
            local id = tonumber(args[2])
            local row = id and Db.single('SELECT * FROM `elyzea_shop_deliveries` WHERE `id` = ?', { id })
            if not row then return say(src, 'Usage : /shopadmin retry <n° de livraison> (voir /shopadmin status <transaction>)') end
            if row.status == 'delivered' then return say(src, 'Déjà livrée.') end
            local progress = row.progress and json.decode(row.progress) or {}
            progress.started = nil   -- l'admin a vérifié en jeu : on reprend après la dernière récompense terminée
            Db.update("UPDATE `elyzea_shop_deliveries` SET `status` = 'pending', `attempts` = 0, `progress` = ? WHERE `id` = ?", { json.encode(progress), id })
            Db.log('info', 'admin_retry', row.account, row.transaction_id, actor)
            row = Db.single('SELECT * FROM `elyzea_shop_deliveries` WHERE `id` = ?', { id })
            say(src, ('Livraison #%d : %s'):format(id, tostring(Shop.process(row))))
        elseif sub == 'cancel' then
            local id = tonumber(args[2])
            local n = id and Db.update("UPDATE `elyzea_shop_deliveries` SET `status` = 'cancelled' WHERE `id` = ? AND `status` IN ('pending','failed')", { id }) or 0
            if n > 0 then Db.log('info', 'admin_cancel', nil, tostring(id), actor) end
            say(src, n > 0 and 'Livraison annulée.' or 'Rien à annuler (déjà livrée ?).')
        elseif sub == 'give' then
            local account, key = targetAccount(args[2]), tostring(args[3] or '')
            if not account or not Config.Products[key] then return say(src, 'Usage : /shopadmin give <id joueur | fivem:ID> <cle_produit>') end
            local tx = ('admin-%s-%d-%d'):format(account, os.time(), math.random(1e6))
            Db.log('info', 'admin_give', account, tx, ('%s par %s'):format(key, actor))
            say(src, ('%s → %s : %s'):format(key, account, tostring(Shop.enqueue(tx, key, 'grant', account, 'admin'))))
        elseif sub == 'pending' then
            local n = tonumber(Db.scalar("SELECT COUNT(*) FROM `elyzea_shop_deliveries` WHERE `status` = 'pending'")) or 0
            local f = tonumber(Db.scalar("SELECT COUNT(*) FROM `elyzea_shop_deliveries` WHERE `status` = 'failed'")) or 0
            say(src, ('Livraisons en attente : %d · échouées : %d'):format(n, f))
        else
            say(src, 'Sous-commandes : coins, balance, status, retry, cancel, give, pending')
        end
    end)
end, false)
