-- =====================================================================
--  elyzea_entreprises - serveur : borne de commande (Burger Shot)
--  1. Le client commande à la borne et paie : l'argent est mis de côté.
--  2. La commande arrive chez les employés en service (permission « orders »).
--  3. Un employé la prépare au « Plan de travail », devant le client.
--  4. Préparée : l'argent va à l'entreprise (et la part de l'employé),
--     la commande est remise au client (proche) ou l'attend au comptoir.
--  Non préparée à temps ou annulée : le client est remboursé, même
--  s'il s'est déconnecté (à sa prochaine connexion).
-- =====================================================================
local E = ENT
local core = exports.elyzea_core
local inv = exports.elyzea_inventory

local Orders = {}     -- [id] = { id, company, cid, name, lines, total, method, status, created, employee, employeeName }
local Working = {}    -- [src] = { id, token, readyAt, used, props, step }
local lastOrder = {}  -- [src] = os.time() (anti-spam)
local ready = false

local function K(c) return E.S[c] and E.S[c].kiosk end
local function HasKiosk(c) return E.S[c] ~= nil and Config.Companies[c].features.kiosk == true and K(c) ~= nil end
local function Number(o) return ('%03d'):format(o.id % 1000) end
local function Cid(src) local p = E.Player(src) return p and p.PlayerData.citizenid end
local function SrcOf(cid)
    if not cid then return nil end
    for src, p in pairs(core:GetPlayers()) do if p.PlayerData.citizenid == cid then return src end end
end
local function Count(src, item)
    local ok, n = pcall(function() return inv:GetItemCount(src, item) end)
    return ok and tonumber(n) or 0
end
local function Product(c, id)
    for _, p in ipairs(K(c).products or {}) do if p.id == id then return p end end
end
local function HasZone(c, ztype)
    for _, z in ipairs(E.S[c].zones or {}) do if z.enabled ~= false and z.type == ztype then return true end end
    return false
end

-- Employés en service qui peuvent préparer les commandes
local function Cooks(c)
    local list = {}
    local _, duty = E.Employees(c)
    for _, id in ipairs(duty) do if E.GradePerms(c, E.Grade(id)).orders then list[#list + 1] = id end end
    return list
end

local function PublicOrder(o)
    return { id = o.id, number = Number(o), name = o.name, lines = o.lines, total = o.total, method = o.method, status = o.status,
        employee = o.employeeName, created = o.created, age = os.time() - o.created }
end

local function Active(c)
    local list = {}
    for _, o in pairs(Orders) do if o.company == c then list[#list + 1] = PublicOrder(o) end end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

local function Mine(cid)
    local list = {}
    for _, o in pairs(Orders) do if o.cid == cid then list[#list + 1] = PublicOrder(o) end end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

function E.PushOrders(c)
    local list = Active(c)
    for _, id in ipairs(Cooks(c)) do TriggerClientEvent('ent:orders', id, list) end
end

local function PushMine(cid)
    local src = SrcOf(cid)
    if src then TriggerClientEvent('ent:myOrders', src, Mine(cid)) end
end

local function SetStatus(o, status)
    o.status = status
    MySQL.update('UPDATE elyzea_entreprises_orders SET status = ?, employee = ? WHERE id = ?', { status, o.employeeName, o.id })
end

local function Close(o, status)
    Orders[o.id] = nil
    SetStatus(o, status)
end

-- Rembourse le client (tout de suite s'il est connecté, sinon à sa prochaine connexion)
local function Refund(o, reason)
    local src = SrcOf(o.cid)
    if src then
        core:AddMoney(src, o.method, o.total, 'remboursement-commande')
        E.Notify(src, ('Commande n°%s remboursée (%d $) : %s.'):format(Number(o), o.total, reason), 'inform')
        Close(o, 'refunded')
        TriggerClientEvent('ent:orderWatchEnd', src, false)
    else
        Close(o, 'refund')
    end
    PushMine(o.cid)
    E.PushOrders(o.company)
    E.Log(nil, o.company, 'Commande remboursée', ('n°%s · %d $ · %s'):format(Number(o), o.total, reason))
end

-- Remet une commande prête au client (inventaire vérifié avant)
local function Give(o, src)
    for _, l in ipairs(o.lines) do
        local ok, can = pcall(function() return inv:CanCarryItem(src, l.item, l.qty) end)
        if ok and can == false then
            E.Notify(src, ('Commande n°%s : ton inventaire est plein. Fais de la place puis récupère-la au comptoir.'):format(Number(o)), 'error')
            return false
        end
    end
    for _, l in ipairs(o.lines) do pcall(function() inv:AddItem(src, l.item, l.qty) end) end
    Close(o, 'done')
    E.Notify(src, ('Commande n°%s récupérée. Bon appétit !'):format(Number(o)), 'success')
    PushMine(o.cid)
    E.PushOrders(o.company)
    return true
end

local function DeleteProps(list)
    for _, net in ipairs(list or {}) do
        local ent = NetworkGetEntityFromNetworkId(net)
        if ent and ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) end
    end
end

-- ---------------------------------------------------------------------
-- Borne : ouverture et commande (clients)
-- ---------------------------------------------------------------------
RegisterNetEvent('ent:kioskOpen', function(c)
    local src = source
    c = tostring(c or '')
    if not ready or not HasKiosk(c) then return end
    if not E.InZone(c, E.Coords(src), { borne = true }, 2.0) then return end
    local s, k = E.S[c], K(c)
    local products = {}
    for _, p in ipairs(k.products or {}) do
        if p.enabled ~= false then
            products[#products + 1] = { id = p.id, category = p.category, label = p.label, description = p.description, price = p.price,
                item = p.item, layers = p.layers, visual = p.visual, color = p.color }
        end
    end
    TriggerClientEvent('ent:kioskData', src, {
        company = c, label = s.job.label, color = Config.Companies[c].color, open = s.enabled and k.enabled ~= false,
        categories = k.categories, products = products, payment = k.payment or 'both', maxItems = k.maxItems or 10,
        staff = #Cooks(c), requireStaff = k.requireStaff ~= false, mine = Mine(Cid(src)), orderTimeout = k.orderTimeout or 15,
    })
end)

RegisterNetEvent('ent:kioskOrder', function(c, cart, method)
    local src = source
    c = tostring(c or '')
    if not ready or not HasKiosk(c) then return end
    local now = os.time()
    if lastOrder[src] and now - lastOrder[src] < 3 then return end
    lastOrder[src] = now
    local s, k = E.S[c], K(c)
    local cid = Cid(src)
    if not cid then return end
    if not E.InZone(c, E.Coords(src), { borne = true }, 2.0) then return end
    if not s.enabled or k.enabled == false then return E.Notify(src, 'La borne est fermée.', 'error') end
    if k.requireStaff ~= false and #Cooks(c) == 0 then return E.Notify(src, 'Aucun employé en service : commande impossible pour le moment.', 'error') end
    if #Mine(cid) >= (k.maxActive or 2) then return E.Notify(src, ('Tu as déjà %d commande(s) en cours.'):format(#Mine(cid)), 'error') end

    local lines, count, total = {}, 0, 0
    local maxItems = math.floor(k.maxItems or 10)
    for _, row in ipairs(type(cart) == 'table' and cart or {}) do
        local p = type(row) == 'table' and Product(c, tostring(row.id or '')) or nil
        local qty = math.floor(tonumber(type(row) == 'table' and row.qty or 0) or 0)
        if p and p.enabled ~= false and qty >= 1 and qty <= maxItems then
            lines[#lines + 1] = { pid = p.id, label = p.label, item = p.item, qty = qty, price = math.floor(p.price or 0), category = p.category }
            count = count + qty
            total = total + qty * math.floor(p.price or 0)
        end
    end
    if #lines == 0 then return E.Notify(src, 'Ta commande est vide.', 'error') end
    if count > maxItems then return E.Notify(src, ('%d articles maximum par commande.'):format(maxItems), 'error') end

    local allowed = k.payment or 'both'
    method = method == 'cash' and 'cash' or 'bank'
    if allowed ~= 'both' then method = allowed end
    if total > 0 and not core:RemoveMoney(src, method, total, 'commande-' .. c) then
        return E.Notify(src, ('Pas assez d\'argent (%s) : %d $.'):format(method == 'cash' and 'liquide' or 'banque', total), 'error')
    end
    local name = E.Name(src)
    local id = MySQL.insert.await('INSERT INTO elyzea_entreprises_orders (company, cid, name, items, total, method, status, created) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { c, cid, name, json.encode(lines), total, method, 'pending', now })
    if not id then
        if total > 0 then core:AddMoney(src, method, total, 'commande-annulee') end
        return E.Notify(src, 'La borne ne répond pas, réessaie.', 'error')
    end
    local o = { id = id, company = c, cid = cid, name = name, lines = lines, total = total, method = method, status = 'pending', created = now }
    Orders[id] = o
    TriggerClientEvent('ent:kioskOrdered', src, { number = Number(o), total = total, mine = Mine(cid) })
    if k.announce ~= false then
        for _, emp in ipairs(Cooks(c)) do TriggerClientEvent('ent:newOrder', emp, { number = Number(o), count = count, name = name }) end
    end
    E.PushOrders(c)
    E.Log(src, c, 'Commande à la borne', ('n°%s · %d article(s) · %d $'):format(Number(o), count, total))
end)

RegisterNetEvent('ent:kioskCancel', function(id)
    local src = source
    local o = Orders[tonumber(id) or -1]
    if not o or o.cid ~= Cid(src) then return end
    if o.status ~= 'pending' then return E.Notify(src, 'Ta commande est déjà en préparation.', 'error') end
    Refund(o, 'annulée à ta demande')
end)

-- Récupérer une commande prête au comptoir / plan de travail
RegisterNetEvent('ent:orderPickup', function(c)
    local src = source
    c = tostring(c or '')
    if not HasKiosk(c) then return end
    if not E.InZone(c, E.Coords(src), { comptoir = true, assemblage = true, borne = true }, 2.5) then return end
    local cid, any = Cid(src), false
    for _, o in pairs(Orders) do
        if o.cid == cid and o.company == c and o.status == 'ready' then any = true Give(o, src) end
    end
    if not any then E.Notify(src, 'Aucune commande prête à ton nom.', 'inform') end
end)

-- ---------------------------------------------------------------------
-- Employés : file des commandes, préparation, annulation
-- ---------------------------------------------------------------------
RegisterNetEvent('ent:ordersData', function()
    local src = source
    local ok, _, c = E.Can(src, 'orders')
    if ok and HasKiosk(c) then TriggerClientEvent('ent:orders', src, Active(c)) end
end)

RegisterNetEvent('ent:orderStart', function(id)
    local src = source
    local ok, c = E.CanOrNotify(src, 'orders')
    if not ok or not HasKiosk(c) then return end
    local o = Orders[tonumber(id) or -1]
    if not o or o.company ~= c then return end
    if o.status ~= 'pending' then return E.Notify(src, 'Cette commande est déjà prise en charge.', 'error') end
    if Working[src] then return E.Notify(src, 'Tu prépares déjà une commande.', 'error') end
    local here = E.Coords(src)
    local zone = E.InZone(c, here, { assemblage = true }, 2.5)
    if not zone then
        if HasZone(c, 'assemblage') then return E.Notify(src, 'Va au plan de travail pour préparer la commande devant le client.', 'error') end
        zone = E.InZone(c, here, { comptoir = true, cuisine = true }, 2.5)
        if not zone then return E.Notify(src, 'Va au comptoir pour préparer la commande.', 'error') end
    end
    local k = K(c)
    local need = {}
    if k.useIngredients ~= false then
        for _, l in ipairs(o.lines) do
            local p = Product(c, l.pid)
            for _, x in ipairs(p and p.ingredients or {}) do need[x.item] = (need[x.item] or 0) + x.count * l.qty end
        end
        local missing = {}
        for item, n in pairs(need) do
            local have = Count(src, item)
            if have < n then missing[#missing + 1] = ('%d × %s'):format(n - have, E.ItemLabel(item)) end
        end
        if #missing > 0 then return E.Notify(src, 'Il te manque : ' .. table.concat(missing, ', ') .. '.', 'error') end
        for item, n in pairs(need) do pcall(function() inv:RemoveItem(src, item, n) end) end
    end
    local steps, total = {}, 0
    for _, l in ipairs(o.lines) do
        local p = Product(c, l.pid) or {}
        for _ = 1, l.qty do
            steps[#steps + 1] = { label = l.label, item = l.item, category = p.category or l.category or 'burger', time = p.time or 5,
                layers = p.layers, visual = p.visual, color = p.color, prop = p.prop }
            total = total + (p.time or 5)
        end
    end
    local token = math.random(100000, 999999)
    Working[src] = { id = o.id, token = token, readyAt = os.time() + math.floor(total * 0.8) - 1, used = need, props = {}, step = 0 }
    o.employee, o.employeeName = src, E.Name(src)
    SetStatus(o, 'preparing')
    TriggerClientEvent('ent:orderAssemble', src, { id = o.id, token = token, number = Number(o), name = o.name, steps = steps,
        zone = { x = zone.x, y = zone.y, z = zone.z, h = zone.h or 0.0 } })
    local cs = SrcOf(o.cid)
    if cs then
        E.Notify(cs, ('Commande n°%s : %s la prépare.'):format(Number(o), o.employeeName), 'success')
        if #(E.Coords(cs) - vector3(zone.x, zone.y, zone.z)) < 40.0 then
            TriggerClientEvent('ent:orderWatch', cs, { number = Number(o), employee = o.employeeName, steps = steps })
        end
    end
    PushMine(o.cid)
    E.PushOrders(c)
end)

-- Avancement (affiché en direct au client)
RegisterNetEvent('ent:orderStep', function(id, token, index)
    local src = source
    local w = Working[src]
    index = math.floor(tonumber(index) or 0)
    if not w or w.id ~= id or w.token ~= token or index <= w.step then return end
    w.step = index
    local o = Orders[id]
    local cs = o and SrcOf(o.cid)
    if cs then TriggerClientEvent('ent:orderWatchStep', cs, index) end
end)

-- Objets posés sur le plateau (supprimés par le serveur si l'employé part)
RegisterNetEvent('ent:orderProps', function(id, token, nets)
    local src = source
    local w = Working[src]
    if not w or w.id ~= id or w.token ~= token or type(nets) ~= 'table' then return end
    for _, n in ipairs(nets) do if #w.props < 40 and tonumber(n) then w.props[#w.props + 1] = math.floor(tonumber(n)) end end
end)

local function ReleaseOrder(o)
    o.employee, o.employeeName = nil, nil
    SetStatus(o, 'pending')
    local cs = SrcOf(o.cid)
    if cs then TriggerClientEvent('ent:orderWatchEnd', cs, false) end
    PushMine(o.cid)
    E.PushOrders(o.company)
end

RegisterNetEvent('ent:orderDone', function(id, token, success)
    local src = source
    local w = Working[src]
    if not w or w.id ~= id or w.token ~= token then return end
    Working[src] = nil
    local props = w.props
    SetTimeout(6000, function() DeleteProps(props) end)
    local o = Orders[id]
    if not o then return end
    if success ~= true then
        for item, n in pairs(w.used or {}) do pcall(function() inv:AddItem(src, item, n) end) end
        E.Notify(src, 'Préparation annulée : la commande retourne dans la file (ingrédients rendus).', 'inform')
        return ReleaseOrder(o)
    end
    if os.time() < w.readyAt then return ReleaseOrder(o) end

    local c, k = o.company, K(o.company)
    local share = math.floor(o.total * math.max(0, math.min(100, k.employeeShare or 0)) / 100)
    if share > 0 then core:AddMoney(src, 'bank', share, 'commande-borne') end
    if o.total - share > 0 then core:AddSocietyMoney(E.S[c].job.name, o.total - share, ('Commande borne n°%s'):format(Number(o))) end
    local emp = E.Player(src)
    local label = {}
    for _, l in ipairs(o.lines) do label[#label + 1] = ('%d × %s'):format(l.qty, l.label) end
    MySQL.insert('INSERT INTO elyzea_entreprises_invoices (company, employee, employee_cid, client, client_cid, label, amount) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { c, E.Name(src), emp and emp.PlayerData.citizenid or nil, o.name, o.cid, ('Borne n°%s : %s'):format(Number(o), table.concat(label, ', ')):sub(1, 255), o.total })
    SetStatus(o, 'ready')
    E.Log(src, c, 'Commande préparée', ('n°%s · %d $%s'):format(Number(o), o.total, share > 0 and (' · part employé %d $'):format(share) or ''))

    local cs = SrcOf(o.cid)
    if cs then TriggerClientEvent('ent:orderWatchEnd', cs, true) end
    if cs and #(E.Coords(cs) - E.Coords(src)) <= (k.deliverDistance or 6) + 0.0 and Give(o, cs) then
        E.Notify(src, ('Commande n°%s remise à %s.%s'):format(Number(o), o.name, share > 0 and (' Ta part : %d $.'):format(share) or ''), 'success')
        TriggerClientEvent('ent:orderHandOver', src)
    else
        E.Notify(src, ('Commande n°%s prête : le client la récupère au comptoir.'):format(Number(o)), 'success')
        if cs then E.Notify(cs, ('Ta commande n°%s est prête ! Récupère-la au comptoir (touche E).'):format(Number(o)), 'success') end
        PushMine(o.cid)
        E.PushOrders(c)
    end
end)

RegisterNetEvent('ent:orderCancel', function(id)
    local src = source
    local ok, c = E.CanOrNotify(src, 'orders')
    if not ok then return end
    local o = Orders[tonumber(id) or -1]
    if not o or o.company ~= c then return end
    if o.status ~= 'pending' then return E.Notify(src, 'Seule une commande en attente peut être annulée.', 'error') end
    Refund(o, ('annulée par %s'):format(E.Name(src)))
    E.Notify(src, ('Commande n°%s annulée et remboursée.'):format(Number(o)), 'inform')
end)

-- ---------------------------------------------------------------------
-- Pour le menu admin
-- ---------------------------------------------------------------------
function E.KioskActive(c) return Active(c) end
function E.KioskAdminCancel(id, by)
    local o = Orders[tonumber(id) or -1]
    if not o then error('Commande introuvable.') end
    if o.status == 'preparing' and o.employee and Working[o.employee] and Working[o.employee].id == o.id then
        TriggerClientEvent('ent:orderAbort', o.employee)
        DeleteProps(Working[o.employee].props)
        Working[o.employee] = nil
    end
    Refund(o, ('annulée par le staff (%s)'):format(by or 'staff'))
    return ('Commande n°%s annulée et remboursée.'):format(Number(o))
end
function E.KioskStats(c)
    return MySQL.single.await([[SELECT COUNT(*) AS n, COALESCE(SUM(total), 0) AS total FROM elyzea_entreprises_orders
        WHERE company = ? AND status IN ('done', 'ready') AND created >= ?]], { c, os.time() - 86400 }) or {}
end

-- ---------------------------------------------------------------------
-- Expiration, déconnexions, remboursements en attente
-- ---------------------------------------------------------------------
local function LoadOrders()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `elyzea_entreprises_orders` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `company` VARCHAR(40) NOT NULL, `cid` VARCHAR(50) NOT NULL,
        `name` VARCHAR(100) NOT NULL, `items` LONGTEXT NOT NULL, `total` INT NOT NULL, `method` VARCHAR(10) NOT NULL,
        `status` VARCHAR(20) NOT NULL, `employee` VARCHAR(100) NULL, `created` INT NOT NULL,
        INDEX (`company`), INDEX (`cid`), INDEX (`status`))]])
    for _, r in ipairs(MySQL.query.await("SELECT * FROM elyzea_entreprises_orders WHERE status IN ('pending', 'preparing', 'ready')") or {}) do
        if E.S[r.company] then
            local o = { id = r.id, company = r.company, cid = r.cid, name = r.name, lines = json.decode(r.items or '[]') or {}, total = r.total,
                method = r.method, status = r.status == 'preparing' and 'pending' or r.status, created = r.created }
            Orders[o.id] = o
            if r.status == 'preparing' then SetStatus(o, 'pending') end
        end
    end
end

CreateThread(function()
    local ok, err = pcall(LoadOrders)
    if not ok then
        print(('^1[elyzea_entreprises] Borne de commande désactivée : base de données indisponible (%s).^0'):format(tostring(err):gsub('^.-:%d+: ', '')))
        return
    end
    ready = true
    while true do
        Wait(30000)
        local now = os.time()
        for _, o in pairs(Orders) do
            local k = K(o.company)
            if o.status == 'pending' and k and now - o.created > math.max(1, k.orderTimeout or 15) * 60 then
                Refund(o, 'elle n\'a pas été préparée à temps')
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastOrder[src] = nil
    local w = Working[src]
    if not w then return end
    Working[src] = nil
    DeleteProps(w.props)
    local o = Orders[w.id]
    if o then ReleaseOrder(o) end
end)

AddEventHandler('elyzea:server:playerLoaded', function(src)
    local cid = Cid(src)
    if not cid then return end
    SetTimeout(5000, function()
        for _, r in ipairs(MySQL.query.await("SELECT id, company, total, method FROM elyzea_entreprises_orders WHERE cid = ? AND status = 'refund'", { cid }) or {}) do
            if MySQL.update.await("UPDATE elyzea_entreprises_orders SET status = 'refunded' WHERE id = ? AND status = 'refund'", { r.id }) == 1 then
                core:AddMoney(src, r.method, r.total, 'remboursement-commande')
                E.Notify(src, ('Commande n°%03d remboursée : %d $.'):format(r.id % 1000, r.total), 'inform')
            end
        end
        local mine = Mine(cid)
        if #mine > 0 then
            TriggerClientEvent('ent:myOrders', src, mine)
            for _, o in ipairs(mine) do
                if o.status == 'ready' then E.Notify(src, ('Ta commande n°%s t\'attend au comptoir.'):format(o.number), 'inform') end
            end
        end
    end)
end)
