-- =====================================================================
--  ELYZEA EMS - serveur : base de données, grades, employés, permissions
--  · La base EMS (ems_grades, ems_employees) est la référence ; le métier
--    « ambulance » d'elyzea_core est reconstruit à partir d'elle (grade = niveau).
--  · Chaque requête du client passe par Ems.Actions : permission, service et
--    limite de fréquence vérifiés ici. Le client ne décide jamais d'un droit.
-- =====================================================================
Ems = {
    grades = {},        -- [id] = { id, name, level, salary (taux horaire actuel), perms = {key=true}, isDefault }
    employees = {},     -- [citizenid] = { citizenid, name, matricule, grade_id, total_seconds, unpaid_seconds, unpaid_amount, … }
    duty = {},          -- [src] = true
    status = {},        -- [src] = 'available' | …
    Actions = {},       -- [nom] = { perm, duty, fn(src, data) }
    ready = false,
}
local P = Ems
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
        if pcall(function() exports.admin_menu:AddLog(src, '[EMS] ' .. action, details) end) then return end
    end
    print(('^5[EMS]^7 %s | %s | %s'):format(src and P.Name(src) or 'Système', action, details or ''))
end

-- Réglages persistants (tarifs, PPA, garage…) : table ems_settings (clé → JSON)
P.Settings = {}
function P.GetSetting(key, default)
    local v = P.Settings[key]
    if v == nil then return default end
    return v
end
function P.SetSetting(key, value)
    P.Settings[key] = value
    MySQL.query.await('INSERT INTO `ems_settings` (`k`, `v`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `v` = VALUES(`v`)', { key, json.encode(value) })
end

-- ---------------------------------------------------------------------
-- Base de données
-- ---------------------------------------------------------------------
local function Q(sql)
    local ok, err = pcall(MySQL.query.await, sql)
    if not ok then print(('^1[EMS] Table non créée : %s^0'):format(tostring(err))) end
end
local function HasColumn(tbl, col)
    return tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = ? AND COLUMN_NAME = ?]], { tbl, col })) or 0
end
local function TableExists(tbl)
    return (tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?]], { tbl })) or 0) > 0
end
-- Table du même nom laissée par l'ancien EMS (autre structure) : renommée en « _ancien », rien n'est supprimé
local function MoveOldTable(tbl, col)
    local ok, err = pcall(function()
        if not TableExists(tbl) or HasColumn(tbl, col) > 0 then return end
        local target, n = tbl .. '_ancien', 1
        while TableExists(target) do n = n + 1 target = ('%s_ancien%d'):format(tbl, n) end
        MySQL.query.await(('RENAME TABLE `%s` TO `%s`'):format(tbl, target))
        print(('^3[EMS] Ancienne table « %s » (autre structure) renommée en « %s ».^0'):format(tbl, target))
    end)
    if not ok then print(('^1[EMS] Vérification de « %s » impossible : %s^0'):format(tbl, tostring(err))) end
end

