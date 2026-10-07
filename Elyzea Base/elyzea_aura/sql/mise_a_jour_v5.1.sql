-- À importer si tu avais déjà installé la v5.0
ALTER TABLE `elyzea_gallery` ADD COLUMN IF NOT EXISTS `type` VARCHAR(10) NOT NULL DEFAULT 'photo';
ALTER TABLE `elyzea_gallery` ADD COLUMN IF NOT EXISTS `duration` INT NOT NULL DEFAULT 0;
ALTER TABLE `elyzea_tracks` ADD COLUMN IF NOT EXISTS `thumb` VARCHAR(500) NULL;
ALTER TABLE `elyzea_tracks` ADD COLUMN IF NOT EXISTS `source` VARCHAR(12) NOT NULL DEFAULT 'direct';

CREATE TABLE IF NOT EXISTS `elyzea_dating_profiles` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(64) NOT NULL,
  `name` VARCHAR(30) NOT NULL,
  `age` TINYINT UNSIGNED NOT NULL,
  `gender` VARCHAR(10) NOT NULL,
  `interest` VARCHAR(10) NOT NULL,
  `bio` VARCHAR(300) NOT NULL DEFAULT '',
  `photos` TEXT NULL,
  `tags` TEXT NULL,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `identifier` (`identifier`)
);

CREATE TABLE IF NOT EXISTS `elyzea_dating_swipes` (
  `swiper` INT NOT NULL,
  `target` INT NOT NULL,
  `liked` TINYINT(1) NOT NULL,
  `super` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`swiper`, `target`),
  KEY `target` (`target`)
);

CREATE TABLE IF NOT EXISTS `elyzea_dating_matches` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `a` INT NOT NULL,
  `b` INT NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `pair` (`a`, `b`)
);

CREATE TABLE IF NOT EXISTS `elyzea_dating_messages` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `match_id` INT NOT NULL,
  `sender` INT NOT NULL,
  `message` VARCHAR(500) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `match_id` (`match_id`)
);
