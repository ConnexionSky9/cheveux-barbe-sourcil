-- =====================================================================
--  ELYZEA EMS - serveur : dossiers médicaux, comptes rendus, statistiques
--  · Dossier patient : groupe sanguin, allergies, notes + historique automatique
--    (actes, factures, PPA, comptes rendus, appels).
--  · Compte rendu : pré-rempli à partir d'un appel ou des actes récents d'un patient.
-- =====================================================================
local P = Ems
local core = exports.elyzea_core

local BLOOD = { ['A+'] = true, ['A-'] = true, ['B+'] = true, ['B-'] = true, ['AB+'] = true, ['AB-'] = true, ['O+'] = true, ['O-'] = true }
local SERVICE_LABEL = {}
for _, s in ipairs(Config.Billing.services) do SERVICE_LABEL[s.id] = s.label end

-- ---------------------------------------------------------------------
-- Patients
-- ---------------------------------------------------------------------
P.Actions.patients = { perm = 'records_view', fn = function(_, d)
    local q = P.Clean(d.q, 60):gsub('[%%_]', '')
    local out, seen = {}, {}
    -- Personnes présentes (connectées)
    for src, p in pairs(core:GetPlayers()) do
        local name = P.Name(src)
        if q == '' or name:lower():find(q:lower(), 1, true) then
            local cid = p.PlayerData.citizenid
            seen[cid] = true
            out[#out + 1] = { cid = cid, name = name, online = true, id = src }
        end
    end
    local rows
    if q ~= '' then
        local like = '%' .. q .. '%'
        rows = MySQL.query.await([[SELECT `patient_cid` AS cid, MAX(`patient_name`) AS name, MAX(UNIX_TIMESTAMP(`created_at`)) AS t FROM `ems_treatments`
            WHERE `patient_name` LIKE ? GROUP BY `patient_cid` ORDER BY t DESC LIMIT 40]], { like })
    else
        rows = MySQL.query.await([[SELECT `patient_cid` AS cid, MAX(`patient_name`) AS name, MAX(UNIX_TIMESTAMP(`created_at`)) AS t FROM `ems_treatments`
            GROUP BY `patient_cid` ORDER BY t DESC LIMIT 40]])
    end
    for _, r in ipairs(rows or {}) do
        if not seen[r.cid] then seen[r.cid] = true out[#out + 1] = { cid = r.cid, name = r.name, last = r.t } end
    end
    if #out < 60 then
        for _, r in ipairs(MySQL.query.await('SELECT `citizenid` AS cid, `name` FROM `ems_patients`' .. (q ~= '' and ' WHERE `name` LIKE ?' or '') .. ' LIMIT 40',
            q ~= '' and { '%' .. q .. '%' } or {}) or {}) do
            if not seen[r.cid] then seen[r.cid] = true out[#out + 1] = { cid = r.cid, name = r.name } end
        end
    end
    return { list = out }
end }

P.Actions.patient = { perm = 'records_view', fn = function(src, d)
    local cid = tostring(d.cid or ''):sub(1, 50)
    if d.src then cid = P.Cid(tonumber(d.src) or -1) or '' end
    if cid == '' then return { error = 'Patient introuvable.' } end
    local file = MySQL.single.await('SELECT `name`, `blood`, `allergies`, `notes`, `updated_by`, UNIX_TIMESTAMP(`updated_at`) AS u FROM `ems_patients` WHERE `citizenid` = ?', { cid }) or {}
    local s = core:GetSourceByCitizenId(cid)
    local name = s and P.Name(s) or file.name
    if not name then name = MySQL.scalar.await('SELECT `patient_name` FROM `ems_treatments` WHERE `patient_cid` = ? ORDER BY `id` DESC LIMIT 1', { cid }) end
    if not name then return { error = 'Aucun dossier pour cette personne.' } end
    local treatments = MySQL.query.await([[SELECT `service`, `ems_name`, `call_id`, `invoice_uid`, UNIX_TIMESTAMP(`created_at`) AS t FROM `ems_treatments`
        WHERE `patient_cid` = ? ORDER BY `id` DESC LIMIT 80]], { cid }) or {}
    for _, t in ipairs(treatments) do t.label = SERVICE_LABEL[t.service] or t.service end
    return { patient = {
        cid = cid, name = name, online = s ~= nil, id = s, down = s and P.IsDown(s) or false,
        blood = file.blood, allergies = file.allergies, notes = file.notes, updatedBy = file.updated_by, updated = file.u,
        treatments = treatments,
        invoices = (P.Can(src, 'billing_manage') or P.Can(src, 'finance')) and (MySQL.query.await([[SELECT `uid`, `kind`, `amount`, `status`, UNIX_TIMESTAMP(`created_at`) AS t
            FROM `ems_invoices` WHERE `patient_cid` = ? ORDER BY `id` DESC LIMIT 30]], { cid }) or {}) or nil,
        ppa = MySQL.query.await([[SELECT `uid`, `type`, `price`, `payment_status`, `delivery_status`, `number`, `ems_name`, UNIX_TIMESTAMP(`created_at`) AS t
            FROM `ems_ppa` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 20]], { cid }) or {},
        reports = MySQL.query.await([[SELECT `id`, `title`, `outcome`, `status`, `author_name`, UNIX_TIMESTAMP(`created_at`) AS t FROM `ems_reports`
            WHERE `patient_cid` = ? ORDER BY `id` DESC LIMIT 30]], { cid }) or {},
        calls = MySQL.query.await([[SELECT `id`, `reason`, `status`, `assigned_name`, UNIX_TIMESTAMP(`created_at`) AS t FROM `ems_calls`
            WHERE `patient_cid` = ? ORDER BY `id` DESC LIMIT 20]], { cid }) or {},
        canWrite = P.Can(src, 'records_write'),
    } }
end }

P.Actions.patientSave = { perm = 'records_write', fn = function(src, d)
    local cid = tostring(d.cid or ''):sub(1, 50)
    local name = P.Clean(d.name, 100)
    if cid == '' or name == '' then return { error = 'Patient introuvable.' } end
    local blood = tostring(d.blood or '')
    if blood ~= '' and not BLOOD[blood] then return { error = 'Groupe sanguin invalide.' } end
    MySQL.query.await([[INSERT INTO `ems_patients` (`citizenid`, `name`, `blood`, `allergies`, `notes`, `updated_by`) VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE `name` = VALUES(`name`), `blood` = VALUES(`blood`), `allergies` = VALUES(`allergies`), `notes` = VALUES(`notes`), `updated_by` = VALUES(`updated_by`)]],
        { cid, name, blood ~= '' and blood or nil, P.Clean(d.allergies, 255), P.Clean(d.notes, 4000), P.Name(src) })
    return { ok = true, message = 'Dossier médical enregistré.' }
end }

-- ---------------------------------------------------------------------
-- Comptes rendus
-- ---------------------------------------------------------------------
local function ReportHistory(id, actor, action)
    MySQL.insert('INSERT INTO `ems_report_history` (`report_id`, `actor_name`, `action`) VALUES (?, ?, ?)', { id, actor, action })
end

P.Actions.reportsList = { perm = 'records_view', fn = function(_, d)
    local where, args = {}, {}
    local st = tostring(d.status or 'active')
    if st == 'active' then where[#where + 1] = "`status` <> 'archived'"
    elseif st == 'open' or st == 'done' or st == 'archived' then where[#where + 1] = '`status` = ?' args[#args + 1] = st end
    local q = P.Clean(d.q, 60):gsub('[%%_]', '')
    if q ~= '' then
        local like = '%' .. q .. '%'
        where[#where + 1] = '(`title` LIKE ? OR `patient_name` LIKE ? OR `author_name` LIKE ? OR `crew` LIKE ?)'
        for _ = 1, 4 do args[#args + 1] = like end
    end
    return { list = MySQL.query.await([[SELECT `id`, `title`, `patient_name`, `outcome`, `status`, `author_name`, `call_id`, UNIX_TIMESTAMP(`created_at`) AS t FROM `ems_reports`]]
        .. (#where > 0 and (' WHERE ' .. table.concat(where, ' AND ')) or '') .. ' ORDER BY `id` DESC LIMIT 150', args) or {} }
end }

-- Brouillon pré-rempli : depuis un appel (callId) ou les actes récents d'un patient (cid)
P.Actions.reportDraft = { perm = 'reports_write', fn = function(src, d)
    local draft = { title = '', crew = { P.Name(src) }, treatments = {}, transport = false, outcome = '', notes = '' }
    local callId = tonumber(d.callId)
    local cid = d.cid and tostring(d.cid):sub(1, 50) or nil
    if d.src then cid = P.Cid(tonumber(d.src) or -1) end
    if not callId and cid and P.CallOfPatient then
        local c = P.CallOfPatient(cid)
        if c then callId = c.id end
    end
    if callId then
        local c = MySQL.single.await([[SELECT `id`, `reason`, `street`, `patient_cid`, `patient_name`, UNIX_TIMESTAMP(`created_at`) AS t, UNIX_TIMESTAMP(`closed_at`) AS c
            FROM `ems_calls` WHERE `id` = ?]], { callId })
        if c then
            draft.callId = c.id
            draft.title = ('%s · %s'):format(c.reason, c.street or '')
            draft.started, draft.ended = c.t, c.c
            cid = cid or c.patient_cid
            draft.patientCid, draft.patientName = c.patient_cid, c.patient_name
            for _, r in ipairs(MySQL.query.await('SELECT DISTINCT `actor_name` FROM `ems_call_log` WHERE `call_id` = ? AND `actor_name` IS NOT NULL', { c.id }) or {}) do
                local n = tostring(r.actor_name):gsub(' %(.-%)$', '')
                local dup = false
                for _, x in ipairs(draft.crew) do if x == n then dup = true end end
                if not dup and n ~= 'Système' and not n:find('^Système') then draft.crew[#draft.crew + 1] = n end
            end
        end
    end
    if cid then
        local rows
        if draft.callId then
            rows = MySQL.query.await('SELECT `service`, `ems_name`, UNIX_TIMESTAMP(`created_at`) AS t FROM `ems_treatments` WHERE `call_id` = ? ORDER BY `id`', { draft.callId })
        else
            rows = MySQL.query.await([[SELECT `service`, `ems_name`, UNIX_TIMESTAMP(`created_at`) AS t FROM `ems_treatments` WHERE `patient_cid` = ?
                AND `created_at` >= DATE_SUB(NOW(), INTERVAL 3 HOUR) ORDER BY `id`]], { cid })
        end
        for _, r in ipairs(rows or {}) do
            draft.treatments[#draft.treatments + 1] = ('%s (%s)'):format(SERVICE_LABEL[r.service] or r.service, r.ems_name or '?')
            if r.service == 'transport' then draft.transport = true end
            if r.service == 'revive' then draft.outcome = 'Réanimé' end
            draft.started = draft.started and math.min(draft.started, r.t) or r.t
            draft.ended = math.max(draft.ended or 0, r.t)
        end
        draft.patientCid = draft.patientCid or cid
        if not draft.patientName then
            local s = core:GetSourceByCitizenId(cid)
            draft.patientName = s and P.Name(s) or MySQL.scalar.await('SELECT `patient_name` FROM `ems_treatments` WHERE `patient_cid` = ? ORDER BY `id` DESC LIMIT 1', { cid })
        end
        if draft.title == '' then draft.title = ('Intervention · %s'):format(draft.patientName or 'patient') end
    end
    if draft.transport and draft.outcome == '' then draft.outcome = 'Transporté à l\'hôpital' end
    return { draft = draft }
end }

P.Actions.reportGet = { perm = 'records_view', fn = function(src, d)
    local r = MySQL.single.await([[SELECT *, UNIX_TIMESTAMP(`created_at`) AS t, UNIX_TIMESTAMP(`updated_at`) AS u, UNIX_TIMESTAMP(`started_at`) AS s,
        UNIX_TIMESTAMP(`ended_at`) AS e FROM `ems_reports` WHERE `id` = ?]], { tonumber(d.id) or 0 })
    if not r then return { error = 'Compte rendu introuvable.' } end
    local okC, crew = pcall(json.decode, r.crew or '[]')
    local okT, tr = pcall(json.decode, r.treatments or '[]')
    r.crew = okC and crew or {}
    r.treatments = okT and tr or {}
    r.transport = r.transport == 1 or r.transport == true
    r.history = MySQL.query.await('SELECT `actor_name`, `action`, UNIX_TIMESTAMP(`created_at`) AS t FROM `ems_report_history` WHERE `report_id` = ? ORDER BY `id` DESC LIMIT 30', { r.id }) or {}
    local mine = r.author_cid == P.Cid(src)
    r.canEdit = (mine and P.Can(src, 'reports_write')) or P.Can(src, 'reports_manage')
    r.canArchive = P.Can(src, 'reports_manage')
    r.created_at, r.updated_at, r.started_at, r.ended_at = nil, nil, nil, nil
    return { report = r }
end }

local function List(v, max, each)
    local out = {}
    for _, x in ipairs(type(v) == 'table' and v or {}) do
        local s = P.Clean(x, each or 80)
        if s ~= '' then out[#out + 1] = s end
        if #out >= max then break end
    end
    return out
end
local function OutcomeOk(o)
    for _, x in ipairs(Config.Reports.outcomes) do if x == o then return true end end
    return o == ''
end

P.Actions.reportSave = { perm = 'reports_write', fn = function(src, d)
    local title = P.Clean(d.title, 120)
    if #title < 3 then return { error = 'Donnez un titre au compte rendu.' } end
    local outcome = tostring(d.outcome or '')
    if not OutcomeOk(outcome) then return { error = 'Issue inconnue.' } end
    local status = d.status == 'done' and 'done' or 'open'
    local crew, tr = json.encode(List(d.crew, 10, 60)), json.encode(List(d.treatments, 30, 120))
    local started = tonumber(d.started) and math.floor(d.started) or nil
    local ended = tonumber(d.ended) and math.floor(d.ended) or nil
    local notes = P.Clean(d.notes, 6000)
    local patientCid = d.patientCid and tostring(d.patientCid):sub(1, 50) or nil
    local patientName = d.patientName and P.Clean(d.patientName, 100) or nil
    local id = tonumber(d.id)
    if id then
        local r = MySQL.single.await('SELECT `author_cid`, `status` FROM `ems_reports` WHERE `id` = ?', { id })
        if not r then return { error = 'Compte rendu introuvable.' } end
        if r.status == 'archived' then return { error = 'Compte rendu archivé.' } end
        if r.author_cid ~= P.Cid(src) and not P.Can(src, 'reports_manage') then return { error = 'Vous ne pouvez modifier que vos comptes rendus.' } end
        MySQL.update.await([[UPDATE `ems_reports` SET `title` = ?, `patient_cid` = ?, `patient_name` = ?, `crew` = ?, `started_at` = FROM_UNIXTIME(?), `ended_at` = FROM_UNIXTIME(?),
            `treatments` = ?, `transport` = ?, `outcome` = ?, `notes` = ?, `status` = ? WHERE `id` = ?]],
            { title, patientCid, patientName, crew, started, ended, tr, d.transport == true and 1 or 0, outcome, notes, status, id })
        ReportHistory(id, P.Name(src), 'Modifié')
        return { ok = true, id = id, message = 'Compte rendu enregistré.' }
    end
    local e = P.Employee(src)
    id = MySQL.insert.await([[INSERT INTO `ems_reports` (`patient_cid`, `patient_name`, `call_id`, `title`, `crew`, `started_at`, `ended_at`, `treatments`, `transport`, `outcome`,
        `notes`, `status`, `author_cid`, `author_name`, `author_matricule`) VALUES (?, ?, ?, ?, ?, FROM_UNIXTIME(?), FROM_UNIXTIME(?), ?, ?, ?, ?, ?, ?, ?, ?)]],
        { patientCid, patientName, tonumber(d.callId), title, crew, started, ended, tr, d.transport == true and 1 or 0, outcome, notes, status,
          P.Cid(src), P.Name(src), e and e.matricule })
    if not id then return { error = 'Enregistrement impossible.' } end
    ReportHistory(id, P.Name(src), 'Créé')
    return { ok = true, id = id, message = ('Compte rendu #%d créé.'):format(id) }
end }

P.Actions.reportArchive = { perm = 'reports_manage', fn = function(src, d)
    local id = tonumber(d.id) or 0
    local on = d.archive == true
    MySQL.update.await('UPDATE `ems_reports` SET `status` = ? WHERE `id` = ?', { on and 'archived' or 'done', id })
    ReportHistory(id, P.Name(src), on and 'Archivé' or 'Désarchivé')
    return { ok = true, message = on and 'Compte rendu archivé.' or 'Compte rendu désarchivé.' }
end }

-- ---------------------------------------------------------------------
-- Statistiques
-- ---------------------------------------------------------------------
P.Actions.stats = { perm = 'stats_view', fn = function(_, d)
    local days = P.Int(d.days, 1, 90, 7)
    local s = MySQL.single.await([[SELECT
        (SELECT COUNT(*) FROM `ems_calls` WHERE `created_at` >= DATE_SUB(NOW(), INTERVAL ? DAY)) AS calls,
        (SELECT COUNT(*) FROM `ems_calls` WHERE `status` = 'done' AND `created_at` >= DATE_SUB(NOW(), INTERVAL ? DAY)) AS done,
        (SELECT COUNT(*) FROM `ems_calls` WHERE `status` = 'cancelled' AND `created_at` >= DATE_SUB(NOW(), INTERVAL ? DAY)) AS cancelled,
        (SELECT AVG(TIMESTAMPDIFF(SECOND, `created_at`, `closed_at`)) FROM `ems_calls` WHERE `status` = 'done' AND `created_at` >= DATE_SUB(NOW(), INTERVAL ? DAY)) AS avgTime,
        (SELECT COUNT(*) FROM `ems_reports` WHERE `created_at` >= DATE_SUB(NOW(), INTERVAL ? DAY)) AS reports,
        (SELECT COALESCE(SUM(`amount`), 0) FROM `ems_invoices` WHERE `status` = 'paid' AND `kind` = 'medical' AND `created_at` >= DATE_SUB(NOW(), INTERVAL ? DAY)) AS billed,
        (SELECT COUNT(*) FROM `ems_ppa` WHERE `delivery_status` = 'delivered' AND `created_at` >= DATE_SUB(NOW(), INTERVAL ? DAY)) AS ppa]],
        { days, days, days, days, days, days, days }) or {}
    local acts = MySQL.query.await([[SELECT `service`, COUNT(*) AS n FROM `ems_treatments` WHERE `created_at` >= DATE_SUB(NOW(), INTERVAL ? DAY) GROUP BY `service`]], { days }) or {}
    for _, a in ipairs(acts) do a.label = SERVICE_LABEL[a.service] or a.service end
    local top = MySQL.query.await([[SELECT `name`, SUM(`seconds`) AS secs FROM `ems_sessions` WHERE `started_at` >= DATE_SUB(NOW(), INTERVAL ? DAY)
        GROUP BY `citizenid`, `name` ORDER BY secs DESC LIMIT 10]], { days }) or {}
    local topActs = MySQL.query.await([[SELECT `ems_name` AS name, COUNT(*) AS n FROM `ems_treatments` WHERE `created_at` >= DATE_SUB(NOW(), INTERVAL ? DAY)
        GROUP BY `ems_cid`, `ems_name` ORDER BY n DESC LIMIT 10]], { days }) or {}
    return { days = days, totals = s, acts = acts, topTime = top, topActs = topActs }
end }
