-- NOIR X — schéma du lot 2 : réglages, paiements, identités, Dark Chat, Ratline, Blanchiment
-- Compatible MySQL 5.7+ / MariaDB 10.3+. Idempotent : peut être rejoué sans risque.
-- Les dates sont des horodatages Unix (secondes) pour rester indépendantes du fuseau du serveur SQL.

CREATE TABLE IF NOT EXISTS `noirx_settings` (
  `path`       VARCHAR(128) NOT NULL,
  `value`      LONGTEXT     NOT NULL,
  `updated_by` VARCHAR(80)  NULL,
  `updated_at` BIGINT       NOT NULL,
  PRIMARY KEY (`path`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `noirx_payouts` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `owner`      VARCHAR(80)  NOT NULL,
  `currency`   VARCHAR(8)   NOT NULL,
  `amount`     BIGINT       NOT NULL,
  `reason`     VARCHAR(64)  NULL,
  `ref`        VARCHAR(128) NULL,
  `status`     VARCHAR(16)  NOT NULL,
  `created_at` BIGINT       NOT NULL,
  `paid_at`    BIGINT       NULL,
  PRIMARY KEY (`id`),
  KEY `ix_noirx_payouts_owner_status` (`owner`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `noirx_identities` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `owner`      VARCHAR(80)  NOT NULL,
  `handle`     VARCHAR(24)  NOT NULL,
  `handle_lc`  VARCHAR(24)  NOT NULL,
  `kind`       VARCHAR(8)   NOT NULL,
  `reputation` INT          NOT NULL DEFAULT 0,
  `created_at` BIGINT       NOT NULL,
  `expires_at` BIGINT       NULL,
  `revoked`    TINYINT      NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_noirx_identities_handle` (`handle_lc`),
  KEY `ix_noirx_identities_owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `noirx_contacts` (
  `owner_identity`   BIGINT UNSIGNED NOT NULL,
  `contact_identity` BIGINT UNSIGNED NOT NULL,
  `status`     VARCHAR(12)  NOT NULL,
  `alias`      VARCHAR(24)  NOT NULL DEFAULT '',
  `favorite`   TINYINT      NOT NULL DEFAULT 0,
  `blocked`    TINYINT      NOT NULL DEFAULT 0,
  `trust`      TINYINT      NOT NULL DEFAULT 0,
  `created_at` BIGINT       NOT NULL,
  PRIMARY KEY (`owner_identity`, `contact_identity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `noirx_ratings` (
  `rater`      BIGINT UNSIGNED NOT NULL,
  `target`     BIGINT UNSIGNED NOT NULL,
  `value`      TINYINT      NOT NULL,
  `updated_at` BIGINT       NOT NULL,
  PRIMARY KEY (`rater`, `target`),
  KEY `ix_noirx_ratings_target` (`target`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `noirx_conversations` (
  `id`              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `kind`            VARCHAR(8)   NOT NULL,
  `name`            VARCHAR(32)  NOT NULL DEFAULT '',
  `owner_identity`  BIGINT UNSIGNED NOT NULL,
  `ephemeral`       INT          NOT NULL DEFAULT 0,
  `created_at`      BIGINT       NOT NULL,
  `last_message_at` BIGINT       NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `noirx_conv_members` (
  `conversation_id` BIGINT UNSIGNED NOT NULL,
  `identity_id`     BIGINT UNSIGNED NOT NULL,
  `role`         VARCHAR(8)   NOT NULL,
  `status`       VARCHAR(8)   NOT NULL,
  `last_read_id` BIGINT       NOT NULL DEFAULT 0,
  `since_id`     BIGINT       NOT NULL DEFAULT 0,
  `favorite`     TINYINT      NOT NULL DEFAULT 0,
  `joined_at`    BIGINT       NOT NULL,
  PRIMARY KEY (`conversation_id`, `identity_id`),
  KEY `ix_noirx_conv_members_identity` (`identity_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `noirx_messages` (
  `id`              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `conversation_id` BIGINT UNSIGNED NOT NULL,
  `sender_identity` BIGINT UNSIGNED NOT NULL,
  `body`       TEXT         NOT NULL,
  `created_at` BIGINT       NOT NULL,
  `expires_at` BIGINT       NULL,
  PRIMARY KEY (`id`),
  KEY `ix_noirx_messages_conv` (`conversation_id`, `id`),
  KEY `ix_noirx_messages_expires` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `noirx_informants` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`       VARCHAR(40)  NOT NULL,
  `tagline`    VARCHAR(80)  NOT NULL DEFAULT '',
  `greeting`   VARCHAR(240) NOT NULL DEFAULT '',
  `enabled`    TINYINT      NOT NULL DEFAULT 1,
  `sort_order` INT          NOT NULL DEFAULT 0,
  `created_at` BIGINT       NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `noirx_intel` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `informant_id` BIGINT UNSIGNED NOT NULL,
  `category`     VARCHAR(24)  NOT NULL,
  `title`        VARCHAR(80)  NOT NULL,
  `keywords`     VARCHAR(255) NOT NULL DEFAULT '',
  `answer`       TEXT         NOT NULL,
  `x`            DOUBLE       NULL,
  `y`            DOUBLE       NULL,
  `z`            DOUBLE       NULL,
  `price`        BIGINT       NOT NULL DEFAULT 0,
  `currency`     VARCHAR(8)   NOT NULL DEFAULT 'dirty',
  `reliability`  TINYINT      NOT NULL DEFAULT 100,
  `enabled`      TINYINT      NOT NULL DEFAULT 1,
  `expires_at`   BIGINT       NULL,
  `sort_order`   INT          NOT NULL DEFAULT 0,
  `created_at`   BIGINT       NOT NULL,
  `updated_at`   BIGINT       NOT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_noirx_intel_informant` (`informant_id`, `enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `noirx_intel_purchases` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `owner`      VARCHAR(80)  NOT NULL,
  `intel_id`   BIGINT UNSIGNED NOT NULL,
  `price`      BIGINT       NOT NULL DEFAULT 0,
  `currency`   VARCHAR(8)   NOT NULL,
  `created_at` BIGINT       NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_noirx_intel_purchase` (`owner`, `intel_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `noirx_ratline_log` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `owner`        VARCHAR(80)  NOT NULL,
  `informant_id` BIGINT UNSIGNED NOT NULL,
  `sender`       VARCHAR(4)   NOT NULL,
  `body`         TEXT         NOT NULL,
  `intel_id`     BIGINT UNSIGNED NULL,
  `has_gps`      TINYINT      NOT NULL DEFAULT 0,
  `created_at`   BIGINT       NOT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_noirx_ratline_log_owner` (`owner`, `informant_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `noirx_launder_jobs` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `owner`         VARCHAR(80)  NOT NULL,
  `amount`        BIGINT       NOT NULL,
  `fee`           BIGINT       NOT NULL,
  `net`           BIGINT       NOT NULL,
  `stolen`        BIGINT       NOT NULL DEFAULT 0,
  `status`        VARCHAR(12)  NOT NULL,
  `started_at`    BIGINT       NOT NULL,
  `ends_at`       BIGINT       NOT NULL,
  `finished_at`   BIGINT       NULL,
  `npc_attack_at` BIGINT       NULL,
  `attacks`       INT          NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `ix_noirx_launder_owner` (`owner`, `status`),
  KEY `ix_noirx_launder_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `noirx_launder_attacks` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `job_id`      BIGINT UNSIGNED NOT NULL,
  `attacker`    VARCHAR(80)  NOT NULL,
  `line`        VARCHAR(64)  NOT NULL,
  `started_at`  BIGINT       NOT NULL,
  `winner`      VARCHAR(10)  NULL,
  `loss`        BIGINT       NOT NULL DEFAULT 0,
  `resolved_at` BIGINT       NULL,
  PRIMARY KEY (`id`),
  KEY `ix_noirx_launder_attacks_job` (`job_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
