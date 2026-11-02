-- =====================================================================
--  ELYZEA RESTAURANT - serveur : remise du sac au client et ouverture du sac
--  Remise (permission « deliver », en service) : l'employé a le sac de CETTE
--  commande (uid), le client de la commande est connecté et proche, il a la
--  place → sac retiré à l'employé puis donné au client → « Livrée ».
--  Ouverture (objet restaurant_bag) : seulement une commande livrée ; le contenu
--  restant est gardé par le serveur (bag_left) : chaque produit ne sort qu'une
--  fois, quel que soit le nombre de copies du sac. Sac vide → supprimé.
-- =====================================================================
local P = Resto
local core = exports.elyzea_core
local BAG = Config.Bag.item

local function inv() return exports.elyzea_inventory end
local function HasBag(src, uid)
    local ok, n = pcall(function() return inv():GetItemCount(src, BAG, { uid = uid }) end)
    return ok and (tonumber(n) or 0) > 0
end
local function BagMeta(src, uid)
    local ok, list = pcall(function() return inv():Search(src, 'slots', BAG, { uid = uid }) end)
    local it = ok and type(list) == 'table' and list[1]
    return it and it.metadata or nil
end

-- ---------------------------------------------------------------------
-- Remise au client
-- ---------------------------------------------------------------------
local delivering = {}
P.Actions.orderDeliver = { perm = 'deliver', duty = true, fn = function(src, d, D)
    local o = P.orders[tonumber(d.id) or -1]
    if not o or o.shop ~= D.id then return { error = 'Commande introuvable.' } end
    if o.status ~= 'ready' then return { error = o.status == 'preparing' and 'Commande pas encore terminée.' or 'Commande non prête.' } end
    if delivering[o.id] then return { error = 'Remise déjà en cours.' } end
    if not HasBag(src, o.bag) then return { error = ('Vous n\'avez pas le sac de la commande %s sur vous.'):format(P.Num(o)) } end
    local target = core:GetSourceByCitizenId(o.cid)
    if not target then return { error = ('%s (client) n\'est pas en ville.'):format(o.cname or 'Le client') } end
    if target == src then return { error = 'Vous ne pouvez pas vous remettre votre propre commande : un collègue doit le faire.' } end
    if P.Dist(src, target) > Config.Delivery.distance then
        return { error = ('Le client (%s) doit être à moins de %d m de vous.'):format(o.cname or '?', math.floor(Config.Delivery.distance)) }
    end
    delivering[o.id] = true
    local ok, res = pcall(function()
        local meta = BagMeta(src, o.bag)
        if not meta then return { error = 'Sac introuvable dans votre inventaire.' } end
        if not inv():CanCarryItem(target, BAG, 1, meta) then return { error = ('L\'inventaire de %s est plein.'):format(o.cname or 'du client') } end
        if not inv():RemoveItem(src, BAG, 1, { uid = o.bag }) then return { error = 'Sac introuvable dans votre inventaire.' } end
        if not inv():AddItem(target, BAG, 1, meta) then
            inv():AddItem(src, BAG, 1, meta)
            return { error = 'Remise impossible : le sac vous a été rendu.' }
        end
        o.status = 'delivered'
        P.orders[o.id] = nil
        P.SaveOrder(o, ', `delivered_at` = NOW()')
        P.Notify(target, ('Votre commande %s de %s vous a été remise. Utilisez le sac dans votre inventaire pour l\'ouvrir.'):format(P.Num(o), D.name), 'success')
        -- Commande en pesos : rien n'est entré sur le compte en $, pas de commission prélevée dessus
        if o.emp and o.method ~= 'pesos' then P.Commission(D, o.emp, o.total, ('Commande %s'):format(P.Num(o)), tostring(o.id)) end
        P.PushOrders()
        P.Log(src, 'Commande livrée', ('%s · %s → %s'):format(D.name, P.Num(o), o.cname or '?'))
        return { ok = true, message = ('Commande %s remise à %s.'):format(P.Num(o), o.cname or 'le client') }
    end)
    delivering[o.id] = nil
    if not ok then print(('^1[RESTO] Remise : %s^0'):format(tostring(res))) return { error = 'Erreur pendant la remise.' } end
    return res
end }

-- ---------------------------------------------------------------------
-- Ouverture du sac
-- ---------------------------------------------------------------------
local function LoadBag(uid)
    if type(uid) ~= 'string' or uid == '' then return nil end
    return MySQL.single.await('SELECT `id`, `shop_id`, `num`, `status`, `bag_left`, `customer_name` FROM `rs_orders` WHERE `bag_uid` = ?', { uid })
