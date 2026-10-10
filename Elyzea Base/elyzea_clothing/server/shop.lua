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
    TriggerClientEvent('elyzea_clothing:open', src, s, balances(src))
    return true
end
exports('OpenFor', openFor)

RegisterNetEvent('elyzea_clothing:closed', function() Shop.sessions[source] = nil end)
AddEventHandler('playerDropped', function() Shop.sessions[source] = nil end)

-- ---------------------------------------------------------------------
-- Paiement
-- cart = { { cat, drawable, texture, col, li }, ... } ; current = ce qui était porté avant
-- ---------------------------------------------------------------------
RegisterNetEvent('elyzea_clothing:buy', function(cart, method, wearNow, current)
    local src = source
    local s = Shop.sessions[src]
    if not s then return result(src, false, 'La boutique est fermée.') end
    if #(GetEntityCoords(GetPlayerPed(src)) - s.coords) > Config.MaxDistance then return result(src, false, 'Tu es trop loin de la boutique.') end
    local okMethod = false
    for _, k in ipairs(Config.Payments) do if k == method then okMethod = true end end
    if not okMethod then return result(src, false, 'Moyen de paiement refusé.') end
    local sex = Items.sexOf(src)
    if not sex then return result(src, false, 'Personnage non compatible.') end

    local allowed, seen, total, list = {}, {}, 0, {}
    for _, id in ipairs(s.shop.categories) do allowed[id] = true end
    for _, it in ipairs(type(cart) == 'table' and cart or {}) do
        local p = Items.cleanPiece(it)
        local catId = type(it) == 'table' and it.cat
        if not Cat[catId] or not allowed[catId] or seen[catId] or p.drawable < -1 or p.drawable > 10000 or p.texture > 500 then
            return result(src, false, 'Panier invalide, recommence.')
        end
        seen[catId] = true
        local pack = Packs.ofCollection(p.col)
        if p.drawable >= 0 and not Shop.sells(s.shop, pack) then return result(src, false, 'Un article du panier n\'est pas vendu ici.') end
        local price = p.drawable < 0 and 0 or Shop.price(s.shop, catId, pack)
        total = total + price
        list[#list + 1] = { cat = catId, piece = p, pack = pack, price = price }
    end
    if #list == 0 then return result(src, false, 'Ton panier est vide.') end

    local useItems = Items.enabled()
    if useItems and not Items.declared(list) then
        return result(src, false, 'Boutique mal installée : un vêtement n\'existe pas dans l\'inventaire. Préviens le staff.')
    end
    if useItems and not wearNow and not Items.canCarry(src, sex, list) then
        return result(src, false, 'Ton inventaire est plein ou trop lourd : fais de la place avant de payer.')
    end
    if total > 0 then
        if money(src, method) < total then
            return result(src, false, ('Il te manque %d %s.'):format(total - money(src, method), Config.Currency), { money = balances(src) })
        end
        if not removeMoney(src, method, total) then return result(src, false, 'Paiement refusé.', { money = balances(src) }) end
    end
    Shop.sessions[src] = nil

    local wear, refund, given = {}, 0, 0
    current = type(current) == 'table' and current or {}
    -- Un sac acheté et porté tout de suite donne sa place AVANT de ranger les anciens vêtements
    if useItems and wearNow then
        for _, it in ipairs(list) do
            if it.cat == 'bags' and not Items.isNaked(sex, 'bags', it.piece.drawable) then Items.setBag(src, true) end
        end
    end
    for _, it in ipairs(list) do
        if not useItems or wearNow then
            wear[#wear + 1] = { cat = it.cat, piece = it.piece }
            if useItems then   -- l'ancienne pièce va dans l'inventaire
                local old = Items.cleanPiece(current[it.cat])
                if not Items.isNaked(sex, it.cat, old.drawable) and not Items.same(old, it.piece) then
                    if Items.give(src, sex, it.cat, old) then given = given + 1 end
                end
            end
        elseif it.piece.drawable >= 0 then
            if Items.give(src, sex, it.cat, it.piece) then given = given + 1 else refund = refund + it.price end
        end
    end
    if refund > 0 then pcall(function() core:AddMoney(src, method, refund, 'remboursement-vetements') end) end
    print(('[elyzea_clothing] %s [%d] : %d article(s), %d %s chez « %s »'):format(GetPlayerName(src), src, #list, total - refund, Config.Currency, s.shop.name))

    local msg
    if useItems and not wearNow then
        msg = ('%d %s dans ton inventaire · %d %s.'):format(given, given > 1 and 'vêtements' or 'vêtement', total - refund, Config.Currency)
        if refund > 0 then msg = msg .. (' (%d %s remboursés : inventaire plein)'):format(refund, Config.Currency) end
    else
        msg = ('Achat réglé : %d %s.'):format(total, Config.Currency) .. (given > 0 and ' Tes anciens vêtements sont dans ton inventaire.' or '')
    end
    result(src, true, msg, { wear = wear })
end)

-- Commande de test (staff) : ouvre la boutique sur place, tous rayons, tous packs
if Config.TestCommand then
    RegisterCommand(Config.TestCommand, function(src)
        if src == 0 then return end
        if not IsPlayerAceAllowed(src, Config.TestAce) and not IsPlayerAceAllowed(src, 'command') then return end
        openFor(src, { name = 'Boutique (test)', multiplier = 100 })
    end, false)
end
