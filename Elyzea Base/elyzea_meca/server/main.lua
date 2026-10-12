-- =====================================================================
--  ELYZEA MÉCANO - serveur : base de données, grades, employés, permissions
--  · La base mécano (meca_grades, meca_employees) est la référence ; le métier
--    « mechanic » d'elyzea_core est reconstruit à partir d'elle (grade = niveau).
--  · Chaque requête du client passe par Meca.Actions : permission, service et
--    limite de fréquence vérifiés ici. Le client ne décide jamais d'un droit.
-- =====================================================================
Meca = {
    grades = {},        -- [id] = { id, name, level, salary (taux horaire actuel), perms = {key=true}, isDefault }
    employees = {},     -- [citizenid] = { citizenid, name, matricule, grade_id, total_seconds, unpaid_seconds, unpaid_amount, … }
    duty = {},          -- [src] = true
    status = {},        -- [src] = 'available' | …
    Actions = {},       -- [nom] = { perm, duty, fn(src, data) }
    ready = false,
}
local P = Meca
local core = exports.elyzea_core
local JOB = Config.Job.name

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
        if pcall(function() exports.admin_menu:AddLog(src, '[MECA] ' .. action, details) end) then return end
    end
    print(('^5[MECA]^7 %s | %s | %s'):format(src and P.Name(src) or 'Système', action, details or ''))
end

-- Réglages persistants (garage, réglages…) : table meca_settings (clé → JSON)
P.Settings = {}
function P.GetSetting(key, default)
    local v = P.Settings[key]
    if v == nil then return default end
    return v
end
function P.SetSetting(key, value)
    P.Settings[key] = value
    MySQL.query.await('INSERT INTO `meca_settings` (`k`, `v`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `v` = VALUES(`v`)', { key, json.encode(value) })
end

-- ---------------------------------------------------------------------
-- Base de données
-- ---------------------------------------------------------------------
local function Q(sql)
    local ok, err = pcall(MySQL.query.await, sql)
    if not ok then print(('^1[MECA] Table non créée : %s^0'):format(tostring(err))) end
end
local function HasColumn(tbl, col)
    return tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = ? AND COLUMN_NAME = ?]], { tbl, col })) or 0
end
local function TableExists(tbl)
    return (tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?]], { tbl })) or 0) > 0
end
-- Table du même nom laissée par un ancien script (autre structure) : renommée en « _ancien », rien n'est supprimé
local function MoveOldTable(tbl, col)
    local ok, err = pcall(function()
        if not TableExists(tbl) or HasColumn(tbl, col) > 0 then return end
        local target, n = tbl .. '_ancien', 1
        while TableExists(target) do n = n + 1 target = ('%s_ancien%d'):format(tbl, n) end
        MySQL.query.await(('RENAME TABLE `%s` TO `%s`'):format(tbl, target))
        print(('^3[MECA] Ancienne table « %s » (autre structure) renommée en « %s ».^0'):format(tbl, target))
    end)
    if not ok then print(('^1[MECA] Vérification de « %s » impossible : %s^0'):format(tbl, tostring(err))) end
end

