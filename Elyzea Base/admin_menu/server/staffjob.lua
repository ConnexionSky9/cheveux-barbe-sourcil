-- =========================================================
--  MES OUTILS › MÉTIER STAFF - SERVEUR (permission « staff_job »)
--  Pont vers les ressources métier « elyzea_police » et « elyzea_ems » :
--   - le staff entre lui-même dans le métier au grade voulu ;
--   - il recrute un joueur connecté ou change son grade (direction comprise) ;
--   - il retire un joueur du métier ;
--   - il revient à son métier d'origine.
--  La ressource métier revalide chaque valeur et journalise l'action.
-- =========================================================
local AM = AdminMenu
local core = exports.elyzea_core
local KEY = 'staffPrevJob'   -- métier d'origine, gardé dans le personnage
local JOBS = {
    police = { res = 'elyzea_police', job = 'police', label = 'Police', tbl = 'police_grades' },
    ems    = { res = 'elyzea_ems', job = 'ambulance', label = 'EMS', tbl = 'ems_grades' },
    meca   = { res = 'elyzea_meca', job = 'mechanic', label = 'Mécano', tbl = 'meca_grades' },
    d8     = { res = 'elyzea_dynasty', job = 'realestate', label = 'Dynasty 8', tbl = 'd8_grades' },
    presse = { res = 'elyzea_presse', job = 'journaliste', label = 'Presse', tbl = 'presse_grades' },
}
local ORDER = { 'police', 'ems', 'meca', 'd8', 'presse' }

local function available(J) return J ~= nil and GetResourceState(J.res) == 'started' end
local function call(J, fn, ...)
    local args = { ... }
    local ok, a, b = pcall(function() return exports[J.res][fn](exports[J.res], table.unpack(args)) end)
    if not ok then print(('^1[AdminMenu] %s:%s : %s^7'):format(J.res, fn, tostring(a))) return nil end
    return a, b
end

