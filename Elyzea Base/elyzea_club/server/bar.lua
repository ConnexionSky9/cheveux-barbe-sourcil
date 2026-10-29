-- =====================================================================
--  ELYZEA BOÎTE DE NUIT - serveur : bar (carte, prix, stock, encaissement)
--  · Chaque boîte a SA carte : prix et stock par boisson (objets d'elyzea_inventory).
--  · Le patron (permission « menu ») règle les prix et la carte ; « stock » commande
--    du stock payé par le compte de la boîte.
--  · Servir (permission « bar », en service, près du point Bar) : le serveur choisit
--    le client proche et les boissons ; le client voit la commande et paie (banque ou
--    espèces). Le serveur recalcule tout : prix de la carte, stock, place dans
--    l'inventaire, argent. Paiement → compte de la boîte → boissons → commission.
-- =====================================================================
local P = Club
local core = exports.elyzea_core
local B = Config.Bar

P.Drinks = {}
for i, d in ipairs(Config.Drinks) do d.sort = i P.Drinks[d.item] = d end

P.menu = {}   -- [shopId] = { [item] = { price, stock, enabled } }

local function inv() return exports.elyzea_inventory end

P.OnReady[#P.OnReady + 1] = function()
    P.menu = {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `cl_menu`') or {}) do
        if P.Drinks[r.item] then
            P.menu[r.shop_id] = P.menu[r.shop_id] or {}
            P.menu[r.shop_id][r.item] = { price = tonumber(r.price) or 0, stock = tonumber(r.stock) or 0, enabled = r.enabled == 1 or r.enabled == true }
        end
    end
    -- Boisson ajoutée dans la configuration après coup : ajoutée à chaque boîte (désactivée, stock 0)
    for id, D in pairs(P.shops) do if not D.deleted then P.SeedMenu(D, true) end end
end

-- Carte de départ d'une boîte (ou boissons manquantes)
function P.SeedMenu(D, onlyMissing)
    P.menu[D.id] = P.menu[D.id] or {}
    for _, d in ipairs(Config.Drinks) do
        if not P.menu[D.id][d.item] then
            local stock = onlyMissing and 0 or B.startStock
            local enabled = not onlyMissing
            P.menu[D.id][d.item] = { price = d.price, stock = stock, enabled = enabled }
            MySQL.query.await('INSERT IGNORE INTO `cl_menu` (`shop_id`, `item`, `price`, `stock`, `enabled`) VALUES (?, ?, ?, ?, ?)',
                { D.id, d.item, d.price, stock, enabled and 1 or 0 })
        end
    end
end
local function SaveLine(D, item)
    local m = P.menu[D.id][item]
    MySQL.update.await('UPDATE `cl_menu` SET `price` = ?, `stock` = ?, `enabled` = ? WHERE `shop_id` = ? AND `item` = ?',
        { m.price, m.stock, m.enabled and 1 or 0, D.id, item })
end

-- Carte affichée (l'image vient d'elyzea_inventory)
function P.MenuView(D, publicOnly)
    local list = {}
    for _, d in ipairs(Config.Drinks) do
        local m = (P.menu[D.id] or {})[d.item]
        if m and (not publicOnly or m.enabled) then
            list[#list + 1] = { item = d.item, label = d.label, cat = d.cat, price = m.price, stock = publicOnly and nil or m.stock,
                available = m.enabled and m.stock > 0, enabled = m.enabled, cost = not publicOnly and d.cost or nil }
        end
    end
    return list
end

function P.NearPoint(src, pt, extra)
    local c, v = P.Coords(src), P.Vec(pt)
    return c ~= nil and v ~= nil and #(c - v) <= (tonumber(pt.r) or Config.Points.defaultRadius) + (extra or 3.0)
end

-- ---------------------------------------------------------------------
-- Carte, prix, stock (tablette)
-- ---------------------------------------------------------------------
P.Actions.menu = { perm = 'tablet', fn = function(src, _, D)
    return { list = P.MenuView(D), canEdit = P.Can(src, 'menu'), canStock = P.Can(src, 'stock'), balance = P.Can(src, 'stock') and P.Balance(D) or nil,
        maxPrice = B.maxPrice, maxStock = B.maxStock }
end }

P.Actions.menuSet = { perm = 'menu', fn = function(src, d, D)
    local item = tostring(d.item or '')
    local m = P.Drinks[item] and P.menu[D.id] and P.menu[D.id][item]
    if not m then return { error = 'Boisson inconnue.' } end
    local old = m.price
    if d.price ~= nil then
        local price = P.Int(d.price, 1, B.maxPrice, nil)
        if not price then return { error = ('Prix invalide (1 à %d $).'):format(B.maxPrice) } end
        m.price = price
    end
    if d.enabled ~= nil then m.enabled = d.enabled == true end
    SaveLine(D, item)
    if m.price ~= old then P.AddLog(D.id, src, nil, nil, 'Prix', nil, nil, ('%s : %d $ → %d $'):format(P.Drinks[item].label, old, m.price)) end
    return { ok = true, message = ('%s : %d $%s.'):format(P.Drinks[item].label, m.price, m.enabled and '' or ' (retiré de la carte)') }
end }

P.Actions.stockOrder = { perm = 'stock', fn = function(src, d, D)
    local item = tostring(d.item or '')
    local drink = P.Drinks[item]
    local m = drink and P.menu[D.id] and P.menu[D.id][item]
    if not m then return { error = 'Boisson inconnue.' } end
    local qty = P.Int(d.qty, 1, B.maxStock, nil)
    if not qty then return { error = 'Quantité invalide.' } end
    if m.stock + qty > B.maxStock then return { error = ('Stock maximal : %d (actuel %d).'):format(B.maxStock, m.stock) } end
    local cost = qty * drink.cost
    local why = ('Stock : %d × %s'):format(qty, drink.label)
    if not P.SocietyRemove(D, cost, why) then return { error = ('Fonds insuffisants : il faut %d $ (solde %d $).'):format(cost, P.Balance(D)) } end
    m.stock = m.stock + qty
    SaveLine(D, item)
    P.Tx(D, { type = 'out', category = 'stock', amount = cost, reason = why, actorCid = P.Cid(src), actorName = P.Name(src) })
    return { ok = true, message = ('%d × %s ajoutés au stock (%d $ payés par la boîte).'):format(qty, drink.label, cost) }
end }

-- ---------------------------------------------------------------------
-- Servir un client
-- ---------------------------------------------------------------------
local Orders = {}      -- [client src] = commande en attente
local orderSeq = 0

local function NearbyCustomers(src)
    local c = P.Coords(src)
    if not c then return {} end
    local list = {}
    for id in pairs(core:GetPlayers()) do
        if id ~= src then
            local tc = P.Coords(id)
            local d = tc and #(tc - c) or 9999
            if d <= B.distance then list[#list + 1] = { id = id, name = P.Name(id), distance = math.floor(d * 10) / 10 } end
        end
    end
    table.sort(list, function(a, b) return a.distance < b.distance end)
    return list
end

local function AtBar(src, D)
    local pt = D.points.bar
    return pt and pt.on ~= false and P.NearPoint(src, pt, B.barDistance)
end

P.Actions.barOpen = { perm = 'bar', duty = true, fn = function(src, _, D)
    if not D.points.bar then return { error = 'Le staff n\'a pas encore placé le point Bar de la boîte.' } end
    if not AtBar(src, D) then return { error = 'Allez derrière le bar pour servir.' } end
    local menu = {}
    for _, l in ipairs(P.MenuView(D)) do if l.enabled then menu[#menu + 1] = l end end
    return { customers = NearbyCustomers(src), menu = menu }
end }

-- Lignes validées et total recalculé par le serveur
local function Quote(D, lines)
    if type(lines) ~= 'table' then return nil, 'Commande vide.' end
    local out, total, n = {}, 0, 0
    local seen = {}
    for _, l in ipairs(lines) do
        local item, qty = tostring(l.item or ''), P.Int(l.qty, 1, B.maxQty, nil)
        local m = P.Drinks[item] and (P.menu[D.id] or {})[item]
        if not m or not qty then return nil, 'Ligne de commande invalide.' end
        if seen[item] then return nil, 'Boisson en double dans la commande.' end
        seen[item] = true
        if not m.enabled then return nil, ('%s n\'est plus à la carte.'):format(P.Drinks[item].label) end
        if m.stock < qty then return nil, ('Stock insuffisant : %s (%d restant).'):format(P.Drinks[item].label, m.stock) end
        n = n + 1
        if n > B.maxLines then return nil, ('%d boissons différentes au maximum.'):format(B.maxLines) end
        out[#out + 1] = { item = item, label = P.Drinks[item].label, qty = qty, unit = m.price, total = m.price * qty }
        total = total + m.price * qty
    end
    if n == 0 then return nil, 'Commande vide.' end
    return out, total
end

P.Actions.barSell = { perm = 'bar', duty = true, fn = function(src, d, D)
    if not AtBar(src, D) then return { error = 'Allez derrière le bar pour servir.' } end
    local t = tonumber(d.target)
    if not t or t == src or not P.GetPlayer(t) then return { error = 'Client introuvable.' } end
    if P.Dist(src, t) > B.distance + 1.0 then return { error = 'Le client est trop loin.' } end
    if Orders[t] and Orders[t].expires > os.time() then return { error = 'Ce client a déjà une commande en attente.' } end
    local lines, total = Quote(D, d.lines)
    if not lines then return { error = total } end
    orderSeq = orderSeq + 1
    local o = { id = orderSeq, shop = D.id, seller = src, sellerCid = P.Cid(src), lines = lines, total = total, expires = os.time() + B.timeout }
    Orders[t] = o
    TriggerClientEvent('club:client:barOffer', t, { id = o.id, shop = D.name, seller = P.Name(src), lines = lines, total = total, timeout = B.timeout })
    return { ok = true, message = ('Commande envoyée à %s : %d $.'):format(P.Name(t), total) }
end }

local paying = {}
P.Pub.barAnswer = { fn = function(src, d)
    local o = Orders[src]
    if not o or o.id ~= tonumber(d.id) then return { error = 'Commande introuvable ou expirée.' } end
    Orders[src] = nil
    local D = P.shops[o.shop]
    local seller = o.seller
    if not d.accept then
        if GetPlayerName(seller) then P.Notify(seller, ('%s a refusé la commande.'):format(P.Name(src)), 'error') end
        return { ok = true, message = 'Commande refusée.' }
    end
    if o.expires < os.time() then return { error = 'Commande expirée.' } end
    if paying[src] then return { error = 'Paiement déjà en cours.' } end
    paying[src] = true
    local ok, res = pcall(function()
        if not P.ShopOpen(D) then return { error = 'La boîte est fermée.' } end
        -- Le serveur est toujours employé de CETTE boîte, en service, et près du client
        local sd = GetPlayerName(seller) and P.ShopOf(seller)
        if not sd or sd.id ~= D.id or not P.OnDuty(seller) or not P.Can(seller, 'bar') then return { error = 'Le serveur n\'est plus disponible.' } end
        if P.Dist(src, seller) > B.distance + 2.0 then return { error = 'Le serveur est trop loin.' } end
        local method = d.method == 'cash' and 'cash' or 'bank'
        -- Prix et stock relus au moment du paiement (la carte a pu changer)
        local req = {}
        for _, l in ipairs(o.lines) do req[#req + 1] = { item = l.item, qty = l.qty } end
        local lines, total = Quote(D, req)
        if not lines then return { error = total } end
        if total ~= o.total then return { error = 'Les prix ont changé : demandez une nouvelle commande.' } end
        local carry = {}
        for _, l in ipairs(lines) do carry[#carry + 1] = { l.item, l.qty } end
        local okc, can = pcall(function() return inv():CanCarryItems(src, carry) end)
        if not okc or not can then return { error = 'Pas assez de place dans votre inventaire.' } end
        if not P.ChargeWith(src, total, method, ('Bar %s'):format(D.name)) then
            return { error = method == 'cash' and 'Pas assez d\'espèces.' or 'Solde bancaire insuffisant.' }
        end
        -- Boissons : retirées du stock puis données ; une ligne qui échoue est remboursée et remise en stock
        local refund, given = 0, {}
        for _, l in ipairs(lines) do
            local m = P.menu[D.id][l.item]
            m.stock = m.stock - l.qty
            local okA, added = pcall(function() return inv():AddItem(src, l.item, l.qty) end)
            if okA and added then given[#given + 1] = ('%d × %s'):format(l.qty, l.label)
            else m.stock = m.stock + l.qty refund = refund + l.total end
            SaveLine(D, l.item)
        end
        if refund > 0 then P.Refund(P.Cid(src), refund, method, ('Remboursement bar %s'):format(D.name)) end
        local paid = total - refund
        if paid <= 0 then return { error = 'Les boissons n\'ont pas pu être données : vous êtes remboursé.' } end
        local uid = P.Uid('BAR')
        P.SocietyAdd(D, paid, ('Bar · %s'):format(table.concat(given, ', ')))
        P.Tx(D, { type = 'in', category = 'sale', amount = paid, reason = ('Bar · %s'):format(table.concat(given, ', ')), actorCid = o.sellerCid,
            actorName = P.Name(seller), targetCid = P.Cid(src), targetName = P.Name(src), ref = uid })
        MySQL.insert.await([[INSERT INTO `cl_sales` (`uid`, `shop_id`, `kind`, `lines`, `price`, `method`, `buyer_cid`, `buyer_name`, `seller_cid`, `seller_name`)
            VALUES (?, ?, 'bar', ?, ?, ?, ?, ?, ?, ?)]], { uid, D.id, json.encode(lines), paid, method, P.Cid(src), P.Name(src), o.sellerCid, P.Name(seller) })
        local com = P.Commission(D, o.sellerCid, paid, 'Bar', uid)
        P.Notify(seller, ('Commande payée par %s : %d $%s.'):format(P.Name(src), paid, com > 0 and (' · commission ' .. com .. ' $') or ''), 'success')
        return { ok = true, message = ('Payé %d $ : %s.%s'):format(paid, table.concat(given, ', '), refund > 0 and (' Remboursé ' .. refund .. ' $ (inventaire plein).') or '') }
    end)
    paying[src] = nil
    if not ok then print(('^1[CLUB] Paiement bar : %s^0'):format(tostring(res))) return { error = 'Erreur pendant le paiement.' } end
    if res.error and GetPlayerName(seller) then P.Notify(seller, ('Commande non payée : %s'):format(res.error), 'error') end
    return res
end }
AddEventHandler('playerDropped', function() Orders[source] = nil paying[source] = nil end)

-- Carte publique (consultée au point Bar ou à l'entrée, sans rien acheter)
P.Pub.menuPublic = { fn = function(src, d)
    local D = P.shops[tonumber(d.shop) or 0]
    if not P.ShopOpen(D) then return { error = 'Cette boîte est fermée.' } end
    local near = (D.points.bar and P.NearPoint(src, D.points.bar, 8.0)) or (D.points.door and P.NearPoint(src, D.points.door, 4.0))
    local member = P.ShopOf(src)
    if not near and not (member and member.id == D.id) then return { error = 'Approchez-vous du bar.' } end
    return { shop = D.name, list = P.MenuView(D, true) }
end }

-- Ventes (tablette) : toutes avec « sales_all », sinon les siennes
P.Actions.sales = { perm = 'tablet', fn = function(src, d, D)
    local where, args = { '`shop_id` = ?' }, { D.id }
    if not P.Can(src, 'sales_all') then where[#where + 1] = '`seller_cid` = ?' args[#args + 1] = P.Cid(src) end
    if d.kind == 'bar' or d.kind == 'entry' then where[#where + 1] = '`kind` = ?' args[#args + 1] = d.kind end
    local rows = MySQL.query.await([[SELECT `uid`, `kind`, `lines`, `price`, `method`, `buyer_name`, `seller_name`, UNIX_TIMESTAMP(`created_at`) AS t
        FROM `cl_sales` WHERE ]] .. table.concat(where, ' AND ') .. ' ORDER BY `id` DESC LIMIT 150', args) or {}
    for _, r in ipairs(rows) do r.lines = P.Decode(r.lines, {}) end
    return { list = rows, all = P.Can(src, 'sales_all') }
end }
