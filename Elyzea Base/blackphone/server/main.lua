-- =====================================================================
--  BLACKPHONE - serveur : socle
--  · Tables bp_* (créées au démarrage, voir sql/install.sql)
--  · Journal d'audit, journal des consultations police, limite de fréquence, verrous
--  · Deux points d'entrée : 'bp:phone' (téléphone) et 'bp:police' (PC portable police).
--    Chaque requête revérifie : objet possédé, profil, application activée (téléphone) ;
--    service, grade et objet (police). Le client n'envoie ni montant calculé, ni identité, ni grade.
-- =====================================================================
BPS = { S = nil, Phone = {}, Police = {}, uid = 0 }
local P = BPS

local TABLES = {
    bp_settings = [[(`k` VARCHAR(32) NOT NULL PRIMARY KEY, `v` LONGTEXT NULL)]],
    bp_devices = [[(`serial` VARCHAR(24) NOT NULL PRIMARY KEY, `owner_cid` VARCHAR(64) NULL, `state` VARCHAR(12) NOT NULL DEFAULT 'active',
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, `last_cid` VARCHAR(64) NULL, `last_used` TIMESTAMP NULL)]],
    bp_profiles = [[(`cid` VARCHAR(64) NOT NULL PRIMARY KEY, `alias` VARCHAR(24) NOT NULL UNIQUE, `rep` INT NOT NULL DEFAULT 0, `banned` TINYINT NOT NULL DEFAULT 0,
        `bio` VARCHAR(200) NULL, `alias_changed_at` INT NOT NULL DEFAULT 0, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP)]],
    bp_contacts = [[(`owner_cid` VARCHAR(64) NOT NULL, `contact_cid` VARCHAR(64) NOT NULL, `favorite` TINYINT NOT NULL DEFAULT 0, `blocked` TINYINT NOT NULL DEFAULT 0,
        `note` VARCHAR(120) NULL, `revealed` TINYINT NOT NULL DEFAULT 0, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`owner_cid`, `contact_cid`))]],
    bp_endorse = [[(`from_cid` VARCHAR(64) NOT NULL, `to_cid` VARCHAR(64) NOT NULL, `value` TINYINT NOT NULL, `day` INT NOT NULL, PRIMARY KEY (`from_cid`, `to_cid`, `day`))]],
    bp_convs = [[(`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `kind` VARCHAR(8) NOT NULL, `name` VARCHAR(40) NULL, `owner_cid` VARCHAR(64) NULL,
        `ephemeral` INT NOT NULL DEFAULT 0, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP)]],
    bp_conv_members = [[(`conv_id` INT NOT NULL, `cid` VARCHAR(64) NOT NULL, `role` VARCHAR(8) NOT NULL DEFAULT 'member', `status` VARCHAR(8) NOT NULL DEFAULT 'active',
        `last_read` INT NOT NULL DEFAULT 0, `invited_by` VARCHAR(64) NULL, PRIMARY KEY (`conv_id`, `cid`), INDEX (`cid`))]],
    bp_messages = [[(`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `conv_id` INT NOT NULL, `sender_cid` VARCHAR(64) NULL, `body` TEXT NOT NULL,
        `system` TINYINT NOT NULL DEFAULT 0, `created_at` INT NOT NULL, `expires_at` INT NULL, INDEX (`conv_id`, `id`), INDEX (`expires_at`))]],
    bp_listings = [[(`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `seller_cid` VARCHAR(64) NOT NULL, `category` VARCHAR(24) NOT NULL, `item` VARCHAR(60) NOT NULL,
        `label` VARCHAR(80) NULL, `qty` INT NOT NULL, `price` INT NOT NULL, `note` VARCHAR(200) NULL, `status` VARCHAR(10) NOT NULL DEFAULT 'active',
        `buyer_cid` VARCHAR(64) NULL, `created_at` INT NOT NULL, `expires_at` INT NOT NULL, `closed_at` INT NULL, INDEX (`status`), INDEX (`seller_cid`))]],
    bp_offers = [[(`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `listing_id` INT NOT NULL, `buyer_cid` VARCHAR(64) NOT NULL, `price` INT NOT NULL,
        `status` VARCHAR(10) NOT NULL DEFAULT 'pending', `created_at` INT NOT NULL, INDEX (`listing_id`))]],
    bp_claims = [[(`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `cid` VARCHAR(64) NOT NULL, `item` VARCHAR(60) NULL, `qty` INT NOT NULL DEFAULT 0,
        `money` INT NOT NULL DEFAULT 0, `reason` VARCHAR(160) NULL, `created_at` INT NOT NULL, `claimed_at` INT NULL, INDEX (`cid`, `claimed_at`))]],
    bp_tx = [[(`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `kind` VARCHAR(16) NOT NULL, `ref` VARCHAR(32) NULL, `from_cid` VARCHAR(64) NULL, `to_cid` VARCHAR(64) NULL,
        `item` VARCHAR(60) NULL, `qty` INT NULL, `amount` INT NOT NULL DEFAULT 0, `fee` INT NOT NULL DEFAULT 0, `created_at` INT NOT NULL, INDEX (`kind`), INDEX (`created_at`))]],
    bp_contracts = [[(`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `owner_cid` VARCHAR(64) NOT NULL, `taker_cid` VARCHAR(64) NULL, `category` VARCHAR(20) NOT NULL,
        `title` VARCHAR(80) NOT NULL, `objective` TEXT NOT NULL, `conditions` VARCHAR(300) NULL, `reward` INT NOT NULL, `deadline` INT NOT NULL,
        `status` VARCHAR(10) NOT NULL DEFAULT 'open', `paid` TINYINT NOT NULL DEFAULT 0, `created_at` INT NOT NULL, `updated_at` INT NOT NULL, INDEX (`status`))]],
    bp_contract_events = [[(`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `contract_id` INT NOT NULL, `actor_cid` VARCHAR(64) NULL, `action` VARCHAR(20) NOT NULL,
        `details` VARCHAR(300) NULL, `created_at` INT NOT NULL, INDEX (`contract_id`))]],
    bp_breach = [[(`id` VARCHAR(24) NOT NULL PRIMARY KEY, `cid` VARCHAR(64) NOT NULL, `alias` VARCHAR(24) NULL, `status` VARCHAR(10) NOT NULL, `difficulty` INT NOT NULL,
        `cost` INT NOT NULL, `started_at` INT NOT NULL, `ends_at` INT NOT NULL, `finished_at` INT NULL, `x` DOUBLE NULL, `y` DOUBLE NULL, `z` DOUBLE NULL,
        `steps_done` INT NOT NULL DEFAULT 0, `steps` INT NOT NULL DEFAULT 3, `countered_by` VARCHAR(100) NULL, INDEX (`status`), INDEX (`cid`))]],
    bp_effects = [[(`name` VARCHAR(32) NOT NULL PRIMARY KEY, `until_at` INT NOT NULL, `ref` VARCHAR(24) NULL)]],
    bp_audit = [[(`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `kind` VARCHAR(16) NOT NULL, `actor_cid` VARCHAR(64) NULL, `actor_name` VARCHAR(100) NULL,
        `ref` VARCHAR(32) NULL, `details` TEXT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, INDEX (`kind`), INDEX (`created_at`))]],
    bp_police_log = [[(`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `officer_cid` VARCHAR(64) NULL, `officer_name` VARCHAR(100) NULL, `action` VARCHAR(24) NOT NULL,
        `ref` VARCHAR(32) NULL, `details` TEXT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, INDEX (`created_at`))]],
}

