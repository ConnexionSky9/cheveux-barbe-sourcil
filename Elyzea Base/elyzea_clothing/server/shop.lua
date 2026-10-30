-- =====================================================================
--  ELYZEA CLOTHING · BOUTIQUE (serveur)
--  Ouverture :  exports.elyzea_clothing:OpenFor(source, {
--      name = 'Ponsonbys', multiplier = 250,          -- % des prix de base
--      categories = { 'tops', 'pants' },              -- rayons vendus (tous si absent)
--      packs = 'all' | 'gta' | { 'ma_marque' },       -- ce que la boutique vend (tout si absent)
--      coords = vector3(...) })                       -- position du vendeur
--  Le PRIX est toujours recalculé ici : le client ne choisit jamais le prix.
-- =====================================================================
Shop = { sessions = {} }

local core = exports.elyzea_core

local function money(src, kind)
    local ok, v = pcall(function() return core:GetMoney(src, kind) end)
    return ok and math.floor(tonumber(v) or 0) or 0
end
local function removeMoney(src, kind, amount)
    local ok, res = pcall(function() return core:RemoveMoney(src, kind, amount, 'boutique-vetements') end)
    return ok and res == true
end
local function balances(src)
    local out = {}
    for _, k in ipairs(Config.Payments) do out[k] = money(src, k) end
    return out
end
local function result(src, ok, msg, extra) TriggerClientEvent('elyzea_clothing:result', src, ok, msg, extra or {}) end

