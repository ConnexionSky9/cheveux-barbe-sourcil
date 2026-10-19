-- =====================================================================
--  ELYZEA EMS - tables (créées AUTOMATIQUEMENT au démarrage de la ressource)
--  Ce fichier contient les mêmes requêtes, pour une installation manuelle.
--  Une ancienne table `ems_ppa` d'une autre structure (ancien EMS) est renommée
--  en `ems_ppa_ancien` par la ressource au démarrage : rien n'est supprimé.
-- =====================================================================

CREATE TABLE IF NOT EXISTS `ems_settings` (
    `k` VARCHAR(50) NOT NULL PRIMARY KEY,
    `v` LONGTEXT NOT NULL ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ems_grades` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(50) NOT NULL UNIQUE,
    `level` INT NOT NULL UNIQUE,
    `salary` INT NOT NULL DEFAULT 0,
    `perms` TEXT NOT NULL,
    `is_default` TINYINT(1) NOT NULL DEFAULT 0 ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ems_employees` (
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

CREATE TABLE IF NOT EXISTS `ems_admin_log` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `actor_cid` VARCHAR(50) NULL, `actor_name` VARCHAR(100) NULL,
    `target_cid` VARCHAR(50) NULL, `target_name` VARCHAR(100) NULL,
    `action` VARCHAR(40) NOT NULL,
    `old_grade` VARCHAR(50) NULL, `new_grade` VARCHAR(50) NULL,
    `reason` VARCHAR(255) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX (`target_cid`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ems_sessions` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL, `name` VARCHAR(100) NULL,
    `grade_name` VARCHAR(50) NULL,
    `started_at` DATETIME NOT NULL, `ended_at` DATETIME NULL,
    `seconds` INT NOT NULL DEFAULT 0,
    `amount` DOUBLE NOT NULL DEFAULT 0,
    `end_reason` VARCHAR(30) NULL,
    INDEX (`citizenid`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ems_rates` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `grade_id` INT NOT NULL, `grade_name` VARCHAR(50) NULL,
    `rate` INT NOT NULL,
    `actor_name` VARCHAR(100) NULL,
    `effective_from` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX (`grade_id`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ems_transactions` (
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

CREATE TABLE IF NOT EXISTS `ems_calls` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `source` VARCHAR(20) NOT NULL,
    `reason` VARCHAR(150) NOT NULL,
    `urgency` TINYINT NOT NULL DEFAULT 2,
    `info` VARCHAR(255) NULL,
    `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL,
    `street` VARCHAR(120) NULL,
    `caller_cid` VARCHAR(50) NULL, `caller_name` VARCHAR(100) NULL,
    `patient_cid` VARCHAR(50) NULL, `patient_name` VARCHAR(100) NULL,
    `status` VARCHAR(12) NOT NULL DEFAULT 'pending',
    `assigned_cid` VARCHAR(50) NULL, `assigned_name` VARCHAR(100) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `closed_at` DATETIME NULL,
    INDEX (`status`), INDEX (`patient_cid`), INDEX (`created_at`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ems_call_log` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `call_id` INT NOT NULL,
    `status` VARCHAR(12) NOT NULL,
    `actor_name` VARCHAR(100) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX (`call_id`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ems_support` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `level` VARCHAR(10) NOT NULL,
    `description` VARCHAR(200) NULL,
    `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL,
    `street` VARCHAR(120) NULL,
    `author_cid` VARCHAR(50) NULL, `author_name` VARCHAR(100) NULL,
    `status` VARCHAR(10) NOT NULL DEFAULT 'active',
    `closed_by` VARCHAR(100) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `closed_at` DATETIME NULL ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ems_treatments` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `patient_cid` VARCHAR(50) NOT NULL, `patient_name` VARCHAR(100) NULL,
    `service` VARCHAR(20) NOT NULL,
    `ems_cid` VARCHAR(50) NULL, `ems_name` VARCHAR(100) NULL,
    `call_id` INT NULL,
    `invoice_uid` VARCHAR(40) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX (`patient_cid`), INDEX (`invoice_uid`), INDEX (`created_at`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ems_invoices` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `uid` VARCHAR(40) NOT NULL UNIQUE,
    `kind` VARCHAR(12) NOT NULL DEFAULT 'medical',
    `patient_cid` VARCHAR(50) NOT NULL, `patient_name` VARCHAR(100) NULL,
    `ems_cid` VARCHAR(50) NULL, `ems_name` VARCHAR(100) NULL,
    `items` TEXT NULL,
    `mode` VARCHAR(10) NULL,
    `amount` INT NOT NULL,
    `status` VARCHAR(10) NOT NULL,
    `method` VARCHAR(6) NULL,
    `txid` VARCHAR(40) NULL,
    `note` VARCHAR(160) NULL,
    `handled_by` VARCHAR(100) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NULL,
    INDEX (`patient_cid`), INDEX (`status`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ems_ppa` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `uid` VARCHAR(40) NOT NULL UNIQUE,
    `citizenid` VARCHAR(50) NOT NULL, `name` VARCHAR(100) NULL,
    `type` VARCHAR(6) NOT NULL,
    `ems_cid` VARCHAR(50) NULL, `ems_name` VARCHAR(100) NULL, `ems_grade` VARCHAR(50) NULL,
    `price` INT NOT NULL,
    `invoice_uid` VARCHAR(40) NULL,
    `payment_status` VARCHAR(12) NOT NULL,
    `delivery_status` VARCHAR(12) NOT NULL,
    `number` VARCHAR(20) NULL,
    `reason` VARCHAR(160) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NULL,
    INDEX (`citizenid`), INDEX (`type`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ems_patients` (
    `citizenid` VARCHAR(50) NOT NULL PRIMARY KEY,
    `name` VARCHAR(100) NULL,
    `blood` VARCHAR(5) NULL,
    `allergies` VARCHAR(255) NULL,
    `notes` TEXT NULL,
    `updated_by` VARCHAR(100) NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ems_reports` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `patient_cid` VARCHAR(50) NULL, `patient_name` VARCHAR(100) NULL,
    `call_id` INT NULL,
    `title` VARCHAR(120) NOT NULL,
    `crew` TEXT NULL,
    `started_at` DATETIME NULL, `ended_at` DATETIME NULL,
    `treatments` TEXT NULL,
    `transport` TINYINT(1) NOT NULL DEFAULT 0,
    `outcome` VARCHAR(40) NULL,
    `notes` TEXT NULL,
    `status` VARCHAR(10) NOT NULL DEFAULT 'open',
    `author_cid` VARCHAR(50) NOT NULL, `author_name` VARCHAR(100) NOT NULL, `author_matricule` VARCHAR(20) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX (`patient_cid`), INDEX (`status`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ems_report_history` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `report_id` INT NOT NULL,
    `actor_name` VARCHAR(100) NULL,
    `action` VARCHAR(120) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX (`report_id`) ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