local function installDB()
    for name, def in pairs(TABLES) do
        local ok, err = pcall(MySQL.query.await, ('CREATE TABLE IF NOT EXISTS `%s` %s DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'):format(name, def))
        if not ok then print(('^1[BLACKPHONE] Table %s : %s^0'):format(name, tostring(err))) end
    end
end

function P.Now() return os.time() end
function P.Uid(prefix)
    P.uid = (P.uid + 1) % 1000
    return ('%s%s%03d%02d'):format(prefix, os.date('%y%m%d%H%M%S'), P.uid, math.random(0, 99))
end

-- Journal d'audit (toutes les actions sensibles) et journal des consultations police
function P.Audit(kind, src, ref, details)
    local cid, name = nil, nil
    if src and src > 0 then cid, name = Bridge.Cid(src), Bridge.Name(src) end
    MySQL.insert('INSERT INTO `bp_audit` (`kind`, `actor_cid`, `actor_name`, `ref`, `details`) VALUES (?, ?, ?, ?, ?)',
        { kind, cid, name, ref and tostring(ref):sub(1, 32) or nil, tostring(details or ''):sub(1, 3000) })
    if kind == 'anomaly' then print(('^3[BLACKPHONE] Anomalie (%s) : %s · %s^0'):format(tostring(name or src), tostring(ref), tostring(details))) end
