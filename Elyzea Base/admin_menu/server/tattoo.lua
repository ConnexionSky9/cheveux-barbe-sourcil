-- =========================================================
--  TATOUEUR - SERVEUR
--  Catalogue lu dans data/tattoos_catalog.lua (+ tattoo_data.lua),
--  prix recalculés ici, jamais ceux du client.
-- =========================================================
local AM = AdminMenu
local CFG = Config.Tattoo or {}
local PRICE_KEYS = { 'head', 'torso', 'left_arm', 'right_arm', 'left_leg', 'right_leg', 'remove' }

local ZONES, ZONE_PRICE = {}, {}
for _, z in ipairs(TattooData.zones) do ZONES[z.id] = z ZONE_PRICE[z.id] = z.price end

-- ---------------------------------------------------------
--  Catalogue
-- ---------------------------------------------------------
local Catalog, ById, ByHash = {}, {}, {}
local CatalogVersion = 0

local ZONE_ALIAS = {
    head = 'ZONE_HEAD', torso = 'ZONE_TORSO', left_arm = 'ZONE_LEFT_ARM', right_arm = 'ZONE_RIGHT_ARM',
    left_leg = 'ZONE_LEFT_LEG', right_leg = 'ZONE_RIGHT_LEG',
}
local function zoneOf(v)
    if type(v) ~= 'string' then return nil end
    local up = v:upper()
    if ZONES[up] then return up end
    return ZONE_ALIAS[v:lower()]
end

