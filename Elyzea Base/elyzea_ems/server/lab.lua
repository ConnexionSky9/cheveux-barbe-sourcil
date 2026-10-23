-- =====================================================================
--  ELYZEA EMS - serveur : laboratoire (analyse sanguine « Alcool et substances »)
--  1. Consommations : enregistrées UNIQUEMENT par le serveur
--       · objets consommés dans l'inventaire (événement elyzea_inventory:usedItem)
--       · exports.elyzea_ems:RecordConsumption(source, substance [, quantité]) pour les autres scripts serveur
--  2. Prélèvement (ALT sur le patient, permission lab_sample) : date et heure gardées.
--  3. Analyse (tablette › Laboratoire, permission lab_analyze) : calcul à partir des consommations
--     faites AVANT le prélèvement (shared/lab_rules.lua). Rapport gardé avec l'identité du patient,
--     le préleveur, le médecin responsable, les dates, les résultats et l'historique.
--  Résultats simulés pour le jeu de rôle. Aucun hasard, aucun positif sans consommation enregistrée.
-- =====================================================================
local P = Ems
local L = Config.Lab
local core = exports.elyzea_core

local Lab = { trackingSince = nil, ready = false, sources = {}, itemMap = {}, lastSample = {} }
EmsLab = Lab

-- objet d'inventaire → { kind, amount }
for item, grams in pairs(L.alcohol.items or {}) do Lab.itemMap[item] = { kind = 'alcohol', amount = tonumber(grams) or 10 } end
local SUB = {}
for _, s in ipairs(L.substances or {}) do
    if type(s.id) == 'string' and s.id:match('^[%w_]+$') then
        SUB[s.id] = s
        for _, item in ipairs(s.items or {}) do Lab.itemMap[item] = { kind = s.id, amount = 1 } Lab.sources[s.id] = true end
    end
end

-- ---------------------------------------------------------------------
-- Base de données
-- ---------------------------------------------------------------------
CreateThread(function()
    while not P.ready do Wait(500) end
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `ems_lab_meta` (`k` VARCHAR(64) NOT NULL PRIMARY KEY, `v` VARCHAR(255) NOT NULL) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `ems_lab_consumptions` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `citizenid` VARCHAR(50) NOT NULL,
        `kind` VARCHAR(32) NOT NULL,
        `amount` DECIMAL(8,2) NOT NULL DEFAULT 1,
        `source` VARCHAR(64) NOT NULL DEFAULT '',
        `consumed_at` INT UNSIGNED NOT NULL,
        INDEX `cid_time` (`citizenid`, `consumed_at`)) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `ems_lab_samples` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `citizenid` VARCHAR(50) NOT NULL,
        `patient_name` VARCHAR(100) NOT NULL,
        `job` VARCHAR(50) NULL,
        `sampled_by_cid` VARCHAR(50) NULL,
        `sampled_by_name` VARCHAR(100) NOT NULL,
        `sampled_at` INT UNSIGNED NOT NULL,
        `status` VARCHAR(12) NOT NULL DEFAULT 'pending',
        `analyzed_by_cid` VARCHAR(50) NULL,
        `analyzed_by_name` VARCHAR(100) NULL,
        `analyzed_at` INT UNSIGNED NULL,
        `results` LONGTEXT NULL,
        `history` LONGTEXT NULL,
        INDEX `cid` (`citizenid`), INDEX `status` (`status`), INDEX `sampled` (`sampled_at`)) DEFAULT CHARSET=utf8mb4]])
    -- Début du suivi : avant cette date, on ne sait pas ce qui a été consommé (résultat « indéterminé »)
    local since = MySQL.scalar.await('SELECT `v` FROM `ems_lab_meta` WHERE `k` = ?', { 'tracking_since' })
    if not since then
        since = os.time()
        MySQL.insert.await('INSERT INTO `ems_lab_meta` (`k`, `v`) VALUES (?, ?)', { 'tracking_since', tostring(since) })
        print('^2[EMS] Laboratoire : suivi des consommations démarré.^0')
    end
    Lab.trackingSince = tonumber(since)
    -- Substances alimentées par un autre script (RecordConsumption) : retenues comme sources de données
    for _, r in ipairs(MySQL.query.await('SELECT `k` FROM `ems_lab_meta` WHERE `k` LIKE ?', { 'source:%' }) or {}) do
        Lab.sources[r.k:sub(8)] = true
    end
    -- Grades déjà créés : les nouvelles permissions du laboratoire sont données une seule fois
    if not MySQL.scalar.await('SELECT `v` FROM `ems_lab_meta` WHERE `k` = ?', { 'perms_v1' }) then
        local n = 0
        for _, g in pairs(P.grades or {}) do
            local add = {}
            if g.name == 'Directeur' or g.perms.direction then add = { 'lab_sample', 'lab_analyze', 'lab_view' }
            elseif g.perms.reports_manage then add = { 'lab_sample', 'lab_analyze', 'lab_view' }
            elseif g.perms.records_write then add = { 'lab_sample', 'lab_view' } end
            if #add > 0 then
                for _, k in ipairs(add) do g.perms[k] = true end
                MySQL.update.await('UPDATE `ems_grades` SET `perms` = ? WHERE `id` = ?', { P.EncodePerms(g.perms), g.id })
                n = n + 1
            end
        end
        MySQL.insert.await('INSERT INTO `ems_lab_meta` (`k`, `v`) VALUES (?, ?)', { 'perms_v1', tostring(os.time()) })
        if n > 0 then
            print(('^2[EMS] Laboratoire : permissions ajoutées à %d grade(s) existant(s).^0'):format(n))
            for s in pairs(core:GetPlayers() or {}) do pcall(P.PushState, s) end
        end
    end
    -- Nettoyage
    MySQL.query('DELETE FROM `ems_lab_consumptions` WHERE `consumed_at` < ?', { os.time() - (L.keepConsumptionsDays or 14) * 86400 })
    MySQL.query('DELETE FROM `ems_lab_samples` WHERE `sampled_at` < ?', { os.time() - (L.keepSamplesDays or 180) * 86400 })
    Lab.ready = true
