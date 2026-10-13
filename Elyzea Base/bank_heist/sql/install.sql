-- =====================================================================
--  BANK HEIST - tables (créées automatiquement au démarrage ; ce fichier sert à une installation manuelle)
--  Les sacs de billets utilisent la table jh_bags de jewelry_heist (colonnes kind et capacity ajoutées automatiquement).
-- =====================================================================
CREATE TABLE IF NOT EXISTS `bh_settings` (`k` VARCHAR(32) NOT NULL PRIMARY KEY, `v` LONGTEXT NULL) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `bh_laptops` (
    `serial` VARCHAR(24) NOT NULL PRIMARY KEY,
    `attempts` INT NOT NULL DEFAULT 3,
    `owner_cid` VARCHAR(64) NULL,
    `last_bank` VARCHAR(32) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `bh_state` (
    `bank_id` VARCHAR(32) NOT NULL PRIMARY KEY,
    `cooldown_until` INT NOT NULL DEFAULT 0,
    `active_session` VARCHAR(24) NULL
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `bh_logs` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `kind` VARCHAR(16) NOT NULL, `ref` VARCHAR(32) NULL, `cid` VARCHAR(64) NULL, `name` VARCHAR(100) NULL, `details` TEXT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, INDEX (`kind`), INDEX (`created_at`)
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- jewelry_heist (si la table existe déjà sans ces colonnes ; une erreur « colonne déjà présente » peut être ignorée)
ALTER TABLE `jh_bags` ADD COLUMN `kind` VARCHAR(12) NOT NULL DEFAULT 'jewel';
ALTER TABLE `jh_bags` ADD COLUMN `capacity` INT NULL;