P.Tables = {
    ems_settings = [[ (
        `k` VARCHAR(50) NOT NULL PRIMARY KEY,
        `v` LONGTEXT NOT NULL ) ]],
    ems_grades = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(50) NOT NULL UNIQUE,
        `level` INT NOT NULL UNIQUE,
        `salary` INT NOT NULL DEFAULT 0,
        `perms` TEXT NOT NULL,
        `is_default` TINYINT(1) NOT NULL DEFAULT 0 ) ]],
    ems_employees = [[ (
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
    ems_admin_log = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `actor_cid` VARCHAR(50) NULL, `actor_name` VARCHAR(100) NULL,
        `target_cid` VARCHAR(50) NULL, `target_name` VARCHAR(100) NULL,
        `action` VARCHAR(40) NOT NULL,
        `old_grade` VARCHAR(50) NULL, `new_grade` VARCHAR(50) NULL,
        `reason` VARCHAR(255) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`target_cid`) ) ]],
    ems_sessions = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `citizenid` VARCHAR(50) NOT NULL, `name` VARCHAR(100) NULL,
        `grade_name` VARCHAR(50) NULL,
        `started_at` DATETIME NOT NULL, `ended_at` DATETIME NULL,
        `seconds` INT NOT NULL DEFAULT 0,
        `amount` DOUBLE NOT NULL DEFAULT 0,
        `end_reason` VARCHAR(30) NULL,
        INDEX (`citizenid`) ) ]],
    ems_rates = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `grade_id` INT NOT NULL, `grade_name` VARCHAR(50) NULL,
        `rate` INT NOT NULL,
        `actor_name` VARCHAR(100) NULL,
        `effective_from` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`grade_id`) ) ]],
    ems_transactions = [[ (
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
    ems_calls = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `source` VARCHAR(20) NOT NULL,
        `reason` VARCHAR(150) NOT NULL,
        `urgency` TINYINT NOT NULL DEFAULT 2,
        `info` VARCHAR(255) NULL,
        `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL,
        `street` VARCHAR(120) NULL,
        `caller_cid` VARCHAR(50) NULL, `caller_name` VARCHAR(100) NULL,
        `patient_cid` VARCHAR(50) NULL, `patient_name` VARCHAR(100) NULL,
        `status` VARCHAR(12) NOT NULL DEFAULT 'pending',
        `assigned_cid` VARCHAR(50) NULL, `assigned_name` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `closed_at` DATETIME NULL,
        INDEX (`status`), INDEX (`patient_cid`) ) ]],
    ems_call_log = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `call_id` INT NOT NULL,
        `status` VARCHAR(12) NOT NULL,
        `actor_name` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`call_id`) ) ]],
    ems_support = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `level` VARCHAR(10) NOT NULL,
        `description` VARCHAR(200) NULL,
        `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL,
        `street` VARCHAR(120) NULL,
        `author_cid` VARCHAR(50) NULL, `author_name` VARCHAR(100) NULL,
        `status` VARCHAR(10) NOT NULL DEFAULT 'active',
        `closed_by` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `closed_at` DATETIME NULL ) ]],
    ems_treatments = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `patient_cid` VARCHAR(50) NOT NULL, `patient_name` VARCHAR(100) NULL,
        `service` VARCHAR(20) NOT NULL,
        `ems_cid` VARCHAR(50) NULL, `ems_name` VARCHAR(100) NULL,
        `call_id` INT NULL,
        `invoice_uid` VARCHAR(40) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`patient_cid`), INDEX (`invoice_uid`) ) ]],
    ems_invoices = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `uid` VARCHAR(40) NOT NULL UNIQUE,
        `kind` VARCHAR(12) NOT NULL DEFAULT 'medical',
        `patient_cid` VARCHAR(50) NOT NULL, `patient_name` VARCHAR(100) NULL,
        `ems_cid` VARCHAR(50) NULL, `ems_name` VARCHAR(100) NULL,
        `items` TEXT NULL,
        `mode` VARCHAR(10) NULL,
        `amount` INT NOT NULL,
        `status` VARCHAR(10) NOT NULL,
        `method` VARCHAR(6) NULL,
        `txid` VARCHAR(40) NULL,
        `note` VARCHAR(160) NULL,
        `handled_by` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` DATETIME NULL,
        INDEX (`patient_cid`), INDEX (`status`) ) ]],
    ems_ppa = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `uid` VARCHAR(40) NOT NULL UNIQUE,
        `citizenid` VARCHAR(50) NOT NULL, `name` VARCHAR(100) NULL,
        `type` VARCHAR(6) NOT NULL,
        `ems_cid` VARCHAR(50) NULL, `ems_name` VARCHAR(100) NULL, `ems_grade` VARCHAR(50) NULL,
        `price` INT NOT NULL,
        `invoice_uid` VARCHAR(40) NULL,
        `payment_status` VARCHAR(12) NOT NULL,
        `delivery_status` VARCHAR(12) NOT NULL,
        `number` VARCHAR(20) NULL,
        `reason` VARCHAR(160) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` DATETIME NULL,
        INDEX (`citizenid`), INDEX (`type`) ) ]],
    ems_patients = [[ (
        `citizenid` VARCHAR(50) NOT NULL PRIMARY KEY,
        `name` VARCHAR(100) NULL,
        `blood` VARCHAR(5) NULL,
        `allergies` VARCHAR(255) NULL,
        `notes` TEXT NULL,
        `updated_by` VARCHAR(100) NULL,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP ) ]],
    ems_reports = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `patient_cid` VARCHAR(50) NULL, `patient_name` VARCHAR(100) NULL,
        `call_id` INT NULL,
        `title` VARCHAR(120) NOT NULL,
        `crew` TEXT NULL,
        `started_at` DATETIME NULL, `ended_at` DATETIME NULL,
        `treatments` TEXT NULL,
        `transport` TINYINT(1) NOT NULL DEFAULT 0,
        `outcome` VARCHAR(40) NULL,
        `notes` TEXT NULL,
        `status` VARCHAR(10) NOT NULL DEFAULT 'open',
        `author_cid` VARCHAR(50) NOT NULL, `author_name` VARCHAR(100) NOT NULL, `author_matricule` VARCHAR(20) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX (`patient_cid`), INDEX (`status`) ) ]],
    ems_report_history = [[ (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `report_id` INT NOT NULL,
        `actor_name` VARCHAR(100) NULL,
        `action` VARCHAR(120) NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`report_id`) ) ]],
}
P.TableOrder = { 'ems_settings', 'ems_grades', 'ems_employees', 'ems_admin_log', 'ems_sessions', 'ems_rates', 'ems_transactions',
    'ems_calls', 'ems_call_log', 'ems_support', 'ems_treatments', 'ems_invoices', 'ems_ppa', 'ems_patients', 'ems_reports', 'ems_report_history' }

