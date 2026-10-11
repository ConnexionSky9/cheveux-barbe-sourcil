-- =====================================================================
--  ELYZEA JOBS · serveur : équipe, recrutement, grades, licenciement
--  Règles : jamais sur soi-même ; on ne gère que les grades en dessous du sien ;
--  on ne donne que des accès qu'on a soi-même ; un seul métier principal.
-- =====================================================================
local core = exports.elyzea_core
HR = {}

-- ---------------------------------------------------------------------
-- Membres d'une entreprise (en ligne et hors ligne)
-- ---------------------------------------------------------------------
function HR.Members(job)
    local online = {}
    for src, p in pairs(core:GetPlayers()) do online[p.PlayerData.citizenid] = src end
    local rows = core:GetGroupMembers(job, 'job') or {}
    local list, cids = {}, {}
    for _, r in ipairs(rows) do cids[#cids + 1] = r.citizenid end
    local names = {}
    if #cids > 0 then
        for _, r in ipairs(MySQL.query.await('SELECT citizenid, charinfo FROM players WHERE citizenid IN (?)', { cids }) or {}) do
            local ci = json.decode(r.charinfo or '{}') or {}
            names[r.citizenid] = (('%s %s'):format(ci.firstname or '', ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
        end
    end
    -- Joueurs connectés dans le métier mais pas encore dans player_groups (sécurité)
    local seen = {}
    for _, r in ipairs(rows) do seen[r.citizenid] = true end
    for cid, src in pairs(online) do
        local p = core:GetPlayer(src)
        if not seen[cid] and p and p.PlayerData.job.name == job then
            rows[#rows + 1] = { citizenid = cid, grade = p.PlayerData.job.grade.level }
            names[cid] = J.Name(src)
        end
    end
    for _, r in ipairs(rows) do
        local src = online[r.citizenid]
        local lvl = tonumber(r.grade) or 0
        if src then
            local p = core:GetPlayer(src)
            if p and p.PlayerData.job.name == job then lvl = p.PlayerData.job.grade.level end
        end
        local g = J.Grade(job, lvl)
        local specs = {}
        for s in pairs(J.Specs(r.citizenid, job)) do specs[#specs + 1] = s end
        list[#list + 1] = {
            cid = r.citizenid, name = (names[r.citizenid] and names[r.citizenid] ~= '') and names[r.citizenid] or r.citizenid,
            grade = lvl, gradeLabel = g and g.name or ('Grade ' .. lvl), isboss = g and g.isboss == true or false,
            online = src ~= nil, id = src, duty = src and J.OnDuty(src, job) or false, specs = specs,
        }
    end
    table.sort(list, function(a, b) if a.grade ~= b.grade then return a.grade > b.grade end return a.name < b.name end)
    return list
end

-- ---------------------------------------------------------------------
-- Règles de gestion
-- ---------------------------------------------------------------------
-- L'acteur (grade myLvl) peut-il gérer quelqu'un de grade tLvl ?
local function CanManage(job, myLvl, tLvl)
    local me = J.Grade(job, myLvl)
    if not me then return false end
    return tLvl < myLvl
end
-- … et lui donner le grade newLvl ?
local function CanGive(job, myLvl, newLvl)
    local g = J.Grade(job, newLvl)
    if not g then return false end
    return newLvl < myLvl and not g.isboss
end

-- Change le grade d'un membre (en ligne : immédiat ; hors ligne : en base)
local function SetMemberGrade(job, cid, lvl)
    local src = core:GetSourceByCitizenId(cid)
    if src then
        local p = core:GetPlayer(src)
        if p and p.PlayerData.job.name == job then
            local duty = J.OnDuty(src, job)
            p.Functions.SetJob(job, lvl)
            if duty and (Config.Companies[job].duty or 'core') == 'core' then p.Functions.SetJobDuty(true) end
            return true, src
        end
    end
    local ok = core:AddPlayerToJob(cid, job, lvl)
    return ok == true, nil
end

-- ---------------------------------------------------------------------
-- Recrutement par proximité
-- ---------------------------------------------------------------------
local Requests = {}     -- [cible] = { id, job, from, fromCid, grade, expires }
local LastOffer = {}    -- [patron] = GetGameTimer()
local nextId = 0

-- Métier principal actuel (nil si aucun des 5)
local function MainJobOf(src)
    local p = core:GetPlayer(src)
    local name = p and p.PlayerData.job and p.PlayerData.job.name
    return (name and J.IsMain(name)) and name or nil
end

local function Expire(target, why)
    local r = Requests[target]
    if not r then return end
    Requests[target] = nil
    TriggerClientEvent('elyzea_jobs:recruitClosed', target, r.id)
    if why and GetPlayerName(r.from) then J.Notify(r.from, why, 'error') end
end

function HR.Recruit(src, c)
    local now = GetGameTimer()
    if LastOffer[src] and now - LastOffer[src] < Config.Recruit.cooldown * 1000 then
        return { error = ('Patientez %d s avant une nouvelle proposition.'):format(Config.Recruit.cooldown) }
    end
    -- Joueur le plus proche (positions serveur, jamais celles du client)
    local best, bestD
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if id ~= src and core:GetPlayer(id) then
            local d = J.Dist(src, id)
            if d <= Config.Recruit.distance and (not bestD or d < bestD) then best, bestD = id, d end
        end
    end
    if not best then return { error = ('Personne à moins de %d m.'):format(math.floor(Config.Recruit.distance)) } end
    local name = J.Name(best)
    local cur = MainJobOf(best)
    if cur == c.job then return { error = ('%s fait déjà partie de l\'entreprise.'):format(name) } end
    if cur then
        return { error = ('%s travaille déjà pour %s : il doit d\'abord démissionner.'):format(name, J.companies[cur] and J.companies[cur].label or cur) }
    end
    local pending = Requests[best]
    if pending and pending.expires > os.time() then return { error = ('%s a déjà une proposition en attente.'):format(name) } end
    LastOffer[src] = now
    nextId = nextId + 1
    local grade = math.floor(tonumber(Config.Companies[c.job].recruitGrade) or 0)
    if not J.Grade(c.job, grade) then grade = 0 end
    Requests[best] = { id = nextId, job = c.job, from = src, fromCid = J.Cid(src), grade = grade, expires = os.time() + Config.Recruit.timeout }
    TriggerClientEvent('elyzea_jobs:recruitOffer', best, {
        id = nextId, company = c.label, color = Config.Companies[c.job].color, grade = J.Grade(c.job, grade).name,
        from = J.Name(src), timeout = Config.Recruit.timeout,
    })
    local id = nextId
    SetTimeout(Config.Recruit.timeout * 1000 + 500, function()
        local r = Requests[best]
        if r and r.id == id then Expire(best, ('%s n\'a pas répondu à la proposition.'):format(name)) end
    end)
    J.Log(c.job, 'recruit_offer', src, best, nil, J.Grade(c.job, grade).name)
    return { ok = true, message = ('Proposition envoyée à %s (%s).'):format(name, J.Grade(c.job, grade).name) }
end

-- Réponse du joueur ciblé : tout est revérifié
RegisterNetEvent('elyzea_jobs:recruitAnswer', function(id, accept)
    local target = source
    local r = Requests[target]
    if not r or r.id ~= tonumber(id) then return end
    Requests[target] = nil
    TriggerClientEvent('elyzea_jobs:recruitClosed', target, r.id)
    local boss = r.from
    local tName = J.Name(target)
    if not accept then
        J.Log(r.job, 'recruit_refused', { cid = r.fromCid, name = GetPlayerName(boss) and J.Name(boss) or r.fromCid }, target)
        if GetPlayerName(boss) then J.Notify(boss, ('%s a refusé la proposition.'):format(tName), 'error') end
        return J.Notify(target, 'Proposition refusée.', 'inform')
    end
    if os.time() > r.expires then return J.Notify(target, 'La proposition a expiré.', 'error') end
    local function fail(msg)
        J.Notify(target, msg, 'error')
        if GetPlayerName(boss) then J.Notify(boss, msg, 'error') end
    end
    -- Le recruteur est toujours là, dans l'entreprise, avec le droit de recruter
    if not GetPlayerName(boss) or J.Cid(boss) ~= r.fromCid then return fail('Le recruteur n\'est plus connecté.') end
    local c = J.CompanyOf(boss)
    if not c or c.job ~= r.job or not J.Can(boss, 'recruit') then return fail('Le recruteur ne peut plus recruter.') end
    if J.Dist(boss, target) > Config.Recruit.distance * 3 then return fail('Vous êtes trop loin du recruteur.') end
    local cur = MainJobOf(target)
    if cur then return fail(('Vous travaillez déjà pour %s : démissionnez d\'abord.'):format(J.companies[cur] and J.companies[cur].label or cur)) end
    local p = core:GetPlayer(target)
    if not p or not p.Functions.SetJob(r.job, r.grade) then return fail('Recrutement impossible (métier introuvable).') end
    J.Log(r.job, 'recruit', boss, target, nil, J.Grade(r.job, r.grade) and J.Grade(r.job, r.grade).name)
    J.Notify(target, ('Bienvenue chez %s !'):format(J.companies[r.job].label), 'success')
    J.Notify(boss, ('%s a rejoint l\'entreprise.'):format(tName), 'success')
end)

AddEventHandler('playerDropped', function()
    local src = source
    if Requests[src] then
        local r = Requests[src]
        Requests[src] = nil
        if GetPlayerName(r.from) then J.Notify(r.from, 'La personne s\'est déconnectée.', 'error') end
    end
    for t, r in pairs(Requests) do
        if r.from == src then Expire(t) end
    end
    LastOffer[src] = nil
end)

-- ---------------------------------------------------------------------
-- Grades des membres, licenciement, démission
-- ---------------------------------------------------------------------
local function FindMember(job, cid)
    for _, m in ipairs(HR.Members(job)) do if m.cid == cid then return m end end
end

function HR.SetGrade(src, c, myLvl, d)
    local cid, newLvl = tostring(d.cid or ''), math.floor(tonumber(d.grade) or -1)
    if cid == J.Cid(src) then return { error = 'Vous ne pouvez pas changer votre propre grade.' } end
    local m = FindMember(c.job, cid)
    if not m then return { error = 'Employé introuvable.' } end
    if not CanManage(c.job, myLvl, m.grade) then return { error = 'Grade égal ou supérieur au vôtre.' } end
    if not CanGive(c.job, myLvl, newLvl) then return { error = 'Vous ne pouvez donner qu\'un grade inférieur au vôtre.' } end
    if newLvl == m.grade then return { error = 'Il a déjà ce grade.' } end
    local ok, online = SetMemberGrade(c.job, cid, newLvl)
    if not ok then return { error = 'Modification impossible.' } end
    local gname = J.Grade(c.job, newLvl).name
    if online then J.Notify(online, ('Nouveau grade : %s.'):format(gname), newLvl > m.grade and 'success' or 'inform') end
    J.Log(c.job, newLvl > m.grade and 'promote' or 'demote', src, { cid = cid, name = m.name }, nil, ('%s → %s'):format(m.gradeLabel, gname))
    return { ok = true, message = ('%s : %s.'):format(m.name, gname) }
end

function HR.Fire(src, c, myLvl, d)
    local cid = tostring(d.cid or '')
    if cid == J.Cid(src) then return { error = 'Utilisez « Démissionner » pour quitter l\'entreprise.' } end
    local m = FindMember(c.job, cid)
    if not m then return { error = 'Employé introuvable.' } end
    if not CanManage(c.job, myLvl, m.grade) then return { error = 'Grade égal ou supérieur au vôtre.' } end
    local ok = core:RemovePlayerFromJob(cid, c.job)
    if not ok then return { error = 'Licenciement impossible.' } end
    MySQL.query.await('DELETE FROM `elyzea_jobs_specialties` WHERE `citizenid` = ? AND `job` = ?', { cid, c.job })
    if J.specs[cid] then J.specs[cid][c.job] = nil end
    if m.id then J.Notify(m.id, ('Vous avez été licencié de %s.'):format(c.label), 'error') end
    J.Log(c.job, 'fire', src, { cid = cid, name = m.name }, nil, m.gradeLabel)
    return { ok = true, message = ('%s a été licencié.'):format(m.name) }
end

function HR.Resign(src, c, myLvl)
    local g = J.Grade(c.job, myLvl)
    if g and g.isboss then
        local bosses = 0
        for _, m in ipairs(HR.Members(c.job)) do if m.isboss then bosses = bosses + 1 end end
        if bosses <= 1 then return { error = 'Vous êtes le seul patron : nommez quelqu\'un ou contactez le staff avant de partir.' } end
    end
    local p = core:GetPlayer(src)
    if not p or not p.Functions.SetJob('unemployed', 0) then return { error = 'Démission impossible.' } end
    local cid = J.Cid(src)
    MySQL.query.await('DELETE FROM `elyzea_jobs_specialties` WHERE `citizenid` = ? AND `job` = ?', { cid, c.job })
    if J.specs[cid] then J.specs[cid][c.job] = nil end
    J.Log(c.job, 'resign', src, nil, nil, g and g.name)
    return { ok = true, message = ('Vous avez quitté %s.'):format(c.label), closed = true }
end

-- Spécialisation (ex. Police scientifique)
function HR.SetSpecialty(src, c, myLvl, d)
    local specs = Config.Companies[c.job].specialties or {}
    local spec, cid, on = tostring(d.spec or ''), tostring(d.cid or ''), d.on == true
    if not specs[spec] then return { error = 'Spécialisation inconnue.' } end
    if cid == J.Cid(src) then return { error = 'Vous ne pouvez pas modifier vos propres spécialisations.' } end
    local m = FindMember(c.job, cid)
    if not m then return { error = 'Employé introuvable.' } end
    if not CanManage(c.job, myLvl, m.grade) then return { error = 'Grade égal ou supérieur au vôtre.' } end
    if on then
        MySQL.query.await('INSERT IGNORE INTO `elyzea_jobs_specialties` (`citizenid`, `job`, `spec`, `given_by`) VALUES (?, ?, ?, ?)', { cid, c.job, spec, J.Name(src) })
        J.specs[cid] = J.specs[cid] or {}
        J.specs[cid][c.job] = J.specs[cid][c.job] or {}
        J.specs[cid][c.job][spec] = true
    else
        MySQL.query.await('DELETE FROM `elyzea_jobs_specialties` WHERE `citizenid` = ? AND `job` = ? AND `spec` = ?', { cid, c.job, spec })
        if J.specs[cid] and J.specs[cid][c.job] then J.specs[cid][c.job][spec] = nil end
    end
    if m.id then
        J.Notify(m.id, ('%s : %s.'):format(specs[spec].label, on and 'spécialisation accordée' or 'spécialisation retirée'), on and 'success' or 'inform')
        J.PushPerms(m.id)
        TriggerClientEvent('elyzea_jobs:companyChanged', m.id, c.job)
    end
    J.Log(c.job, on and 'spec_add' or 'spec_remove', src, { cid = cid, name = m.name }, nil, specs[spec].label)
    return { ok = true, message = ('%s : %s.'):format(m.name, on and ('spécialisation « ' .. specs[spec].label .. ' » accordée') or 'spécialisation retirée') }
end

-- ---------------------------------------------------------------------
-- Gestion des grades (noms, salaires, accès)
-- ---------------------------------------------------------------------
local function CleanName(v)
    local n = tostring(v or ''):gsub('[<>"]', ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 30)
    return n ~= '' and n or nil
end

-- Accès demandés, limités à ceux que l'acteur possède
local function CleanPerms(src, job, d)
    local out = {}
    for _, p in ipairs(J.PermDefs(job)) do
        out[p.id] = type(d) == 'table' and d[p.id] == true and J.Can(src, p.id) or false
    end
    return out
end

-- Décale d'un cran les membres à partir d'un niveau (ajout / suppression de grade)
local function ShiftMembers(job, fromLevel, delta)
    for _, m in ipairs(HR.Members(job)) do
        if m.grade >= fromLevel then SetMemberGrade(job, m.cid, m.grade + delta) end
    end
end

function HR.GradesData(src, c, myLvl)
    local counts = {}
    for _, m in ipairs(HR.Members(c.job)) do counts[m.grade] = (counts[m.grade] or 0) + 1 end
    local grades = {}
    for i, g in ipairs(c.grades) do
        local lvl = i - 1
        grades[#grades + 1] = { level = lvl, name = g.name, payment = g.payment, isboss = g.isboss == true,
            perms = g.isboss and 'all' or (g.perms or {}), members = counts[lvl] or 0, editable = lvl < myLvl and not g.isboss }
    end
    local mine = {}
    for _, p in ipairs(J.PermDefs(c.job)) do mine[p.id] = J.Can(src, p.id) end
    return { grades = grades, labels = J.PermDefs(c.job), mine = mine, myLevel = myLvl, maxSalary = Config.Grades.maxSalary, maxGrades = Config.Grades.max }
end

local function Salary(v)
    local pay = math.floor(tonumber(v) or -1)
    if pay < 0 or pay > Config.Grades.maxSalary then return nil end
    return pay
end

function HR.SaveGrade(src, c, myLvl, d)
    local lvl = math.floor(tonumber(d.level) or -1)
    local g = c.grades[lvl + 1]
    if not g then return { error = 'Grade inexistant.' } end
    if lvl >= myLvl or g.isboss then return { error = 'Vous ne pouvez modifier que les grades en dessous du vôtre.' } end
    local name, pay = CleanName(d.name), Salary(d.payment)
    if not name then return { error = 'Donnez un nom au grade.' } end
    if not pay then return { error = ('Salaire entre 0 et %d $.'):format(Config.Grades.maxSalary) } end
    local before = g.name
    g.name, g.payment, g.perms = name, pay, CleanPerms(src, c.job, d.perms)
    J.Save(c.job)
    J.Apply(c.job)
    J.Log(c.job, 'grade_edit', src, nil, pay, ('%d · %s%s'):format(lvl, name, before ~= name and (' (ex-' .. before .. ')') or ''))
    return { ok = true, message = ('Grade « %s » enregistré.'):format(name) }
end

function HR.CreateGrade(src, c, myLvl, d)
    if #c.grades >= Config.Grades.max then return { error = 'Nombre maximum de grades atteint.' } end
    local pos = math.floor(tonumber(d.position) or -1)   -- niveau du nouveau grade (les grades à partir de ce niveau montent d'un cran)
    if pos < 0 or pos > myLvl then return { error = 'Le nouveau grade doit être en dessous du vôtre.' } end
    local name, pay = CleanName(d.name), Salary(d.payment)
    if not name then return { error = 'Donnez un nom au grade.' } end
    if not pay then return { error = ('Salaire entre 0 et %d $.'):format(Config.Grades.maxSalary) } end
    table.insert(c.grades, pos + 1, { name = name, payment = pay, perms = CleanPerms(src, c.job, d.perms) })
    J.Save(c.job)
    J.Apply(c.job)                 -- le métier connaît d'abord le nouveau grade…
    ShiftMembers(c.job, pos, 1)    -- …puis les membres au-dessus montent d'un cran : ils gardent leur grade
    J.Log(c.job, 'grade_create', src, nil, pay, ('%d · %s'):format(pos, name))
    return { ok = true, message = ('Grade « %s » créé.'):format(name) }
end

function HR.DeleteGrade(src, c, myLvl, d)
    local lvl = math.floor(tonumber(d.level) or -1)
    local g = c.grades[lvl + 1]
    if not g then return { error = 'Grade inexistant.' } end
    if lvl >= myLvl or g.isboss then return { error = 'Vous ne pouvez supprimer que les grades en dessous du vôtre.' } end
    if #c.grades <= 2 then return { error = 'Il faut garder au moins deux grades.' } end
    for _, m in ipairs(HR.Members(c.job)) do
        if m.grade == lvl then return { error = 'Des employés ont encore ce grade : changez-leur de grade avant.' } end
    end
    table.remove(c.grades, lvl + 1)
    J.Save(c.job)
    J.Apply(c.job)                    -- le métier sans ce grade…
    ShiftMembers(c.job, lvl + 1, -1)  -- …puis les membres au-dessus descendent d'un cran (leur grade ne change pas)
    J.Log(c.job, 'grade_delete', src, nil, nil, ('%d · %s'):format(lvl, g.name))
    return { ok = true, message = ('Grade « %s » supprimé.'):format(g.name) }
end
