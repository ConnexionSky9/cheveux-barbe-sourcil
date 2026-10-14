-- =====================================================================
--  ELYZEA POLICE - serveur : rapports
--  Créer / modifier ses rapports : « reports_write » ; modifier et archiver ceux des
--  autres : « reports_manage ». Chaque modification est notée (police_report_history).
-- =====================================================================
local P = Police
local STATUS = { open = 'En cours', done = 'Terminé', archived = 'Archivé' }

local function TypeOk(t)
    for _, v in ipairs(Config.Reports.types) do if v == t then return true end end
    return false
end

local function CleanList(list, max, itemMax, urls)
    local out = {}
    for _, v in ipairs(type(list) == 'table' and list or {}) do
        local s = P.Clean(v, itemMax)
        if s ~= '' and (not urls or s:match('^https?://[%w%-%._~:/%?#%[%]@!%$&\'%(%)%*%+,;=%%]+$')) then out[#out + 1] = s end
        if #out >= max then break end
    end
    return out
end

local function Decode(s)
    local ok, v = pcall(json.decode, s or '[]')
    return ok and type(v) == 'table' and v or {}
end

local function History(id, src, action)
    MySQL.insert('INSERT INTO `police_report_history` (`report_id`, `actor_name`, `action`) VALUES (?, ?, ?)', { id, P.Name(src), action })
end

P.Actions.reportsList = { perm = 'reports_view', fn = function(_, d)
    local where, params = {}, {}
    local status = d.status
    if status == 'all' then
        -- tout
    elseif STATUS[status] then where[#where + 1] = '`status` = ?' params[#params + 1] = status
    else where[#where + 1] = '`status` <> \'archived\'' end
    if d.type and TypeOk(d.type) then where[#where + 1] = '`type` = ?' params[#params + 1] = d.type end
    local q = P.Clean(d.q, 60):gsub('[%%_]', '')
    if q ~= '' then
        local like = '%' .. q .. '%'
        where[#where + 1] = '(`title` LIKE ? OR `people` LIKE ? OR `author_name` LIKE ? OR `author_matricule` LIKE ? OR `location` LIKE ?)'
        for _ = 1, 5 do params[#params + 1] = like end
    end
    local from = tostring(d.from or ''):match('^%d%d%d%d%-%d%d%-%d%d$')
    local to = tostring(d.to or ''):match('^%d%d%d%d%-%d%d%-%d%d$')
    if from then where[#where + 1] = 'DATE(`created_at`) >= ?' params[#params + 1] = from end
    if to then where[#where + 1] = 'DATE(`created_at`) <= ?' params[#params + 1] = to end
    local sql = ([[SELECT `id`, `title`, `type`, `people`, `location`, `status`, `author_name`, `author_matricule`, `author_cid`,
        UNIX_TIMESTAMP(`created_at`) AS t FROM `police_reports` %s ORDER BY `id` DESC LIMIT 100]]):format(#where > 0 and ('WHERE ' .. table.concat(where, ' AND ')) or '')
    local rows = MySQL.query.await(sql, params) or {}
    for _, r in ipairs(rows) do r.people = Decode(r.people) end
    return { list = rows, types = Config.Reports.types }
end }

P.Actions.reportGet = { perm = 'reports_view', fn = function(src, d)
    local r = MySQL.single.await([[SELECT *, UNIX_TIMESTAMP(`created_at`) AS t, UNIX_TIMESTAMP(`updated_at`) AS u FROM `police_reports` WHERE `id` = ?]], { P.Int(d.id, 1, nil, 0) })
    if not r then return { error = 'Rapport introuvable.' } end
    r.people, r.attachments = Decode(r.people), Decode(r.attachments)
    r.created_at, r.updated_at = nil, nil
    local mine = r.author_cid == P.Cid(src)
    r.canEdit = (mine and P.Can(src, 'reports_write')) or P.Can(src, 'reports_manage')
    r.canArchive = P.Can(src, 'reports_manage')
    r.history = MySQL.query.await('SELECT `actor_name`, `action`, UNIX_TIMESTAMP(`created_at`) AS t FROM `police_report_history` WHERE `report_id` = ? ORDER BY `id` DESC LIMIT 30', { r.id }) or {}
    return { report = r }
end }

P.Actions.reportSave = { perm = 'reports_write', fn = function(src, d)
    local title = P.Clean(d.title, 120)
    if #title < 3 then return { error = 'Donnez un titre au rapport (3 caractères minimum).' } end
    if not TypeOk(d.type) then return { error = 'Choisissez un type de rapport.' } end
    local status = (d.status == 'done' or d.status == 'open') and d.status or 'open'
    local people = json.encode(CleanList(d.people, 15, 60))
    local attachments = json.encode(CleanList(d.attachments, Config.Reports.maxAttachments, 300, true))
    local location = P.Clean(d.location, 120)
    local description = P.Clean(d.description, 6000)
    local observations = P.Clean(d.observations, 3000)
    if #description < 5 then return { error = 'Décrivez les faits.' } end
    local id = P.Int(d.id, 1, nil, nil)
    if id then
        local r = MySQL.single.await('SELECT `id`, `author_cid`, `status` FROM `police_reports` WHERE `id` = ?', { id })
        if not r then return { error = 'Rapport introuvable.' } end
        if r.status == 'archived' then return { error = 'Ce rapport est archivé.' } end
        if r.author_cid ~= P.Cid(src) and not P.Can(src, 'reports_manage') then return { error = 'Vous ne pouvez modifier que vos rapports.' } end
        MySQL.update.await([[UPDATE `police_reports` SET `title` = ?, `type` = ?, `people` = ?, `location` = ?, `description` = ?, `observations` = ?,
            `attachments` = ?, `status` = ? WHERE `id` = ?]], { title, d.type, people, location, description, observations, attachments, status, id })
        History(id, src, status ~= r.status and ('Modifié · statut : %s'):format(STATUS[status]) or 'Modifié')
        return { ok = true, id = id, message = 'Rapport enregistré.' }
    end
    local e = P.Employee(src)
    id = MySQL.insert.await([[INSERT INTO `police_reports` (`title`, `type`, `people`, `location`, `description`, `observations`, `attachments`, `status`,
        `author_cid`, `author_name`, `author_matricule`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
        { title, d.type, people, location, description, observations, attachments, status, P.Cid(src), P.Name(src), e and e.matricule })
    if not id then return { error = 'Enregistrement impossible.' } end
    History(id, src, 'Rédigé')
    P.Log(src, 'Rapport rédigé', ('#%d · %s'):format(id, title))
    return { ok = true, id = id, message = ('Rapport #%d enregistré.'):format(id) }
end }

P.Actions.reportArchive = { perm = 'reports_manage', fn = function(src, d)
    local id = P.Int(d.id, 1, nil, 0)
    local r = MySQL.single.await('SELECT `id`, `status` FROM `police_reports` WHERE `id` = ?', { id })
    if not r then return { error = 'Rapport introuvable.' } end
    local archive = d.archive ~= false
    MySQL.update.await('UPDATE `police_reports` SET `status` = ? WHERE `id` = ?', { archive and 'archived' or 'done', id })
    History(id, src, archive and 'Archivé' or 'Désarchivé')
    return { ok = true, message = archive and 'Rapport archivé.' or 'Rapport ressorti des archives.' }
end }

-- ---------------------------------------------------------------------
--  Pont pour noirx (Police Hack) : Config.PoliceHack.adapterResource = 'elyzea_police'
--  IsPolice(src)          → agent en service
--  ListReports(src)       → 15 derniers rapports non archivés (sans le contenu détaillé)
--  DeleteReport(src, id)  → le rapport est archivé (jamais effacé de la base, récupérable
--                           par la direction), avec une ligne d'historique
-- ---------------------------------------------------------------------
exports('IsPolice', function(src) return P.OnDuty(tonumber(src)) == true end)

-- Liste tenue en cache (rafraîchie toutes les 20 s) : pas d'attente SQL dans un export appelé par une autre ressource
local MdtCache = {}
CreateThread(function()
    while true do
        local rows = MySQL.query.await([[SELECT `id`, `title`, `type`, `author_name`, UNIX_TIMESTAMP(`created_at`) AS t
            FROM `police_reports` WHERE `status` <> 'archived' ORDER BY `id` DESC LIMIT 15]]) or {}
        local out = {}
        for _, r in ipairs(rows) do
            out[#out + 1] = { id = r.id, title = r.title, type = r.type, author = r.author_name, date = os.date('%d/%m %H:%M', tonumber(r.t) or 0) }
        end
        MdtCache = out
        Wait(20000)
    end
end)

exports('ListReports', function(src) return MdtCache end)

exports('DeleteReport', function(src, id)
    id = P.Int(id, 1, nil, 0)
    local idx
    for i, r in ipairs(MdtCache) do if tonumber(r.id) == id then idx = i end end
    if not idx then return false end
    table.remove(MdtCache, idx)
    MySQL.update('UPDATE `police_reports` SET `status` = ? WHERE `id` = ? AND `status` <> ?', { 'archived', id, 'archived' })
    MySQL.insert('INSERT INTO `police_report_history` (`report_id`, `actor_name`, `action`) VALUES (?, ?, ?)',
        { id, 'Inconnu', 'Rapport retiré du MDT lors d\'une intrusion (archivé, récupérable)' })
    return true
end)
