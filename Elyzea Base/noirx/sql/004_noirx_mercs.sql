-- NOIR X : contrats de mercenaires (application Mercenaires)
-- Idempotent : peut être rejoué sans risque. Dates en horodatage Unix (secondes).

CREATE TABLE IF NOT EXISTS `noirx_merc_contracts` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `buyer`       VARCHAR(80)  NOT NULL,
  `buyer_name`  VARCHAR(80)  NULL,
  `target`      VARCHAR(80)  NOT NULL,
  `target_name` VARCHAR(80)  NOT NULL,
  `tier`        VARCHAR(16)  NOT NULL,
  `size`        TINYINT      NOT NULL,
  `price`       BIGINT       NOT NULL,
  `currency`    VARCHAR(8)   NOT NULL,
  `status`      VARCHAR(16)  NOT NULL,
  `refund`      BIGINT       NOT NULL DEFAULT 0,
  `note`        VARCHAR(120) NULL,
  `created_at`  BIGINT       NOT NULL,
  `deploy_at`   BIGINT       NOT NULL,
  `expires_at`  BIGINT       NOT NULL,
  `engaged_at`  BIGINT       NULL,
  `finished_at` BIGINT       NULL,
  PRIMARY KEY (`id`),
  KEY `ix_noirx_merc_buyer` (`buyer`, `created_at`),
  KEY `ix_noirx_merc_target` (`target`, `created_at`),
  KEY `ix_noirx_merc_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