end
local function BagView(row, uid)
    local D = P.shops[row.shop_id]
    local lines = {}
    for i, l in ipairs(P.Decode(row.bag_left, {})) do
        local p = P.Products[l.p] or {}
        lines[#lines + 1] = { i = i, label = l.label, qty = l.qty, image = p.image or (tostring(l.item) .. '.png') }
    end
    return { uid = uid, num = ('#%03d'):format(tonumber(row.num) or 0), shop = D and D.name or 'Restaurant', logo = D and P.Opt(D, 'logo', '🍽️') or '🍽️',
        color = D and P.Opt(D, 'color', '#f97316') or '#f97316', customer = row.customer_name, lines = lines }
end

CreateThread(function()
    while GetResourceState('elyzea_inventory') ~= 'started' do Wait(500) end
    exports.elyzea_inventory:RegisterUsableItem(BAG, function(src, item)
        local uid = item and item.metadata and item.metadata.uid
        local row = LoadBag(uid)
        if not row then P.Notify(src, 'Ce sac est vide.', 'error') return false end
        if row.status ~= 'delivered' then P.Notify(src, 'Ce sac n\'a pas encore été remis au client : il ne s\'ouvre pas.', 'error') return false end
        local v = BagView(row, uid)
        if #v.lines == 0 then
            inv():RemoveItem(src, BAG, 1, { uid = uid })
            P.Notify(src, 'Le sac était vide : jeté.', 'inform')
            return false
        end
        TriggerClientEvent('resto:client:bag', src, v)
        return false   -- jamais consommé ici : le sac disparaît quand il est vide
    end)
end)

-- Prendre un produit (line = n°) ou tout (line absent)
local bagLock = {}
P.Pub.bagTake = { fn = function(src, d)
    local uid = tostring(d.uid or '')
    if uid == '' then return { error = 'Sac invalide.' } end
    if bagLock[uid] then return { error = 'Un instant…' } end
    bagLock[uid] = true
    local ok, res = pcall(function()
        if not HasBag(src, uid) then return { error = 'Vous n\'avez plus ce sac.', close = true } end
        local row = LoadBag(uid)
        if not row or row.status ~= 'delivered' then return { error = 'Ce sac ne s\'ouvre pas.', close = true } end
        local left = P.Decode(row.bag_left, {})
        local pick = {}
        local want = tonumber(d.line)
        for i, l in ipairs(left) do
            if (not want or want == i) and (tonumber(l.qty) or 0) > 0 then pick[#pick + 1] = { i = i, item = l.item, qty = math.floor(tonumber(l.qty)) } end
        end
        if #pick == 0 then return { error = 'Rien à prendre.' } end
        local list = {}
        for _, x in ipairs(pick) do list[#list + 1] = { x.item, x.qty } end
        if not inv():CanCarryItems(src, list) then return { error = 'Pas assez de place dans votre inventaire.' } end
        -- Contenu restant mis à jour AVANT de donner (écriture conditionnelle : jamais deux fois)
        local newLeft = {}
        local remaining = 0
        local taken = {}
        for i, l in ipairs(left) do
            local nl = { p = l.p, item = l.item, label = l.label, qty = tonumber(l.qty) or 0 }
            for _, x in ipairs(pick) do if x.i == i then nl.qty = 0 taken[#taken + 1] = x end end
            if nl.qty > 0 then remaining = remaining + nl.qty newLeft[#newLeft + 1] = nl end
        end
        local aff = MySQL.update.await('UPDATE `rs_orders` SET `bag_left` = ?, `opened` = ? WHERE `bag_uid` = ? AND `bag_left` = ?',
            { json.encode(newLeft), remaining == 0 and 1 or 0, uid, row.bag_left })
        if (tonumber(aff) or 0) < 1 then return { error = 'Le sac a changé : rouvrez-le.', close = true } end
        local got = {}
        for _, x in ipairs(taken) do
            if inv():AddItem(src, x.item, x.qty) then got[#got + 1] = ('%d × %s'):format(x.qty, left[x.i].label)
            else print(('^1[RESTO] Sac %s : %d × %s non donné (inventaire)^0'):format(uid, x.qty, tostring(x.item))) end
        end
        if remaining == 0 then inv():RemoveItem(src, BAG, 1, { uid = uid }) end
        row.bag_left = json.encode(newLeft)
        return { ok = true, empty = remaining == 0, bag = BagView(row, uid),
            message = (#got > 0 and ('Récupéré : %s.'):format(table.concat(got, ', ')) or 'Rien récupéré.') .. (remaining == 0 and ' Sac vide : jeté.' or '') }
    end)
    bagLock[uid] = nil
    if not ok then print(('^1[RESTO] Sac : %s^0'):format(tostring(res))) return { error = 'Erreur pendant l\'ouverture du sac.' } end
    return res
end }
