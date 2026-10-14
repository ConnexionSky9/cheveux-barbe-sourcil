-- NOIR X — schéma du lot 1 (téléphone + audit)
-- Compatible MySQL 5.7+ / MariaDB 10.3+. Idempotent : peut être rejoué sans risque.

CREATE TABLE IF NOT EXISTS `noirx_devices` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `owner`      VARCHAR(80)  NOT NULL,              -- Identity.GetCharacterId()
  `serial`     VARCHAR(16)  NOT NULL,
  `settings`   LONGTEXT     NULL,                  -- JSON validé côté serveur
  `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_noirx_devices_owner` (`owner`),
  UNIQUE KEY `uq_noirx_devices_serial` (`serial`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `noirx_audit` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `actor`      VARCHAR(80)  NOT NULL,
  `action`     VARCHAR(64)  NOT NULL,
  `details`    LONGTEXT     NULL,
  `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `ix_noirx_audit_actor` (`actor`),
  KEY `ix_noirx_audit_action_date` (`action`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
