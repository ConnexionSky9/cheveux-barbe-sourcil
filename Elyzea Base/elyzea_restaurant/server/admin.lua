-- =====================================================================
--  ELYZEA RESTAURANT - serveur : administration (staff)
--  Accès : permissions staff d'admin_menu, vérifiées à chaque requête :
--  « resto_manage » = tout ; sinon une case par action (champ staff = …, voir P.StaffPerms dans main.lua).
--  · Créer plusieurs restaurants (chacune : métier, compte de société, grades, matricules).
--  · Points : commande (comptoir, obligatoire), coffre, bureau (tablette),
--    stations de cuisine (une ou plusieurs, chacune avec ses types).
--  · Logo, couleur, blip ; nommer le patron, activer / désactiver, supprimer
--    (désactivation : finances et historiques gardés) ; commandes (annuler).
-- =====================================================================
local P = Resto
local core = exports.elyzea_core

local function Log(src, action, details)
    if GetResourceState('admin_menu') == 'started' and type(src) == 'number' then
        pcall(function() exports.admin_menu:AddLog(src, '[Restaurant] ' .. action, details or '') end)
    else
        print(('^5[RESTO]^7 %s | %s'):format(action, details or ''))
    end
end

local function StaffPos(src)
    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    local r2 = function(v) return math.floor(v * 100 + 0.5) / 100 end
    return { x = r2(c.x), y = r2(c.y), z = r2(c.z), h = r2(GetEntityHeading(ped)) }
end

local function ShopView(D)
    local emp = 0
    for _ in pairs(P.ShopEmployees(D.id)) do emp = emp + 1 end
    local active = 0
    for _, o in pairs(P.orders) do if o.shop == D.id then active = active + 1 end end
    return { id = D.id, name = D.name, address = D.address, job = D.job, jobLabel = D.jobLabel, society = D.society, matPrefix = D.matPrefix,
        enabled = D.enabled, deleted = D.deleted, options = D.options, points = D.points, employees = emp, balance = P.Balance(D),
        publicOpen = P.PublicOpen(D), activeOrders = active }
end

