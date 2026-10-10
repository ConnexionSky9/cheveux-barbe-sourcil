-- =====================================================================
--  elyzea_police - serveur : tablette de l'agent (MDT)
-- =====================================================================
local P = Police
local M = {}   -- [action] = { perm, offDuty, fn(src, d) -> résultat }

local function GradeLabel(level)
    local g = P.Settings.job.grades[(tonumber(level) or 0) + 1]
    return g and g.name or ('Grade ' .. tostring(level))
end

local function MyPerms(src)
    local out = {}
    for perm in pairs(P.Settings.permGrades) do out[perm] = P.Can(src, perm, true) end
    return out
end

local function Me(src)
    local p = P.GetPlayer(src)
    local job = p.PlayerData.job
    return {
        id = src, name = P.Name(src), grade = job.grade.level, gradeLabel = job.grade.name,
        onduty = job.onduty == true, callsign = p.PlayerData.metadata.callsign, perms = MyPerms(src),
        jobLabel = job.label,
    }
end

local function Like(q)
    q = tostring(q or ''):lower():gsub('[%%_]', ''):sub(1, 50)
    return '%' .. q .. '%', q
end

-- ---------------------------------------------------------------------
-- Accueil
-- ---------------------------------------------------------------------
M.dashboard = { perm = 'mdt', offDuty = true, fn = function(src)
    local units = {}
    for _, c in ipairs(P.CopsOnDuty()) do
        local p = P.GetPlayer(c)
        units[#units + 1] = { id = c, name = P.Name(c), grade = p.PlayerData.job.grade.name,
            callsign = p.PlayerData.metadata.callsign }
    end
    table.sort(units, function(a, b) return (a.callsign or 'zz') < (b.callsign or 'zz') end)
    return {
        me = Me(src),
        units = units,
        calls = P.CallList(),
        warrants = MySQL.query.await('SELECT id, citizenid, name, reason, danger, officer, DATE_FORMAT(created_at, "%d/%m %H:%i") AS date FROM police_warrants WHERE active = 1 ORDER BY danger DESC, id DESC LIMIT 6') or {},
        records = MySQL.query.await('SELECT id, citizenid, name, title, officer, DATE_FORMAT(created_at, "%d/%m %H:%i") AS date FROM police_records ORDER BY id DESC LIMIT 6') or {},
        jailed = MySQL.scalar.await('SELECT COUNT(*) FROM police_jail') or 0,
    }
end }

M.toggleDuty = { perm = 'mdt', offDuty = true, fn = function(src)
    P.SetDuty(src)
    return { ok = true }
end }

M.setCallsign = { perm = 'mdt', offDuty = true, fn = function(src, d)
    local cs = tostring(d.callsign or ''):upper():gsub('[^%w%-]', ''):sub(1, 8)
    local p = P.GetPlayer(src)
    p.Functions.SetMetaData('callsign', cs ~= '' and cs or nil)
    return { ok = true, message = cs ~= '' and ('Indicatif : %s'):format(cs) or 'Indicatif retiré.' }
end }

-- ---------------------------------------------------------------------
-- Citoyens
-- ---------------------------------------------------------------------
M.searchCitizens = { perm = 'mdt', fn = function(_, d)
    local like, raw = Like(d.q)
    if #raw < 2 then return { list = {} } end
    local rows = MySQL.query.await([[SELECT citizenid, charinfo FROM players
        WHERE LOWER(CONCAT(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')), ' ', JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')))) LIKE ?
           OR LOWER(citizenid) LIKE ? OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.phone')) LIKE ?
        LIMIT 30]], { like, like, like }) or {}
    local list = {}
    for _, r in ipairs(rows) do
        local ci = json.decode(r.charinfo or '{}') or {}
        list[#list + 1] = { citizenid = r.citizenid, name = P.CharName(ci), birthdate = ci.birthdate, phone = ci.phone }
    end
    return { list = list }
end }

