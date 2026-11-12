-- =========================================================
--  ELYFY : tables du streaming musical (créées automatiquement au démarrage)
-- =========================================================

-- Titres de la ville : chansons créées avec le studio IA et titres publiés par les artistes
CREATE TABLE IF NOT EXISTS `elyzea_ef_tracks` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `owner` VARCHAR(64) NOT NULL,
  `kind` VARCHAR(8) NOT NULL DEFAULT 'ai',
  `artist` VARCHAR(60) NOT NULL,
  `title` VARCHAR(80) NOT NULL,
  `url` VARCHAR(500) NULL,
  `temp_url` VARCHAR(500) NULL,
  `lyrics` TEXT NULL,
  `style` VARCHAR(30) NULL,
  `mood` VARCHAR(30) NULL,
  `voice` VARCHAR(10) NULL,
  `status` VARCHAR(12) NOT NULL DEFAULT 'queued',
  `provider_id` VARCHAR(80) NULL,
  `error` VARCHAR(200) NULL,
  `price` INT NOT NULL DEFAULT 0,
  `public` TINYINT NOT NULL DEFAULT 0,
  `plays` INT NOT NULL DEFAULT 0,
  `likes` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `ready_at` DATETIME NULL,
  PRIMARY KEY (`id`),
  KEY `owner` (`owner`, `id`),
  KEY `status` (`status`),
  KEY `public` (`public`, `plays`)
);

-- Titres enregistrés par un joueur : j'aime, téléchargés (données du titre gardées avec)
CREATE TABLE IF NOT EXISTS `elyzea_ef_saved` (
  `identifier` VARCHAR(64) NOT NULL,
  `track_key` VARCHAR(80) NOT NULL,
  `data` TEXT NOT NULL,
  `liked` TINYINT NOT NULL DEFAULT 0,
  `liked_at` DATETIME NULL,
  `downloaded` TINYINT NOT NULL DEFAULT 0,
  `downloaded_at` DATETIME NULL,
  PRIMARY KEY (`identifier`, `track_key`),
  KEY `liked` (`identifier`, `liked`, `liked_at`),
  KEY `dl` (`identifier`, `downloaded`, `downloaded_at`)
);

CREATE TABLE IF NOT EXISTS `elyzea_ef_playlists` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `owner` VARCHAR(64) NOT NULL,
  `name` VARCHAR(50) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `owner` (`owner`, `updated_at`)
);

CREATE TABLE IF NOT EXISTS `elyzea_ef_playlist_items` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `playlist_id` INT NOT NULL,
  `track_key` VARCHAR(80) NOT NULL,
  `data` TEXT NOT NULL,
  `added_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `pl_track` (`playlist_id`, `track_key`),
  KEY `playlist` (`playlist_id`, `id`)
);

-- Écoutés récemment
CREATE TABLE IF NOT EXISTS `elyzea_ef_history` (
  `identifier` VARCHAR(64) NOT NULL,
  `track_key` VARCHAR(80) NOT NULL,
  `data` TEXT NOT NULL,
  `played_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`, `track_key`),
  KEY `recent` (`identifier`, `played_at`)
);

CREATE TABLE IF NOT EXISTS `elyzea_ef_track_likes` (
  `track_id` INT NOT NULL,
  `identifier` VARCHAR(64) NOT NULL,
  PRIMARY KEY (`track_id`, `identifier`)
);

-- Nom d'artiste (studio, publications)
CREATE TABLE IF NOT EXISTS `elyzea_ef_profiles` (
  `identifier` VARCHAR(64) NOT NULL,
  `artist` VARCHAR(40) NOT NULL,
  PRIMARY KEY (`identifier`)
);
