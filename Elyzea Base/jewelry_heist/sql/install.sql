-- =====================================================================
--  JEWELRY HEIST - tables (créées automatiquement au démarrage ; ce fichier sert à une installation manuelle)
-- =====================================================================
CREATE TABLE IF NOT EXISTS `jh_settings` (
    `k` VARCHAR(32) NOT NULL PRIMARY KEY,
    `v` LONGTEXT NULL
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `jh_bags` (
    `id` VARCHAR(24) NOT NULL PRIMARY KEY,
    `shop_id` VARCHAR(32) NULL,
    `owner_cid` VARCHAR(64) NULL,
    `owner_name` VARCHAR(100) NULL,
    `holder_cid` VARCHAR(64) NULL,
    `state` VARCHAR(12) NOT NULL DEFAULT 'ground',
    `x` DOUBLE NOT NULL DEFAULT 0, `y` DOUBLE NOT NULL DEFAULT 0, `z` DOUBLE NOT NULL DEFAULT 0,
    `money` INT NOT NULL DEFAULT 0,
    `money_type` VARCHAR(8) NOT NULL DEFAULT 'cash',
    `gems` LONGTEXT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `jh_logs` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `kind` VARCHAR(16) NOT NULL,
    `ref` VARCHAR(32) NULL,
    `cid` VARCHAR(64) NULL,
    `name` VARCHAR(100) NULL,
    `details` TEXT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX (`kind`), INDEX (`created_at`)
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
