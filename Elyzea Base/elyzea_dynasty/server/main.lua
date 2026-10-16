-- =====================================================================
--  ELYZEA DYNASTY 8 - serveur : base de données, grades, employés, permissions
--  · La base Dynasty 8 (d8_grades, d8_employees) est la référence ; le métier
--    « mechanic » d'elyzea_core est reconstruit à partir d'elle (grade = niveau).
--  · Chaque requête du client passe par Dynasty.Actions : permission, service et
--    limite de fréquence vérifiés ici. Le client ne décide jamais d'un droit.
-- =====================================================================
Dynasty = {
    grades = {},        -- [id] = { id, name, level, salary (taux horaire actuel), perms = {key=true}, isDefault }
    employees = {},     -- [citizenid] = { citizenid, name, matricule, grade_id, total_seconds, unpaid_seconds, unpaid_amount, … }
    duty = {},          -- [src] = true
    status = {},        -- [src] = 'available' | …
    Actions = {},       -- [nom] = { perm, duty, fn(src, data) }
    ready = false,
}
local P = Dynasty
local core = exports.elyzea_core
local DEF_JOB = Config.Job.name:gsub('[^%w_]', '')
P.T = { grades = 'd8_grades', employees = 'd8_employees' }

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
function P.Clean(s, max) return (tostring(s or ''):gsub('[<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, max or 100) end
function P.Int(v, mn, mx, def)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return def end
    v = math.floor(v)
    if mn then v = math.max(mn, v) end
    if mx then v = math.min(mx, v) end
    return v
end
-- Identifiant unique d'opération (factures, paies, PPA)
local uidSeq = 0
function P.Uid(prefix)
    uidSeq = (uidSeq + 1) % 1000
    return ('%s-%s-%03d%04d'):format(prefix or 'OP', os.date('%y%m%d%H%M%S'), uidSeq, math.random(0, 9999))
end

function P.Log(src, action, details)
    if GetResourceState('admin_menu') == 'started' then
        if pcall(function() exports.admin_menu:AddLog(src, '[D8] ' .. action, details) end) then return end
    end
    print(('^5[D8]^7 %s | %s | %s'):format(src and P.Name(src) or 'Système', action, details or ''))
end

-- Réglages persistants (garage, réglages…) : table d8_settings (clé → JSON)
P.Settings = {}
function P.GetSetting(key, default)
    local v = P.Settings[key]
    if v == nil then return default end
    return v
end
function P.SetSetting(key, value)
    P.Settings[key] = value
    MySQL.query.await('INSERT INTO `d8_settings` (`k`, `v`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `v` = VALUES(`v`)', { key, json.encode(value) })
end

-- ---------------------------------------------------------------------
-- Base de données
-- ---------------------------------------------------------------------
local function Q(sql)
    local ok, err = pcall(MySQL.query.await, sql)
    if not ok then print(('^1[D8] Table non créée : %s^0'):format(tostring(err))) end
end
P.Tables = {
    d8_settings = [[ (
        `k` VARCHAR(50) NOT NULL PRIMARY KEY,
        `v` LONGTEXT NOT NULL ) ]],
    d8_grades = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `job` VARCHAR(40) NOT NULL DEFAULT ']] .. DEF_JOB .. [[',
        `name` VARCHAR(50) NOT NULL,
        `level` INT NOT NULL,
        `salary` INT NOT NULL DEFAULT 0,
        `perms` TEXT NOT NULL,
        `is_default` TINYINT(1) NOT NULL DEFAULT 0,
        `active` TINYINT(1) NOT NULL DEFAULT 1,
        UNIQUE KEY `job_name` (`job`, `name`), UNIQUE KEY `job_level` (`job`, `level`) ) ]],
    d8_employees = [[ (
        `citizenid` VARCHAR(50) NOT NULL PRIMARY KEY,
        `job` VARCHAR(40) NOT NULL DEFAULT ']] .. DEF_JOB .. [[',
        `name` VARCHAR(100) NOT NULL,
        `matricule` VARCHAR(20) NOT NULL UNIQUE,
        `grade_id` INT NOT NULL,
        `recruited_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `promoted_at` DATETIME NULL,
        `note` VARCHAR(255) NULL,
        `total_seconds` INT NOT NULL DEFAULT 0,
        `unpaid_seconds` INT NOT NULL DEFAULT 0,
        `unpaid_amount` DOUBLE NOT NULL DEFAULT 0 ) ]],
    d8_admin_log = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `actor_cid` VARCHAR(50) NULL, `actor_name` VARCHAR(100) NULL,
        `target_cid` VARCHAR(50) NULL, `target_name` VARCHAR(100) NULL,
        `action` VARCHAR(40) NOT NULL,
        `old_grade` VARCHAR(50) NULL, `new_grade` VARCHAR(50) NULL,
        `reason` VARCHAR(255) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`target_cid`) ) ]],
    d8_sessions = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `citizenid` VARCHAR(50) NOT NULL, `name` VARCHAR(100) NULL,
        `grade_name` VARCHAR(50) NULL,
        `started_at` DATETIME NOT NULL, `ended_at` DATETIME NULL,
        `seconds` INT NOT NULL DEFAULT 0,
        `amount` DOUBLE NOT NULL DEFAULT 0,
        `end_reason` VARCHAR(30) NULL,
        INDEX (`citizenid`) ) ]],
    d8_rates = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `grade_id` INT NOT NULL, `grade_name` VARCHAR(50) NULL,
        `rate` INT NOT NULL,
        `actor_name` VARCHAR(100) NULL,
        `effective_from` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`grade_id`) ) ]],
    d8_transactions = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
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
        INDEX (`category`), INDEX (`target_cid`), INDEX (`created_at`) ) ]],
    d8_interiors = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `code` VARCHAR(40) NULL UNIQUE,
        `label` VARCHAR(60) NOT NULL,
        `kind` VARCHAR(12) NOT NULL,
        `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL, `h` DOUBLE NOT NULL DEFAULT 0,
        `ipls` TEXT NULL,
        `resource` VARCHAR(60) NULL,
        `notes` VARCHAR(255) NULL,
        `enabled` TINYINT(1) NOT NULL DEFAULT 1,
        `created_by` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ) ]],
    d8_properties = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(80) NOT NULL,
        `address` VARCHAR(120) NULL,
        `category` VARCHAR(12) NOT NULL,
        `interior_id` INT NULL,
        `status` VARCHAR(12) NOT NULL DEFAULT 'available',
        `enabled` TINYINT(1) NOT NULL DEFAULT 1,
        `sale_price` INT NOT NULL DEFAULT 0,
        `rent_price` INT NOT NULL DEFAULT 0,
        `extend_price` INT NULL,
        `rent_min_days` INT NOT NULL DEFAULT 1,
        `rent_max_days` INT NOT NULL DEFAULT 30,
        `for_sale` TINYINT(1) NOT NULL DEFAULT 1,
        `for_rent` TINYINT(1) NOT NULL DEFAULT 1,
        `code` VARCHAR(12) NULL,
        `points` LONGTEXT NULL,
        `garage` LONGTEXT NULL,
        `stash_slots` INT NOT NULL DEFAULT 50,
        `stash_weight` INT NOT NULL DEFAULT 150,
        `deco_limit` INT NOT NULL DEFAULT 40,
        `contract_id` INT NULL,
        `reserved_by` VARCHAR(100) NULL,
        `notes` VARCHAR(255) NULL,
        `created_by` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX (`status`) ) ]],
    d8_contracts = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `uid` VARCHAR(40) NOT NULL UNIQUE,
        `property_id` INT NOT NULL,
        `kind` VARCHAR(6) NOT NULL,
        `holder_cid` VARCHAR(50) NOT NULL, `holder_name` VARCHAR(100) NULL, `holder_phone` VARCHAR(20) NULL,
        `price` INT NOT NULL DEFAULT 0,
        `rate` INT NOT NULL DEFAULT 0,
        `days` INT NOT NULL DEFAULT 0,
        `paid_total` INT NOT NULL DEFAULT 0,
        `method` VARCHAR(6) NULL,
        `started_at` DATETIME NOT NULL,
        `ends_at` DATETIME NULL,
        `status` VARCHAR(10) NOT NULL DEFAULT 'active',
        `employee_cid` VARCHAR(50) NULL, `employee_name` VARCHAR(100) NULL,
        `stash_id` VARCHAR(80) NULL,
        `ended_at` DATETIME NULL, `end_reason` VARCHAR(120) NULL,
        INDEX (`property_id`), INDEX (`holder_cid`), INDEX (`status`) ) ]],
    d8_payments = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `txid` VARCHAR(40) NOT NULL UNIQUE,
        `contract_id` INT NULL, `property_id` INT NOT NULL,
        `kind` VARCHAR(10) NOT NULL,
        `amount` INT NOT NULL,
        `days` INT NULL,
        `method` VARCHAR(6) NULL,
        `payer_cid` VARCHAR(50) NULL, `payer_name` VARCHAR(100) NULL,
        `employee_name` VARCHAR(100) NULL,
        `status` VARCHAR(10) NOT NULL,
        `note` VARCHAR(160) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`contract_id`), INDEX (`property_id`) ) ]],
    d8_access = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `contract_id` INT NOT NULL, `property_id` INT NOT NULL,
        `cid` VARCHAR(50) NOT NULL, `name` VARCHAR(100) NULL,
        `can_stash` TINYINT(1) NOT NULL DEFAULT 0,
        `can_manage` TINYINT(1) NOT NULL DEFAULT 0,
        `can_garage` TINYINT(1) NOT NULL DEFAULT 0,
        `added_by` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY `contract_cid` (`contract_id`, `cid`), INDEX (`cid`) ) ]],
    d8_vehicles = [[ (
        `vehicle_id` INT NOT NULL PRIMARY KEY,
        `property_id` INT NOT NULL,
        `slot` INT NOT NULL,
        `plate` VARCHAR(15) NULL, `model` VARCHAR(50) NULL,
        `owner_cid` VARCHAR(50) NULL,
        `stored_by` VARCHAR(100) NULL,
        `stored_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY `property_slot` (`property_id`, `slot`) ) ]],
    d8_deco = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `property_id` INT NOT NULL,
        `contract_id` INT NULL,
        `interior_id` INT NULL,
        `model` VARCHAR(60) NOT NULL,
        `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL,
        `rx` DOUBLE NOT NULL DEFAULT 0, `ry` DOUBLE NOT NULL DEFAULT 0, `rz` DOUBLE NOT NULL DEFAULT 0,
        `stored` TINYINT(1) NOT NULL DEFAULT 0,
        `placed_by` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`property_id`) ) ]],
    d8_visits = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `property_id` INT NOT NULL,
        `employee_cid` VARCHAR(50) NULL, `employee_name` VARCHAR(100) NULL,
        `clients` VARCHAR(255) NULL,
        `started_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `ended_at` DATETIME NULL, `end_reason` VARCHAR(60) NULL,
        INDEX (`property_id`) ) ]],
    d8_property_log = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `property_id` INT NOT NULL,
        `action` VARCHAR(40) NOT NULL,
        `details` VARCHAR(255) NULL,
        `actor_name` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`property_id`) ) ]],
}
P.TableOrder = { 'd8_settings', 'd8_grades', 'd8_employees', 'd8_admin_log', 'd8_sessions', 'd8_rates', 'd8_transactions',
    'd8_interiors', 'd8_properties', 'd8_contracts', 'd8_payments', 'd8_access', 'd8_vehicles', 'd8_deco', 'd8_visits', 'd8_property_log' }

local function InitDb()
    for _, name in ipairs(P.TableOrder) do
        Q(('CREATE TABLE IF NOT EXISTS `%s` %s DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'):format(name, P.Tables[name]))
    end
    -- Base d'avant les agences : tout ce qui existe appartient à la première agence
    P.AddJobColumns({ 'd8_grades', 'd8_employees' }, { 'd8_admin_log', 'd8_transactions', 'd8_contracts' }, 'd8_grades')
    pcall(function() core:ToUtf8mb4(P.TableOrder) end)
end

-- ---------------------------------------------------------------------
-- Grades
-- ---------------------------------------------------------------------
local function DecodePerms(raw)
    local ok, list = pcall(json.decode, raw or '[]')
    local set = {}
    for _, k in ipairs(ok and type(list) == 'table' and list or {}) do if D8PermSet[k] then set[k] = true end end
    return set
end
function P.EncodePerms(set)
    local list = {}
    for _, p in ipairs(D8Perms) do if set[p.key] then list[#list + 1] = p.key end end
    return json.encode(list)
end

-- Grades d'une agence (job), du plus bas au plus haut
function P.SortedGrades(job)
    local list = {}
    for _, g in pairs(P.grades) do if not job or g.job == job then list[#list + 1] = g end end
    table.sort(list, function(a, b) return a.level < b.level end)
    return list
end
function P.DefaultGrade(job)
    local sorted = P.SortedGrades(job)
    for _, g in ipairs(sorted) do if g.isDefault then return g end end
    return sorted[1]
end
function P.GradeByLevel(job, level)
    for _, g in pairs(P.grades) do if g.job == job and g.level == level then return g end end
end
function P.TopLevel(job)
    local top = 0
    for _, g in pairs(P.grades) do if g.job == job and g.level > top then top = g.level end end
    return top
end

function P.LoadGrades()
    P.grades = {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `d8_grades`') or {}) do
        P.grades[r.id] = { id = r.id, job = r.job, name = r.name, level = r.level, salary = r.salary, perms = DecodePerms(r.perms), isDefault = r.is_default == 1 or r.is_default == true,
            active = not (r.active == 0 or r.active == false) }
    end
end

function P.SeedGrades(job)
    for _, g in ipairs(Config.DefaultGrades) do
        local set = {}
        if g.perms == 'all' then for _, p in ipairs(D8Perms) do set[p.key] = true end
        else for _, k in ipairs(g.perms or {}) do set[k] = true end end
        local id = MySQL.insert.await('INSERT INTO `d8_grades` (`job`, `name`, `level`, `salary`, `perms`, `is_default`) VALUES (?, ?, ?, ?, ?, ?)',
            { job, g.name, g.level, g.salary or 0, P.EncodePerms(set), g.default and 1 or 0 })
        if id then MySQL.insert.await('INSERT INTO `d8_rates` (`grade_id`, `grade_name`, `rate`, `actor_name`) VALUES (?, ?, ?, ?)', { id, g.name, g.salary or 0, 'Installation' }) end
    end
    print(('^2[D8] Grades par défaut créés pour %s.^0'):format(job))
end

-- Grade « Directeur » toujours présent : l'ancien grade « Direction » est renommé,
-- sinon un grade Directeur (toutes les permissions) est créé au-dessus des autres.
local function EnsureDirecteur(job)
    for _, g in pairs(P.grades) do if g.job == job and g.name == 'Directeur' then return end end
    for _, g in pairs(P.grades) do
        if g.job == job and g.name == 'Direction' then
            MySQL.update.await('UPDATE `d8_grades` SET `name` = ? WHERE `id` = ?', { 'Directeur', g.id })
            g.name = 'Directeur'
            print('^2[D8] Grade « Direction » renommé « Directeur ».^0')
            return
        end
    end
    local set = {}
    for _, p in ipairs(D8Perms) do set[p.key] = true end
    local level = P.TopLevel(job) + 1
    local id = MySQL.insert.await('INSERT INTO `d8_grades` (`job`, `name`, `level`, `salary`, `perms`, `is_default`) VALUES (?, ?, ?, ?, ?, 0)',
        { job, 'Directeur', level, 1400, P.EncodePerms(set) })
    if id then
        MySQL.insert.await('INSERT INTO `d8_rates` (`grade_id`, `grade_name`, `rate`, `actor_name`) VALUES (?, ?, ?, ?)', { id, 'Directeur', 1400, 'Installation' })
        P.grades[id] = { id = id, job = job, name = 'Directeur', level = level, salary = 1400, perms = set, isDefault = false, active = true }
        print(('^2[D8] Grade « Directeur » créé (niveau %d) pour %s.^0'):format(level, job))
    end
end

P.EnsureDirecteur = EnsureDirecteur

-- Métier d'elyzea_core : un grade du core par niveau ; payment = 0 (la direction paie les heures dans Finance)
function P.SyncCoreJob(job)
    if not job then
        for _, a in ipairs(P.agencyList) do P.SyncCoreJob(a.job) end
        return
    end
    local grades = {}
    local top = P.TopLevel(job)
    for _, g in pairs(P.grades) do
        if g.job == job then grades[g.level] = { name = g.name, payment = 0, isboss = g.perms.direction == true or g.level == top } end
    end
    if not grades[0] then grades[0] = { name = 'Sans grade', payment = 0 } end
    local ok, err = pcall(function()
        core:CreateJob(job, { label = P.AgencyLabel(job), type = Config.Job.type, defaultDuty = false, offDutyPay = false, grades = grades })
    end)
    if not ok then print(('^1[D8] Métier « %s » non déclaré dans elyzea_core : %s^0'):format(job, tostring(err))) end
end

-- ---------------------------------------------------------------------
-- Employés
-- ---------------------------------------------------------------------
function P.LoadEmployees()
    P.employees = {}
    for _, r in ipairs(MySQL.query.await([[SELECT `citizenid`, `job`, `name`, `matricule`, `grade_id`, `note`, `total_seconds`, `unpaid_seconds`, `unpaid_amount`,
        DATE_FORMAT(`recruited_at`, '%d/%m/%Y') AS recruited, DATE_FORMAT(`promoted_at`, '%d/%m/%Y') AS promoted FROM `d8_employees`]]) or {}) do
        r.total_seconds, r.unpaid_seconds, r.unpaid_amount = tonumber(r.total_seconds) or 0, tonumber(r.unpaid_seconds) or 0, tonumber(r.unpaid_amount) or 0
        P.employees[r.citizenid] = r
    end
end

-- Préfixe de l'agence ; numéro suivant le plus grand déjà donné avec ce préfixe (toutes agences)
function P.NextMatricule(job)
    local max = 0
    local a = P.Agency(job)
    local prefix = a and a.mat or Config.Matricule.prefix
    for _, e in pairs(P.employees) do
        local m = tostring(e.matricule)
        local n = m:sub(1, #prefix) == prefix and tonumber(m:sub(#prefix + 1)) or nil
        if n and n > max then max = n end
    end
    return ('%s%0' .. Config.Matricule.digits .. 'd'):format(prefix, max + 1)
end

function P.Employee(src) local cid = P.Cid(src) return cid and P.employees[cid] or nil end
function P.GradeOfCid(cid) local e = P.employees[cid] return e and P.grades[e.grade_id] or nil end
function P.Grade(src) local cid = P.Cid(src) return cid and P.GradeOfCid(cid) or nil end

-- Membre du métier : métier dans le core ET fiche d'employé
function P.IsDynasty(src)
    local p = P.GetPlayer(src)
    if not p or not p.PlayerData.job then return false end
    local e = P.employees[p.PlayerData.citizenid]
    return e ~= nil and e.job == p.PlayerData.job.name and P.agencies[e.job] ~= nil
end
   -- nom gardé pour le code commun avec la police
function P.OnDuty(src) return P.duty[tonumber(src) or -1] == true end

function P.Can(src, perm)
    if not P.IsDynasty(src) then return false end
    local g = P.Grade(src)
    return g ~= nil and g.perms[perm] == true
end

-- job : agence concernée (sinon celle de l'employé visé, ou celle de l'auteur)
function P.AddLog(actorSrc, targetCid, targetName, action, oldGrade, newGrade, reason, job)
    local aCid, aName
    if type(actorSrc) == 'number' and actorSrc > 0 then aCid, aName = P.Cid(actorSrc), P.Name(actorSrc)
    elseif type(actorSrc) == 'string' then aName = actorSrc end
    job = job or (targetCid and P.JobOf(targetCid)) or (type(actorSrc) == 'number' and actorSrc > 0 and P.MyJob(actorSrc)) or nil
    MySQL.insert('INSERT INTO `d8_admin_log` (`job`, `actor_cid`, `actor_name`, `target_cid`, `target_name`, `action`, `old_grade`, `new_grade`, `reason`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { job, aCid, aName, targetCid, targetName, action, oldGrade, newGrade, reason and P.Clean(reason, 255) or nil })
end

-- Applique un grade (base Dynasty 8 + elyzea_core), connecté ou non.
-- Le temps de service en cours est d'abord compté au taux de l'ancien grade (Finance).
P.applying = {}
function P.ApplyGrade(cid, grade)
    local e = P.employees[cid]
    if not e or not grade then return false end
    if P.FlushCid then P.FlushCid(cid) end
    e.grade_id = grade.id
    MySQL.update.await('UPDATE `d8_employees` SET `grade_id` = ?, `promoted_at` = NOW() WHERE `citizenid` = ?', { grade.id, cid })
    P.applying[cid] = true
    pcall(function() core:AddPlayerToJob(cid, e.job, grade.level) end)
    P.applying[cid] = nil
    local src = core:GetSourceByCitizenId(cid)
    if src then
        if P.OnDuty(src) then
            local p = P.GetPlayer(src)
            if p then pcall(function() p.Functions.SetJobDuty(true) end) end
        end
        P.PushState(src)
    end
    return true
end

function P.Hire(cid, name, grade)
    if P.employees[cid] then return false, 'Déjà employé de Dynasty 8.' end
    local job = grade.job
    local mat = P.NextMatricule(job)
    MySQL.insert.await('INSERT INTO `d8_employees` (`citizenid`, `job`, `name`, `matricule`, `grade_id`) VALUES (?, ?, ?, ?, ?)', { cid, job, name, mat, grade.id })
    P.employees[cid] = { citizenid = cid, job = job, name = name, matricule = mat, grade_id = grade.id, recruited = os.date('%d/%m/%Y'),
        total_seconds = 0, unpaid_seconds = 0, unpaid_amount = 0 }
    P.applying[cid] = true
    pcall(function() core:AddPlayerToJob(cid, job, grade.level) end)
    P.applying[cid] = nil
    local src = core:GetSourceByCitizenId(cid)
    if src then P.PushState(src) end
    return true, mat
end

-- Retire un employé. Le temps dû non payé est gardé dans d8_sessions / l'historique,
-- mais la fiche disparaît : la direction doit payer AVANT de renvoyer (rappelé dans la tablette).
function P.Remove(cid)
    local e = P.employees[cid]
    if not e then return false end
    local src = core:GetSourceByCitizenId(cid)
    if src and P.OnDuty(src) and P.SetDuty then P.SetDuty(src, false, true) end
    P.employees[cid] = nil
    MySQL.update.await('DELETE FROM `d8_employees` WHERE `citizenid` = ?', { cid })
    P.applying[cid] = true
    pcall(function() core:RemovePlayerFromJob(cid, e.job) end)
    P.applying[cid] = nil
    if src then P.PushState(src) end
    return true
end

-- Mutation vers une autre agence (grade de la nouvelle agence) : nouveau matricule,
-- service terminé (temps compté au taux de l'ancien grade), salaire dû conservé
function P.Transfer(cid, grade)
    local e = P.employees[cid]
    if not e or not grade or e.job == grade.job then return false end
    local src = core:GetSourceByCitizenId(cid)
    if src and P.OnDuty(src) and P.SetDuty then P.SetDuty(src, false, true) end
    if P.FlushCid then P.FlushCid(cid) end
    local mat = P.NextMatricule(grade.job)
    MySQL.update.await('UPDATE `d8_employees` SET `job` = ?, `grade_id` = ?, `matricule` = ? WHERE `citizenid` = ?', { grade.job, grade.id, mat, cid })
    e.job, e.grade_id, e.matricule = grade.job, grade.id, mat
    P.applying[cid] = true
    pcall(function() core:AddPlayerToJob(cid, grade.job, grade.level) end)
    P.applying[cid] = nil
    if src then P.PushState(src) end
    return true, mat
end

-- ---------------------------------------------------------------------
-- État publié au client (affichage seulement : le serveur revérifie tout)
-- ---------------------------------------------------------------------
function P.PushState(src)
    if not GetPlayerName(src) then return end
    if not P.IsDynasty(src) then
        if Player(src).state.d8 ~= nil then Player(src).state:set('d8', nil, true) end
        return
    end
    local e, g = P.Employee(src), P.Grade(src)
    local a = P.Agency(e.job) or {}
    local perms = {}
    for k in pairs(g and g.perms or {}) do perms[k] = true end
    Player(src).state:set('d8', {
        job = e.job, agency = a.label or Config.Job.label, short = a.short, color = a.color,
        matricule = e.matricule, name = P.Name(src), grade = g and g.name or '?', level = g and g.level or 0, perms = perms,
        duty = P.OnDuty(src), status = P.status[src] or 'available',
    }, true)
end

function P.PushAll()
    for src in pairs(core:GetPlayers()) do P.PushState(src) end
end

-- ---------------------------------------------------------------------
-- Changements de métier faits ailleurs (menu admin, /setjob…)
-- ---------------------------------------------------------------------
-- Le métier du core est celui d'une agence : fiche créée, mutée ou mise au bon grade
local function FollowCoreJob(src, cid, job)
    local level = job.grade and job.grade.level or 0
    local grade = P.GradeByLevel(job.name, level) or P.DefaultGrade(job.name)
    if not grade then return end
    local e = P.employees[cid]
    if not e then
        P.Hire(cid, P.Name(src), grade)
        P.AddLog('Système', cid, P.Name(src), 'Recrutement', nil, grade.name, 'Métier donné hors de la tablette')
    elseif e.job ~= job.name then
        local before = P.grades[e.grade_id]
        local from = P.AgencyLabel(e.job)
        P.Transfer(cid, grade)
        P.AddLog('Système', cid, P.Name(src), 'Mutation', before and before.name, grade.name, ('%s → %s (hors de la tablette)'):format(from, P.AgencyLabel(job.name)))
    elseif e.grade_id ~= grade.id then
        local before = P.grades[e.grade_id]
        P.ApplyGrade(cid, grade)
        P.AddLog('Système', cid, P.Name(src), 'Changement de grade', before and before.name, grade.name, 'Grade changé hors de la tablette')
    end
end

AddEventHandler('elyzea:server:onJobUpdate', function(src, job, old)
    local cid = P.Cid(src)
    if not cid or P.applying[cid] or not P.ready then return end
    if job and P.IsAgencyJob(job.name) then
        FollowCoreJob(src, cid, job)
    elseif old and P.IsAgencyJob(old.name) and P.employees[cid] then
        if P.OnDuty(src) and P.SetDuty then P.SetDuty(src, false, true) end
        P.AddLog('Système', cid, P.Name(src), 'Départ', nil, nil, 'Métier changé hors de la tablette')
        P.employees[cid] = nil
        MySQL.update('DELETE FROM `d8_employees` WHERE `citizenid` = ?', { cid })
    end
    P.PushState(src)
end)

AddEventHandler('elyzea:server:playerLoaded', function(src)
    -- Toujours hors service à la connexion
    local p = P.GetPlayer(src)
    if p and p.PlayerData.job and P.IsAgencyJob(p.PlayerData.job.name) then
        if p.PlayerData.job.onduty then pcall(function() p.Functions.SetJobDuty(false) end) end
        -- Métier changé pendant que la ressource était arrêtée : on suit
        local cid = p.PlayerData.citizenid
        if P.ready and P.employees[cid] and P.employees[cid].job ~= p.PlayerData.job.name then FollowCoreJob(src, cid, p.PlayerData.job) end
    end
    P.PushState(src)
end)

-- ---------------------------------------------------------------------
-- Requêtes du client (tablette, F6, ALT) : un seul point d'entrée
-- ---------------------------------------------------------------------
local rate = {}
local function Allowed(src)
    local now = GetGameTimer()
    local r = rate[src]
    if not r or now - r.t > 1000 then rate[src] = { t = now, n = 1 } return true end
    r.n = r.n + 1
    return r.n <= 12
end

Ely.callback.register('d8:req', function(src, action, data)
    if not P.ready then return { error = 'Le métier démarre, réessayez dans un instant.' } end
    if not Allowed(src) then return { error = 'Trop de demandes, patientez une seconde.' } end
    local a = P.Actions[tostring(action)]
    if not a then return { error = 'Action inconnue.' } end
    if a.perm ~= false then
        if not P.IsDynasty(src) then return { error = 'Réservé aux employés Dynasty 8.' } end
        if a.perm and not P.Can(src, a.perm) then return { error = 'Votre grade ne permet pas cette action.' } end
        if a.duty and not P.OnDuty(src) then return { error = 'Prenez votre service pour faire cela.' } end
    end
    local ok, res = pcall(a.fn, src, type(data) == 'table' and data or {})
    if not ok then
        print(('^1[D8] Erreur « %s » : %s^0'):format(tostring(action), tostring(res)))
        return { error = 'Erreur serveur.' }
    end
    return res or {}
end)

-- Données de départ du client (config publique)
P.Actions.init = { perm = false, fn = function(src)
    local statuses = {}
    for _, s in ipairs(Config.Statuses) do statuses[#statuses + 1] = s end
    return { perms = D8Perms, statuses = statuses, propStatuses = Config.PropertyStatuses, categories = Config.Categories,
        garageSizes = Config.GarageSizes, map = Config.MapImage, mapRefresh = Config.MapRefresh, job = P.AgencyLabel(P.MyJob(src) or P.MainJob()),
        rent = Config.Rent, codeLength = Config.CodeLength, deco = Config.Deco, visitMinutes = Config.Visit.maxMinutes }
end }

-- ---------------------------------------------------------------------
-- Démarrage
-- ---------------------------------------------------------------------
CreateThread(function()
    InitDb()
    local ok, err = pcall(function()
        for _, r in ipairs(MySQL.query.await('SELECT `k`, `v` FROM `d8_settings`') or {}) do
            local okj, v = pcall(json.decode, r.v)
            if okj then P.Settings[r.k] = v end
        end
        P.LoadAgencies(true)
        P.LoadGrades()
        for _, a in ipairs(P.agencyList) do
            local has = false
            for _, g in pairs(P.grades) do if g.job == a.job then has = true break end end
            if not has then P.SeedGrades(a.job) end
        end
        P.LoadGrades()
        for _, a in ipairs(P.agencyList) do EnsureDirecteur(a.job) end
        P.LoadEmployees()
    end)
    if not ok then print(('^1[D8] Chargement impossible : %s^0'):format(tostring(err))) return end
    P.SyncCoreJob()
    if P.OnReady then for _, fn in ipairs(P.OnReady) do pcall(fn) end end
    P.ready = true
    for src, p in pairs(core:GetPlayers()) do
        if p.PlayerData.job and P.IsAgencyJob(p.PlayerData.job.name) and p.PlayerData.job.onduty then pcall(function() p.Functions.SetJobDuty(false) end) end
        P.PushState(src)
    end
    local n = 0
    for _ in pairs(P.employees) do n = n + 1 end
    print(('^2[D8] Prêt : %d agence(s), %d grade(s), %d employé(s).^0'):format(#P.agencyList, #P.SortedGrades(), n))
end)

AddEventHandler('playerDropped', function() rate[source] = nil end)
