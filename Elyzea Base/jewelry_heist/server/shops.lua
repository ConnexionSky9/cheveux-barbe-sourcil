-- =====================================================================
--  JEWELRY HEIST - serveur : vente normale au bijoutier et racheteurs (receleurs)
--  Prix toujours calculés ici. Vente d'un joueur : objets retirés AVANT le paiement ;
--  si le paiement échoue, les objets sont rendus. Achat : argent retiré AVANT l'objet ;
--  si l'objet ne peut pas être donné, l'argent est rendu. Un verrou par joueur empêche
--  deux transactions simultanées (double clic, événements répétés).
-- =====================================================================
local P = JHS

local function qtyOf(v, max)
    local q = math.floor(tonumber(v) or 0)
    if q < 1 or q > max then return nil end
    return q
end

local function icons(gid) return gid end

-- ---------------------------------------------------------------------
-- Bijoutier : listes achat / vente
-- ---------------------------------------------------------------------
local function shopPrices(shop, gid)
    local base = P.S.gems[gid].price
    return math.floor(base * shop.sale.buyMarkup / 100), math.floor(base * shop.sale.sellRate / 100)
end

local function shopUsable(src, shop)
    if not P.S.general.enabled then return JH.T('disabled') end
    if not shop or not shop.enabled then return JH.T('rob_disabled') end
    if not P.Near(src, shop.ped.x, shop.ped.y, shop.ped.z, shop.interactDistance + 1.0) then return JH.T('too_far') end
    if P.heists[shop.id] then return JH.T('rob_active') end
    if (P.shopClosed[shop.id] or 0) > GetGameTimer() then return JH.T('shop_closed', math.ceil((P.shopClosed[shop.id] - GetGameTimer()) / 60000)) end
end

