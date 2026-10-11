-- =====================================================================
--  elyzea_police - serveur : laboratoire, affaires et rapports scientifiques
--  · Les analyses durent réellement (ends_at en base) et se terminent même après un redémarrage.
--  · Le résultat est calculé par le serveur à la fin de l'analyse, puis FIGÉ (copie des données
--    de l'arme, du propriétaire, des correspondances) : une modification ultérieure du registre
--    ne change pas un rapport existant.
--  · Le client ne fait que demander ; il ne choisit jamais un résultat.
-- =====================================================================
local P = Police
local Fx = Forensics
local F = Config.Forensics or {}
local core = exports.elyzea_core
local inv = function() return exports.elyzea_inventory end
PoliceMdtActions = PoliceMdtActions or {}
local A = PoliceMdtActions

local function Decode(s) local ok, v = pcall(json.decode, s or '') return ok and v or {} end
local function Num(v) return math.floor(tonumber(v) or 0) end
local function CanAny(src, ...)
    for _, p in ipairs({ ... }) do if P.Can(src, p, true) then return true end end
    return false
end

local function CaseCode(id) return Fx.Code('AFF', id) end
local function ReportCode(id) return Fx.Code('RPT', id) end

local function CaseOf(id)
    return id and MySQL.single.await('SELECT `id`, `code`, `title`, `status` FROM `police_cases` WHERE `id` = ?', { id }) or nil
end

-- Nom d'un personnage (pour une correspondance ADN / empreinte)
local function CharName(cid)
    local r = MySQL.single.await('SELECT `charinfo` FROM `players` WHERE `citizenid` = ?', { cid })
    if not r then return nil end
    local ci = Decode(r.charinfo)
    return ('%s %s'):format(ci.firstname or '', ci.lastname or '')
end

-- Autres preuves liées à la même référence (même arme / même profil ADN)
local function Linked(ref, exceptId)
    if not ref then return {} end
    local rows = MySQL.query.await([[SELECT e.`id`, e.`code`, e.`type`, e.`status`, e.`street`, UNIX_TIMESTAMP(e.`created_at`) AS t, c.`code` AS case_code
        FROM `police_evidence` e LEFT JOIN `police_cases` c ON c.`id` = e.`case_id`
        WHERE e.`ref` = ? AND e.`id` <> ? AND e.`status` <> 'scene' ORDER BY e.`id` DESC LIMIT 20]], { ref, exceptId or 0 }) or {}
    for _, r in ipairs(rows) do r.typeLabel = Fx.TYPE_LABEL[r.type] end
    return rows
end

