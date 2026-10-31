-- =====================================================================
--  ELYZEA RESTAURANT - serveur : commandes
--  Client  : carte au point de commande → panier → paiement (banque / espèces)
--            → commande enregistrée, personnel prévenu.
--  Employé : appli « Commande » du téléphone de service (ou tablette) :
--            en attente → « Prendre en charge » (un seul employé, jamais deux)
--            → stations de cuisine (kitchen.lua) → sac (restaurant_bag)
--            → remise au client (bag.lua).
--  Statuts : pending (En attente) · preparing (En préparation) · ready (Terminée)
--            · delivered (Livrée) · cancelled (Annulée)
--  Tout est recalculé ici : prix de la carte, total, quantités, propriétaire.
-- =====================================================================
local P = Resto
local core = exports.elyzea_core
local O = Config.Orders

P.orders = {}     -- [id] = commande non terminée (pending, preparing, ready)
P.nums = {}       -- [shopId] = dernier numéro donné
local ordering = {}   -- [src] = true pendant un paiement (pas de double commande)

P.StatusLabel = { pending = 'En attente', preparing = 'En préparation', ready = 'Terminée', delivered = 'Livrée', cancelled = 'Annulée' }

function P.Num(o) return ('#%03d'):format(tonumber(o.num) or 0) end
local function Units(o)
    local n, done = 0, 0
    for _, l in ipairs(o.lines) do n, done = n + l.qty, done + math.min(l.qty, l.done or 0) end
    return n, done
end
P.Units = Units

function P.SaveOrder(o, extra, args)
    -- Positions explicites : employé vide (nil) au milieu de la liste sans décaler les valeurs
    local a = { json.encode(o.lines), o.status, o.emp or nil, o.empName or nil }
    local n = 4
    for i = 1, select('#', table.unpack(args or {})) do n = n + 1 a[n] = (args or {})[i] end
    a[n + 1] = o.id
    MySQL.update.await('UPDATE `rs_orders` SET `lines` = ?, `status` = ?, `employee_cid` = ?, `employee_name` = ?' .. (extra or '') .. ' WHERE `id` = ?', a)
end

-- Vue d'une commande (téléphone, tablette, client)
function P.OrderView(o, viewerCid)
    local lines = {}
    for i, l in ipairs(o.lines) do
        local p = P.Products[l.p] or {}
        lines[i] = { label = l.label, qty = l.qty, done = math.min(l.qty, l.done or 0), price = l.price, image = p.image or (l.item .. '.png'),
            station = p.station, stationLabel = (Config.StationTypes[p.station or ''] or {}).label }
    end
    local units, done = Units(o)
    return { id = o.id, num = P.Num(o), status = o.status, statusLabel = P.StatusLabel[o.status] or o.status, t = o.created, total = o.total,
        method = o.method, customer = o.cname, employee = o.empName, mine = viewerCid ~= nil and o.emp == viewerCid, units = units, done = done,
        lines = lines, bagMissing = o.status == 'ready' and o.bagGiven == false or nil, shop = (P.shops[o.shop] or {}).name }
end

-- Prévenir les employés concernés du restaurant (permission « orders »)
function P.NotifyStaff(D, msg, kind)
    for src in pairs(core:GetPlayers()) do
        local e = P.Employee(src)
        if e and e.shop_id == D.id and P.ShopOf(src) and P.Can(src, 'orders') and (O.notifyOffDuty or P.OnDuty(src)) then
            P.Notify(src, msg, kind or 'inform')
        end
    end
end
-- Rafraîchir l'appli « Commande » des téléphones ouverts (les données restent filtrées par restaurant)
function P.PushOrders()
    TriggerEvent('elyzea_jobphone:pushRes', GetCurrentResourceName(), 'cmd')
end
function P.NotifyCid(cid, msg, kind)
    local s = cid and core:GetSourceByCitizenId(cid)
    if s then P.Notify(s, msg, kind) end
    return s
