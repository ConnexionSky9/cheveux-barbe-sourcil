-- Téléphone de service des métiers (créées aussi automatiquement au démarrage)
CREATE TABLE IF NOT EXISTS `jobphone_numbers` (
    `citizenid` VARCHAR(64) NOT NULL,
    `job` VARCHAR(64) NOT NULL,
    `number` VARCHAR(16) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`, `job`),
    UNIQUE KEY `uniq_number` (`number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `jobphone_messages` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `unit` VARCHAR(80) NOT NULL,
    `from_cid` VARCHAR(64) NOT NULL,
    `from_name` VARCHAR(100) NOT NULL,
    `to_cid` VARCHAR(64) NULL,
    `body` VARCHAR(300) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_unit` (`unit`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `jobphone_reads` (
    `citizenid` VARCHAR(64) NOT NULL,
    `conv` VARCHAR(160) NOT NULL,
    `last_id` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`citizenid`, `conv`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Entreprises : numéro public et état ouvert / fermé (appli « Entreprise »)
CREATE TABLE IF NOT EXISTS `jobphone_business` (
    `unit` VARCHAR(80) NOT NULL,
    `number` VARCHAR(16) NOT NULL,
    `open` TINYINT(1) NOT NULL DEFAULT 0,
    `changed_by` VARCHAR(100) NULL,
    `changed_at` TIMESTAMP NULL,
    PRIMARY KEY (`unit`),
    UNIQUE KEY `uniq_number` (`number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Messages des clients (téléphone perso › numéro public) et réponses de l'entreprise
CREATE TABLE IF NOT EXISTS `jobphone_biz_messages` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `unit` VARCHAR(80) NOT NULL,
    `client_number` VARCHAR(20) NOT NULL,
    `client_name` VARCHAR(100) NULL,
    `direction` VARCHAR(3) NOT NULL,
    `body` VARCHAR(500) NOT NULL,
    `author` VARCHAR(100) NULL,
    `is_read` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_unit` (`unit`, `client_number`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
