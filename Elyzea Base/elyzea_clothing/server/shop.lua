-- =====================================================================
--  ELYZEA CLOTHING · BOUTIQUE (serveur)
--  Ouverture :  exports.elyzea_clothing:OpenFor(source, {
--      name = 'Ponsonbys', multiplier = 250,          -- % des prix de base
--      categories = { 'tops', 'pants' },              -- rayons vendus (tous si absent)
--      packs = 'all' | 'gta' | { 'ma_marque' },       -- ce que la boutique vend (tout si absent)
--      coords = vector3(...),                         -- position du vendeur
--      currency = 'pesos' })                          -- 'pesos' : la boutique n'accepte QUE les pesos (objet d'inventaire)
--  Le PRIX est toujours recalculé ici : le client ne choisit jamais le prix.
-- =====================================================================
Shop = { sessions = {} }

local core = exports.elyzea_core

-- Pesos (elyzea_change) : objet d'inventaire, pas un compte d'argent
local PESOS = Config.PesosItem or 'pesos'
local function money(src, kind)
    if kind == 'pesos' then
        local ok, v = pcall(function() return exports.elyzea_inventory:GetItemCount(src, PESOS) end)
        return ok and math.floor(tonumber(v) or 0) or 0
    end
    local ok, v = pcall(function() return core:GetMoney(src, kind) end)
    return ok and math.floor(tonumber(v) or 0) or 0
end
local function removeMoney(src, kind, amount)
    if kind == 'pesos' then
        local ok, res = pcall(function() return exports.elyzea_inventory:RemoveItem(src, PESOS, amount) end)
        return ok and res == true
    end
    local ok, res = pcall(function() return core:RemoveMoney(src, kind, amount, 'boutique-vetements') end)
    return ok and res == true
end
local function addMoney(src, kind, amount, reason)
    if kind == 'pesos' then
        return pcall(function() return exports.elyzea_inventory:AddItem(src, PESOS, amount) end)
    end
    return pcall(function() return core:AddMoney(src, kind, amount, reason) end)
end
-- Moyens de paiement d'une boutique.
-- Règle globale « Vetements » de elyzea_change (Config.Payment) : dollars et/ou pesos,
-- monnaie imposée ou non. Une boutique réglée « pesos uniquement » sur son PNJ reste en pesos
-- (sauf si la règle globale impose les dollars).
local function changeOn() return GetResourceState('elyzea_change') == 'started' end
local function payRule(shop)
    if not changeOn() then
        return { methods = (shop and shop.pesos) and { 'pesos' } or Config.Payments, rate = 1.0 }
    end
    local opts = { dollarMethods = Config.Payments }
    if shop and shop.pesos then opts.npcCurrency, opts.npcForce = 'pesos', true end
    local ok, r = pcall(function() return exports.elyzea_change:PaymentMethods(Config.PaymentBusiness or 'Vetements', opts) end)
    if not ok or type(r) ~= 'table' or type(r.methods) ~= 'table' or #r.methods == 0 then
        return { methods = (shop and shop.pesos) and { 'pesos' } or Config.Payments, rate = 1.0 }
    end
    return { methods = r.methods, rate = tonumber(r.rate) or 1.0 }
end
local function paymentsOf(shop) return payRule(shop).methods end
local function onlyPesos(list) return #list == 1 and list[1] == 'pesos' end
local function currencyOf(shop) return onlyPesos(paymentsOf(shop)) and 'pesos' or Config.Currency end
-- Prix dans la monnaie choisie (les prix de la boutique sont en dollars)
local function dueIn(method, total, rate)
    if method == 'pesos' then return math.ceil(total * (rate or 1.0) - 1e-9) end
    return total
