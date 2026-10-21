-- =====================================================================
--  ELYZEA LABS : tables SQL
--  Facultatif : la ressource crée ces tables toute seule au démarrage (server/main.lua).
--  Aucune donnée n'est supprimée lors d'une mise à jour (CREATE TABLE IF NOT EXISTS).
--  Le coffre d'un laboratoire est gardé par elyzea_inventory (table `elyzea_stashes`, id « lab_<id> »).
-- =====================================================================

-- Laboratoires : l'identifiant, le niveau, l'expérience et les améliorations appartiennent au laboratoire
CREATE TABLE IF NOT EXISTS `labs` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(60) NOT NULL,
    `interior` VARCHAR(30) NOT NULL DEFAULT 'bunker',
    `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL, `h` DOUBLE NOT NULL DEFAULT 0,
    `price` INT NOT NULL DEFAULT 0,
    `owner_group` INT NULL,                       -- groupe d'elyzea_illegal (illegal_groups.id)
    `owner_since` TIMESTAMP NULL,
    `level` INT NOT NULL DEFAULT 1,
    `xp` INT NOT NULL DEFAULT 0,
    `code_hash` CHAR(64) NULL,                    -- SHA-256(sel .. code) : le code n'est jamais gardé en clair
    `code_salt` VARCHAR(32) NULL,
    `perms` LONGTEXT NULL,                        -- droits par grade (JSON)
    `upgrades` LONGTEXT NULL,                     -- historique des améliorations achetées (JSON)
    `disabled` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX `owner` (`owner_group`)
) DEFAULT CHARSET=utf8mb4;

-- Équipements achetés (placés ou rangés), liés au laboratoire
CREATE TABLE IF NOT EXISTS `labs_equipment` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `lab_id` INT NOT NULL,
    `type` VARCHAR(40) NOT NULL,
    `placed` TINYINT(1) NOT NULL DEFAULT 1,
    `x` DOUBLE NOT NULL DEFAULT 0, `y` DOUBLE NOT NULL DEFAULT 0, `z` DOUBLE NOT NULL DEFAULT 0,
    `rx` DOUBLE NOT NULL DEFAULT 0, `ry` DOUBLE NOT NULL DEFAULT 0, `rz` DOUBLE NOT NULL DEFAULT 0,
    `price` INT NOT NULL DEFAULT 0,
    `bought_by` VARCHAR(100) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX `lab` (`lab_id`)
) DEFAULT CHARSET=utf8mb4;

-- Attaques et captures (historique gardé)
CREATE TABLE IF NOT EXISTS `labs_raids` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `lab_id` INT NOT NULL,
    `attacker_group` INT NOT NULL,
    `defender_group` INT NULL,
    `attacker_label` VARCHAR(60) NOT NULL DEFAULT '',
    `defender_label` VARCHAR(60) NOT NULL DEFAULT '',
    `status` VARCHAR(20) NOT NULL,                -- preparing | active | success | failed | cancelled
    `reason` VARCHAR(255) NOT NULL DEFAULT '',
    `started_by` VARCHAR(100) NOT NULL DEFAULT '',
    `started_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ended_at` TIMESTAMP NULL,
    INDEX `lab` (`lab_id`), INDEX `started` (`started_at`)
) DEFAULT CHARSET=utf8mb4;

-- Réglages modifiés dans admin_menu (attaques, points des intérieurs) et version du schéma
CREATE TABLE IF NOT EXISTS `labs_settings` (
    `k` VARCHAR(32) NOT NULL PRIMARY KEY,
    `v` LONGTEXT NOT NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) DEFAULT CHARSET=utf8mb4;

-- Journal (achats, fabrications, accès, codes, attaques, actions du staff)
CREATE TABLE IF NOT EXISTS `labs_logs` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `lab_id` INT NULL,
    `kind` VARCHAR(20) NOT NULL,
    `actor` VARCHAR(100) NOT NULL DEFAULT '',
    `detail` VARCHAR(255) NOT NULL DEFAULT '',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX `lab` (`lab_id`), INDEX `created` (`created_at`)
) DEFAULT CHARSET=utf8mb4;

INSERT INTO `labs_settings` (`k`, `v`) VALUES ('schema', '1') ON DUPLICATE KEY UPDATE `v` = `v`;
