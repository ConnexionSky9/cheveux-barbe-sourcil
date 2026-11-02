-- =====================================================================
--  elyzea_fourriere : la ressource crée tout ceci toute seule au démarrage.
--  Ce fichier sert si tu préfères l'importer à la main.
-- =====================================================================

-- Catégorie du véhicule (car, moto, heli, plane, boat), relevée sur le véhicule par le serveur
ALTER TABLE `player_vehicles` ADD COLUMN IF NOT EXISTS `vclass` VARCHAR(10) NULL DEFAULT NULL;

-- Véhicules en fourrière et en réparation
--   player_vehicles.state : 2 = en fourrière, 4 = en réparation (nouveau)
CREATE TABLE IF NOT EXISTS `elyzea_fourriere` (
    `plate`         VARCHAR(16)  NOT NULL,
    `citizenid`     VARCHAR(64)  NOT NULL,
    `model`         VARCHAR(64)  NULL DEFAULT NULL,
    `vclass`        VARCHAR(10)  NULL DEFAULT NULL,
    `destroyed`     TINYINT(1)   NOT NULL DEFAULT 0,
    `reason`        VARCHAR(20)  NOT NULL DEFAULT 'police',
    `status`        VARCHAR(10)  NOT NULL DEFAULT 'impound',    -- impound | repair
    `impounded_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `paid_amount`   INT          NULL DEFAULT NULL,
    `paid_currency` VARCHAR(10)  NULL DEFAULT NULL,             -- cash | bank | pesos
    `paid_at`       DATETIME     NULL DEFAULT NULL,
    `repair_until`  DATETIME     NULL DEFAULT NULL,             -- fin de la réparation (date réelle)
    PRIMARY KEY (`plate`),
    KEY `citizenid` (`citizenid`),
    KEY `status` (`status`, `repair_until`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