-- Grades d'un métier. D'abord ceux de la ressource (AdminGrades) ; si elle n'en renvoie aucun
-- (ressource encore en démarrage, erreur, agences mal liées), on lit directement sa table en base
-- pour que le staff puisse toujours choisir. Renvoie la liste et, si besoin, la raison.
local warned = {}
local function gradesOf(J)
    local list = call(J, 'AdminGrades')
    if type(list) == 'table' and #list > 0 then return list end
    local why = list == nil and ('la ressource « %s » ne répond pas à AdminGrades'):format(J.res)
        or ('la ressource « %s » n\'a renvoyé aucun grade'):format(J.res)
    local rows
    if J.tbl then
        local ok, r = pcall(MySQL.query.await, ('SELECT `id`, `job`, `name`, `level`, `perms` FROM `%s` ORDER BY `job`, `level`'):format(J.tbl))
        rows = ok and r or nil
    end
    local out, jobs = {}, {}
    for _, r in ipairs(rows or {}) do jobs[r.job] = true end
    local multi = next(jobs) and next(jobs, next(jobs)) ~= nil
    for _, r in ipairs(rows or {}) do
        local perms = tostring(r.perms or '')
        out[#out + 1] = { id = r.id, name = multi and ('%s · %s'):format(r.job, r.name) or r.name, level = tonumber(r.level) or 0,
            direction = perms:find('direction', 1, true) ~= nil or perms == 'all', job = r.job }
    end
    if not warned[J.res] then
        warned[J.res] = true
        print(('^3[AdminMenu] Métier staff : %s ; %d grade(s) lus dans la table %s.^7'):format(why, #out, J.tbl or '?'))
    end
    return out, why .. (#out > 0 and ' : grades lus directement en base.' or ' et sa table de grades est vide ou absente.')
end

local function prevJob(src)
    local p = core:GetPlayer(src)
    return p and p.PlayerData.metadata and p.PlayerData.metadata[KEY] or nil
end

local A = {}

-- Le staff entre dans le métier (ou change de grade) : son vrai métier est gardé
function A.join(J, src, d)
    local p = core:GetPlayer(src)
    if not p then return AM.notify(src, 'Personnage non chargé.', 'error') end
    local j = p.PlayerData.job or {}
    local isStaffJob = false
    for _, k in ipairs(ORDER) do
        -- Métier d'une agence (elyzea_agences : plusieurs polices, EMS…) : déjà un métier staff
        if JOBS[k].job == j.name or (available(JOBS[k]) and call(JOBS[k], 'AdminInfo', src)) then isStaffJob = true end
    end
    if not prevJob(src) and not isStaffJob then
        core:SetMetadata(src, KEY, { name = j.name or 'unemployed', grade = j.grade and j.grade.level or 0, label = j.label })
    end
    local ok, msg = call(J, 'AdminSetGrade', src, src, d.grade)
    if ok then call(J, 'AdminDuty', src, true) end
    AM.notify(src, msg or (J.label .. ' ne répond pas.'), ok and 'success' or 'error')
    if ok then AM.addLog(src, 'Métier staff : ' .. J.label, tostring(msg)) end
end

function A.duty(J, src)
    local info = call(J, 'AdminInfo', src)
    if not info then return AM.notify(src, ('Tu n\'es pas dans le métier %s.'):format(J.label), 'error') end
    local ok, msg = call(J, 'AdminDuty', src, not info.duty)
    AM.notify(src, msg or (J.label .. ' ne répond pas.'), ok and 'inform' or 'error')
end

-- Retour au métier d'origine (la ressource métier retire automatiquement le membre)
function A.back(_, src)
    local prev = prevJob(src)
    if not prev then return AM.notify(src, 'Aucun métier d\'origine enregistré.', 'error') end
    core:SetJob(src, prev.name or 'unemployed', tonumber(prev.grade) or 0)
    core:SetMetadata(src, KEY, nil)
    AM.notify(src, ('Retour à ton métier : %s.'):format(prev.label or prev.name or 'Sans emploi'), 'success')
    AM.addLog(src, 'Métier staff : retour au métier d\'origine', tostring(prev.name))
end

-- Recruter un joueur / lui donner un grade (direction comprise)
function A.set(J, src, d)
    local target = tonumber(d.target)
    if not target or not GetPlayerName(target) then return AM.notify(src, 'Joueur introuvable.', 'error') end
    local ok, msg = call(J, 'AdminSetGrade', src, target, d.grade)
    AM.notify(src, msg or (J.label .. ' ne répond pas.'), ok and 'success' or 'error')
    if ok then AM.addLog(src, 'Métier staff : grade ' .. J.label, ('%s [%d] · %s'):format(GetPlayerName(target), target, tostring(msg))) end
end

function A.remove(J, src, d)
    local target = tonumber(d.target)
    if not target then return end
    local ok, msg = call(J, 'AdminRemove', src, target)
    AM.notify(src, msg or (J.label .. ' ne répond pas.'), ok and 'success' or 'error')
    if ok then AM.addLog(src, 'Métier staff : retrait ' .. J.label, ('%s [%d]'):format(GetPlayerName(target) or '?', target)) end
end

AM.Actions.staffjob = { perm = 'staff_job', fn = function(src, d)
    local data = type(d.data) == 'table' and d.data or {}
    local J = JOBS[tostring(data.job or 'police')]
    local fn = A[tostring(d.name or '')]
    if not fn then return end
    if fn ~= A.back and not available(J) then
        return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(J and J.res or '?'), 'error')
    end
    fn(J, src, data)
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'staff_job') then return end
    local prev = prevJob(src)
    local jobs = {}
    for _, key in ipairs(ORDER) do
        local J = JOBS[key]
        if not available(J) then
            jobs[#jobs + 1] = { key = key, label = J.label, resource = J.res, available = false }
        else
            local members = {}
            for _, s in ipairs(GetPlayers()) do
                local id = tonumber(s)
                local info = call(J, 'AdminInfo', id)
                if info then members[tostring(id)] = info end
            end
            local grades, why = gradesOf(J)
            jobs[#jobs + 1] = { key = key, label = J.label, resource = J.res, available = true, grades = grades, gradesNote = why,
                me = members[tostring(src)], members = members }
        end
    end
    data.staffJob = { jobs = jobs, prev = prev and (prev.label or prev.name) or nil }
end)
