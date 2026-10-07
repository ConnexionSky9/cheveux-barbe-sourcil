-- À importer si tu avais déjà installé la v1.0
-- (l'ancienne app Pulse est remplacée par Birdy ; tu peux supprimer elyzea_posts et elyzea_post_likes)

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
  PRIMARY KEY (`id`),
  KEY `owner` (`owner`)
);

