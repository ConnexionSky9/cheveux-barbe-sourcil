-- ELYZEA MANUTENTION : réglages du métier (créée automatiquement au démarrage ; ce fichier est facultatif)
CREATE TABLE IF NOT EXISTS `manut_settings` (
    `k` VARCHAR(40) NOT NULL PRIMARY KEY, `v` LONGTEXT NOT NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) DEFAULT CHARSET=utf8mb4;
