-- =====================================================================
--  ELYZEA LASERGAME : tables MySQL / MariaDB
--  FACULTATIF : la ressource crée elle-même ces tables au démarrage.
--  Ce fichier sert à les créer à la main (phpMyAdmin › Importer) si tu préfères.
--  Généré depuis server/database.lua (même contenu).
-- =====================================================================

CREATE TABLE IF NOT EXISTS `lg_players` (
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
    ) DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lg_matches` (
    `uid` VARCHAR(24) NOT NULL PRIMARY KEY, `mode` VARCHAR(8) NOT NULL, `name` VARCHAR(40) NOT NULL DEFAULT '',
    `map` VARCHAR(32) NOT NULL, `format` VARCHAR(8) NULL, `status` VARCHAR(12) NOT NULL DEFAULT 'running',
    `score_a` INT NOT NULL DEFAULT 0, `score_b` INT NOT NULL DEFAULT 0, `winner` CHAR(1) NULL,
    `round` INT NOT NULL DEFAULT 0, `pot` BIGINT NOT NULL DEFAULT 0, `ranked` TINYINT(1) NOT NULL DEFAULT 0,
    `data` LONGTEXT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, `ended_at` TIMESTAMP NULL DEFAULT NULL,
    INDEX `mode_created` (`mode`, `created_at`)
    ) DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lg_match_players` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `match_uid` VARCHAR(24) NOT NULL, `citizenid` VARCHAR(64) NOT NULL,
    `mode` VARCHAR(8) NOT NULL, `team` CHAR(1) NULL, `result` VARCHAR(8) NOT NULL,
    `kills` INT NOT NULL DEFAULT 0, `deaths` INT NOT NULL DEFAULT 0, `points_delta` INT NOT NULL DEFAULT 0,
    `payout` BIGINT NOT NULL DEFAULT 0, `round` INT NOT NULL DEFAULT 0, `opp_sig` VARCHAR(64) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX `cid_created` (`citizenid`, `created_at`), INDEX `match_uid` (`match_uid`), INDEX `opp` (`citizenid`, `opp_sig`, `created_at`)
    ) DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lg_ledger` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `match_uid` VARCHAR(24) NOT NULL, `citizenid` VARCHAR(64) NOT NULL,
    `name` VARCHAR(80) NOT NULL DEFAULT '', `team` CHAR(1) NULL, `amount` BIGINT NOT NULL, `account` VARCHAR(10) NOT NULL DEFAULT 'bank',
    `status` VARCHAR(10) NOT NULL DEFAULT 'held', `payout` BIGINT NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, `settled_at` TIMESTAMP NULL DEFAULT NULL,
    INDEX `match_uid` (`match_uid`), INDEX `status` (`status`), INDEX `cid` (`citizenid`)
    ) DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lg_pending` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `citizenid` VARCHAR(64) NOT NULL, `amount` BIGINT NOT NULL,
    `account` VARCHAR(10) NOT NULL DEFAULT 'bank', `reason` VARCHAR(120) NOT NULL DEFAULT '',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, INDEX `cid` (`citizenid`)
    ) DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lg_restore` (
    `citizenid` VARCHAR(64) NOT NULL PRIMARY KEY, `match_uid` VARCHAR(24) NOT NULL, `data` TEXT NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    ) DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lg_logs` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `category` VARCHAR(12) NOT NULL, `citizenid` VARCHAR(64) NULL,
    `name` VARCHAR(80) NULL, `message` VARCHAR(255) NOT NULL, `data` TEXT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, INDEX `cat_created` (`category`, `created_at`)
    ) DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lg_arenas` (
    `id` VARCHAR(32) NOT NULL PRIMARY KEY, `label` VARCHAR(40) NOT NULL DEFAULT '', `enabled` TINYINT(1) NOT NULL DEFAULT 0,
    `data` LONGTEXT NOT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lg_settings` (
    `k` VARCHAR(40) NOT NULL PRIMARY KEY, `v` LONGTEXT NOT NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) DEFAULT CHARSET=utf8mb4;


-- Appli « LaserGame » du téléphone (elyzea_aura) : demandes de match, annonces, inscriptions, messages
CREATE TABLE IF NOT EXISTS `lg_phone_posts` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `kind` VARCHAR(8) NOT NULL, `citizenid` VARCHAR(64) NOT NULL,
    `name` VARCHAR(80) NOT NULL DEFAULT '', `mode` VARCHAR(8) NOT NULL, `map` VARCHAR(32) NOT NULL DEFAULT '',
    `format` VARCHAR(8) NOT NULL DEFAULT '', `stake` INT NOT NULL DEFAULT 0, `slots` INT NOT NULL DEFAULT 0,
    `starts_at` INT NOT NULL DEFAULT 0, `message` VARCHAR(200) NOT NULL DEFAULT '',
    `status` VARCHAR(10) NOT NULL DEFAULT 'open', `notified` INT NOT NULL DEFAULT 0, `created_at` INT NOT NULL DEFAULT 0,
    INDEX `status_kind` (`status`, `kind`), INDEX `cid` (`citizenid`)
    ) DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lg_phone_joins` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `post_id` INT NOT NULL, `citizenid` VARCHAR(64) NOT NULL,
    `name` VARCHAR(80) NOT NULL DEFAULT '', `created_at` INT NOT NULL DEFAULT 0,
    INDEX `post` (`post_id`), INDEX `cid` (`citizenid`)
    ) DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lg_phone_messages` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `from_cid` VARCHAR(64) NOT NULL, `from_name` VARCHAR(80) NOT NULL DEFAULT '',
    `to_cid` VARCHAR(64) NOT NULL, `to_name` VARCHAR(80) NOT NULL DEFAULT '', `post_id` INT NOT NULL DEFAULT 0,
    `body` VARCHAR(400) NOT NULL, `created_at` INT NOT NULL DEFAULT 0, `read_at` INT NOT NULL DEFAULT 0,
    INDEX `to_read` (`to_cid`, `read_at`), INDEX `pair` (`from_cid`, `to_cid`, `id`)
    ) DEFAULT CHARSET=utf8mb4;
