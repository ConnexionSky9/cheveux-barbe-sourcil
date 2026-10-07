-- =========================================================
--  MÉTIERS : TENUES DE SERVICE ET CHANGEMENT DE MÉTIER (staff)
--  - Tenues par métier, par grade et par sexe : enfilées à la prise
--    de service, retirées à la fin (client/uniforms.lua).
--  - « Rejoindre ce métier » : le staff prend temporairement un
--    métier EMS / Police pour utiliser la tablette joueur, puis
--    reprend son métier d'origine en un clic.
-- =========================================================
local AM = AdminMenu
local Uniforms = Storage.load('uniforms', {})   -- [job][grade][gender] = { c = { [id] = {d, t} }, p = { [id] = {d, t} } }
local Switch = Storage.load('job_switch', {})   -- [licence] = { job, grade, charId, temp, tempGrade }

local GROUPS = {
    ems = { perm = 'ems_staff', label = 'EMS', cfg = function() return Config.Ems or {} end },
    police = { perm = 'police_staff', label = 'Police', cfg = function() return Config.Police or {} end },
    lscustom = { perm = 'lscustom_staff', label = 'LsCustom', cfg = function() return Config.LsCustom or {} end },
    concess = { perm = 'concess_staff', label = 'Concession', cfg = function() return Config.Concess or {} end },
    -- Tous les autres métiers du serveur (onglet Métiers › Gestion des métiers)
    custom = { perm = 'jobs_manage', label = 'Métiers', cfg = function() return { jobs = AM.JobsMgrList and AM.JobsMgrList() or {} } end },
}

-- Métiers d'un groupe (config + liste de la ressource Police si démarrée), gardés 5 s
local groupCache = {}
local groupJobsRaw
local function groupJobs(g)
    local c = groupCache[g]
    if c and GetGameTimer() - c.t < 5000 then return c.list, c.set end
    local list, set = groupJobsRaw(g)
    groupCache[g] = { list = list, set = set, t = GetGameTimer() }
    return list, set
