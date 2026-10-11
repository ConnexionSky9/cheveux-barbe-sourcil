-- =====================================================================
--  elyzea_police - serveur : POLICE SCIENTIFIQUE
--  Preuves réelles uniquement :
--   · douille : créée quand un joueur tire avec une arme de son inventaire. Le serveur relève
--     lui-même l'arme en main et son numéro de série (le client n'envoie qu'une position) ;
--   · sang : créée quand un joueur est blessé (profil ADN fictif du personnage) ;
--   · arme saisie : mise sous scellé depuis l'inventaire d'un agent.
--  Chaîne de conservation : chaque étape est journalisée (police_evidence_log).
--  Analyses : durée réelle gérée par le serveur ; résultat et rapport figés à la fin de l'analyse.
-- =====================================================================
local P = Police
local F = Config.Forensics or {}
local core = exports.elyzea_core
local inv = function() return exports.elyzea_inventory end

Forensics = { scene = {}, dna = {}, ready = false }
local Fx = Forensics

local TYPE_LABEL = { casing = 'Douille', blood = 'Trace de sang', weapon = 'Arme saisie' }
local STATUS_LABEL = {
    scene = 'Sur la scène', collected = 'Collectée (transport)', reception = 'Réception du laboratoire', lab = 'Au laboratoire',
    stored = 'Salle des scellés', returned = 'Restituée', destroyed = 'Détruite', invalid = 'Dégradée (non collectée)',
}
local ANALYSIS_LABEL = { ballistic = 'Balistique', dna = 'ADN', prints = 'Empreintes digitales' }
local ANALYSES_FOR = { casing = { 'ballistic' }, blood = { 'dna' }, weapon = { 'ballistic', 'prints' } }
Fx.TYPE_LABEL, Fx.STATUS_LABEL, Fx.ANALYSIS_LABEL, Fx.ANALYSES_FOR = TYPE_LABEL, STATUS_LABEL, ANALYSIS_LABEL, ANALYSES_FOR

