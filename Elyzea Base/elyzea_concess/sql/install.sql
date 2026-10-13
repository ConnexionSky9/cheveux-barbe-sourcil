-- =====================================================================
--  ELYZEA CONCESSION - tables (créées AUTOMATIQUEMENT au démarrage de la ressource)
--  Ce fichier contient les mêmes requêtes, pour une installation manuelle.
--  Préfixe cd_ : aucune collision avec d'anciennes tables concess_* (non modifiées).
--  Les véhicules vendus vont dans `player_vehicles` (table d'elyzea_core) : aucune
--  autre table de propriété n'est créée. Les catégories de départ sont ajoutées
--  par la ressource au premier démarrage.
-- =====================================================================

CREATE TABLE IF NOT EXISTS `cd_settings` (`k` VARCHAR(50) NOT NULL PRIMARY KEY, `v` LONGTEXT NOT NULL) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cd_shops` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(80) NOT NULL,
        `address` VARCHAR(120) NULL,
        `job` VARCHAR(40) NOT NULL UNIQUE,
        `job_label` VARCHAR(60) NULL,
        `society` VARCHAR(40) NOT NULL,
        `mat_prefix` VARCHAR(8) NOT NULL DEFAULT 'CD-',
        `enabled` TINYINT(1) NOT NULL DEFAULT 0,
        `deleted` TINYINT(1) NOT NULL DEFAULT 0,
        `points` LONGTEXT NULL,
        `options` LONGTEXT NULL,
        `created_by` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cd_grades` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `name` VARCHAR(50) NOT NULL,
        `level` INT NOT NULL,
        `salary` INT NOT NULL DEFAULT 0,
        `perms` TEXT NOT NULL,
        `is_default` TINYINT(1) NOT NULL DEFAULT 0,
        `active` TINYINT(1) NOT NULL DEFAULT 1,
        UNIQUE KEY `shop_level` (`shop_id`, `level`), UNIQUE KEY `shop_name` (`shop_id`, `name`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cd_employees` (
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

CREATE TABLE IF NOT EXISTS `cd_admin_log` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `actor_cid` VARCHAR(50) NULL, `actor_name` VARCHAR(100) NULL,
        `target_cid` VARCHAR(50) NULL, `target_name` VARCHAR(100) NULL,
        `action` VARCHAR(40) NOT NULL,
        `old_grade` VARCHAR(50) NULL, `new_grade` VARCHAR(50) NULL,
        `reason` VARCHAR(255) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`shop_id`), INDEX (`target_cid`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cd_sessions` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `citizenid` VARCHAR(50) NOT NULL, `name` VARCHAR(100) NULL,
        `grade_name` VARCHAR(50) NULL,
        `started_at` DATETIME NOT NULL, `ended_at` DATETIME NULL,
        `seconds` INT NOT NULL DEFAULT 0,
        `amount` DOUBLE NOT NULL DEFAULT 0,
        `end_reason` VARCHAR(30) NULL,
        INDEX (`citizenid`), INDEX (`shop_id`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cd_rates` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `grade_id` INT NOT NULL, `grade_name` VARCHAR(50) NULL,
        `rate` INT NOT NULL,
        `actor_name` VARCHAR(100) NULL,
        `effective_from` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`shop_id`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cd_transactions` (
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

CREATE TABLE IF NOT EXISTS `cd_categories` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(50) NOT NULL UNIQUE,
        `description` VARCHAR(255) NULL,
        `icon` VARCHAR(16) NULL,
        `image` VARCHAR(255) NULL,
        `sort` INT NOT NULL DEFAULT 0,
        `enabled` TINYINT(1) NOT NULL DEFAULT 1,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cd_models` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `model` VARCHAR(50) NOT NULL UNIQUE,
        `label` VARCHAR(80) NOT NULL,
        `brand` VARCHAR(50) NULL,
        `category_id` INT NULL,
        `description` VARCHAR(500) NULL,
        `image` VARCHAR(255) NULL,
        `ref_price` INT NULL,
        `commercial` TINYINT(1) NOT NULL DEFAULT 1,
        `displayable` TINYINT(1) NOT NULL DEFAULT 1,
        `enabled` TINYINT(1) NOT NULL DEFAULT 1,
        `removed` TINYINT(1) NOT NULL DEFAULT 0,
        `vclass` INT NULL,
        `seats` INT NULL,
        `validated_by` VARCHAR(100) NULL,
        `created_by` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX (`category_id`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cd_catalog_log` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NULL, `model_id` INT NULL, `category_id` INT NULL,
        `action` VARCHAR(50) NOT NULL,
        `details` VARCHAR(255) NULL,
        `actor_name` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`shop_id`), INDEX (`model_id`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cd_shop_categories` (
        `shop_id` INT NOT NULL, `category_id` INT NOT NULL,
        `enabled` TINYINT(1) NOT NULL DEFAULT 1,
        `visible` TINYINT(1) NOT NULL DEFAULT 1,
        `sellable` TINYINT(1) NOT NULL DEFAULT 1,
        `sort` INT NOT NULL DEFAULT 0,
        PRIMARY KEY (`shop_id`, `category_id`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cd_shop_models` (
        `shop_id` INT NOT NULL, `model_id` INT NOT NULL,
        `enabled` TINYINT(1) NOT NULL DEFAULT 1,
        `visible` TINYINT(1) NOT NULL DEFAULT 1,
        `sellable` TINYINT(1) NOT NULL DEFAULT 1,
        `displayable` TINYINT(1) NOT NULL DEFAULT 1,
        `price` INT NULL,
        PRIMARY KEY (`shop_id`, `model_id`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cd_price_log` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NOT NULL, `model_id` INT NOT NULL, `model` VARCHAR(50) NULL,
        `old_price` INT NULL, `new_price` INT NULL,
        `actor_cid` VARCHAR(50) NULL, `actor_name` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`shop_id`, `model_id`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cd_slots` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `label` VARCHAR(40) NULL,
        `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL, `h` DOUBLE NOT NULL DEFAULT 0,
        `enabled` TINYINT(1) NOT NULL DEFAULT 1,
        INDEX (`shop_id`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cd_display` (
        `slot_id` INT NOT NULL PRIMARY KEY,
        `shop_id` INT NOT NULL,
        `model_id` INT NOT NULL, `model` VARCHAR(50) NOT NULL,
        `h` DOUBLE NULL,
        `color1` INT NULL, `color2` INT NULL,
        `placed_by` VARCHAR(100) NULL,
        `placed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`shop_id`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cd_sales` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `uid` VARCHAR(40) NOT NULL UNIQUE,
        `shop_id` INT NOT NULL,
        `model_id` INT NULL, `model` VARCHAR(50) NOT NULL, `label` VARCHAR(80) NULL, `category` VARCHAR(50) NULL,
        `list_price` INT NOT NULL DEFAULT 0, `discount` INT NOT NULL DEFAULT 0, `price` INT NOT NULL DEFAULT 0,
        `method` VARCHAR(6) NULL,
        `buyer_cid` VARCHAR(50) NOT NULL, `buyer_name` VARCHAR(100) NULL,
        `seller_cid` VARCHAR(50) NULL, `seller_name` VARCHAR(100) NULL,
        `plate` VARCHAR(15) NULL, `vehicle_id` INT NULL,
        `status` VARCHAR(10) NOT NULL DEFAULT 'paid',
        `delivery` VARCHAR(10) NOT NULL DEFAULT 'pending',
        `delivered_at` DATETIME NULL,
        `key_given` TINYINT(1) NOT NULL DEFAULT 0,
        `note` VARCHAR(160) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX (`shop_id`), INDEX (`buyer_cid`), INDEX (`delivery`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cd_commission` (
    `grade_id` INT NOT NULL PRIMARY KEY,
    `pct` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `actor_name` VARCHAR(100) NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
