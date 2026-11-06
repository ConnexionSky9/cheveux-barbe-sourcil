-- =====================================================================
--  ELYZEA LASERGAME - BASE DE DONNÉES
--  Les tables sont créées automatiquement au démarrage (même contenu que sql/install.sql).
--  API MySQL compatible oxmysql (@elyzea_core/lib/MySQL.lua ou @oxmysql/lib/MySQL.lua).
-- =====================================================================
DB = { ready = false }

DB.Schema = {
    -- Profil LaserGame d'un personnage (statistiques PVP, rang, exclusion)
    [[CREATE TABLE IF NOT EXISTS `lg_players` (
        `citizenid` VARCHAR(64) NOT NULL PRIMARY KEY,
        `firstname` VARCHAR(40) NOT NULL DEFAULT '', `lastname` VARCHAR(40) NOT NULL DEFAULT '',
        `points` INT NOT NULL DEFAULT 1000, `peak_points` INT NOT NULL DEFAULT 1000,
        `wins` INT NOT NULL DEFAULT 0, `losses` INT NOT NULL DEFAULT 0, `draws` INT NOT NULL DEFAULT 0,
        `kills` INT NOT NULL DEFAULT 0, `deaths` INT NOT NULL DEFAULT 0, `matches` INT NOT NULL DEFAULT 0,
        `streak` INT NOT NULL DEFAULT 0, `best_streak` INT NOT NULL DEFAULT 0,
        `banned` TINYINT(1) NOT NULL DEFAULT 0, `ban_reason` VARCHAR(160) NULL, `ban_until` TIMESTAMP NULL DEFAULT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX `pts` (`points`), INDEX `wins` (`wins`)
    ) DEFAULT CHARSET=utf8mb4]],
    -- Parties PVP : historique et statistiques
    [[CREATE TABLE IF NOT EXISTS `lg_matches` (
        `uid` VARCHAR(24) NOT NULL PRIMARY KEY, `mode` VARCHAR(8) NOT NULL, `name` VARCHAR(40) NOT NULL DEFAULT '',
        `map` VARCHAR(32) NOT NULL, `format` VARCHAR(8) NULL, `status` VARCHAR(12) NOT NULL DEFAULT 'running',
        `score_a` INT NOT NULL DEFAULT 0, `score_b` INT NOT NULL DEFAULT 0, `winner` CHAR(1) NULL,
        `round` INT NOT NULL DEFAULT 0, `pot` BIGINT NOT NULL DEFAULT 0, `ranked` TINYINT(1) NOT NULL DEFAULT 0,
        `data` LONGTEXT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, `ended_at` TIMESTAMP NULL DEFAULT NULL,
        INDEX `mode_created` (`mode`, `created_at`)
    ) DEFAULT CHARSET=utf8mb4]],
    -- Participation d'un joueur à une partie (historique personnel, anti-farm)
    [[CREATE TABLE IF NOT EXISTS `lg_match_players` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `match_uid` VARCHAR(24) NOT NULL, `citizenid` VARCHAR(64) NOT NULL,
        `mode` VARCHAR(8) NOT NULL, `team` CHAR(1) NULL, `result` VARCHAR(8) NOT NULL,
        `kills` INT NOT NULL DEFAULT 0, `deaths` INT NOT NULL DEFAULT 0, `points_delta` INT NOT NULL DEFAULT 0,
        `payout` BIGINT NOT NULL DEFAULT 0, `round` INT NOT NULL DEFAULT 0, `opp_sig` VARCHAR(64) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX `cid_created` (`citizenid`, `created_at`), INDEX `match_uid` (`match_uid`), INDEX `opp` (`citizenid`, `opp_sig`, `created_at`)
    ) DEFAULT CHARSET=utf8mb4]],
    -- Mises PVP : chaque ligne est un montant réellement débité, réglé UNE SEULE FOIS (held -> paid/refunded/lost)
    [[CREATE TABLE IF NOT EXISTS `lg_ledger` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `match_uid` VARCHAR(24) NOT NULL, `citizenid` VARCHAR(64) NOT NULL,
        `name` VARCHAR(80) NOT NULL DEFAULT '', `team` CHAR(1) NULL, `amount` BIGINT NOT NULL, `account` VARCHAR(10) NOT NULL DEFAULT 'bank',
        `status` VARCHAR(10) NOT NULL DEFAULT 'held', `payout` BIGINT NOT NULL DEFAULT 0,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, `settled_at` TIMESTAMP NULL DEFAULT NULL,
        INDEX `match_uid` (`match_uid`), INDEX `status` (`status`), INDEX `cid` (`citizenid`)
    ) DEFAULT CHARSET=utf8mb4]],
    -- Gains à verser à un joueur déconnecté au moment du paiement (à sa prochaine connexion)
    [[CREATE TABLE IF NOT EXISTS `lg_pending` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `citizenid` VARCHAR(64) NOT NULL, `amount` BIGINT NOT NULL,
        `account` VARCHAR(10) NOT NULL DEFAULT 'bank', `reason` VARCHAR(120) NOT NULL DEFAULT '',
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, INDEX `cid` (`citizenid`)
    ) DEFAULT CHARSET=utf8mb4]],
    -- État RP sauvegardé à l'entrée d'une partie (rendu à la sortie, à la reconnexion, après un crash / redémarrage)
    [[CREATE TABLE IF NOT EXISTS `lg_restore` (
        `citizenid` VARCHAR(64) NOT NULL PRIMARY KEY, `match_uid` VARCHAR(24) NOT NULL, `data` TEXT NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    ) DEFAULT CHARSET=utf8mb4]],
    -- Journaux
    [[CREATE TABLE IF NOT EXISTS `lg_logs` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `category` VARCHAR(12) NOT NULL, `citizenid` VARCHAR(64) NULL,
        `name` VARCHAR(80) NULL, `message` VARCHAR(255) NOT NULL, `data` TEXT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, INDEX `cat_created` (`category`, `created_at`)
    ) DEFAULT CHARSET=utf8mb4]],
    -- Arènes créées en jeu par le staff (zone, apparitions, ambiance), en coordonnées du monde
    [[CREATE TABLE IF NOT EXISTS `lg_arenas` (
        `id` VARCHAR(32) NOT NULL PRIMARY KEY, `label` VARCHAR(40) NOT NULL DEFAULT '', `enabled` TINYINT(1) NOT NULL DEFAULT 0,
        `data` LONGTEXT NOT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) DEFAULT CHARSET=utf8mb4]],
    -- Réglages modifiés en jeu par le staff (remplacent ceux des fichiers de configuration)
    [[CREATE TABLE IF NOT EXISTS `lg_settings` (
        `k` VARCHAR(40) NOT NULL PRIMARY KEY, `v` LONGTEXT NOT NULL,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) DEFAULT CHARSET=utf8mb4]],
}