end)

-- ---------------------------------------------------------------------
-- Enregistrement des consommations (serveur uniquement)
-- ---------------------------------------------------------------------
function Lab.Record(src, kind, amount, source)
    src = tonumber(src)
    if not src or not Lab.ready then return false end
    kind = tostring(kind or ''):lower()
    if kind ~= 'alcohol' and not SUB[kind] then return false end
    local cid = P.Cid(src)
    if not cid then return false end
    amount = math.max(0.01, math.min(500, tonumber(amount) or 1))
    MySQL.insert('INSERT INTO `ems_lab_consumptions` (`citizenid`, `kind`, `amount`, `source`, `consumed_at`) VALUES (?, ?, ?, ?, ?)',
        { cid, kind, amount, tostring(source or ''):sub(1, 64), os.time() })
    return true
end

-- Objets consommés dans l'inventaire (nourriture / boissons / objets utilisables qui déclenchent l'événement)
AddEventHandler('elyzea_inventory:usedItem', function(src, name)
    local m = Lab.itemMap[tostring(name or '')]
    if m then Lab.Record(src, m.kind, m.amount, 'item:' .. name) end
end)

-- Autres scripts serveur : exports.elyzea_ems:RecordConsumption(source, 'cocaine', 1)
-- (alcool : quantité en grammes d'alcool pur, 10 g ≈ un verre)
exports('RecordConsumption', function(src, kind, amount)
    local ok = Lab.Record(src, kind, amount, 'script:' .. (GetInvokingResource() or '?'))
    kind = tostring(kind or ''):lower()
    if ok and kind ~= 'alcohol' and not Lab.sources[kind] then
        Lab.sources[kind] = true
        MySQL.insert('INSERT IGNORE INTO `ems_lab_meta` (`k`, `v`) VALUES (?, ?)', { 'source:' .. kind, GetInvokingResource() or '?' })
    end
    return ok
end)

-- ---------------------------------------------------------------------
-- Analyse
-- ---------------------------------------------------------------------
local function compute(cid, sampleT)
    local maxH = L.alcohol.detectionHours or 12
    for _, s in pairs(SUB) do maxH = math.max(maxH, s.detectionHours or 48) end
    local rows = MySQL.query.await('SELECT `kind`, `amount`, `consumed_at` AS `at` FROM `ems_lab_consumptions` WHERE `citizenid` = ? AND `consumed_at` BETWEEN ? AND ?',
        { cid, sampleT - maxH * 3600, sampleT }) or {}
    local byKind = {}
    for _, r in ipairs(rows) do
        byKind[r.kind] = byKind[r.kind] or {}
        table.insert(byKind[r.kind], { at = tonumber(r.at), amount = tonumber(r.amount) })
    end
    return LabRules.Analyze(byKind, sampleT, Lab.trackingSince, L, Lab.sources)
end
Lab.Compute = compute

local function decode(s, def)
    local ok, v = pcall(json.decode, s or '')
    return ok and v or def
end

local function view(row, full)
    local v = { id = row.id, ref = ('LAB-%05d'):format(row.id), cid = row.citizenid, patient = row.patient_name, status = row.status,
        sampledBy = row.sampled_by_name, sampledAt = tonumber(row.sampled_at), analyzedBy = row.analyzed_by_name, analyzedAt = tonumber(row.analyzed_at) }
    if full then
        v.results = decode(row.results, nil)
        v.history = decode(row.history, {})
    elseif row.results then
        -- résumé pour la liste : positifs
        local r = decode(row.results, {})
        local pos = {}
        if r.alcohol and r.alcohol.status == 'positive' then pos[#pos + 1] = 'Alcool' end
        for _, s in ipairs(r.substances or {}) do if s.status == 'positive' then pos[#pos + 1] = s.label end end
        v.positives = pos
    end
    return v
end

-- Enregistre un prélèvement (heure du prélèvement = maintenant). Renvoie l'identifiant, ou nil + message.
-- Utilisé par l'acte « Prise de sang » (server/procedures.lua) et par l'ancien prélèvement simple.
function Lab.CreateSample(src, t, action)
    if not Lab.ready then return nil, 'Le laboratoire démarre, réessayez dans un instant.' end
    local cid = P.Cid(t)
    if not cid then return nil, 'Patient introuvable.' end
    if Lab.lastSample[cid] and os.time() - Lab.lastSample[cid] < (L.sampleCooldown or 60) then return nil, 'Un prélèvement vient déjà d\'être fait sur ce patient.' end
    Lab.lastSample[cid] = os.time()
    local now = os.time()
    local who = P.Name(src)
    local history = { { at = now, by = who, action = action or 'Prélèvement sanguin effectué' } }
    local id = MySQL.insert.await([[INSERT INTO `ems_lab_samples` (`citizenid`, `patient_name`, `job`, `sampled_by_cid`, `sampled_by_name`, `sampled_at`, `status`, `history`)
        VALUES (?, ?, ?, ?, ?, ?, 'pending', ?)]], { cid, P.Name(t), P.MyJob(src), P.Cid(src), who, now, json.encode(history) })
    if not id then Lab.lastSample[cid] = nil return nil, 'Prélèvement non enregistré.' end
    return id
end

-- Prélèvement simple (sans mini-jeu) : seulement si l'acte « Prise de sang » est désactivé
P.Actions.labSample = { perm = 'lab_sample', duty = true, fn = function(src, d)
    if P.ProcEnabled and P.ProcEnabled('blood') then return { error = 'Utilisez l\'acte « Prise de sang » (Actes et examens).' } end
    local t = tonumber(d.target)
    if not t or t == src or not GetPlayerName(t) or not P.GetPlayer(t) then return { error = 'Patient introuvable.' } end
    if P.Dist(src, t) > (L.sampleDistance or 3.0) + 1.0 then return { error = 'Le patient est trop loin.' } end
    local id, err = Lab.CreateSample(src, t)
    if not id then return { error = err } end
    if P.AddTreatment then P.AddTreatment(t, 'consult', src) end
    P.Notify(t, 'Un prélèvement sanguin vient de vous être fait.', 'inform')
    return { message = ('Prélèvement LAB-%05d enregistré. Analyse depuis la tablette › Laboratoire.'):format(id), id = id }
end }

P.Actions.labList = { perm = 'lab_view', fn = function(_, d)
    local q = P.Clean(d.q, 60):gsub('[%%_]', '')
    local rows
    if d.cid and d.cid ~= '' then
        rows = MySQL.query.await('SELECT * FROM `ems_lab_samples` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 60', { tostring(d.cid):sub(1, 50) })
    elseif q ~= '' then
        rows = MySQL.query.await('SELECT * FROM `ems_lab_samples` WHERE `patient_name` LIKE ? ORDER BY `id` DESC LIMIT 60', { '%' .. q .. '%' })
    else
        rows = MySQL.query.await('SELECT * FROM `ems_lab_samples` ORDER BY (`status` = \'pending\') DESC, `id` DESC LIMIT 60')
    end
    local out = {}
    for _, r in ipairs(rows or {}) do out[#out + 1] = view(r, false) end
    return { list = out }
end }

P.Actions.labReport = { perm = 'lab_view', fn = function(src, d)
    local row = MySQL.single.await('SELECT * FROM `ems_lab_samples` WHERE `id` = ?', { tonumber(d.id) or 0 })
    if not row then return { error = 'Analyse introuvable.' } end
    local v = view(row, true)
    -- autres analyses du même patient (historique)
    local others = MySQL.query.await('SELECT * FROM `ems_lab_samples` WHERE `citizenid` = ? AND `id` <> ? ORDER BY `id` DESC LIMIT 15', { row.citizenid, row.id }) or {}
    v.previous = {}
    for _, r in ipairs(others) do v.previous[#v.previous + 1] = view(r, false) end
    v.canAnalyze = row.status == 'pending' and P.Can(src, 'lab_analyze')
    v.config = { thresholds = L.alcohol.thresholds }
    return { report = v }
end }

-- Analyse : calculée une seule fois par le serveur, puis figée dans le rapport
P.Actions.labAnalyze = { perm = 'lab_analyze', duty = true, fn = function(src, d)
    local row = MySQL.single.await('SELECT * FROM `ems_lab_samples` WHERE `id` = ?', { tonumber(d.id) or 0 })
    if not row then return { error = 'Prélèvement introuvable.' } end
    if row.status ~= 'pending' then return { error = 'Ce prélèvement a déjà été analysé.' } end
    local now = os.time()
    local results = compute(row.citizenid, tonumber(row.sampled_at))
    results.simulated = true
    local history = decode(row.history, {})
    history[#history + 1] = { at = now, by = P.Name(src), action = 'Analyse sanguine réalisée (alcool et substances)' }
    local changed = MySQL.update.await([[UPDATE `ems_lab_samples` SET `status` = 'done', `analyzed_by_cid` = ?, `analyzed_by_name` = ?, `analyzed_at` = ?, `results` = ?, `history` = ?
        WHERE `id` = ? AND `status` = 'pending']], { P.Cid(src), P.Name(src), now, json.encode(results), json.encode(history), row.id })
    if not changed or changed == 0 then return { error = 'Ce prélèvement a déjà été analysé.' } end
    return { message = ('Analyse LAB-%05d terminée.'):format(row.id) }
end }

-- Annuler un prélèvement non analysé (erreur de patient…) : direction ou médecin responsable
P.Actions.labCancel = { perm = 'lab_analyze', fn = function(src, d)
    local row = MySQL.single.await('SELECT `id`, `status`, `history` FROM `ems_lab_samples` WHERE `id` = ?', { tonumber(d.id) or 0 })
    if not row or row.status ~= 'pending' then return { error = 'Seul un prélèvement en attente peut être annulé.' } end
    local history = decode(row.history, {})
    history[#history + 1] = { at = os.time(), by = P.Name(src), action = 'Prélèvement annulé' .. (P.Clean(d.reason, 120) ~= '' and (' : ' .. P.Clean(d.reason, 120)) or '') }
    MySQL.update.await('UPDATE `ems_lab_samples` SET `status` = \'cancelled\', `history` = ? WHERE `id` = ?', { json.encode(history), row.id })
    return { message = 'Prélèvement annulé.' }
end }
