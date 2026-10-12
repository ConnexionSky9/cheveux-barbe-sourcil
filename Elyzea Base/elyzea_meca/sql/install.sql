-- =====================================================================
--  ELYZEA MÉCANO - tables (créées AUTOMATIQUEMENT au démarrage de la ressource)
--  Ce fichier contient les mêmes requêtes, pour une installation manuelle.
--  Une ancienne table `meca_*` d'une autre structure est renommée en `*_ancien`
--  par la ressource au démarrage : rien n'est supprimé.
--  Le catalogue et les grades de départ sont créés par la ressource
--  (config.lua) au premier démarrage.
-- =====================================================================

CREATE TABLE IF NOT EXISTS `meca_settings` (
    `k` VARCHAR(50) NOT NULL PRIMARY KEY,
    `v` LONGTEXT NOT NULL ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `meca_grades` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(50) NOT NULL UNIQUE,
    `level` INT NOT NULL UNIQUE,
    `salary` INT NOT NULL DEFAULT 0,
    `perms` TEXT NOT NULL,
    `is_default` TINYINT(1) NOT NULL DEFAULT 0,
    `active` TINYINT(1) NOT NULL DEFAULT 1 ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `meca_employees` (
    `citizenid` VARCHAR(50) NOT NULL PRIMARY KEY,
    `name` VARCHAR(100) NOT NULL,
    `matricule` VARCHAR(20) NOT NULL UNIQUE,
    `grade_id` INT NOT NULL,
    `recruited_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `promoted_at` DATETIME NULL,
    `note` VARCHAR(255) NULL,
    `total_seconds` INT NOT NULL DEFAULT 0,
    `unpaid_seconds` INT NOT NULL DEFAULT 0,
    `unpaid_amount` DOUBLE NOT NULL DEFAULT 0 ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `meca_admin_log` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `actor_cid` VARCHAR(50) NULL, `actor_name` VARCHAR(100) NULL,
    `target_cid` VARCHAR(50) NULL, `target_name` VARCHAR(100) NULL,
    `action` VARCHAR(40) NOT NULL,
    `old_grade` VARCHAR(50) NULL, `new_grade` VARCHAR(50) NULL,
    `reason` VARCHAR(255) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX (`target_cid`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `meca_sessions` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL, `name` VARCHAR(100) NULL,
    `grade_name` VARCHAR(50) NULL,
    `started_at` DATETIME NOT NULL, `ended_at` DATETIME NULL,
    `seconds` INT NOT NULL DEFAULT 0,
    `amount` DOUBLE NOT NULL DEFAULT 0,
    `end_reason` VARCHAR(30) NULL,
    INDEX (`citizenid`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `meca_rates` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `grade_id` INT NOT NULL, `grade_name` VARCHAR(50) NULL,
    `rate` INT NOT NULL,
    `actor_name` VARCHAR(100) NULL,
    `effective_from` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX (`grade_id`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `meca_transactions` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
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
    INDEX (`category`), INDEX (`target_cid`), INDEX (`created_at`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `meca_catalog` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `code` VARCHAR(40) NOT NULL UNIQUE,
    `name` VARCHAR(80) NOT NULL,
    `description` VARCHAR(255) NULL,
    `category` VARCHAR(20) NOT NULL,
    `kind` VARCHAR(12) NOT NULL,
    `mod_key` VARCHAR(20) NULL,
    `level` INT NULL,
    `price` INT NOT NULL DEFAULT 0,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `min_level` INT NOT NULL DEFAULT 1,
    `compat` VARCHAR(120) NULL,
    `sort` INT NOT NULL DEFAULT 0,
    `updated_by` VARCHAR(100) NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `meca_quotes` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `uid` VARCHAR(40) NOT NULL UNIQUE,
    `customer_cid` VARCHAR(50) NULL, `customer_name` VARCHAR(100) NULL,
    `vehicle_id` INT NULL, `plate` VARCHAR(15) NULL, `model` VARCHAR(60) NULL,
    `mechanic_cid` VARCHAR(50) NULL, `mechanic_name` VARCHAR(100) NULL,
    `workshop` VARCHAR(40) NULL,
    `items` LONGTEXT NOT NULL,
    `total` INT NOT NULL,
    `paid` INT NOT NULL DEFAULT 0,
    `refunded` INT NOT NULL DEFAULT 0,
    `method` VARCHAR(6) NULL,
    `status` VARCHAR(12) NOT NULL,
    `invoice_uid` VARCHAR(40) NULL,
    `tow_id` INT NULL,
    `note` VARCHAR(255) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NULL,
    INDEX (`customer_cid`), INDEX (`vehicle_id`), INDEX (`status`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `meca_invoices` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `uid` VARCHAR(40) NOT NULL UNIQUE,
    `quote_uid` VARCHAR(40) NOT NULL UNIQUE,
    `customer_cid` VARCHAR(50) NULL, `customer_name` VARCHAR(100) NULL,
    `vehicle_id` INT NULL, `plate` VARCHAR(15) NULL,
    `mechanic_name` VARCHAR(100) NULL,
    `items` LONGTEXT NOT NULL,
    `amount` INT NOT NULL,
    `status` VARCHAR(10) NOT NULL,
    `method` VARCHAR(6) NULL,
    `txid` VARCHAR(40) NULL,
    `note` VARCHAR(160) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NULL,
    INDEX (`customer_cid`), INDEX (`vehicle_id`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `meca_vehicle_history` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `vehicle_id` INT NULL, `plate` VARCHAR(15) NULL,
    `action` VARCHAR(40) NOT NULL,
    `details` VARCHAR(255) NULL,
    `ref` VARCHAR(40) NULL,
    `mechanic_cid` VARCHAR(50) NULL, `mechanic_name` VARCHAR(100) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX (`vehicle_id`), INDEX (`plate`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `meca_carplay` (
    `vehicle_id` INT NOT NULL PRIMARY KEY,
    `plate` VARCHAR(15) NULL,
    `invoice_uid` VARCHAR(40) NULL,
    `price` INT NOT NULL DEFAULT 0,
    `installed_by` VARCHAR(100) NULL,
    `installed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `meca_tow` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `source` VARCHAR(20) NOT NULL,
    `reason` VARCHAR(150) NOT NULL,
    `description` VARCHAR(255) NULL,
    `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL,
    `street` VARCHAR(120) NULL,
    `client_cid` VARCHAR(50) NULL, `client_name` VARCHAR(100) NULL, `client_phone` VARCHAR(20) NULL,
    `vehicle` VARCHAR(80) NULL, `plate` VARCHAR(15) NULL,
    `status` VARCHAR(12) NOT NULL DEFAULT 'pending',
    `assigned_cid` VARCHAR(50) NULL, `assigned_name` VARCHAR(100) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `closed_at` DATETIME NULL,
    INDEX (`status`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `meca_tow_log` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `tow_id` INT NOT NULL,
    `status` VARCHAR(12) NOT NULL,
    `actor_name` VARCHAR(100) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX (`tow_id`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
