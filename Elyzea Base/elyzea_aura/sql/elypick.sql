-- =========================================================
--  ELYPICK : tables du réseau social (créées automatiquement au démarrage)
--  Les comptes (elyzea_accounts, app = 'instapick'), les publications
--  (elyzea_social_posts), les likes et les commentaires existants sont conservés.
-- =========================================================
CREATE TABLE IF NOT EXISTS `elyzea_ep_profiles` (
  `identifier` VARCHAR(64) NOT NULL,
  `avatar` VARCHAR(500) NULL,
  `bio` VARCHAR(300) NOT NULL DEFAULT '',
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`)
);

CREATE TABLE IF NOT EXISTS `elyzea_ep_follows` (
  `follower` VARCHAR(64) NOT NULL,
  `followed` VARCHAR(64) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`follower`, `followed`),
  KEY `followed` (`followed`, `created_at`)
);

CREATE TABLE IF NOT EXISTS `elyzea_ep_stories` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `author` VARCHAR(64) NOT NULL,
  `image` VARCHAR(500) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `expires_at` DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  KEY `author_exp` (`author`, `expires_at`),
  KEY `expires_at` (`expires_at`)
);

CREATE TABLE IF NOT EXISTS `elyzea_ep_story_views` (
  `story_id` INT NOT NULL,
  `viewer` VARCHAR(64) NOT NULL,
  PRIMARY KEY (`story_id`, `viewer`)
);

CREATE TABLE IF NOT EXISTS `elyzea_ep_highlights` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `owner` VARCHAR(64) NOT NULL,
  `title` VARCHAR(30) NOT NULL,
  `cover` VARCHAR(500) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `owner` (`owner`)
);

-- Copie de la story : elle reste à la une après sa suppression automatique (24 h)
CREATE TABLE IF NOT EXISTS `elyzea_ep_highlight_items` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `highlight_id` INT NOT NULL,
  `story_id` INT NULL,
  `image` VARCHAR(500) NOT NULL,
  `story_at` DATETIME NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `highlight` (`highlight_id`, `id`),
  UNIQUE KEY `hl_story` (`highlight_id`, `story_id`)
);

CREATE TABLE IF NOT EXISTS `elyzea_ep_conversations` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `user_a` VARCHAR(64) NOT NULL,
  `user_b` VARCHAR(64) NOT NULL,
  `last_message` VARCHAR(120) NOT NULL DEFAULT '',
  `last_sender` VARCHAR(64) NULL,
  `last_id` INT NOT NULL DEFAULT 0,
  `last_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `read_a` INT NOT NULL DEFAULT 0,
  `read_b` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `pair` (`user_a`, `user_b`),
  KEY `user_b` (`user_b`),
  KEY `last_at` (`last_at`)
);

CREATE TABLE IF NOT EXISTS `elyzea_ep_messages` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `conv_id` INT NOT NULL,
  `sender` VARCHAR(64) NOT NULL,
  `body` VARCHAR(500) NOT NULL DEFAULT '',
  `post_id` INT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `conv` (`conv_id`, `id`)
);

-- dkey : clé anti-doublon (un like, un abonnement, une story par jour = une seule notification)
CREATE TABLE IF NOT EXISTS `elyzea_ep_notifications` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `owner` VARCHAR(64) NOT NULL,
  `type` VARCHAR(12) NOT NULL,
  `actor` VARCHAR(64) NOT NULL,
  `post_id` INT NULL,
  `dkey` VARCHAR(160) NOT NULL,
  `is_read` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `dkey` (`dkey`),
  KEY `owner` (`owner`, `id`)
);

-- Colonnes et index ajoutés aux tables existantes (fait automatiquement par server/elypick.lua ;
-- à la main, n'exécute que ce qui manque) :
-- ALTER TABLE `elyzea_social_posts` ADD COLUMN `music_title` VARCHAR(80) NULL, ADD COLUMN `music_artist` VARCHAR(60) NULL,
--   ADD COLUMN `music_url` VARCHAR(500) NULL, ADD COLUMN `music_thumb` VARCHAR(500) NULL, ADD COLUMN `music_source` VARCHAR(12) NULL;
-- ALTER TABLE `elyzea_social_posts` ADD INDEX `app_id` (`app`, `id`), ADD INDEX `author_app` (`author`, `app`, `id`);
-- ALTER TABLE `elyzea_accounts` ADD INDEX `app_display` (`app`, `display_name`);
