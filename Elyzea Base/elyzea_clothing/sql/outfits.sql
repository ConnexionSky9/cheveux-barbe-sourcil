-- =====================================================================
--  ELYZEA CLOTHING · TENUES ENREGISTRÉES
--  Ces tables sont créées toutes seules au démarrage d'elyzea_clothing (server/outfits.lua).
--  Ce fichier sert seulement si tu préfères les créer à la main (phpMyAdmin › SQL).
--  Rien d'existant n'est modifié : ni ely_characters, ni les objets vêtements de l'inventaire.
-- =====================================================================

CREATE TABLE IF NOT EXISTS `elyzea_outfit_categories` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(64) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `citizen_name` (`citizenid`, `name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `elyzea_outfits` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(64) NOT NULL,
    `category` VARCHAR(40) NOT NULL DEFAULT '',   -- '' = sans catégorie, id par défaut (ex. 'soiree') ou 'c<n°>' (catégorie personnelle)
    `sex` VARCHAR(6) NOT NULL,                     -- 'male' / 'female'
    `pieces` LONGTEXT NOT NULL,                    -- JSON { rayon = { drawable, texture, col, li } }
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `citizen_name` (`citizenid`, `name`),
    KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
