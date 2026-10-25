-- server_shop : boutique en jeu + livraison des achats.
-- Rien de ce qui vient du client (NUI) ne décide d'un prix, d'un compte ou d'un paiement :
-- le serveur lit lui-même l'identifiant Cfx.re du joueur, vérifie le produit dans le catalogue de l'API,
-- et seule l'API (sur notification Tebex signée) crée les livraisons.

-- ---------- Framework ----------
local function pickFramework()
    local want = Config.Framework
    if want == 'esx' or (want == 'auto' and Adapters.esx.available()) then return Adapters.esx end
    if want == 'elyzea' or (want == 'auto' and Adapters.elyzea.available()) then return Adapters.elyzea end
    return nil
end

CreateThread(function()
    Wait(1000)
    Framework = pickFramework()
    if not Framework then print('^1[server_shop] Aucun framework détecté (es_extended ou elyzea_core) : livraisons désactivées.^0') return end
    if not Api.ready() then print('^1[server_shop] shop_api_url / shop_api_token absents de server.cfg : boutique désactivée.^0') end
    local ok, err = pcall(Db.init)
    if not ok then print('^1[server_shop] Base de données : ' .. tostring(err) .. '^0') end
    print(('^2[server_shop] prêt (framework : %s)^0'):format(Framework.name))
    Framework.onLoaded(function(src) SetTimeout(2000, function() SyncPlayer(src) end) end)
    -- Joueurs déjà connectés (redémarrage de la ressource)
    for _, id in ipairs(GetPlayers()) do SyncPlayer(tonumber(id)) end
end)

local function notify(src, msg, kind) if Framework then Framework.notify(src, msg, kind) end end

-- ---------- Catalogue (cache) ----------
local catalog, catalogAt = nil, 0
local function getCatalog(force)
    if not force and catalog and os.time() - catalogAt < Config.CatalogCacheSeconds then return catalog end
    local st, data = Api.call('GET', '/catalog')
    if Api.ok(st) and data then catalog, catalogAt = data, os.time() end
    return catalog
end

-- ---------- Anti-abus ----------
local last = {}
local function cooldown(src, kind)
    last[src] = last[src] or {}
    local now = GetGameTimer()
    if last[src][kind] and now - last[src][kind] < (Config.Cooldowns[kind] or 3) * 1000 then return false end
    last[src][kind] = now
    return true
end

local function identity(src)
    local cfx = Rewards.cfxOf(src)
    if not cfx then return nil end
    local ids = {}
    for _, kind in ipairs({ 'license', 'license2', 'discord', 'steam' }) do
        local v = GetPlayerIdentifierByType(src, kind)
        if v then ids[kind] = v end
    end
    return { cfxId = cfx, name = (GetPlayerName(src) or 'Joueur'):sub(1, 64), identifiers = ids }
end

-- ---------- Avantages actifs (grades) ----------
function SyncPlayer(src)
    if not src or not GetPlayerName(src) then return end
    local cfx = Rewards.cfxOf(src)
    if not cfx then return end
    CreateThread(function()
        local st, data = Api.call('GET', ('/players/%s/summary'):format(cfx))
        if Api.ok(st) and data then Rewards.applyEntitlements(src, data.entitlements) end
    end)
end
AddEventHandler('playerDropped', function() local src = source Rewards.clear(src) last[src] = nil end)

-- ---------- Boutique (NUI) ----------
RegisterNetEvent('server_shop:open', function()
    local src = source
    if not cooldown(src, 'refresh') then return end
    local id = identity(src)
    local cat = getCatalog(false)
    if not cat then return TriggerClientEvent('server_shop:data', src, { error = Config.Locale.api_down }) end
    local summary
    if id then
        local st, data = Api.call('GET', ('/players/%s/summary'):format(id.cfxId))
        if Api.ok(st) then summary = data end
    end
    TriggerClientEvent('server_shop:data', src, {
        serverName = Config.ServerName, siteUrl = Config.SiteUrl, catalog = cat, summary = summary,
        account = id and { name = id.name, cfxId = id.cfxId } or nil, noCfx = id == nil,
    })
end)

