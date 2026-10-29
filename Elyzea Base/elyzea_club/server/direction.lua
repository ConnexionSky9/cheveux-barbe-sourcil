-- =====================================================================
--  ELYZEA BOÎTE DE NUIT - serveur : direction (recrutement, employés, grades, permissions)
--  Tout est limité à la boîte de l'employé (D) : personnel et grades de SA boîte.
--  Hiérarchie (vérifiée ici, jamais par l'interface) :
--   · on n'agit que sur un employé de niveau INFÉRIEUR au sien, jamais sur soi-même ;
--   · on ne donne qu'un grade de niveau inférieur au sien ;
--   · on ne crée / modifie que des grades de niveau inférieur au sien ;
--   · on ne donne à un grade que des permissions que l'on possède.
-- =====================================================================
local P = Club
local core = exports.elyzea_core
local R = Config.Recruit

local function MyLevel(src) local g = P.Grade(src) return g and g.level or -1 end
local function ShopGrade(D, id) local g = P.grades[tonumber(id) or 0] return g and g.shop_id == D.id and g or nil end

local function EmployeeView(e, withOnline)
    local g = P.grades[e.grade_id]
    local v = { cid = e.citizenid, name = e.name, matricule = e.matricule, gradeId = e.grade_id, grade = g and g.name or '?', level = g and g.level or 0,
        recruited = e.recruited, promoted = e.promoted, note = e.note, total = e.total_seconds, unpaid = e.unpaid_seconds, unpaidAmount = math.floor(e.unpaid_amount) }
    if withOnline then
        local src = core:GetSourceByCitizenId(e.citizenid)
        v.online, v.duty, v.status = src ~= nil, src ~= nil and P.OnDuty(src) or false, src and P.status[src] or nil
    end
    return v
end

-- ---------------------------------------------------------------------
-- Recrutement : personne la plus proche, Accepter / Refuser
-- ---------------------------------------------------------------------
local Requests, lastRecruit, reqSeq = {}, {}, 0

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

P.Actions.recruitPreview = { perm = 'recruit', fn = function(src, _, D)
    local t, d = Nearest(src)
    if not t then return { error = ('Personne à moins de %d m.'):format(math.floor(R.distance)) } end
    local tp = P.GetPlayer(t)
    local grades = {}
    for _, g in ipairs(P.SortedGrades(D.id)) do if g.level < MyLevel(src) and g.active ~= false then grades[#grades + 1] = { id = g.id, name = g.name, level = g.level } end end
    local def = P.DefaultGrade(D.id)
    local cur = P.employees[tp and tp.PlayerData.citizenid or '']
    return { target = { id = t, name = P.Name(t), distance = math.floor(d * 10) / 10, job = tp and tp.PlayerData.job and tp.PlayerData.job.label or '?',
        already = cur ~= nil, pending = Requests[t] ~= nil }, grades = grades, defaultGrade = def and def.id }
end }

P.Actions.recruitSend = { perm = 'recruit', fn = function(src, d, D)
    local t = tonumber(d.target)
    if not t or t == src or not GetPlayerName(t) then return { error = 'Personne introuvable.' } end
    if P.Dist(src, t) > R.distance + 1.0 then return { error = 'La personne s\'est éloignée.' } end
    local now = os.time()
    if lastRecruit[src] and now - lastRecruit[src] < R.cooldown then return { error = 'Patientez quelques secondes.' } end
    local tp = P.GetPlayer(t)
    if not tp then return { error = 'Personne introuvable.' } end
    if P.employees[tp.PlayerData.citizenid] then return { error = 'Cette personne travaille déjà dans une boîte.' } end
    if Requests[t] and Requests[t].expires > now then return { error = 'Une demande est déjà en attente pour cette personne.' } end
    local grade = ShopGrade(D, d.gradeId) or P.DefaultGrade(D.id)
    if not grade or grade.level >= MyLevel(src) then return { error = 'Vous ne pouvez recruter qu\'à un grade inférieur au vôtre.' } end
    if grade.active == false then return { error = 'Ce grade est désactivé.' } end
    lastRecruit[src] = now
    reqSeq = reqSeq + 1
    Requests[t] = { id = reqSeq, from = src, shop = D.id, gradeId = grade.id, expires = now + R.timeout }
    TriggerClientEvent('club:client:recruitOffer', t, { id = reqSeq, from = P.Name(src), grade = grade.name, job = D.name, timeout = R.timeout,
        current = tp.PlayerData.job and tp.PlayerData.job.name ~= 'unemployed' and tp.PlayerData.job.label or nil })
    local id = reqSeq
    SetTimeout(R.timeout * 1000 + 500, function()
        local r = Requests[t]
        if r and r.id == id then
            Requests[t] = nil
            TriggerClientEvent('club:client:recruitClosed', t, id)
            if GetPlayerName(src) then P.Notify(src, ('%s n\'a pas répondu à temps.'):format(P.Name(t)), 'error') end
        end
    end)
    return { ok = true, message = ('Demande envoyée à %s.'):format(P.Name(t)) }
end }

RegisterNetEvent('club:server:recruitAnswer', function(id, accept)
    local t = source
    local r = Requests[t]
    if not r or r.id ~= tonumber(id) then return end
    Requests[t] = nil
    local src = r.from
    local D = P.shops[r.shop]
    local online = GetPlayerName(src) ~= nil
    if accept ~= true then
        if online then P.Notify(src, ('%s a refusé de rejoindre la boîte.'):format(P.Name(t)), 'error') end
        return P.Notify(t, 'Vous avez refusé la proposition.', 'inform')
    end
    if os.time() > r.expires then return P.Notify(t, 'La proposition a expiré.', 'error') end
    local SD = online and P.ShopOf(src)
    if not D or not SD or SD.id ~= D.id or not P.Can(src, 'recruit') then return P.Notify(t, 'La personne qui vous recrutait n\'est plus disponible.', 'error') end
    local grade = ShopGrade(D, r.gradeId) or P.DefaultGrade(D.id)
    if not grade or grade.level >= MyLevel(src) then return P.Notify(t, 'Recrutement impossible.', 'error') end
    local cid = P.Cid(t)
    if not cid or P.employees[cid] then return P.Notify(t, 'Vous travaillez déjà dans une boîte.', 'error') end
    local ok, mat = P.Hire(D, cid, P.Name(t), grade)
    if not ok then return P.Notify(t, mat or 'Recrutement impossible.', 'error') end
    P.AddLog(D.id, src, cid, P.Name(t), 'Recrutement', nil, grade.name, nil)
    P.Notify(t, ('Bienvenue chez %s : grade %s, matricule %s.'):format(D.name, grade.name, mat), 'success')
    P.Notify(src, ('%s a rejoint %s (%s, %s).'):format(P.Name(t), D.name, grade.name, mat), 'success')
    P.Log(src, 'Recrutement', ('%s · %s · %s · %s'):format(D.name, P.Name(t), grade.name, mat))
end)

AddEventHandler('playerDropped', function()
    local src = source
    if Requests[src] then
        local r = Requests[src]
        Requests[src] = nil
        if GetPlayerName(r.from) then P.Notify(r.from, 'La personne s\'est déconnectée : demande annulée.', 'error') end
    end
    for t, r in pairs(Requests) do
        if r.from == src then Requests[t] = nil TriggerClientEvent('club:client:recruitClosed', t, r.id) end
    end
    lastRecruit[src] = nil
end)

-- ---------------------------------------------------------------------
-- Employés
-- ---------------------------------------------------------------------
P.Actions.employees = { perm = 'employees_view', fn = function(src, _, D)
    local list = {}
    for _, e in pairs(P.ShopEmployees(D.id)) do list[#list + 1] = EmployeeView(e, true) end
    table.sort(list, function(a, b) if a.level ~= b.level then return a.level > b.level end return a.name < b.name end)
    local grades = {}
    for _, g in ipairs(P.SortedGrades(D.id)) do if g.active ~= false then grades[#grades + 1] = { id = g.id, name = g.name, level = g.level } end end
    return { list = list, grades = grades, myLevel = MyLevel(src), myCid = P.Cid(src) }
end }

P.Actions.employee = { perm = 'employees_view', fn = function(src, d, D)
    local e = P.employees[tostring(d.cid or '')]
    if not e or e.shop_id ~= D.id then return { error = 'Employé introuvable.' } end
    local v = EmployeeView(e, true)
    v.canAct = e.citizenid ~= P.Cid(src) and v.level < MyLevel(src)
    v.history = P.Can(src, 'history_view') and (MySQL.query.await([[SELECT `actor_name`, `action`, `old_grade`, `new_grade`, `reason`, UNIX_TIMESTAMP(`created_at`) AS t
        FROM `cl_admin_log` WHERE `shop_id` = ? AND `target_cid` = ? ORDER BY `id` DESC LIMIT 30]], { D.id, e.citizenid }) or {}) or nil
    local st = MySQL.single.await([[SELECT COUNT(*) AS n, COALESCE(SUM(`price`), 0) AS total FROM `cl_sales` WHERE `shop_id` = ? AND `seller_cid` = ? AND `status` = 'paid']],
        { D.id, e.citizenid }) or {}
    v.sales, v.revenue = tonumber(st.n) or 0, tonumber(st.total) or 0
    v.sessions = MySQL.query.await([[SELECT `grade_name`, `seconds`, `amount`, `end_reason`, UNIX_TIMESTAMP(`started_at`) AS s, UNIX_TIMESTAMP(`ended_at`) AS e
        FROM `cl_sessions` WHERE `shop_id` = ? AND `citizenid` = ? ORDER BY `id` DESC LIMIT 20]], { D.id, e.citizenid }) or {}
    return { employee = v }
end }

local function CheckTarget(src, D, cid)
    local e = P.employees[tostring(cid or '')]
    if not e or e.shop_id ~= D.id then return nil, 'Employé introuvable.' end
    if e.citizenid == P.Cid(src) then return nil, 'Vous ne pouvez pas agir sur votre propre fiche.' end
    local g = P.grades[e.grade_id]
    if g and g.level >= MyLevel(src) then return nil, 'Cet employé a un grade égal ou supérieur au vôtre.' end
    return e, nil, g
end

P.Actions.setGrade = { perm = 'employees_view', fn = function(src, d, D)
    local e, why, old = CheckTarget(src, D, d.cid)
    if not e then return { error = why } end
    local new = ShopGrade(D, d.gradeId)
    if not new then return { error = 'Grade introuvable.' } end
    if old and new.id == old.id then return { error = 'C\'est déjà son grade.' } end
    if new.level >= MyLevel(src) then return { error = 'Vous ne pouvez pas donner un grade égal ou supérieur au vôtre.' } end
    if new.active == false then return { error = 'Ce grade est désactivé : il ne peut plus être donné.' } end
    local up = not old or new.level > old.level
    if up and not P.Can(src, 'promote') then return { error = 'Votre grade ne permet pas de promouvoir.' } end
    if not up and not P.Can(src, 'demote') then return { error = 'Votre grade ne permet pas de rétrograder.' } end
    P.ApplyGrade(e.citizenid, new)
    if up then e.promoted = os.date('%d/%m/%Y') end
    local reason = P.Clean(d.reason, 255)
    P.AddLog(D.id, src, e.citizenid, e.name, up and 'Promotion' or 'Rétrogradation', old and old.name, new.name, reason ~= '' and reason or nil)
    local tsrc = core:GetSourceByCitizenId(e.citizenid)
    if tsrc then P.Notify(tsrc, ('%s : vous êtes maintenant %s.'):format(up and 'Promotion' or 'Rétrogradation', new.name), up and 'success' or 'inform') end
    return { ok = true, message = ('%s est maintenant %s.'):format(e.name, new.name) }
end }

P.Actions.fire = { perm = 'fire', fn = function(src, d, D)
    local e, why, old = CheckTarget(src, D, d.cid)
    if not e then return { error = why } end
    local reason = P.Clean(d.reason, 255)
    local tsrc = core:GetSourceByCitizenId(e.citizenid)
    P.FlushCid(e.citizenid)
    if math.floor(e.unpaid_amount) > 0 and d.dropUnpaid ~= true then
        return { error = ('%s a %d $ de salaire non payé : payez-le dans Finance avant le renvoi, ou confirmez l\'abandon.'):format(e.name, math.floor(e.unpaid_amount)),
            unpaid = math.floor(e.unpaid_amount) }
    end
    if math.floor(e.unpaid_amount) > 0 then P.AddLog(D.id, src, e.citizenid, e.name, 'Salaire abandonné', nil, nil, ('%d $ non payés au renvoi'):format(math.floor(e.unpaid_amount))) end
    P.Remove(e.citizenid)
    P.AddLog(D.id, src, e.citizenid, e.name, 'Renvoi', old and old.name, nil, reason ~= '' and reason or nil)
    if tsrc then P.Notify(tsrc, ('Vous ne faites plus partie de %s%s.'):format(D.name, reason ~= '' and (' : ' .. reason) or ''), 'error') end
    return { ok = true, message = ('%s a été retiré(e) de %s.'):format(e.name, D.name) }
end }

P.Actions.editEmployee = { perm = 'employees_edit', fn = function(src, d, D)
    local e, why = CheckTarget(src, D, d.cid)
    if not e then return { error = why } end
    local mat = P.Clean(d.matricule, 20):upper()
    if #mat < 2 then return { error = 'Matricule invalide.' } end
    for _, o in pairs(P.ShopEmployees(D.id)) do
        if o.citizenid ~= e.citizenid and o.matricule == mat then return { error = 'Ce matricule est déjà utilisé.' } end
    end
    local note = P.Clean(d.note, 255)
    MySQL.update.await('UPDATE `cl_employees` SET `matricule` = ?, `note` = ? WHERE `citizenid` = ?', { mat, note ~= '' and note or nil, e.citizenid })
    local before = e.matricule
    e.matricule, e.note = mat, note ~= '' and note or nil
    if before ~= mat then P.AddLog(D.id, src, e.citizenid, e.name, 'Matricule modifié', before, mat, nil) end
    local tsrc = core:GetSourceByCitizenId(e.citizenid)
    if tsrc then P.PushState(tsrc) end
    return { ok = true, message = 'Fiche enregistrée.' }
end }

P.Actions.resign = { perm = nil, open = false, fn = function(src, d, D)
    local cid = P.Cid(src)
    local g = P.Grade(src)
    if g and g.level == P.TopLevel(D.id) then
        local others = 0
        for c, e in pairs(P.ShopEmployees(D.id)) do if c ~= cid and P.grades[e.grade_id] and P.grades[e.grade_id].level == g.level then others = others + 1 end end
        if others == 0 then return { error = 'Vous êtes le seul au plus haut grade : nommez quelqu\'un avant de partir.' } end
    end
    local name = P.Name(src)
    P.FlushCid(cid)
    local e = P.employees[cid]
    if e and math.floor(e.unpaid_amount) > 0 and d.dropUnpaid ~= true then
        return { error = ('Vous avez %d $ de salaire non payé : demandez votre paie avant de partir, ou confirmez l\'abandon.'):format(math.floor(e.unpaid_amount)),
            unpaid = math.floor(e.unpaid_amount) }
    end
    P.Remove(cid)
    P.AddLog(D.id, src, cid, name, 'Démission', g and g.name, nil, e and math.floor(e.unpaid_amount) > 0 and ('%d $ non payés abandonnés'):format(math.floor(e.unpaid_amount)) or nil)
    return { ok = true, message = ('Vous avez quitté %s.'):format(D.name) }
end }

P.Actions.history = { perm = 'history_view', fn = function(_, d, D)
    local q = P.Clean(d.q, 60):gsub('[%%_]', '')
    local sql = [[SELECT `actor_name`, `target_name`, `action`, `old_grade`, `new_grade`, `reason`, UNIX_TIMESTAMP(`created_at`) AS t FROM `cl_admin_log` WHERE `shop_id` = ?]]
    local args = { D.id }
    if q ~= '' then
        local like = '%' .. q .. '%'
        sql = sql .. ' AND (`actor_name` LIKE ? OR `target_name` LIKE ? OR `action` LIKE ?)'
        args[#args + 1], args[#args + 2], args[#args + 3] = like, like, like
    end
    return { list = MySQL.query.await(sql .. ' ORDER BY `id` DESC LIMIT 150', args) or {} }
end }

-- ---------------------------------------------------------------------
-- Grades et permissions
-- ---------------------------------------------------------------------
local function GradeView(D, g)
    local count = 0
    for _, e in pairs(P.ShopEmployees(D.id)) do if e.grade_id == g.id then count = count + 1 end end
    local perms = {}
    for k in pairs(g.perms) do perms[#perms + 1] = k end
    return { id = g.id, name = g.name, level = g.level, isDefault = g.isDefault, perms = perms, members = count, active = g.active ~= false }
end

P.Actions.grades = { perm = 'direction', fn = function(src, _, D)
    local list = {}
    for _, g in ipairs(P.SortedGrades(D.id)) do list[#list + 1] = GradeView(D, g) end
    local mine = {}
    for k in pairs(P.Grade(src).perms) do mine[k] = true end
    return { list = list, myLevel = MyLevel(src), myPerms = mine, permList = CLPerms, canGrades = P.Can(src, 'grades_manage'), canPerms = P.Can(src, 'perms_manage') }
end }

local function AfterGradeChange(D) P.SyncCoreJob(D) P.PushShop(D.id) end

local function ValidName(D, name, exceptId)
    name = P.Clean(name, 50)
    if #name < 2 then return nil, 'Nom de grade trop court.' end
    for _, g in ipairs(P.SortedGrades(D.id)) do if g.id ~= exceptId and g.name:lower() == name:lower() then return nil, 'Un grade porte déjà ce nom.' end end
    return name
end
local function ValidLevel(src, D, level, exceptId)
    level = P.Int(level, 1, 99, nil)
    if not level then return nil, 'Niveau invalide (1 à 99).' end
    if level >= MyLevel(src) then return nil, 'Le niveau doit être inférieur au vôtre.' end
    for _, g in ipairs(P.SortedGrades(D.id)) do
        if g.id ~= exceptId and g.level == level then return nil, ('Le niveau %d est déjà utilisé par « %s ».'):format(level, g.name) end
    end
    return level
end

P.Actions.gradeSave = { perm = 'grades_manage', fn = function(src, d, D)
    local id = tonumber(d.id)
    local g = id and ShopGrade(D, id) or nil
    if id and not g then return { error = 'Grade introuvable.' } end
    if g and g.level >= MyLevel(src) then return { error = 'Vous ne pouvez modifier que les grades inférieurs au vôtre.' } end
    local name, e1 = ValidName(D, d.name, id)
    if not name then return { error = e1 } end
    local level, e2 = ValidLevel(src, D, d.level, id)
    if not level then return { error = e2 } end
    local isDefault, active = d.isDefault == true, d.active ~= false
    if isDefault and not active then return { error = 'Le grade des recrues ne peut pas être désactivé.' } end
    if g then
        if g.isDefault and not active then return { error = 'Le grade des recrues ne peut pas être désactivé.' } end
        local oldLevel = g.level
        MySQL.update.await('UPDATE `cl_grades` SET `name` = ?, `level` = ?, `active` = ? WHERE `id` = ?', { name, level, active and 1 or 0, g.id })
        g.name, g.level, g.active = name, level, active
        if oldLevel ~= level then for cid, e in pairs(P.ShopEmployees(D.id)) do if e.grade_id == g.id then P.ApplyGrade(cid, g) end end end
    else
        local newId = MySQL.insert.await('INSERT INTO `cl_grades` (`shop_id`, `name`, `level`, `salary`, `perms`, `active`) VALUES (?, ?, ?, ?, ?, ?)',
            { D.id, name, level, 0, '[]', active and 1 or 0 })
        if not newId then return { error = 'Enregistrement impossible.' } end
        g = { id = newId, shop_id = D.id, name = name, level = level, salary = 0, perms = {}, isDefault = false, active = active }
        P.grades[newId] = g
    end
    if isDefault and not g.isDefault then
        MySQL.update.await('UPDATE `cl_grades` SET `is_default` = (`id` = ?) WHERE `shop_id` = ?', { g.id, D.id })
        for _, o in ipairs(P.SortedGrades(D.id)) do o.isDefault = o.id == g.id end
    end
    AfterGradeChange(D)
    P.AddLog(D.id, src, nil, nil, id and 'Grade modifié' or 'Grade créé', nil, name, ('niveau %d'):format(level))
    return { ok = true, id = g.id, message = id and 'Grade enregistré.' or ('Grade « %s » créé.'):format(name) }
end }

P.Actions.gradeDelete = { perm = 'grades_manage', fn = function(src, d, D)
    local g = ShopGrade(D, d.id)
    if not g then return { error = 'Grade introuvable.' } end
    if g.level >= MyLevel(src) then return { error = 'Vous ne pouvez supprimer que les grades inférieurs au vôtre.' } end
    local members = {}
    for cid, e in pairs(P.ShopEmployees(D.id)) do if e.grade_id == g.id then members[#members + 1] = cid end end
    local target
    if #members > 0 then
        target = ShopGrade(D, d.reassign)
        if not target or target.id == g.id then return { error = ('%d employé(s) ont ce grade : choisissez le grade où les réaffecter.'):format(#members), needReassign = true } end
        if target.level >= MyLevel(src) then return { error = 'Le grade de réaffectation doit être inférieur au vôtre.' } end
    end
    if #P.SortedGrades(D.id) <= 1 then return { error = 'Il faut garder au moins un grade.' } end
    for _, cid in ipairs(members) do P.ApplyGrade(cid, target) end
    MySQL.update.await('DELETE FROM `cl_grades` WHERE `id` = ?', { g.id })
    P.grades[g.id] = nil
    if g.isDefault then
        local def = P.SortedGrades(D.id)[1]
        if def then def.isDefault = true MySQL.update.await('UPDATE `cl_grades` SET `is_default` = 1 WHERE `id` = ?', { def.id }) end
    end
    AfterGradeChange(D)
    P.AddLog(D.id, src, nil, nil, 'Grade supprimé', g.name, target and target.name, #members > 0 and ('%d employé(s) réaffecté(s)'):format(#members) or nil)
    return { ok = true, message = ('Grade « %s » supprimé%s.'):format(g.name, #members > 0 and (' · ' .. #members .. ' employé(s) réaffecté(s)') or '') }
end }

P.Actions.gradePerms = { perm = 'perms_manage', fn = function(src, d, D)
    local g = ShopGrade(D, d.id)
    if not g then return { error = 'Grade introuvable.' } end
    if g.level >= MyLevel(src) then return { error = 'Vous ne pouvez modifier que les grades inférieurs au vôtre.' } end
    local mine = P.Grade(src).perms
    local set = {}
    for k in pairs(g.perms) do if not mine[k] then set[k] = true end end
    for _, k in ipairs(type(d.perms) == 'table' and d.perms or {}) do if CLPermSet[k] and mine[k] then set[k] = true end end
    g.perms = set
    MySQL.update.await('UPDATE `cl_grades` SET `perms` = ? WHERE `id` = ?', { P.EncodePerms(set), g.id })
    AfterGradeChange(D)
    P.AddLog(D.id, src, nil, nil, 'Permissions modifiées', nil, g.name, nil)
    return { ok = true, message = ('Permissions de « %s » enregistrées.'):format(g.name) }
end }