-- ---------------------------------------------------------------------
-- Base de données
-- ---------------------------------------------------------------------
local function InitDb()
    -- Chaque table est créée séparément : une erreur n'empêche pas les autres d'exister
    local function q(sql)
        local ok, err = pcall(MySQL.query.await, sql)
        if not ok then print(('^1[Police] Table de la police scientifique non créée : %s^0'):format(tostring(err))) end
    end
    q([[CREATE TABLE IF NOT EXISTS `police_evidence` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `code` VARCHAR(20) NULL UNIQUE,
        `type` VARCHAR(20) NOT NULL,
        `status` VARCHAR(20) NOT NULL DEFAULT 'scene',
        `location` VARCHAR(80) NULL,
        `x` FLOAT NOT NULL DEFAULT 0, `y` FLOAT NOT NULL DEFAULT 0, `z` FLOAT NOT NULL DEFAULT 0,
        `street` VARCHAR(120) NULL,
        `ref` VARCHAR(40) NULL,
        `data` LONGTEXT NULL,
        `case_id` INT NULL,
        `holder` VARCHAR(100) NULL, `holder_cid` VARCHAR(50) NULL,
        `collected_by` VARCHAR(100) NULL, `collected_cid` VARCHAR(50) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `collected_at` TIMESTAMP NULL,
        INDEX (`status`), INDEX (`ref`), INDEX (`case_id`)) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    q([[CREATE TABLE IF NOT EXISTS `police_evidence_log` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `evidence_id` INT NOT NULL,
        `action` VARCHAR(40) NOT NULL,
        `actor` VARCHAR(100) NULL, `actor_cid` VARCHAR(50) NULL,
        `details` VARCHAR(255) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`evidence_id`)) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    q([[CREATE TABLE IF NOT EXISTS `police_cases` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `code` VARCHAR(20) NULL UNIQUE,
        `title` VARCHAR(120) NOT NULL,
        `description` TEXT NULL,
        `status` VARCHAR(20) NOT NULL DEFAULT 'open',
        `created_by` VARCHAR(100) NULL, `created_cid` VARCHAR(50) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    q([[CREATE TABLE IF NOT EXISTS `police_case_notes` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `case_id` INT NOT NULL,
        `kind` VARCHAR(20) NOT NULL DEFAULT 'note',
        `author` VARCHAR(100) NULL, `author_cid` VARCHAR(50) NULL,
        `text` TEXT NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`case_id`)) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    q([[CREATE TABLE IF NOT EXISTS `police_analyses` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `evidence_id` INT NOT NULL,
        `kind` VARCHAR(20) NOT NULL,
        `status` VARCHAR(20) NOT NULL DEFAULT 'running',
        `technician` VARCHAR(100) NULL, `technician_cid` VARCHAR(50) NULL,
        `started_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `ends_at` DATETIME NULL,
        `result` LONGTEXT NULL,
        INDEX (`evidence_id`), INDEX (`status`)) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    q([[CREATE TABLE IF NOT EXISTS `police_reports` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `code` VARCHAR(20) NULL UNIQUE,
        `analysis_id` INT NOT NULL UNIQUE,
        `evidence_id` INT NOT NULL,
        `case_id` INT NULL,
        `kind` VARCHAR(20) NOT NULL,
        `technician` VARCHAR(100) NULL, `technician_cid` VARCHAR(50) NULL,
        `data` LONGTEXT NOT NULL,
        `conclusion` TEXT NULL,
        `status` VARCHAR(20) NOT NULL DEFAULT 'draft',
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `finalized_at` TIMESTAMP NULL,
        INDEX (`evidence_id`), INDEX (`case_id`)) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    q([[CREATE TABLE IF NOT EXISTS `police_dna` (
        `citizenid` VARCHAR(50) NOT NULL PRIMARY KEY,
        `profile` VARCHAR(20) NOT NULL UNIQUE) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    pcall(function() core:ToUtf8mb4({ 'police_evidence', 'police_evidence_log', 'police_cases', 'police_case_notes', 'police_analyses', 'police_reports', 'police_dna' }) end)
end

-- ---------------------------------------------------------------------
-- Utilitaires
-- ---------------------------------------------------------------------
function Fx.Code(prefix, id) return ('%s-%06d'):format(prefix, tonumber(id) or 0) end

function Fx.Log(evId, action, src, details)
    local actor, cid
    if type(src) == 'number' and src > 0 then actor, cid = P.Name(src), P.Cid(src) elseif type(src) == 'string' then actor = src end
    MySQL.insert('INSERT INTO `police_evidence_log` (`evidence_id`, `action`, `actor`, `actor_cid`, `details`) VALUES (?, ?, ?, ?, ?)',
        { evId, action, actor, cid, details and tostring(details):sub(1, 255) or nil })
end

local function Clean(s, max) return tostring(s or ''):gsub('[<>]', ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, max or 120) end
Fx.Clean = Clean

local function PedPos(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    return GetEntityCoords(ped)
end

-- Position envoyée par le client, acceptée seulement si elle est près du joueur
local function SafePos(src, x, y, z, maxDist)
    local pos = PedPos(src)
    if not pos then return nil end
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if x and y and z and #(vector3(x, y, z) - pos) <= (maxDist or 4.0) then return vector3(x, y, z) end
    return vector3(pos.x, pos.y, pos.z - 0.95)
end

-- Infos visibles par les policiers sur la scène (jamais le numéro de série ni le profil ADN)
local function Public(e)
    return { id = e.id, type = e.type, x = e.x, y = e.y, z = e.z, t = e.t, count = e.data.count or 1,
        calibre = e.type == 'casing' and e.data.calibre or nil, label = TYPE_LABEL[e.type] }
end

function Fx.LabNear(src)
    local pos = PedPos(src)
    if not pos then return false end
    for _, pt in ipairs(P.Settings.points and P.Settings.points.lab or {}) do
        if #(pos - vector3(pt.x, pt.y, pt.z)) <= (F.labDistance or 12.0) then return true end
    end
    return false
end

-- Profil ADN fictif d'un personnage (créé une fois, unique, persistant)
function Fx.DnaOf(cid)
    if not cid then return nil end
    if Fx.dna[cid] then return Fx.dna[cid] end
    local used = {}
    for _, p in pairs(Fx.dna) do used[p] = true end
    local profile
    repeat
        profile = ('ADN-%04X-%04X'):format(math.random(0, 0xFFFF), math.random(0, 0xFFFF))
    until not used[profile]
    Fx.dna[cid] = profile
    MySQL.insert('INSERT IGNORE INTO `police_dna` (`citizenid`, `profile`) VALUES (?, ?)', { cid, profile })
    return profile
end

-- ---------------------------------------------------------------------
-- Preuves sur la scène
-- ---------------------------------------------------------------------
local function Broadcast(event, ...)
    for _, src in ipairs(P.CopsOnDuty()) do TriggerClientEvent(event, src, ...) end
end

local function AddScene(kind, pos, ref, data, street)
    local id = MySQL.insert.await('INSERT INTO `police_evidence` (`type`, `status`, `location`, `x`, `y`, `z`, `street`, `ref`, `data`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { kind, 'scene', 'Scène de crime', pos.x, pos.y, pos.z, street, ref, json.encode(data) })
    if not id then return end
    local code = Fx.Code(kind == 'casing' and 'DOU' or 'SNG', id)
    MySQL.update('UPDATE `police_evidence` SET `code` = ? WHERE `id` = ?', { code, id })
    local e = { id = id, code = code, type = kind, x = pos.x, y = pos.y, z = pos.z, t = os.time(), ref = ref, data = data, street = street }
    Fx.scene[id] = e
    Fx.Log(id, 'Découverte', 'Système', ('%s laissée%s'):format(TYPE_LABEL[kind], street and (' · ' .. street) or ''))
    Broadcast('police:forensic:add', Public(e))
end

-- Même arme / même personne au même endroit récemment : on compte au lieu de créer
local function Merge(kind, ref, pos)
    local now = os.time()
    for _, e in pairs(Fx.scene) do
        if e.type == kind and e.ref == ref and now - e.t <= (kind == 'blood' and 600 or (F.mergeSeconds or 120))
            and #(vector3(e.x, e.y, e.z) - pos) <= (F.mergeDistance or 1.5) then
            e.data.count = (e.data.count or 1) + 1
            MySQL.update('UPDATE `police_evidence` SET `data` = ? WHERE `id` = ?', { json.encode(e.data), e.id })
            Broadcast('police:forensic:update', Public(e))
            return true
        end
    end
    return false
end

local lastShot, lastBlood = {}, {}

-- Le client signale un tir : le serveur vérifie l'arme réellement en main
RegisterNetEvent('police:forensic:shot', function(x, y, z, street)
    local src = source
    if not F.enabled or not F.casings or not Fx.ready then return end
    local now = GetGameTimer()
    if lastShot[src] and now - lastShot[src] < 700 then return end
    lastShot[src] = now
    if F.ignoreOnDutyPolice and P.OnDuty(src) then return end
    if GetResourceState('elyzea_inventory') ~= 'started' then return end
    local cur = inv():GetCurrentWeapon(src)
    if not cur or not cur.metadata or not cur.metadata.serial then return end
    local def = inv():Items(cur.name)
    if not def or not def.ammoname then return end
    local pos = SafePos(src, x, y, z, 4.0)
    if not pos then return end
    local serial = tostring(cur.metadata.serial)
    if Merge('casing', serial, pos) then return end
    local ammo = inv():Items(def.ammoname)
    AddScene('casing', pos, serial, {
        weapon = cur.name, label = def.label, ammo = def.ammoname, calibre = ammo and ammo.label or def.ammoname, serial = serial, count = 1,
    }, Clean(street, 120))
end)

-- Le client signale une blessure : trace de sang avec le profil ADN du personnage
RegisterNetEvent('police:forensic:blood', function(x, y, z, street)
    local src = source
    if not F.enabled or not F.blood or not Fx.ready then return end
    local now = GetGameTimer()
    if lastBlood[src] and now - lastBlood[src] < (F.bloodCooldown or 20) * 1000 then return end
    lastBlood[src] = now
    local cid = P.Cid(src)
    if not cid then return end
    local pos = SafePos(src, x, y, z, 3.0)
    if not pos then return end
    local dna = Fx.DnaOf(cid)
    if Merge('blood', dna, pos) then return end
    AddScene('blood', pos, dna, { dna = dna, count = 1 }, Clean(street, 120))
end)

-- Preuves proches (policiers en service)
local lastNearby = {}
RegisterNetEvent('police:forensic:nearby', function()
    local src = source
    if not P.OnDuty(src) then return end
    local now = GetGameTimer()
    if lastNearby[src] and now - lastNearby[src] < 1500 then return end
    lastNearby[src] = now
    local pos = PedPos(src)
    if not pos then return end
    local out, range = {}, (F.visibleDistance or 25.0) * 2
    for _, e in pairs(Fx.scene) do
        if #(vector3(e.x, e.y, e.z) - pos) <= range then out[#out + 1] = Public(e) end
    end
    TriggerClientEvent('police:forensic:nearby', src, out)
end)

-- ---------------------------------------------------------------------
-- Collecte (ALT) : un sachet vide → un sachet scellé avec le numéro de la preuve
-- ---------------------------------------------------------------------
local collecting = {}
RegisterNetEvent('police:forensic:collect', function(id)
    local src = source
    id = tonumber(id)
    local e = id and Fx.scene[id]
    if not e then return P.Notify(src, 'Cette preuve n\'est plus sur la scène.', 'error') end
    if not P.Can(src, 'sci_collect') then return P.Notify(src, 'Prélèvement réservé à la police scientifique (en service).', 'error') end
    if collecting[id] then return end
    local pos = PedPos(src)
    if not pos or #(pos - vector3(e.x, e.y, e.z)) > (F.collectDistance or 2.5) + 0.5 then return P.Notify(src, 'Approchez-vous de la preuve.', 'error') end
    if (tonumber(inv():Search(src, 'count', 'empty_evidence_bag')) or 0) < 1 then
        return P.Notify(src, 'Il vous faut un sachet de preuve vide (armurerie de la police).', 'error')
    end
    local meta = { evidence = e.id, code = e.code, kind = e.type, label = ('Scellé %s'):format(e.code),
        description = ('%s · %s%s'):format(TYPE_LABEL[e.type], os.date('%d/%m %H:%M'), e.street and (' · ' .. e.street) or '') }
    if not inv():CanCarryItem(src, 'filled_evidence_bag', 1, meta) then return P.Notify(src, 'Inventaire plein.', 'error') end
    collecting[id] = true
    -- Passage scène → collectée : une seule fois (impossible à dupliquer)
    local n = MySQL.update.await([[UPDATE `police_evidence` SET `status` = 'collected', `location` = 'Transport', `collected_by` = ?, `collected_cid` = ?,
        `holder` = ?, `holder_cid` = ?, `collected_at` = NOW() WHERE `id` = ? AND `status` = 'scene']], { P.Name(src), P.Cid(src), P.Name(src), P.Cid(src), e.id })
    if not n or n < 1 then
        collecting[id] = nil
        Fx.scene[id] = nil
        Broadcast('police:forensic:remove', id)
        return P.Notify(src, 'Cette preuve a déjà été collectée.', 'error')
    end
    Fx.scene[id] = nil
    Broadcast('police:forensic:remove', id)
    inv():RemoveItem(src, 'empty_evidence_bag', 1)
    if not inv():AddItem(src, 'filled_evidence_bag', 1, meta) then
        -- Ne devrait pas arriver (vérifié avant) : la preuve reste collectée, à réceptionner depuis la tablette
        P.Notify(src, 'Le sachet n\'a pas pu être rangé : la preuve est à réceptionner au laboratoire.', 'error')
    end
    collecting[id] = nil
    Fx.Log(e.id, 'Collecte', src, ('%s · %s'):format(e.code, e.street or 'position relevée'))
    P.Notify(src, ('Preuve %s placée sous scellé.'):format(e.code), 'success')
    P.Log(src, 'Preuve collectée', e.code)
end)

-- ---------------------------------------------------------------------
-- Réception au laboratoire : les sachets scellés de l'agent
-- ---------------------------------------------------------------------
function Fx.ReceiveAll(src)
    if not (P.Can(src, 'sci_lab') or P.Can(src, 'sci_collect')) then return { error = 'Réservé à la police scientifique (en service).' } end
    if not Fx.LabNear(src) then return { error = 'Rendez-vous au laboratoire pour réceptionner les preuves.' } end
    local items = inv():GetInventoryItems(src) or {}
    local done = {}
    for _, it in pairs(items) do
        local evId = it and it.name == 'filled_evidence_bag' and it.metadata and tonumber(it.metadata.evidence)
        if evId then
            local row = MySQL.single.await('SELECT `id`, `code`, `status`, `collected_cid`, `collected_by` FROM `police_evidence` WHERE `id` = ?', { evId })
            if row and row.status == 'collected' and inv():RemoveItem(src, 'filled_evidence_bag', 1, nil, it.slot) then
                MySQL.update.await([[UPDATE `police_evidence` SET `status` = 'reception', `location` = 'Réception du laboratoire', `holder` = ?, `holder_cid` = ? WHERE `id` = ?]],
                    { 'Laboratoire', nil, row.id })
                if row.collected_cid and row.collected_cid ~= P.Cid(src) then
                    Fx.Log(row.id, 'Transfert de responsabilité', src, ('Collectée par %s, remise par %s'):format(row.collected_by or '?', P.Name(src)))
                end
                Fx.Log(row.id, 'Réception au laboratoire', src, row.code)
                done[#done + 1] = row.code
            elseif row and row.status ~= 'collected' then
                -- Sachet d'une preuve déjà traitée : invalide, retiré (aucune réapparition possible)
                inv():RemoveItem(src, 'filled_evidence_bag', 1, nil, it.slot)
                Fx.Log(row.id, 'Sachet invalide retiré', src, ('Statut déjà : %s'):format(STATUS_LABEL[row.status] or row.status))
            end
        end
    end
    if #done == 0 then return { error = 'Aucun sachet scellé à réceptionner dans votre inventaire.' } end
    P.Log(src, 'Preuves réceptionnées', table.concat(done, ', '))
    return { ok = true, message = ('%d preuve(s) réceptionnée(s) : %s.'):format(#done, table.concat(done, ', ')) }
end

RegisterNetEvent('police:forensic:receive', function()
    local src = source
    local r = Fx.ReceiveAll(src)
    P.Notify(src, r.error or r.message, r.error and 'error' or 'success')
end)

-- ---------------------------------------------------------------------
-- Arme saisie : mise sous scellé depuis l'inventaire de l'agent
-- ---------------------------------------------------------------------
function Fx.MyWeapons(src)
    local out = {}
    for _, it in pairs(inv():GetInventoryItems(src) or {}) do
        local def = it and inv():Items(it.name)
        if def and def.kind == 'weapon' and it.metadata and it.metadata.serial then
            out[#out + 1] = { slot = it.slot, name = it.name, label = def.label, serial = it.metadata.serial, engraving = it.metadata.engraving }
        end
    end
    table.sort(out, function(a, b) return a.slot < b.slot end)
    return out
end

function Fx.SeizeWeapon(src, slot, caseId)
    slot = tonumber(slot)
    local it = slot and inv():GetSlot(src, slot)
    local def = it and inv():Items(it.name)
    if not def or def.kind ~= 'weapon' or not it.metadata or not it.metadata.serial then return { error = 'Arme introuvable dans votre inventaire.' } end
    local serial = tostring(it.metadata.serial)
    local open = MySQL.scalar.await([[SELECT `id` FROM `police_evidence` WHERE `type` = 'weapon' AND `ref` = ? AND `status` NOT IN ('returned','destroyed','invalid')]], { serial })
    if open then return { error = 'Cette arme est déjà sous scellé.' } end
    local meta = { evidence = 0, kind = 'weapon' }
    if not inv():CanCarryItem(src, 'filled_evidence_bag', 1, meta) then return { error = 'Inventaire plein (il faut une place pour le sachet).' } end
    local itemMeta = it.metadata
    if not inv():RemoveItem(src, it.name, 1, nil, slot) then return { error = 'Impossible de retirer l\'arme.' } end
    local pos = PedPos(src) or vector3(0, 0, 0)
    local data = { weapon = it.name, label = def.label, ammo = def.ammoname, serial = serial, engraving = itemMeta.engraving, item = { name = it.name, metadata = itemMeta } }
    local id = MySQL.insert.await([[INSERT INTO `police_evidence` (`type`, `status`, `location`, `x`, `y`, `z`, `ref`, `data`, `case_id`, `holder`, `holder_cid`, `collected_by`, `collected_cid`, `collected_at`)
        VALUES ('weapon', 'collected', 'Transport', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())]],
        { pos.x, pos.y, pos.z, serial, json.encode(data), tonumber(caseId), P.Name(src), P.Cid(src), P.Name(src), P.Cid(src) })
    local code = Fx.Code('ARM', id)
    MySQL.update.await('UPDATE `police_evidence` SET `code` = ? WHERE `id` = ?', { code, id })
    inv():AddItem(src, 'filled_evidence_bag', 1, { evidence = id, code = code, kind = 'weapon', label = ('Scellé %s'):format(code),
        description = ('Arme saisie · %s · n° %s'):format(def.label, serial) })
    pcall(function() inv():SetWeaponStatus(serial, 'seized', P.Name(src), code) end)
    Fx.Log(id, 'Saisie', src, ('%s · n° %s'):format(def.label, serial))
    P.Log(src, 'Arme saisie', ('%s · %s'):format(code, serial))
    return { ok = true, message = ('%s mise sous scellé (%s). Déposez le sachet au laboratoire.'):format(def.label, code) }
end

-- ---------------------------------------------------------------------
-- Dégradation des preuves non collectées
-- ---------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(5 * 60000)
        local limit = os.time() - (F.sceneLifetimeHours or 24) * 3600
        for id, e in pairs(Fx.scene) do
            if e.t < limit then
                Fx.scene[id] = nil
                MySQL.update('UPDATE `police_evidence` SET `status` = \'invalid\', `location` = NULL WHERE `id` = ? AND `status` = \'scene\'', { id })
                Fx.Log(id, 'Dégradée', 'Système', 'Non collectée à temps')
                Broadcast('police:forensic:remove', id)
            end
        end
    end
end)

CreateThread(function()
    local ok, err = pcall(function()
        InitDb()
        for _, r in ipairs(MySQL.query.await('SELECT `citizenid`, `profile` FROM `police_dna`') or {}) do Fx.dna[r.citizenid] = r.profile end
        for _, r in ipairs(MySQL.query.await([[SELECT `id`, `code`, `type`, `x`, `y`, `z`, `street`, `ref`, `data`, UNIX_TIMESTAMP(`created_at`) AS t
            FROM `police_evidence` WHERE `status` = 'scene']]) or {}) do
            Fx.scene[r.id] = { id = r.id, code = r.code, type = r.type, x = r.x, y = r.y, z = r.z, street = r.street, ref = r.ref, t = tonumber(r.t) or os.time(),
                data = json.decode(r.data or '{}') or {} }
        end
    end)
    if not ok then print(('^1[Police] Police scientifique indisponible (base de données) : %s^0'):format(tostring(err))) return end
    Fx.ready = true
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastShot[src], lastBlood[src], lastNearby[src] = nil, nil, nil
end)
