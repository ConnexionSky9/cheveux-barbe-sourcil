-- =========================================================
--  MES OUTILS › MÉTIER STAFF - SERVEUR
--  Le staff prend n'importe quel métier / grade en un clic (tests, RP),
--  passe en service, puis revient à son métier d'origine.
--  Permission « staff_job » vérifiée par le dispatcher d'actions.
-- =========================================================
local AM = AdminMenu
local core = exports.elyzea_core
local KEY = 'staffPrevJob'   -- métier d'origine, gardé dans le personnage

local function jobsList()
    local ok, jobs = pcall(function() return core:GetJobs() end)
    local list = {}
    for name, j in pairs(ok and jobs or {}) do
        local grades = {}
        for lvl, g in pairs(j.grades or {}) do
            grades[#grades + 1] = { level = tonumber(lvl) or 0, name = g.name or tostring(lvl), isboss = g.isboss == true, payment = g.payment or 0 }
        end
        table.sort(grades, function(a, b) return a.level < b.level end)
        list[#list + 1] = { name = name, label = j.label or name, type = j.type, grades = grades }
    end
    table.sort(list, function(a, b)
        if a.name == 'unemployed' then return true elseif b.name == 'unemployed' then return false end
        return tostring(a.label):lower() < tostring(b.label):lower()
    end)
    return list
end

local function current(src)
    local p = core:GetPlayer(src)
    if not p then return nil end
    local j = p.PlayerData.job or {}
    return {
        name = j.name, label = j.label, level = j.grade and j.grade.level or 0, grade = j.grade and j.grade.name or '',
        onduty = j.onduty == true, isboss = j.isboss == true, prev = p.PlayerData.metadata and p.PlayerData.metadata[KEY] or nil,
    }
end

local A = {}

function A.set(src, d)
    local job, grade = tostring(d.job or ''), math.floor(tonumber(d.grade) or 0)
    local ok, def = pcall(function() return core:GetJob(job) end)
    if not ok or not def then return AM.notify(src, 'Métier introuvable.', 'error') end
    if not (def.grades or {})[grade] then return AM.notify(src, 'Grade introuvable.', 'error') end
    local cur = current(src)
    if not cur then return AM.notify(src, 'Personnage non chargé.', 'error') end
    -- Premier changement : on garde le vrai métier pour pouvoir y revenir
    if not cur.prev then core:SetMetadata(src, KEY, { name = cur.name, grade = cur.level, label = cur.label, gradeLabel = cur.grade }) end
    core:SetJob(src, job, grade)
    core:SetJobDuty(src, d.duty ~= false)
    local g = def.grades[grade]
    AM.notify(src, ('Métier : %s · %s (en service).'):format(def.label or job, g and g.name or grade), 'success')
    AM.addLog(src, 'Métier staff', ('%s · grade %d'):format(job, grade))
end

function A.duty(src)
    local cur = current(src)
    if not cur then return end
    core:SetJobDuty(src, not cur.onduty)
    AM.notify(src, cur.onduty and 'Tu n\'es plus en service.' or 'Tu es en service.', 'inform')
end

function A.back(src)
    local cur = current(src)
    if not cur or not cur.prev then return AM.notify(src, 'Aucun métier d\'origine enregistré.', 'error') end
    local prev = cur.prev
    core:SetJob(src, prev.name or 'unemployed', tonumber(prev.grade) or 0)
    core:SetMetadata(src, KEY, nil)
    AM.notify(src, ('Retour à ton métier : %s · %s.'):format(prev.label or prev.name or 'Sans emploi', prev.gradeLabel or prev.grade or 0), 'success')
    AM.addLog(src, 'Métier staff : retour au métier d\'origine', tostring(prev.name))
end

-- Garde ton métier actuel comme métier d'origine (oublie l'ancien)
function A.keep(src)
    local cur = current(src)
    if not cur then return end
    core:SetMetadata(src, KEY, nil)
    AM.notify(src, ('%s est maintenant ton métier normal.'):format(cur.label or cur.name), 'success')
end

AM.Actions.staffjob = { perm = 'staff_job', fn = function(src, d)
    local fn = A[tostring(d.name or '')]
    if fn then fn(src, type(d.data) == 'table' and d.data or {}) end
end }

local cache, cacheAt = nil, -1e9
table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'staff_job') or GetResourceState('elyzea_core') ~= 'started' then return end
    if not cache or GetGameTimer() - cacheAt > 15000 then cache, cacheAt = jobsList(), GetGameTimer() end
    data.staffJob = { jobs = cache, current = current(src) }
end)
AddEventHandler('elyzea:server:jobsUpdated', function() cache = nil end)
