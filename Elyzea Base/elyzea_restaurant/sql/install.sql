-- elyzea_restaurant : tables créées AUTOMATIQUEMENT au démarrage de la ressource.
-- Ce fichier n'est utile que pour les créer à la main (mêmes définitions).

CREATE TABLE IF NOT EXISTS `rs_admin_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `shop_id` int(11) NOT NULL,
  `actor_cid` varchar(50) DEFAULT NULL,
  `actor_name` varchar(100) DEFAULT NULL,
  `target_cid` varchar(50) DEFAULT NULL,
  `target_name` varchar(100) DEFAULT NULL,
  `action` varchar(40) NOT NULL,
  `old_grade` varchar(50) DEFAULT NULL,
  `new_grade` varchar(50) DEFAULT NULL,
  `reason` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `shop_id` (`shop_id`),
  KEY `target_cid` (`target_cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rs_commission` (
  `grade_id` int(11) NOT NULL,
  `pct` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `actor_name` varchar(100) DEFAULT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`grade_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rs_employees` (
  `citizenid` varchar(50) NOT NULL,
  `shop_id` int(11) NOT NULL,
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
  KEY `shop_id` (`shop_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rs_grades` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `shop_id` int(11) NOT NULL,
  `name` varchar(50) NOT NULL,
  `level` int(11) NOT NULL,
  `salary` int(11) NOT NULL DEFAULT 0,
  `perms` text NOT NULL,
  `is_default` tinyint(1) NOT NULL DEFAULT 0,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `shop_level` (`shop_id`,`level`),
  UNIQUE KEY `shop_name` (`shop_id`,`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rs_menu` (
  `shop_id` int(11) NOT NULL,
  `product` varchar(40) NOT NULL,
  `price` int(11) NOT NULL,
  `enabled` tinyint(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`shop_id`,`product`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rs_orders` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `shop_id` int(11) NOT NULL,
  `num` int(11) NOT NULL,
  `customer_cid` varchar(50) NOT NULL,
  `customer_name` varchar(100) DEFAULT NULL,
  `lines` text NOT NULL,
  `total` int(11) NOT NULL,
  `method` varchar(6) NOT NULL,
  `paid` int(11) DEFAULT NULL,
  `status` varchar(12) NOT NULL DEFAULT 'pending',
  `employee_cid` varchar(50) DEFAULT NULL,
  `employee_name` varchar(100) DEFAULT NULL,
  `bag_uid` varchar(40) DEFAULT NULL,
  `bag_left` text DEFAULT NULL,
  `opened` tinyint(1) NOT NULL DEFAULT 0,
  `cancel_reason` varchar(160) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `taken_at` datetime DEFAULT NULL,
  `ready_at` datetime DEFAULT NULL,
  `delivered_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `bag_uid` (`bag_uid`),
  KEY `shop_id` (`shop_id`),
  KEY `status` (`status`),
  KEY `customer_cid` (`customer_cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rs_rates` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `shop_id` int(11) NOT NULL,
  `grade_id` int(11) NOT NULL,
  `grade_name` varchar(50) DEFAULT NULL,
  `rate` int(11) NOT NULL,
  `actor_name` varchar(100) DEFAULT NULL,
  `effective_from` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `shop_id` (`shop_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rs_sessions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `shop_id` int(11) NOT NULL,
  `citizenid` varchar(50) NOT NULL,
  `name` varchar(100) DEFAULT NULL,
  `grade_name` varchar(50) DEFAULT NULL,
  `started_at` datetime NOT NULL,
  `ended_at` datetime DEFAULT NULL,
  `seconds` int(11) NOT NULL DEFAULT 0,
  `amount` double NOT NULL DEFAULT 0,
  `end_reason` varchar(30) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`),
  KEY `shop_id` (`shop_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rs_settings` (
  `k` varchar(50) NOT NULL,
  `v` longtext NOT NULL,
  PRIMARY KEY (`k`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rs_shops` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(80) NOT NULL,
  `address` varchar(120) DEFAULT NULL,
  `job` varchar(40) NOT NULL,
  `job_label` varchar(60) DEFAULT NULL,
  `society` varchar(40) NOT NULL,
  `mat_prefix` varchar(8) NOT NULL DEFAULT 'RS-',
  `enabled` tinyint(1) NOT NULL DEFAULT 0,
  `deleted` tinyint(1) NOT NULL DEFAULT 0,
  `points` longtext DEFAULT NULL,
  `options` longtext DEFAULT NULL,
  `created_by` varchar(100) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `job` (`job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rs_transactions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `shop_id` int(11) NOT NULL,
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
  PRIMARY KEY (`id`),
  UNIQUE KEY `txid` (`txid`),
  KEY `shop_id` (`shop_id`),
  KEY `category` (`category`),
  KEY `created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Remboursements en pesos d'un client absent (remis à sa prochaine connexion)
CREATE TABLE IF NOT EXISTS `rs_refunds` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `item` varchar(40) NOT NULL,
  `amount` int(11) NOT NULL,
  `reason` varchar(160) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Base déjà installée avant la version 1.1 (la ressource le fait seule au démarrage) :
-- ALTER TABLE `rs_orders` ADD COLUMN `paid` INT NULL AFTER `method`;