P.Admin.data = { fn = function()
    local shops = {}
    for _, D in pairs(P.shops) do if not D.deleted then shops[#shops + 1] = ShopView(D) end end
    table.sort(shops, function(a, c) return a.id < c.id end)
    local grades = {}
    for _, D in pairs(P.shops) do
        local list = {}
        for _, g in ipairs(P.SortedGrades(D.id)) do list[#list + 1] = { id = g.id, name = g.name, level = g.level } end
        grades[tostring(D.id)] = list
    end
    local types = {}
    for k, t in pairs(Config.StationTypes) do types[#types + 1] = { id = k, label = t.label, icon = t.icon } end
    table.sort(types, function(a, c) return a.label < c.label end)
    return { shops = shops, grades = grades, stationTypes = types }
end }

-- ---------------------------------------------------------------------
-- Restaurants
-- ---------------------------------------------------------------------
local function ValidJob(job, exceptId)
    job = tostring(job or ''):lower():gsub('[^%w_]', ''):sub(1, 40)
    if #job < 3 then return nil, 'Nom de métier invalide (3 à 40 caractères : lettres, chiffres, _).' end
    for _, D in pairs(P.shops) do if D.id ~= exceptId and D.job == job and not D.deleted then return nil, ('Le métier « %s » est déjà utilisé par « %s ».'):format(job, D.name) end end
    if job == 'unemployed' then return nil, 'Nom de métier réservé.' end
    local existing = core:GetJob(job)
    if existing and not exceptId and not P.GetSetting('ownJobs', {})[job] then
        return nil, ('Le métier « %s » existe déjà dans elyzea_core (autre script) : choisissez un autre nom.'):format(job)
    end
    return job
end

P.Admin.shopSave = { staff = 'edit', fn = function(src, d)
    local id = tonumber(d.id)
    local D = id and P.shops[id]
    if id and (not D or D.deleted) then return { error = 'Restaurant introuvable.' } end
    local name = P.Clean(d.name, 80)
    if #name < 2 then return { error = 'Nom trop court.' } end
    local job, why = ValidJob(d.job ~= nil and d.job ~= '' and d.job or (D and D.job) or ('resto_' .. name:lower():gsub('[^%w]', ''):sub(1, 20)), id)
    if not job then return { error = why } end
    if D and D.job ~= job then
        for _ in pairs(P.ShopEmployees(D.id)) do return { error = 'Des employés ont le métier actuel : retirez-les avant de changer le nom du métier.' } end
    end
    local society = tostring(d.society or ''):lower():gsub('[^%w_]', ''):sub(1, 40)
    if society == '' then society = job end
    local prefix = P.Clean(d.matPrefix, 8):upper()
    if prefix == '' then prefix = 'RS-' end
    local opts = D and D.options or { publicOpen = true }
    local logo = P.Clean(d.logo, 300)
    opts.logo = logo ~= '' and logo or (opts.logo or '🍽️')
    local color = tostring(d.color or '')
    opts.color = color:match('^#%x%x%x%x%x%x$') and color or (opts.color or '#f97316')
    opts.requireDuty = d.requireDuty ~= false
    opts.blip = d.blip ~= false
    opts.blipSprite = P.Int(d.blipSprite, 1, 900, opts.blipSprite or 93)
    opts.blipColor = P.Int(d.blipColor, 0, 85, opts.blipColor or 47)
    local address, jobLabel = P.Clean(d.address, 120), P.Clean(d.jobLabel, 60)
    if jobLabel == '' then jobLabel = name end
    if D then
        D.name, D.address, D.job, D.jobLabel, D.society, D.matPrefix, D.options = name, address, job, jobLabel, society, prefix, opts
        P.SaveShop(D)
        Log(src, 'Restaurant modifiée', ('%s · métier %s · compte %s'):format(name, job, society))
    else
        id = MySQL.insert.await([[INSERT INTO `rs_shops` (`name`, `address`, `job`, `job_label`, `society`, `mat_prefix`, `enabled`, `points`, `options`, `created_by`)
            VALUES (?, ?, ?, ?, ?, ?, 0, '{}', ?, ?)]], { name, address, job, jobLabel, society, prefix, json.encode(opts), P.Name(src) })
        if not id then return { error = 'Création impossible.' } end
        D = { id = id, name = name, address = address, job = job, jobLabel = jobLabel, society = society, matPrefix = prefix, enabled = false, deleted = false, points = {}, options = opts }
        P.shops[id] = D
        local own = P.GetSetting('ownJobs', {})
        own[job] = true
        P.SetSetting('ownJobs', own)
        P.SeedGrades(id)
        P.SeedMenu(D)
        Log(src, 'Restaurant créée', ('%s · métier %s · compte %s'):format(name, job, society))
    end
    pcall(function() core:GetSocietyMoney(society) end)
    P.SyncCoreJob(D)
    P.RegisterStash(D)
    P.Touch()
    P.PushShop(D.id)
    return { ok = true, id = D.id, message = tonumber(d.id) and 'Restaurant enregistré.' or 'Restaurant créé (fermé tant que vous ne l\'activez pas). Placez ses points et stations, puis nommez le patron.' }
end }

P.Admin.shopEnable = { staff = 'toggle', fn = function(src, d)
    local D = P.shops[tonumber(d.id) or 0]
    if not D or D.deleted then return { error = 'Restaurant introuvable.' } end
    local on = d.enabled == true
    if on and not D.points.order then return { error = 'Placez d\'abord le point de commande.' } end
    if on and #(D.points.stations or {}) == 0 then return { error = 'Placez d\'abord au moins une station de cuisine.' } end
    D.enabled = on
    P.SaveShop(D)
    Log(src, on and 'Restaurant activée' or 'Restaurant désactivée', D.name)
    P.Touch()
    P.PushShop(D.id)
    return { ok = true, message = on and 'Restaurant activé : il prend des commandes (le patron peut les fermer).' or 'Restaurant désactivé par le staff : commandes suspendues (rien n\'est supprimé).' }
end }

P.Admin.shopDelete = { staff = 'delete', fn = function(src, d)
    local D = P.shops[tonumber(d.id) or 0]
    if not D or D.deleted then return { error = 'Restaurant introuvable.' } end
    if d.confirm ~= D.name then return { error = 'Confirmation incorrecte : tapez exactement le nom du restaurant.' } end
    local n = 0
    for cid in pairs(P.ShopEmployees(D.id)) do P.Remove(cid) n = n + 1 end
    for _, o in pairs(P.orders) do if o.shop == D.id then return { error = 'Des commandes sont en cours : terminez-les ou annulez-les avant de supprimer le restaurant.' } end end
    D.enabled, D.deleted = false, true
    P.SaveShop(D)
    pcall(function() core:RemoveJob(D.job) end)
    local own = P.GetSetting('ownJobs', {})
    own[D.job] = nil
    P.SetSetting('ownJobs', own)
    Log(src, 'Restaurant supprimée', ('%s · %d employé(s) retiré(s) du métier'):format(D.name, n))
    P.Touch()
    return { ok = true, message = ('« %s » supprimé : %d employé(s) retiré(s). Les commandes et les finances sont conservées.'):format(D.name, n) }
end }

P.Admin.setBoss = { staff = 'boss', fn = function(src, d)
    local D = P.shops[tonumber(d.id) or 0]
    if not D or D.deleted then return { error = 'Restaurant introuvable.' } end
    local t = tonumber(d.target)
    local cid = t and P.Cid(t)
    if not cid then return { error = 'Joueur introuvable (ID serveur).' } end
    local top = P.TopGrade(D.id)
    if not top then return { error = 'Aucun grade dans ce restaurant.' } end
    local cur = P.employees[cid]
    if cur and cur.shop_id ~= D.id then return { error = 'Ce joueur travaille dans une autre restaurant : il doit d\'abord la quitter.' } end
    if cur then P.ApplyGrade(cid, top) else
        local ok, why = P.Hire(D, cid, P.Name(t), top)
        if not ok then return { error = why } end
    end
    P.AddLog(D.id, src, cid, P.Name(t), 'Nommé par le staff', nil, top.name, nil)
    Log(src, 'Patron nommé', ('%s · %s (%s)'):format(D.name, P.Name(t), top.name))
    P.Notify(t, ('Vous êtes %s de %s.'):format(top.name, D.name), 'success')
    return { ok = true, message = ('%s est maintenant %s de %s.'):format(P.Name(t), top.name, D.name) }
end }

-- ---------------------------------------------------------------------
-- Points et stations
-- ---------------------------------------------------------------------
local KEYS = { order = 'Point de commande', stash = 'Coffre', manage = 'Bureau (tablette)' }
P.Admin.point = { staff = 'points', fn = function(src, d)
    local D = P.shops[tonumber(d.id) or 0]
    if not D or D.deleted then return { error = 'Restaurant introuvable.' } end
    local key = tostring(d.key or '')
    if not KEYS[key] then return { error = 'Point inconnu.' } end
    D.points = D.points or {}
    if d.remove then
        if key == 'order' and D.enabled then return { error = 'Désactivez le restaurant avant de retirer son point de commande.' } end
        D.points[key] = nil
    else
        local p = StaffPos(src)
        p.r = math.max(0.6, math.min(10.0, tonumber(d.r) or (D.points[key] and D.points[key].r) or Config.Points.defaultRadius))
        p.on = true
        D.points[key] = p
    end
    P.SaveShop(D)
    Log(src, d.remove and 'Point retiré' or 'Point placé', ('%s · %s'):format(D.name, KEYS[key]))
    P.Touch()
    return { ok = true, message = d.remove and 'Point retiré.' or ('%s placé à votre position (orientation comprise).'):format(KEYS[key]) }
end }

local function CleanTypes(list)
    local out, seen = {}, {}
    for _, t in ipairs(type(list) == 'table' and list or {}) do
        t = tostring(t)
        if Config.StationTypes[t] and not seen[t] then seen[t] = true out[#out + 1] = t end
    end
    return out
end
-- Station : ajout (à la position du staff), types, déplacement, retrait
P.Admin.station = { staff = 'points', fn = function(src, d)
    local D = P.shops[tonumber(d.id) or 0]
    if not D or D.deleted then return { error = 'Restaurant introuvable.' } end
    D.points = D.points or {}
    D.points.stations = D.points.stations or {}
    local list = D.points.stations
    local i = tonumber(d.index)
    if d.remove then
        if not list[i or -1] then return { error = 'Station introuvable.' } end
        if D.enabled and #list <= 1 then return { error = 'Désactivez le restaurant avant de retirer sa dernière station.' } end
        table.remove(list, i)
        for s, c in pairs(P.cook) do if c.shop == D.id then P.cook[s] = nil end end
    else
        local types = CleanTypes(d.types)
        if #types == 0 then return { error = 'Cochez au moins un type de station.' } end
        if i and list[i] then
            list[i].types = types
            if d.move then local p = StaffPos(src) list[i].x, list[i].y, list[i].z, list[i].h = p.x, p.y, p.z, p.h end
        else
            if #list >= 30 then return { error = '30 stations au plus par restaurant.' } end
            local p = StaffPos(src)
            p.r, p.on, p.types = Config.Points.defaultRadius, true, types
            list[#list + 1] = p
        end
    end
    P.SaveShop(D)
    Log(src, d.remove and 'Station retirée' or 'Station enregistrée', D.name)
    P.Touch()
    return { ok = true, message = d.remove and 'Station retirée.' or (i and 'Station enregistrée.' or 'Station posée à votre position.') }
end }

P.Admin.teleport = { fn = function(src, d)
    local D = P.shops[tonumber(d.id) or 0]
    if not D then return { error = 'Restaurant introuvable.' } end
    local pt
    if d.key == 'station' then pt = ((D.points or {}).stations or {})[tonumber(d.index) or -1]
    else pt = D.points[tostring(d.key or '')] end
    if not pt then return { error = 'Point non placé.' } end
    SetEntityCoords(GetPlayerPed(src), pt.x + 0.0, pt.y + 0.0, pt.z + 0.0, false, false, false, false)
    return { ok = true, message = 'Téléporté.' }
end }

-- ---------------------------------------------------------------------
-- Commandes (staff) : voir et annuler / rembourser
-- ---------------------------------------------------------------------
P.Admin.orders = { staff = 'orders', fn = function(_, d)
    local D = P.shops[tonumber(d.id) or 0]
    if not D then return { error = 'Restaurant introuvable.' } end
    local list = {}
    for _, o in pairs(P.orders) do if o.shop == D.id then list[#list + 1] = P.OrderView(o) end end
    table.sort(list, function(a, c) return a.id < c.id end)
    return { list = list }
end }
P.Admin.orderCancel = { staff = 'orders', fn = function(src, d)
    local o = P.orders[tonumber(d.order) or -1]
    local D = o and P.shops[o.shop]
    if not o or not D then return { error = 'Commande introuvable.' } end
    local ok, why = P.CancelOrder(D, o, 'Annulée par le staff', src)
    if not ok then return { error = why } end
    Log(src, 'Commande annulée', ('%s · %s · %d $ remboursés'):format(D.name, P.Num(o), o.total))
    return { ok = true, message = ('Commande %s annulée et remboursée.'):format(P.Num(o)) }
end }