P.Tables = {
    meca_settings = [[ (
        `k` VARCHAR(50) NOT NULL PRIMARY KEY,
        `v` LONGTEXT NOT NULL ) ]],
    meca_grades = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(50) NOT NULL UNIQUE,
        `level` INT NOT NULL UNIQUE,
        `salary` INT NOT NULL DEFAULT 0,
        `perms` TEXT NOT NULL,
        `is_default` TINYINT(1) NOT NULL DEFAULT 0,
        `active` TINYINT(1) NOT NULL DEFAULT 1 ) ]],
    meca_employees = [[ (
        `citizenid` VARCHAR(50) NOT NULL PRIMARY KEY,
        `name` VARCHAR(100) NOT NULL,
        `matricule` VARCHAR(20) NOT NULL UNIQUE,
        `grade_id` INT NOT NULL,
        `recruited_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `promoted_at` DATETIME NULL,
        `note` VARCHAR(255) NULL,
        `total_seconds` INT NOT NULL DEFAULT 0,
        `unpaid_seconds` INT NOT NULL DEFAULT 0,
        `unpaid_amount` DOUBLE NOT NULL DEFAULT 0 ) ]],
    meca_admin_log = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `actor_cid` VARCHAR(50) NULL, `actor_name` VARCHAR(100) NULL,
        `target_cid` VARCHAR(50) NULL, `target_name` VARCHAR(100) NULL,
        `action` VARCHAR(40) NOT NULL,
        `old_grade` VARCHAR(50) NULL, `new_grade` VARCHAR(50) NULL,
        `reason` VARCHAR(255) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`target_cid`) ) ]],
    meca_sessions = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `citizenid` VARCHAR(50) NOT NULL, `name` VARCHAR(100) NULL,
        `grade_name` VARCHAR(50) NULL,
        `started_at` DATETIME NOT NULL, `ended_at` DATETIME NULL,
        `seconds` INT NOT NULL DEFAULT 0,
        `amount` DOUBLE NOT NULL DEFAULT 0,
        `end_reason` VARCHAR(30) NULL,
        INDEX (`citizenid`) ) ]],
    meca_rates = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `grade_id` INT NOT NULL, `grade_name` VARCHAR(50) NULL,
        `rate` INT NOT NULL,
        `actor_name` VARCHAR(100) NULL,
        `effective_from` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`grade_id`) ) ]],
    meca_transactions = [[ (
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
    meca_catalog = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `code` VARCHAR(40) NOT NULL UNIQUE,
        `name` VARCHAR(80) NOT NULL,
        `description` VARCHAR(255) NULL,
        `category` VARCHAR(20) NOT NULL,
        `kind` VARCHAR(12) NOT NULL,
        `mod_key` VARCHAR(20) NULL,
        `level` INT NULL,
        `price` INT NOT NULL DEFAULT 0,
        `enabled` TINYINT(1) NOT NULL DEFAULT 1,
        `min_level` INT NOT NULL DEFAULT 1,
        `compat` VARCHAR(120) NULL,
        `sort` INT NOT NULL DEFAULT 0,
        `updated_by` VARCHAR(100) NULL,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP ) ]],
    meca_quotes = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `uid` VARCHAR(40) NOT NULL UNIQUE,
        `customer_cid` VARCHAR(50) NULL, `customer_name` VARCHAR(100) NULL,
        `vehicle_id` INT NULL, `plate` VARCHAR(15) NULL, `model` VARCHAR(60) NULL,
        `mechanic_cid` VARCHAR(50) NULL, `mechanic_name` VARCHAR(100) NULL,
        `workshop` VARCHAR(40) NULL,
        `items` LONGTEXT NOT NULL,
        `total` INT NOT NULL,
        `paid` INT NOT NULL DEFAULT 0,
        `refunded` INT NOT NULL DEFAULT 0,
        `method` VARCHAR(6) NULL,
        `status` VARCHAR(12) NOT NULL,
        `invoice_uid` VARCHAR(40) NULL,
        `tow_id` INT NULL,
        `note` VARCHAR(255) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` DATETIME NULL,
        INDEX (`customer_cid`), INDEX (`vehicle_id`), INDEX (`status`) ) ]],
    meca_invoices = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `uid` VARCHAR(40) NOT NULL UNIQUE,
        `quote_uid` VARCHAR(40) NOT NULL UNIQUE,
        `customer_cid` VARCHAR(50) NULL, `customer_name` VARCHAR(100) NULL,
        `vehicle_id` INT NULL, `plate` VARCHAR(15) NULL,
        `mechanic_name` VARCHAR(100) NULL,
        `items` LONGTEXT NOT NULL,
        `amount` INT NOT NULL,
        `status` VARCHAR(10) NOT NULL,
        `method` VARCHAR(6) NULL,
        `txid` VARCHAR(40) NULL,
        `note` VARCHAR(160) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` DATETIME NULL,
        INDEX (`customer_cid`), INDEX (`vehicle_id`) ) ]],
    meca_vehicle_history = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `vehicle_id` INT NULL, `plate` VARCHAR(15) NULL,
        `action` VARCHAR(40) NOT NULL,
        `details` VARCHAR(255) NULL,
        `ref` VARCHAR(40) NULL,
        `mechanic_cid` VARCHAR(50) NULL, `mechanic_name` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`vehicle_id`), INDEX (`plate`) ) ]],
    meca_carplay = [[ (
        `vehicle_id` INT NOT NULL PRIMARY KEY,
        `plate` VARCHAR(15) NULL,
        `invoice_uid` VARCHAR(40) NULL,
        `price` INT NOT NULL DEFAULT 0,
        `installed_by` VARCHAR(100) NULL,
        `installed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ) ]],
    meca_tow = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `source` VARCHAR(20) NOT NULL,
        `reason` VARCHAR(150) NOT NULL,
        `description` VARCHAR(255) NULL,
        `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL,
        `street` VARCHAR(120) NULL,
        `client_cid` VARCHAR(50) NULL, `client_name` VARCHAR(100) NULL, `client_phone` VARCHAR(20) NULL,
        `vehicle` VARCHAR(80) NULL, `plate` VARCHAR(15) NULL,
        `status` VARCHAR(12) NOT NULL DEFAULT 'pending',
        `assigned_cid` VARCHAR(50) NULL, `assigned_name` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `closed_at` DATETIME NULL,
        INDEX (`status`) ) ]],
    meca_tow_log = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `tow_id` INT NOT NULL,
        `status` VARCHAR(12) NOT NULL,
        `actor_name` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`tow_id`) ) ]],
}
P.TableOrder = { 'meca_settings', 'meca_grades', 'meca_employees', 'meca_admin_log', 'meca_sessions', 'meca_rates', 'meca_transactions',
    'meca_catalog', 'meca_quotes', 'meca_invoices', 'meca_vehicle_history', 'meca_carplay', 'meca_tow', 'meca_tow_log' }

local function InitDb()
    for _, name in ipairs(P.TableOrder) do pcall(CheckTable, name) end
    for _, name in ipairs(P.TableOrder) do
        Q(('CREATE TABLE IF NOT EXISTS `%s` %s DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'):format(name, P.Tables[name]))
    end
    pcall(function() core:ToUtf8mb4(P.TableOrder) end)
end

-- ---------------------------------------------------------------------
-- Grades
-- ---------------------------------------------------------------------
local function DecodePerms(raw)
    local ok, list = pcall(json.decode, raw or '[]')
    local set = {}
    for _, k in ipairs(ok and type(list) == 'table' and list or {}) do if MecaPermSet[k] then set[k] = true end end
    return set
end
function P.EncodePerms(set)
    local list = {}
    for _, p in ipairs(MecaPerms) do if set[p.key] then list[#list + 1] = p.key end end
    return json.encode(list)
end

function P.SortedGrades()
    local list = {}
    for _, g in pairs(P.grades) do list[#list + 1] = g end
    table.sort(list, function(a, b) return a.level < b.level end)
    return list
end
function P.DefaultGrade()
    local sorted = P.SortedGrades()
    for _, g in ipairs(sorted) do if g.isDefault then return g end end
    return sorted[1]
end
function P.GradeByLevel(level)
    for _, g in pairs(P.grades) do if g.level == level then return g end end
end
function P.TopLevel()
    local top = 0
    for _, g in pairs(P.grades) do if g.level > top then top = g.level end end
    return top
end

function P.LoadGrades()
    P.grades = {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `meca_grades`') or {}) do
        P.grades[r.id] = { id = r.id, name = r.name, level = r.level, salary = r.salary, perms = DecodePerms(r.perms), isDefault = r.is_default == 1 or r.is_default == true,
            active = not (r.active == 0 or r.active == false) }
    end
end

local function SeedGrades()
    for _, g in ipairs(Config.DefaultGrades) do
        local set = {}
        if g.perms == 'all' then for _, p in ipairs(MecaPerms) do set[p.key] = true end
        else for _, k in ipairs(g.perms or {}) do set[k] = true end end
        local id = MySQL.insert.await('INSERT INTO `meca_grades` (`name`, `level`, `salary`, `perms`, `is_default`) VALUES (?, ?, ?, ?, ?)',
            { g.name, g.level, g.salary or 0, P.EncodePerms(set), g.default and 1 or 0 })
        if id then MySQL.insert.await('INSERT INTO `meca_rates` (`grade_id`, `grade_name`, `rate`, `actor_name`) VALUES (?, ?, ?, ?)', { id, g.name, g.salary or 0, 'Installation' }) end
    end
    print('^2[MECA] Grades par défaut créés.^0')
end

-- Grade « Directeur » toujours présent : l'ancien grade « Direction » est renommé,
-- sinon un grade Directeur (toutes les permissions) est créé au-dessus des autres.
local function EnsureDirecteur()
    for _, g in pairs(P.grades) do if g.name == 'Directeur' then return end end
    for _, g in pairs(P.grades) do
        if g.name == 'Direction' then
            MySQL.update.await('UPDATE `meca_grades` SET `name` = ? WHERE `id` = ?', { 'Directeur', g.id })
            g.name = 'Directeur'
            print('^2[MECA] Grade « Direction » renommé « Directeur ».^0')
            return
        end
    end
    local set = {}
    for _, p in ipairs(MecaPerms) do set[p.key] = true end
    local level = P.TopLevel() + 1
    local id = MySQL.insert.await('INSERT INTO `meca_grades` (`name`, `level`, `salary`, `perms`, `is_default`) VALUES (?, ?, ?, ?, 0)',
        { 'Directeur', level, 1400, P.EncodePerms(set) })
    if id then
        MySQL.insert.await('INSERT INTO `meca_rates` (`grade_id`, `grade_name`, `rate`, `actor_name`) VALUES (?, ?, ?, ?)', { id, 'Directeur', 1400, 'Installation' })
        P.grades[id] = { id = id, name = 'Directeur', level = level, salary = 1400, perms = set, isDefault = false, active = true }
        print(('^2[MECA] Grade « Directeur » créé (niveau %d).^0'):format(level))
    end
end

-- Métier d'elyzea_core : un grade du core par niveau ; payment = 0 (la direction paie les heures dans Finance)
function P.SyncCoreJob()
    local grades = {}
    local top = P.TopLevel()
    for _, g in pairs(P.grades) do
        grades[g.level] = { name = g.name, payment = 0, isboss = g.perms.direction == true or g.level == top }
    end
    if not grades[0] then grades[0] = { name = 'Sans grade', payment = 0 } end
    local ok, err = pcall(function()
        core:CreateJob(JOB, { label = Config.Job.label, type = Config.Job.type, defaultDuty = false, offDutyPay = false, grades = grades })
    end)
    if not ok then print(('^1[MECA] Métier non déclaré dans elyzea_core : %s^0'):format(tostring(err))) end
end

-- ---------------------------------------------------------------------
-- Employés
-- ---------------------------------------------------------------------
function P.LoadEmployees()
    P.employees = {}
    for _, r in ipairs(MySQL.query.await([[SELECT `citizenid`, `name`, `matricule`, `grade_id`, `note`, `total_seconds`, `unpaid_seconds`, `unpaid_amount`,
        DATE_FORMAT(`recruited_at`, '%d/%m/%Y') AS recruited, DATE_FORMAT(`promoted_at`, '%d/%m/%Y') AS promoted FROM `meca_employees`]]) or {}) do
        r.total_seconds, r.unpaid_seconds, r.unpaid_amount = tonumber(r.total_seconds) or 0, tonumber(r.unpaid_seconds) or 0, tonumber(r.unpaid_amount) or 0
        P.employees[r.citizenid] = r
    end
end

function P.NextMatricule()
    local max = 0
    local prefix = Config.Matricule.prefix
    for _, e in pairs(P.employees) do
        local n = tonumber(tostring(e.matricule):sub(#prefix + 1))
        if n and n > max then max = n end
    end
    return ('%s%0' .. Config.Matricule.digits .. 'd'):format(prefix, max + 1)
end

function P.Employee(src) local cid = P.Cid(src) return cid and P.employees[cid] or nil end
function P.GradeOfCid(cid) local e = P.employees[cid] return e and P.grades[e.grade_id] or nil end
function P.Grade(src) local cid = P.Cid(src) return cid and P.GradeOfCid(cid) or nil end

-- Membre du métier : métier dans le core ET fiche d'employé
function P.IsMeca(src)
    local p = P.GetPlayer(src)
    return p ~= nil and p.PlayerData.job and p.PlayerData.job.name == JOB and P.employees[p.PlayerData.citizenid] ~= nil
end
   -- nom gardé pour le code commun avec la police
function P.OnDuty(src) return P.duty[tonumber(src) or -1] == true end

function P.Can(src, perm)
    if not P.IsMeca(src) then return false end
    local g = P.Grade(src)
    return g ~= nil and g.perms[perm] == true
end

function P.AddLog(actorSrc, targetCid, targetName, action, oldGrade, newGrade, reason)
    local aCid, aName
    if type(actorSrc) == 'number' and actorSrc > 0 then aCid, aName = P.Cid(actorSrc), P.Name(actorSrc)
    elseif type(actorSrc) == 'string' then aName = actorSrc end
    MySQL.insert('INSERT INTO `meca_admin_log` (`actor_cid`, `actor_name`, `target_cid`, `target_name`, `action`, `old_grade`, `new_grade`, `reason`) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { aCid, aName, targetCid, targetName, action, oldGrade, newGrade, reason and P.Clean(reason, 255) or nil })
end

-- Applique un grade (base mécano + elyzea_core), connecté ou non.
-- Le temps de service en cours est d'abord compté au taux de l'ancien grade (Finance).
P.applying = {}
function P.ApplyGrade(cid, grade)
    local e = P.employees[cid]
    if not e or not grade then return false end
    if P.FlushCid then P.FlushCid(cid) end
    e.grade_id = grade.id
    MySQL.update.await('UPDATE `meca_employees` SET `grade_id` = ?, `promoted_at` = NOW() WHERE `citizenid` = ?', { grade.id, cid })
    P.applying[cid] = true
    pcall(function() core:AddPlayerToJob(cid, JOB, grade.level) end)
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
    if P.employees[cid] then return false, 'Déjà employé du garage.' end
    local mat = P.NextMatricule()
    MySQL.insert.await('INSERT INTO `meca_employees` (`citizenid`, `name`, `matricule`, `grade_id`) VALUES (?, ?, ?, ?)', { cid, name, mat, grade.id })
    P.employees[cid] = { citizenid = cid, name = name, matricule = mat, grade_id = grade.id, recruited = os.date('%d/%m/%Y'),
        total_seconds = 0, unpaid_seconds = 0, unpaid_amount = 0 }
    P.applying[cid] = true
    pcall(function() core:AddPlayerToJob(cid, JOB, grade.level) end)
    P.applying[cid] = nil
    local src = core:GetSourceByCitizenId(cid)
    if src then P.PushState(src) end
    return true, mat
end

-- Retire un employé. Le temps dû non payé est gardé dans meca_sessions / l'historique,
-- mais la fiche disparaît : la direction doit payer AVANT de renvoyer (rappelé dans la tablette).
function P.Remove(cid)
    local e = P.employees[cid]
    if not e then return false end
    local src = core:GetSourceByCitizenId(cid)
    if src and P.OnDuty(src) and P.SetDuty then P.SetDuty(src, false, true) end
    P.employees[cid] = nil
    MySQL.update.await('DELETE FROM `meca_employees` WHERE `citizenid` = ?', { cid })
    P.applying[cid] = true
    pcall(function() core:RemovePlayerFromJob(cid, JOB) end)
    P.applying[cid] = nil
    if src then P.PushState(src) end
    return true
end

-- ---------------------------------------------------------------------
-- État publié au client (affichage seulement : le serveur revérifie tout)
-- ---------------------------------------------------------------------
function P.PushState(src)
    if not GetPlayerName(src) then return end
    if not P.IsMeca(src) then
        if Player(src).state.meca ~= nil then Player(src).state:set('meca', nil, true) end
        return
    end
    local e, g = P.Employee(src), P.Grade(src)
    local perms = {}
    for k in pairs(g and g.perms or {}) do perms[k] = true end
    Player(src).state:set('meca', {
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
AddEventHandler('elyzea:server:onJobUpdate', function(src, job, old)
    local cid = P.Cid(src)
    if not cid or P.applying[cid] or not P.ready then return end
    if job and job.name == JOB then
        local level = job.grade and job.grade.level or 0
        local grade = P.GradeByLevel(level) or P.DefaultGrade()
        if not P.employees[cid] then
            P.Hire(cid, P.Name(src), grade)
            P.AddLog('Système', cid, P.Name(src), 'Recrutement', nil, grade.name, 'Métier donné hors de la tablette')
        elseif P.employees[cid].grade_id ~= grade.id then
            local before = P.grades[P.employees[cid].grade_id]
            P.ApplyGrade(cid, grade)
            P.AddLog('Système', cid, P.Name(src), 'Changement de grade', before and before.name, grade.name, 'Grade changé hors de la tablette')
        end
    elseif old and old.name == JOB and P.employees[cid] then
        if P.OnDuty(src) and P.SetDuty then P.SetDuty(src, false, true) end
        P.employees[cid] = nil
        MySQL.update('DELETE FROM `meca_employees` WHERE `citizenid` = ?', { cid })
        P.AddLog('Système', cid, P.Name(src), 'Départ', nil, nil, 'Métier changé hors de la tablette')
    end
    P.PushState(src)
end)

AddEventHandler('elyzea:server:playerLoaded', function(src)
    -- Toujours hors service à la connexion (pas de temps de service fantôme)
    local p = P.GetPlayer(src)
    if p and p.PlayerData.job and p.PlayerData.job.name == JOB and p.PlayerData.job.onduty then
        pcall(function() p.Functions.SetJobDuty(false) end)
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

Ely.callback.register('meca:req', function(src, action, data)
    if not P.ready then return { error = 'Le métier démarre, réessayez dans un instant.' } end
    if not Allowed(src) then return { error = 'Trop de demandes, patientez une seconde.' } end
    local a = P.Actions[tostring(action)]
    if not a then return { error = 'Action inconnue.' } end
    if a.perm ~= false then
        if not P.IsMeca(src) then return { error = 'Réservé aux mécaniciens.' } end
        if a.perm and not P.Can(src, a.perm) then return { error = 'Votre grade ne permet pas cette action.' } end
        if a.duty and not P.OnDuty(src) then return { error = 'Prenez votre service pour faire cela.' } end
    end
    local ok, res = pcall(a.fn, src, type(data) == 'table' and data or {})
    if not ok then
        print(('^1[MECA] Erreur « %s » : %s^0'):format(tostring(action), tostring(res)))
        return { error = 'Erreur serveur.' }
    end
    return res or {}
end)

-- Données de départ du client (config publique)
P.Actions.init = { perm = false, fn = function()
    local statuses = {}
    for _, s in ipairs(Config.Statuses) do statuses[#statuses + 1] = s end
    return { perms = MecaPerms, statuses = statuses, towStatuses = Config.Tow.statuses,
        map = Config.MapImage, mapRefresh = Config.MapRefresh, job = Config.Job.label, repair = Config.Repair, towCommand = Config.Tow.command }
end }

-- ---------------------------------------------------------------------
-- Démarrage
-- ---------------------------------------------------------------------
CreateThread(function()
    InitDb()
    local ok, err = pcall(function()
        for _, r in ipairs(MySQL.query.await('SELECT `k`, `v` FROM `meca_settings`') or {}) do
            local okj, v = pcall(json.decode, r.v)
            if okj then P.Settings[r.k] = v end
        end
        P.LoadGrades()
        if not next(P.grades) then SeedGrades() P.LoadGrades() end
        EnsureDirecteur()
        P.LoadEmployees()
    end)
    if not ok then print(('^1[MECA] Chargement impossible : %s^0'):format(tostring(err))) return end
    P.SyncCoreJob()
    if P.OnReady then for _, fn in ipairs(P.OnReady) do pcall(fn) end end
    P.ready = true
    for src, p in pairs(core:GetPlayers()) do
        if p.PlayerData.job and p.PlayerData.job.name == JOB and p.PlayerData.job.onduty then pcall(function() p.Functions.SetJobDuty(false) end) end
        P.PushState(src)
    end
    local n = 0
    for _ in pairs(P.employees) do n = n + 1 end
    print(('^2[MECA] Prêt : %d grade(s), %d employé(s).^0'):format(#P.SortedGrades(), n))
end)

AddEventHandler('playerDropped', function() rate[source] = nil end)