function DB.Init()
    MySQL.ready.await()
    for _, q in ipairs(DB.Schema) do MySQL.query.await(q) end
    if (Config.Logs.keepDays or 0) > 0 then
        MySQL.query.await('DELETE FROM `lg_logs` WHERE `created_at` < (NOW() - INTERVAL ? DAY)', { Config.Logs.keepDays })
    end
    DB.ready = true
end

-- ---------------------------------------------------------------- profils
local PROFILE_COLS = '`citizenid`, `firstname`, `lastname`, `points`, `peak_points`, `wins`, `losses`, `draws`, `kills`, `deaths`, `matches`, '
    .. '`streak`, `best_streak`, '
    .. '`banned`, `ban_reason`, `ban_until`'

-- Profil (créé s'il n'existe pas ; le nom RP est mis à jour à chaque lecture)
function DB.Profile(id)
    local row = MySQL.single.await('SELECT ' .. PROFILE_COLS .. ' FROM `lg_players` WHERE `citizenid` = ?', { id.cid })
    if not row then
        MySQL.insert.await('INSERT IGNORE INTO `lg_players` (`citizenid`, `firstname`, `lastname`, `points`, `peak_points`) VALUES (?, ?, ?, ?, ?)',
            { id.cid, id.firstname or '', id.lastname or '', LG.Ranking.start, LG.Ranking.start })
        row = MySQL.single.await('SELECT ' .. PROFILE_COLS .. ' FROM `lg_players` WHERE `citizenid` = ?', { id.cid })
    elseif id.firstname and (row.firstname ~= id.firstname or row.lastname ~= id.lastname) then
        MySQL.update('UPDATE `lg_players` SET `firstname` = ?, `lastname` = ? WHERE `citizenid` = ?', { id.firstname, id.lastname or '', id.cid })
        row.firstname, row.lastname = id.firstname, id.lastname or ''
    end
    return row
end

function DB.ProfileByCid(cid)
    return MySQL.single.await('SELECT ' .. PROFILE_COLS .. ' FROM `lg_players` WHERE `citizenid` = ?', { cid })
end

-- ---------------------------------------------------------------- réglages
function DB.GetSetting(k)
    local row = MySQL.single.await('SELECT `v` FROM `lg_settings` WHERE `k` = ?', { k })
    if not row then return nil end
    local ok, v = pcall(json.decode, row.v)
    return ok and v or nil
end

function DB.SetSetting(k, v)
    MySQL.query.await('INSERT INTO `lg_settings` (`k`, `v`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `v` = VALUES(`v`)', { k, json.encode(v) })
end