end
function P.PoliceLog(src, action, ref, details)
    MySQL.insert('INSERT INTO `bp_police_log` (`officer_cid`, `officer_name`, `action`, `ref`, `details`) VALUES (?, ?, ?, ?, ?)',
        { Bridge.Cid(src), Bridge.Name(src), action, ref and tostring(ref):sub(1, 32) or nil, tostring(details or ''):sub(1, 2000) })
end

-- Limite de fréquence (par joueur) et verrous (opérations concurrentes)
local hits = {}
function P.RateOk(src, max)
    local now = GetGameTimer()
    local h = hits[src]
    if not h or now - h.t > 3000 then hits[src] = { t = now, n = 1 } return true end
    h.n = h.n + 1
    if h.n > (max or 12) then
        if h.n == (max or 12) + 1 then P.Audit('anomaly', src, 'rate', 'Trop de requêtes en 3 s') end
        return false
    end
    return true
end
local locks = {}
function P.Lock(k) if locks[k] then return false end locks[k] = true return true end
function P.Unlock(k) locks[k] = nil end
-- Exécute fn sous verrou (libéré même en cas d'erreur)
function P.Locked(k, fn)
    if not P.Lock(k) then return { error = 'Opération déjà en cours, patientez.' } end
    local ok, res = pcall(fn)
    P.Unlock(k)
    if not ok then print(('^1[BLACKPHONE] %s : %s^0'):format(k, tostring(res))) return { error = 'Erreur serveur.' } end
    return res
end

function P.Str(v, max) if type(v) ~= 'string' and type(v) ~= 'number' then return '' end return (tostring(v):gsub('[<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, max or 200) end
function P.Int(v, mn, mx) v = tonumber(v) if not v or v ~= v or v == math.huge or v == -math.huge then return nil end v = math.floor(v) if (mn and v < mn) or (mx and v > mx) then return nil end return v end

-- ---------------------------------------------------------------------
-- Téléphone : possession de l'objet + profil
-- ---------------------------------------------------------------------
function P.HasPhone(src) return Bridge.Count(src, P.S.general.phoneItem) > 0 end

Ely.callback.register('bp:phone', function(src, app, action, data)
    if not P.S.general.enabled then return { error = 'Le réseau BLACKPHONE est hors ligne.' } end
    if not P.RateOk(src) then return { error = 'Trop rapide.' } end
    app, action = tostring(app or ''), tostring(action or '')
    if not P.HasPhone(src) then P.Audit('anomaly', src, 'nophone', app .. '.' .. action) return { error = 'Aucun BLACKPHONE sur vous.', closed = true } end
    local handlers = P.Phone[app]
    local fn = handlers and handlers[action]
    if not fn then return { error = 'Action inconnue.' } end
    if app ~= 'core' and app ~= 'profile' and P.S.apps[app] == false then return { error = 'Application désactivée.' } end
    local cid = Bridge.Cid(src)
    if not cid then return { error = 'Personnage introuvable.' } end
    local prof = P.Profile(cid)
    if app ~= 'core' and app ~= 'profile' then
        if not prof then return { error = 'Créez d\'abord votre pseudonyme.', needAlias = true } end
        if prof.banned then return { error = 'Accès au réseau suspendu.' } end
    end
    local ok, res = pcall(fn, src, type(data) == 'table' and data or {}, { cid = cid, profile = prof })
    if not ok then print(('^1[BLACKPHONE] %s.%s : %s^0'):format(app, action, tostring(res))) return { error = 'Erreur serveur.' } end
    return type(res) == 'table' and res or {}
end)

AddEventHandler('playerDropped', function() hits[source] = nil end)

-- Ouverture du téléphone : uniquement depuis l'objet de l'inventaire (export appelé par elyzea_inventory)
exports('useBlackphone', function(_, inv, slot)
    local src = type(inv) == 'table' and tonumber(inv.id) or tonumber(inv)
    if not src or not P.S.general.enabled then return false end
    if not P.HasPhone(src) then return false end
    local serial = P.EnsureDevice(src, slot)
    TriggerClientEvent('bp:client:open', src, { serial = serial })
    return false   -- false : l'objet n'est jamais consommé
end)

CreateThread(function()
    installDB()
    P.LoadSettings()
    if P.OnReady then for _, fn in ipairs(P.OnReady) do pcall(fn) end end
    MySQL.query('DELETE FROM `bp_audit` WHERE `created_at` < (NOW() - INTERVAL ? DAY)', { P.S.general.auditDays })
    print('^2[BLACKPHONE] Réseau prêt.^0')
end)
function P.Ready(fn) P.OnReady = P.OnReady or {} P.OnReady[#P.OnReady + 1] = fn end
