-- =====================================================================
--  ELYZEA EMS - serveur : direction (recrutement, employés, grades, permissions)
--  Règles de hiérarchie (vérifiées ici, jamais par l'interface) :
--   · on n'agit que sur un employé de niveau INFÉRIEUR au sien, jamais sur soi-même ;
--   · on ne donne qu'un grade de niveau inférieur au sien ;
--   · on ne crée / modifie que des grades de niveau inférieur au sien ;
--   · on ne donne à un grade que des permissions que l'on possède.
--  Le staff (admin_menu › Métier staff) passe par Ems.AdminSetGrade (api.lua).
-- =====================================================================
local P = Ems
local core = exports.elyzea_core
local R = Config.Recruit

local function MyLevel(src) local g = P.Grade(src) return g and g.level or -1 end

local function EmployeeView(e, withOnline)
    local g = P.grades[e.grade_id]
    local v = { cid = e.citizenid, name = e.name, matricule = e.matricule, gradeId = e.grade_id, grade = g and g.name or '?', level = g and g.level or 0,
        recruited = e.recruited, promoted = e.promoted, note = e.note,
        total = e.total_seconds, unpaid = e.unpaid_seconds, unpaidAmount = math.floor(e.unpaid_amount) }
    if withOnline then
        local src = core:GetSourceByCitizenId(e.citizenid)
        v.online = src ~= nil
        v.duty = src ~= nil and P.OnDuty(src) or false
        v.status = src and P.status[src] or nil
    end
    return v
end

-- ---------------------------------------------------------------------
-- Recrutement : joueur valide le plus proche, demande Accepter / Refuser
-- ---------------------------------------------------------------------
local Requests = {}     -- [cible] = { id, from, gradeId, expires }
local lastRecruit = {}
local reqSeq = 0

local function Nearest(src)
    local c = P.Coords(src)
    if not c then return nil end
    local best, bestD
    for id in pairs(core:GetPlayers()) do
        if id ~= src then
            local tc = P.Coords(id)
            local d = tc and #(tc - c) or 9999
            if d <= R.distance and (not bestD or d < bestD) then best, bestD = id, d end
        end
    end
    return best, bestD
end

-- Aperçu : qui va recevoir la demande (vérification de l'identité avant l'envoi)
P.Actions.recruitPreview = { perm = 'recruit', fn = function(src)
    local t, d = Nearest(src)
    if not t then return { error = ('Personne à moins de %d m.'):format(math.floor(R.distance)) } end
    local tp = P.GetPlayer(t)
    local grades = {}
    for _, g in ipairs(P.SortedGrades()) do if g.level < MyLevel(src) then grades[#grades + 1] = { id = g.id, name = g.name, level = g.level } end end
    local def = P.DefaultGrade()
    return { target = { id = t, name = P.Name(t), distance = math.floor(d * 10) / 10, job = tp and tp.PlayerData.job and tp.PlayerData.job.label or '?',
        already = P.employees[tp and tp.PlayerData.citizenid or ''] ~= nil, pending = Requests[t] ~= nil },
        grades = grades, defaultGrade = def and def.id }
end }

P.Actions.recruitSend = { perm = 'recruit', fn = function(src, d)
    local t = tonumber(d.target)
    if not t or t == src or not GetPlayerName(t) then return { error = 'Personne introuvable.' } end
    if P.Dist(src, t) > R.distance + 1.0 then return { error = 'La personne s\'est éloignée.' } end
    local now = os.time()
    if lastRecruit[src] and now - lastRecruit[src] < R.cooldown then return { error = 'Patientez quelques secondes.' } end
    local tp = P.GetPlayer(t)
    if not tp then return { error = 'Personne introuvable.' } end
    if P.employees[tp.PlayerData.citizenid] then return { error = 'Cette personne est déjà à l\'EMS.' } end
    if Requests[t] and Requests[t].expires > now then return { error = 'Une demande est déjà en attente pour cette personne.' } end
    local grade = P.grades[tonumber(d.gradeId) or 0] or P.DefaultGrade()
    if not grade or grade.level >= MyLevel(src) then return { error = 'Vous ne pouvez recruter qu\'à un grade inférieur au vôtre.' } end
    lastRecruit[src] = now
    reqSeq = reqSeq + 1
    Requests[t] = { id = reqSeq, from = src, fromCid = P.Cid(src), gradeId = grade.id, expires = now + R.timeout }
    TriggerClientEvent('ems:client:recruitOffer', t, { id = reqSeq, from = P.Name(src), grade = grade.name, job = Config.Job.label, timeout = R.timeout,
        current = tp.PlayerData.job and tp.PlayerData.job.name ~= 'unemployed' and tp.PlayerData.job.label or nil })
    local id = reqSeq
    SetTimeout(R.timeout * 1000 + 500, function()
        local r = Requests[t]
        if r and r.id == id then
            Requests[t] = nil
            TriggerClientEvent('ems:client:recruitClosed', t, id)
            if GetPlayerName(src) then P.Notify(src, ('%s n\'a pas répondu à temps.'):format(P.Name(t)), 'error') end
        end
    end)
    return { ok = true, message = ('Demande envoyée à %s.'):format(P.Name(t)) }
end }

RegisterNetEvent('ems:server:recruitAnswer', function(id, accept)
    local t = source
    local r = Requests[t]
    if not r or r.id ~= tonumber(id) then return end
    Requests[t] = nil
    local src = r.from
    local online = GetPlayerName(src) ~= nil
    if accept ~= true then
        if online then P.Notify(src, ('%s a refusé de rejoindre l\'EMS.'):format(P.Name(t)), 'error') end
        return P.Notify(t, 'Vous avez refusé la proposition.', 'inform')
    end
    -- Revérification complète au moment de la réponse
    if os.time() > r.expires then return P.Notify(t, 'La proposition a expiré.', 'error') end
    if not online or not P.Can(src, 'recruit') then return P.Notify(t, 'La personne qui vous recrutait n\'est plus disponible.', 'error') end
    local grade = P.grades[r.gradeId] or P.DefaultGrade()
    if not grade or grade.level >= MyLevel(src) then return P.Notify(t, 'Recrutement impossible.', 'error') end
    local cid = P.Cid(t)
    if not cid or P.employees[cid] then return P.Notify(t, 'Vous êtes déjà à l\'EMS.', 'error') end
    local ok, mat = P.Hire(cid, P.Name(t), grade)
    if not ok then return P.Notify(t, mat or 'Recrutement impossible.', 'error') end
    P.AddLog(src, cid, P.Name(t), 'Recrutement', nil, grade.name, nil)
    P.Notify(t, ('Bienvenue au %s : grade %s, matricule %s.'):format(Config.Job.label, grade.name, mat), 'success')
    P.Notify(src, ('%s a rejoint l\'EMS (%s, %s).'):format(P.Name(t), grade.name, mat), 'success')
    P.Log(src, 'Recrutement', ('%s · %s · %s'):format(P.Name(t), grade.name, mat))
end)

AddEventHandler('playerDropped', function()
    local src = source
    if Requests[src] then
        local r = Requests[src]
        Requests[src] = nil
        if GetPlayerName(r.from) then P.Notify(r.from, 'La personne s\'est déconnectée : demande annulée.', 'error') end
    end
    for t, r in pairs(Requests) do
        if r.from == src then Requests[t] = nil TriggerClientEvent('ems:client:recruitClosed', t, r.id) end
    end
    lastRecruit[src] = nil
end)

-- ---------------------------------------------------------------------
-- Employés
-- ---------------------------------------------------------------------
P.Actions.employees = { perm = 'employees_view', fn = function(src)
    local list = {}
    for _, e in pairs(P.employees) do list[#list + 1] = EmployeeView(e, true) end
    table.sort(list, function(a, b) if a.level ~= b.level then return a.level > b.level end return a.name < b.name end)
    local grades = {}
    for _, g in ipairs(P.SortedGrades()) do grades[#grades + 1] = { id = g.id, name = g.name, level = g.level } end
    return { list = list, grades = grades, myLevel = MyLevel(src), myCid = P.Cid(src) }
end }

P.Actions.employee = { perm = 'employees_view', fn = function(src, d)
    local e = P.employees[tostring(d.cid or '')]
    if not e then return { error = 'Employé introuvable.' } end
    local v = EmployeeView(e, true)
    local mine = MyLevel(src)
    v.canAct = e.citizenid ~= P.Cid(src) and v.level < mine
    v.history = P.Can(src, 'history_view') and (MySQL.query.await([[SELECT `actor_name`, `action`, `old_grade`, `new_grade`, `reason`, UNIX_TIMESTAMP(`created_at`) AS t
        FROM `ems_admin_log` WHERE `target_cid` = ? ORDER BY `id` DESC LIMIT 30]], { e.citizenid }) or {}) or nil
    v.reports = MySQL.scalar.await('SELECT COUNT(*) FROM `ems_reports` WHERE `author_cid` = ?', { e.citizenid }) or 0
    v.treatments = MySQL.scalar.await('SELECT COUNT(*) FROM `ems_treatments` WHERE `ems_cid` = ?', { e.citizenid }) or 0
    v.sessions = MySQL.query.await([[SELECT `grade_name`, `seconds`, `amount`, `end_reason`, UNIX_TIMESTAMP(`started_at`) AS s, UNIX_TIMESTAMP(`ended_at`) AS e
        FROM `ems_sessions` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 20]], { e.citizenid }) or {}
    return { employee = v }
end }

local function CheckTarget(src, cid)
    local e = P.employees[tostring(cid or '')]
    if not e then return nil, 'Employé introuvable.' end
    if e.citizenid == P.Cid(src) then return nil, 'Vous ne pouvez pas agir sur votre propre fiche.' end
    local g = P.grades[e.grade_id]
    if g and g.level >= MyLevel(src) then return nil, 'Cet employé a un grade égal ou supérieur au vôtre.' end
    return e, nil, g
end

-- Promotion, rétrogradation et changement de grade : une seule action, droits selon le sens
P.Actions.setGrade = { perm = 'employees_view', fn = function(src, d)
    local e, why, old = CheckTarget(src, d.cid)
    if not e then return { error = why } end
    local new = P.grades[tonumber(d.gradeId) or 0]
    if not new then return { error = 'Grade introuvable.' } end
    if old and new.id == old.id then return { error = 'C\'est déjà son grade.' } end
    if new.level >= MyLevel(src) then return { error = 'Vous ne pouvez pas donner un grade égal ou supérieur au vôtre.' } end
    local up = not old or new.level > old.level
    if up and not P.Can(src, 'promote') then return { error = 'Votre grade ne permet pas de promouvoir.' } end
    if not up and not P.Can(src, 'demote') then return { error = 'Votre grade ne permet pas de rétrograder.' } end
    P.ApplyGrade(e.citizenid, new)
    if up then
        e.promoted = os.date('%d/%m/%Y')
        MySQL.update('UPDATE `ems_employees` SET `promoted_at` = NOW() WHERE `citizenid` = ?', { e.citizenid })
    end
    local reason = P.Clean(d.reason, 255)
    P.AddLog(src, e.citizenid, e.name, up and 'Promotion' or 'Rétrogradation', old and old.name, new.name, reason ~= '' and reason or nil)
    local tsrc = core:GetSourceByCitizenId(e.citizenid)
    if tsrc then P.Notify(tsrc, ('%s : vous êtes maintenant %s.'):format(up and 'Promotion' or 'Rétrogradation', new.name), up and 'success' or 'inform') end
    P.Log(src, up and 'Promotion' or 'Rétrogradation', ('%s · %s → %s'):format(e.name, old and old.name or '?', new.name))
    return { ok = true, message = ('%s est maintenant %s.'):format(e.name, new.name) }
end }

P.Actions.fire = { perm = 'fire', fn = function(src, d)
    local e, why, old = CheckTarget(src, d.cid)
    if not e then return { error = why } end
    local reason = P.Clean(d.reason, 255)
    local tsrc = core:GetSourceByCitizenId(e.citizenid)
    P.FlushCid(e.citizenid)
    -- Salaire dû : la direction choisit de le payer avant (Finance) ou de l'abandonner en connaissance de cause
    if math.floor(e.unpaid_amount) > 0 and d.dropUnpaid ~= true then
        return { error = ('%s a %d $ de salaire non payé : payez-le dans Finance avant le renvoi, ou confirmez l\'abandon.'):format(e.name, math.floor(e.unpaid_amount)),
            unpaid = math.floor(e.unpaid_amount) }
    end
    if math.floor(e.unpaid_amount) > 0 then
        P.AddLog(src, e.citizenid, e.name, 'Salaire abandonné', nil, nil, ('%d $ non payés au renvoi'):format(math.floor(e.unpaid_amount)))
    end
    P.Remove(e.citizenid)
    P.AddLog(src, e.citizenid, e.name, 'Renvoi', old and old.name, nil, reason ~= '' and reason or nil)
    if tsrc then P.Notify(tsrc, ('Vous ne faites plus partie de l\'EMS%s.'):format(reason ~= '' and (' : ' .. reason) or ''), 'error') end
    P.Log(src, 'Renvoi', ('%s · %s'):format(e.name, reason))
    return { ok = true, message = ('%s a été retiré(e) de l\'EMS.'):format(e.name) }
end }

P.Actions.editEmployee = { perm = 'employees_edit', fn = function(src, d)
    local e, why = CheckTarget(src, d.cid)
    if not e then return { error = why } end
    local mat = P.Clean(d.matricule, 20):upper()
    if #mat < 2 then return { error = 'Matricule invalide.' } end
    for _, o in pairs(P.employees) do
        if o.citizenid ~= e.citizenid and o.matricule == mat then return { error = 'Ce matricule est déjà utilisé.' } end
    end
    local note = P.Clean(d.note, 255)
    MySQL.update.await('UPDATE `ems_employees` SET `matricule` = ?, `note` = ? WHERE `citizenid` = ?', { mat, note ~= '' and note or nil, e.citizenid })
    local changed = e.matricule ~= mat
    local before = e.matricule
    e.matricule, e.note = mat, note ~= '' and note or nil
    if changed then P.AddLog(src, e.citizenid, e.name, 'Matricule modifié', before, mat, nil) end
    local tsrc = core:GetSourceByCitizenId(e.citizenid)
    if tsrc then P.PushState(tsrc) end
    return { ok = true, message = 'Fiche enregistrée.' }
end }

-- Démission (tablette › Agents › ma fiche) : impossible pour le dernier plus haut gradé
P.Actions.resign = { perm = nil, fn = function(src, d)
    local cid = P.Cid(src)
    local g = P.Grade(src)
    if g and g.level == P.TopLevel() then
        local others = 0
        for c, e in pairs(P.employees) do if c ~= cid and P.grades[e.grade_id] and P.grades[e.grade_id].level == g.level then others = others + 1 end end
        if others == 0 then return { error = 'Vous êtes le seul au plus haut grade : nommez quelqu\'un avant de partir.' } end
    end
    local name = P.Name(src)
    P.FlushCid(cid)
    local e = P.employees[cid]
    if e and math.floor(e.unpaid_amount) > 0 and d.dropUnpaid ~= true then
        return { error = ('Vous avez %d $ de salaire non payé : demandez votre paie à la direction avant de partir, ou confirmez l\'abandon.'):format(math.floor(e.unpaid_amount)),
            unpaid = math.floor(e.unpaid_amount) }
    end
    P.Remove(cid)
    P.AddLog(src, cid, name, 'Démission', g and g.name, nil, e and math.floor(e.unpaid_amount) > 0 and ('%d $ non payés abandonnés'):format(math.floor(e.unpaid_amount)) or nil)
    return { ok = true, message = 'Vous avez quitté l\'EMS.' }
end }

P.Actions.history = { perm = 'history_view', fn = function(_, d)
    local q = P.Clean(d.q, 60):gsub('[%%_]', '')
    local rows
    if q ~= '' then
        local like = '%' .. q .. '%'
        rows = MySQL.query.await([[SELECT `actor_name`, `target_name`, `action`, `old_grade`, `new_grade`, `reason`, UNIX_TIMESTAMP(`created_at`) AS t FROM `ems_admin_log`
            WHERE `actor_name` LIKE ? OR `target_name` LIKE ? OR `action` LIKE ? ORDER BY `id` DESC LIMIT 150]], { like, like, like })
    else
        rows = MySQL.query.await([[SELECT `actor_name`, `target_name`, `action`, `old_grade`, `new_grade`, `reason`, UNIX_TIMESTAMP(`created_at`) AS t
            FROM `ems_admin_log` ORDER BY `id` DESC LIMIT 150]])
    end
    return { list = rows or {} }
end }

-- ---------------------------------------------------------------------
-- Grades et permissions
-- ---------------------------------------------------------------------
local function GradeView(g)
    local count = 0
    for _, e in pairs(P.employees) do if e.grade_id == g.id then count = count + 1 end end
    local perms = {}
    for k in pairs(g.perms) do perms[#perms + 1] = k end
    return { id = g.id, name = g.name, level = g.level, isDefault = g.isDefault, perms = perms, members = count }
end

P.Actions.grades = { perm = 'direction', fn = function(src)
    local list = {}
    for _, g in ipairs(P.SortedGrades()) do list[#list + 1] = GradeView(g) end
    local mine = {}
    for k in pairs(P.Grade(src).perms) do mine[k] = true end
    return { list = list, myLevel = MyLevel(src), myPerms = mine, permList = EmsPerms,
        canGrades = P.Can(src, 'grades_manage'), canPerms = P.Can(src, 'perms_manage') }
end }

local function AfterGradeChange()
    P.SyncCoreJob()
    P.PushAll()
end

local function ValidName(src, name, exceptId)
    name = P.Clean(name, 50)
    if #name < 2 then return nil, 'Nom de grade trop court.' end
    for _, g in pairs(P.grades) do
        if g.id ~= exceptId and g.name:lower() == name:lower() then return nil, 'Un grade porte déjà ce nom.' end
    end
    return name
end
local function ValidLevel(src, level, exceptId)
    level = P.Int(level, 1, 99, nil)
    if not level then return nil, 'Niveau invalide (1 à 99).' end
    if level >= MyLevel(src) then return nil, 'Le niveau doit être inférieur au vôtre.' end
    for _, g in pairs(P.grades) do
        if g.id ~= exceptId and g.level == level then return nil, ('Le niveau %d est déjà utilisé par « %s ».'):format(level, g.name) end
    end
    return level
end

P.Actions.gradeSave = { perm = 'grades_manage', fn = function(src, d)
    local id = tonumber(d.id)
    local g = id and P.grades[id] or nil
    if id and not g then return { error = 'Grade introuvable.' } end
    if g and g.level >= MyLevel(src) then return { error = 'Vous ne pouvez modifier que les grades inférieurs au vôtre.' } end
    local name, e1 = ValidName(src, d.name, id)
    if not name then return { error = e1 } end
    local level, e2 = ValidLevel(src, d.level, id)
    if not level then return { error = e2 } end
    local isDefault = d.isDefault == true
    if g then
        local oldLevel = g.level
        MySQL.update.await('UPDATE `ems_grades` SET `name` = ?, `level` = ? WHERE `id` = ?', { name, level, g.id })
        g.name, g.level = name, level
        if oldLevel ~= level then
            -- Les employés de ce grade suivent son nouveau niveau dans elyzea_core
            for cid, e in pairs(P.employees) do if e.grade_id == g.id then P.ApplyGrade(cid, g) end end
        end
    else
        local newId = MySQL.insert.await('INSERT INTO `ems_grades` (`name`, `level`, `salary`, `perms`) VALUES (?, ?, ?, ?)', { name, level, 0, '[]' })
        if not newId then return { error = 'Enregistrement impossible.' } end
        g = { id = newId, name = name, level = level, salary = 0, perms = {}, isDefault = false }
        P.grades[newId] = g
    end
    if isDefault and not g.isDefault then
        MySQL.update.await('UPDATE `ems_grades` SET `is_default` = (`id` = ?)', { g.id })
        for _, o in pairs(P.grades) do o.isDefault = o.id == g.id end
    end
    AfterGradeChange()
    P.AddLog(src, nil, nil, id and 'Grade modifié' or 'Grade créé', nil, name, ('niveau %d'):format(level))
    return { ok = true, id = g.id, message = id and 'Grade enregistré.' or ('Grade « %s » créé.'):format(name) }
end }

-- Suppression : les employés du grade doivent être réaffectés à un grade valide
P.Actions.gradeDelete = { perm = 'grades_manage', fn = function(src, d)
    local g = P.grades[tonumber(d.id) or 0]
    if not g then return { error = 'Grade introuvable.' } end
    if g.level >= MyLevel(src) then return { error = 'Vous ne pouvez supprimer que les grades inférieurs au vôtre.' } end
    local count = 0
    for _ in pairs(P.employees) do count = count + 1 end
    local members = {}
    for cid, e in pairs(P.employees) do if e.grade_id == g.id then members[#members + 1] = cid end end
    local target
    if #members > 0 then
        target = P.grades[tonumber(d.reassign) or 0]
        if not target or target.id == g.id then return { error = ('%d employé(s) ont ce grade : choisissez le grade où les réaffecter.'):format(#members), needReassign = true } end
        if target.level >= MyLevel(src) then return { error = 'Le grade de réaffectation doit être inférieur au vôtre.' } end
    end
    local n = 0
    for _ in pairs(P.grades) do n = n + 1 end
    if n <= 1 then return { error = 'Il faut garder au moins un grade.' } end
    for _, cid in ipairs(members) do P.ApplyGrade(cid, target) end
    MySQL.update.await('DELETE FROM `ems_grades` WHERE `id` = ?', { g.id })
    P.grades[g.id] = nil
    if g.isDefault then
        local def = P.SortedGrades()[1]
        if def then
            def.isDefault = true
            MySQL.update.await('UPDATE `ems_grades` SET `is_default` = 1 WHERE `id` = ?', { def.id })
        end
    end
    AfterGradeChange()
    P.AddLog(src, nil, nil, 'Grade supprimé', g.name, target and target.name, #members > 0 and ('%d employé(s) réaffecté(s)'):format(#members) or nil)
    return { ok = true, message = ('Grade « %s » supprimé%s.'):format(g.name, #members > 0 and (' · ' .. #members .. ' employé(s) réaffecté(s)') or '') }
end }

P.Actions.gradePerms = { perm = 'perms_manage', fn = function(src, d)
    local g = P.grades[tonumber(d.id) or 0]
    if not g then return { error = 'Grade introuvable.' } end
    if g.level >= MyLevel(src) then return { error = 'Vous ne pouvez modifier que les grades inférieurs au vôtre.' } end
    local mine = P.Grade(src).perms
    local set = {}
    -- Une permission que l'on n'a pas : on ne peut ni la donner ni la retirer (elle reste comme avant)
    for k in pairs(g.perms) do if not mine[k] then set[k] = true end end
    for _, k in ipairs(type(d.perms) == 'table' and d.perms or {}) do
        if EmsPermSet[k] and mine[k] then set[k] = true end
    end
    g.perms = set
    MySQL.update.await('UPDATE `ems_grades` SET `perms` = ? WHERE `id` = ?', { P.EncodePerms(set), g.id })
    AfterGradeChange()
    P.AddLog(src, nil, nil, 'Permissions modifiées', nil, g.name, nil)
    return { ok = true, message = ('Permissions de « %s » enregistrées.'):format(g.name) }
end }
