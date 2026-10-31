-- =====================================================================
--  ELYZEA RESTAURANT - serveur : carte, ouverture, coffre, données publiques,
--  tableau de bord, fiche, restaurants de la configuration
--  · Chaque restaurant a SA carte : produits proposés (catalogue de config.lua)
--    et prix (permission « menu »).
--  · Ouverture des commandes au public : permission « open ».
-- =====================================================================
local P = Resto
local core = exports.elyzea_core

P.Products, P.Cats = {}, {}
for i, p in ipairs(Config.Products) do p.sort = i P.Products[p.id] = p end
for i, c in ipairs(Config.Categories) do c.sort = i P.Cats[c.id] = c end

P.menu = {}   -- [shopId] = { [productId] = { price, enabled } }

local function Image(p) return p.image or (p.item .. '.png') end

P.OnReady[#P.OnReady + 1] = function()
    P.menu = {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `rs_menu`') or {}) do
        if P.Products[r.product] then
            P.menu[r.shop_id] = P.menu[r.shop_id] or {}
            P.menu[r.shop_id][r.product] = { price = tonumber(r.price) or 0, enabled = r.enabled == 1 or r.enabled == true }
        end
    end
    -- Produit ajouté au catalogue après coup : ajouté à chaque restaurant (retiré de la carte)
    for _, D in pairs(P.shops) do if not D.deleted then P.SeedMenu(D, true) end end
    -- Coffre de chaque restaurant (accès revérifié par elyzea_inventory à chaque ouverture)
    for _, D in pairs(P.shops) do if not D.deleted then P.RegisterStash(D) end end
    pcall(function()
        exports.elyzea_inventory:RegisterStashAccess('resto:', function(src, stashId)
            local D = P.ShopOf(src)
            return D ~= nil and stashId == ('resto:%d'):format(D.id) and P.Can(src, 'stash')
        end)
    end)
end

-- Carte de départ d'un restaurant (only = liste d'ids proposés ; sinon les produits « default »)
function P.SeedMenu(D, onlyMissing, only)
    P.menu[D.id] = P.menu[D.id] or {}
    local want
    if type(only) == 'table' and #only > 0 then want = {} for _, id in ipairs(only) do want[id] = true end end
    for _, p in ipairs(Config.Products) do
        if not P.menu[D.id][p.id] then
            local enabled = not onlyMissing and ((want and want[p.id]) or (not want and p.default == true)) or false
            P.menu[D.id][p.id] = { price = p.price, enabled = enabled }
            MySQL.query.await('INSERT IGNORE INTO `rs_menu` (`shop_id`, `product`, `price`, `enabled`) VALUES (?, ?, ?, ?)',
                { D.id, p.id, p.price, enabled and 1 or 0 })
        end
    end
end

-- Ligne de carte d'un restaurant (nil si produit inconnu ou retiré)
function P.MenuLine(D, productId)
    local p = P.Products[tostring(productId or '')]
    local m = p and (P.menu[D.id] or {})[p.id]
    if not p or not m or not m.enabled then return nil end
    return p, m.price
end

-- Carte affichée (publique : produits proposés seulement)
function P.MenuView(D, publicOnly)
    local list = {}
    for _, p in ipairs(Config.Products) do
        local m = (P.menu[D.id] or {})[p.id]
        if m and (not publicOnly or m.enabled) then
            list[#list + 1] = { id = p.id, item = p.item, label = p.label, desc = p.desc, cat = p.cat, price = m.price, enabled = m.enabled,
                image = Image(p), game = not publicOnly and p.game or nil, difficulty = not publicOnly and p.difficulty or nil,
                station = not publicOnly and p.station or nil }
        end
    end
    return list
end

function P.NearPoint(src, pt, extra)
    local c, v = P.Coords(src), P.Vec(pt)
    return c ~= nil and v ~= nil and #(c - v) <= (tonumber(pt.r) or Config.Points.defaultRadius) + (extra or 3.0)
end

-- Commandes ouvertes au public : restaurant actif + ouvert par la direction + point de commande placé
function P.PublicOpen(D) return P.ShopOpen(D) and P.Opt(D, 'publicOpen', true) == true and D.points.order ~= nil end

function P.RegisterStash(D)
    pcall(function()
        exports.elyzea_inventory:RegisterStash(('resto:%d'):format(D.id), ('Coffre · %s'):format(D.name), Config.Stash.slots, Config.Stash.weight * 1000)
    end)
end

-- ---------------------------------------------------------------------
-- Configuration publique et restaurants visibles
-- ---------------------------------------------------------------------
P.Pub.init = { fn = function()
    local types = {}
    for k, t in pairs(Config.StationTypes) do types[k] = { label = t.label, icon = t.icon } end
    return { perms = RSPerms, statuses = Config.Statuses, keys = Config.Keys, categories = Config.Categories, stationTypes = types,
        games = Config.MiniGames, methods = Config.Orders.methods, limits = { maxQty = Config.Orders.maxQty, maxLines = Config.Orders.maxLines, maxUnits = Config.Orders.maxUnits } }
end }

-- Points publics de chaque restaurant actif
P.Pub.shops = { fn = function()
    local list = {}
    for _, D in pairs(P.shops) do
        if P.ShopOpen(D) then
            local pts = D.points or {}
            local stations = {}
            for i, s in ipairs(pts.stations or {}) do stations[#stations + 1] = { i = i, x = s.x, y = s.y, z = s.z, r = s.r, types = s.types } end
            list[#list + 1] = { id = D.id, name = D.name, address = D.address, logo = P.Opt(D, 'logo', '🍽️'), color = P.Opt(D, 'color', '#f97316'),
                blip = P.Opt(D, 'blip', true), blipSprite = P.Opt(D, 'blipSprite', 93), blipColor = P.Opt(D, 'blipColor', 47), publicOpen = P.PublicOpen(D),
                order = pts.order, stash = pts.stash, manage = pts.manage, stations = stations }
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return { list = list, version = P.version }
end }

-- ---------------------------------------------------------------------
-- Carte et prix (tablette)
-- ---------------------------------------------------------------------
P.Actions.menu = { perm = 'tablet', fn = function(src, _, D)
    return { list = P.MenuView(D), categories = Config.Categories, canEdit = P.Can(src, 'menu'), maxPrice = Config.Orders.maxPrice }
end }

P.Actions.menuSet = { perm = 'menu', fn = function(src, d, D)
    local p = P.Products[tostring(d.id or '')]
    local m = p and (P.menu[D.id] or {})[p.id]
    if not m then return { error = 'Produit introuvable.' } end
    local msg
    if d.price ~= nil then
        local price = P.Int(d.price, 0, Config.Orders.maxPrice, nil)
        if not price then return { error = ('Prix invalide (0 à %d $).'):format(Config.Orders.maxPrice) } end
        m.price = price
        msg = ('%s : %d $.'):format(p.label, price)
    end
    if d.enabled ~= nil then
        m.enabled = d.enabled == true
        msg = m.enabled and ('%s remis à la carte.'):format(p.label) or ('%s retiré de la carte.'):format(p.label)
    end
    MySQL.update.await('UPDATE `rs_menu` SET `price` = ?, `enabled` = ? WHERE `shop_id` = ? AND `product` = ?', { m.price, m.enabled and 1 or 0, D.id, p.id })
    P.AddLog(D.id, src, nil, nil, 'Carte', nil, nil, msg)
    return { ok = true, message = msg }
end }

-- Ouverture des commandes au public
P.Actions.openSet = { perm = 'open', fn = function(src, d, D)
    local on = d.publicOpen == true
    if on and not D.points.order then return { error = 'Le staff n\'a pas encore placé le point de commande.' } end
    D.options.publicOpen = on
    P.SaveShop(D)
    P.AddLog(D.id, src, nil, nil, on and 'Ouverture' or 'Fermeture', nil, nil, nil)
    P.Touch()
    P.PushShop(D.id)
    return { ok = true, message = on and 'Commandes ouvertes au public.' or 'Commandes fermées au public (les commandes en cours continuent).' }
end }

-- Coffre
P.Actions.stash = { perm = 'stash', fn = function(src, _, D)
    if not D.points.stash then return { error = 'Le staff n\'a pas encore placé le coffre du restaurant.' } end
    if not P.NearPoint(src, D.points.stash, 2.0) then return { error = 'Approchez-vous du coffre.' } end
    P.RegisterStash(D)
    local ok, opened = pcall(function() return exports.elyzea_inventory:OpenInventory(src, 'stash', ('resto:%d'):format(D.id)) end)
    if not ok or not opened then return { error = 'Ouverture du coffre impossible.' } end
    return { ok = true }
end }

-- ---------------------------------------------------------------------
-- Tableau de bord
-- ---------------------------------------------------------------------
P.Actions.dashboard = { perm = 'tablet', fn = function(src, _, D)
    local function sum(where)
        local r = MySQL.single.await("SELECT COUNT(*) AS n, COALESCE(SUM(`total`), 0) AS total FROM `rs_orders` WHERE `shop_id` = ? AND `status` <> 'cancelled' AND " .. where, { D.id }) or {}
        return { n = tonumber(r.n) or 0, total = tonumber(r.total) or 0 }
    end
    local stats = { today = sum('DATE(`created_at`) = CURDATE()'), week = sum('`created_at` >= DATE_SUB(NOW(), INTERVAL 7 DAY)') }
    local counts = { pending = 0, preparing = 0, ready = 0 }
    for _, o in pairs(P.orders) do if o.shop == D.id and counts[o.status] then counts[o.status] = counts[o.status] + 1 end end
    local crew = {}
    for _, s in ipairs(P.CrewOnDuty(D.id)) do crew[#crew + 1] = P.CrewInfo(s) end
    table.sort(crew, P.SortCrew)
    local e, g = P.Employee(src), P.Grade(src)
    local last = MySQL.query.await([[SELECT `num`, `lines`, `total`, `status`, `customer_name`, `employee_name`, UNIX_TIMESTAMP(`created_at`) AS t FROM `rs_orders`
        WHERE `shop_id` = ? ORDER BY `id` DESC LIMIT 8]], { D.id }) or {}
    for _, r in ipairs(last) do r.lines = P.Decode(r.lines, {}) end
    return { shop = { name = D.name, address = D.address, logo = P.Opt(D, 'logo', '🍽️') }, publicOpen = P.PublicOpen(D), canOpen = P.Can(src, 'open'),
        hasOrderPoint = D.points.order ~= nil, stats = stats, counts = counts, crew = crew, last = last,
        balance = P.Can(src, 'finance') and P.Balance(D) or nil,
        me = { grade = g and g.name or '?', matricule = e and e.matricule or '', duty = P.OnDuty(src), status = P.status[src] or 'available', times = P.MyTimes(src) } }
end }

-- Fiche du restaurant (lecture) : réglages du staff, points placés
P.Actions.config = { perm = 'tablet', fn = function(_, _, D)
    local pts = D.points or {}
    local stations = {}
    for i, s in ipairs(pts.stations or {}) do
        local labels = {}
        for _, t in ipairs(s.types or {}) do labels[#labels + 1] = (Config.StationTypes[t] or {}).label or t end
        stations[#stations + 1] = { i = i, label = table.concat(labels, ', ') }
    end
    return { shop = { name = D.name, address = D.address, job = D.job, society = D.society, requireDuty = P.Opt(D, 'requireDuty', true), logo = P.Opt(D, 'logo', '🍽️') },
        points = { order = pts.order ~= nil, stash = pts.stash ~= nil, manage = pts.manage ~= nil }, stations = stations }
end }

-- ---------------------------------------------------------------------
-- Restaurants de config.lua (créés une seule fois, jamais écrasés)
-- ---------------------------------------------------------------------
local function CleanPt(p)
    if type(p) ~= 'table' or not tonumber(p.x) or not tonumber(p.y) or not tonumber(p.z) then return nil end
    if tonumber(p.x) == 0 and tonumber(p.y) == 0 then return nil end
    return { x = p.x + 0.0, y = p.y + 0.0, z = p.z + 0.0, h = tonumber(p.h) or 0.0, r = tonumber(p.r) or Config.Points.defaultRadius, on = true }
end
P.OnReady[#P.OnReady + 1] = function()
    for _, c in ipairs(Config.Restaurants or {}) do
        local job = tostring(c.job or ''):lower():gsub('[^%w_]', '')
        if #job >= 3 and not P.ShopByJob(job) then
            local okJob = not core:GetJob(job) or P.GetSetting('ownJobs', {})[job]
            if not okJob then
                print(('^3[RESTO] Config.Restaurants : le métier « %s » existe déjà (autre script) : restaurant ignoré.^0'):format(job))
            else
                local pts = { order = CleanPt((c.points or {}).order), manage = CleanPt((c.points or {}).manage), stash = CleanPt((c.points or {}).stash), stations = {} }
                for _, s in ipairs((c.points or {}).stations or {}) do
                    local p = CleanPt(s)
                    if p then
                        p.types = {}
                        for _, t in ipairs(s.types or {}) do if Config.StationTypes[t] then p.types[#p.types + 1] = t end end
                        if #p.types > 0 then pts.stations[#pts.stations + 1] = p end
                    end
                end
                local opts = { publicOpen = true, requireDuty = true, blip = c.blip ~= false, logo = c.logo or '🍽️', color = c.color or '#f97316' }
                local society = tostring(c.society or job):lower():gsub('[^%w_]', '')
                local name = P.Clean(c.name or job, 80)
                local id = MySQL.insert.await([[INSERT INTO `rs_shops` (`name`, `address`, `job`, `job_label`, `society`, `mat_prefix`, `enabled`, `points`, `options`, `created_by`)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], { name, P.Clean(c.address, 120), job, name, society, P.Clean(c.matPrefix or 'RS-', 8):upper(),
                    (c.enabled ~= false and pts.order) and 1 or 0, json.encode(pts), json.encode(opts), 'config.lua' })
                if id then
                    local D = { id = id, name = name, address = P.Clean(c.address, 120), job = job, jobLabel = name, society = society,
                        matPrefix = P.Clean(c.matPrefix or 'RS-', 8):upper(), enabled = (c.enabled ~= false and pts.order) and true or false, deleted = false, points = pts, options = opts }
                    P.shops[id] = D
                    local own = P.GetSetting('ownJobs', {})
                    own[job] = true
                    P.SetSetting('ownJobs', own)
                    P.SeedGrades(id)
                    P.SyncCoreJob(D)
                    P.SeedMenu(D, false, c.products)
                    P.RegisterStash(D)
                    pcall(function() core:GetSocietyMoney(society) end)
                    print(('^2[RESTO] Restaurant « %s » créé depuis config.lua.^0'):format(name))
                end
            end
        end
    end
end
