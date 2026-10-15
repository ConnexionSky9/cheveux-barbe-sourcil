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
