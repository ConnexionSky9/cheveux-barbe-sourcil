-- =====================================================================
--  JEWELRY HEIST - serveur : socle
--  · Tables : jh_settings (réglages), jh_bags (sacs et leur contenu), jh_logs (journal)
--  · Journal (braquages, sacs, ventes, staff, anomalies)
--  · Limite de fréquence par joueur, verrous, dispatcher des requêtes client
--  Le client n'envoie jamais de montant, de prix ni de contenu : uniquement des identifiants.
-- =====================================================================
JHS = { S = nil, Req = {}, uid = 0 }
local P = JHS

local TABLES = {
    jh_settings = [[(`k` VARCHAR(32) NOT NULL PRIMARY KEY, `v` LONGTEXT NULL)]],
    jh_bags = [[(`id` VARCHAR(24) NOT NULL PRIMARY KEY, `shop_id` VARCHAR(32) NULL, `owner_cid` VARCHAR(64) NULL, `owner_name` VARCHAR(100) NULL,
        `holder_cid` VARCHAR(64) NULL, `state` VARCHAR(12) NOT NULL DEFAULT 'ground', `x` DOUBLE NOT NULL DEFAULT 0, `y` DOUBLE NOT NULL DEFAULT 0, `z` DOUBLE NOT NULL DEFAULT 0,
        `money` INT NOT NULL DEFAULT 0, `money_type` VARCHAR(8) NOT NULL DEFAULT 'cash', `gems` LONGTEXT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP)]],
    jh_logs = [[(`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `kind` VARCHAR(16) NOT NULL, `ref` VARCHAR(32) NULL, `cid` VARCHAR(64) NULL, `name` VARCHAR(100) NULL,
        `details` TEXT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, INDEX (`kind`), INDEX (`created_at`))]],
}

function P.InstallDB()
    for name, def in pairs(TABLES) do
        local ok, err = pcall(MySQL.query.await, ('CREATE TABLE IF NOT EXISTS `%s` %s DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'):format(name, def))
        if not ok then print(('^1[JEWELRY] Table %s : %s^0'):format(name, tostring(err))) end
    end
    -- Sacs de billets (bank_heist) : type et capacité. Erreur « colonne déjà présente » ignorée.
    pcall(MySQL.query.await, "ALTER TABLE `jh_bags` ADD COLUMN IF NOT EXISTS `kind` VARCHAR(12) NOT NULL DEFAULT 'jewel'")
    pcall(MySQL.query.await, 'ALTER TABLE `jh_bags` ADD COLUMN IF NOT EXISTS `capacity` INT NULL')
end

-- ---------------------------------------------------------------------
-- Identifiants uniques (missions, sacs, ventes)
-- ---------------------------------------------------------------------
function P.Uid(prefix)
    P.uid = (P.uid + 1) % 1000
    return ('%s%s%03d%02d'):format(prefix, os.date('%y%m%d%H%M%S'), P.uid, math.random(0, 99))
end

-- ---------------------------------------------------------------------
-- Journal
-- ---------------------------------------------------------------------
function P.Log(kind, ref, src, details)
    local cid, name = nil, nil
    if src and src > 0 then cid, name = Adapters.Perms.CitizenId(src), Adapters.Perms.Name(src) end
    MySQL.insert('INSERT INTO `jh_logs` (`kind`, `ref`, `cid`, `name`, `details`) VALUES (?, ?, ?, ?, ?)',
        { kind, ref and tostring(ref):sub(1, 32) or nil, cid, name, tostring(details or ''):sub(1, 2000) })
    if kind == 'anomaly' then print(('^3[JEWELRY] Anomalie (%s) : %s · %s^0'):format(tostring(name or src), tostring(ref), tostring(details))) end
end

-- ---------------------------------------------------------------------
-- Limite de fréquence (par joueur) et verrous
-- ---------------------------------------------------------------------
local hits = {}
function P.RateOk(src)
    local now = GetGameTimer()
    local h = hits[src]
    if not h or now - h.t > 3000 then hits[src] = { t = now, n = 1 } return true end
    h.n = h.n + 1
    if h.n > (P.S.security.rateLimit or 6) then
        if h.n == (P.S.security.rateLimit or 6) + 1 then P.Log('anomaly', 'rate', src, 'Trop de requêtes en 3 s') end
        return false
    end
    return true
end

local locks = {}
function P.Lock(key) if locks[key] then return false end locks[key] = true return true end
function P.Unlock(key) locks[key] = nil end

-- Position réelle du joueur (lue par le serveur, jamais envoyée par le client)
function P.PedPos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped), GetEntityHeading(ped)
end
function P.Near(src, x, y, z, dist)
    local pos = P.PedPos(src)
    if not pos then return false end
    return #(pos - vector3(x + 0.0, y + 0.0, z + 0.0)) <= (dist + 0.5)
end

function P.IsDown(src)
    if Player(src).state.emsDown then return true end
    local ped = GetPlayerPed(src)
    return ped and ped ~= 0 and GetEntityHealth(ped) <= 0
end

function P.Notify(src, key, kind, ...) Adapters.Notify.Send(src, JH.T(key, ...), kind) end

-- ---------------------------------------------------------------------
-- Dispatcher des requêtes client : Ely.callback 'jh:req' (action, données)
-- Chaque action : P.Req.<nom> = function(src, data) return { ... } end
-- ---------------------------------------------------------------------
Ely.callback.register('jh:req', function(src, action, data)
    local def = P.Req[tostring(action or '')]
    if not def then return { error = 'Action inconnue.' } end
    if not P.RateOk(src) then return { error = JH.T('busy') } end
    if type(data) ~= 'table' then data = {} end
    local ok, res = pcall(def, src, data)
    if not ok then
        print(('^1[JEWELRY] Erreur %s : %s^0'):format(tostring(action), tostring(res)))
        return { error = 'Erreur serveur.' }
    end
    return type(res) == 'table' and res or {}
end)

AddEventHandler('playerDropped', function() hits[source] = nil end)

-- Démarrage : tables, réglages, sacs enregistrés
CreateThread(function()
    P.InstallDB()
    P.LoadSettings()
    P.LoadBags()
    local days = math.max(1, tonumber(P.S.security.logRetentionDays) or 30)
    MySQL.query('DELETE FROM `jh_logs` WHERE `created_at` < (NOW() - INTERVAL ? DAY)', { days })
    print('^2[JEWELRY] Braquage de bijouterie prêt.^0')
end)
