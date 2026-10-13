-- =====================================================================
--  ELYZEA CONCESSION - serveur : base de données, concessions, grades, employés
--  · Plusieurs concessions, chacune avec : son métier elyzea_core, son compte de
--    société, ses grades et permissions, ses employés, ses points, son catalogue.
--  · Un employé appartient à UNE concession (celle de son métier dans le core).
--  · Chaque requête passe par un point d'entrée qui vérifie : employé, concession
--    active, permission du grade, service. Le client ne décide jamais d'un droit.
--  · Les actions d'employé reçoivent la concession D en paramètre : fn(src, data, D).
-- =====================================================================
Concess = {
    shops = {},         -- [id] = concession
    grades = {},        -- [id] = { id, shop_id, name, level, salary, perms = {key=true}, isDefault, active }
    employees = {},     -- [citizenid] = { citizenid, shop_id, name, matricule, grade_id, … }
    duty = {},          -- [src] = true
    status = {},        -- [src] = statut
    Actions = {},       -- employés : [nom] = { perm, duty, fn(src, data, D) }
    Pub = {},           -- tout joueur : [nom] = { fn(src, data) }
    Admin = {},         -- staff : [nom] = { fn(src, data) }
    OnReady = {},
    ready = false,
}
local P = Concess
local core = exports.elyzea_core

-- ---------------------------------------------------------------------
-- Utilitaires
-- ---------------------------------------------------------------------
function P.Notify(src, msg, kind) core:Notify(src, msg, kind or 'inform') end
function P.GetPlayer(src) return core:GetPlayer(src) end
function P.Cid(src) local p = P.GetPlayer(src) return p and p.PlayerData.citizenid end
function P.Name(src)
    local p = P.GetPlayer(src)
    if not p then return GetPlayerName(src) or ('ID ' .. tostring(src)) end
    local ci = p.PlayerData.charinfo or {}
    return ('%s %s'):format(ci.firstname or '', ci.lastname or '')
end
function P.Coords(src)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and GetEntityCoords(ped) or nil
end
function P.Dist(a, b)
    local ca, cb = P.Coords(a), P.Coords(b)
    if not ca or not cb then return 9999.0 end
    return #(ca - cb)
