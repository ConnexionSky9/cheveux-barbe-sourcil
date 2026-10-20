-- =====================================================================
--  Agences du métier (elyzea_agences) - fichier identique dans chaque
--  métier (police, EMS, mécano, Dynasty 8, presse).
--  · Une agence = un métier elyzea_core (ex. police, bcso, sheriff…) avec
--    ses grades, ses employés, son compte de société, son préfixe de
--    matricule, son téléphone de service et sa zone d'alerte.
--  · Sans elyzea_agences : une seule agence, celle de Config.Job (comme avant).
--  Nécessite dans main.lua : P.T (tables), P.SeedGrades(job), P.SyncCoreJob(job),
--  P.LoadGrades(), P.Remove(cid), P.PushAll() ; dans config.lua : Config.AgencyKind.
-- =====================================================================
local P = Police or Ems or Meca or Dynasty or Presse
local core = exports.elyzea_core
local KIND = Config.AgencyKind
local AG = 'elyzea_agences'

P.agencies = P.agencies or {}       -- [job] = { job, label, short, mat, phone, color, society, zone }
P.agencyList = P.agencyList or {}   -- agences dans l'ordre de création

-- ---------------------------------------------------------------------
-- Base de données : colonne `job` (agence) ajoutée aux tables d'avant les agences.
-- required : tables dont chaque ligne appartient à une agence (grades, employés…)
-- optional : historiques (colonne facultative) ; gradesTbl : nom / niveau uniques PAR agence
-- Les lignes existantes sont rattachées à la première agence (Config.Job.name).
-- ---------------------------------------------------------------------
function P.AddJobColumns(required, optional, gradesTbl)
    local def = Config.Job.name:gsub('[^%w_]', '')
    local function Has(t, c)
        return (tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE()
            AND TABLE_NAME = ? AND COLUMN_NAME = ?]], { t, c })) or 0) > 0
    end
    local function Run(sql)
        local ok, err = pcall(MySQL.query.await, sql)
        if not ok then print(('^1[%s] Mise à jour agences : %s^0'):format(GetCurrentResourceName(), tostring(err))) end
    end
    for _, t in ipairs(required or {}) do
        if not Has(t, 'job') then
            Run(("ALTER TABLE `%s` ADD COLUMN `job` VARCHAR(40) NOT NULL DEFAULT '%s', ADD INDEX `idx_job` (`job`)"):format(t, def))
            print(('^3[%s] Table « %s » : colonne agence ajoutée (lignes existantes → %s).^0'):format(GetCurrentResourceName(), t, def))
        end
    end
    for _, t in ipairs(optional or {}) do
        if not Has(t, 'job') then
            Run(('ALTER TABLE `%s` ADD COLUMN `job` VARCHAR(255) NULL'):format(t))
            Run(("UPDATE `%s` SET `job` = '%s'"):format(t, def))
        end
    end
    if gradesTbl then
        local idx = MySQL.query.await([[SELECT `INDEX_NAME` AS n, GROUP_CONCAT(`COLUMN_NAME`) AS c FROM information_schema.STATISTICS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND NON_UNIQUE = 0 AND INDEX_NAME <> 'PRIMARY' GROUP BY `INDEX_NAME`]], { gradesTbl }) or {}
        local names = {}
        for _, r in ipairs(idx) do names[r.n] = r.c end
        for n, c in pairs(names) do
            if c == 'name' or c == 'level' then Run(('ALTER TABLE `%s` DROP INDEX `%s`'):format(gradesTbl, n)) end
        end
        if not names.job_name then Run(('ALTER TABLE `%s` ADD UNIQUE KEY `job_name` (`job`, `name`)'):format(gradesTbl)) end
        if not names.job_level then Run(('ALTER TABLE `%s` ADD UNIQUE KEY `job_level` (`job`, `level`)'):format(gradesTbl)) end
    end
end

local function Default()
    return { job = Config.Job.name, label = Config.Job.label, short = Config.Job.label, mat = Config.Matricule.prefix,
        society = Config.Society or Config.Job.name }
end

local function Registry()
    if GetResourceState(AG) ~= 'started' then return nil end
    local ok, ready = pcall(function() return exports[AG]:IsReady() end)
    return ok and ready == true
end