M.profile = { perm = 'mdt', fn = function(_, d)
    local cid = tostring(d.citizenid or '')
    local row = MySQL.single.await('SELECT citizenid, charinfo, metadata, job FROM players WHERE citizenid = ?', { cid })
    if not row then return { error = 'Citoyen introuvable.' } end
    local ci = json.decode(row.charinfo or '{}') or {}
    local meta = json.decode(row.metadata or '{}') or {}
    local job = json.decode(row.job or '{}') or {}
    local online = P.FindByCid(cid)
    local jail = MySQL.single.await('SELECT remaining, reason, officer FROM police_jail WHERE citizenid = ?', { cid })
    return {
        citizenid = cid, name = P.CharName(ci), birthdate = ci.birthdate, gender = ci.gender, phone = ci.phone,
        nationality = ci.nationality, job = job.label or job.name, online = online ~= nil, onlineId = online,
        licences = meta.licences or {},
        jail = jail,
        records = MySQL.query.await('SELECT id, title, content, charges, fine, jail, officer, DATE_FORMAT(created_at, "%d/%m/%Y %H:%i") AS date FROM police_records WHERE citizenid = ? ORDER BY id DESC', { cid }) or {},
        fines = MySQL.query.await('SELECT id, label, amount, paid, officer, DATE_FORMAT(created_at, "%d/%m/%Y") AS date FROM police_fines WHERE citizenid = ? ORDER BY id DESC LIMIT 50', { cid }) or {},
        warrants = MySQL.query.await('SELECT id, name, reason, danger, officer, DATE_FORMAT(created_at, "%d/%m/%Y") AS date FROM police_warrants WHERE citizenid = ? AND active = 1 ORDER BY id DESC', { cid }) or {},
        vehicles = MySQL.query.await('SELECT plate, vehicle FROM player_vehicles WHERE citizenid = ?', { cid }) or {},
    }
end }

M.setLicense = { perm = 'licenses', fn = function(src, d)
    local ok, msg = P.SetLicense(src, tostring(d.citizenid or ''), d.license, d.state == true)
    return { ok = ok, message = msg }
end }

