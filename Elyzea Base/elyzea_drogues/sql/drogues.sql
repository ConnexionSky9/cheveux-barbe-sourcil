-- =====================================================================
--  ELYZEA DROGUES : tables SQL
--  Facultatif : la ressource crée ces tables toute seule au démarrage (server/core.lua).
--  Ce fichier sert à les créer à la main (phpMyAdmin, HeidiSQL…) si vous préférez.
-- =====================================================================

-- Réglages modifiés dans admin_menu (une ligne par section, JSON) + version du schéma
CREATE TABLE IF NOT EXISTS `elyzea_drogues_settings` (
    `k` VARCHAR(32) NOT NULL PRIMARY KEY,
    `v` LONGTEXT NOT NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) DEFAULT CHARSET=utf8mb4;

-- Installations placées par le staff : postes, points de récolte, PNJ acheteurs / fournisseurs
CREATE TABLE IF NOT EXISTS `drogues_sites` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `type` VARCHAR(40) NOT NULL,
    `model` VARCHAR(60) NOT NULL,
    `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL, `h` DOUBLE NOT NULL DEFAULT 0,
    `rx` DOUBLE NOT NULL DEFAULT 0, `ry` DOUBLE NOT NULL DEFAULT 0,
    `label` VARCHAR(60) NULL,
    `created_by` VARCHAR(100) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) DEFAULT CHARSET=utf8mb4;

-- Pots et plantes des joueurs (croissance calculée à partir des dates)
CREATE TABLE IF NOT EXISTS `drogues_plants` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `owner_cid` VARCHAR(50) NOT NULL,
    `owner_name` VARCHAR(100) NOT NULL DEFAULT '',
    `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL, `h` DOUBLE NOT NULL DEFAULT 0,
    `variety` VARCHAR(30) NULL,
    `planted_at` INT UNSIGNED NULL,
    `progress` DOUBLE NOT NULL DEFAULT 0,
    `water` DOUBLE NOT NULL DEFAULT 0,
    `health` DOUBLE NOT NULL DEFAULT 100,
    `lamp` TINYINT(1) NOT NULL DEFAULT 0,
    `fert` TINYINT(1) NOT NULL DEFAULT 0,
    `dead` TINYINT(1) NOT NULL DEFAULT 0,
    `dead_at` INT UNSIGNED NULL,
    `last_at` INT UNSIGNED NOT NULL,
    `watered_at` INT UNSIGNED NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX `owner` (`owner_cid`)
) DEFAULT CHARSET=utf8mb4;

-- Journal (fabrication, ventes, culture, actions du staff) : vidé après 30 jours
CREATE TABLE IF NOT EXISTS `drogues_logs` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `kind` VARCHAR(20) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL DEFAULT '',
    `name` VARCHAR(100) NOT NULL DEFAULT '',
    `detail` VARCHAR(255) NOT NULL DEFAULT '',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX `created` (`created_at`),
    INDEX `kind` (`kind`)
) DEFAULT CHARSET=utf8mb4;

INSERT INTO `elyzea_drogues_settings` (`k`, `v`) VALUES ('schema', '2') ON DUPLICATE KEY UPDATE `v` = `v`;
