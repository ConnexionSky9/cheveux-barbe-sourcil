-- À importer si tu avais déjà installé la v5.1

CREATE TABLE IF NOT EXISTS `elyzea_delivery_orders` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `owner` VARCHAR(64) NOT NULL,
  `items` TEXT NOT NULL,
  `total` INT NOT NULL,
  `pay` VARCHAR(8) NOT NULL DEFAULT 'bank',
  `shop` VARCHAR(80) NOT NULL DEFAULT '',
  `status` VARCHAR(12) NOT NULL DEFAULT 'preparing',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `owner` (`owner`)
);
