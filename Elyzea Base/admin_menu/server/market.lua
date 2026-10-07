-- =========================================================
--  SUPÉRETTE - SERVEUR
--  Produits, catégories et prix réglés PNJ par PNJ dans l'éditeur.
--  Le prix est toujours relu ici ; l'objet n'est donné qu'après paiement
--  (remboursé automatiquement si l'inventaire est plein).
-- =========================================================
local AM = AdminMenu
local CFG = Config.Market or {}

local function clean(s, max) return (tostring(s or ''):gsub('[<>"]', '')):sub(1, max or 40) end
local function int(v, mn, mx, def)
    v = tonumber(v)
    if not v or v ~= v then return def end
    return math.max(mn, math.min(mx, math.floor(v)))
end

-- Rôle du PNJ (appelé par server/editor.lua › cleanNpc)
function MarketCleanRole(m)
    local items = {}
    local src = type(m.items) == 'table' and m.items or {}
    if #src == 0 and m.useDefaults then src = CFG.defaultItems or {} end
    for _, it in ipairs(src) do
        local name = tostring(it.item or ''):gsub('[^%w_%-]', ''):sub(1, 60)
        if name ~= '' and #items < 150 then
            items[#items + 1] = {
                item = name,
                label = clean(it.label, 40),
                price = int(it.price, 0, 10000000, 0),
                cat = clean(it.cat, 24) ~= '' and clean(it.cat, 24) or 'Divers',
                max = int(it.max, 1, 1000, 50),
            }
        end
    end
    local name = clean(m.name, 40)
    return {
        name = name ~= '' and name or 'Supérette',
        items = items,
        payChoice = m.payChoice ~= false,
        blip = m.blip == true,
        blipSprite = int(m.blipSprite, 1, 900, CFG.blipSprite or 52),
        blipColor = int(m.blipColor, 0, 85, CFG.blipColor or 2),
    }
end

RegisterNetEvent('adminmenu:market:request', function(id)
    local src = source
    if CFG.enabled == false then return end
    if not AM.rateLimit(src, 'npc', 4, 1000) then return end
    local r = AM.EditorPeds.check(src, id)
    if not r or not r.npc.market then return end
    local mk, n = r.npc.market, r.npc
    if #mk.items == 0 then return AM.notify(src, 'Les rayons sont vides pour le moment.', 'error') end

    local items = {}
    for i, it in ipairs(mk.items) do
        items[#items + 1] = { i = i, item = it.item, label = it.label ~= '' and it.label or (Bridge.GetLabel(it.item) or it.item),
            price = it.price, cat = it.cat, max = it.max }
    end
    local choice = mk.payChoice and n.payment ~= 'item'
    local wallet = {}
    if choice then
        wallet.cash = Bridge.GetMoney(src, 'cash')
        wallet.bank = Bridge.GetMoney(src, 'bank')
    else
        wallet[n.payment] = Bridge.GetMoney(src, n.payment, n.paymentItem)
    end
    TriggerClientEvent('adminmenu:market:show', src, {
        id = r.id, name = mk.name, items = items, payChoice = choice, payment = n.payment, wallet = wallet,
        paymentLabel = n.payment == 'item' and (Bridge.GetLabel(n.paymentItem) or n.paymentItem) or nil,
        image = CFG.imagePath or 'nui://elyzea_inventory/html/img/%s.png', categories = CFG.categories or {},
    })
end)

local Busy = {}
local function result(src, ok, msg, wallet) TriggerClientEvent('adminmenu:market:result', src, ok, msg, wallet) end

-- cart = { [index du produit] = quantité }
RegisterNetEvent('adminmenu:market:buy', function(id, cart, method)
    local src = source
    if not AM.rateLimit(src, 'market_buy', 3, 1500) or Busy[src] then return end
    local r = AM.EditorPeds.check(src, id)
    if not r or not r.npc.market then return result(src, false, 'Tu es trop loin du comptoir.') end
    local mk, n = r.npc.market, r.npc
    if type(cart) ~= 'table' then return result(src, false, 'Panier invalide.') end

    local lines, total = {}, 0
    for k, q in pairs(cart) do
        local it = mk.items[tonumber(k) or -1]
        local qty = int(q, 0, 1000, 0)
        if not it then return result(src, false, 'Un produit n\'est plus en rayon.') end
        if qty > it.max then return result(src, false, ('Maximum %d × %s par achat.'):format(it.max, it.label ~= '' and it.label or it.item)) end
        if qty > 0 then
            lines[#lines + 1] = { it = it, qty = qty }
            total = total + it.price * qty
        end
    end
    if #lines == 0 then return result(src, false, 'Ton panier est vide.') end

    local kind, item = n.payment, n.paymentItem
    if mk.payChoice and n.payment ~= 'item' then kind = (method == 'bank') and 'bank' or 'cash' end

    Busy[src] = true
    if total > 0 then
        if Bridge.GetMoney(src, kind, item) < total then
            Busy[src] = nil
            return result(src, false, kind == 'bank' and 'Pas assez d\'argent sur ton compte.' or 'Tu n\'as pas assez d\'argent sur toi.')
        end
        if not Bridge.RemoveMoney(src, kind, item, total, 'superette') then
            Busy[src] = nil
            return result(src, false, 'Le paiement a échoué.')
        end
    end

    -- Remise des produits ; ce qui ne rentre pas est remboursé
    local refund, missing = 0, {}
    for _, l in ipairs(lines) do
        local ok = Bridge.AddItem(src, l.it.item, l.qty)
        if not ok then
            refund = refund + l.it.price * l.qty
            missing[#missing + 1] = l.it.label ~= '' and l.it.label or (Bridge.GetLabel(l.it.item) or l.it.item)
        end
    end
    if refund > 0 then Bridge.AddMoney(src, kind, item, refund, 'superette-remboursement') end
    Busy[src] = nil

    local wallet = {}
    if mk.payChoice and n.payment ~= 'item' then
        wallet.cash = Bridge.GetMoney(src, 'cash') wallet.bank = Bridge.GetMoney(src, 'bank')
    else wallet[n.payment] = Bridge.GetMoney(src, n.payment, n.paymentItem) end

    if #missing == #lines then
        return result(src, false, 'Ton inventaire est plein : rien n\'a été acheté, tu es remboursé.', wallet)
    end
    local paid = total - refund
    local msg = ('Achat effectué : %s $.'):format(paid)
    if #missing > 0 then msg = msg .. (' Inventaire plein pour : %s (remboursé).'):format(table.concat(missing, ', ')) end
    result(src, true, msg, wallet)
    TriggerEvent('adminmenu:market:paid', src, paid, r.id, cart)
end)

AddEventHandler('playerDropped', function() Busy[source] = nil end)
