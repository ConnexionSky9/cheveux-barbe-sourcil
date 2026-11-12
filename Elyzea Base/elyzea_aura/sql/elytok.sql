-- =========================================================
--  ELYTOK : tables du réseau social vidéo (créées automatiquement au démarrage)
--  Les comptes sont dans elyzea_accounts (app = 'elytok').
-- =========================================================
CREATE TABLE IF NOT EXISTS `elyzea_et_profiles` (
  `identifier` VARCHAR(64) NOT NULL,
  `avatar` VARCHAR(500) NULL,
  `bio` VARCHAR(300) NOT NULL DEFAULT '',
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`)
);

CREATE TABLE IF NOT EXISTS `elyzea_et_videos` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `author` VARCHAR(64) NOT NULL,
  `url` VARCHAR(500) NOT NULL,
  `duration` INT NOT NULL DEFAULT 0,
  `caption` VARCHAR(300) NOT NULL DEFAULT '',
  `music_title` VARCHAR(80) NULL,
  `music_artist` VARCHAR(60) NULL,
  `music_url` VARCHAR(500) NULL,
  `allow_comments` TINYINT NOT NULL DEFAULT 1,
  `views` INT NOT NULL DEFAULT 0,
  `likes` INT NOT NULL DEFAULT 0,
  `comments` INT NOT NULL DEFAULT 0,
  `shares` INT NOT NULL DEFAULT 0,
  `saves` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `author` (`author`, `id`),
  KEY `created` (`created_at`)
);

CREATE TABLE IF NOT EXISTS `elyzea_et_likes` (
  `video_id` INT NOT NULL,
  `identifier` VARCHAR(64) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`video_id`, `identifier`),
  KEY `who` (`identifier`, `created_at`)
);

CREATE TABLE IF NOT EXISTS `elyzea_et_saves` (
  `video_id` INT NOT NULL,
  `identifier` VARCHAR(64) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`video_id`, `identifier`),
  KEY `who` (`identifier`, `created_at`)
);

CREATE TABLE IF NOT EXISTS `elyzea_et_views` (
  `video_id` INT NOT NULL,
  `identifier` VARCHAR(64) NOT NULL,
  PRIMARY KEY (`video_id`, `identifier`)
);

CREATE TABLE IF NOT EXISTS `elyzea_et_comments` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `video_id` INT NOT NULL,
  `author` VARCHAR(64) NOT NULL,
  `content` VARCHAR(200) NOT NULL,
  `likes` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `video` (`video_id`, `id`)
);

CREATE TABLE IF NOT EXISTS `elyzea_et_comment_likes` (
  `comment_id` INT NOT NULL,
  `identifier` VARCHAR(64) NOT NULL,
  PRIMARY KEY (`comment_id`, `identifier`)
);

CREATE TABLE IF NOT EXISTS `elyzea_et_follows` (
  `follower` VARCHAR(64) NOT NULL,
  `followed` VARCHAR(64) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`follower`, `followed`),
  KEY `followed` (`followed`, `created_at`)
);

CREATE TABLE IF NOT EXISTS `elyzea_et_notifications` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `owner` VARCHAR(64) NOT NULL,
  `type` VARCHAR(12) NOT NULL,
  `actor` VARCHAR(64) NOT NULL,
  `video_id` INT NULL,
  `text` VARCHAR(200) NULL,
  `dkey` VARCHAR(90) NOT NULL,
  `is_read` TINYINT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `owner_dkey` (`owner`, `dkey`),
  KEY `owner` (`owner`, `id`)
);

CREATE TABLE IF NOT EXISTS `elyzea_et_messages` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `sender` VARCHAR(64) NOT NULL,
  `receiver` VARCHAR(64) NOT NULL,
  `content` VARCHAR(500) NOT NULL DEFAULT '',
  `video_id` INT NULL,
  `is_read` TINYINT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `pair` (`sender`, `receiver`, `id`),
  KEY `inbox` (`receiver`, `is_read`)
);
