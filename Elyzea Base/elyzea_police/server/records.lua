-- =====================================================================
--  ELYZEA POLICE - serveur : recherche de citoyens et personnes recherchées
--  · « search »        : chercher un citoyen par nom / prénom, voir sa fiche
--                         (identité, permis, amendes, rapports, avis de recherche)
--  · « wanted_view »   : liste des personnes recherchées et motifs
--  · « wanted_manage » : créer, modifier et lever un avis de recherche
-- =====================================================================
local P = Police
local core = exports.elyzea_core
local DANGER = { [1] = true, [2] = true, [3] = true }

local function Decode(s, def)
    if type(s) == 'table' then return s end
    local ok, v = pcall(json.decode, s or '')
    return ok and type(v) == 'table' and v or def
end

local function Like(q) return '%' .. q:gsub('[%%_\\]', '') .. '%' end

local function FullName(ci) return (('%s %s'):format(ci.firstname or '', ci.lastname or ''):gsub('^%s+', ''):gsub('%s+$', '')) end

local function Url(s)
    s = P.Clean(s, 500)
    if s == '' then return nil end
    return s:match('^https?://[%w%-%._~:/%?#%[%]@!%$&\'%(%)%*%+,;=%%]+$') and s or false
end

local function Author(src)
    local e = P.Employee(src)
    return P.Cid(src), P.Name(src), e and e.matricule or nil
end

-- ---------------------------------------------------------------------
-- Recherche de citoyens
-- ---------------------------------------------------------------------
local NAME_SQL = [[CONCAT(JSON_UNQUOTE(JSON_EXTRACT(`charinfo`, '$.firstname')), ' ', JSON_UNQUOTE(JSON_EXTRACT(`charinfo`, '$.lastname')))]]
local NAME_SQL_REV = [[CONCAT(JSON_UNQUOTE(JSON_EXTRACT(`charinfo`, '$.lastname')), ' ', JSON_UNQUOTE(JSON_EXTRACT(`charinfo`, '$.firstname')))]]