end
function P.Vec(t) return type(t) == 'table' and tonumber(t.x) and vector3(t.x + 0.0, t.y + 0.0, t.z + 0.0) or nil end
function P.Clean(s, max) return (tostring(s or ''):gsub('[<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, max or 100) end
function P.Int(v, mn, mx, def)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return def end
    v = math.floor(v)
    if mn then v = math.max(mn, v) end
    if mx then v = math.min(mx, v) end
    return v
end
local uidSeq = 0
function P.Uid(prefix)
    uidSeq = (uidSeq + 1) % 1000
    return ('%s-%s-%03d%04d'):format(prefix or 'OP', os.date('%y%m%d%H%M%S'), uidSeq, math.random(0, 9999))
end
function P.Log(src, action, details)
    if GetResourceState('admin_menu') == 'started' then
        if pcall(function() exports.admin_menu:AddLog(src, '[Concession] ' .. action, details) end) then return end
    end
    print(('^5[CONCESS]^7 %s | %s | %s'):format(src and P.Name(src) or 'Système', action, details or ''))
end
local function dec(raw, def) local ok, v = pcall(json.decode, raw or '') return ok and type(v) == 'table' and v or def end
P.Decode = dec

P.Settings = {}
function P.GetSetting(key, default) local v = P.Settings[key] if v == nil then return default end return v end
function P.SetSetting(key, value)
    P.Settings[key] = value
    MySQL.query.await('INSERT INTO `cd_settings` (`k`, `v`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `v` = VALUES(`v`)', { key, json.encode(value) })
end

-- ---------------------------------------------------------------------
-- Base de données (préfixe cd_ : n'entre pas en conflit avec d'anciennes tables concess_*)
-- ---------------------------------------------------------------------
P.Tables = {
    cd_settings = [[ (`k` VARCHAR(50) NOT NULL PRIMARY KEY, `v` LONGTEXT NOT NULL) ]],
    cd_shops = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(80) NOT NULL,
        `address` VARCHAR(120) NULL,
        `job` VARCHAR(40) NOT NULL UNIQUE,
        `job_label` VARCHAR(60) NULL,
        `society` VARCHAR(40) NOT NULL,
        `mat_prefix` VARCHAR(8) NOT NULL DEFAULT 'CD-',
        `enabled` TINYINT(1) NOT NULL DEFAULT 0,
        `deleted` TINYINT(1) NOT NULL DEFAULT 0,
        `points` LONGTEXT NULL,
        `options` LONGTEXT NULL,
        `created_by` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP ) ]],
    cd_grades = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `name` VARCHAR(50) NOT NULL,
        `level` INT NOT NULL,
        `salary` INT NOT NULL DEFAULT 0,
        `perms` TEXT NOT NULL,
        `is_default` TINYINT(1) NOT NULL DEFAULT 0,
        `active` TINYINT(1) NOT NULL DEFAULT 1,
        UNIQUE KEY `shop_level` (`shop_id`, `level`), UNIQUE KEY `shop_name` (`shop_id`, `name`) ) ]],
    cd_employees = [[ (
        `citizenid` VARCHAR(50) NOT NULL PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `name` VARCHAR(100) NOT NULL,
        `matricule` VARCHAR(20) NOT NULL,
        `grade_id` INT NOT NULL,
        `recruited_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `promoted_at` DATETIME NULL,
        `note` VARCHAR(255) NULL,
        `total_seconds` INT NOT NULL DEFAULT 0,
        `unpaid_seconds` INT NOT NULL DEFAULT 0,
        `unpaid_amount` DOUBLE NOT NULL DEFAULT 0,
        INDEX (`shop_id`) ) ]],
    cd_admin_log = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `actor_cid` VARCHAR(50) NULL, `actor_name` VARCHAR(100) NULL,
        `target_cid` VARCHAR(50) NULL, `target_name` VARCHAR(100) NULL,
        `action` VARCHAR(40) NOT NULL,
        `old_grade` VARCHAR(50) NULL, `new_grade` VARCHAR(50) NULL,
        `reason` VARCHAR(255) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`shop_id`), INDEX (`target_cid`) ) ]],
    cd_sessions = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `citizenid` VARCHAR(50) NOT NULL, `name` VARCHAR(100) NULL,
        `grade_name` VARCHAR(50) NULL,
        `started_at` DATETIME NOT NULL, `ended_at` DATETIME NULL,
        `seconds` INT NOT NULL DEFAULT 0,
        `amount` DOUBLE NOT NULL DEFAULT 0,
        `end_reason` VARCHAR(30) NULL,
        INDEX (`citizenid`), INDEX (`shop_id`) ) ]],
    cd_rates = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `grade_id` INT NOT NULL, `grade_name` VARCHAR(50) NULL,
        `rate` INT NOT NULL,
        `actor_name` VARCHAR(100) NULL,
        `effective_from` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`shop_id`) ) ]],
    cd_transactions = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `txid` VARCHAR(40) NOT NULL UNIQUE,
        `type` VARCHAR(10) NOT NULL,
        `category` VARCHAR(20) NOT NULL,
        `amount` INT NOT NULL,
        `reason` VARCHAR(160) NULL,
        `actor_cid` VARCHAR(50) NULL, `actor_name` VARCHAR(100) NULL,
        `target_cid` VARCHAR(50) NULL, `target_name` VARCHAR(100) NULL,
        `seconds` INT NULL,
        `ref` VARCHAR(40) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`shop_id`), INDEX (`category`), INDEX (`created_at`) ) ]],
    cd_categories = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(50) NOT NULL UNIQUE,
        `description` VARCHAR(255) NULL,
        `icon` VARCHAR(16) NULL,
        `image` VARCHAR(255) NULL,
        `sort` INT NOT NULL DEFAULT 0,
        `enabled` TINYINT(1) NOT NULL DEFAULT 1,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ) ]],
    cd_models = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `model` VARCHAR(50) NOT NULL UNIQUE,
        `label` VARCHAR(80) NOT NULL,
        `brand` VARCHAR(50) NULL,
        `category_id` INT NULL,
        `description` VARCHAR(500) NULL,
        `image` VARCHAR(255) NULL,
        `ref_price` INT NULL,
        `commercial` TINYINT(1) NOT NULL DEFAULT 1,
        `displayable` TINYINT(1) NOT NULL DEFAULT 1,
        `enabled` TINYINT(1) NOT NULL DEFAULT 1,
        `removed` TINYINT(1) NOT NULL DEFAULT 0,
        `vclass` INT NULL,
        `seats` INT NULL,
        `validated_by` VARCHAR(100) NULL,
        `created_by` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX (`category_id`) ) ]],
    cd_catalog_log = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NULL, `model_id` INT NULL, `category_id` INT NULL,
        `action` VARCHAR(50) NOT NULL,
        `details` VARCHAR(255) NULL,
        `actor_name` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`shop_id`), INDEX (`model_id`) ) ]],
    cd_shop_categories = [[ (
        `shop_id` INT NOT NULL, `category_id` INT NOT NULL,
        `enabled` TINYINT(1) NOT NULL DEFAULT 1,
        `visible` TINYINT(1) NOT NULL DEFAULT 1,
        `sellable` TINYINT(1) NOT NULL DEFAULT 1,
        `sort` INT NOT NULL DEFAULT 0,
        PRIMARY KEY (`shop_id`, `category_id`) ) ]],
    cd_shop_models = [[ (
        `shop_id` INT NOT NULL, `model_id` INT NOT NULL,
        `enabled` TINYINT(1) NOT NULL DEFAULT 1,
        `visible` TINYINT(1) NOT NULL DEFAULT 1,
        `sellable` TINYINT(1) NOT NULL DEFAULT 1,
        `displayable` TINYINT(1) NOT NULL DEFAULT 1,
        `price` INT NULL,
        PRIMARY KEY (`shop_id`, `model_id`) ) ]],
    cd_price_log = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NOT NULL, `model_id` INT NOT NULL, `model` VARCHAR(50) NULL,
        `old_price` INT NULL, `new_price` INT NULL,
        `actor_cid` VARCHAR(50) NULL, `actor_name` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`shop_id`, `model_id`) ) ]],
    cd_slots = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `label` VARCHAR(40) NULL,
        `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL, `h` DOUBLE NOT NULL DEFAULT 0,
        `enabled` TINYINT(1) NOT NULL DEFAULT 1,
        INDEX (`shop_id`) ) ]],
    cd_display = [[ (
        `slot_id` INT NOT NULL PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `model_id` INT NOT NULL, `model` VARCHAR(50) NOT NULL,
        `h` DOUBLE NULL,
        `color1` INT NULL, `color2` INT NULL,
        `placed_by` VARCHAR(100) NULL,
        `placed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`shop_id`) ) ]],
    cd_sales = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `uid` VARCHAR(40) NOT NULL UNIQUE,
        `shop_id` INT NOT NULL,
        `model_id` INT NULL, `model` VARCHAR(50) NOT NULL, `label` VARCHAR(80) NULL, `category` VARCHAR(50) NULL,
        `list_price` INT NOT NULL DEFAULT 0, `discount` INT NOT NULL DEFAULT 0, `price` INT NOT NULL DEFAULT 0,
        `method` VARCHAR(6) NULL,
        `buyer_cid` VARCHAR(50) NOT NULL, `buyer_name` VARCHAR(100) NULL,
        `seller_cid` VARCHAR(50) NULL, `seller_name` VARCHAR(100) NULL,
        `plate` VARCHAR(15) NULL, `vehicle_id` INT NULL,
        `status` VARCHAR(10) NOT NULL DEFAULT 'paid',
        `delivery` VARCHAR(10) NOT NULL DEFAULT 'pending',
        `delivered_at` DATETIME NULL,
        `key_given` TINYINT(1) NOT NULL DEFAULT 0,
        `note` VARCHAR(160) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`shop_id`), INDEX (`buyer_cid`), INDEX (`delivery`) ) ]],
}
P.TableOrder = { 'cd_settings', 'cd_shops', 'cd_grades', 'cd_employees', 'cd_admin_log', 'cd_sessions', 'cd_rates', 'cd_transactions',
    'cd_categories', 'cd_models', 'cd_catalog_log', 'cd_shop_categories', 'cd_shop_models', 'cd_price_log', 'cd_slots', 'cd_display', 'cd_sales' }

local function InitDb()
    for _, name in ipairs(P.TableOrder) do
        local ok, err = pcall(MySQL.query.await, ('CREATE TABLE IF NOT EXISTS `%s` %s DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'):format(name, P.Tables[name]))
        if not ok then print(('^1[CONCESS] Table %s non créée : %s^0'):format(name, tostring(err))) end
    end
    pcall(function() core:ToUtf8mb4(P.TableOrder) end)
end

-- ---------------------------------------------------------------------
-- Concessions
-- ---------------------------------------------------------------------
local function RowToShop(r)
    return { id = r.id, name = r.name, address = r.address or '', job = r.job, jobLabel = r.job_label or r.name, society = r.society,
        matPrefix = r.mat_prefix or 'CD-', enabled = r.enabled == 1 or r.enabled == true, deleted = r.deleted == 1 or r.deleted == true,
        points = dec(r.points, {}), options = dec(r.options, {}) }
end
function P.Opt(D, key, def) local v = D and D.options and D.options[key] if v == nil then return def end return v end

function P.LoadShops()
    P.shops = {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `cd_shops`') or {}) do P.shops[r.id] = RowToShop(r) end
end
function P.ShopByJob(job)
    for _, D in pairs(P.shops) do if D.job == job and not D.deleted then return D end end
end
function P.SaveShop(D)
    MySQL.update.await([[UPDATE `cd_shops` SET `name` = ?, `address` = ?, `job` = ?, `job_label` = ?, `society` = ?, `mat_prefix` = ?, `enabled` = ?, `deleted` = ?,
        `points` = ?, `options` = ? WHERE `id` = ?]], { D.name, D.address, D.job, D.jobLabel, D.society, D.matPrefix, D.enabled and 1 or 0, D.deleted and 1 or 0,
        json.encode(D.points or {}), json.encode(D.options or {}), D.id })
end
-- Concession ouverte : active et non supprimée
function P.ShopOpen(D) return D ~= nil and D.enabled and not D.deleted end

-- Version publique des points / concessions : les clients rechargent quand elle change
P.version = 0
function P.Touch()
    P.version = P.version + 1
    GlobalState.concessVersion = P.version
end

-- ---------------------------------------------------------------------
-- Grades (par concession)
-- ---------------------------------------------------------------------
local function DecodePerms(raw)
    local set = {}
    for _, k in ipairs(dec(raw, {})) do if CDPermSet[k] then set[k] = true end end
    return set
end
function P.EncodePerms(set)
    local list = {}
    for _, p in ipairs(CDPerms) do if set[p.key] then list[#list + 1] = p.key end end
    return json.encode(list)
end
function P.LoadGrades()
    P.grades = {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `cd_grades`') or {}) do
        P.grades[r.id] = { id = r.id, shop_id = r.shop_id, name = r.name, level = r.level, salary = r.salary, perms = DecodePerms(r.perms),
            isDefault = r.is_default == 1 or r.is_default == true, active = not (r.active == 0 or r.active == false) }
    end
end
function P.SortedGrades(shopId)
    local list = {}
    for _, g in pairs(P.grades) do if g.shop_id == shopId then list[#list + 1] = g end end
    table.sort(list, function(a, b) return a.level < b.level end)
    return list
end
function P.DefaultGrade(shopId)
    local sorted = P.SortedGrades(shopId)
    for _, g in ipairs(sorted) do if g.isDefault and g.active then return g end end
    return sorted[1]
end
function P.GradeByLevel(shopId, level)
    for _, g in pairs(P.grades) do if g.shop_id == shopId and g.level == level then return g end end
end
function P.TopLevel(shopId)
    local top = 0
    for _, g in pairs(P.grades) do if g.shop_id == shopId and g.level > top then top = g.level end end
    return top
end
function P.TopGrade(shopId) return P.GradeByLevel(shopId, P.TopLevel(shopId)) end

-- Grades de départ d'une nouvelle concession
function P.SeedGrades(shopId)
    for _, g in ipairs(Config.DefaultGrades) do
        local set = {}
        if g.perms == 'all' then for _, p in ipairs(CDPerms) do set[p.key] = true end
        else for _, k in ipairs(g.perms or {}) do set[k] = true end end
        local id = MySQL.insert.await('INSERT INTO `cd_grades` (`shop_id`, `name`, `level`, `salary`, `perms`, `is_default`) VALUES (?, ?, ?, ?, ?, ?)',
            { shopId, g.name, g.level, g.salary or 0, P.EncodePerms(set), g.default and 1 or 0 })
        if id then
            MySQL.insert.await('INSERT INTO `cd_rates` (`shop_id`, `grade_id`, `grade_name`, `rate`, `actor_name`) VALUES (?, ?, ?, ?, ?)', { shopId, id, g.name, g.salary or 0, 'Installation' })
            P.grades[id] = { id = id, shop_id = shopId, name = g.name, level = g.level, salary = g.salary or 0, perms = set, isDefault = g.default == true, active = true }
        end
    end
end

-- Métier elyzea_core de la concession : un grade du core par niveau ; payment = 0
-- (les heures de service sont payées par la direction dans Finance, comme les autres métiers)
function P.SyncCoreJob(D)
    if not D or D.deleted then return end
    local grades = {}
    local top = P.TopLevel(D.id)
    for _, g in ipairs(P.SortedGrades(D.id)) do
        grades[g.level] = { name = g.name, payment = 0, isboss = g.perms.direction == true or g.level == top }
    end
    if not grades[0] then grades[0] = { name = 'Sans grade', payment = 0 } end
    local ok, err = pcall(function()
        core:CreateJob(D.job, { label = D.jobLabel or D.name, type = 'cardealer', defaultDuty = false, offDutyPay = false, grades = grades })
    end)
    if not ok then print(('^1[CONCESS] Métier %s non déclaré : %s^0'):format(D.job, tostring(err))) end
end

-- ---------------------------------------------------------------------
-- Employés
-- ---------------------------------------------------------------------
function P.LoadEmployees()
    P.employees = {}
    for _, r in ipairs(MySQL.query.await([[SELECT `citizenid`, `shop_id`, `name`, `matricule`, `grade_id`, `note`, `total_seconds`, `unpaid_seconds`, `unpaid_amount`,
        DATE_FORMAT(`recruited_at`, '%d/%m/%Y') AS recruited, DATE_FORMAT(`promoted_at`, '%d/%m/%Y') AS promoted FROM `cd_employees`]]) or {}) do
        r.total_seconds, r.unpaid_seconds, r.unpaid_amount = tonumber(r.total_seconds) or 0, tonumber(r.unpaid_seconds) or 0, tonumber(r.unpaid_amount) or 0
        P.employees[r.citizenid] = r
    end
end
function P.ShopEmployees(shopId)
    local list = {}
    for cid, e in pairs(P.employees) do if e.shop_id == shopId then list[cid] = e end end
    return list
end
function P.NextMatricule(D)
    local max, prefix = 0, D.matPrefix or 'CD-'
    for _, e in pairs(P.employees) do
        if e.shop_id == D.id then
            local n = tonumber(tostring(e.matricule):sub(#prefix + 1))
            if n and n > max then max = n end
        end
    end
    return ('%s%03d'):format(prefix, max + 1)
end

function P.Employee(src) local cid = P.Cid(src) return cid and P.employees[cid] or nil end
function P.GradeOfCid(cid) local e = P.employees[cid] return e and P.grades[e.grade_id] or nil end
function P.Grade(src) local cid = P.Cid(src) return cid and P.GradeOfCid(cid) or nil end

-- Concession du joueur : fiche d'employé + métier du core correspondant + concession ouverte
function P.ShopOf(src)
    local p = P.GetPlayer(src)
    if not p then return nil end
    local e = P.employees[p.PlayerData.citizenid]
    local D = e and P.shops[e.shop_id]
    if not D or D.deleted or not (p.PlayerData.job and p.PlayerData.job.name == D.job) then return nil end
    return D
end
function P.IsMember(src) return P.ShopOf(src) ~= nil end
function P.OnDuty(src) return P.duty[tonumber(src) or -1] == true end
function P.Can(src, perm)
    local D = P.ShopOf(src)
    if not D then return false end
    local g = P.Grade(src)
    return g ~= nil and g.perms[perm] == true
end

function P.AddLog(shopId, actorSrc, targetCid, targetName, action, oldGrade, newGrade, reason)
    local aCid, aName
    if type(actorSrc) == 'number' and actorSrc > 0 then aCid, aName = P.Cid(actorSrc), P.Name(actorSrc)
    elseif type(actorSrc) == 'string' then aName = actorSrc end
    MySQL.insert([[INSERT INTO `cd_admin_log` (`shop_id`, `actor_cid`, `actor_name`, `target_cid`, `target_name`, `action`, `old_grade`, `new_grade`, `reason`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]], { shopId, aCid, aName, targetCid, targetName, action, oldGrade, newGrade, reason and P.Clean(reason, 255) or nil })
end

P.applying = {}
function P.ApplyGrade(cid, grade)
    local e = P.employees[cid]
    local D = e and P.shops[e.shop_id]
    if not e or not grade or not D or grade.shop_id ~= e.shop_id then return false end
    if P.FlushCid then P.FlushCid(cid) end
    e.grade_id = grade.id
    MySQL.update.await('UPDATE `cd_employees` SET `grade_id` = ?, `promoted_at` = NOW() WHERE `citizenid` = ?', { grade.id, cid })
    P.applying[cid] = true
    pcall(function() core:AddPlayerToJob(cid, D.job, grade.level) end)
    P.applying[cid] = nil
    local src = core:GetSourceByCitizenId(cid)
    if src then
        if P.OnDuty(src) then local p = P.GetPlayer(src) if p then pcall(function() p.Functions.SetJobDuty(true) end) end end
        P.PushState(src)
    end
    return true
end

function P.Hire(D, cid, name, grade)
    local cur = P.employees[cid]
    if cur then
        local other = P.shops[cur.shop_id]
        return false, cur.shop_id == D.id and 'Déjà employé de cette concession.' or ('Déjà employé de « %s ».'):format(other and other.name or '?')
    end
    local mat = P.NextMatricule(D)
    MySQL.insert.await('INSERT INTO `cd_employees` (`citizenid`, `shop_id`, `name`, `matricule`, `grade_id`) VALUES (?, ?, ?, ?, ?)', { cid, D.id, name, mat, grade.id })
    P.employees[cid] = { citizenid = cid, shop_id = D.id, name = name, matricule = mat, grade_id = grade.id, recruited = os.date('%d/%m/%Y'),
        total_seconds = 0, unpaid_seconds = 0, unpaid_amount = 0 }
    P.applying[cid] = true
    pcall(function() core:AddPlayerToJob(cid, D.job, grade.level) end)
    P.applying[cid] = nil
    local src = core:GetSourceByCitizenId(cid)
    if src then P.PushState(src) end
    return true, mat
end

function P.Remove(cid)
    local e = P.employees[cid]
    if not e then return false end
    local D = P.shops[e.shop_id]
    local src = core:GetSourceByCitizenId(cid)
    if src and P.OnDuty(src) and P.SetDuty then P.SetDuty(src, false, true) end
    P.employees[cid] = nil
    MySQL.update.await('DELETE FROM `cd_employees` WHERE `citizenid` = ?', { cid })
    if D then
        P.applying[cid] = true
        pcall(function() core:RemovePlayerFromJob(cid, D.job) end)
        P.applying[cid] = nil
    end
    if src then P.PushState(src) end
    return true
end

-- ---------------------------------------------------------------------
-- État publié au client (affichage seulement : le serveur revérifie tout)
-- ---------------------------------------------------------------------
function P.PushState(src)
    if not GetPlayerName(src) then return end
    local D = P.ShopOf(src)
    if not D then
        if Player(src).state.concess ~= nil then Player(src).state:set('concess', nil, true) end
        return
    end
    local e, g = P.Employee(src), P.Grade(src)
    local perms = {}
    for k in pairs(g and g.perms or {}) do perms[k] = true end
    Player(src).state:set('concess', {
        shop = D.id, shopName = D.name, matricule = e.matricule, name = P.Name(src), grade = g and g.name or '?', level = g and g.level or 0,
        perms = perms, duty = P.OnDuty(src), status = P.status[src] or 'available', open = P.ShopOpen(D),
    }, true)
end
function P.PushAll() for src in pairs(core:GetPlayers()) do P.PushState(src) end end
function P.PushShop(shopId)
    for src in pairs(core:GetPlayers()) do
        local e = P.Employee(src)
        if e and e.shop_id == shopId then P.PushState(src) end
    end
end

-- ---------------------------------------------------------------------
-- Changements de métier faits ailleurs (menu admin, /setjob…)
-- ---------------------------------------------------------------------
AddEventHandler('elyzea:server:onJobUpdate', function(src, job, old)
    local cid = P.Cid(src)
    if not cid or P.applying[cid] or not P.ready then return end
    local D = job and P.ShopByJob(job.name)
    local cur = P.employees[cid]
    if D then
        local level = job.grade and job.grade.level or 0
        local grade = P.GradeByLevel(D.id, level) or P.DefaultGrade(D.id)
        if cur and cur.shop_id ~= D.id then
            -- Passé d'une concession à une autre : la fiche de l'ancienne est fermée
            if P.OnDuty(src) and P.SetDuty then P.SetDuty(src, false, true) end
            P.employees[cid] = nil
            MySQL.update.await('DELETE FROM `cd_employees` WHERE `citizenid` = ?', { cid })
            P.AddLog(cur.shop_id, 'Système', cid, P.Name(src), 'Départ', nil, nil, 'Métier changé hors de la tablette')
            cur = nil
        end
        if grade and not cur then
            P.Hire(D, cid, P.Name(src), grade)
            P.AddLog(D.id, 'Système', cid, P.Name(src), 'Recrutement', nil, grade.name, 'Métier donné hors de la tablette')
        elseif grade and cur.grade_id ~= grade.id then
            local before = P.grades[cur.grade_id]
            P.ApplyGrade(cid, grade)
            P.AddLog(D.id, 'Système', cid, P.Name(src), 'Changement de grade', before and before.name, grade.name, 'Grade changé hors de la tablette')
        end
    elseif cur and old and P.shops[cur.shop_id] and old.name == P.shops[cur.shop_id].job then
        if P.OnDuty(src) and P.SetDuty then P.SetDuty(src, false, true) end
        P.employees[cid] = nil
        MySQL.update('DELETE FROM `cd_employees` WHERE `citizenid` = ?', { cid })
        P.AddLog(cur.shop_id, 'Système', cid, P.Name(src), 'Départ', nil, nil, 'Métier changé hors de la tablette')
    end
    P.PushState(src)
end)

AddEventHandler('elyzea:server:playerLoaded', function(src)
    local D = P.ShopOf(src)
    local p = P.GetPlayer(src)
    if D and p and p.PlayerData.job.onduty then pcall(function() p.Functions.SetJobDuty(false) end) end
    P.PushState(src)
end)

-- ---------------------------------------------------------------------
-- Points d'entrée des requêtes
-- ---------------------------------------------------------------------
local rate = {}
local function Allowed(src, n)
    local now = GetGameTimer()
    local r = rate[src]
    if not r or now - r.t > 1000 then rate[src] = { t = now, n = 1 } return true end
    r.n = r.n + 1
    return r.n <= (n or 12)
end
AddEventHandler('playerDropped', function() rate[source] = nil end)

local function Run(kind, a, action, ...)
    local ok, res = pcall(a.fn, ...)
    if not ok then
        print(('^1[CONCESS] Erreur %s « %s » : %s^0'):format(kind, tostring(action), tostring(res)))
        return { error = 'Erreur serveur.' }
    end
    return res or {}
end

-- Employés : la concession est celle du joueur, jamais une valeur envoyée par le client
Ely.callback.register('concess:req', function(src, action, data)
    if not P.ready then return { error = 'La concession démarre, réessayez dans un instant.' } end
    if not Allowed(src) then return { error = 'Trop de demandes, patientez une seconde.' } end
    local a = P.Actions[tostring(action)]
    if not a then return { error = 'Action inconnue.' } end
    local D = P.ShopOf(src)
    if a.perm ~= false then
        if not D then return { error = 'Réservé aux employés d\'une concession.' } end
        if not D.enabled and a.open ~= false then return { error = ('La concession « %s » est fermée par le staff.'):format(D.name) } end
        if a.perm and not P.Can(src, a.perm) then return { error = 'Votre grade ne permet pas cette action.' } end
        if a.duty and P.Opt(D, 'requireDuty', true) and not P.OnDuty(src) then return { error = 'Prenez votre service pour faire cela.' } end
    end
    return Run('employé', a, action, src, type(data) == 'table' and data or {}, D)
end)

-- Tout joueur (catalogue client, réponse à une offre, livraison)
Ely.callback.register('concess:pub', function(src, action, data)
    if not P.ready then return { error = 'La concession démarre, réessayez dans un instant.' } end
    if not Allowed(src, 15) then return { error = 'Trop de demandes, patientez une seconde.' } end
    local a = P.Pub[tostring(action)]
    if not a then return { error = 'Action inconnue.' } end
    return Run('public', a, action, src, type(data) == 'table' and data or {})
end)

-- Staff : permission réelle d'admin_menu (« dealer_manage »)
function P.IsStaff(src)
    if GetResourceState('admin_menu') ~= 'started' then return false end
    local ok, res = pcall(function() return exports.admin_menu:HasPermission(src, 'dealer_manage') end)
    return ok and res == true
end
Ely.callback.register('concess:admin', function(src, action, data)
    if not P.ready then return { error = 'La concession démarre, réessayez dans un instant.' } end
    if not P.IsStaff(src) then return { error = 'Réservé au staff (permission « Administration automobile »).' } end
    if not Allowed(src, 20) then return { error = 'Trop de demandes, patientez une seconde.' } end
    local a = P.Admin[tostring(action)]
    if not a then return { error = 'Action inconnue.' } end
    return Run('staff', a, action, src, type(data) == 'table' and data or {})
end)

-- Configuration publique du client
P.Pub.init = { fn = function()
    return { perms = CDPerms, statuses = Config.Statuses, imageUrl = Config.ImageUrl, keys = Config.Keys }
end }

-- ---------------------------------------------------------------------
-- Démarrage
-- ---------------------------------------------------------------------
CreateThread(function()
    InitDb()
    local ok, err = pcall(function()
        for _, r in ipairs(MySQL.query.await('SELECT `k`, `v` FROM `cd_settings`') or {}) do
            local okj, v = pcall(json.decode, r.v)
            if okj then P.Settings[r.k] = v end
        end
        P.LoadShops()
        P.LoadGrades()
        P.LoadEmployees()
    end)
    if not ok then print(('^1[CONCESS] Chargement impossible : %s^0'):format(tostring(err))) return end
    for _, D in pairs(P.shops) do P.SyncCoreJob(D) end
    for _, fn in ipairs(P.OnReady) do local okr, e = pcall(fn) if not okr then print(('^1[CONCESS] Démarrage : %s^0'):format(tostring(e))) end end
    P.ready = true
    P.Touch()
    for src, p in pairs(core:GetPlayers()) do
        local D = P.ShopOf(src)
        if D and p.PlayerData.job.onduty then pcall(function() p.Functions.SetJobDuty(false) end) end
        P.PushState(src)
    end
    local ns, ne = 0, 0
    for _ in pairs(P.shops) do ns = ns + 1 end
    for _ in pairs(P.employees) do ne = ne + 1 end
    print(('^2[CONCESS] Prêt : %d concession(s), %d employé(s).^0'):format(ns, ne))
end)
