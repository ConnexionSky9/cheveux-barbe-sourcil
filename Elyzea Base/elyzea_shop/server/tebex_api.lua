-- =====================================================================
--  Tebex : connexion DIRECTE à la boutique Tebex (API officielle, clé sv_tebexSecret)
--  · Lit les informations de la boutique (nom, adresse, devise) : Plugin API /information
--  · Lit les paquets (nom, prix TTC, image, catégorie) : Headless API, jeton public de la boutique
--  · Crée un lien de paiement PERSONNEL pour le joueur (Plugin API /checkout, son identifiant Cfx.re)
--  · La clé secrète reste sur le serveur : elle n'est jamais envoyée aux joueurs ni à l'admin menu.
--  La livraison après paiement reste faite par les commandes du paquet (server/tebex.lua).
-- =====================================================================
TebexAPI = {
    state = { connected = false, syncing = false, error = nil, lastSync = 0, account = nil, packages = {}, list = {} },
}
local PLUGIN = 'https://plugin.tebex.io'
local HEADLESS = 'https://headless.tebex.io/api'
local publicToken = nil

local function secret() return GetConvar('sv_tebexSecret', '') end

local function request(method, url, body, useSecret, cb)
    local headers = { ['Content-Type'] = 'application/json', ['Accept'] = 'application/json' }
    if useSecret then headers['X-Tebex-Secret'] = secret() end
    PerformHttpRequest(url, function(code, text)
        code = tonumber(code) or 0
        local ok, data = pcall(json.decode, text or '')
        if not ok then data = nil end
        cb(code, data, text)
    end, method, body and json.encode(body) or '', headers)
end

local function apiError(code, data, text)
    if code == 401 or code == 403 then return ('HTTP %d : clé sv_tebexSecret refusée par Tebex (vérifie la clé du serveur de jeu sur creator.tebex.io)'):format(code) end
    if type(data) == 'table' then
        local m = data.detail or data.title or data.error_message or data.message
        if m then return ('HTTP %d : %s'):format(code, tostring(m)) end
    end
    if code == 0 then return 'Tebex injoignable (connexion Internet du serveur ?)' end
    return ('HTTP %d'):format(code) .. ((text and text ~= '') and (' : ' .. tostring(text):sub(1, 120)) or '')
end

local SYMBOLS = { EUR = '€', USD = '$', GBP = '£', CHF = 'CHF', CAD = '$ CA' }
--- Prix au format français : 9,99 €
function TebexAPI.formatPrice(amount, currency)
    amount = tonumber(amount)
    if not amount then return nil end
    local s = ('%.2f'):format(amount):gsub('%.', ',')
    local cur = tostring(currency or ''):upper()
    if cur == 'USD' then return '$' .. s end
    return s .. ' ' .. (SYMBOLS[cur] or cur)
end

local function storeUrl(domain)
    domain = tostring(domain or '')
    if domain == '' then return nil end
    if not domain:match('^https?://') then domain = 'https://' .. domain end
    return (domain:gsub('/+$', ''))
end

local function cleanText(s, max)
    s = tostring(s or ''):gsub('<br%s*/?>', '\n'):gsub('</p>', '\n'):gsub('<[^>]->', '')
    s = s:gsub('&nbsp;', ' '):gsub('&amp;', '&'):gsub('&quot;', '"'):gsub('&#039;', '\''):gsub('&lt;', '<'):gsub('&gt;', '>')
    s = s:gsub('\r', ''):gsub('\n%s*\n+', '\n'):gsub('^%s+', ''):gsub('%s+$', '')
    return s:sub(1, max or 600)
end

