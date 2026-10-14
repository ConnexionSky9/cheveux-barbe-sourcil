-- NOIR X : Dark Market (annonces, offres privées, transactions, colis, profils vendeurs)
-- Idempotent : peut être rejoué sans risque. Dates en horodatage Unix (secondes).

CREATE TABLE IF NOT EXISTS `noirx_market_listings` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `seller`       VARCHAR(80)  NOT NULL,
  `seller_alias` VARCHAR(24)  NOT NULL,
  `item`         VARCHAR(64)  NOT NULL,
  `label`        VARCHAR(80)  NOT NULL,
  `category`     VARCHAR(24)  NOT NULL,
  `quantity`     INT          NOT NULL,
  `initial_qty`  INT          NOT NULL,
  `price`        BIGINT       NOT NULL,
  `currency`     VARCHAR(8)   NOT NULL,
  `note`         VARCHAR(140) NULL,
  `status`       VARCHAR(12)  NOT NULL,
  `created_at`   BIGINT       NOT NULL,
  `expires_at`   BIGINT       NOT NULL,
  `closed_at`    BIGINT       NULL,
  PRIMARY KEY (`id`),
  KEY `ix_noirx_ml_status` (`status`, `expires_at`),
  KEY `ix_noirx_ml_seller` (`seller`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `noirx_market_offers` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `listing_id`  BIGINT UNSIGNED NOT NULL,
  `buyer`       VARCHAR(80)  NOT NULL,
  `buyer_alias` VARCHAR(24)  NOT NULL,
  `quantity`    INT          NOT NULL,
  `unit_price`  BIGINT       NOT NULL,
  `total`       BIGINT       NOT NULL,
  `currency`    VARCHAR(8)   NOT NULL,
  `status`      VARCHAR(12)  NOT NULL,
  `created_at`  BIGINT       NOT NULL,
  `expires_at`  BIGINT       NOT NULL,
  `closed_at`   BIGINT       NULL,
  PRIMARY KEY (`id`),
  KEY `ix_noirx_mo_listing` (`listing_id`, `status`),
  KEY `ix_noirx_mo_buyer` (`buyer`, `status`),
  KEY `ix_noirx_mo_status` (`status`, `expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `noirx_market_tx` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `listing_id`   BIGINT UNSIGNED NOT NULL,
  `offer_id`     BIGINT UNSIGNED NULL,
  `seller`       VARCHAR(80)  NOT NULL,
  `buyer`        VARCHAR(80)  NOT NULL,
  `seller_alias` VARCHAR(24)  NOT NULL,
  `buyer_alias`  VARCHAR(24)  NOT NULL,
  `item`         VARCHAR(64)  NOT NULL,
  `label`        VARCHAR(80)  NOT NULL,
  `quantity`     INT          NOT NULL,
  `unit_price`   BIGINT       NOT NULL,
  `total`        BIGINT       NOT NULL,
  `fee`          BIGINT       NOT NULL,
  `currency`     VARCHAR(8)   NOT NULL,
  `rating`       TINYINT      NULL,
  `created_at`   BIGINT       NOT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_noirx_mt_seller` (`seller`, `created_at`),
  KEY `ix_noirx_mt_buyer` (`buyer`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `noirx_market_pickups` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `owner`        VARCHAR(80)  NOT NULL,
  `item`         VARCHAR(64)  NOT NULL,
  `label`        VARCHAR(80)  NOT NULL,
  `quantity`     INT          NOT NULL,
  `reason`       VARCHAR(24)  NOT NULL,
  `ref`          VARCHAR(64)  NULL,
  `status`       VARCHAR(12)  NOT NULL,
  `created_at`   BIGINT       NOT NULL,
  `delivered_at` BIGINT       NULL,
  PRIMARY KEY (`id`),
  KEY `ix_noirx_mp_owner` (`owner`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `noirx_market_profiles` (
  `owner`       VARCHAR(80)  NOT NULL,
  `alias`       VARCHAR(24)  NULL,
  `sales`       INT          NOT NULL DEFAULT 0,
  `purchases`   INT          NOT NULL DEFAULT 0,
  `volume`      BIGINT       NOT NULL DEFAULT 0,
  `rating_up`   INT          NOT NULL DEFAULT 0,
  `rating_down` INT          NOT NULL DEFAULT 0,
  `banned`      TINYINT      NOT NULL DEFAULT 0,
  `ban_reason`  VARCHAR(120) NULL,
  PRIMARY KEY (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
