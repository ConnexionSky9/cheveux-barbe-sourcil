-- ELYZEA POLICE - tables (créées aussi automatiquement au démarrage de la ressource)
-- Les grades par défaut (Config.DefaultGrades) sont insérés au premier démarrage.

CREATE TABLE IF NOT EXISTS `police_grades` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(50) NOT NULL UNIQUE,
    `level` INT NOT NULL UNIQUE,
    `salary` INT NOT NULL DEFAULT 0,
    `perms` TEXT NOT NULL,
    `is_default` TINYINT(1) NOT NULL DEFAULT 0
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `police_employees` (
    `citizenid` VARCHAR(50) NOT NULL PRIMARY KEY,
    `name` VARCHAR(100) NOT NULL,
    `matricule` VARCHAR(20) NOT NULL UNIQUE,
    `grade_id` INT NOT NULL,
    `recruited_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `promoted_at` DATETIME NULL,
    `note` VARCHAR(255) NULL
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `police_admin_log` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `actor_cid` VARCHAR(50) NULL, `actor_name` VARCHAR(100) NULL,
    `target_cid` VARCHAR(50) NULL, `target_name` VARCHAR(100) NULL,
    `action` VARCHAR(40) NOT NULL,
    `old_grade` VARCHAR(50) NULL, `new_grade` VARCHAR(50) NULL,
    `reason` VARCHAR(255) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX (`target_cid`)
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `police_reports` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `title` VARCHAR(120) NOT NULL,
    `type` VARCHAR(40) NOT NULL,
    `people` TEXT NULL,
    `location` VARCHAR(120) NULL,
    `description` TEXT NULL,
    `observations` TEXT NULL,
    `attachments` TEXT NULL,
    `status` VARCHAR(20) NOT NULL DEFAULT 'open',
    `author_cid` VARCHAR(50) NOT NULL, `author_name` VARCHAR(100) NOT NULL, `author_matricule` VARCHAR(20) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX (`type`), INDEX (`status`), INDEX (`author_cid`)
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `police_report_history` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `report_id` INT NOT NULL,
    `actor_name` VARCHAR(100) NULL,
    `action` VARCHAR(120) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX (`report_id`)
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `police_fines` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL, `name` VARCHAR(100) NOT NULL,
    `offense` VARCHAR(100) NOT NULL, `reason` VARCHAR(150) NULL, `description` VARCHAR(500) NULL,
    `amount` INT NOT NULL,
    `officer_cid` VARCHAR(50) NULL, `officer_name` VARCHAR(100) NULL, `officer_matricule` VARCHAR(20) NULL,
    `paid` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX (`citizenid`)
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `police_alerts` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `kind` VARCHAR(10) NOT NULL,
    `type` VARCHAR(20) NOT NULL,
    `title` VARCHAR(100) NULL, `description` VARCHAR(255) NULL,
    `x` FLOAT NOT NULL DEFAULT 0, `y` FLOAT NOT NULL DEFAULT 0, `z` FLOAT NOT NULL DEFAULT 0,
    `street` VARCHAR(120) NULL,
    `author_cid` VARCHAR(50) NULL, `author_name` VARCHAR(100) NULL,
    `status` VARCHAR(10) NOT NULL DEFAULT 'active',
    `closed_by` VARCHAR(100) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `closed_at` DATETIME NULL,
    INDEX (`status`)
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

