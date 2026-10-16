-- =====================================================================
--  ELYZEA POLICE - serveur : base de données, grades, employés, permissions
--  · La base police (police_grades, police_employees) est la référence ; le métier
--    de chaque agence dans elyzea_core est reconstruit à partir d'elle (grade = niveau hiérarchique).
--  · Plusieurs agences (elyzea_agences, server/agencies.lua) : chaque grade et chaque
--    employé appartient à une agence (colonne `job` = métier elyzea_core de l'agence).
--  · Chaque requête du client passe par Police.Actions : permission, données et
--    limite de fréquence vérifiées ici. Le client ne décide jamais d'un droit.
-- =====================================================================
Police = {
    grades = {},        -- [id] = { id, job, name, level, salary ($ par heure de service), perms = {key=true}, isDefault }
    employees = {},     -- [citizenid] = { citizenid, job, name, matricule, grade_id, recruited_at, promoted_at, note, service_seconds }
    duty = {},          -- [src] = true
    status = {},        -- [src] = 'available' | ...
    Actions = {},       -- [nom] = { perm, duty, fn(src, data) }
    ready = false,
}
local P = Police
local core = exports.elyzea_core
local DEF_JOB = Config.Job.name:gsub('[^%w_]', '')
P.T = { grades = 'police_grades', employees = 'police_employees' }

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
    if not v or v ~= v then return def end
    v = math.floor(v)
    if mn then v = math.max(mn, v) end
    if mx then v = math.min(mx, v) end
    return v
end

function P.Log(src, action, details)
    if GetResourceState('admin_menu') == 'started' then
        if pcall(function() exports.admin_menu:AddLog(src, '[Police] ' .. action, details) end) then return end
    end
    print(('^5[Police]^7 %s | %s | %s'):format(src and P.Name(src) or 'Système', action, details or ''))
end

-- ---------------------------------------------------------------------
-- Base de données
-- ---------------------------------------------------------------------
local function Q(sql)
    local ok, err = pcall(MySQL.query.await, sql)
    if not ok then print(('^1[Police] Table non créée : %s^0'):format(tostring(err))) end
end

-- Tables du même nom laissées par l'ancienne police (structure différente) :
-- renommées en « _ancien » (données gardées) pour créer les bonnes tables
local function HasColumn(tbl, col)
    return tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = ? AND COLUMN_NAME = ?]], { tbl, col })) or 0
end
local function TableExists(tbl)
    return (tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?]], { tbl })) or 0) > 0
end
local function MoveOldTable(tbl, col)
    local ok, err = pcall(function()
        if not TableExists(tbl) or HasColumn(tbl, col) > 0 then return end
        local target, n = tbl .. '_ancien', 1
        while TableExists(target) do n = n + 1 target = ('%s_ancien%d'):format(tbl, n) end
        MySQL.query.await(('RENAME TABLE `%s` TO `%s`'):format(tbl, target))
        print(('^3[Police] Ancienne table « %s » (autre structure) renommée en « %s ».^0'):format(tbl, target))
    end)
    if not ok then print(('^1[Police] Vérification de « %s » impossible : %s^0'):format(tbl, tostring(err))) end
end

