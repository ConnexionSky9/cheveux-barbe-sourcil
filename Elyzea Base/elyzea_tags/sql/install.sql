-- Elyzea Tags : table créée automatiquement au démarrage (ce fichier sert seulement à la créer à la main)
CREATE TABLE IF NOT EXISTS `elyzea_tags` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL,
    `nx` DOUBLE NOT NULL, `ny` DOUBLE NOT NULL, `nz` DOUBLE NOT NULL,
    `size` FLOAT NOT NULL DEFAULT 1.6,
    `rot` FLOAT NOT NULL DEFAULT 0,
    `text` VARCHAR(100) NOT NULL,
    `color` VARCHAR(7) NOT NULL,
    `font` VARCHAR(24) NOT NULL,
    `citizenid` VARCHAR(64) NULL,
    `author` VARCHAR(100) NULL,
    `license` VARCHAR(80) NULL,
    `group_id` INT NULL,
    `group_label` VARCHAR(100) NULL,
    `zone_id` INT NULL,
    `zone_name` VARCHAR(100) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY `citizenid` (`citizenid`),
    KEY `zone_id` (`zone_id`)
    ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Mise à jour d'une installation existante (fait automatiquement au démarrage) :
-- ALTER TABLE `elyzea_tags` ADD COLUMN `rot` FLOAT NOT NULL DEFAULT 0 AFTER `size`;