local function InitDb()
    MoveOldTable('ems_ppa', 'uid')
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
    for _, k in ipairs(ok and type(list) == 'table' and list or {}) do if EmsPermSet[k] then set[k] = true end end
    return set
end
function P.EncodePerms(set)
    local list = {}
    for _, p in ipairs(EmsPerms) do if set[p.key] then list[#list + 1] = p.key end end
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
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `ems_grades`') or {}) do
        P.grades[r.id] = { id = r.id, name = r.name, level = r.level, salary = r.salary, perms = DecodePerms(r.perms), isDefault = r.is_default == 1 or r.is_default == true }
    end
end

local function SeedGrades()
    for _, g in ipairs(Config.DefaultGrades) do
        local set = {}
        if g.perms == 'all' then for _, p in ipairs(EmsPerms) do set[p.key] = true end
        else for _, k in ipairs(g.perms or {}) do set[k] = true end end
        local id = MySQL.insert.await('INSERT INTO `ems_grades` (`name`, `level`, `salary`, `perms`, `is_default`) VALUES (?, ?, ?, ?, ?)',
            { g.name, g.level, g.salary or 0, P.EncodePerms(set), g.default and 1 or 0 })
        if id then MySQL.insert.await('INSERT INTO `ems_rates` (`grade_id`, `grade_name`, `rate`, `actor_name`) VALUES (?, ?, ?, ?)', { id, g.name, g.salary or 0, 'Installation' }) end
    end
    print('^2[EMS] Grades par défaut créés.^0')
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
    if not ok then print(('^1[EMS] Métier non déclaré dans elyzea_core : %s^0'):format(tostring(err))) end
end

-- ---------------------------------------------------------------------
-- Employés
-- ---------------------------------------------------------------------
function P.LoadEmployees()
    P.employees = {}
    for _, r in ipairs(MySQL.query.await([[SELECT `citizenid`, `name`, `matricule`, `grade_id`, `note`, `total_seconds`, `unpaid_seconds`, `unpaid_amount`,
        DATE_FORMAT(`recruited_at`, '%d/%m/%Y') AS recruited, DATE_FORMAT(`promoted_at`, '%d/%m/%Y') AS promoted FROM `ems_employees`]]) or {}) do
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

-- Membre de l'EMS : métier dans le core ET fiche d'employé
function P.IsEms(src)
    local p = P.GetPlayer(src)
    return p ~= nil and p.PlayerData.job and p.PlayerData.job.name == JOB and P.employees[p.PlayerData.citizenid] ~= nil
end
P.IsCop = P.IsEms   -- nom gardé pour le code commun avec la police
function P.OnDuty(src) return P.duty[tonumber(src) or -1] == true end

function P.Can(src, perm)
    if not P.IsEms(src) then return false end
    local g = P.Grade(src)
    return g ~= nil and g.perms[perm] == true
end

function P.AddLog(actorSrc, targetCid, targetName, action, oldGrade, newGrade, reason)
    local aCid, aName
    if type(actorSrc) == 'number' and actorSrc > 0 then aCid, aName = P.Cid(actorSrc), P.Name(actorSrc)
    elseif type(actorSrc) == 'string' then aName = actorSrc end
    MySQL.insert('INSERT INTO `ems_admin_log` (`actor_cid`, `actor_name`, `target_cid`, `target_name`, `action`, `old_grade`, `new_grade`, `reason`) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { aCid, aName, targetCid, targetName, action, oldGrade, newGrade, reason and P.Clean(reason, 255) or nil })
end

-- Applique un grade (base EMS + elyzea_core), connecté ou non.
-- Le temps de service en cours est d'abord compté au taux de l'ancien grade (Finance).
P.applying = {}
function P.ApplyGrade(cid, grade)
    local e = P.employees[cid]
    if not e or not grade then return false end
    if P.FlushCid then P.FlushCid(cid) end
    e.grade_id = grade.id
    MySQL.update.await('UPDATE `ems_employees` SET `grade_id` = ?, `promoted_at` = NOW() WHERE `citizenid` = ?', { grade.id, cid })
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
    if P.employees[cid] then return false, 'Déjà membre de l\'EMS.' end
    local mat = P.NextMatricule()
    MySQL.insert.await('INSERT INTO `ems_employees` (`citizenid`, `name`, `matricule`, `grade_id`) VALUES (?, ?, ?, ?)', { cid, name, mat, grade.id })
    P.employees[cid] = { citizenid = cid, name = name, matricule = mat, grade_id = grade.id, recruited = os.date('%d/%m/%Y'),
        total_seconds = 0, unpaid_seconds = 0, unpaid_amount = 0 }
    P.applying[cid] = true
    pcall(function() core:AddPlayerToJob(cid, JOB, grade.level) end)
    P.applying[cid] = nil
    local src = core:GetSourceByCitizenId(cid)
    if src then P.PushState(src) end
    return true, mat
end

-- Retire un employé. Le temps dû non payé est gardé dans ems_sessions / l'historique,
-- mais la fiche disparaît : la direction doit payer AVANT de renvoyer (rappelé dans la tablette).
function P.Remove(cid)
    local e = P.employees[cid]
    if not e then return false end
    local src = core:GetSourceByCitizenId(cid)
    if src and P.OnDuty(src) and P.SetDuty then P.SetDuty(src, false, true) end
    P.employees[cid] = nil
    MySQL.update.await('DELETE FROM `ems_employees` WHERE `citizenid` = ?', { cid })
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
    if not P.IsEms(src) then
        if Player(src).state.ems ~= nil then Player(src).state:set('ems', nil, true) end
        return
    end
    local e, g = P.Employee(src), P.Grade(src)
    local perms = {}
    for k in pairs(g and g.perms or {}) do perms[k] = true end
    Player(src).state:set('ems', {
        matricule = e.matricule, grade = g and g.name or '?', level = g and g.level or 0, perms = perms,
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
        MySQL.update('DELETE FROM `ems_employees` WHERE `citizenid` = ?', { cid })
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

Ely.callback.register('ems:req', function(src, action, data)
    if not P.ready then return { error = 'L\'EMS démarre, réessayez dans un instant.' } end
    if not Allowed(src) then return { error = 'Trop de demandes, patientez une seconde.' } end
    local a = P.Actions[tostring(action)]
    if not a then return { error = 'Action inconnue.' } end
    if a.perm ~= false then
        if not P.IsEms(src) then return { error = 'Réservé à l\'EMS.' } end
        if a.perm and not P.Can(src, a.perm) then return { error = 'Votre grade ne permet pas cette action.' } end
        if a.duty and not P.OnDuty(src) then return { error = 'Prenez votre service pour faire cela.' } end
    end
    local ok, res = pcall(a.fn, src, type(data) == 'table' and data or {})
    if not ok then
        print(('^1[EMS] Erreur « %s » : %s^0'):format(tostring(action), tostring(res)))
        return { error = 'Erreur serveur.' }
    end
    return res or {}
end)

-- Données de départ du client (config publique)
P.Actions.init = { perm = false, fn = function()
    local statuses = {}
    for _, s in ipairs(Config.Statuses) do statuses[#statuses + 1] = s end
    return { perms = EmsPerms, statuses = statuses, levels = Config.Support.levels, urgencies = Config.Calls.urgencies,
        callStatuses = Config.Calls.statuses, outcomes = Config.Reports.outcomes,
        map = Config.MapImage, mapRefresh = Config.MapRefresh, job = Config.Job.label, death = { hold = Config.Death.respawnHold } }
end }

-- ---------------------------------------------------------------------
-- Démarrage
-- ---------------------------------------------------------------------
CreateThread(function()
    InitDb()
    local ok, err = pcall(function()
        for _, r in ipairs(MySQL.query.await('SELECT `k`, `v` FROM `ems_settings`') or {}) do
            local okj, v = pcall(json.decode, r.v)
            if okj then P.Settings[r.k] = v end
        end
        P.LoadGrades()
        if not next(P.grades) then SeedGrades() P.LoadGrades() end
        P.LoadEmployees()
    end)
    if not ok then print(('^1[EMS] Chargement impossible : %s^0'):format(tostring(err))) return end
    P.SyncCoreJob()
    if P.OnReady then for _, fn in ipairs(P.OnReady) do pcall(fn) end end
    P.ready = true
    for src, p in pairs(core:GetPlayers()) do
        if p.PlayerData.job and p.PlayerData.job.name == JOB and p.PlayerData.job.onduty then pcall(function() p.Functions.SetJobDuty(false) end) end
        P.PushState(src)
    end
    local n = 0
    for _ in pairs(P.employees) do n = n + 1 end
    print(('^2[EMS] Prêt : %d grade(s), %d employé(s).^0'):format(#P.SortedGrades(), n))
end)

AddEventHandler('playerDropped', function() rate[source] = nil end)