P.Actions.citizenSearch = { perm = 'search', fn = function(_, d)
    local q = P.Clean(d.q, 60)
    if #q < 2 then return { error = 'Tapez au moins 2 lettres du nom ou du prénom.' } end
    local like = Like(q)
    local rows = MySQL.query.await(('SELECT `citizenid`, `charinfo`, `job` FROM `players` WHERE %s LIKE ? OR %s LIKE ? LIMIT 30'):format(NAME_SQL, NAME_SQL_REV), { like, like }) or {}
    local cids, list = {}, {}
    for _, r in ipairs(rows) do
        local ci, job = Decode(r.charinfo, {}), Decode(r.job, {})
        list[#list + 1] = { cid = r.citizenid, name = FullName(ci), birthdate = ci.birthdate, gender = tonumber(ci.gender) or 0,
            job = job.label or job.name, online = core:GetSourceByCitizenId(r.citizenid) ~= nil, wanted = false }
        cids[#cids + 1] = r.citizenid
    end
    if #cids > 0 then
        local marks = ('?,'):rep(#cids):sub(1, -2)
        local wanted = MySQL.query.await(('SELECT DISTINCT `citizenid` FROM `police_wanted` WHERE `status` = \'active\' AND `citizenid` IN (%s)'):format(marks), cids) or {}
        local set = {}
        for _, w in ipairs(wanted) do set[w.citizenid] = true end
        for _, c in ipairs(list) do c.wanted = set[c.cid] == true end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return { list = list }
end }

P.Actions.citizenGet = { perm = 'search', fn = function(src, d)
    local cid = P.Clean(d.cid, 50)
    local r = MySQL.single.await('SELECT `citizenid`, `charinfo`, `job`, `metadata` FROM `players` WHERE `citizenid` = ?', { cid })
    if not r then return { error = 'Citoyen introuvable.' } end
    local ci, job, md = Decode(r.charinfo, {}), Decode(r.job, {}), Decode(r.metadata, {})
    local name = FullName(ci)
    local lic = type(md.licences) == 'table' and md.licences or {}
    local c = {
        cid = r.citizenid, name = name, firstname = ci.firstname, lastname = ci.lastname, birthdate = ci.birthdate,
        gender = tonumber(ci.gender) or 0, nationality = ci.nationality, phone = ci.phone,
        job = job.label or job.name, jobGrade = type(job.grade) == 'table' and job.grade.name or nil,
        online = core:GetSourceByCitizenId(r.citizenid) ~= nil,
        licences = { driver = lic.driver == true, weapon = lic.weapon == true },
        isCop = P.employees[r.citizenid] ~= nil,
    }
    c.fines = MySQL.query.await([[SELECT `id`, `offense`, `reason`, `amount`, `paid`, `officer_name`, `officer_matricule`, UNIX_TIMESTAMP(`created_at`) AS t
        FROM `police_fines` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 30]], { cid }) or {}
    c.unpaid = 0
    for _, f in ipairs(c.fines) do
        f.paid = f.paid == true or f.paid == 1
        if not f.paid then c.unpaid = c.unpaid + (tonumber(f.amount) or 0) end
    end
    c.reports = P.Can(src, 'reports_view') and (MySQL.query.await([[SELECT `id`, `title`, `type`, `status`, UNIX_TIMESTAMP(`created_at`) AS t FROM `police_reports`
        WHERE `people` LIKE ? ORDER BY `id` DESC LIMIT 20]], { Like(name) }) or {}) or nil
    c.wanted = MySQL.query.await([[SELECT `id`, `reason`, `description`, `danger`, `status`, `author_name`, `author_matricule`, `closed_by`, `close_reason`,
        UNIX_TIMESTAMP(`created_at`) AS t FROM `police_wanted` WHERE `citizenid` = ? ORDER BY (`status` = 'active') DESC, `id` DESC LIMIT 20]], { cid }) or {}
    return { citizen = c }
end }

-- ---------------------------------------------------------------------
-- Personnes recherchées
-- ---------------------------------------------------------------------
P.Actions.wantedList = { perm = 'wanted_view', fn = function(_, d)
    local where, params = {}, {}
    if d.status == 'closed' then where[#where + 1] = '`status` = \'closed\''
    elseif d.status ~= 'all' then where[#where + 1] = '`status` = \'active\'' end
    local q = P.Clean(d.q, 60)
    if q ~= '' then
        where[#where + 1] = '(`name` LIKE ? OR `reason` LIKE ?)'
        params[#params + 1], params[#params + 2] = Like(q), Like(q)
    end
    local rows = MySQL.query.await(([[SELECT `id`, `citizenid`, `name`, `reason`, `description`, `danger`, `photo`, `status`, `author_name`, `author_matricule`,
        `closed_by`, `close_reason`, UNIX_TIMESTAMP(`created_at`) AS t, UNIX_TIMESTAMP(`closed_at`) AS ct FROM `police_wanted` %s
        ORDER BY (`status` = 'active') DESC, `danger` DESC, `id` DESC LIMIT 100]]):format(#where > 0 and ('WHERE ' .. table.concat(where, ' AND ')) or ''), params) or {}
    local active = MySQL.scalar.await('SELECT COUNT(*) FROM `police_wanted` WHERE `status` = \'active\'') or 0
    return { list = rows, active = tonumber(active) or 0 }
end }

P.Actions.wantedSave = { perm = 'wanted_manage', fn = function(src, d)
    local id = tonumber(d.id)
    local old
    if id then
        old = MySQL.single.await('SELECT `id`, `status` FROM `police_wanted` WHERE `id` = ?', { id })
        if not old then return { error = 'Avis introuvable.' } end
        if old.status ~= 'active' then return { error = 'Cet avis est levé, il ne peut plus être modifié.' } end
    end
    local cid = P.Clean(d.cid, 50)
    local name = P.Clean(d.name, 100)
    if cid ~= '' then
        local r = MySQL.single.await('SELECT `charinfo` FROM `players` WHERE `citizenid` = ?', { cid })
        if not r then return { error = 'Citoyen introuvable.' } end
        name = FullName(Decode(r.charinfo, {}))
    else
        cid = nil
    end
    if #name < 2 then return { error = 'Indiquez le nom de la personne recherchée.' } end
    local reason = P.Clean(d.reason, 150)
    if #reason < 3 then return { error = 'Indiquez le motif de la recherche.' } end
    local description = P.Clean(d.description, 1000)
    local danger = DANGER[tonumber(d.danger)] and tonumber(d.danger) or 1
    local photo = Url(d.photo)
    if photo == false then return { error = 'Le lien de la photo doit commencer par http:// ou https://.' } end
    if id then
        MySQL.update.await('UPDATE `police_wanted` SET `citizenid` = ?, `name` = ?, `reason` = ?, `description` = ?, `danger` = ?, `photo` = ? WHERE `id` = ?',
            { cid, name, reason, description, danger, photo, id })
        P.Log(src, ('Avis de recherche #%d modifié : %s'):format(id, name))
        return { ok = true, id = id, message = 'Avis de recherche modifié.' }
    end
    local aCid, aName, aMat = Author(src)
    local newId = MySQL.insert.await([[INSERT INTO `police_wanted` (`citizenid`, `name`, `reason`, `description`, `danger`, `photo`, `author_cid`, `author_name`, `author_matricule`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]], { cid, name, reason, description, danger, photo, aCid, aName, aMat })
    if not newId then return { error = 'Enregistrement impossible.' } end
    P.Log(src, ('Avis de recherche #%d : %s (%s)'):format(newId, name, reason))
    -- Prévenir les collègues en service
    for _, s in ipairs(P.CopsOnDuty('wanted_view')) do
        if s ~= src then P.Notify(s, ('Nouvel avis de recherche : %s · %s'):format(name, reason), danger == 3 and 'error' or 'inform') end
    end
    return { ok = true, id = newId, message = ('Avis de recherche publié : %s.'):format(name) }
end }

P.Actions.wantedClose = { perm = 'wanted_manage', fn = function(src, d)
    local id = tonumber(d.id) or 0
    local w = MySQL.single.await('SELECT `id`, `name`, `status` FROM `police_wanted` WHERE `id` = ?', { id })
    if not w then return { error = 'Avis introuvable.' } end
    if w.status ~= 'active' then return { error = 'Cet avis est déjà levé.' } end
    local _, aName, aMat = Author(src)
    local by = aMat and ('%s · %s'):format(aName, aMat) or aName
    local why = P.Clean(d.reason, 150)
    MySQL.update.await('UPDATE `police_wanted` SET `status` = \'closed\', `closed_by` = ?, `close_reason` = ?, `closed_at` = NOW() WHERE `id` = ?',
        { by, why ~= '' and why or nil, id })
    P.Log(src, ('Avis de recherche #%d levé : %s'):format(id, w.name))
    return { ok = true, message = ('Avis levé : %s.'):format(w.name) }
end }