P.Req.shopData = function(src, d)
    local shop = P.ShopById(tostring(d.shop or ''))
    local why = shopUsable(src, shop)
    if why then return { error = why } end
    local list = {}
    for _, gid in ipairs(Config.GemOrder) do
        local g = P.S.gems[gid]
        if g.enabled and P.GemInShop(gid, shop.id) then
            local buy, sell = shopPrices(shop, gid)
            list[#list + 1] = { id = gid, icon = icons(gid), label = g.label, description = g.description, owned = Adapters.Inv.Count(src, gid), buy = buy, sell = sell }
        end
    end
    return { ok = true, kind = 'shop', id = shop.id, name = shop.name, buy = shop.sale.buy, sell = shop.sale.sell, maxPerTx = shop.sale.maxPerTx,
        payment = Adapters.Money.Labels[shop.sale.payment], list = list }
end

P.Req.shopBuy = function(src, d)
    local shop = P.ShopById(tostring(d.shop or ''))
    local why = shopUsable(src, shop)
    if why then return { error = why } end
    if not shop.sale.buy then return { error = JH.T('no_perm') } end
    local gid = tostring(d.gem or '')
    local g = P.S.gems[gid]
    if not g or not g.enabled or not P.GemInShop(gid, shop.id) then P.Log('anomaly', 'shopBuy', src, 'Bijou non proposé : ' .. gid) return { error = JH.T('sell_refused') } end
    local qty = qtyOf(d.qty, shop.sale.maxPerTx)
    if not qty then return { error = JH.T('sell_qty', shop.sale.maxPerTx) } end
    local unit = shopPrices(shop, gid)
    local total = unit * qty
    if not P.Lock('tx:' .. src) then return { error = JH.T('busy') } end
    local res
    if not Adapters.Inv.CanCarry(src, gid, qty) then res = { error = JH.T('buy_space') }
    elseif not Adapters.Money.Remove(src, shop.sale.payment, total, ('Bijouterie %s : %d × %s'):format(shop.name, qty, g.label)) then res = { error = JH.T('buy_money') }
    else
        local ok, reason = Adapters.Inv.Add(src, gid, qty)
        if ok then
            P.Log('sale', shop.id, src, ('Achat au bijoutier %s : %d × %s = %s (%s)'):format(shop.name, qty, g.label, JH.Money(total), shop.sale.payment))
            P.Notify(src, 'buy_done', 'success', qty, g.label, JH.Money(total))
            res = { ok = true }
        else
            Adapters.Money.Add(src, shop.sale.payment, total, 'Remboursement bijouterie')
            P.Log('anomaly', 'shopBuy', src, ('Objet non donné (%s) : %s remboursé'):format(tostring(reason), JH.Money(total)))
            res = { error = JH.T('buy_space') }
        end
    end
    P.Unlock('tx:' .. src)
    return res
end

-- Vente d'objets par le joueur (bijoutier ou racheteur) : retrait puis paiement, rendu si échec
local function sellTo(src, who, gid, qty, unit, payment, label)
    if not P.Lock('tx:' .. src) then return { error = JH.T('busy') } end
    local g = P.S.gems[gid]
    local total = unit * qty
    local res
    if Adapters.Inv.Count(src, gid) < qty then res = { error = JH.T('sell_none') }
    else
        local removed = Adapters.Inv.Remove(src, gid, qty)
        if not removed then res = { error = JH.T('sell_fail') }
        elseif not Adapters.Money.Add(src, payment, total, ('%s : %d × %s'):format(label, qty, g.label)) then
            local back = Adapters.Inv.Add(src, gid, qty)
            P.Log('anomaly', who, src, ('Paiement refusé (%s) : objets %s'):format(JH.Money(total), back and 'rendus' or 'NON RENDUS'))
            res = { error = JH.T('sell_fail') }
        else
            P.Log('sale', who, src, ('%s : %d × %s à %s = %s (%s)'):format(label, qty, g.label, JH.Money(unit), JH.Money(total), payment))
            P.Notify(src, 'sell_done', 'success', qty, g.label, JH.Money(total))
            res = { ok = true }
        end
    end
    P.Unlock('tx:' .. src)
    return res
end

P.Req.shopSell = function(src, d)
    local shop = P.ShopById(tostring(d.shop or ''))
    local why = shopUsable(src, shop)
    if why then return { error = why } end
    if not shop.sale.sell then return { error = JH.T('no_perm') } end
    local gid = tostring(d.gem or '')
    local g = P.S.gems[gid]
    if not g or not g.enabled or not P.GemInShop(gid, shop.id) then return { error = JH.T('sell_refused') } end
    local qty = qtyOf(d.qty, shop.sale.maxPerTx)
    if not qty then return { error = JH.T('sell_qty', shop.sale.maxPerTx) } end
    local _, unit = shopPrices(shop, gid)
    return sellTo(src, shop.id, gid, qty, unit, shop.sale.payment, 'Vente au bijoutier ' .. shop.name)
end

-- ---------------------------------------------------------------------
-- Racheteurs
-- ---------------------------------------------------------------------
local function buyerUsable(src, buyer)
    if not P.S.general.enabled then return JH.T('disabled') end
    if not buyer or not buyer.enabled then return JH.T('sell_refused') end
    if not P.Near(src, buyer.ped.x, buyer.ped.y, buyer.ped.z, buyer.interactDistance + 1.0) then return JH.T('too_far') end
end

P.Req.buyerData = function(src, d)
    local buyer = P.BuyerById(tostring(d.buyer or ''))
    local why = buyerUsable(src, buyer)
    if why then return { error = why } end
    local list = {}
    for _, gid in ipairs(Config.GemOrder) do
        if P.GemForBuyer(gid, buyer) then
            local g = P.S.gems[gid]
            list[#list + 1] = { id = gid, icon = icons(gid), label = g.label, description = g.description, owned = Adapters.Inv.Count(src, gid), sell = P.BuyerPrice(gid, buyer) }
        end
    end
    return { ok = true, kind = 'buyer', id = buyer.id, name = buyer.name, sell = true, buy = false, maxPerTx = buyer.maxPerTx,
        payment = Adapters.Money.Labels[buyer.payment], list = list }
end

P.Req.buyerSell = function(src, d)
    local buyer = P.BuyerById(tostring(d.buyer or ''))
    local why = buyerUsable(src, buyer)
    if why then return { error = why } end
    local gid = tostring(d.gem or '')
    if not P.S.gems[gid] or not P.GemForBuyer(gid, buyer) then P.Log('anomaly', 'buyerSell', src, 'Bijou refusé : ' .. gid) return { error = JH.T('sell_refused') } end
    local qty = qtyOf(d.qty, buyer.maxPerTx)
    if not qty then return { error = JH.T('sell_qty', buyer.maxPerTx) } end
    return sellTo(src, buyer.id, gid, qty, P.BuyerPrice(gid, buyer), buyer.payment, 'Revente au ' .. buyer.name)
end
