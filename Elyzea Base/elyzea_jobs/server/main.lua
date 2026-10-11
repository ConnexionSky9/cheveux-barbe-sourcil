-- =====================================================================
--  ELYZEA JOBS · serveur : entreprises, grades, accès, journal
--  Source unique des grades (noms, salaires, accès) des 5 métiers principaux.
--  Les grades sont déclarés dans elyzea_core (CreateJobs) : pas de hiérarchie parallèle.
-- =====================================================================
J = { companies = {}, specs = {}, ready = false }
local core = exports.elyzea_core

local MAIN = {}
for _, j in ipairs(Config.MainJobs) do MAIN[j] = true end

-- ---------------------------------------------------------------------
-- Utilitaires
-- ---------------------------------------------------------------------
function J.Copy(t)
    if type(t) ~= 'table' then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = J.Copy(v) end
    return r
end

function J.Player(src) return core:GetPlayer(src) end

function J.Cid(src)
    local p = J.Player(src)
    return p and p.PlayerData.citizenid or nil
end

function J.Name(src)
    local ok, n = pcall(function() return core:GetCharName(src) end)
    return ok and n or (GetPlayerName(src) or ('ID ' .. tostring(src)))
end

function J.Notify(src, msg, kind) core:Notify(src, msg, kind or 'inform') end

function J.Dist(a, b)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if pa == 0 or pb == 0 then return 9999.0 end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb))
end