end
local function unitOf(method) return method == 'pesos' and 'pesos' or Config.Currency end
local function balances(src, shop)
    local out = {}
    for _, k in ipairs(paymentsOf(shop)) do out[k] = money(src, k) end
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
        pesos = shop.currency == 'pesos',
        bagColor = (type(shop.bagColor) == 'string' and Config.Bags and Config.Bags.colors[shop.bagColor]) and shop.bagColor or nil,
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
    local rule = payRule(s)
    TriggerClientEvent('elyzea_clothing:open', src, s, balances(src, s), { manage = Hidden.canManage(src), payments = rule.methods, currency = currencyOf(s), rate = rule.rate,
        bags = Config.Bags and Config.Bags.enabled and Items.enabled() or false })
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
-- withBag = true : les vêtements achetés (non portés) vont dans des sacs de shopping (server/bags.lua)
RegisterNetEvent('elyzea_clothing:buy', function(cart, method, wearNow, current, withBag)
    local src = source
    if paying[src] then return end
    local s = Shop.sessions[src]
    if not s then return result(src, false, 'La boutique est fermée.') end
    if #(GetEntityCoords(GetPlayerPed(src)) - s.coords) > Config.MaxDistance then return result(src, false, 'Tu es trop loin de la boutique.') end
    local okMethod = false
    local rule = payRule(s.shop)
    for _, k in ipairs(rule.methods) do if k == method then okMethod = true end end
    local CUR = unitOf(method)
    if not okMethod then
        if onlyPesos(rule.methods) then return result(src, false, 'Cette boutique n\'accepte que les pesos.') end
        return result(src, false, 'Moyen de paiement refusé.')
    end
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
    end
    -- Sac de shopping : les articles achetés (pas les anciens vêtements) vont dans un ou plusieurs sacs
    local bagList, bagColor = {}, nil
    if useItems and withBag == true and Config.Bags and Config.Bags.enabled and Bags then
        for _, g in ipairs(toGive) do if not g.old then bagList[#bagList + 1] = g end end
        if #bagList > 0 then bagColor = Bags.pickColor(s.shop.bagColor) end
    end
    if useItems and #toGive > 0 then
        local okCarry
        if bagColor then
            local extra = {}
            for _, g in ipairs(toGive) do
                if g.old then extra[#extra + 1] = { Items.nameOf(g.cat), 1, Items.metadata(sex, g.cat, g.piece) } end
            end
            okCarry = Bags.canCarry(src, bagColor, Bags.count(#bagList), extra)
        else
            okCarry = Items.canCarry(src, sex, toGive)
        end
        if not okCarry then
            return result(src, false, 'Ton inventaire est plein ou trop lourd : fais de la place avant de payer.')
        end
    end
    local due = dueIn(method, total, rule.rate)
    if due > 0 then
        if money(src, method) < due then
            local msg = ('Il te manque %d %s.'):format(due - money(src, method), CUR)
            if method == 'pesos' then msg = msg .. ' Change de l\'argent au bureau de change.' end
            return result(src, false, msg, { money = balances(src, s.shop) })
        end
        paying[src] = true
        local ok = removeMoney(src, method, due)
        paying[src] = nil
        if not ok then return result(src, false, 'Paiement refusé.', { money = balances(src, s.shop) }) end
    end
    Shop.sessions[src] = nil

    local wear, refund, given, bought = {}, 0, 0, 0
    -- Un sac acheté et porté tout de suite donne sa place AVANT de ranger les anciens vêtements
    if useItems and wornCat.bags and not Items.isNaked(sex, 'bags', wornCat.bags.piece.drawable) then Items.setBag(src, true) end
    for _, it in ipairs(list) do
        if it.wear then wear[#wear + 1] = { cat = it.cat, piece = it.piece } end
    end
    local bagged, bagCount = 0, 0
    local function refundOf(g)
        for _, it in ipairs(list) do if it.cat == g.cat and it.piece == g.piece then refund = refund + it.price end end
    end
    if useItems then
        if bagColor then
            -- articles achetés → sacs (le contenu est enregistré par le serveur) ; ce qui n'a pas pu être mis en sac est remboursé
            local entries, ofEntry = {}, {}
            for _, g in ipairs(bagList) do
                local e = { name = Items.nameOf(g.cat), md = Items.metadata(sex, g.cat, g.piece) }
                entries[#entries + 1] = e
                ofEntry[e] = g
            end
            local left, made = Bags.create(src, bagColor, s.shop.name, entries)
            bagCount = made or 0
            bagged = #entries - #left
            for _, e in ipairs(left) do refundOf(ofEntry[e]) end
        end
        for _, g in ipairs(toGive) do
            if not bagColor or g.old then
                if Items.give(src, sex, g.cat, g.piece) then
                    if g.old then given = given + 1 else bought = bought + 1 end
                elseif not g.old then
                    refundOf(g)
                end
            end
        end
    end
    -- Remboursement exact dans la monnaie payée
    local paid = due
    if refund > 0 then
        local back = due - dueIn(method, total - refund, rule.rate)
        if back > 0 then addMoney(src, method, back, 'remboursement-vetements') end
        paid = due - math.max(0, back)
    end
    print(('[elyzea_clothing] %s [%d] : %d article(s), %d %s chez « %s »'):format(GetPlayerName(src), src, #list, paid, CUR, s.shop.name))

    local parts = { ('Achat réglé : %d %s.'):format(paid, CUR) }
    if #wear > 0 and wearNow then
        parts[#parts + 1] = ('%d %s sur toi%s.'):format(#wear, #wear > 1 and 'pièces portées' or 'pièce portée',
            useItems and ' (F3 pour ' .. (#wear > 1 and 'les' or 'la') .. ' ranger dans l\'inventaire)' or '')
    end
    if bought > 0 then parts[#parts + 1] = ('%d %s dans ton inventaire.'):format(bought, bought > 1 and 'vêtements' or 'vêtement') end
    if bagged > 0 then
        parts[#parts + 1] = ('%d %s dans %d sac%s de shopping 🛍️ (utilise le sac dans ton inventaire pour l\'ouvrir).'):format(bagged,
            bagged > 1 and 'vêtements' or 'vêtement', bagCount, bagCount > 1 and 's' or '')
    end
    if given > 0 then parts[#parts + 1] = 'Tes anciens vêtements y sont aussi.' end
    if refund > 0 then parts[#parts + 1] = ('%d %s remboursés (inventaire plein).'):format(due - paid, CUR) end
    result(src, true, table.concat(parts, ' '), { wear = (wearNow or not useItems) and wear or {}, bags = bagCount })
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