end
function groupJobsRaw(g)
    local cfg = GROUPS[g].cfg()
    local list, seen = {}, {}
    local function add(n) n = tostring(n) if not seen[n] then seen[n] = true list[#list + 1] = n end end
    for _, j in ipairs(cfg.jobs or {}) do add(j) end
    if g == 'lscustom' or g == 'concess' then
        local res = cfg.resource or (g == 'concess' and 'elyzea_concess' or 'elyzea_lscustom')
        if GetResourceState(res) == 'started' then
            local ok, name = pcall(function() return exports[res]:GetJobName() end)
            if ok and name then add(name) end
        end
    end
    if g == 'police' then
        local res = cfg.resource or 'elyzea_police'
        if GetResourceState(res) == 'started' then
            local ok, jobs = pcall(function() return exports[res]:GetPoliceJobs() end)
            if ok and type(jobs) == 'table' then for _, j in ipairs(jobs) do add(j) end end
        end
    end
    return list, seen
end

local function jobInfo(name)
    for _, j in ipairs(Bridge.GetJobs()) do if j.name == name then return j end end
end

local function groupOfJob(job)
    for g in pairs(GROUPS) do
        local _, set = groupJobs(g)
        if set[job] then return g end
    end
end

local function canGroup(src, g)
    return GROUPS[g] ~= nil and AM.hasPerm(src, GROUPS[g].perm)
end

-- ---------------------------------------------------------
--  Tenues
-- ---------------------------------------------------------
local function cleanPart(t, maxId)
    local out = {}
    for k, v in pairs(type(t) == 'table' and t or {}) do
        local id = tonumber(k)
        if id and id >= 0 and id <= maxId and type(v) == 'table' then
            out[tostring(math.floor(id))] = { math.floor(tonumber(v[1]) or 0), math.floor(tonumber(v[2]) or 0) }
        end
    end
    return out
end

local function broadcast(target)
    TriggerClientEvent('adminmenu:uniforms', target or -1, Uniforms)
end

RegisterNetEvent('adminmenu:uniforms:request', function() broadcast(source) end)

-- ---------------------------------------------------------
--  Tenues par défaut (Config.Uniforms.defaults)
-- ---------------------------------------------------------
local Seeded = Storage.load('uniforms_seeded', {})   -- [job] = true : tenues par défaut déjà posées une fois

local function toPart(t)
    local out = {}
    for k, v in pairs(t or {}) do out[tostring(k)] = { v[1], v[2] } end
    return out
end

-- Tenues par défaut d'un type ('police' ou 'ems') : { [grade] = { male = ..., female = ... } }
local function buildDefaults(kind)
    local def = Config.Uniforms and Config.Uniforms.defaults and Config.Uniforms.defaults[kind]
    if not def then return nil end
    local out = {}
    for gender, d in pairs(def) do
        out['0'] = out['0'] or {}
        out['0'][gender] = { c = toPart(d.base.c), p = toPart(d.base.p) }
        for lvl, over in pairs(d.grades or {}) do
            local o = { c = toPart(d.base.c), p = toPart(d.base.p) }
            for k, v in pairs(over) do o.c[tostring(k)] = { v[1], v[2] } end
            out[tostring(lvl)] = out[tostring(lvl)] or {}
            out[tostring(lvl)][gender] = o
        end
    end
    return out
end

local function kindOfJob(job)
    for g in pairs(GROUPS) do
        local _, set = groupJobs(g)
        if set[job] then return g end
    end
end

local function seedAll()
    local changed = false
    for g in pairs(GROUPS) do
        -- Les autres métiers du serveur n'ont pas de tenue par défaut : le staff les crée lui-même
        for _, job in ipairs(g == 'custom' and {} or (groupJobs(g))) do
            if not Seeded[job] then
                Seeded[job] = true
                changed = true
                if not Uniforms[job] or next(Uniforms[job]) == nil then
                    Uniforms[job] = buildDefaults(g)
                    print(('^2[AdminMenu] Tenues de service par défaut créées pour le métier « %s ».^7'):format(job))
                end
            end
        end
    end
    if changed then
        Storage.save('uniforms_seeded', Seeded)
        Storage.save('uniforms', Uniforms)
        broadcast()
    end
end

-- ---------------------------------------------------------
--  Enregistrer / supprimer / réinitialiser (utilisé par le menu ET par les tablettes staff des métiers)
-- ---------------------------------------------------------
local function genderLabel(g) return g == 'male' and 'homme' or 'femme' end

-- Renvoie ok, message
local function saveUniform(src, job, grade, gender, outfit)
    job, grade, gender = tostring(job or ''), tonumber(grade), tostring(gender or '')
    if job == '' or not grade or grade < 0 or (gender ~= 'male' and gender ~= 'female') then return false, 'Données de tenue invalides.' end
    if type(outfit) ~= 'table' then return false, 'Tenue invalide.' end
    Uniforms[job] = Uniforms[job] or {}
    Uniforms[job][tostring(grade)] = Uniforms[job][tostring(grade)] or {}
    Uniforms[job][tostring(grade)][gender] = { c = cleanPart(outfit.c, 11), p = cleanPart(outfit.p, 7) }
    Seeded[job] = true
    Storage.save('uniforms_seeded', Seeded)
    Storage.save('uniforms', Uniforms)
    broadcast()
    AM.addLog(src, 'Tenue de service enregistrée', ('%s · grade %d · %s'):format(job, grade, genderLabel(gender)))
    return true, ('Tenue %s enregistrée pour le grade %d. Elle sera mise aux joueurs à leur prise de service.'):format(genderLabel(gender), grade)
end

local function deleteUniform(src, job, grade, gender)
    job, grade, gender = tostring(job or ''), tostring(grade or ''), tostring(gender or '')
    local e = Uniforms[job] and Uniforms[job][grade]
    if not e or not e[gender] then return false, 'Aucune tenue à supprimer.' end
    e[gender] = nil
    if next(e) == nil then Uniforms[job][grade] = nil end
    Storage.save('uniforms', Uniforms)
    broadcast()
    AM.addLog(src, 'Tenue de service supprimée', ('%s · grade %s · %s'):format(job, grade, genderLabel(gender)))
    return true, 'Tenue supprimée.'
end

local function resetUniforms(src, job)
    job = tostring(job or '')
    local kind = kindOfJob(job)
    local def = kind and buildDefaults(kind)
    if not def then return false, 'Pas de tenues par défaut pour ce métier.' end
    Uniforms[job] = def
    Seeded[job] = true
    Storage.save('uniforms_seeded', Seeded)
    Storage.save('uniforms', Uniforms)
    broadcast()
    AM.addLog(src, 'Tenues par défaut remises', job)
    return true, 'Tenues par défaut remises pour ce métier.'
end

-- Résumé : quelles tenues existent, par grade et par sexe
local function summary(job)
    local out = {}
    for grade, e in pairs(Uniforms[tostring(job)] or {}) do out[grade] = { male = e.male ~= nil, female = e.female ~= nil } end
    return out
end

local A = AM.Actions

A.uniform_save = { permAny = { 'ems_staff', 'police_staff', 'lscustom_staff', 'concess_staff', 'jobs_manage' }, noRefresh = true, fn = function(src, d)
    local g = tostring(d.group or '')
    if not canGroup(src, g) then return AM.notify(src, 'Tu n\'as pas accès aux tenues de ce métier.', 'error') end
    local _, set = groupJobs(g)
    if not set[tostring(d.job)] then return AM.notify(src, 'Métier non géré ici.', 'error') end
    local ok, msg = saveUniform(src, d.job, d.grade, d.gender, d.outfit)
    AM.notify(src, msg, ok and 'success' or 'error')
    AM.sendData(src)
end }

A.uniform_delete = { permAny = { 'ems_staff', 'police_staff', 'lscustom_staff', 'concess_staff', 'jobs_manage' }, noRefresh = true, fn = function(src, d)
    if not canGroup(src, tostring(d.group or '')) then return AM.notify(src, 'Tu n\'as pas accès aux tenues de ce métier.', 'error') end
    local ok, msg = deleteUniform(src, d.job, d.grade, d.gender)
    AM.notify(src, msg, ok and 'success' or 'error')
    AM.sendData(src)
end }

A.uniform_reset = { permAny = { 'ems_staff', 'police_staff', 'lscustom_staff', 'concess_staff', 'jobs_manage' }, noRefresh = true, fn = function(src, d)
    if not canGroup(src, tostring(d.group or '')) then return AM.notify(src, 'Tu n\'as pas accès aux tenues de ce métier.', 'error') end
    local ok, msg = resetUniforms(src, d.job)
    AM.notify(src, msg, ok and 'success' or 'error')
    AM.sendData(src)
end }

-- Pour les tablettes staff des métiers (elyzea_police_staff, elyzea_ems_staff…).
-- L'accès à la tablette est vérifié par la ressource qui appelle.
exports('SaveUniform', saveUniform)
exports('DeleteUniform', deleteUniform)
exports('ResetUniforms', resetUniforms)
exports('GetUniformSummary', function(job) return summary(job) end)

CreateThread(function()
    Wait(5000)   -- laisse le temps aux ressources des métiers de démarrer
    seedAll()
end)

-- ---------------------------------------------------------
--  Changement de métier du staff
-- ---------------------------------------------------------
local function gradeName(job, grade)
    local info = jobInfo(job)
    for _, gr in ipairs(info and info.grades or {}) do if gr.level == grade then return gr.label end end
    return ('grade %d'):format(grade)
end

local function jobLabel(job)
    local info = jobInfo(job)
    return info and info.label or job
end

A.job_switch = { permAny = { 'ems_staff', 'police_staff', 'lscustom_staff', 'concess_staff', 'jobs_manage' }, noRefresh = true, fn = function(src, d)
    local g, job, grade = tostring(d.group or ''), tostring(d.job or ''), tonumber(d.grade) or 0
    if not canGroup(src, g) then return AM.notify(src, ('Tu n\'as pas accès au métier %s.'):format(GROUPS[g] and GROUPS[g].label or '?'), 'error') end
    local _, set = groupJobs(g)
    if not set[job] then return AM.notify(src, 'Métier non géré ici.', 'error') end
    local info = jobInfo(job)
    if not info then return AM.notify(src, ('Le métier « %s » n\'existe pas sur le serveur.'):format(job), 'error') end
    local validGrade = false
    for _, gr in ipairs(info.grades or {}) do if gr.level == grade then validGrade = true end end
    if not validGrade then return AM.notify(src, 'Ce grade n\'existe pas.', 'error') end

    local curJob, curGrade = Bridge.GetJob(src)
    if not curJob then return AM.notify(src, 'Impossible de lire ton métier actuel.', 'error') end
    if curJob == job and curGrade == grade then return AM.notify(src, 'Tu as déjà ce métier et ce grade.', 'error') end

    local lic = AM.getLicense(src)
    if not lic then return AM.notify(src, 'Licence introuvable.', 'error') end
    -- On garde le métier d'ORIGINE, même si le staff enchaîne plusieurs changements
    if not Switch[lic] then
        Switch[lic] = { job = curJob, grade = curGrade, charId = Bridge.GetCharId(src) }
    end
    local previousTemp = Switch[lic].temp
    if not Bridge.SetJob(src, job, grade) then return AM.notify(src, 'Le changement de métier a échoué.', 'error') end
    -- Ancien métier temporaire (ex. EMS → Police) : on le retire de la liste du personnage
    if previousTemp and previousTemp ~= job and previousTemp ~= Switch[lic].job then Bridge.RemoveFromJob(src, previousTemp) end
    Switch[lic].temp, Switch[lic].tempGrade = job, grade
    Storage.save('job_switch', Switch)

    AM.addLog(src, 'Changement de métier (staff)', ('%s · %s (métier d\'origine : %s · %s)'):format(
        jobLabel(job), gradeName(job, grade), jobLabel(Switch[lic].job), gradeName(Switch[lic].job, Switch[lic].grade)))
    AM.notify(src, ('Tu es maintenant %s · %s. Prends ton service pour utiliser la tablette.'):format(jobLabel(job), gradeName(job, grade)), 'success')
    AM.sendData(src)
end }

A.job_restore = { permAny = { 'ems_staff', 'police_staff', 'lscustom_staff', 'concess_staff', 'jobs_manage', 'manage_staff' }, noRefresh = true, fn = function(src)
    local lic = AM.getLicense(src)
    local s = lic and Switch[lic]
    if not s then return AM.notify(src, 'Aucun métier d\'origine à reprendre.', 'error') end
    if s.charId and Bridge.GetCharId(src) ~= s.charId then
        return AM.notify(src, 'Reconnecte-toi avec le personnage qui a changé de métier pour reprendre son métier d\'origine.', 'error')
    end
    if not Bridge.SetJob(src, s.job, s.grade) then return AM.notify(src, 'Le retour au métier d\'origine a échoué.', 'error') end
    if s.temp and s.temp ~= s.job then Bridge.RemoveFromJob(src, s.temp) end
    Switch[lic] = nil
    Storage.save('job_switch', Switch)
    AM.addLog(src, 'Retour au métier d\'origine (staff)', ('%s · %s'):format(jobLabel(s.job), gradeName(s.job, s.grade)))
    AM.notify(src, ('Tu as repris ton métier : %s · %s.'):format(jobLabel(s.job), gradeName(s.job, s.grade)), 'success')
    AM.sendData(src)
end }

-- ---------------------------------------------------------
--  Données des onglets EMS / Police
-- ---------------------------------------------------------
AddEventHandler('onResourceStart', function(res)
    if res == 'elyzea_police' or res == 'elyzea_lscustom' or res == 'elyzea_concess' or res == 'elyzea_ems' then
        SetTimeout(4000, seedAll)
    end
end)

table.insert(AM.DataHooks, function(src, data)
    local groups = {}
    for g in pairs(GROUPS) do
        if canGroup(src, g) then
            local names = groupJobs(g)
            local jobs = {}
            for _, n in ipairs(names) do
                local info = jobInfo(n)
                jobs[#jobs + 1] = { name = n, label = info and info.label or n, exists = info ~= nil, grades = info and info.grades or {}, uniforms = summary(n) }
            end
            groups[g] = { jobs = jobs }
        end
    end
    if next(groups) == nil then return end
    local curJob, curGrade, duty = Bridge.GetJob(src)
    local lic = AM.getLicense(src)
    local s = lic and Switch[lic]
    data.jobtools = {
        groups = groups,
        uniformsEnabled = not Config.Uniforms or Config.Uniforms.enabled ~= false,
        me = {
            job = curJob, jobLabel = curJob and jobLabel(curJob), grade = curGrade, gradeLabel = curJob and gradeName(curJob, curGrade or 0),
            duty = duty, group = curJob and groupOfJob(curJob),
            origin = s and { job = s.job, label = jobLabel(s.job), grade = s.grade, gradeLabel = gradeName(s.job, s.grade) } or nil,
        },
    }
end)

exports('GetUniforms', function() return Uniforms end)

-- ---------------------------------------------------------
--  Onglet « Métiers » : tous les métiers du serveur, effectifs en ville et en service
--  (gardé 5 s : un seul calcul pour tous les staffs)
-- ---------------------------------------------------------
local hubCache, hubTime = nil, 0
local function jobsHub()
    if hubCache and GetGameTimer() - hubTime < 5000 then return hubCache end
    local counts = {}
    for _, p in ipairs(GetPlayers()) do
        local job, _, duty = Bridge.GetJob(tonumber(p))
        if job then
            counts[job] = counts[job] or { online = 0, duty = 0 }
            counts[job].online = counts[job].online + 1
            if duty ~= false then counts[job].duty = counts[job].duty + 1 end
        end
    end
    local managed = {}
    local groups = {}
    for g in pairs(GROUPS) do
        local names = groupJobs(g)
        local agg = { online = 0, duty = 0, jobs = names }
        for _, n in ipairs(names) do
            managed[n] = g
            local c = counts[n]
            if c then agg.online = agg.online + c.online agg.duty = agg.duty + c.duty end
        end
        groups[g] = agg
    end
    local list = {}
    for _, j in ipairs(Bridge.GetJobs()) do
        if j.name ~= 'unemployed' then
            local c = counts[j.name] or { online = 0, duty = 0 }
            list[#list + 1] = { name = j.name, label = j.label, grades = #(j.grades or {}), online = c.online, duty = c.duty, managed = managed[j.name] }
        end
    end
    table.sort(list, function(a, b)
        if a.online ~= b.online then return a.online > b.online end
        return a.label:lower() < b.label:lower()
    end)
    hubCache, hubTime = { list = list, groups = groups }, GetGameTimer()
    return hubCache
end

table.insert(AM.DataHooks, function(src, data)
    local any = AM.hasPerm(src, 'manage_staff')
    for _, g in pairs(GROUPS) do if AM.hasPerm(src, g.perm) then any = true end end
    if any then data.jobsHub = jobsHub() end
end)
