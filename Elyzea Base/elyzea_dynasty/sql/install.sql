-- =====================================================================
--  ELYZEA DYNASTY 8 - tables (créées AUTOMATIQUEMENT au démarrage de la ressource)
--  Ce fichier contient les mêmes requêtes, pour une installation manuelle.
--  Les grades de départ et les intérieurs de départ (config.lua) sont ajoutés
--  par la ressource au premier démarrage.
--  Le véhicule rangé dans un bien utilise player_vehicles.state = 3 (aucune
--  colonne ajoutée à player_vehicles).
-- =====================================================================

CREATE TABLE IF NOT EXISTS `d8_settings` (
        `k` VARCHAR(50) NOT NULL PRIMARY KEY,
        `v` LONGTEXT NOT NULL ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `d8_grades` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(50) NOT NULL UNIQUE,
        `level` INT NOT NULL UNIQUE,
        `salary` INT NOT NULL DEFAULT 0,
        `perms` TEXT NOT NULL,
        `is_default` TINYINT(1) NOT NULL DEFAULT 0,
        `active` TINYINT(1) NOT NULL DEFAULT 1 ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `d8_employees` (
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

CREATE TABLE IF NOT EXISTS `d8_admin_log` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `actor_cid` VARCHAR(50) NULL, `actor_name` VARCHAR(100) NULL,
        `target_cid` VARCHAR(50) NULL, `target_name` VARCHAR(100) NULL,
        `action` VARCHAR(40) NOT NULL,
        `old_grade` VARCHAR(50) NULL, `new_grade` VARCHAR(50) NULL,
        `reason` VARCHAR(255) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`target_cid`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `d8_sessions` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `citizenid` VARCHAR(50) NOT NULL, `name` VARCHAR(100) NULL,
        `grade_name` VARCHAR(50) NULL,
        `started_at` DATETIME NOT NULL, `ended_at` DATETIME NULL,
        `seconds` INT NOT NULL DEFAULT 0,
        `amount` DOUBLE NOT NULL DEFAULT 0,
        `end_reason` VARCHAR(30) NULL,
        INDEX (`citizenid`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `d8_rates` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `grade_id` INT NOT NULL, `grade_name` VARCHAR(50) NULL,
        `rate` INT NOT NULL,
        `actor_name` VARCHAR(100) NULL,
        `effective_from` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`grade_id`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `d8_transactions` (
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

CREATE TABLE IF NOT EXISTS `d8_interiors` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `code` VARCHAR(40) NULL UNIQUE,
        `label` VARCHAR(60) NOT NULL,
        `kind` VARCHAR(12) NOT NULL,
        `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL, `h` DOUBLE NOT NULL DEFAULT 0,
        `ipls` TEXT NULL,
        `resource` VARCHAR(60) NULL,
        `notes` VARCHAR(255) NULL,
        `enabled` TINYINT(1) NOT NULL DEFAULT 1,
        `created_by` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `d8_properties` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(80) NOT NULL,
        `address` VARCHAR(120) NULL,
        `category` VARCHAR(12) NOT NULL,
        `interior_id` INT NULL,
        `status` VARCHAR(12) NOT NULL DEFAULT 'available',
        `enabled` TINYINT(1) NOT NULL DEFAULT 1,
        `sale_price` INT NOT NULL DEFAULT 0,
        `rent_price` INT NOT NULL DEFAULT 0,
        `extend_price` INT NULL,
        `rent_min_days` INT NOT NULL DEFAULT 1,
        `rent_max_days` INT NOT NULL DEFAULT 30,
        `for_sale` TINYINT(1) NOT NULL DEFAULT 1,
        `for_rent` TINYINT(1) NOT NULL DEFAULT 1,
        `code` VARCHAR(12) NULL,
        `points` LONGTEXT NULL,
        `garage` LONGTEXT NULL,
        `stash_slots` INT NOT NULL DEFAULT 50,
        `stash_weight` INT NOT NULL DEFAULT 150,
        `deco_limit` INT NOT NULL DEFAULT 40,
        `contract_id` INT NULL,
        `reserved_by` VARCHAR(100) NULL,
        `notes` VARCHAR(255) NULL,
        `created_by` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX (`status`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `d8_contracts` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `uid` VARCHAR(40) NOT NULL UNIQUE,
        `property_id` INT NOT NULL,
        `kind` VARCHAR(6) NOT NULL,
        `holder_cid` VARCHAR(50) NOT NULL, `holder_name` VARCHAR(100) NULL, `holder_phone` VARCHAR(20) NULL,
        `price` INT NOT NULL DEFAULT 0,
        `rate` INT NOT NULL DEFAULT 0,
        `days` INT NOT NULL DEFAULT 0,
        `paid_total` INT NOT NULL DEFAULT 0,
        `method` VARCHAR(6) NULL,
        `started_at` DATETIME NOT NULL,
        `ends_at` DATETIME NULL,
        `status` VARCHAR(10) NOT NULL DEFAULT 'active',
        `employee_cid` VARCHAR(50) NULL, `employee_name` VARCHAR(100) NULL,
        `stash_id` VARCHAR(80) NULL,
        `ended_at` DATETIME NULL, `end_reason` VARCHAR(120) NULL,
        INDEX (`property_id`), INDEX (`holder_cid`), INDEX (`status`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `d8_payments` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `txid` VARCHAR(40) NOT NULL UNIQUE,
        `contract_id` INT NULL, `property_id` INT NOT NULL,
        `kind` VARCHAR(10) NOT NULL,
        `amount` INT NOT NULL,
        `days` INT NULL,
        `method` VARCHAR(6) NULL,
        `payer_cid` VARCHAR(50) NULL, `payer_name` VARCHAR(100) NULL,
        `employee_name` VARCHAR(100) NULL,
        `status` VARCHAR(10) NOT NULL,
        `note` VARCHAR(160) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`contract_id`), INDEX (`property_id`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `d8_access` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `contract_id` INT NOT NULL, `property_id` INT NOT NULL,
        `cid` VARCHAR(50) NOT NULL, `name` VARCHAR(100) NULL,
        `can_stash` TINYINT(1) NOT NULL DEFAULT 0,
        `can_manage` TINYINT(1) NOT NULL DEFAULT 0,
        `can_garage` TINYINT(1) NOT NULL DEFAULT 0,
        `added_by` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY `contract_cid` (`contract_id`, `cid`), INDEX (`cid`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `d8_vehicles` (
        `vehicle_id` INT NOT NULL PRIMARY KEY,
        `property_id` INT NOT NULL,
        `slot` INT NOT NULL,
        `plate` VARCHAR(15) NULL, `model` VARCHAR(50) NULL,
        `owner_cid` VARCHAR(50) NULL,
        `stored_by` VARCHAR(100) NULL,
        `stored_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY `property_slot` (`property_id`, `slot`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `d8_deco` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `property_id` INT NOT NULL,
        `contract_id` INT NULL,
        `interior_id` INT NULL,
        `model` VARCHAR(60) NOT NULL,
        `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL,
        `rx` DOUBLE NOT NULL DEFAULT 0, `ry` DOUBLE NOT NULL DEFAULT 0, `rz` DOUBLE NOT NULL DEFAULT 0,
        `stored` TINYINT(1) NOT NULL DEFAULT 0,
        `placed_by` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`property_id`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `d8_visits` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `property_id` INT NOT NULL,
        `employee_cid` VARCHAR(50) NULL, `employee_name` VARCHAR(100) NULL,
        `clients` VARCHAR(255) NULL,
        `started_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `ended_at` DATETIME NULL, `end_reason` VARCHAR(60) NULL,
        INDEX (`property_id`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `d8_property_log` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `property_id` INT NOT NULL,
        `action` VARCHAR(40) NOT NULL,
        `details` VARCHAR(255) NULL,
        `actor_name` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`property_id`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
