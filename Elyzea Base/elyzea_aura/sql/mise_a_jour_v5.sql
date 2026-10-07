-- À importer si tu avais déjà installé la v1.1
ALTER TABLE `elyzea_phones` ADD COLUMN IF NOT EXISTS `passcode` VARCHAR(40) NULL;

CREATE TABLE IF NOT EXISTS `elyzea_bank_requests` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `from_number` VARCHAR(20) NOT NULL,
  `to_number` VARCHAR(20) NOT NULL,
  `amount` INT NOT NULL,
  `reason` VARCHAR(60) NOT NULL DEFAULT '',
  `status` VARCHAR(12) NOT NULL DEFAULT 'pending',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `to_number` (`to_number`),
  KEY `from_number` (`from_number`)
);
