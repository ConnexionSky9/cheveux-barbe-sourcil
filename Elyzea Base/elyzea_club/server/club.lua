-- =====================================================================
--  ELYZEA BOÎTE DE NUIT - serveur : données publiques, tableau de bord, fiche
-- =====================================================================
local P = Club

-- Configuration publique du client
P.Pub.init = { fn = function()
    return { perms = CLPerms, statuses = Config.Statuses, keys = Config.Keys, drinks = Config.Drinks, music = { models = Config.Music.models,
        maxSpeakers = Config.Music.maxSpeakers, minRange = Config.Music.minRange, maxRange = Config.Music.maxRange }, wristband = Config.Entry.wristband }
end }

-- Heure du serveur : base de l'heure commune de la musique
P.Pub.time = { fn = function() return { now = os.time() } end }

-- Boîtes visibles en ville : points, blip, ouverture, enceintes (positions publiques : le son vient d'elles)
P.Pub.shops = { fn = function()
    local list = {}
    for _, D in pairs(P.shops) do
        if P.ShopOpen(D) then
            local pts = D.points or {}
            list[#list + 1] = { id = D.id, name = D.name, address = D.address, blip = P.Opt(D, 'blip', true), blipSprite = P.Opt(D, 'blipSprite', 614),
                blipColor = P.Opt(D, 'blipColor', 27), publicOpen = P.PublicOpen(D), fee = P.EntryFee(D),
                door = pts.door, inside = pts.inside, bar = pts.bar, stash = pts.stash, manage = pts.manage, speakers = P.SpeakerList(D.id) }
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return { list = list, version = P.version }
end }

-- ---------------------------------------------------------------------
-- Tableau de bord
-- ---------------------------------------------------------------------
P.Actions.dashboard = { perm = 'tablet', fn = function(src, _, D)
    local function sum(where, args)
        local r = MySQL.single.await('SELECT COUNT(*) AS n, COALESCE(SUM(`price`), 0) AS total FROM `cl_sales` WHERE `shop_id` = ? AND ' .. where, args) or {}
        return { n = tonumber(r.n) or 0, total = tonumber(r.total) or 0 }
    end
    local today = 'DATE(`created_at`) = CURDATE()'
    local week = '`created_at` >= DATE_SUB(NOW(), INTERVAL 7 DAY)'
    local stats = {
        barToday = sum("`kind` = 'bar' AND " .. today, { D.id }), barWeek = sum("`kind` = 'bar' AND " .. week, { D.id }),
        entryToday = sum("`kind` = 'entry' AND " .. today, { D.id }), entryWeek = sum("`kind` = 'entry' AND " .. week, { D.id }),
    }
    local crew = {}
    for _, s in ipairs(P.CrewOnDuty(D.id)) do crew[#crew + 1] = P.CrewInfo(s) end
    table.sort(crew, P.SortCrew)
    local lowStock = {}
    for _, l in ipairs(P.MenuView(D)) do if l.enabled and l.stock <= 5 then lowStock[#lowStock + 1] = { label = l.label, stock = l.stock } end end
    local bands = 0
    for _, t in pairs(P.bands[D.id] or {}) do if t > os.time() then bands = bands + 1 end end
    local m = GlobalState.clubMusic and GlobalState.clubMusic[tostring(D.id)]
    local e, g = P.Employee(src), P.Grade(src)
    local last = MySQL.query.await([[SELECT `kind`, `lines`, `price`, `buyer_name`, `seller_name`, UNIX_TIMESTAMP(`created_at`) AS t FROM `cl_sales`
        WHERE `shop_id` = ? ORDER BY `id` DESC LIMIT 8]], { D.id }) or {}
    for _, r in ipairs(last) do r.lines = P.Decode(r.lines, {}) end
    return { shop = { name = D.name, address = D.address }, publicOpen = P.PublicOpen(D), fee = P.EntryFee(D), stats = stats, crew = crew, lowStock = lowStock,
        bands = bands, music = m and { title = m.title, paused = m.paused } or nil, speakers = P.SpeakerCount(D.id), last = last,
        balance = P.Can(src, 'finance') and P.Balance(D) or nil,
        me = { grade = g and g.name or '?', matricule = e and e.matricule or '', duty = P.OnDuty(src), status = P.status[src] or 'available', times = P.MyTimes(src) } }
end }

-- Fiche de la boîte (lecture) : réglages du staff, points placés
P.Actions.config = { perm = 'tablet', fn = function(_, _, D)
    local pts = D.points or {}
    return { shop = { name = D.name, address = D.address, job = D.job, society = D.society, requireDuty = P.Opt(D, 'requireDuty', true) },
        points = { door = pts.door ~= nil, inside = pts.inside ~= nil, bar = pts.bar ~= nil, stash = pts.stash ~= nil, manage = pts.manage ~= nil },
        speakers = P.SpeakerCount(D.id), maxSpeakers = Config.Music.maxSpeakers }
end }

-- Quitter la boîte (démission) : déjà géré par direction.lua (« resign »)