local function PermDefs(job)
    local c = Config.Companies[job]
    local list = {}
    for _, p in ipairs(Config.CommonPerms) do list[#list + 1] = p end
    for _, p in ipairs(c and c.perms or {}) do list[#list + 1] = p end
    return list
end
J.PermDefs = PermDefs

local function PermSet(job)
    local s = {}
    for _, p in ipairs(PermDefs(job)) do s[p.id] = true end
    return s
end
J.PermSet = PermSet

-- Accès par défaut d'un grade (niveau lvl, niveau du haut top)
local function DefaultPerms(job, lvl, top)
    local out = {}
    for _, p in ipairs(PermDefs(job)) do
        local need = (p.min or 0) >= 0 and (p.min or 0) or (top + p.min)
        out[p.id] = lvl >= need
    end
    return out
end

local function EnsurePerms(job)
    local c = J.companies[job]
    if not c then return end
    local top = #c.grades - 1
    for i, g in ipairs(c.grades) do
        if type(g.perms) ~= 'table' then g.perms = {} end
        local def = DefaultPerms(job, i - 1, top)
        for id, v in pairs(def) do if g.perms[id] == nil then g.perms[id] = v end end
        for id in pairs(g.perms) do if def[id] == nil then g.perms[id] = nil end end   -- accès retirés de la config
    end
end

-- ---------------------------------------------------------------------
-- Base de données
-- ---------------------------------------------------------------------
local function InitDatabase()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `elyzea_jobs` (
        `job` VARCHAR(50) NOT NULL PRIMARY KEY,
        `label` VARCHAR(80) NOT NULL,
        `type` VARCHAR(30) NULL,
        `grades` LONGTEXT NOT NULL,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `elyzea_jobs_logs` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `job` VARCHAR(50) NOT NULL,
        `kind` VARCHAR(30) NOT NULL,
        `actor_cid` VARCHAR(50) NULL, `actor_name` VARCHAR(100) NULL,
        `target_cid` VARCHAR(50) NULL, `target_name` VARCHAR(100) NULL,
        `amount` BIGINT NULL,
        `details` VARCHAR(255) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX `job_date` (`job`, `created_at`)
    ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `elyzea_jobs_specialties` (
        `citizenid` VARCHAR(50) NOT NULL,
        `job` VARCHAR(50) NOT NULL,
        `spec` VARCHAR(50) NOT NULL,
        `given_by` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`, `job`, `spec`)
    ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    pcall(function() core:ToUtf8mb4({ 'elyzea_jobs', 'elyzea_jobs_logs', 'elyzea_jobs_specialties' }) end)
end

function J.Save(job)
    local c = J.companies[job]
    if not c then return end
    local grades = {}
    for i, g in ipairs(c.grades) do
        grades[i] = { name = g.name, payment = g.payment, isboss = g.isboss == true, perms = g.perms }
    end
    MySQL.query.await('INSERT INTO `elyzea_jobs` (`job`, `label`, `type`, `grades`) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE `label` = VALUES(`label`), `type` = VALUES(`type`), `grades` = VALUES(`grades`)',
        { job, c.label, c.type, json.encode(grades) })
end

-- Journal (RH, finances, grades…)
function J.Log(job, kind, actor, target, amount, details)
    local aCid, aName, tCid, tName
    if type(actor) == 'number' and actor > 0 then aCid, aName = J.Cid(actor), J.Name(actor)
    elseif type(actor) == 'table' then aCid, aName = actor.cid, actor.name end
    if type(target) == 'number' and target > 0 then tCid, tName = J.Cid(target), J.Name(target)
    elseif type(target) == 'table' then tCid, tName = target.cid, target.name end
    MySQL.insert('INSERT INTO `elyzea_jobs_logs` (`job`, `kind`, `actor_cid`, `actor_name`, `target_cid`, `target_name`, `amount`, `details`) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { job, kind, aCid, aName, tCid, tName, amount and math.floor(amount) or nil, details and tostring(details):sub(1, 255) or nil })
    if GetResourceState('admin_menu') == 'started' and type(actor) == 'number' then
        pcall(function() exports.admin_menu:AddLog(actor, ('[%s] %s'):format(Config.Companies[job] and Config.Companies[job].label or job, kind), details) end)
    end
end

-- ---------------------------------------------------------------------
-- Déclaration dans elyzea_core
-- ---------------------------------------------------------------------
function J.Apply(job)
    local c = J.companies[job]
    if not c then return end
    local grades = {}
    for i, g in ipairs(c.grades) do
        grades[i - 1] = { name = g.name, payment = math.floor(tonumber(g.payment) or 0), isboss = g.isboss or nil, bankAuth = g.isboss or nil }
    end
    J.applying = true
    local ok, err = pcall(function()
        core:CreateJobs({ [job] = { label = c.label, type = c.type, defaultDuty = false, offDutyPay = false, grades = grades } })
    end)
    J.applying = false
    if not ok then print(('^1[elyzea_jobs] Impossible de déclarer le métier %s : %s^0'):format(job, tostring(err))) end
    TriggerEvent('elyzea_jobs:companyChanged', job)
    TriggerClientEvent('elyzea_jobs:companyChanged', -1, job)
end

-- Grades depuis une définition elyzea_core ({ [niveau] = {name, payment, isboss} })
local function GradesFromCore(def)
    local list, top = {}, -1
    for lvl in pairs(def.grades or {}) do top = math.max(top, tonumber(lvl) or -1) end
    for lvl = 0, top do
        local g = def.grades[lvl] or def.grades[tostring(lvl)] or {}
        list[#list + 1] = { name = tostring(g.name or g.label or ('Grade ' .. lvl)), payment = math.floor(tonumber(g.payment or g.salary) or 0), isboss = g.isboss == true }
    end
    if #list == 0 then list = { { name = 'Employé', payment = 50 }, { name = 'Patron', payment = 150, isboss = true } } end
    local anyBoss = false
    for _, g in ipairs(list) do if g.isboss then anyBoss = true end end
    if not anyBoss then list[#list].isboss = true end
    return list
end

local function NewCompany(job, label, ctype, grades)
    J.companies[job] = { job = job, label = Config.Companies[job].label or label or job, type = ctype, grades = grades }
    EnsurePerms(job)
end

-- Première installation : une ressource métier propose sa définition (utilisée seulement si rien n'est enregistré)
function J.Seed(job, def)
    if not Config.Companies[job] or J.companies[job] or type(def) ~= 'table' then return false end
    NewCompany(job, def.label, def.type, GradesFromCore(def))
    J.Save(job)
    J.Apply(job)
    print(('^2[elyzea_jobs] %s : grades repris de %s (%d grades).^0'):format(job, GetInvokingResource() or '?', #J.companies[job].grades))
    return true
end

-- ---------------------------------------------------------------------
-- Chargement
-- ---------------------------------------------------------------------
local function Load()
    InitDatabase()
    local rows = MySQL.query.await('SELECT `job`, `label`, `type`, `grades` FROM `elyzea_jobs`') or {}
    for _, r in ipairs(rows) do
        if Config.Companies[r.job] then
            local grades = json.decode(r.grades or '[]') or {}
            if #grades > 0 then NewCompany(r.job, r.label, r.type, grades) end
        end
    end
    for _, r in ipairs(MySQL.query.await('SELECT `citizenid`, `job`, `spec` FROM `elyzea_jobs_specialties`') or {}) do
        J.specs[r.citizenid] = J.specs[r.citizenid] or {}
        J.specs[r.citizenid][r.job] = J.specs[r.citizenid][r.job] or {}
        J.specs[r.citizenid][r.job][r.spec] = true
    end
    -- Entreprises pas encore enregistrées : reprises du métier déjà déclaré dans elyzea_core
    for job in pairs(Config.Companies) do
        if not J.companies[job] then
            local ok, def = pcall(function() return core:GetJob(job) end)
            if ok and def then
                NewCompany(job, def.label, def.type, GradesFromCore(def))
                J.Save(job)
                print(('^2[elyzea_jobs] %s : grades repris du métier existant.^0'):format(job))
            end
        end
    end
    for job in pairs(J.companies) do J.Apply(job) end
    J.ready = true
    for src in pairs(core:GetPlayers()) do J.PushPerms(src) end
    local names = {}
    for job, c in pairs(J.companies) do names[#names + 1] = ('%s (%d grades)'):format(c.label, #c.grades) end
    print(('^2[elyzea_jobs] Prêt : %s^0'):format(#names > 0 and table.concat(names, ', ') or 'aucune entreprise encore déclarée'))
end

CreateThread(function()
    local ok, err = pcall(Load)
    if not ok then print(('^1[elyzea_jobs] Base de données indisponible : %s^0'):format(tostring(err))) end
end)

-- Une autre ressource redéclare un métier géré ici (ancienne version, menu staff…) : on remet le nôtre
AddEventHandler('elyzea:server:jobsUpdated', function()
    if J.applying or not J.ready then return end
    for job, c in pairs(J.companies) do
        local ok, def = pcall(function() return core:GetJob(job) end)
        if ok and def then
            local same = def.label == c.label
            for i, g in ipairs(c.grades) do
                local d = def.grades and (def.grades[i - 1] or def.grades[tostring(i - 1)])
                if not d or d.name ~= g.name or math.floor(tonumber(d.payment) or 0) ~= math.floor(tonumber(g.payment) or 0) then same = false end
            end
            if not same then SetTimeout(500, function() J.Apply(job) end) end
        end
    end
end)

-- ---------------------------------------------------------------------
-- Entreprise et accès d'un joueur
-- ---------------------------------------------------------------------
function J.IsMain(job) return MAIN[job] == true end

-- Entreprise du joueur (nil s'il n'est pas dans une des 5)
function J.CompanyOf(src)
    local p = J.Player(src)
    if not p then return nil end
    local job = p.PlayerData.job
    local c = job and J.companies[job.name]
    if not c then return nil end
    return c, job.grade and job.grade.level or 0, p
end

function J.Grade(job, lvl)
    local c = J.companies[job]
    return c and c.grades[(tonumber(lvl) or 0) + 1] or nil
end

function J.TopLevel(job)
    local c = J.companies[job]
    return c and #c.grades - 1 or 0
end

-- Spécialités d'un joueur dans son métier
-- Spécialisations d'un employé (seulement celles encore prévues dans la config)
function J.Specs(cid, job)
    local defs = Config.Companies[job] and Config.Companies[job].specialties or {}
    local out = {}
    for spec in pairs((J.specs[cid] or {})[job] or {}) do if defs[spec] then out[spec] = true end end
    return out
end

function J.Can(src, perm)
    local c, lvl, p = J.CompanyOf(src)
    if not c then return false end
    local g = c.grades[lvl + 1]
    if not g then return false end
    if g.isboss then return true end
    if g.perms and g.perms[perm] == true then return true end
    local defs = Config.Companies[c.job].specialties or {}
    for spec in pairs(J.Specs(p.PlayerData.citizenid, c.job)) do
        for _, sp in ipairs(defs[spec] and defs[spec].perms or {}) do if sp == perm then return true end end
    end
    return false
end

function J.OnDuty(src, job)
    local p = J.Player(src)
    if not p or p.PlayerData.job.name ~= job then return false end
    local mode = Config.Companies[job] and Config.Companies[job].duty or 'core'
    local key = mode:match('^state:(.+)$')
    if key then return Player(src).state[key] == true end
    return p.PlayerData.job.onduty == true
end

-- Accès de tous les grades sous forme lisible (pour les clients)
function J.PublicCompany(job)
    local c = J.companies[job]
    if not c then return nil end
    local cfg = Config.Companies[job]
    local grades = {}
    for i, g in ipairs(c.grades) do grades[i] = { level = i - 1, name = g.name, payment = g.payment, isboss = g.isboss == true } end
    return { job = job, label = c.label, short = cfg.short, color = cfg.color, grades = grades }
end

-- ---------------------------------------------------------------------
-- Accès visibles par le client (state bag « ejobs ») : seulement pour afficher
-- les bons boutons. Le serveur revérifie toujours avec J.Can.
-- ---------------------------------------------------------------------
function J.PushPerms(src)
    if not GetPlayerName(src) then return end
    local c, lvl = J.CompanyOf(src)
    if not c then
        if Player(src).state.ejobs ~= nil then Player(src).state:set('ejobs', nil, true) end
        return
    end
    local perms = {}
    for _, p in ipairs(J.PermDefs(c.job)) do perms[p.id] = J.Can(src, p.id) or nil end
    Player(src).state:set('ejobs', { job = c.job, grade = lvl, perms = perms }, true)
end

function J.PushJob(job)
    for src, p in pairs(core:GetPlayers()) do
        if p.PlayerData.job and p.PlayerData.job.name == job then J.PushPerms(src) end
    end
end

AddEventHandler('elyzea:server:playerLoaded', function(src) SetTimeout(500, function() J.PushPerms(src) end) end)
AddEventHandler('elyzea:server:onJobUpdate', function(src) SetTimeout(200, function() J.PushPerms(src) end) end)
AddEventHandler('elyzea_jobs:companyChanged', function(job) SetTimeout(300, function() J.PushJob(job) end) end)

-- ---------------------------------------------------------------------
-- Exports pour les ressources métiers
-- ---------------------------------------------------------------------
exports('Manages', function(job) return Config.Companies[job] ~= nil end)
exports('IsReady', function() return J.ready end)
exports('IsMainJob', function(job) return J.IsMain(job) end)
exports('Can', function(src, perm) return J.Can(src, perm) end)
exports('OnDuty', function(src, job) return J.OnDuty(src, job) end)
exports('HasSpecialty', function(src, spec)
    local c, _, p = J.CompanyOf(src)
    return c ~= nil and J.Specs(p.PlayerData.citizenid, c.job)[spec] == true
end)
exports('Seed', function(job, def) return J.Seed(job, def) end)
exports('GetCompany', function(job) return J.PublicCompany(job) end)
exports('AddLog', function(job, kind, actor, target, amount, details) J.Log(job, kind, actor, target, amount, details) end)

-- Menu staff d'une ressource métier : nouvelle liste de grades { {name, payment, isboss}, ... }
-- Les accès sont gardés pour les grades du même nom.
exports('StaffSetGrades', function(job, label, grades)
    local c = J.companies[job]
    if not c or type(grades) ~= 'table' or #grades == 0 then return false end
    local old = {}
    for _, g in ipairs(c.grades) do old[g.name] = g.perms end
    local list = {}
    for _, g in ipairs(grades) do
        local name = tostring(g.name or g.label or ''):sub(1, 50)
        if name ~= '' then list[#list + 1] = { name = name, payment = math.max(0, math.floor(tonumber(g.payment or g.salary) or 0)), isboss = g.isboss == true, perms = old[name] } end
    end
    if #list == 0 then return false end
    c.grades = list
    if label and tostring(label) ~= '' then c.label = tostring(label):sub(1, 50) end
    EnsurePerms(job)
    J.Save(job)
    J.Apply(job)
    J.Log(job, 'grades_staff', { name = GetInvokingResource() or 'staff' }, nil, nil, ('%d grade(s)'):format(#list))
    return true
end)

J.EnsurePerms = EnsurePerms
