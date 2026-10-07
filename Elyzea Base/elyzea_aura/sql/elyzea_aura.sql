CREATE TABLE IF NOT EXISTS `elyzea_phones` (
  `identifier` VARCHAR(64) NOT NULL,
  `number` VARCHAR(20) NOT NULL,
  `settings` LONGTEXT NULL,
  `passcode` VARCHAR(40) NULL,
  PRIMARY KEY (`identifier`),
  UNIQUE KEY `number` (`number`)
);

CREATE TABLE IF NOT EXISTS `elyzea_contacts` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `owner` VARCHAR(64) NOT NULL,
  `name` VARCHAR(50) NOT NULL,
  `number` VARCHAR(20) NOT NULL,
  `favorite` TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `owner` (`owner`)
);

CREATE TABLE IF NOT EXISTS `elyzea_messages` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `sender` VARCHAR(20) NOT NULL,
  `receiver` VARCHAR(20) NOT NULL,
  `message` TEXT NOT NULL,
  `is_read` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `sender` (`sender`),
  KEY `receiver` (`receiver`)
);

CREATE TABLE IF NOT EXISTS `elyzea_calls` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `caller` VARCHAR(20) NOT NULL,
  `receiver` VARCHAR(20) NOT NULL,
  `status` VARCHAR(16) NOT NULL,
  `duration` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `caller` (`caller`),
  KEY `receiver` (`receiver`)
);

CREATE TABLE IF NOT EXISTS `elyzea_accounts` (
  `identifier` VARCHAR(64) NOT NULL,
  `app` VARCHAR(20) NOT NULL,
  `username` VARCHAR(20) NOT NULL,
  `display_name` VARCHAR(40) NOT NULL,
  PRIMARY KEY (`identifier`, `app`),
  UNIQUE KEY `app_username` (`app`, `username`)
);

CREATE TABLE IF NOT EXISTS `elyzea_social_posts` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `app` VARCHAR(20) NOT NULL,
  `author` VARCHAR(64) NOT NULL,
  `content` VARCHAR(300) NOT NULL DEFAULT '',
  `image` VARCHAR(500) NULL,
  `repost_of` INT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `app` (`app`),
  KEY `repost_of` (`repost_of`)
);

CREATE TABLE IF NOT EXISTS `elyzea_social_likes` (
  `post_id` INT NOT NULL,
  `identifier` VARCHAR(64) NOT NULL,
  PRIMARY KEY (`post_id`, `identifier`)
);

CREATE TABLE IF NOT EXISTS `elyzea_social_comments` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `post_id` INT NOT NULL,
  `author` VARCHAR(64) NOT NULL,
  `content` VARCHAR(200) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `post_id` (`post_id`)
);

CREATE TABLE IF NOT EXISTS `elyzea_tracks` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `owner` VARCHAR(64) NOT NULL,
  `title` VARCHAR(80) NOT NULL,
  `artist` VARCHAR(60) NOT NULL,
  `url` VARCHAR(500) NOT NULL,
  `thumb` VARCHAR(500) NULL,
  `source` VARCHAR(12) NOT NULL DEFAULT 'direct',
  PRIMARY KEY (`id`),
  KEY `owner` (`owner`)
);

CREATE TABLE IF NOT EXISTS `elyzea_ads` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `author` VARCHAR(64) NOT NULL,
  `author_name` VARCHAR(60) NOT NULL,
  `number` VARCHAR(20) NOT NULL,
  `title` VARCHAR(80) NOT NULL,
  `content` VARCHAR(500) NOT NULL,
  `price` INT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
);

CREATE TABLE IF NOT EXISTS `elyzea_notes` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `owner` VARCHAR(64) NOT NULL,
  `title` VARCHAR(80) NOT NULL,
  `content` TEXT NOT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `owner` (`owner`)
);

CREATE TABLE IF NOT EXISTS `elyzea_gallery` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `owner` VARCHAR(64) NOT NULL,
  `url` VARCHAR(500) NOT NULL,
  `type` VARCHAR(10) NOT NULL DEFAULT 'photo',
  `duration` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `owner` (`owner`)
);

CREATE TABLE IF NOT EXISTS `elyzea_bank_history` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `owner` VARCHAR(64) NOT NULL,
  `label` VARCHAR(100) NOT NULL,
  `amount` INT NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `owner` (`owner`)
);

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

CREATE TABLE IF NOT EXISTS `elyzea_mechanic_jobs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `owner` VARCHAR(64) NOT NULL,
  `service` VARCHAR(12) NOT NULL,
  `price` INT NOT NULL,
  `pay` VARCHAR(8) NOT NULL DEFAULT 'bank',
  `vehicle` VARCHAR(60) NOT NULL DEFAULT '',
  `plate` VARCHAR(12) NOT NULL DEFAULT '',
  `garage` VARCHAR(80) NOT NULL DEFAULT '',
  `status` VARCHAR(12) NOT NULL DEFAULT 'pending',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `owner` (`owner`)
);

CREATE TABLE IF NOT EXISTS `elyzea_garage_orders` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `owner` VARCHAR(64) NOT NULL,
  `plate` VARCHAR(12) NOT NULL,
  `vehicle` VARCHAR(60) NOT NULL DEFAULT '',
  `price` INT NOT NULL,
  `pay` VARCHAR(8) NOT NULL DEFAULT 'bank',
  `status` VARCHAR(12) NOT NULL DEFAULT 'pending',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `owner` (`owner`)
);
