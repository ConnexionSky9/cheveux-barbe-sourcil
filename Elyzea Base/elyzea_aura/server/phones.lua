-- =========================================================
--  ELYZEA AURA - LES 6 TÉLÉPHONES (serveur)
--  · Modèle utilisé : celui choisi avec « Utiliser » (s'il est encore dans l'inventaire),
--    sinon le meilleur que le joueur a sur lui. Sans téléphone : impossible d'ouvrir.
--  · Applications : vérifiées ici (HasApp) ; un modèle ne peut pas utiliser une appli qu'il n'a pas.
--  · Personnalisation : on ne peut enregistrer que ce que permet le niveau du téléphone
--    (les choix plus avancés restent gardés pour un meilleur téléphone).
--  · Vendeur de téléphones : exports.elyzea_aura:OpenPhoneShop(src, opts) (PNJ de l'éditeur de map).
-- =========================================================
local CFG = Config.Phones
local A = AuraCore

-- Réglages de personnalisation ajoutés avec les ElyAura : valeurs par défaut si config.lua est plus ancien
for k, v in pairs({ effect = 'none', case = 'none', widgets = {}, ringtoneUrl = '', lockStyle = 'classic', edgeColor = '',
    edgeMode = 'auto', iconShape = 'squircle', font = 'manrope' }) do
    if Config.DefaultSettings[k] == nil then Config.DefaultSettings[k] = v end
end

local function Ox(fn, ...)
    if GetResourceState('elyzea_inventory') ~= 'started' then return nil end
    local ok, res = pcall(function(...) return exports.elyzea_inventory[fn](exports.elyzea_inventory, ...) end, ...)
    if ok then return res end
    return nil
end
local function Count(src, item)
    local n = Ox('Search', src, 'count', item)
    return tonumber(n) or 0
end

-- Modèles que le joueur a sur lui : { [n] = true }
local function Owned(src)
    local out = {}
    for n, m in pairs(CFG.Models) do if Count(src, m.item) > 0 then out[n] = true end end
    for item, n in pairs(CFG.LegacyItems or {}) do if Count(src, item) > 0 then out[n] = true end end
    return out
end

local function ModelOf(src, me)
    if GetResourceState('elyzea_inventory') ~= 'started' then return 2 end   -- sans inventaire : téléphone standard
    local own = Owned(src)
    me = me or A.Players[src]
    local pick = me and tonumber(me.settings and me.settings.device)
    if pick and own[pick] then return pick end
    local best
    for n in pairs(own) do if not best or n > best then best = n end end
    return best
end

local function AppSet(m)
    if m.apps == 'all' then
        local ex = {}
        for _, id in ipairs(m.exclude or {}) do ex[id] = true end
        return nil, ex
    end
    local s = {}
    for _, id in ipairs(m.apps or {}) do s[id] = true end
    return s, {}
end

local function Allows(player, app)
    local n = player and player.model
    local m = n and CFG.Models[n]
    if not m then return true end
    local only, ex = AppSet(m)
    if only then return only[app] == true end
    return not ex[app]
end

-- Ce que le téléphone (NUI) doit savoir du modèle
local function Info(src, me)
    local n = ModelOf(src, me)
    me.model = n
    local m = n and CFG.Models[n]
    if not m then return nil end
    local only, ex = AppSet(m)
    local apps, exclude = nil, {}
    if only then apps = {} for id in pairs(only) do apps[#apps + 1] = id end end
    for id in pairs(ex) do exclude[#exclude + 1] = id end
    local owned = {}
    for k in pairs(Owned(src)) do owned[#owned + 1] = k end
    table.sort(owned)
    return { n = n, label = m.label, tier = m.tier, apps = apps, exclude = exclude, faceId = m.faceId ~= false,
        store = m.store ~= false, fold = m.fold == true, owned = owned }
end

-- ---------------------------------------------------------
--  Personnalisation autorisée selon le niveau (mêmes règles que html/js/devices.js)
-- ---------------------------------------------------------
local LOW_WP = { elyzea = true, uni = true, halo = true }
local LOW_ACC = { elyzea = true, plasma = true, glace = true }
local LOW_RING = { cristal = true, classique = true }
local T5_EFFECTS = { feux = true, matrice = true }
local T6_EFFECTS = { holo = true }
local T6_FRAMES = { or_rose = true, carbone = true, holo = true, obsidienne = true }
local T6_WP = { galaxie = true, vague = true }
local CASES_T5 = { cuir = true, neon = true }

local function Clamp(me)
    local s, tier = me.settings, 6
    local m = me.model and CFG.Models[me.model]
    if m then tier = m.tier end
    local D = Config.DefaultSettings
    if tier < 2 then
        s.theme, s.wallpaper, s.accent, s.iconStyle, s.clockStyle, s.edgeLight, s.ringtone = 'dark', 'uni', 'elyzea', 'prisme', 'stack', false, 'classique'
    end
    if tier < 3 then
        if not LOW_WP[s.wallpaper] then s.wallpaper = 'elyzea' end
        if not LOW_ACC[s.accent] then s.accent = 'elyzea' end
        if not LOW_RING[s.ringtone] then s.ringtone = 'cristal' end
        s.iconStyle, s.clockStyle = 'prisme', 'stack'
    end
    if tier < 4 then
        if type(s.accent) == 'string' and s.accent:sub(1, 1) == '#' then s.accent = 'elyzea' end
        if type(s.wallpaper) == 'string' and s.wallpaper:sub(1, 8) == 'https://' then s.wallpaper = 'elyzea' end
        s.effect, s.case = 'none', 'none'
    end
    if tier < 5 then
        if T5_EFFECTS[s.effect] then s.effect = 'none' end
        if CASES_T5[s.case] then s.case = 'none' end
        s.widgets, s.ringtoneUrl, s.lockStyle = {}, '', 'classic'
    end
    if tier < 6 then
        if T6_EFFECTS[s.effect] then s.effect = 'none' end
        if T6_FRAMES[s.frame] then s.frame = D.frame end
        if T6_WP[s.wallpaper] then s.wallpaper = 'elyzea' end
        s.edgeColor, s.edgeMode, s.iconShape, s.font = '', 'auto', 'squircle', 'manrope'
    end
    if m and m.faceId == false then s.faceid = false end
    -- Valeurs libres : contrôle du format
    if type(s.ringtoneUrl) ~= 'string' or #s.ringtoneUrl > 300 or (s.ringtoneUrl ~= '' and not s.ringtoneUrl:match('^https://')) then s.ringtoneUrl = '' end
    if type(s.edgeColor) ~= 'string' or (s.edgeColor ~= '' and not s.edgeColor:match('^#%x%x%x%x%x%x$')) then s.edgeColor = '' end
    for _, k in ipairs({ 'effect', 'case', 'lockStyle', 'edgeMode', 'iconShape', 'font' }) do
        if type(s[k]) ~= 'string' or #s[k] > 24 or not s[k]:match('^[%w_]+$') then s[k] = D[k] end
    end
    local w = {}
    if type(s.widgets) == 'table' then
        for _, id in ipairs(s.widgets) do if type(id) == 'string' and id:match('^[%w_]+$') and #w < 6 then w[#w + 1] = id end end
    end
    s.widgets = w
    if s.device ~= nil and not CFG.Models[tonumber(s.device) or 0] then s.device = nil end
end

Devices = { ModelOf = ModelOf, Allows = Allows, Info = Info, Clamp = Clamp, Owned = Owned }

-- ---------------------------------------------------------
--  « Utiliser » un téléphone dans l'inventaire : il devient le téléphone du joueur
-- ---------------------------------------------------------
local function useModel(src, n)
    local me = A.Players[src]
    if not me then return end
    me.settings.device = n
    me.model = n
    MySQL.update.await('UPDATE elyzea_phones SET settings = ? WHERE identifier = ?', { json.encode(me.settings), me.identifier })
    A.Notify(src, { app = 'settings', title = CFG.Models[n].label, text = 'C\'est maintenant votre téléphone (F1 pour l\'ouvrir).' })
    TriggerClientEvent('elyzea_aura:client:deviceChanged', src, n)
end
local function registerItems()
    if GetResourceState('elyzea_inventory') ~= 'started' then return end
    for n, m in pairs(CFG.Models) do
        pcall(function() exports.elyzea_inventory:RegisterUsableItem(m.item, function(src) useModel(src, n) end) end)
    end
end
CreateThread(function() Wait(1500) registerItems() end)
AddEventHandler('onResourceStart', function(res) if res == 'elyzea_inventory' then SetTimeout(2000, registerItems) end end)

-- ---------------------------------------------------------
--  Vendeur de téléphones
-- ---------------------------------------------------------
local ShopOpen = {}   -- [src] = { coords, name, until }

local function hasVip(src)
    if GetResourceState('elyzea_shop') ~= 'started' then return false end
    for _, perk in ipairs(CFG.Model6Perks or {}) do
        local ok, r = pcall(function() return exports.elyzea_shop:HasPerk(src, perk) end)
        if ok and r then return true end
    end
    return false
end

local function player(src)
    local ok, p = pcall(function() return exports.elyzea_core:GetPlayer(src) end)
    return ok and p or nil
end

local function catalog(src)
    local list, own = {}, Owned(src)
    for n = 1, 6 do
        local m = CFG.Models[n]
        if m then
            list[#list + 1] = { n = n, label = m.label, price = m.price, tagline = m.tagline, tier = m.tier, vip = m.vip == true,
                fold = m.fold == true, owned = own[n] == true }
        end
    end
    return list
end

-- Appelé par admin_menu quand un joueur parle au PNJ « Vendeur de téléphones »
exports('OpenPhoneShop', function(src, opts)
    opts = type(opts) == 'table' and opts or {}
    local ped = GetPlayerPed(src)
    ShopOpen[src] = { coords = ped ~= 0 and GetEntityCoords(ped) or nil, name = tostring(opts.name or 'ElyAura Store'), t = os.time() }
    local p = player(src)
    local money = p and p.PlayerData and p.PlayerData.money or {}
    TriggerClientEvent('elyzea_aura:client:phoneShop', src, {
        name = ShopOpen[src].name, list = catalog(src), vip = hasVip(src),
        cash = tonumber(money.cash) or 0, bank = tonumber(money.bank) or 0, allowBank = CFG.Shop.allowBank ~= false,
    })
end)

RegisterNetEvent('elyzea_aura:server:phoneShopClose', function() ShopOpen[source] = nil end)

local buying = {}
RegisterNetEvent('elyzea_aura:server:phoneShopBuy', function(n, method)
    local src = source
    local sess = ShopOpen[src]
    if not sess or os.time() - sess.t > 600 or buying[src] then return end
    local ped = GetPlayerPed(src)
    if sess.coords and (ped == 0 or #(GetEntityCoords(ped) - sess.coords) > 8.0) then
        return TriggerClientEvent('elyzea_aura:client:phoneShopResult', src, { ok = false, error = 'Vous êtes trop loin du vendeur.' })
    end
    n = tonumber(n)
    local m = n and CFG.Models[n]
    if not m then return end
    if m.vip and not hasVip(src) then
        return TriggerClientEvent('elyzea_aura:client:phoneShopResult', src, { ok = false, error = 'Réservé aux abonnés Elyzea Royale (ou plus).' })
    end
    method = (method == 'bank' and CFG.Shop.allowBank ~= false) and 'bank' or 'cash'
    buying[src] = true
    local ok, err = false, 'Paiement refusé.'
    local canCarry = Ox('CanCarryItem', src, m.item, 1)
    if canCarry == false then
        err = 'Inventaire plein.'
    else
        local p = player(src)
        local paid = p and p.Functions and p.Functions.RemoveMoney(method, m.price, 'achat-' .. m.item)
        if not paid then
            err = method == 'cash' and 'Pas assez d\'argent liquide.' or 'Solde bancaire insuffisant.'
        elseif Ox('AddItem', src, m.item, 1) then
            ok = true
        else
            if p.Functions.AddMoney then p.Functions.AddMoney(method, m.price, 'remboursement-' .. m.item) end
            err = 'Inventaire plein.'
        end
    end
    buying[src] = nil
    local p = player(src)
    local money = p and p.PlayerData and p.PlayerData.money or {}
    TriggerClientEvent('elyzea_aura:client:phoneShopResult', src, { ok = ok, error = not ok and err or nil,
        message = ok and ('%s acheté ! « Utiliser » dans l\'inventaire pour l\'activer.'):format(m.label) or nil,
        list = catalog(src), cash = tonumber(money.cash) or 0, bank = tonumber(money.bank) or 0 })
end)

AddEventHandler('playerDropped', function() ShopOpen[source], buying[source] = nil, nil end)