-- Paquets de la boutique (Headless API, lecture publique avec le jeton de la boutique)
local function loadPackages(cb)
    request('GET', ('%s/accounts/%s/categories?includePackages=1'):format(HEADLESS, publicToken), nil, false, function(code, data, text)
        if code < 200 or code >= 300 or type(data) ~= 'table' or type(data.data) ~= 'table' then
            return cb(false, apiError(code, data, text))
        end
        local map, list = {}, {}
        for _, cat in ipairs(data.data) do
            for _, p in ipairs(type(cat.packages) == 'table' and cat.packages or {}) do
                local id = tonumber(p.id)
                if id and not map[id] then
                    local img = type(p.image) == 'string' and p.image:match('^https://[^%s"\'<>]+$') or nil
                    local pk = {
                        id = math.floor(id), name = tostring(p.name or ('Paquet ' .. id)), category = tostring(cat.name or ''),
                        price = tonumber(p.total_price) or tonumber(p.base_price), basePrice = tonumber(p.base_price),
                        discount = tonumber(p.discount) or 0, currency = tostring(p.currency or ''), image = img,
                        type = tostring(p.type or ''), description = cleanText(p.description, 600),
                    }
                    pk.priceText = TebexAPI.formatPrice(pk.price, pk.currency)
                    map[pk.id] = pk
                    list[#list + 1] = pk
                end
            end
        end
        table.sort(list, function(a, b) if a.category ~= b.category then return a.category < b.category end return a.name < b.name end)
        cb(true, map, list)
    end)
end

--- Synchronisation complète (informations + paquets). cb(ok, message) facultatif.
function TebexAPI.sync(cb)
    local st = TebexAPI.state
    local function done(ok, msg)
        st.syncing = false
        st.lastSync = os.time()
        if not ok then
            st.connected, st.error = false, msg
            print(('^3[elyzea_shop] Tebex : %s^0'):format(tostring(msg)))
            if Db and Db.log then pcall(Db.log, 'warn', 'tebex_sync', nil, nil, tostring(msg)) end
        else
            st.connected, st.error = true, nil
        end
        if cb then cb(ok, msg) end
    end
    if secret() == '' then return done(false, 'sv_tebexSecret absent de server.cfg') end
    if st.syncing then if cb then cb(false, 'Synchronisation déjà en cours') end return end
    st.syncing = true
    request('GET', PLUGIN .. '/information', nil, true, function(code, data, text)
        if code < 200 or code >= 300 or type(data) ~= 'table' or type(data.account) ~= 'table' then
            return done(false, apiError(code, data, text))
        end
        local a = data.account
        publicToken = a.public_token
        st.account = {
            name = tostring(a.name or ''), domain = storeUrl(a.domain), gameType = tostring(a.game_type or ''),
            currency = type(a.currency) == 'table' and tostring(a.currency.iso4217 or '') or '',
            server = type(data.server) == 'table' and tostring(data.server.name or '') or '',
        }
        -- adresse de la boutique : celle de Tebex si config.lua n'en donne pas (ou garde l'exemple)
        if st.account.domain and (Config.Tebex.storeUrl == nil or Config.Tebex.storeUrl == '' or Config.Tebex.storeUrl == 'https://elyzea.tebex.io' or Config.Tebex.autoStoreUrl ~= false) then
            Config.Tebex.storeUrl = st.account.domain
        end
        if not publicToken or publicToken == '' then return done(false, 'Jeton public de la boutique absent de la réponse Tebex') end
        loadPackages(function(ok, map, list)
            if not ok then return done(false, map) end
            st.packages, st.list = map, list
            print(('^2[elyzea_shop] Tebex connecté : %s (%d paquet(s))^0'):format(st.account.name, #list))
            done(true, ('%d paquet(s) lu(s) sur %s'):format(#list, st.account.name))
        end)
    end)
end

function TebexAPI.package(id)
    id = tonumber(id)
    return id and TebexAPI.state.packages[math.floor(id)] or nil
end

--- Lien de paiement personnel (le paiement est rattaché au compte Cfx.re du joueur). cb(url | nil, erreur)
function TebexAPI.checkout(packageId, account, cb)
    if secret() == '' then return cb(nil, 'sv_tebexSecret absent') end
    request('POST', PLUGIN .. '/checkout', { package_id = math.floor(tonumber(packageId) or 0), username_id = tostring(account) }, true, function(code, data, text)
        if code >= 200 and code < 300 and type(data) == 'table' and type(data.url) == 'string' and data.url:match('^https://') then
            return cb(data.url)
        end
        cb(nil, apiError(code, data, text))
    end)
end

CreateThread(function()
    Wait(4000)
    while true do
        TebexAPI.sync()
        Wait(math.max(2, tonumber(Config.Tebex.syncMinutes) or 10) * 60000)
    end
end)