-- Nettoie la description de boutique reçue
local function cleanShop(shop)
    shop = type(shop) == 'table' and shop or {}
    local cats = {}
    for _, id in ipairs(type(shop.categories) == 'table' and shop.categories or {}) do if Cat[id] then cats[#cats + 1] = id end end
    if #cats == 0 then for _, c in ipairs(Config.Categories) do cats[#cats + 1] = c.id end end
    local packs = 'all'
    if shop.packs == 'gta' then packs = 'gta'
    elseif type(shop.packs) == 'table' then
        packs = {}
        for _, p in ipairs(shop.packs) do packs[#packs + 1] = tostring(p) end
    end
    return {
        name = tostring(shop.name or 'Boutique de vêtements'):sub(1, 40),
        multiplier = math.max(0, math.min(1000, math.floor(tonumber(shop.multiplier) or 100))),
        categories = cats, packs = packs,
    }
end

-- Le pack est-il vendu dans cette boutique ?
-- shop.packs : 'all' (tout), 'gta' (GTA seulement) ou une liste de packs (peut contenir 'gta')
function Shop.sells(shop, pack)
    local listed = function(id)
        if type(shop.packs) ~= 'table' then return false end
        for _, x in ipairs(shop.packs) do if x == id then return true end end
        return false
    end
    if not pack then return Config.Packs.showGTA ~= false and (shop.packs == 'all' or shop.packs == 'gta' or listed('gta')) end
    if pack.hidden then return false end
    return shop.packs == 'all' or listed(pack.id)
end

-- Vêtement de GTA retiré dans config.lua (Config.Blacklist)
local function blacklisted(sex, catId, d)
    for _, n in ipairs(((Config.Blacklist or {})[sex] or {})[catId] or {}) do if n == d then return true end end
    return false
end

function Shop.price(shop, catId, pack)
    local c = Cat[catId]
    local p = c.price * shop.multiplier / 100
    if pack then p = p * pack.price / 100 end
    return math.floor(p + 0.5)
end

local function openFor(src, shop)
    src = tonumber(src)
    if not src or not GetPlayerName(src) then return false end
    local s = cleanShop(shop)
    local c = shop and shop.coords
    local pos = c and vector3(c.x + 0.0, c.y + 0.0, c.z + 0.0) or GetEntityCoords(GetPlayerPed(src))
    Shop.sessions[src] = { shop = s, coords = pos }
    s.vendor = c and { x = pos.x, y = pos.y, z = pos.z } or nil
    TriggerClientEvent('elyzea_clothing:open', src, s, balances(src), { manage = Hidden.canManage(src) })
    return true
end
exports('OpenFor', openFor)

RegisterNetEvent('elyzea_clothing:closed', function() Shop.sessions[source] = nil end)
AddEventHandler('playerDropped', function() Shop.sessions[source] = nil end)

-- ---------------------------------------------------------------------
-- Paiement
-- cart = { { cat, drawable, texture, col, li, wear }, ... } : plusieurs articles par rayon
--   (plusieurs hauts, plusieurs pantalons…) ; wear = la pièce à porter tout de suite
--   (une seule par rayon). current = ce qui était porté avant l'essayage.
-- ---------------------------------------------------------------------
local paying = {}
RegisterNetEvent('elyzea_clothing:buy', function(cart, method, wearNow, current)
    local src = source
    if paying[src] then return end
    local s = Shop.sessions[src]
    if not s then return result(src, false, 'La boutique est fermée.') end
    if #(GetEntityCoords(GetPlayerPed(src)) - s.coords) > Config.MaxDistance then return result(src, false, 'Tu es trop loin de la boutique.') end
    local okMethod = false
    for _, k in ipairs(Config.Payments) do if k == method then okMethod = true end end
    if not okMethod then return result(src, false, 'Moyen de paiement refusé.') end
    local sex = Items.sexOf(src)
    if not sex then return result(src, false, 'Personnage non compatible.') end
    wearNow = wearNow == true
    if wearNow and Items.inUniform(src) then return result(src, false, 'Tu portes une tenue de service : achète sans porter (les vêtements iront dans ton inventaire).') end
    local useItems = Items.enabled()
    cart = type(cart) == 'table' and cart or {}
    if #cart > (Config.MaxCart or 30) then return result(src, false, ('Panier trop grand : %d articles au maximum.'):format(Config.MaxCart or 30)) end

    local allowed, seen, wornCat, perCat, total, list = {}, {}, {}, {}, 0, {}
    for _, id in ipairs(s.shop.categories) do allowed[id] = true end
    for _, it in ipairs(cart) do
        local p = Items.cleanPiece(it)
        local catId = type(it) == 'table' and it.cat
        if not Cat[catId] or not allowed[catId] or p.drawable < -1 or p.drawable > 10000 or p.texture > 500 then
            return result(src, false, 'Panier invalide, recommence.')
        end
        -- Le même article (même modèle, même coloris) n'est compté qu'une fois
        local key = ('%s|%d|%d|%s|%s'):format(catId, p.drawable, p.texture, p.col or '', tostring(p.li or ''))
        if not seen[key] then
            seen[key] = true
            perCat[catId] = (perCat[catId] or 0) + 1
            -- Sans inventaire, un vêtement acheté est forcément porté : un seul par rayon
            if not useItems and perCat[catId] > 1 then return result(src, false, 'Un seul article par rayon dans cette boutique.') end
            local pack = Packs.ofCollection(p.col)
            if p.drawable >= 0 and not Shop.sells(s.shop, pack) then return result(src, false, 'Un article du panier n\'est pas vendu ici.') end
            if p.drawable >= 0 and (Hidden.is(sex, catId, p) or (not p.col and blacklisted(sex, catId, p.drawable))) then
                return result(src, false, 'Un article du panier n\'est plus en vente.')
            end
            local price = p.drawable < 0 and 0 or Shop.price(s.shop, catId, pack)
            total = total + price
            list[#list + 1] = { cat = catId, piece = p, pack = pack, price = price, wear = it.wear == true }
        end
    end
    if #list == 0 then return result(src, false, 'Ton panier est vide.') end

    -- Pièce portée par rayon : celle marquée par le joueur, sinon la première du rayon
    for _, it in ipairs(list) do
        if it.wear and (wornCat[it.cat] or not wearNow and useItems) then it.wear = false end
        if it.wear then wornCat[it.cat] = it end
    end
    if wearNow or not useItems then
        for _, it in ipairs(list) do if not wornCat[it.cat] then wornCat[it.cat] = it it.wear = true end end
    else
        wornCat = {}
        for _, it in ipairs(list) do it.wear = false end
    end

    if useItems and not Items.declared(list) then
        return result(src, false, 'Boutique mal installée : un vêtement n\'existe pas dans l\'inventaire. Préviens le staff.')
    end
    -- Tout ce qui va dans l'inventaire doit y tenir AVANT de payer : articles non portés + vêtements retirés
    current = type(current) == 'table' and current or {}
    local toGive = {}
    if useItems then
        for _, it in ipairs(list) do
            if not it.wear and it.piece.drawable >= 0 then toGive[#toGive + 1] = { cat = it.cat, piece = it.piece } end
        end
        for cat, it in pairs(wornCat) do
            local old = Items.cleanPiece(current[cat])
            if not Items.isNaked(sex, cat, old.drawable) and not Items.same(old, it.piece) then toGive[#toGive + 1] = { cat = cat, piece = old, old = true } end
        end
        if #toGive > 0 and not Items.canCarry(src, sex, toGive) then
            return result(src, false, 'Ton inventaire est plein ou trop lourd : fais de la place avant de payer.')
        end
    end
    if total > 0 then
        if money(src, method) < total then
            return result(src, false, ('Il te manque %d %s.'):format(total - money(src, method), Config.Currency), { money = balances(src) })
        end
        paying[src] = true
        local ok = removeMoney(src, method, total)
        paying[src] = nil
        if not ok then return result(src, false, 'Paiement refusé.', { money = balances(src) }) end
    end
    Shop.sessions[src] = nil

    local wear, refund, given, bought = {}, 0, 0, 0
    -- Un sac acheté et porté tout de suite donne sa place AVANT de ranger les anciens vêtements
    if useItems and wornCat.bags and not Items.isNaked(sex, 'bags', wornCat.bags.piece.drawable) then Items.setBag(src, true) end
    for _, it in ipairs(list) do
        if it.wear then wear[#wear + 1] = { cat = it.cat, piece = it.piece } end
    end
    if useItems then
        for _, g in ipairs(toGive) do
            if Items.give(src, sex, g.cat, g.piece) then
                if g.old then given = given + 1 else bought = bought + 1 end
            elseif not g.old then
                for _, it in ipairs(list) do if it.cat == g.cat and it.piece == g.piece then refund = refund + it.price end end
            end
        end
    end
    if refund > 0 then pcall(function() core:AddMoney(src, method, refund, 'remboursement-vetements') end) end
    print(('[elyzea_clothing] %s [%d] : %d article(s), %d %s chez « %s »'):format(GetPlayerName(src), src, #list, total - refund, Config.Currency, s.shop.name))

    local parts = { ('Achat réglé : %d %s.'):format(total - refund, Config.Currency) }
    if #wear > 0 and wearNow then parts[#parts + 1] = ('%d %s sur toi.'):format(#wear, #wear > 1 and 'pièces portées' or 'pièce portée') end
    if bought > 0 then parts[#parts + 1] = ('%d %s dans ton inventaire.'):format(bought, bought > 1 and 'vêtements' or 'vêtement') end
    if given > 0 then parts[#parts + 1] = 'Tes anciens vêtements y sont aussi.' end
    if refund > 0 then parts[#parts + 1] = ('%d %s remboursés (inventaire plein).'):format(refund, Config.Currency) end
    result(src, true, table.concat(parts, ' '), { wear = (wearNow or not useItems) and wear or {} })
end)
AddEventHandler('playerDropped', function() paying[source] = nil end)

-- Commande de test (staff) : ouvre la boutique sur place, tous rayons, tous packs
if Config.TestCommand then
    RegisterCommand(Config.TestCommand, function(src)
        if src == 0 then return end
        if not IsPlayerAceAllowed(src, Config.TestAce) and not IsPlayerAceAllowed(src, 'command') then return end
        openFor(src, { name = 'Boutique (test)', multiplier = 100 })
    end, false)
end