RegisterNetEvent('server_shop:checkout', function(productId, quantity)
    local src = source
    productId, quantity = tonumber(productId), math.floor(tonumber(quantity) or 1)
    if not cooldown(src, 'checkout') then return TriggerClientEvent('server_shop:result', src, 'checkout', { error = Config.Locale.wait }) end
    local id = identity(src)
    if not id then return TriggerClientEvent('server_shop:result', src, 'checkout', { error = Config.Locale.no_cfx }) end
    -- Vérification préalable dans le catalogue (l'API revérifie tout de son côté)
    local found
    for _, p in ipairs((getCatalog(false) or {}).products or {}) do if p.id == productId then found = p break end end
    if not found or not found.available or quantity < 1 or quantity > (found.maxQuantity or 1) then
        return TriggerClientEvent('server_shop:result', src, 'checkout', { error = 'Produit indisponible.' })
    end
    local st, data = Api.call('POST', '/checkout', { cfxId = id.cfxId, name = id.name, identifiers = id.identifiers, items = { { productId = productId, quantity = quantity } } })
    if not Api.ok(st) or not data or not data.redirectUrl then
        return TriggerClientEvent('server_shop:result', src, 'checkout', { error = (data and data.error) or Config.Locale.api_down })
    end
    TriggerClientEvent('server_shop:result', src, 'checkout', { url = data.redirectUrl, ref = data.ref })
end)

local function linkCode(src)
    if not cooldown(src, 'link') then return { error = Config.Locale.wait } end
    local id = identity(src)
    if not id then return { error = Config.Locale.no_cfx } end
    local st, data = Api.call('POST', '/link-code', id)
    if not Api.ok(st) or not data then return { error = (data and data.error) or Config.Locale.api_down } end
    return { code = data.code, url = data.url }
end

RegisterNetEvent('server_shop:link', function()
    local src = source
    TriggerClientEvent('server_shop:result', src, 'link', linkCode(src))
end)

RegisterCommand(Config.LinkCommand, function(src)
    if src == 0 then return end
    CreateThread(function()
        local r = linkCode(src)
        if r.error then return notify(src, r.error, 'error') end
        TriggerClientEvent('chat:addMessage', src, { args = { 'Boutique', ('Votre code : %s (10 minutes). Saisissez-le sur %s'):format(r.code, r.url) } })
        notify(src, ('Code boutique : %s (valable 10 minutes)'):format(r.code), 'success')
    end)
end, false)

-- ---------- Livraisons ----------
local function report(jobId, ok, info)
    local body = { ok = ok }
    -- json.encode({}) donne [] (tableau) : une table vide n'est donc pas envoyée
    if ok then body.meta = (type(info) == 'table' and next(info) ~= nil) and info or nil else body.error = tostring(info or 'Erreur'):sub(1, 480) end
    local st, data = Api.call('POST', ('/deliveries/%d/result'):format(jobId), body)
    if not Api.ok(st) then print(('^3[server_shop] compte rendu de la livraison %d refusé (HTTP %s) : %s^0'):format(jobId, tostring(st), data and data.error or '?')) end
    return Api.ok(st)
end

local function processJob(src, job)
    -- Déjà exécutée ici ? (réponse perdue la dernière fois) → on renvoie seulement le compte rendu
    local rows = Db.query('SELECT `status`, `meta` FROM `server_shop_deliveries` WHERE `job_id` = ?', { job.id }) or {}
    local prev = rows[1]
    if prev then
        if prev.status == 'done' then
            local ok, meta = pcall(json.decode, prev.meta or 'null')
            return report(job.id, true, (ok and type(meta) == 'table') and meta or nil)
        end
        -- Exécution interrompue (arrêt du serveur en plein milieu) : on ne refait pas, un admin vérifie
        return report(job.id, false, 'Livraison interrompue lors d\'un essai précédent : vérifier en jeu puis relancer ou annuler depuis le panel')
    end
    Db.query('INSERT INTO `server_shop_deliveries` (`job_id`, `reward_id`, `action`, `status`) VALUES (?, ?, ?, ?)', { job.id, job.rewardId, job.action, 'started' })
    local okRun, ok, info = pcall(Rewards.run, src, job)
    if not okRun then ok, info = false, 'Erreur script : ' .. tostring(ok) end
    if ok then
        Db.query('UPDATE `server_shop_deliveries` SET `status` = ?, `meta` = ? WHERE `job_id` = ?', { 'done', json.encode(info or {}), job.id })
        notify(src, (job.action == 'grant' and Config.Locale.delivered or Config.Locale.revoked):format(job.productName or 'Produit'), job.action == 'grant' and 'success' or 'inform')
    else
        -- Échec propre (rien n'a été donné) : on efface la trace pour permettre un nouvel essai
        Db.query('DELETE FROM `server_shop_deliveries` WHERE `job_id` = ?', { job.id })
    end
    report(job.id, ok, info)
    return ok
end

CreateThread(function()
    while true do
        Wait(Config.PollSeconds * 1000)
        if Framework and Api.ready() then
            local byCfx, ids = {}, {}
            for _, s in ipairs(GetPlayers()) do
                local src = tonumber(s)
                local cfx = Rewards.cfxOf(src)
                if cfx and Framework.isLoaded(src) then byCfx[cfx] = src ids[#ids + 1] = cfx end
            end
            if #ids > 0 then
                local st, jobs = Api.call('POST', '/deliveries/claim', { cfxIds = ids })
                if Api.ok(st) and type(jobs) == 'table' then
                    local touched = {}
                    for _, job in ipairs(jobs) do
                        local src = byCfx[job.recipientCfxId]
                        if src and GetPlayerName(src) then
                            local ok, err = pcall(processJob, src, job)
                            if not ok then print('^1[server_shop] livraison ' .. tostring(job.id) .. ' : ' .. tostring(err) .. '^0') end
                            if job.type == 'group' or job.type == 'perk' then touched[src] = true end
                        else
                            report(job.id, false, 'Joueur déconnecté pendant la livraison')
                        end
                    end
                    for src in pairs(touched) do SyncPlayer(src) end
                elseif st ~= 0 and not Api.ok(st) then
                    print(('^3[server_shop] API livraisons : HTTP %s^0'):format(tostring(st)))
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, s in ipairs(GetPlayers()) do Rewards.clear(tonumber(s)) end
end)