end

-- ---------------------------------------------------------------------
-- Chargement : commandes non terminées et numéros
-- ---------------------------------------------------------------------
P.OnReady[#P.OnReady + 1] = function()
    P.orders, P.nums = {}, {}
    for _, r in ipairs(MySQL.query.await('SELECT `shop_id`, MAX(`num`) AS n FROM `rs_orders` GROUP BY `shop_id`') or {}) do
        P.nums[tonumber(r.shop_id)] = tonumber(r.n) or 0
    end
    for _, r in ipairs(MySQL.query.await([[SELECT `id`, `shop_id`, `num`, `customer_cid`, `customer_name`, `lines`, `total`, `method`, `status`, `employee_cid`, `employee_name`,
        `bag_uid`, UNIX_TIMESTAMP(`created_at`) AS t FROM `rs_orders` WHERE `status` IN ('pending', 'preparing', 'ready')]]) or {}) do
        P.orders[r.id] = { id = r.id, shop = r.shop_id, num = r.num, cid = r.customer_cid, cname = r.customer_name, lines = P.Decode(r.lines, {}),
            total = tonumber(r.total) or 0, method = r.method, status = r.status, emp = r.employee_cid, empName = r.employee_name, bag = r.bag_uid,
            bagGiven = r.status == 'ready' and true or nil, created = tonumber(r.t) or os.time() }
    end
end

-- ---------------------------------------------------------------------
-- Client : carte et commande
-- ---------------------------------------------------------------------
local function MyActive(cid)
    local list, n = {}, 0
    for _, o in pairs(P.orders) do
        if o.cid == cid then n = n + 1 list[#list + 1] = P.OrderView(o) end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list, n
end

P.Pub.menuCard = { fn = function(src, d)
    local D = P.shops[tonumber(d.shop) or 0]
    if not D or not P.ShopOpen(D) then return { error = 'Restaurant introuvable.' } end
    local mine = MyActive(P.Cid(src) or '')
    return { shop = { id = D.id, name = D.name, logo = P.Opt(D, 'logo', '🍽️'), color = P.Opt(D, 'color', '#f97316'), address = D.address, open = P.PublicOpen(D) },
        categories = Config.Categories, products = P.MenuView(D, true), methods = O.methods,
        limits = { maxQty = O.maxQty, maxLines = O.maxLines, maxUnits = O.maxUnits }, mine = mine }
end }

P.Pub.myOrders = { fn = function(src)
    local mine = MyActive(P.Cid(src) or '')
    return { list = mine }
end }

-- Panier → lignes validées (prix de la carte, quantités bornées, doublons fusionnés)
function P.BuildLines(D, raw)
    if type(raw) ~= 'table' then return nil, 'Panier vide.' end
    local byId, order = {}, {}
    local units, total = 0, 0
    for _, r in ipairs(raw) do
        if type(r) ~= 'table' then return nil, 'Panier invalide.' end
        local p, price = P.MenuLine(D, r.id)
        if not p then return nil, 'Un produit du panier n\'est plus à la carte : rouvrez la carte.' end
        local raw = tonumber(r.qty)
        local qty = raw and raw == math.floor(raw) and raw >= 1 and raw <= O.maxQty and math.floor(raw) or nil
        if not qty then return nil, ('Quantité invalide (1 à %d).'):format(O.maxQty) end
        if not byId[p.id] then
            byId[p.id] = { p = p.id, item = p.item, label = p.label, qty = 0, price = price, done = 0 }
            order[#order + 1] = byId[p.id]
        end
        byId[p.id].qty = math.min(O.maxQty, byId[p.id].qty + qty)
    end
    if #order == 0 then return nil, 'Panier vide.' end
    if #order > O.maxLines then return nil, ('%d produits différents au plus par commande.'):format(O.maxLines) end
    for _, l in ipairs(order) do units, total = units + l.qty, total + l.qty * l.price end
    if units > O.maxUnits then return nil, ('%d articles au plus par commande.'):format(O.maxUnits) end
    return order, total, units
end

local function MethodOk(m) for _, x in ipairs(O.methods) do if x == m then return true end end return false end

P.Pub.order = { fn = function(src, d)
    local D = P.shops[tonumber(d.shop) or 0]
    if not D or not P.ShopOpen(D) then return { error = 'Restaurant introuvable.' } end
    if not P.PublicOpen(D) then return { error = ('%s ne prend pas de commandes pour le moment.'):format(D.name) } end
    if not P.NearPoint(src, D.points.order, O.orderDistance) then return { error = 'Approchez-vous du point de commande.' } end
    local cid = P.Cid(src)
    if not cid then return { error = 'Personnage non chargé.' } end
    if ordering[src] then return { error = 'Paiement déjà en cours.' } end
    local _, active = MyActive(cid)
    if active >= O.maxActivePerCustomer then return { error = ('Vous avez déjà %d commande(s) en cours : attendez qu\'elle(s) soi(en)t livrée(s).'):format(active) } end
    local method = tostring(d.method or '')
    if not MethodOk(method) then return { error = 'Moyen de paiement invalide.' } end
    local lines, total, units = P.BuildLines(D, d.lines)
    if not lines then return { error = total } end
    if tonumber(d.expect) and tonumber(d.expect) ~= total then return { error = 'Les prix ont changé : vérifiez votre panier.', reload = true } end

    ordering[src] = true
    local ok, res = pcall(function()
        local label = ('Commande · %s'):format(D.name)
        if not P.ChargeWith(src, total, method, label) then
            return { error = method == 'cash' and 'Pas assez d\'espèces sur vous.' or 'Solde bancaire insuffisant.' }
        end
        if total > 0 and not P.SocietyAdd(D, total, label) then
            P.Refund(cid, total, method, 'Remboursement · ' .. label)
            return { error = 'Paiement impossible pour le moment : vous avez été remboursé.' }
        end
        -- Numéro donné seulement une fois payé (aucune attente entre la lecture et l'écriture)
        local num = (P.nums[D.id] or 0) + 1
        P.nums[D.id] = num
        label = ('Commande %s · %s'):format(('#%03d'):format(num), D.name)
        local name = P.Name(src)
        local id = MySQL.insert.await([[INSERT INTO `rs_orders` (`shop_id`, `num`, `customer_cid`, `customer_name`, `lines`, `total`, `method`, `status`)
            VALUES (?, ?, ?, ?, ?, ?, ?, 'pending')]], { D.id, num, cid, name, json.encode(lines), total, method })
        if not id then
            if total > 0 then P.SocietyRemove(D, total, 'Annulation · ' .. label) end
            P.Refund(cid, total, method, 'Remboursement · ' .. label)
            return { error = 'Commande non enregistrée : vous avez été remboursé.' }
        end
        local o = { id = id, shop = D.id, num = num, cid = cid, cname = name, lines = lines, total = total, method = method, status = 'pending', created = os.time() }
        P.orders[id] = o
        if total > 0 then
            P.Tx(D, { type = 'in', category = 'order', amount = total, reason = label, actorCid = cid, actorName = name, ref = tostring(id) })
        end
        P.NotifyStaff(D, ('Nouvelle commande reçue ! Commande %s – %d produit(s). Consultez votre téléphone de service pour la prendre en charge.'):format(P.Num(o), units), 'success')
        P.PushOrders()
        P.Log(src, 'Commande', ('%s · %s · %d $'):format(D.name, P.Num(o), total))
        return { ok = true, order = P.OrderView(o), message = ('Commande %s payée (%d $). Vous serez prévenu(e) quand elle sera prête.'):format(P.Num(o), total) }
    end)
    ordering[src] = nil
    if not ok then print(('^1[RESTO] Commande : %s^0'):format(tostring(res))) return { error = 'Erreur pendant la commande.' } end
    return res
end }

AddEventHandler('playerDropped', function() ordering[source] = nil end)

-- ---------------------------------------------------------------------
-- Employé : liste, prise en charge, libération, annulation
-- ---------------------------------------------------------------------
local function ShopOrder(D, id)
    local o = P.orders[tonumber(id) or -1]
    if not o or o.shop ~= D.id then return nil end
    return o
end
function P.MyTaken(cid)
    local n = 0
    for _, o in pairs(P.orders) do if o.emp == cid and (o.status == 'preparing' or o.status == 'ready') then n = n + 1 end end
    return n
end

P.Actions.ordersList = { perm = 'orders', fn = function(src, _, D)
    local cid = P.Cid(src)
    local pending, mine, others = {}, {}, {}
    for _, o in pairs(P.orders) do
        if o.shop == D.id then
            local v = P.OrderView(o, cid)
            if o.status == 'pending' then pending[#pending + 1] = v
            elseif o.emp == cid then mine[#mine + 1] = v
            else others[#others + 1] = v end
        end
    end
    local byId = function(a, b) return a.id < b.id end
    table.sort(pending, byId) table.sort(mine, byId) table.sort(others, byId)
    local history = MySQL.query.await([[SELECT `id`, `num`, `lines`, `total`, `status`, `customer_name`, `employee_name`, `cancel_reason`,
        UNIX_TIMESTAMP(`created_at`) AS t, UNIX_TIMESTAMP(`delivered_at`) AS dt FROM `rs_orders`
        WHERE `shop_id` = ? AND `status` IN ('delivered', 'cancelled') ORDER BY `id` DESC LIMIT ?]], { D.id, O.historyLimit }) or {}
    for _, r in ipairs(history) do
        local lines = {}
        for _, l in ipairs(P.Decode(r.lines, {})) do lines[#lines + 1] = { label = l.label, qty = l.qty } end
        r.lines, r.num, r.statusLabel = lines, ('#%03d'):format(tonumber(r.num) or 0), P.StatusLabel[r.status] or r.status
    end
    return { pending = pending, mine = mine, others = others, history = history, duty = P.OnDuty(src), shop = D.name,
        can = { take = P.Can(src, 'orders'), cook = P.Can(src, 'cook'), deliver = P.Can(src, 'deliver'), manage = P.Can(src, 'orders_manage') },
        maxPerEmployee = O.maxPerEmployee, taken = P.MyTaken(cid) }
end }

-- Prise en charge : vérification et attribution sans aucune attente entre les deux
-- (le serveur traite une requête à la fois : deux employés ne peuvent pas prendre la même)
P.Actions.orderTake = { perm = 'orders', duty = true, fn = function(src, d, D)
    local o = ShopOrder(D, d.id)
    if not o then return { error = 'Commande introuvable.' } end
    local cid = P.Cid(src)
    if o.status ~= 'pending' then
        return { error = o.emp == cid and 'Vous avez déjà cette commande.' or ('Commande déjà prise en charge par %s.'):format(o.empName or 'un collègue'), refresh = true }
    end
    if P.MyTaken(cid) >= O.maxPerEmployee then return { error = ('Vous avez déjà %d commande(s) en cours.'):format(O.maxPerEmployee) } end
    o.status, o.emp, o.empName, o.taken = 'preparing', cid, P.Name(src), os.time()
    P.SaveOrder(o, ', `taken_at` = NOW()')
    P.NotifyCid(o.cid, ('Votre commande %s chez %s est en préparation.'):format(P.Num(o), D.name), 'inform')
    P.PushOrders()
    return { ok = true, message = ('Commande %s prise en charge : préparez-la aux stations.'):format(P.Num(o)), order = P.OrderView(o, cid) }
end }

-- Rendre une commande (elle repasse « En attente », la préparation déjà faite est gardée)
P.Actions.orderRelease = { perm = 'orders', fn = function(src, d, D)
    local o = ShopOrder(D, d.id)
    if not o then return { error = 'Commande introuvable.' } end
    local cid = P.Cid(src)
    if o.emp ~= cid and not P.Can(src, 'orders_manage') then return { error = 'Ce n\'est pas votre commande.' } end
    if o.status ~= 'preparing' then return { error = o.status == 'ready' and 'Commande terminée : le sac est déjà prêt, remettez-le au client.' or 'Commande non prise en charge.' } end
    P.CancelCook(o.id)
    o.status, o.emp, o.empName, o.taken = 'pending', nil, nil, nil
    P.SaveOrder(o)
    P.PushOrders()
    P.NotifyStaff(D, ('Commande %s remise en attente.'):format(P.Num(o)))
    return { ok = true, message = ('Commande %s remise en attente.'):format(P.Num(o)) }
end }

-- Annuler + rembourser (permission « orders_manage », ou staff)
function P.CancelOrder(D, o, reason, actorSrc)
    if o.status == 'delivered' or o.status == 'cancelled' then return false, 'Commande déjà terminée.' end
    if o.status == 'ready' and o.bagGiven ~= false and o.bag then
        -- Le sac doit disparaître : on le reprend à l'employé qui l'a (connecté)
        local holder = o.emp and core:GetSourceByCitizenId(o.emp)
        local ok = holder and exports.elyzea_inventory:RemoveItem(holder, Config.Bag.item, 1, { uid = o.bag })
        if not ok then return false, 'Le sac de cette commande doit d\'abord être récupéré (l\'employé qui l\'a n\'est pas connecté ou ne l\'a plus).' end
    end
    local label = ('Remboursement commande %s · %s'):format(P.Num(o), D.name)
    if o.total > 0 then
        if not P.SocietyRemove(D, o.total, label) then return false, ('Fonds insuffisants pour rembourser (%d $).'):format(o.total) end
        P.Refund(o.cid, o.total, o.method, label)
        P.Tx(D, { type = 'out', category = 'refund', amount = o.total, reason = label, actorCid = actorSrc and P.Cid(actorSrc) or nil,
            actorName = actorSrc and P.Name(actorSrc) or 'Système', targetCid = o.cid, targetName = o.cname, ref = tostring(o.id) })
    end
    P.CancelCook(o.id)
    o.status = 'cancelled'
    P.orders[o.id] = nil
    P.SaveOrder(o, ', `cancel_reason` = ?', { P.Clean(reason or 'Annulée', 160) })
    P.NotifyCid(o.cid, ('Votre commande %s chez %s a été annulée : %d $ remboursés.'):format(P.Num(o), D.name, o.total), 'error')
    P.PushOrders()
    return true
end

P.Actions.orderCancel = { perm = 'orders_manage', fn = function(src, d, D)
    local o = ShopOrder(D, d.id)
    if not o then return { error = 'Commande introuvable.' } end
    local ok, why = P.CancelOrder(D, o, P.Clean(d.reason, 160) ~= '' and P.Clean(d.reason, 160) or 'Annulée par le restaurant', src)
    if not ok then return { error = why } end
    P.AddLog(D.id, src, o.cid, o.cname, 'Commande annulée', nil, nil, P.Num(o))
    return { ok = true, message = ('Commande %s annulée et remboursée.'):format(P.Num(o)) }
end }

-- ---------------------------------------------------------------------
-- Commandes jamais prises en charge : annulées et remboursées
-- ---------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(60000)
        if P.ready and (tonumber(O.expireMinutes) or 0) > 0 then
            local limit = os.time() - O.expireMinutes * 60
            local old = {}
            for _, o in pairs(P.orders) do if o.status == 'pending' and o.created < limit then old[#old + 1] = o end end
            for _, o in ipairs(old) do
                local D = P.shops[o.shop]
                if D and P.orders[o.id] then P.CancelOrder(D, o, 'Non prise en charge à temps') end
            end
        end
    end
end)