-- (Re)lit les agences du registre. wait = attendre le registre au démarrage
function P.LoadAgencies(wait)
    if wait then
        local t = GetGameTimer() + 15000
        while GetGameTimer() < t do
            local st = GetResourceState(AG)
            if st ~= 'starting' and st ~= 'started' then break end
            if Registry() then break end
            Wait(250)
        end
    end
    local list
    if Registry() then
        local ok, l = pcall(function() return exports[AG]:GetAgencies(KIND) end)
        list = ok and l or nil
        if list and #list == 0 then
            pcall(function() exports[AG]:Seed(KIND, Default()) end)
            ok, l = pcall(function() return exports[AG]:GetAgencies(KIND) end)
            list = ok and l or nil
        end
    end
    if not list or #list == 0 then list = { Default() } end
    P.agencies, P.agencyList = {}, {}
    for _, a in ipairs(list) do
        local ag = { job = a.job, label = a.label, short = a.short or a.label, mat = a.mat or Config.Matricule.prefix, phone = a.phone, color = a.color,
            society = (a.job == Config.Job.name and (Config.Society or a.job)) or a.job, zone = a.zone }
        P.agencies[ag.job] = ag
        P.agencyList[#P.agencyList + 1] = ag
    end
end

function P.Agency(job) return job and P.agencies[job] or nil end
function P.IsAgencyJob(job) return job ~= nil and P.agencies[job] ~= nil end
function P.MainJob() return P.agencyList[1] and P.agencyList[1].job or Config.Job.name end
function P.JobOf(cid) local e = cid and P.employees[cid] return e and e.job or nil end
-- Agence d'un joueur (membre seulement)
function P.AgencyOf(src)
    local cid = P.Cid(src)
    local e = cid and P.employees[cid]
    return e and P.agencies[e.job] or nil
end
function P.MyJob(src) local a = P.AgencyOf(src) return a and a.job or nil end
function P.AgencyLabel(job) local a = P.agencies[job or ''] return a and a.label or Config.Job.label end
function P.Society(job) local a = P.agencies[job or ''] return a and a.society or job or Config.Society or Config.Job.name end
function P.MultiAgency() return #P.agencyList > 1 end

-- Agences qui reçoivent une alerte à ces coordonnées : { [job] = true }
function P.RouteJobs(coords)
    local set = {}
    if coords and Registry() then
        local ok, jobs = pcall(function() return exports[AG]:Route(KIND, { x = coords.x, y = coords.y }) end)
        if ok and type(jobs) == 'table' then
            for _, j in ipairs(jobs) do if P.agencies[j] then set[j] = true end end
        end
    end
    if not next(set) then for job in pairs(P.agencies) do set[job] = true end end
    return set
end

-- Grades et métier elyzea_core présents pour chaque agence
function P.EnsureAgency(job)
    local has = false
    for _, g in pairs(P.grades) do if g.job == job then has = true break end end
    if not has then
        P.SeedGrades(job)
        P.LoadGrades()
    end
    if P.EnsureDirecteur then P.EnsureDirecteur(job) end
    P.SyncCoreJob(job)
end

-- Agence supprimée : employés retirés du métier, grades effacés, métier retiré du core
local function DropAgency(job)
    if not P.agencies[job] then return end
    local n = 0
    for cid, e in pairs(P.employees) do
        if e.job == job then
            P.AddLog('Staff', cid, e.name, 'Départ (agence supprimée)', nil, nil, P.AgencyLabel(job), job)
            P.Remove(cid)
            n = n + 1
        end
    end
    for id, g in pairs(P.grades) do if g.job == job then P.grades[id] = nil end end
    MySQL.update.await(('DELETE FROM `%s` WHERE `job` = ?'):format(P.T.grades), { job })
    pcall(function() core:RemoveJob(job) end)
    P.agencies[job] = nil
    for i, a in ipairs(P.agencyList) do if a.job == job then table.remove(P.agencyList, i) break end end
    print(('^3[%s] Agence « %s » supprimée : %d employé(s) retiré(s).^0'):format(GetCurrentResourceName(), job, n))
end

-- Rappels du métier après un changement d'agences (ex. points de garage republiés)
function P.RunAfterAgencies()
    for _, fn in ipairs(P.AfterAgencies or {}) do
        local ok, err = pcall(fn)
        if not ok then print(('^1[%s] Agences : %s^0'):format(GetCurrentResourceName(), tostring(err))) end
    end
end

AddEventHandler('elyzea_agences:changed', function(kind, job, action)
    if kind ~= KIND or not P.ready then return end
    if action == 'deleted' then
        DropAgency(job)
    else
        P.LoadAgencies(false)
        if P.agencies[job] then P.EnsureAgency(job) end
    end
    P.RunAfterAgencies()
    P.PushAll()
end)

-- Registre démarré (ou redémarré) après le métier : on le relit
AddEventHandler('elyzea_agences:ready', function()
    if not P.ready then return end
    P.LoadAgencies(false)
    for _, a in ipairs(P.agencyList) do P.EnsureAgency(a.job) end
    P.RunAfterAgencies()
    P.PushAll()
end)

-- ---------------------------------------------------------------------
-- Exports pour le panneau des agences
-- ---------------------------------------------------------------------
exports('AgencyStats', function(job)
    local employees, duty, grades = 0, 0, 0
    for _, e in pairs(P.employees) do if e.job == job then employees = employees + 1 end end
    for src in pairs(P.duty) do
        local cid = P.Cid(src)
        if cid and P.employees[cid] and P.employees[cid].job == job then duty = duty + 1 end
    end
    for _, g in pairs(P.grades) do if g.job == job then grades = grades + 1 end end
    return { employees = employees, duty = duty, grades = grades }
end)

-- Le staff nomme le directeur d'une agence : plus haut grade de l'agence
exports('AgencyAppoint', function(adminSrc, target, job)
    if not P.agencies[job] then return false, 'Agence inconnue de ce métier.' end
    local sorted = P.SortedGrades(job)
    local top = sorted[#sorted]
    if not top then return false, 'Cette agence n\'a aucun grade.' end
    return P.AdminSetGrade(adminSrc, target, top.id)
end)

exports('GetAgencies', function()
    local out = {}
    for _, a in ipairs(P.agencyList) do out[#out + 1] = { job = a.job, label = a.label, short = a.short } end
    return out
end)
exports('GetAgencyOf', function(src)
    local a = P.AgencyOf(tonumber(src))
    return a and { job = a.job, label = a.label, short = a.short } or nil
end)