-- ---------------------------------------------------------------------
-- Véhicules
-- ---------------------------------------------------------------------
M.searchVehicles = { perm = 'mdt', fn = function(_, d)
    local like, raw = Like(d.q)
    if #raw < 2 then return { list = {} } end
    local rows = MySQL.query.await([[SELECT pv.plate, pv.vehicle, pv.citizenid, p.charinfo FROM player_vehicles pv
        LEFT JOIN players p ON p.citizenid = pv.citizenid WHERE LOWER(pv.plate) LIKE ? LIMIT 30]], { like }) or {}
    local list = {}
    for _, r in ipairs(rows) do
        list[#list + 1] = { plate = r.plate, model = r.vehicle, citizenid = r.citizenid, owner = r.charinfo and P.CharName(r.charinfo) or '?' }
    end
    return { list = list }
end }

-- ---------------------------------------------------------------------
-- Rapports
-- ---------------------------------------------------------------------
M.saveRecord = { perm = 'records_write', fn = function(src, d)
    local cid = tostring(d.citizenid or '')
    local row = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', { cid })
    if not row then return { error = 'Citoyen introuvable.' } end
    local title = tostring(d.title or ''):sub(1, 150)
    local content = tostring(d.content or ''):sub(1, 8000)
    if title == '' or content == '' then return { error = 'Titre et contenu obligatoires.' } end
    local charges, fine, jail = {}, 0, 0
    for _, id in ipairs(type(d.charges) == 'table' and d.charges or {}) do
        for _, f in ipairs(P.Settings.fines) do
            if f.id == id then
                charges[#charges + 1] = f.label
                fine = fine + (tonumber(f.amount) or 0)
                jail = jail + (tonumber(f.jail) or 0)
            end
        end
    end
    local p = P.GetPlayer(src)
    MySQL.insert.await('INSERT INTO police_records (citizenid, name, title, content, charges, fine, jail, officer, officer_cid) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { cid, P.CharName(row.charinfo), title, content, table.concat(charges, ', '), fine, jail, P.Name(src), p.PlayerData.citizenid })
    P.Log(src, 'Rapport', ('%s · %s'):format(P.CharName(row.charinfo), title))
    return { ok = true, message = 'Rapport enregistré.' }
end }

M.deleteRecord = { perm = 'records_delete', fn = function(src, d)
    MySQL.query.await('DELETE FROM police_records WHERE id = ?', { tonumber(d.id) })
    P.Log(src, 'Rapport supprimé', ('#%s'):format(tostring(d.id)))
    return { ok = true, message = 'Rapport supprimé.' }
end }

M.records = { perm = 'mdt', fn = function(_, d)
    local like = Like(d.q)
    return { list = MySQL.query.await([[SELECT id, citizenid, name, title, charges, officer, DATE_FORMAT(created_at, "%d/%m/%Y %H:%i") AS date
        FROM police_records WHERE LOWER(name) LIKE ? OR LOWER(title) LIKE ? OR LOWER(officer) LIKE ? ORDER BY id DESC LIMIT 60]], { like, like, like }) or {} }
end }

-- ---------------------------------------------------------------------
-- Avis de recherche
-- ---------------------------------------------------------------------
M.warrants = { perm = 'mdt', fn = function()
    return { list = MySQL.query.await('SELECT id, citizenid, name, reason, danger, officer, DATE_FORMAT(created_at, "%d/%m/%Y %H:%i") AS date FROM police_warrants WHERE active = 1 ORDER BY danger DESC, id DESC') or {} }
end }

M.createWarrant = { perm = 'warrants', fn = function(src, d)
    local name = tostring(d.name or ''):sub(1, 100)
    local cid = d.citizenid and tostring(d.citizenid) or nil
    if cid then
        local row = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', { cid })
        if row then name = P.CharName(row.charinfo) else cid = nil end
    end
    local reason = tostring(d.reason or ''):sub(1, 2000)
    if name == '' or reason == '' then return { error = 'Nom et motif obligatoires.' } end
    local danger = math.max(1, math.min(3, tonumber(d.danger) or 1))
    MySQL.insert.await('INSERT INTO police_warrants (citizenid, name, reason, danger, officer) VALUES (?, ?, ?, ?, ?)',
        { cid, name, reason, danger, P.Name(src) })
    for _, c in ipairs(P.CopsOnDuty()) do
        P.Notify(c, ('Nouvel avis de recherche : %s'):format(name), danger == 3 and 'error' or 'warning')
    end
    P.Log(src, 'Avis de recherche', ('%s · %s'):format(name, reason))
    return { ok = true, message = 'Avis de recherche publié.' }
end }

M.closeWarrant = { perm = 'warrants', fn = function(src, d)
    MySQL.update.await('UPDATE police_warrants SET active = 0 WHERE id = ?', { tonumber(d.id) })
    P.Log(src, 'Avis de recherche levé', ('#%s'):format(tostring(d.id)))
    return { ok = true, message = 'Avis de recherche levé.' }
end }

-- ---------------------------------------------------------------------
-- Prison
-- ---------------------------------------------------------------------
M.jailed = { perm = 'mdt', fn = function()
    return { list = MySQL.query.await('SELECT citizenid, name, remaining, reason, officer FROM police_jail ORDER BY remaining DESC') or {} }
end }

M.release = { perm = 'jail', fn = function(src, d)
    P.ReleaseCid(tostring(d.citizenid or ''), P.Name(src))
    P.Log(src, 'Libération', tostring(d.citizenid))
    return { ok = true, message = 'Prisonnier libéré.' }
end }

-- ---------------------------------------------------------------------
-- Appels
-- ---------------------------------------------------------------------
M.calls = { perm = 'dispatch', fn = function() return { list = P.CallList() } end }

-- ---------------------------------------------------------------------
-- Effectif (patron)
-- ---------------------------------------------------------------------
local function Members()
    local jobName = P.Settings.job.name
    local online = {}
    for src, p in pairs(exports.elyzea_core:GetPlayers()) do online[p.PlayerData.citizenid] = src end
    local list = {}
    local ok, members = pcall(function() return exports.elyzea_core:GetGroupMembers(jobName, 'job') end)
    if ok and type(members) == 'table' then
        local cids = {}
        for _, m in ipairs(members) do cids[#cids + 1] = m.citizenid end
        local names = {}
        if #cids > 0 then
            for _, r in ipairs(MySQL.query.await('SELECT citizenid, charinfo FROM players WHERE citizenid IN (?)', { cids }) or {}) do
                names[r.citizenid] = P.CharName(r.charinfo)
            end
        end
        for _, m in ipairs(members) do
            local src = online[m.citizenid]
            list[#list + 1] = { citizenid = m.citizenid, name = names[m.citizenid] or m.citizenid, grade = tonumber(m.grade) or 0,
                gradeLabel = GradeLabel(m.grade), online = src ~= nil, onduty = src and P.OnDuty(src) or false }
        end
    else
        for cid, src in pairs(online) do
            local p = P.GetPlayer(src)
            if p.PlayerData.job.name == jobName then
                list[#list + 1] = { citizenid = cid, name = P.Name(src), grade = p.PlayerData.job.grade.level,
                    gradeLabel = p.PlayerData.job.grade.name, online = true, onduty = P.OnDuty(src) }
            end
        end
    end
    table.sort(list, function(a, b) if a.grade ~= b.grade then return a.grade > b.grade end return a.name < b.name end)
    return list
end

M.roster = { perm = 'roster', offDuty = true, fn = function()
    local grades = {}
    for i, g in ipairs(P.Settings.job.grades) do grades[#grades + 1] = { level = i - 1, name = g.name } end
    return { list = Members(), grades = grades }
end }

local function CheckBelow(src, grade)
    if grade >= P.Grade(src) then return false end
    return true
end

M.hire = { perm = 'roster', offDuty = true, fn = function(src, d)
    local target = tonumber(d.target)
    local p = target and P.GetPlayer(target)
    if not p then return { error = 'Joueur introuvable (ID).' } end
    if P.Dist(src, target) > 10.0 then return { error = 'La personne doit être près de vous.' } end
    local grade = tonumber(d.grade) or 0
    if not CheckBelow(src, grade) then return { error = 'Vous ne pouvez recruter qu\'à un grade inférieur au vôtre.' } end
    p.Functions.SetJob(P.Settings.job.name, grade)
    P.Notify(target, ('Vous avez été recruté : %s.'):format(GradeLabel(grade)), 'success')
    P.Log(src, 'Recrutement', ('%s · %s'):format(P.Name(target), GradeLabel(grade)))
    return { ok = true, message = ('%s a été recruté.'):format(P.Name(target)) }
end }

M.setGrade = { perm = 'roster', offDuty = true, fn = function(src, d)
    local cid, grade = tostring(d.citizenid or ''), tonumber(d.grade) or 0
    if not P.Settings.job.grades[grade + 1] then return { error = 'Grade inexistant.' } end
    if not CheckBelow(src, grade) then return { error = 'Vous ne pouvez donner qu\'un grade inférieur au vôtre.' } end
    local jobName = P.Settings.job.name
    local target, p = P.FindByCid(cid)
    if p and p.PlayerData.job.name == jobName then
        if p.PlayerData.job.grade.level >= P.Grade(src) then return { error = 'Grade égal ou supérieur au vôtre.' } end
        p.Functions.SetJob(jobName, grade)
        P.Notify(target, ('Nouveau grade : %s.'):format(GradeLabel(grade)), 'inform')
    else
        local ok = pcall(function() exports.elyzea_core:AddPlayerToJob(cid, jobName, grade) end)
        if not ok then return { error = 'Impossible de modifier un agent hors ligne (elyzea_core).' } end
    end
    P.Log(src, 'Changement de grade', ('%s · %s'):format(cid, GradeLabel(grade)))
    return { ok = true, message = 'Grade modifié.' }
end }

M.fire = { perm = 'roster', offDuty = true, fn = function(src, d)
    local cid = tostring(d.citizenid or '')
    local jobName = P.Settings.job.name
    local target, p = P.FindByCid(cid)
    if target == src then return { error = 'Vous ne pouvez pas vous renvoyer vous-même.' } end
    if p and p.PlayerData.job.name == jobName then
        if p.PlayerData.job.grade.level >= P.Grade(src) then return { error = 'Grade égal ou supérieur au vôtre.' } end
        p.Functions.SetJob('unemployed', 0)
        P.Notify(target, 'Vous avez été renvoyé de la police.', 'error')
    end
    pcall(function() exports.elyzea_core:RemovePlayerFromJob(cid, jobName) end)
    P.Log(src, 'Renvoi', cid)
    return { ok = true, message = 'Agent renvoyé.' }
end }

-- ---------------------------------------------------------------------
-- Patron : argent de l'entreprise
-- ---------------------------------------------------------------------
local core = exports.elyzea_core
local function JobName() return P.Settings.job.name end
local function Amount(v)
    local n = math.floor(tonumber(v) or 0)
    if n <= 0 or n > 10000000 then return nil end
    return n
end
local function Account(v) return v == 'bank' and 'bank' or 'cash' end

M.bossMoney = { perm = 'boss_money', offDuty = true, fn = function(src)
    local p = P.GetPlayer(src)
    local logs = {}
    for _, l in ipairs(core:GetSocietyLogs(JobName(), 15) or {}) do
        logs[#logs + 1] = { amount = tonumber(l.amount) or 0, reason = l.reason or '', date = tostring(l.created_at or '') }
    end
    return { balance = core:GetSocietyMoney(JobName()), logs = logs,
        cash = p.Functions.GetMoney('cash'), bank = p.Functions.GetMoney('bank') }
end }

M.bossDeposit = { perm = 'boss_money', offDuty = true, fn = function(src, d)
    local amount, kind = Amount(d.amount), Account(d.account)
    if not amount then return { error = 'Montant invalide.' } end
    local p = P.GetPlayer(src)
    if not p.Functions.RemoveMoney(kind, amount, 'Dépôt entreprise police') then
        return { error = kind == 'cash' and "Vous n'avez pas assez de liquide." or "Vous n'avez pas assez d'argent en banque." }
    end
    if not core:AddSocietyMoney(JobName(), amount, 'Dépôt : ' .. P.Name(src)) then
        p.Functions.AddMoney(kind, amount, 'Remboursement dépôt entreprise')
        return { error = "Le compte de l'entreprise est indisponible." }
    end
    P.Log(src, 'Dépôt entreprise', ('%d $ (%s)'):format(amount, kind))
    return { ok = true, message = ('%d $ déposés.'):format(amount) }
end }

M.bossWithdraw = { perm = 'boss_money', offDuty = true, fn = function(src, d)
    local amount, kind = Amount(d.amount), Account(d.account)
    if not amount then return { error = 'Montant invalide.' } end
    if not core:RemoveSocietyMoney(JobName(), amount, 'Retrait : ' .. P.Name(src)) then
        return { error = "Pas assez d'argent sur le compte de l'entreprise." }
    end
    P.GetPlayer(src).Functions.AddMoney(kind, amount, 'Retrait entreprise police')
    P.Log(src, 'Retrait entreprise', ('%d $ (%s)'):format(amount, kind))
    return { ok = true, message = ('%d $ retirés.'):format(amount) }
end }

-- ---------------------------------------------------------------------
-- Patron : grades (nom, salaire, accès)
-- Règle : on ne touche qu'aux grades en dessous du sien, et on ne donne
-- que des accès qu'on a soi-même.
-- ---------------------------------------------------------------------
local function PermIds()
    local out = {}
    for _, l in ipairs(Config.PermLabels) do if P.Settings.permGrades[l.id] ~= nil then out[#out + 1] = l end end
    return out
end

local function CleanName(v)
    local n = tostring(v or ''):gsub('[<>"]', ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 30)
    return n ~= '' and n or nil
end

-- Accès demandés, limités à ceux que le patron a lui-même
local function CleanPerms(src, d)
    local out = {}
    for _, l in ipairs(PermIds()) do
        out[l.id] = type(d) == 'table' and d[l.id] == true and P.Can(src, l.id, true) or false
    end
    return out
end

local function Refresh()
    P.SaveSettings()
    P.RegisterJob()
    P.Sync()
end

-- Change le grade (niveau) de tous les membres d'un niveau donné ou plus : décalage après ajout / suppression
local function ShiftMembers(fromLevel, delta)
    local jobName = JobName()
    for _, m in ipairs(Members()) do
        if m.grade >= fromLevel then
            local newLevel = m.grade + delta
            local target, p = P.FindByCid(m.citizenid)
            if p and p.PlayerData.job.name == jobName then
                local duty = p.PlayerData.job.onduty == true
                p.Functions.SetJob(jobName, newLevel)
                if duty then p.Functions.SetJobDuty(true) end
            else
                pcall(function() core:AddPlayerToJob(m.citizenid, jobName, newLevel) end)
            end
            if target then TriggerClientEvent('police:client:configChanged', target) end
        end
    end
end

M.bossGrades = { perm = 'boss_grades', offDuty = true, fn = function(src)
    local counts = {}
    for _, m in ipairs(Members()) do counts[m.grade] = (counts[m.grade] or 0) + 1 end
    local my = P.Grade(src)
    local grades = {}
    for i, g in ipairs(P.Settings.job.grades) do
        local lvl = i - 1
        grades[#grades + 1] = { level = lvl, name = g.name, payment = tonumber(g.payment) or 0, isboss = g.isboss == true,
            perms = g.isboss and 'all' or (g.perms or {}), members = counts[lvl] or 0, editable = lvl < my and not g.isboss }
    end
    local mine = {}
    for _, l in ipairs(PermIds()) do mine[l.id] = P.Can(src, l.id, true) end
    return { grades = grades, labels = PermIds(), mine = mine, myLevel = my,
        maxSalary = P.Settings.settings.maxSalary or 2000, maxGrades = P.Settings.settings.maxGrades or 15 }
end }

M.bossSaveGrade = { perm = 'boss_grades', offDuty = true, fn = function(src, d)
    local lvl = math.floor(tonumber(d.level) or -1)
    local g = P.Settings.job.grades[lvl + 1]
    if not g then return { error = 'Grade inexistant.' } end
    if lvl >= P.Grade(src) or g.isboss then return { error = 'Vous ne pouvez modifier que les grades en dessous du vôtre.' } end
    local name = CleanName(d.name)
    if not name then return { error = 'Donnez un nom au grade.' } end
    local maxSalary = P.Settings.settings.maxSalary or 2000
    local pay = math.floor(tonumber(d.payment) or -1)
    if pay < 0 or pay > maxSalary then return { error = ('Salaire entre 0 et %d $.'):format(maxSalary) } end
    g.name, g.payment, g.perms = name, pay, CleanPerms(src, d.perms)
    Refresh()
    P.Log(src, 'Grade modifié', ('%d · %s · %d $'):format(lvl, name, pay))
    return { ok = true, message = ('Grade « %s » enregistré.'):format(name) }
end }

M.bossCreateGrade = { perm = 'boss_grades', offDuty = true, fn = function(src, d)
    local grades = P.Settings.job.grades
    if #grades >= (P.Settings.settings.maxGrades or 15) then return { error = 'Nombre maximum de grades atteint.' } end
    local my = P.Grade(src)
    local pos = math.floor(tonumber(d.position) or -1)   -- niveau du nouveau grade (les grades à partir de ce niveau montent d'un cran)
    if pos < 0 or pos > my then return { error = 'Le nouveau grade doit être en dessous du vôtre.' } end
    local name = CleanName(d.name)
    if not name then return { error = 'Donnez un nom au grade.' } end
    local maxSalary = P.Settings.settings.maxSalary or 2000
    local pay = math.floor(tonumber(d.payment) or -1)
    if pay < 0 or pay > maxSalary then return { error = ('Salaire entre 0 et %d $.'):format(maxSalary) } end
    table.insert(grades, pos + 1, { name = name, payment = pay, perms = CleanPerms(src, d.perms) })
    Refresh()                 -- le métier connaît d'abord le nouveau grade (niveau du haut compris)…
    ShiftMembers(pos, 1)      -- …puis les membres au-dessus montent d'un cran : ils gardent leur grade
    P.Sync()
    P.Log(src, 'Grade créé', ('%d · %s · %d $'):format(pos, name, pay))
    return { ok = true, message = ('Grade « %s » créé.'):format(name) }
end }

M.bossDeleteGrade = { perm = 'boss_grades', offDuty = true, fn = function(src, d)
    local grades = P.Settings.job.grades
    local lvl = math.floor(tonumber(d.level) or -1)
    local g = grades[lvl + 1]
    if not g then return { error = 'Grade inexistant.' } end
    if lvl >= P.Grade(src) or g.isboss then return { error = 'Vous ne pouvez supprimer que les grades en dessous du vôtre.' } end
    if #grades <= 1 then return { error = 'Il faut garder au moins un grade.' } end
    for _, m in ipairs(Members()) do
        if m.grade == lvl then return { error = 'Des agents ont encore ce grade : changez-leur de grade avant.' } end
    end
    table.remove(grades, lvl + 1)
    Refresh()                   -- le métier sans ce grade…
    ShiftMembers(lvl + 1, -1)   -- …puis les membres au-dessus descendent d'un cran (leur grade ne change pas)
    P.Sync()
    P.Log(src, 'Grade supprimé', ('%d · %s'):format(lvl, g.name))
    return { ok = true, message = ('Grade « %s » supprimé.'):format(g.name) }
end }

-- ---------------------------------------------------------------------
-- Point d'entrée
-- ---------------------------------------------------------------------
RegisterNetEvent('police:server:mdt', function(reqId, action, data)
    local src = source
    local a = M[action]
    local result
    if not a then
        result = { error = 'Action inconnue.' }
    elseif not P.IsCop(src) then
        result = { error = "Vous n'êtes pas policier." }
    elseif not P.Can(src, a.perm, a.offDuty) then
        result = { error = P.OnDuty(src) and "Votre grade ne permet pas cette action." or 'Prenez votre service pour utiliser cette fonction.' }
    else
        local ok, res = pcall(a.fn, src, type(data) == 'table' and data or {})
        if ok then result = res or {} else
            print('^1[Police] Erreur MDT « ' .. tostring(action) .. ' » : ' .. tostring(res) .. '^0')
            result = { error = 'Erreur serveur.' }
        end
    end
    TriggerClientEvent('police:client:mdtResponse', src, reqId, result)
end)
