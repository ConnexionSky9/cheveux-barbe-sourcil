-- Créée automatiquement au démarrage de la ressource (installation manuelle seulement)
CREATE TABLE IF NOT EXISTS `ely_agencies` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `kind` VARCHAR(20) NOT NULL,
    `job` VARCHAR(40) NOT NULL UNIQUE,
    `label` VARCHAR(60) NOT NULL,
    `short` VARCHAR(12) NULL,
    `mat_prefix` VARCHAR(8) NOT NULL,
    `phone_prefix` VARCHAR(3) NOT NULL,
    `color` VARCHAR(9) NULL,
    `zone` LONGTEXT NULL,
    `created_by` VARCHAR(100) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX (`kind`)
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
