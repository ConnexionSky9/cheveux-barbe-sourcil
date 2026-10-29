-- =====================================================================
--  ELYZEA BOÎTE DE NUIT - tables (créées automatiquement au démarrage)
--  Ce fichier ne sert que pour une installation manuelle.
-- =====================================================================
CREATE TABLE IF NOT EXISTS `cl_settings` (`k` VARCHAR(50) NOT NULL PRIMARY KEY, `v` LONGTEXT NOT NULL) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cl_shops` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(80) NOT NULL,
        `address` VARCHAR(120) NULL,
        `job` VARCHAR(40) NOT NULL UNIQUE,
        `job_label` VARCHAR(60) NULL,
        `society` VARCHAR(40) NOT NULL,
        `mat_prefix` VARCHAR(8) NOT NULL DEFAULT 'BN-',
        `enabled` TINYINT(1) NOT NULL DEFAULT 0,
        `deleted` TINYINT(1) NOT NULL DEFAULT 0,
        `points` LONGTEXT NULL,
        `options` LONGTEXT NULL,
        `created_by` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cl_grades` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `name` VARCHAR(50) NOT NULL,
        `level` INT NOT NULL,
        `salary` INT NOT NULL DEFAULT 0,
        `perms` TEXT NOT NULL,
        `is_default` TINYINT(1) NOT NULL DEFAULT 0,
        `active` TINYINT(1) NOT NULL DEFAULT 1,
        UNIQUE KEY `shop_level` (`shop_id`, `level`), UNIQUE KEY `shop_name` (`shop_id`, `name`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cl_employees` (
        `citizenid` VARCHAR(50) NOT NULL PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `name` VARCHAR(100) NOT NULL,
        `matricule` VARCHAR(20) NOT NULL,
        `grade_id` INT NOT NULL,
        `recruited_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `promoted_at` DATETIME NULL,
        `note` VARCHAR(255) NULL,
        `total_seconds` INT NOT NULL DEFAULT 0,
        `unpaid_seconds` INT NOT NULL DEFAULT 0,
        `unpaid_amount` DOUBLE NOT NULL DEFAULT 0,
        INDEX (`shop_id`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cl_admin_log` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `actor_cid` VARCHAR(50) NULL, `actor_name` VARCHAR(100) NULL,
        `target_cid` VARCHAR(50) NULL, `target_name` VARCHAR(100) NULL,
        `action` VARCHAR(40) NOT NULL,
        `old_grade` VARCHAR(50) NULL, `new_grade` VARCHAR(50) NULL,
        `reason` VARCHAR(255) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`shop_id`), INDEX (`target_cid`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cl_sessions` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `citizenid` VARCHAR(50) NOT NULL, `name` VARCHAR(100) NULL,
        `grade_name` VARCHAR(50) NULL,
        `started_at` DATETIME NOT NULL, `ended_at` DATETIME NULL,
        `seconds` INT NOT NULL DEFAULT 0,
        `amount` DOUBLE NOT NULL DEFAULT 0,
        `end_reason` VARCHAR(30) NULL,
        INDEX (`citizenid`), INDEX (`shop_id`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cl_rates` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `grade_id` INT NOT NULL, `grade_name` VARCHAR(50) NULL,
        `rate` INT NOT NULL,
        `actor_name` VARCHAR(100) NULL,
        `effective_from` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`shop_id`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cl_transactions` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `txid` VARCHAR(40) NOT NULL UNIQUE,
        `type` VARCHAR(10) NOT NULL,
        `category` VARCHAR(20) NOT NULL,
        `amount` INT NOT NULL,
        `reason` VARCHAR(160) NULL,
        `actor_cid` VARCHAR(50) NULL, `actor_name` VARCHAR(100) NULL,
        `target_cid` VARCHAR(50) NULL, `target_name` VARCHAR(100) NULL,
        `seconds` INT NULL,
        `ref` VARCHAR(40) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`shop_id`), INDEX (`category`), INDEX (`created_at`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cl_menu` (
        `shop_id` INT NOT NULL, `item` VARCHAR(50) NOT NULL,
        `price` INT NOT NULL, `stock` INT NOT NULL DEFAULT 0,
        `enabled` TINYINT(1) NOT NULL DEFAULT 1,
        PRIMARY KEY (`shop_id`, `item`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cl_sales` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `uid` VARCHAR(40) NOT NULL UNIQUE,
        `shop_id` INT NOT NULL,
        `kind` VARCHAR(10) NOT NULL DEFAULT 'bar',
        `lines` TEXT NULL,
        `price` INT NOT NULL DEFAULT 0,
        `method` VARCHAR(6) NULL,
        `buyer_cid` VARCHAR(50) NULL, `buyer_name` VARCHAR(100) NULL,
        `seller_cid` VARCHAR(50) NULL, `seller_name` VARCHAR(100) NULL,
        `status` VARCHAR(10) NOT NULL DEFAULT 'paid',
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`shop_id`), INDEX (`kind`), INDEX (`seller_cid`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cl_lists` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `kind` VARCHAR(5) NOT NULL,
        `citizenid` VARCHAR(50) NOT NULL, `name` VARCHAR(100) NULL,
        `reason` VARCHAR(160) NULL,
        `expires_at` INT NULL,
        `actor_name` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY `shop_kind_cid` (`shop_id`, `kind`, `citizenid`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cl_speakers` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `model` VARCHAR(60) NOT NULL,
        `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL, `h` DOUBLE NOT NULL DEFAULT 0,
        `placed_by` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`shop_id`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cl_tracks` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `yt` VARCHAR(16) NOT NULL,
        `title` VARCHAR(120) NULL,
        `duration` INT NOT NULL DEFAULT 0,
        `sort` INT NOT NULL DEFAULT 0,
        `broken` TINYINT(1) NOT NULL DEFAULT 0,
        `added_by` VARCHAR(100) NULL,
        INDEX (`shop_id`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cl_commission` (
    `grade_id` INT NOT NULL PRIMARY KEY,
    `pct` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `actor_name` VARCHAR(100) NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
