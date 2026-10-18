-- Elyzea Animaux : tables créées automatiquement au démarrage de la ressource.
-- Ce fichier sert seulement à les créer à la main (phpMyAdmin) si tu préfères.
-- Aucune table existante n'est modifiée.

CREATE TABLE IF NOT EXISTS `elyzea_animaux` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `chip` VARCHAR(16) NOT NULL,
    `citizenid` VARCHAR(64) NOT NULL,
    `species` VARCHAR(40) NOT NULL,
    `variant` VARCHAR(24) NOT NULL,
    `name` VARCHAR(40) NOT NULL,
    `status` VARCHAR(12) NOT NULL DEFAULT 'stored',
    `hunger` FLOAT NOT NULL DEFAULT 100,
    `thirst` FLOAT NOT NULL DEFAULT 100,
    `health` FLOAT NOT NULL DEFAULT 100,
    `gear` TEXT NULL,
    `price` INT NOT NULL DEFAULT 0,
    `vendor` VARCHAR(40) NULL,
    `injured_at` INT NULL,
    `acquired_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `chip` (`chip`),
    KEY `citizenid` (`citizenid`)
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `elyzea_animaux_config` (
    `k` VARCHAR(40) NOT NULL PRIMARY KEY,
    `v` LONGTEXT NOT NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `elyzea_animaux_farm` (
    `enclosure` VARCHAR(40) NOT NULL,
    `slot` INT NOT NULL,
    `species` VARCHAR(40) NOT NULL,
    `variant` VARCHAR(24) NOT NULL,
    `hunger` FLOAT NOT NULL DEFAULT 100,
    `health` FLOAT NOT NULL DEFAULT 100,
    `last_produce` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`enclosure`, `slot`)
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
