-- =====================================================================
--  ELYZEA FAMILLE - tables (créées automatiquement au démarrage de la ressource ;
--  ce fichier contient exactement les mêmes requêtes, pour une installation manuelle).
--  Dates : secondes Unix (BIGINT), indépendantes du fuseau horaire du serveur MySQL.
-- =====================================================================

-- État contraceptif durable d'un personnage (privé)
CREATE TABLE IF NOT EXISTS `rp_contraception` (
    `citizenid`          VARCHAR(64) NOT NULL,
    `pill_until`         BIGINT      NOT NULL DEFAULT 0,
    `implant_until`      BIGINT      NOT NULL DEFAULT 0,
    `prescription_until` BIGINT      NOT NULL DEFAULT 0,
    `updated_at`         BIGINT      NOT NULL DEFAULT 0,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Historique contraceptif (prises, poses, ordonnances, préservatifs)
CREATE TABLE IF NOT EXISTS `rp_contraception_log` (
    `id`         BIGINT      NOT NULL AUTO_INCREMENT,
    `citizenid`  VARCHAR(64) NOT NULL,
    `methode`    VARCHAR(24) NOT NULL,
    `action`     VARCHAR(24) NOT NULL,
    `at`         BIGINT      NOT NULL,
    `par`        VARCHAR(64) NULL,
    `jusqu_a`    BIGINT      NULL,
    `ref`        VARCHAR(24) NULL,
    PRIMARY KEY (`id`),
    KEY `idx_cid_at` (`citizenid`, `at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Moments intimes (une ligne par interaction acceptée)
CREATE TABLE IF NOT EXISTS `rp_intimacy_sessions` (
    `id`          VARCHAR(16) NOT NULL,
    `a_cid`       VARCHAR(64) NOT NULL,
    `b_cid`       VARCHAR(64) NOT NULL,
    `status`      VARCHAR(16) NOT NULL DEFAULT 'active',   -- active | terminee | annulee | interrompue
    `volontaire`  TINYINT(1)  NOT NULL DEFAULT 0,
    `preservatif` VARCHAR(64) NULL,                          -- citizenid de la personne qui l'a fourni
    `duree`       INT         NOT NULL,
    `started_at`  BIGINT      NOT NULL,
    `ended_at`    BIGINT      NULL,
    `end_reason`  VARCHAR(32) NULL,
    PRIMARY KEY (`id`),
    KEY `idx_a` (`a_cid`, `started_at`),
    KEY `idx_b` (`b_cid`, `started_at`),
    KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tentatives de conception : UNE au maximum par moment intime (contrainte unique)
CREATE TABLE IF NOT EXISTS `rp_conception_attempts` (
    `id`           BIGINT      NOT NULL AUTO_INCREMENT,
    `session_id`   VARCHAR(16) NOT NULL,
    `porteur_cid`  VARCHAR(64) NULL,
    `partenaire_cid` VARCHAR(64) NULL,
    `resultat`     VARCHAR(32) NOT NULL,
    `raison`       VARCHAR(32) NULL,
    `volontaire`   TINYINT(1)  NOT NULL DEFAULT 0,
    `protections`  TEXT        NULL,
    `probabilite`  DOUBLE      NOT NULL DEFAULT 0,
    `tirage`       DOUBLE      NULL,
    `pregnancy_id` VARCHAR(16) NULL,
    `created_at`   BIGINT      NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_session` (`session_id`),
    KEY `idx_porteur` (`porteur_cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Grossesses. `active_key` = citizenid tant que la grossesse est en cours, NULL ensuite :
-- l'index unique empêche deux grossesses simultanées chez la même personne.
CREATE TABLE IF NOT EXISTS `rp_pregnancies` (
    `id`            VARCHAR(16) NOT NULL,
    `porteur_cid`   VARCHAR(64) NOT NULL,
    `partenaire_cid` VARCHAR(64) NULL,
    `session_id`    VARCHAR(16) NULL,
    `bebes`         TINYINT     NOT NULL DEFAULT 1,
    `bebes_connus`  TINYINT(1)  NOT NULL DEFAULT 0,             -- 1 après un examen EMS
    `conceived_at`  BIGINT      NOT NULL,
    `due_at`        BIGINT      NOT NULL,
    `status`        VARCHAR(16) NOT NULL DEFAULT 'en_cours',  -- en_cours | accouchee | terminee
    `active_key`    VARCHAR(64) NULL,
    `discovered_at` BIGINT      NULL,
    `ended_at`      BIGINT      NULL,
    `created_at`    BIGINT      NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_active` (`active_key`),
    UNIQUE KEY `uniq_session` (`session_id`),
    KEY `idx_porteur` (`porteur_cid`),
    KEY `idx_due` (`status`, `due_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Événements d'une grossesse (conception, symptômes, examens… : modules suivants)
CREATE TABLE IF NOT EXISTS `rp_pregnancy_events` (
    `id`           BIGINT      NOT NULL AUTO_INCREMENT,
    `pregnancy_id` VARCHAR(16) NOT NULL,
    `kind`         VARCHAR(32) NOT NULL,
    `at`           BIGINT      NOT NULL,
    `data`         TEXT        NULL,
    PRIMARY KEY (`id`),
    KEY `idx_preg` (`pregnancy_id`, `at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Journal d'audit (actions sensibles, refus, tentatives suspectes)
CREATE TABLE IF NOT EXISTS `rp_famille_logs` (
    `id`      BIGINT       NOT NULL AUTO_INCREMENT,
    `at`      BIGINT       NOT NULL,
    `acteur`  VARCHAR(64)  NULL,
    `action`  VARCHAR(48)  NOT NULL,
    `cible`   VARCHAR(64)  NULL,
    `details` TEXT         NULL,
    PRIMARY KEY (`id`),
    KEY `idx_at` (`at`),
    KEY `idx_acteur` (`acteur`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Réglages modifiés depuis le menu admin (admin_menu › Famille). Vide = valeurs de config.lua.
CREATE TABLE IF NOT EXISTS `rp_famille_reglages` (
    `cle`        VARCHAR(64) NOT NULL,
    `valeur`     TEXT        NOT NULL,
    `updated_at` BIGINT      NOT NULL,
    `par`        VARCHAR(64) NULL,
    PRIMARY KEY (`cle`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