local function add(e, seen)
    local m, f = e.m or '', e.f or ''
    if (m == '' and f == '') or not e.collection or not e.zone then return end
    if TattooData.hidden[m] or TattooData.hidden[f] then return end
    local key = e.collection .. '|' .. m .. '|' .. f
    if seen[key] then return end
    seen[key] = true
    e.id = #Catalog + 1
    Catalog[#Catalog + 1] = e
    ById[e.id] = e
    if m ~= '' then ByHash[GetHashKey(m)] = e end
    if f ~= '' then ByHash[GetHashKey(f)] = e end
end

-- Parcourt n'importe quel format de liste (Lua, JSON…)
local function walk(t, parentKey, seen, depth)
    if type(t) ~= 'table' or depth > 6 then return end
    local hm = t.hashMale or t.HashNameMale or t.male
    local hf = t.hashFemale or t.HashNameFemale or t.female
    if t.collection or t.Collection then
        if type(hm) == 'string' or type(hf) == 'string' then
            add({
                collection = t.collection or t.Collection,
                m = type(hm) == 'string' and hm or '', f = type(hf) == 'string' and hf or '',
                zone = zoneOf(t.zone or t.Zone) or zoneOf(parentKey),
                label = tostring(t.label or t.LocalizedName or t.name or t.Name or ''),
                gxt = tostring(t.name or t.Name or ''),
            }, seen)
        end
        return
    end
    for k, v in pairs(t) do walk(v, type(k) == 'string' and k or parentKey, seen, depth + 1) end
end

local function loadSource(src)
    local raw = LoadResourceFile(src.resource, src.file)
    if not raw or raw == '' then return nil end
    if src.file:match('%.json$') then
        local ok, d = pcall(json.decode, raw)
        return ok and d or nil
    end
    local env = setmetatable({ Config = {}, Locales = {} }, { __index = function(_, k)
        local safe = { vector2 = vector2, vector3 = vector3, vector4 = vector4, vec2 = vec2, vec3 = vec3, vec4 = vec4,
            json = json, GetHashKey = GetHashKey, joaat = joaat, tostring = tostring, tonumber = tonumber,
            pairs = pairs, ipairs = ipairs, type = type, table = table, string = string, math = math }
        return safe[k]
    end })
    local fn = load(raw, '@' .. src.resource .. '/' .. src.file, 't', env)
    if not fn or not pcall(fn) then return nil end
    return env.Config.Tattoos or env.Tattoos or env.Config.TattooList
end

local function buildCatalog()
    Catalog, ById, ByHash = {}, {}, {}
    local seen, from = {}, nil
    for _, src in ipairs(CFG.sources or {}) do
        if GetResourceState(src.resource) ~= 'missing' then
            local data = loadSource(src)
            if data then
                walk(data, nil, seen, 0)
                if #Catalog > 0 then from = src.resource .. '/' .. src.file break end
            end
        end
    end
    for _, c in ipairs(TattooData.custom or {}) do
        add({ collection = c.collection, m = c.male or '', f = c.female or '', zone = zoneOf(c.zone) or 'ZONE_TORSO', label = c.label or '', gxt = '' }, seen)
    end
    CatalogVersion = CatalogVersion + 1
    if #Catalog == 0 then
        print('^1[AdminMenu] Tatoueur : aucun tatouage trouvé. Vérifie Config.Tattoo.sources (data/tattoos_catalog.lua).^7')
    else
        print(('^2[AdminMenu] Tatoueur : %d tatouages chargés%s.^7'):format(#Catalog, from and (' depuis ' .. from) or ''))
    end
end

CreateThread(function() Wait(1500) buildCatalog() end)

RegisterNetEvent('adminmenu:tattoo:catalog', function()
    local src = source
    if not AM.rateLimit(src, 'tattoo_cat', 2, 5000) then return end
    local list = {}
    for i, e in ipairs(Catalog) do list[i] = { e.id, e.collection, e.m, e.f, e.zone, e.label, e.gxt } end
    TriggerLatentClientEvent('adminmenu:tattoo:catalog', src, 250000, CatalogVersion, list, TattooData.zones, TattooData.collections)
end)

-- ---------------------------------------------------------
--  Rôle du PNJ (appelé par server/editor.lua › cleanNpc)
-- ---------------------------------------------------------
function TattooCleanRole(t)
    local def = CFG.defaultPrices or {}
    local prices = {}
    local src = type(t.prices) == 'table' and t.prices or {}
    for _, k in ipairs(PRICE_KEYS) do
        local v = tonumber(src[k]) or tonumber(def[k]) or 0
        prices[k] = math.max(0, math.min(1000000, math.floor(v)))
    end
    local name = tostring(t.name or ''):gsub('[<>]', ''):sub(1, 40)
    return {
        name = name ~= '' and name or 'Salon de tatouage', prices = prices,
        payChoice = t.payChoice ~= false, removal = t.removal ~= false,
        blip = t.blip == true,
        blipSprite = math.floor(tonumber(t.blipSprite) or CFG.blipSprite or 75),
        blipColor = math.floor(tonumber(t.blipColor) or CFG.blipColor or 1),
    }
end

local function priceOf(tt, key)
    local p = tt.prices and tt.prices[key]
    if p == nil then p = (CFG.defaultPrices or {})[key] end
    return math.floor(tonumber(p) or 0)
end

-- ---------------------------------------------------------
--  Têtes sauvegardées (mode interne) : liste de { collection, overlay } (hashs)
-- ---------------------------------------------------------
local Saved = Storage.load('tattoo_looks', {})
local function charKey(src) return Bridge.GetCharId(src) or AM.getLicense(src) end

RegisterNetEvent('adminmenu:tattoo:getSaved', function()
    local src = source
    if not AM.rateLimit(src, 'tattoo_saved', 3, 5000) then return end
    local k = charKey(src)
    TriggerClientEvent('adminmenu:tattoo:saved', src, k and Saved[k] or nil)
end)

-- ---------------------------------------------------------
--  Ouverture
-- ---------------------------------------------------------
RegisterNetEvent('adminmenu:tattoo:request', function(id)
    local src = source
    if CFG.enabled == false then return end
    if not AM.rateLimit(src, 'npc', 4, 1000) then return end
    local r = AM.EditorPeds.check(src, id)
    if not r or not r.npc.tattoo then return end
    if #Catalog == 0 then return AM.notify(src, 'Le salon est fermé : aucun tatouage disponible (voir la console serveur).', 'error') end
    local tt, n = r.npc.tattoo, r.npc
    local prices = {}
    for _, k in ipairs(PRICE_KEYS) do prices[k] = priceOf(tt, k) end
    local wallet = {}
    local choice = tt.payChoice and n.payment ~= 'item'
    if choice then
        wallet.cash = Bridge.GetMoney(src, 'cash')
        wallet.bank = Bridge.GetMoney(src, 'bank')
    else
        wallet[n.payment] = Bridge.GetMoney(src, n.payment, n.paymentItem)
    end
    TriggerClientEvent('adminmenu:tattoo:show', src, {
        id = r.id, name = tt.name, prices = prices, removal = tt.removal,
        payChoice = choice, payment = n.payment, wallet = wallet, version = CatalogVersion,
        paymentLabel = n.payment == 'item' and (Bridge.GetLabel(n.paymentItem) or n.paymentItem) or nil,
    })
end)

-- ---------------------------------------------------------
--  Paiement : add = { id, … }, remove = { id, … }, final = liste complète de hashs
-- ---------------------------------------------------------
local Paying = {}
local function result(src, ok, msg) TriggerClientEvent('adminmenu:tattoo:result', src, ok, msg) end

RegisterNetEvent('adminmenu:tattoo:pay', function(id, cart, final, method)
    local src = source
    if not AM.rateLimit(src, 'tattoo_pay', 2, 1500) or Paying[src] then return end
    local r = AM.EditorPeds.check(src, id)
    if not r or not r.npc.tattoo then return result(src, false, 'Tu es trop loin du salon.') end
    local tt, n = r.npc.tattoo, r.npc
    if type(cart) ~= 'table' then return result(src, false, 'Panier invalide.') end

    local total, lines = 0, 0
    for _, tid in ipairs(type(cart.add) == 'table' and cart.add or {}) do
        local e = ById[tonumber(tid) or -1]
        if not e then return result(src, false, 'Un tatouage du panier n\'existe plus.') end
        total = total + priceOf(tt, ZONE_PRICE[e.zone] or 'torso')
        lines = lines + 1
        if lines > 60 then return result(src, false, 'Panier trop grand.') end
    end
    for _, tid in ipairs(type(cart.remove) == 'table' and cart.remove or {}) do
        if not tt.removal then return result(src, false, 'Ce salon ne retire pas les tatouages.') end
        if not ById[tonumber(tid) or -1] then return result(src, false, 'Tatouage inconnu.') end
        total = total + priceOf(tt, 'remove')
        lines = lines + 1
    end
    if lines == 0 then return result(src, false, 'Ton panier est vide.') end

    local kind, item = n.payment, n.paymentItem
    if tt.payChoice and n.payment ~= 'item' then kind = (method == 'bank') and 'bank' or 'cash' end
    Paying[src] = true
    if total > 0 then
        if Bridge.GetMoney(src, kind, item) < total then
            Paying[src] = nil
            return result(src, false, kind == 'bank' and 'Pas assez d\'argent sur ton compte.' or 'Tu n\'as pas assez d\'argent sur toi.')
        end
        if not Bridge.RemoveMoney(src, kind, item, total, 'tatoueur') then
            Paying[src] = nil
            return result(src, false, 'Le paiement a échoué.')
        end
    end
    Paying[src] = nil

    -- Sauvegarde interne : liste complète des tatouages après passage
    if type(final) == 'table' then
        local clean = {}
        for i, v in ipairs(final) do
            if i > 200 then break end
            if type(v) == 'table' and tonumber(v[1]) and tonumber(v[2]) then clean[#clean + 1] = { math.floor(v[1]), math.floor(v[2]) } end
        end
        local k = charKey(src)
        if k then Saved[k] = clean Storage.saveLater('tattoo_looks', Saved, 3000) end
    end

    result(src, true, total > 0 and ('Payé %s $. Tatouages enregistrés !'):format(total) or 'Tatouages enregistrés !')
    TriggerEvent('adminmenu:tattoo:paid', src, total, r.id, cart)
end)

AddEventHandler('playerDropped', function() Paying[source] = nil end)

exports('GetTattooCatalog', function() return Catalog end)