local function InitDb()
    MoveOldTable('police_reports', 'title')
    MoveOldTable('police_fines', 'offense')
    Q(([[CREATE TABLE IF NOT EXISTS `police_grades` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `job` VARCHAR(40) NOT NULL DEFAULT '%s',
        `name` VARCHAR(50) NOT NULL,
        `level` INT NOT NULL,
        `salary` INT NOT NULL DEFAULT 0,
        `perms` TEXT NOT NULL,
        `is_default` TINYINT(1) NOT NULL DEFAULT 0,
        UNIQUE KEY `job_name` (`job`, `name`), UNIQUE KEY `job_level` (`job`, `level`)
    ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]]):format(DEF_JOB))
    Q(([[CREATE TABLE IF NOT EXISTS `police_employees` (
        `citizenid` VARCHAR(50) NOT NULL PRIMARY KEY,
        `job` VARCHAR(40) NOT NULL DEFAULT '%s',
        `name` VARCHAR(100) NOT NULL,
        `matricule` VARCHAR(20) NOT NULL UNIQUE,
        `grade_id` INT NOT NULL,
        `recruited_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `promoted_at` DATETIME NULL,
        `note` VARCHAR(255) NULL,
        `service_seconds` INT NOT NULL DEFAULT 0,
        INDEX (`job`)
    ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]]):format(DEF_JOB))
    Q([[CREATE TABLE IF NOT EXISTS `police_admin_log` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `actor_cid` VARCHAR(50) NULL, `actor_name` VARCHAR(100) NULL,
        `target_cid` VARCHAR(50) NULL, `target_name` VARCHAR(100) NULL,
        `action` VARCHAR(40) NOT NULL,
        `old_grade` VARCHAR(50) NULL, `new_grade` VARCHAR(50) NULL,
        `reason` VARCHAR(255) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`target_cid`)
    ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    Q([[CREATE TABLE IF NOT EXISTS `police_reports` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `title` VARCHAR(120) NOT NULL,
        `type` VARCHAR(40) NOT NULL,
        `people` TEXT NULL,
        `location` VARCHAR(120) NULL,
        `description` TEXT NULL,
        `observations` TEXT NULL,
        `attachments` TEXT NULL,
        `status` VARCHAR(20) NOT NULL DEFAULT 'open',
        `author_cid` VARCHAR(50) NOT NULL, `author_name` VARCHAR(100) NOT NULL, `author_matricule` VARCHAR(20) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX (`type`), INDEX (`status`), INDEX (`author_cid`)
    ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    Q([[CREATE TABLE IF NOT EXISTS `police_report_history` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `report_id` INT NOT NULL,
        `actor_name` VARCHAR(100) NULL,
        `action` VARCHAR(120) NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`report_id`)
    ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    Q([[CREATE TABLE IF NOT EXISTS `police_fines` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `citizenid` VARCHAR(50) NOT NULL, `name` VARCHAR(100) NOT NULL,
        `offense` VARCHAR(100) NOT NULL, `reason` VARCHAR(150) NULL, `description` VARCHAR(500) NULL,
        `amount` INT NOT NULL,
        `officer_cid` VARCHAR(50) NULL, `officer_name` VARCHAR(100) NULL, `officer_matricule` VARCHAR(20) NULL,
        `paid` TINYINT(1) NOT NULL DEFAULT 0,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`citizenid`)
    ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    Q([[CREATE TABLE IF NOT EXISTS `police_alerts` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `kind` VARCHAR(10) NOT NULL,
        `type` VARCHAR(20) NOT NULL,
        `title` VARCHAR(100) NULL, `description` VARCHAR(255) NULL,
        `x` FLOAT NOT NULL DEFAULT 0, `y` FLOAT NOT NULL DEFAULT 0, `z` FLOAT NOT NULL DEFAULT 0,
        `street` VARCHAR(120) NULL,
        `author_cid` VARCHAR(50) NULL, `author_name` VARCHAR(100) NULL,
        `status` VARCHAR(10) NOT NULL DEFAULT 'active',
        `closed_by` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `closed_at` DATETIME NULL,
        INDEX (`status`)
    ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    Q([[CREATE TABLE IF NOT EXISTS `police_wanted` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `citizenid` VARCHAR(50) NULL,
        `name` VARCHAR(100) NOT NULL,
        `reason` VARCHAR(150) NOT NULL,
        `description` TEXT NULL,
        `danger` TINYINT NOT NULL DEFAULT 1,
        `photo` VARCHAR(500) NULL,
        `status` VARCHAR(10) NOT NULL DEFAULT 'active',
        `author_cid` VARCHAR(50) NULL, `author_name` VARCHAR(100) NULL, `author_matricule` VARCHAR(20) NULL,
        `closed_by` VARCHAR(100) NULL, `close_reason` VARCHAR(150) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `closed_at` DATETIME NULL,
        INDEX (`citizenid`), INDEX (`status`)
    ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    -- Mise à jour d'une base créée avant la partie Finance
    if HasColumn('police_employees', 'service_seconds') == 0 then MySQL.query.await('ALTER TABLE `police_employees` ADD COLUMN `service_seconds` INT NOT NULL DEFAULT 0') end
    -- Mise à jour d'une base créée avant les agences : tout ce qui existe appartient à la première agence
    P.AddJobColumns({ 'police_grades', 'police_employees' }, { 'police_admin_log', 'police_alerts' }, 'police_grades')
    pcall(function() core:ToUtf8mb4({ 'police_grades', 'police_employees', 'police_admin_log', 'police_reports', 'police_report_history', 'police_fines', 'police_alerts', 'police_wanted' }) end)
end

-- ---------------------------------------------------------------------
-- Grades
-- ---------------------------------------------------------------------
local function DecodePerms(raw)
    local ok, list = pcall(json.decode, raw or '[]')
    local set = {}
    for _, k in ipairs(ok and type(list) == 'table' and list or {}) do if PolicePermSet[k] then set[k] = true end end
    return set
end
function P.EncodePerms(set)
    local list = {}
    for _, p in ipairs(PolicePerms) do if set[p.key] then list[#list + 1] = p.key end end
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
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `police_grades`') or {}) do
        P.grades[r.id] = { id = r.id, job = r.job, name = r.name, level = r.level, salary = r.salary, perms = DecodePerms(r.perms), isDefault = r.is_default == 1 or r.is_default == true }
    end
end

-- Permissions ajoutées après l'installation : si aucun grade ne l'a encore, elle est donnée
-- aux grades dont le grade par défaut de même niveau l'a dans la config, et au plus haut grade
local NEW_PERMS = { 'finance', 'search', 'wanted_view', 'wanted_manage', 'impound' }
function P.GrantNewPerms(job)
    if not job then
        for _, a in ipairs(P.agencyList) do P.GrantNewPerms(a.job) end
        return
    end
    local top = nil
    for _, g in pairs(P.grades) do if g.job == job and (not top or g.level > top.level) then top = g end end
    if not top then return end
    local changed = {}
    for _, perm in ipairs(NEW_PERMS) do
        local has = false
        for _, g in pairs(P.grades) do if g.job == job and g.perms[perm] then has = true break end end
        if not has then
            for _, g in pairs(P.grades) do if g.job == job then
                local give = g == top
                for _, d in ipairs(Config.DefaultGrades) do
                    if d.level == g.level then
                        if d.perms == 'all' then give = true
                        else for _, k in ipairs(d.perms or {}) do if k == perm then give = true end end end
                    end
                end
                if give then g.perms[perm] = true changed[g.id] = g end
            end end
        end
    end
    for _, g in pairs(changed) do
        MySQL.update.await('UPDATE `police_grades` SET `perms` = ? WHERE `id` = ?', { P.EncodePerms(g.perms), g.id })
    end
end

function P.SeedGrades(job)
    for _, g in ipairs(Config.DefaultGrades) do
        local set = {}
        if g.perms == 'all' then for _, p in ipairs(PolicePerms) do set[p.key] = true end
        else for _, k in ipairs(g.perms or {}) do set[k] = true end end
        MySQL.insert.await('INSERT INTO `police_grades` (`job`, `name`, `level`, `salary`, `perms`, `is_default`) VALUES (?, ?, ?, ?, ?, ?)',
            { job, g.name, g.level, g.salary or 0, P.EncodePerms(set), g.default and 1 or 0 })
    end
    print(('^2[Police] Grades par défaut créés pour %s (Cadet → Commissaire).^0'):format(job))
end

-- Métier de l'agence dans elyzea_core : un grade du core par niveau hiérarchique (job nil = toutes)
function P.SyncCoreJob(job)
    if not job then
        for _, a in ipairs(P.agencyList) do P.SyncCoreJob(a.job) end
        return
    end
    local grades = {}
    local top = P.TopLevel(job)
    for _, g in pairs(P.grades) do
        -- payment = 0 : pas de paie automatique du core, la direction paie les heures de service (Finance)
        if g.job == job then grades[g.level] = { name = g.name, payment = 0, isboss = g.perms.direction == true or g.level == top } end
    end
    if not grades[0] then grades[0] = { name = 'Sans grade', payment = 0 } end
    local ok, err = pcall(function()
        core:CreateJob(job, { label = P.AgencyLabel(job), type = Config.Job.type, defaultDuty = false, offDutyPay = false, grades = grades })
    end)
    if not ok then print(('^1[Police] Métier « %s » non déclaré dans elyzea_core : %s^0'):format(job, tostring(err))) end
end

-- ---------------------------------------------------------------------
-- Employés
-- ---------------------------------------------------------------------
function P.LoadEmployees()
    P.employees = {}
    for _, r in ipairs(MySQL.query.await([[SELECT `citizenid`, `job`, `name`, `matricule`, `grade_id`, `note`, `service_seconds`,
        DATE_FORMAT(`recruited_at`, '%d/%m/%Y') AS recruited, DATE_FORMAT(`promoted_at`, '%d/%m/%Y') AS promoted FROM `police_employees`]]) or {}) do
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

-- Membre de la police : métier d'une agence dans le core ET fiche d'employé de cette agence
function P.IsCop(src)
    local p = P.GetPlayer(src)
    if not p or not p.PlayerData.job then return false end
    local e = P.employees[p.PlayerData.citizenid]
    return e ~= nil and e.job == p.PlayerData.job.name and P.agencies[e.job] ~= nil
end
-- Même agence (job) que le joueur src ?
function P.SameAgency(src, job) return job ~= nil and P.MyJob(src) == job end
function P.OnDuty(src) return P.duty[tonumber(src) or -1] == true end

function P.Can(src, perm)
    if not P.IsCop(src) then return false end
    local g = P.Grade(src)
    return g ~= nil and g.perms[perm] == true
end

-- job : agence concernée (sinon celle de l'employé visé, ou celle de l'auteur)
function P.AddLog(actorSrc, targetCid, targetName, action, oldGrade, newGrade, reason, job)
    local aCid, aName
    if type(actorSrc) == 'number' and actorSrc > 0 then aCid, aName = P.Cid(actorSrc), P.Name(actorSrc)
    elseif type(actorSrc) == 'string' then aName = actorSrc end
    job = job or (targetCid and P.JobOf(targetCid)) or (type(actorSrc) == 'number' and actorSrc > 0 and P.MyJob(actorSrc)) or nil
    MySQL.insert('INSERT INTO `police_admin_log` (`job`, `actor_cid`, `actor_name`, `target_cid`, `target_name`, `action`, `old_grade`, `new_grade`, `reason`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { job, aCid, aName, targetCid, targetName, action, oldGrade, newGrade, reason and P.Clean(reason, 255) or nil })
end

-- Applique un grade à un employé (base police + elyzea_core), connecté ou non
P.applying = {}
function P.ApplyGrade(cid, grade)
    local e = P.employees[cid]
    if not e or not grade then return false end
    e.grade_id = grade.id
    MySQL.update.await('UPDATE `police_employees` SET `grade_id` = ? WHERE `citizenid` = ?', { grade.id, cid })
    P.applying[cid] = true
    pcall(function() core:AddPlayerToJob(cid, e.job, grade.level) end)
    P.applying[cid] = nil
    local src = core:GetSourceByCitizenId(cid)
    if src then
        -- Le changement de métier remet le service à zéro dans le core : on le garde
        if P.OnDuty(src) then
            local p = P.GetPlayer(src)
            if p then pcall(function() p.Functions.SetJobDuty(true) end) end
        end
        P.PushState(src)
    end
    return true
end

-- Crée la fiche d'un nouvel employé et lui donne le métier de l'agence du grade
function P.Hire(cid, name, grade)
    if P.employees[cid] then return false, 'Déjà dans la police.' end
    local job = grade.job
    local mat = P.NextMatricule(job)
    MySQL.insert.await('INSERT INTO `police_employees` (`citizenid`, `job`, `name`, `matricule`, `grade_id`) VALUES (?, ?, ?, ?, ?)', { cid, job, name, mat, grade.id })
    P.employees[cid] = { citizenid = cid, job = job, name = name, matricule = mat, grade_id = grade.id, recruited = os.date('%d/%m/%Y'), service_seconds = 0 }
    P.applying[cid] = true
    pcall(function() core:AddPlayerToJob(cid, job, grade.level) end)
    P.applying[cid] = nil
    local src = core:GetSourceByCitizenId(cid)
    if src then P.PushState(src) end
    return true, mat
end

-- Retire un employé (fiche supprimée, métier retiré, service terminé)
function P.Remove(cid)
    local e = P.employees[cid]
    if not e then return false end
    local src = core:GetSourceByCitizenId(cid)
    if src and P.OnDuty(src) and P.SetDuty then P.SetDuty(src, false, true) end
    P.employees[cid] = nil
    MySQL.update.await('DELETE FROM `police_employees` WHERE `citizenid` = ?', { cid })
    P.applying[cid] = true
    pcall(function() core:RemovePlayerFromJob(cid, e.job) end)
    P.applying[cid] = nil
    if src then P.PushState(src) end
    return true
end

-- Mutation vers une autre agence (grade de la nouvelle agence) : nouveau matricule,
-- service terminé, temps de service non payé conservé
function P.Transfer(cid, grade)
    local e = P.employees[cid]
    if not e or not grade or e.job == grade.job then return false end
    local src = core:GetSourceByCitizenId(cid)
    if src and P.OnDuty(src) and P.SetDuty then P.SetDuty(src, false, true) end
    local mat = P.NextMatricule(grade.job)
    MySQL.update.await('UPDATE `police_employees` SET `job` = ?, `grade_id` = ?, `matricule` = ? WHERE `citizenid` = ?', { grade.job, grade.id, mat, cid })
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
    if not P.IsCop(src) then
        if Player(src).state.police ~= nil then Player(src).state:set('police', nil, true) end
        return
    end
    local e, g = P.Employee(src), P.Grade(src)
    local a = P.Agency(e.job) or {}
    local perms = {}
    for k in pairs(g and g.perms or {}) do perms[k] = true end
    Player(src).state:set('police', {
        matricule = e.matricule, grade = g and g.name or '?', level = g and g.level or 0, perms = perms,
        duty = P.OnDuty(src), status = P.status[src] or 'available',
        job = e.job, agency = a.label or Config.Job.label, short = a.short, color = a.color,
    }, true)
end

function P.PushAll()
    for src in pairs(core:GetPlayers()) do P.PushState(src) end
end

-- ---------------------------------------------------------------------
-- Synchronisation avec les changements de métier faits ailleurs (menu admin, /setjob…)
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
        MySQL.update('DELETE FROM `police_employees` WHERE `citizenid` = ?', { cid })
    end
    P.PushState(src)
end)

AddEventHandler('elyzea:server:playerLoaded', function(src)
    -- Toujours hors service à la connexion (pas d'agent fantôme)
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
-- Requêtes du client (tablette, F6…) : un seul point d'entrée
-- ---------------------------------------------------------------------
local rate = {}
local function Allowed(src)
    local now = GetGameTimer()
    local r = rate[src]
    if not r or now - r.t > 1000 then rate[src] = { t = now, n = 1 } return true end
    r.n = r.n + 1
    return r.n <= 12
end

Ely.callback.register('police:req', function(src, action, data)
    if not P.ready then return { error = 'La police démarre, réessayez dans un instant.' } end
    if not Allowed(src) then return { error = 'Trop de demandes, patientez une seconde.' } end
    local a = P.Actions[tostring(action)]
    if not a then return { error = 'Action inconnue.' } end
    if a.perm ~= false then
        if not P.IsCop(src) then return { error = 'Réservé à la police.' } end
        if a.perm and not P.Can(src, a.perm) then return { error = 'Votre grade ne permet pas cette action.' } end
        if a.duty and not P.OnDuty(src) then return { error = 'Prenez votre service pour faire cela.' } end
    end
    local ok, res = pcall(a.fn, src, type(data) == 'table' and data or {})
    if not ok then
        print(('^1[Police] Erreur « %s » : %s^0'):format(tostring(action), tostring(res)))
        return { error = 'Erreur serveur.' }
    end
    return res or {}
end)

-- Données de départ du client (config publique)
P.Actions.init = { perm = false, fn = function(src)
    local statuses = {}
    for _, s in ipairs(Config.Statuses) do statuses[#statuses + 1] = s end
    return { perms = PolicePerms, statuses = statuses, offenses = Config.Fines.offenses, maxFine = Config.Fines.maxAmount,
        levels = Config.AgentAlerts.levels, reportTypes = Config.Reports.types, maxAttachments = Config.Reports.maxAttachments,
        map = Config.MapImage, mapRefresh = Config.MapRefresh, job = P.AgencyLabel(P.MyJob(src) or P.MainJob()) }
end }

-- ---------------------------------------------------------------------
-- Démarrage
-- ---------------------------------------------------------------------
CreateThread(function()
    InitDb()
    local ok, err = pcall(function()
        P.LoadAgencies(true)
        P.LoadGrades()
        for _, a in ipairs(P.agencyList) do
            local has = false
            for _, g in pairs(P.grades) do if g.job == a.job then has = true break end end
            if not has then P.SeedGrades(a.job) end
        end
        P.LoadGrades()
        P.LoadEmployees()
        P.GrantNewPerms()
    end)
    if not ok then print(('^1[Police] Chargement impossible : %s^0'):format(tostring(err))) return end
    P.SyncCoreJob()
    P.ready = true
    -- Ressource redémarrée : tout le monde hors service, états republiés
    for src, p in pairs(core:GetPlayers()) do
        if p.PlayerData.job and P.IsAgencyJob(p.PlayerData.job.name) and p.PlayerData.job.onduty then pcall(function() p.Functions.SetJobDuty(false) end) end
        P.PushState(src)
    end
    local n = 0
    for _ in pairs(P.employees) do n = n + 1 end
    print(('^2[Police] Prête : %d agence(s), %d grade(s), %d employé(s).^0'):format(#P.agencyList, #P.SortedGrades(), n))
end)

AddEventHandler('playerDropped', function() rate[source] = nil end)