-- ---------------------------------------------------------------------
-- Calcul des résultats (fin d'analyse)
-- ---------------------------------------------------------------------
local Compute = {}

Compute.ballistic = function(e, d)
    local serial = d.serial
    local rec = serial and inv():GetWeaponRecord(serial) or nil
    local res = { kind = 'ballistic', evidence = e.code, type = e.type, calibre = d.calibre or d.ammo, weaponType = d.label or d.weapon }
    if rec then
        res.identified = true
        res.serial = rec.serial
        res.engraving = rec.engraving
        res.owner = rec.owner_name or 'Aucun propriétaire enregistré'
        res.ownerKnown = rec.owner_cid ~= nil
        res.weaponStatus = rec.status
        res.registeredAt = rec.created
    elseif serial then
        res.identified = true
        res.serial = serial
        res.owner = 'Arme absente du registre'
    else
        res.identified = false
        res.compatible = d.weapon and inv():CountWeaponModel(d.weapon) or 0
    end
    res.matches = Linked(serial, e.id)
    if e.type == 'casing' or e.type == 'bullet' then
        local what = e.type == 'bullet' and ('Projectile extrait du véhicule %s'):format(d.plate or '?') or 'Douille'
        res.plate = d.plate
        res.count = d.count or 1
        res.limits = res.identified
            and 'Correspondance établie par le numéro de série relevé lors du tir. Le propriétaire enregistré n\'est pas forcément le tireur.'
            or ('Seul le type d\'arme est déterminé : %d arme(s) de ce modèle sont enregistrées.'):format(res.compatible or 0)
        res.summary = res.identified
            and ('%s : calibre %s, tiré par l\'arme %s n° %s (propriétaire enregistré : %s).'):format(what, res.calibre or '?', res.weaponType or '?', res.serial, res.owner or '?')
            or ('%s : calibre %s, compatible avec une arme de type %s.'):format(what, res.calibre or '?', res.weaponType or '?')
    else
        res.limits = 'Identité de l\'arme établie par son numéro de série. Les douilles liées partagent ce numéro.'
        res.summary = ('Arme %s n° %s%s.'):format(res.weaponType or '?', res.serial or '?', res.engraving and (' gravée « ' .. res.engraving .. ' »') or '')
    end
    return res
end

Compute.prints = function(e, d)
    local rec = d.serial and inv():GetWeaponRecord(d.serial) or nil
    local res = { kind = 'prints', evidence = e.code, weaponType = d.label, serial = d.serial, prints = {} }
    for _, h in ipairs(rec and rec.handlers or {}) do
        res.prints[#res.prints + 1] = { fingerprint = h.fingerprint or 'Empreinte partielle', name = h.fingerprint and h.name or nil, identified = h.fingerprint ~= nil and h.name ~= nil }
    end
    res.limits = 'Une empreinte prouve qu\'une personne a manipulé l\'arme, pas qu\'elle a commis un crime. Seules les dernières manipulations sont exploitables.'
    res.summary = #res.prints > 0 and ('%d empreinte(s) relevée(s) sur l\'arme.'):format(#res.prints) or 'Aucune empreinte exploitable.'
    return res
end

Compute.dna = function(e, d)
    local res = { kind = 'dna', evidence = e.code, profile = d.dna, samples = d.count or 1 }
    local cid = d.dna and MySQL.scalar.await('SELECT `citizenid` FROM `police_dna` WHERE `profile` = ?', { d.dna })
    local name = cid and CharName(cid)
    res.identified = name ~= nil
    res.match = name or 'Profil non identifié'
    res.matches = Linked(d.dna, e.id)
    res.limits = 'Profil ADN fictif propre au serveur. Une correspondance indique que la personne a saigné à cet endroit, sans préciser les circonstances.'
    res.summary = res.identified and ('Profil %s : correspond à %s.'):format(d.dna, name) or ('Profil %s non identifié.'):format(d.dna or '?')
    return res
end

local function Finish(a)
    local e = MySQL.single.await('SELECT * FROM `police_evidence` WHERE `id` = ?', { a.evidence_id })
    if not e then return end
    local d = Decode(e.data)
    local ok, res = pcall(Compute[a.kind], e, d)
    if not ok then
        print(('^1[Police] Analyse %d impossible : %s^0'):format(a.id, tostring(res)))
        res = { kind = a.kind, evidence = e.code, error = true, summary = 'Analyse impossible (erreur du laboratoire).', limits = '' }
    end
    res.analysedAt = os.time()
    res.technician = a.technician
    local updated = MySQL.update.await('UPDATE `police_analyses` SET `status` = \'done\', `result` = ? WHERE `id` = ? AND `status` = \'running\'', { json.encode(res), a.id })
    if not updated or updated < 1 then return end
    local rid = MySQL.insert.await([[INSERT IGNORE INTO `police_reports` (`analysis_id`, `evidence_id`, `case_id`, `kind`, `technician`, `technician_cid`, `data`, `conclusion`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)]], { a.id, e.id, e.case_id, a.kind, a.technician, a.technician_cid, json.encode(res), res.summary })
    if rid and rid > 0 then MySQL.update.await('UPDATE `police_reports` SET `code` = ? WHERE `id` = ?', { ReportCode(rid), rid }) end
    Fx.Log(e.id, 'Analyse terminée', 'Laboratoire', ('%s · %s'):format(Fx.ANALYSIS_LABEL[a.kind], res.summary or ''))
    local tech = a.technician_cid and core:GetSourceByCitizenId(a.technician_cid)
    if tech then P.Notify(tech, ('Analyse %s de %s terminée : rapport %s à relire.'):format(Fx.ANALYSIS_LABEL[a.kind], e.code, rid and ReportCode(rid) or ''), 'success') end
end

-- Analyses arrivées à terme (aussi celles d'avant un redémarrage)
CreateThread(function()
    while not Fx.ready do Wait(1000) end
    while true do
        local due = MySQL.query.await('SELECT `id`, `evidence_id`, `kind`, `technician`, `technician_cid` FROM `police_analyses` WHERE `status` = \'running\' AND `ends_at` <= NOW() LIMIT 10') or {}
        for _, a in ipairs(due) do Finish(a) end
        Wait(10000)
    end
end)

-- ---------------------------------------------------------------------
-- Tableau de bord
-- ---------------------------------------------------------------------
A.sciDashboard = { perm = 'sci_view', offDuty = true, fn = function()
    local s = MySQL.single.await([[SELECT
        (SELECT COUNT(*) FROM `police_cases` WHERE `status` = 'open') AS cases,
        (SELECT COUNT(*) FROM `police_evidence` WHERE `status` IN ('collected','reception')) AS pending,
        (SELECT COUNT(*) FROM `police_analyses` WHERE `status` = 'running') AS running,
        (SELECT COUNT(*) FROM `police_analyses` WHERE `status` = 'done' AND `started_at` >= CURDATE()) AS doneToday,
        (SELECT COUNT(*) FROM `police_reports` WHERE `status` = 'draft') AS drafts,
        (SELECT COUNT(*) FROM `police_evidence` WHERE `status` = 'scene') AS scene]]) or {}
    local running = MySQL.query.await([[SELECT a.`id`, a.`kind`, a.`technician`, UNIX_TIMESTAMP(a.`ends_at`) AS ends, e.`code`
        FROM `police_analyses` a JOIN `police_evidence` e ON e.`id` = a.`evidence_id` WHERE a.`status` = 'running' ORDER BY a.`ends_at` LIMIT 10]]) or {}
    local recent = MySQL.query.await([[SELECT `id`, `code`, `type`, `status`, `collected_by`, `street`, UNIX_TIMESTAMP(`collected_at`) AS t
        FROM `police_evidence` WHERE `collected_at` IS NOT NULL ORDER BY `collected_at` DESC LIMIT 8]]) or {}
    local reports = MySQL.query.await([[SELECT r.`id`, r.`code`, r.`kind`, r.`status`, r.`technician`, e.`code` AS evidence, UNIX_TIMESTAMP(r.`created_at`) AS t
        FROM `police_reports` r JOIN `police_evidence` e ON e.`id` = r.`evidence_id` ORDER BY r.`id` DESC LIMIT 8]]) or {}
    for _, r in ipairs(running) do r.label = Fx.ANALYSIS_LABEL[r.kind] end
    for _, r in ipairs(recent) do r.typeLabel, r.statusLabel = Fx.TYPE_LABEL[r.type], Fx.STATUS_LABEL[r.status] end
    for _, r in ipairs(reports) do r.label = Fx.ANALYSIS_LABEL[r.kind] end
    return { stats = s, running = running, recent = recent, reports = reports, now = os.time() }
end }

-- ---------------------------------------------------------------------
-- Affaires
-- ---------------------------------------------------------------------
A.sciCases = { perm = 'sci_view', offDuty = true, fn = function(_, d)
    local status = d.status == 'closed' and 'closed' or (d.status == 'all' and nil or 'open')
    local rows = MySQL.query.await(([[SELECT c.`id`, c.`code`, c.`title`, c.`status`, c.`created_by`, UNIX_TIMESTAMP(c.`updated_at`) AS t,
        (SELECT COUNT(*) FROM `police_evidence` e WHERE e.`case_id` = c.`id`) AS evidence
        FROM `police_cases` c %s ORDER BY c.`updated_at` DESC LIMIT 60]]):format(status and 'WHERE c.`status` = ?' or ''), status and { status } or {}) or {}
    return { list = rows }
end }

A.sciCase = { perm = 'sci_view', offDuty = true, fn = function(_, d)
    local c = MySQL.single.await('SELECT `id`, `code`, `title`, `description`, `status`, `created_by`, UNIX_TIMESTAMP(`created_at`) AS t FROM `police_cases` WHERE `id` = ?', { Num(d.id) })
    if not c then return { error = 'Affaire introuvable.' } end
    local evidence = MySQL.query.await([[SELECT `id`, `code`, `type`, `status`, `street`, `collected_by`, UNIX_TIMESTAMP(`created_at`) AS t FROM `police_evidence` WHERE `case_id` = ? ORDER BY `id`]], { c.id }) or {}
    for _, e in ipairs(evidence) do e.typeLabel, e.statusLabel = Fx.TYPE_LABEL[e.type], Fx.STATUS_LABEL[e.status] end
    local notes = MySQL.query.await('SELECT `kind`, `author`, `text`, UNIX_TIMESTAMP(`created_at`) AS t FROM `police_case_notes` WHERE `case_id` = ? ORDER BY `id` DESC', { c.id }) or {}
    local timeline = MySQL.query.await([[SELECT l.`action`, l.`actor`, l.`details`, UNIX_TIMESTAMP(l.`created_at`) AS t, e.`code`
        FROM `police_evidence_log` l JOIN `police_evidence` e ON e.`id` = l.`evidence_id` WHERE e.`case_id` = ? ORDER BY l.`id` DESC LIMIT 80]], { c.id }) or {}
    for _, n in ipairs(notes) do timeline[#timeline + 1] = { action = n.kind == 'status' and 'Statut de l\'affaire' or 'Note', actor = n.author, details = n.text, t = n.t } end
    table.sort(timeline, function(a, b) return (a.t or 0) > (b.t or 0) end)
    local officers, seen = {}, {}
    for _, row in ipairs(timeline) do
        if row.actor and row.actor ~= 'Système' and row.actor ~= 'Laboratoire' and not seen[row.actor] then seen[row.actor] = true officers[#officers + 1] = row.actor end
    end
    if c.created_by and not seen[c.created_by] then officers[#officers + 1] = c.created_by end
    local reports = MySQL.query.await([[SELECT r.`id`, r.`code`, r.`kind`, r.`status`, e.`code` AS evidence FROM `police_reports` r JOIN `police_evidence` e ON e.`id` = r.`evidence_id`
        WHERE e.`case_id` = ? ORDER BY r.`id` DESC]], { c.id }) or {}
    for _, r in ipairs(reports) do r.label = Fx.ANALYSIS_LABEL[r.kind] end
    return { case = c, evidence = evidence, notes = notes, timeline = timeline, officers = officers, reports = reports }
end }

A.sciCaseCreate = { perm = 'sci_cases', offDuty = true, fn = function(src, d)
    local title = Fx.Clean(d.title, 120)
    if #title < 3 then return { error = 'Donnez un titre à l\'affaire.' } end
    local id = MySQL.insert.await('INSERT INTO `police_cases` (`title`, `description`, `created_by`, `created_cid`) VALUES (?, ?, ?, ?)',
        { title, Fx.Clean(d.description, 4000), P.Name(src), P.Cid(src) })
    MySQL.update.await('UPDATE `police_cases` SET `code` = ? WHERE `id` = ?', { CaseCode(id), id })
    MySQL.insert.await('INSERT INTO `police_case_notes` (`case_id`, `kind`, `author`, `author_cid`, `text`) VALUES (?, ?, ?, ?, ?)', { id, 'status', P.Name(src), P.Cid(src), 'Affaire ouverte.' })
    P.Log(src, 'Affaire créée', ('%s · %s'):format(CaseCode(id), title))
    return { ok = true, message = ('Affaire %s créée.'):format(CaseCode(id)), id = id }
end }

A.sciCaseUpdate = { perm = 'sci_cases', offDuty = true, fn = function(src, d)
    local c = CaseOf(Num(d.id))
    if not c then return { error = 'Affaire introuvable.' } end
    local title = Fx.Clean(d.title, 120)
    if #title < 3 then return { error = 'Donnez un titre à l\'affaire.' } end
    MySQL.update.await('UPDATE `police_cases` SET `title` = ?, `description` = ? WHERE `id` = ?', { title, Fx.Clean(d.description, 4000), c.id })
    P.Log(src, 'Affaire modifiée', c.code)
    return { ok = true, message = 'Affaire enregistrée.' }
end }

A.sciCaseStatus = { perm = 'sci_cases', offDuty = true, fn = function(src, d)
    local c = CaseOf(Num(d.id))
    if not c then return { error = 'Affaire introuvable.' } end
    local status = d.status == 'closed' and 'closed' or 'open'
    if status == c.status then return { error = 'L\'affaire a déjà ce statut.' } end
    local reason = Fx.Clean(d.reason, 500)
    if #reason < 5 then return { error = 'Indiquez la raison (5 caractères minimum).' } end
    MySQL.update.await('UPDATE `police_cases` SET `status` = ? WHERE `id` = ?', { status, c.id })
    MySQL.insert.await('INSERT INTO `police_case_notes` (`case_id`, `kind`, `author`, `author_cid`, `text`) VALUES (?, ?, ?, ?, ?)',
        { c.id, 'status', P.Name(src), P.Cid(src), (status == 'closed' and 'Clôturée : ' or 'Rouverte : ') .. reason })
    P.Log(src, status == 'closed' and 'Affaire clôturée' or 'Affaire rouverte', ('%s · %s'):format(c.code, reason))
    return { ok = true, message = status == 'closed' and 'Affaire clôturée.' or 'Affaire rouverte.' }
end }

A.sciCaseNote = { perm = 'sci_view', offDuty = true, fn = function(src, d)
    if not CanAny(src, 'sci_cases', 'sci_lab', 'sci_collect') then return { error = 'Votre accès ne permet pas d\'ajouter une note.' } end
    local c = CaseOf(Num(d.id))
    if not c then return { error = 'Affaire introuvable.' } end
    local text = Fx.Clean(d.text, 1000)
    if #text < 2 then return { error = 'Note vide.' } end
    MySQL.insert.await('INSERT INTO `police_case_notes` (`case_id`, `kind`, `author`, `author_cid`, `text`) VALUES (?, ?, ?, ?, ?)', { c.id, 'note', P.Name(src), P.Cid(src), text })
    MySQL.update('UPDATE `police_cases` SET `updated_at` = NOW() WHERE `id` = ?', { c.id })
    return { ok = true, message = 'Note ajoutée.' }
end }

-- ---------------------------------------------------------------------
-- Preuves
-- ---------------------------------------------------------------------
A.sciEvidence = { perm = 'sci_view', offDuty = true, fn = function(_, d)
    local where, params = { "e.`status` <> 'scene'" }, {}
    if d.status and Fx.STATUS_LABEL[d.status] then where[#where + 1] = 'e.`status` = ?' params[#params + 1] = d.status end
    if d.type and Fx.TYPE_LABEL[d.type] then where[#where + 1] = 'e.`type` = ?' params[#params + 1] = d.type end
    local q = Fx.Clean(d.q, 30)
    if q ~= '' then where[#where + 1] = '(e.`code` LIKE ? OR e.`street` LIKE ? OR c.`code` LIKE ?)' local l = '%' .. q:gsub('[%%_]', '') .. '%' params[#params + 1] = l params[#params + 1] = l params[#params + 1] = l end
    local rows = MySQL.query.await(([[SELECT e.`id`, e.`code`, e.`type`, e.`status`, e.`location`, e.`street`, e.`collected_by`, UNIX_TIMESTAMP(e.`collected_at`) AS t, c.`code` AS case_code,
        (SELECT COUNT(*) FROM `police_analyses` a WHERE a.`evidence_id` = e.`id` AND a.`status` = 'done') AS analyses
        FROM `police_evidence` e LEFT JOIN `police_cases` c ON c.`id` = e.`case_id` WHERE %s ORDER BY e.`id` DESC LIMIT 80]]):format(table.concat(where, ' AND ')), params) or {}
    for _, r in ipairs(rows) do r.typeLabel, r.statusLabel = Fx.TYPE_LABEL[r.type], Fx.STATUS_LABEL[r.status] end
    local cases = MySQL.query.await('SELECT `id`, `code`, `title` FROM `police_cases` WHERE `status` = \'open\' ORDER BY `id` DESC LIMIT 50') or {}
    return { list = rows, cases = cases }
end }

A.sciEvidenceOne = { perm = 'sci_view', offDuty = true, fn = function(src, d)
    local e = MySQL.single.await([[SELECT e.*, UNIX_TIMESTAMP(e.`created_at`) AS t, UNIX_TIMESTAMP(e.`collected_at`) AS ct, c.`code` AS case_code, c.`title` AS case_title
        FROM `police_evidence` e LEFT JOIN `police_cases` c ON c.`id` = e.`case_id` WHERE e.`id` = ?]], { Num(d.id) })
    if not e or e.status == 'scene' then return { error = 'Preuve introuvable.' } end
    local data = Decode(e.data)
    -- Données visibles avant analyse : ce que l'œil voit (jamais le numéro relevé au tir ni le profil ADN)
    local visible = { count = data.count }
    if e.type == 'casing' or e.type == 'bullet' then visible.calibre = data.calibre end
    if e.type == 'bullet' then visible.plate = data.plate end
    if e.type == 'weapon' then visible.weapon, visible.serial, visible.engraving = data.label, data.serial, data.engraving end
    local log = MySQL.query.await('SELECT `action`, `actor`, `details`, UNIX_TIMESTAMP(`created_at`) AS t FROM `police_evidence_log` WHERE `evidence_id` = ? ORDER BY `id`', { e.id }) or {}
    local analyses = MySQL.query.await('SELECT `id`, `kind`, `status`, `technician`, UNIX_TIMESTAMP(`ends_at`) AS ends FROM `police_analyses` WHERE `evidence_id` = ? ORDER BY `id`', { e.id }) or {}
    for _, a in ipairs(analyses) do a.label = Fx.ANALYSIS_LABEL[a.kind] end
    local reports = MySQL.query.await('SELECT `id`, `code`, `kind`, `status` FROM `police_reports` WHERE `evidence_id` = ? ORDER BY `id`', { e.id }) or {}
    for _, r in ipairs(reports) do r.label = Fx.ANALYSIS_LABEL[r.kind] end
    local possible = {}
    for _, k in ipairs(Fx.ANALYSES_FOR[e.type] or {}) do possible[#possible + 1] = { kind = k, label = Fx.ANALYSIS_LABEL[k] } end
    return {
        evidence = { id = e.id, code = e.code, type = e.type, typeLabel = Fx.TYPE_LABEL[e.type], status = e.status, statusLabel = Fx.STATUS_LABEL[e.status],
            location = e.location, street = e.street, x = e.x, y = e.y, collected_by = e.collected_by, holder = e.holder, t = e.t, ct = e.ct,
            case_id = e.case_id, case_code = e.case_code, case_title = e.case_title, visible = visible },
        log = log, analyses = analyses, reports = reports, possible = possible, now = os.time(),
        cases = MySQL.query.await('SELECT `id`, `code`, `title` FROM `police_cases` WHERE `status` = \'open\' ORDER BY `id` DESC LIMIT 50') or {},
        labNear = Fx.LabNear(src),
    }
end }

A.sciEvidenceLink = { perm = 'sci_view', offDuty = true, fn = function(src, d)
    if not CanAny(src, 'sci_cases', 'sci_collect', 'sci_lab') then return { error = 'Votre accès ne permet pas d\'associer une preuve.' } end
    local e = MySQL.single.await('SELECT `id`, `code`, `case_id`, `status` FROM `police_evidence` WHERE `id` = ?', { Num(d.id) })
    if not e or e.status == 'scene' then return { error = 'Preuve introuvable.' } end
    local caseId = tonumber(d.caseId)
    local c = caseId and caseId > 0 and CaseOf(caseId) or nil
    if caseId and caseId > 0 and (not c or c.status ~= 'open') then return { error = 'Affaire introuvable ou clôturée.' } end
    MySQL.update.await('UPDATE `police_evidence` SET `case_id` = ? WHERE `id` = ?', { c and c.id or nil, e.id })
    MySQL.update.await('UPDATE `police_reports` SET `case_id` = ? WHERE `evidence_id` = ? AND `status` = \'draft\'', { c and c.id or nil, e.id })
    Fx.Log(e.id, c and 'Associée à une affaire' or 'Retirée de l\'affaire', src, c and ('%s · %s'):format(c.code, c.title) or nil)
    if c then MySQL.update('UPDATE `police_cases` SET `updated_at` = NOW() WHERE `id` = ?', { c.id }) end
    return { ok = true, message = c and ('%s associée à %s.'):format(e.code, c.code) or 'Preuve retirée de l\'affaire.' }
end }

A.sciReceive = { perm = 'sci_view', fn = function(src) return Fx.ReceiveAll(src) end }

A.sciMyWeapons = { perm = 'sci_collect', fn = function(src)
    local cases = MySQL.query.await('SELECT `id`, `code`, `title` FROM `police_cases` WHERE `status` = \'open\' ORDER BY `id` DESC LIMIT 50') or {}
    return { list = Fx.MyWeapons(src), cases = cases }
end }
A.sciSeizeWeapon = { perm = 'sci_collect', fn = function(src, d) return Fx.SeizeWeapon(src, d.slot, d.caseId) end }

-- ---------------------------------------------------------------------
-- Laboratoire
-- ---------------------------------------------------------------------
local labBusy = {}
A.sciAnalyze = { perm = 'sci_lab', fn = function(src, d)
    if labBusy[src] then return { error = 'Analyse en cours de lancement.' } end
    if not Fx.LabNear(src) then return { error = 'Les analyses se lancent au laboratoire.' } end
    local e = MySQL.single.await('SELECT `id`, `code`, `type`, `status` FROM `police_evidence` WHERE `id` = ?', { Num(d.id) })
    if not e then return { error = 'Preuve introuvable.' } end
    local kind = tostring(d.kind or '')
    local okKind = false
    for _, k in ipairs(Fx.ANALYSES_FOR[e.type] or {}) do if k == kind then okKind = true end end
    if not okKind then return { error = 'Analyse impossible sur ce type de preuve.' } end
    if e.status ~= 'reception' and e.status ~= 'lab' and e.status ~= 'stored' then return { error = 'La preuve doit d\'abord être réceptionnée au laboratoire.' } end
    labBusy[src] = true
    local exists = MySQL.scalar.await('SELECT `id` FROM `police_analyses` WHERE `evidence_id` = ? AND `kind` = ? LIMIT 1', { e.id, kind })
    if exists then labBusy[src] = nil return { error = 'Cette analyse a déjà été faite ou est en cours.' } end
    local secs = math.max(10, math.floor(tonumber((F.analysis or {})[kind]) or 120))
    MySQL.insert.await('INSERT INTO `police_analyses` (`evidence_id`, `kind`, `technician`, `technician_cid`, `ends_at`) VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? SECOND))',
        { e.id, kind, P.Name(src), P.Cid(src), secs })
    MySQL.update.await('UPDATE `police_evidence` SET `status` = \'lab\', `location` = \'Laboratoire\' WHERE `id` = ?', { e.id })
    Fx.Log(e.id, 'Analyse lancée', src, ('%s (%d s)'):format(Fx.ANALYSIS_LABEL[kind], secs))
    labBusy[src] = nil
    return { ok = true, message = ('Analyse %s de %s lancée (%d s).'):format(Fx.ANALYSIS_LABEL[kind], e.code, secs) }
end }

A.sciStore = { perm = 'sci_lab', fn = function(src, d)
    local e = MySQL.single.await('SELECT `id`, `code`, `status` FROM `police_evidence` WHERE `id` = ?', { Num(d.id) })
    if not e or (e.status ~= 'reception' and e.status ~= 'lab') then return { error = 'Seule une preuve du laboratoire peut être rangée.' } end
    local running = MySQL.scalar.await('SELECT COUNT(*) FROM `police_analyses` WHERE `evidence_id` = ? AND `status` = \'running\'', { e.id })
    if (tonumber(running) or 0) > 0 then return { error = 'Une analyse est en cours sur cette preuve.' } end
    MySQL.update.await('UPDATE `police_evidence` SET `status` = \'stored\', `location` = \'Salle des scellés\' WHERE `id` = ?', { e.id })
    Fx.Log(e.id, 'Stockage', src, 'Salle des scellés')
    return { ok = true, message = ('%s rangée en salle des scellés.'):format(e.code) }
end }

A.sciReturn = { perm = 'sci_custody', fn = function(src, d)
    local e = MySQL.single.await('SELECT * FROM `police_evidence` WHERE `id` = ?', { Num(d.id) })
    if not e or e.type ~= 'weapon' or (e.status ~= 'stored' and e.status ~= 'lab' and e.status ~= 'reception') then return { error = 'Seule une arme du laboratoire peut être restituée.' } end
    local data = Decode(e.data)
    local item = data.item
    if not item or not item.name then return { error = 'Données de l\'arme manquantes.' } end
    if not inv():CanCarryItem(src, item.name, 1, item.metadata) then return { error = 'Inventaire plein.' } end
    local n = MySQL.update.await('UPDATE `police_evidence` SET `status` = \'returned\', `location` = NULL, `holder` = ?, `holder_cid` = ? WHERE `id` = ? AND `status` = ?', { P.Name(src), P.Cid(src), e.id, e.status })
    if not n or n < 1 then return { error = 'Preuve déjà traitée.' } end
    inv():AddItem(src, item.name, 1, item.metadata)
    pcall(function() inv():SetWeaponStatus(data.serial, 'active', P.Name(src), e.code) end)
    Fx.Log(e.id, 'Restitution', src, 'Arme remise à l\'agent pour restitution')
    P.Log(src, 'Arme restituée', e.code)
    return { ok = true, message = ('Arme %s remise dans votre inventaire pour restitution.'):format(e.code) }
end }

A.sciDestroy = { perm = 'sci_custody', fn = function(src, d)
    local e = MySQL.single.await('SELECT `id`, `code`, `type`, `status`, `ref` FROM `police_evidence` WHERE `id` = ?', { Num(d.id) })
    if not e or e.status == 'scene' or e.status == 'destroyed' or e.status == 'returned' or e.status == 'collected' then return { error = 'Cette preuve ne peut pas être détruite.' } end
    local reason = Fx.Clean(d.reason, 200)
    if #reason < 5 then return { error = 'Indiquez la raison de la destruction.' } end
    MySQL.update.await('UPDATE `police_evidence` SET `status` = \'destroyed\', `location` = NULL WHERE `id` = ?', { e.id })
    if e.type == 'weapon' then pcall(function() inv():SetWeaponStatus(e.ref, 'destroyed', P.Name(src), e.code) end) end
    Fx.Log(e.id, 'Destruction', src, reason)
    P.Log(src, 'Preuve détruite', ('%s · %s'):format(e.code, reason))
    return { ok = true, message = ('%s détruite.'):format(e.code) }
end }

-- Comparaison de deux preuves analysées (même arme ? même profil ?)
A.sciCompare = { perm = 'sci_lab', offDuty = true, fn = function(_, d)
    local function Res(id)
        local e = MySQL.single.await('SELECT `id`, `code`, `type` FROM `police_evidence` WHERE `id` = ?', { Num(id) })
        if not e then return nil end
        local rows = MySQL.query.await('SELECT `kind`, `result` FROM `police_analyses` WHERE `evidence_id` = ? AND `status` = \'done\'', { e.id }) or {}
        e.results = {}
        for _, r in ipairs(rows) do e.results[r.kind] = Decode(r.result) end
        return e
    end
    local a, b = Res(d.a), Res(d.b)
    if not a or not b then return { error = 'Choisissez deux preuves.' } end
    if a.id == b.id then return { error = 'Choisissez deux preuves différentes.' } end
    local ra, rb = a.results.ballistic, b.results.ballistic
    local da, db = a.results.dna, b.results.dna
    local text, match
    if ra and rb then
        if ra.serial and rb.serial then
            match = ra.serial == rb.serial
            text = match and ('Même arme : n° %s.'):format(ra.serial) or ('Armes différentes (n° %s / n° %s).'):format(ra.serial, rb.serial)
        else
            match = nil
            text = ('Identification individuelle impossible : %s / %s.'):format(ra.weaponType or '?', rb.weaponType or '?')
        end
    elseif da and db then
        match = da.profile == db.profile
        text = match and ('Même profil ADN : %s.'):format(da.profile) or 'Profils ADN différents.'
    else
        return { error = 'Les deux preuves doivent avoir une analyse terminée du même type (balistique ou ADN).' }
    end
    return { ok = true, text = ('%s ↔ %s : %s'):format(a.code, b.code, text), match = match }
end }

-- ---------------------------------------------------------------------
-- Rapports
-- ---------------------------------------------------------------------
A.sciReports = { perm = 'sci_view', offDuty = true, fn = function(_, d)
    local status = (d.status == 'draft' or d.status == 'final') and d.status or nil
    local rows = MySQL.query.await(([[SELECT r.`id`, r.`code`, r.`kind`, r.`status`, r.`technician`, UNIX_TIMESTAMP(r.`created_at`) AS t, e.`code` AS evidence, c.`code` AS case_code
        FROM `police_reports` r JOIN `police_evidence` e ON e.`id` = r.`evidence_id` LEFT JOIN `police_cases` c ON c.`id` = r.`case_id`
        %s ORDER BY r.`id` DESC LIMIT 80]]):format(status and 'WHERE r.`status` = ?' or ''), status and { status } or {}) or {}
    for _, r in ipairs(rows) do r.label = Fx.ANALYSIS_LABEL[r.kind] end
    return { list = rows }
end }

A.sciReport = { perm = 'sci_view', offDuty = true, fn = function(_, d)
    local r = MySQL.single.await([[SELECT r.*, UNIX_TIMESTAMP(r.`created_at`) AS t, UNIX_TIMESTAMP(r.`finalized_at`) AS ft, e.`code` AS evidence, e.`type` AS etype, e.`street`,
        UNIX_TIMESTAMP(e.`collected_at`) AS ct, e.`collected_by`, c.`code` AS case_code, c.`title` AS case_title
        FROM `police_reports` r JOIN `police_evidence` e ON e.`id` = r.`evidence_id` LEFT JOIN `police_cases` c ON c.`id` = r.`case_id` WHERE r.`id` = ?]], { Num(d.id) })
    if not r then return { error = 'Rapport introuvable.' } end
    r.data = Decode(r.data)
    r.label = Fx.ANALYSIS_LABEL[r.kind]
    r.typeLabel = Fx.TYPE_LABEL[r.etype]
    r.technician_cid = nil
    return { report = r }
end }

A.sciReportSave = { perm = 'sci_lab', offDuty = true, fn = function(src, d)
    local r = MySQL.single.await('SELECT `id`, `code`, `status` FROM `police_reports` WHERE `id` = ?', { Num(d.id) })
    if not r then return { error = 'Rapport introuvable.' } end
    if r.status ~= 'draft' then return { error = 'Un rapport finalisé ne peut plus être modifié.' } end
    local text = Fx.Clean(d.conclusion, 3000)
    if #text < 5 then return { error = 'Rédigez la conclusion.' } end
    MySQL.update.await('UPDATE `police_reports` SET `conclusion` = ?, `technician` = ?, `technician_cid` = ? WHERE `id` = ? AND `status` = \'draft\'', { text, P.Name(src), P.Cid(src), r.id })
    if d.finalize == true then
        MySQL.update.await('UPDATE `police_reports` SET `status` = \'final\', `finalized_at` = NOW() WHERE `id` = ? AND `status` = \'draft\'', { r.id })
        P.Log(src, 'Rapport scientifique finalisé', r.code)
        return { ok = true, message = ('Rapport %s finalisé et transmis aux enquêteurs.'):format(r.code) }
    end
    return { ok = true, message = 'Brouillon enregistré.' }
end }

AddEventHandler('playerDropped', function() labBusy[source] = nil end)
