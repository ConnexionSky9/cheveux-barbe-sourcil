-- =====================================================================
--  ELYZEA PRESSE - installation manuelle (facultative)
--  Les tables sont créées AUTOMATIQUEMENT au démarrage de la ressource ; ce fichier
--  contient exactement les mêmes tables (générées depuis une base de test MariaDB).
--  Aucune table existante n'est modifiée ou supprimée. Désinstaller : sql/uninstall.sql
-- =====================================================================

CREATE TABLE IF NOT EXISTS `presse_admin_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `actor_cid` varchar(50) DEFAULT NULL,
  `actor_name` varchar(100) DEFAULT NULL,
  `target_cid` varchar(50) DEFAULT NULL,
  `target_name` varchar(100) DEFAULT NULL,
  `action` varchar(40) NOT NULL,
  `old_grade` varchar(50) DEFAULT NULL,
  `new_grade` varchar(50) DEFAULT NULL,
  `reason` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `job` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `target_cid` (`target_cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
;

CREATE TABLE IF NOT EXISTS `presse_ads` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `job` varchar(40) NOT NULL,
  `uid` varchar(40) NOT NULL,
  `tier` varchar(20) NOT NULL,
  `client_cid` varchar(50) NOT NULL,
  `client_name` varchar(100) DEFAULT NULL,
  `text` varchar(300) NOT NULL,
  `price` int(11) NOT NULL,
  `method` varchar(6) DEFAULT NULL,
  `status` varchar(10) NOT NULL DEFAULT 'active',
  `seller_cid` varchar(50) DEFAULT NULL,
  `seller_name` varchar(100) DEFAULT NULL,
  `txid` varchar(40) DEFAULT NULL,
  `note` varchar(160) DEFAULT NULL,
  `handled_by` varchar(100) DEFAULT NULL,
  `expires_at` datetime NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uid` (`uid`),
  KEY `job` (`job`),
  KEY `active` (`status`,`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
;

CREATE TABLE IF NOT EXISTS `presse_article_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `article_id` int(11) NOT NULL,
  `action` varchar(40) NOT NULL,
  `actor_cid` varchar(50) DEFAULT NULL,
  `actor_name` varchar(100) DEFAULT NULL,
  `details` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `article_id` (`article_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
;

CREATE TABLE IF NOT EXISTS `presse_articles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `job` varchar(40) NOT NULL,
  `title` varchar(120) NOT NULL,
  `title_key` varchar(120) NOT NULL,
  `summary` varchar(300) DEFAULT NULL,
  `body` mediumtext NOT NULL,
  `category` varchar(20) NOT NULL DEFAULT 'societe',
  `status` varchar(12) NOT NULL DEFAULT 'draft',
  `author_cid` varchar(50) NOT NULL,
  `author_name` varchar(100) DEFAULT NULL,
  `editor_name` varchar(100) DEFAULT NULL,
  `reviewer_name` varchar(100) DEFAULT NULL,
  `review_note` varchar(255) DEFAULT NULL,
  `interview_id` int(11) DEFAULT NULL,
  `media` text DEFAULT NULL,
  `version` int(11) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `submitted_at` datetime DEFAULT NULL,
  `published_at` datetime DEFAULT NULL,
  `archived_at` datetime DEFAULT NULL,
  `deleted_at` datetime DEFAULT NULL,
  `delete_reason` varchar(160) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `job_status` (`job`,`status`),
  KEY `author_cid` (`author_cid`),
  KEY `pub` (`status`,`published_at`),
  KEY `title_key` (`title_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
;

CREATE TABLE IF NOT EXISTS `presse_cards` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `number` varchar(24) NOT NULL,
  `job` varchar(40) NOT NULL,
  `citizenid` varchar(50) NOT NULL,
  `name` varchar(100) DEFAULT NULL,
  `matricule` varchar(20) DEFAULT NULL,
  `issued_by` varchar(100) DEFAULT NULL,
  `issued_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `revoked_at` datetime DEFAULT NULL,
  `revoke_reason` varchar(120) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `number` (`number`),
  KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
;

CREATE TABLE IF NOT EXISTS `presse_commission` (
  `grade_id` int(11) NOT NULL,
  `pct` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `actor_name` varchar(100) DEFAULT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`grade_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
;

CREATE TABLE IF NOT EXISTS `presse_employees` (
  `citizenid` varchar(50) NOT NULL,
  `job` varchar(40) NOT NULL DEFAULT 'journaliste',
  `name` varchar(100) NOT NULL,
  `matricule` varchar(20) NOT NULL,
  `grade_id` int(11) NOT NULL,
  `recruited_at` datetime NOT NULL DEFAULT current_timestamp(),
  `promoted_at` datetime DEFAULT NULL,
  `note` varchar(255) DEFAULT NULL,
  `total_seconds` int(11) NOT NULL DEFAULT 0,
  `unpaid_seconds` int(11) NOT NULL DEFAULT 0,
  `unpaid_amount` double NOT NULL DEFAULT 0,
  PRIMARY KEY (`citizenid`),
  UNIQUE KEY `matricule` (`matricule`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
;

CREATE TABLE IF NOT EXISTS `presse_flashes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `job` varchar(40) NOT NULL,
  `kind` varchar(10) NOT NULL,
  `author_cid` varchar(50) DEFAULT NULL,
  `author_name` varchar(100) DEFAULT NULL,
  `title` varchar(80) DEFAULT NULL,
  `text` varchar(255) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `job` (`job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
;

CREATE TABLE IF NOT EXISTS `presse_grades` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `job` varchar(40) NOT NULL DEFAULT 'journaliste',
  `name` varchar(50) NOT NULL,
  `level` int(11) NOT NULL,
  `salary` int(11) NOT NULL DEFAULT 0,
  `perms` text NOT NULL,
  `is_default` tinyint(1) NOT NULL DEFAULT 0,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `job_name` (`job`,`name`),
  UNIQUE KEY `job_level` (`job`,`level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
;

CREATE TABLE IF NOT EXISTS `presse_interviews` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `job` varchar(40) NOT NULL,
  `journalist_cid` varchar(50) NOT NULL,
  `journalist_name` varchar(100) DEFAULT NULL,
  `subject` varchar(120) NOT NULL,
  `interviewee_cid` varchar(50) DEFAULT NULL,
  `interviewee_name` varchar(100) DEFAULT NULL,
  `anonymous` tinyint(1) NOT NULL DEFAULT 0,
  `status` varchar(10) NOT NULL DEFAULT 'active',
  `notes` mediumtext DEFAULT NULL,
  `location` varchar(120) DEFAULT NULL,
  `started_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `ended_at` datetime DEFAULT NULL,
  `end_reason` varchar(60) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `job` (`job`),
  KEY `journalist_cid` (`journalist_cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
;

CREATE TABLE IF NOT EXISTS `presse_media` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `job` varchar(40) NOT NULL,
  `kind` varchar(6) NOT NULL,
  `author_cid` varchar(50) NOT NULL,
  `author_name` varchar(100) DEFAULT NULL,
  `caption` varchar(160) NOT NULL,
  `street` varchar(120) DEFAULT NULL,
  `x` double DEFAULT NULL,
  `y` double DEFAULT NULL,
  `z` double DEFAULT NULL,
  `seconds` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `job` (`job`),
  KEY `author_cid` (`author_cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
;

CREATE TABLE IF NOT EXISTS `presse_rates` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `grade_id` int(11) NOT NULL,
  `grade_name` varchar(50) DEFAULT NULL,
  `rate` int(11) NOT NULL,
  `actor_name` varchar(100) DEFAULT NULL,
  `effective_from` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `grade_id` (`grade_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
;

CREATE TABLE IF NOT EXISTS `presse_sessions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `name` varchar(100) DEFAULT NULL,
  `grade_name` varchar(50) DEFAULT NULL,
  `started_at` datetime NOT NULL,
  `ended_at` datetime DEFAULT NULL,
  `seconds` int(11) NOT NULL DEFAULT 0,
  `amount` double NOT NULL DEFAULT 0,
  `end_reason` varchar(30) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
;

CREATE TABLE IF NOT EXISTS `presse_settings` (
  `k` varchar(50) NOT NULL,
  `v` longtext NOT NULL,
  PRIMARY KEY (`k`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
;

CREATE TABLE IF NOT EXISTS `presse_transactions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `txid` varchar(40) NOT NULL,
  `type` varchar(10) NOT NULL,
  `category` varchar(20) NOT NULL,
  `amount` int(11) NOT NULL,
  `reason` varchar(160) DEFAULT NULL,
  `actor_cid` varchar(50) DEFAULT NULL,
  `actor_name` varchar(100) DEFAULT NULL,
  `target_cid` varchar(50) DEFAULT NULL,
  `target_name` varchar(100) DEFAULT NULL,
  `seconds` int(11) DEFAULT NULL,
  `ref` varchar(40) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `job` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `txid` (`txid`),
  KEY `category` (`category`),
  KEY `target_cid` (`target_cid`),
  KEY `created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
;

