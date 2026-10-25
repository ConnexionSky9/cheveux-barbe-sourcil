-- =====================================================================
--  elyzea_shop — tables (base de données du serveur de jeu)
--  À importer une fois (HeidiSQL, phpMyAdmin ou : mysql -u ... nom_base < sql/install.sql).
--  La ressource crée aussi ces tables au démarrage si elles manquent (CREATE TABLE IF NOT EXISTS).
--  Aucune table existante du serveur n'est modifiée.
--  « account » = identifiant Cfx.re numérique du joueur (identifiant fivem:XXXX), commun à tous ses personnages.
-- =====================================================================

-- Livraisons : une ligne par (transaction, produit, action). La clé unique rend chaque livraison idempotente.
CREATE TABLE IF NOT EXISTS `elyzea_shop_deliveries` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `transaction_id` VARCHAR(64)  NOT NULL,                  -- transaction Tebex, ou « coins-… » / « admin-… »
  `product_key`    VARCHAR(48)  NOT NULL,
  `action`         ENUM('grant','revoke') NOT NULL,
  `account`        VARCHAR(32)  NOT NULL,
  `source`         VARCHAR(16)  NOT NULL,                  -- tebex, coins, admin
  `status`         ENUM('pending','delivered','failed','cancelled') NOT NULL DEFAULT 'pending',
  `attempts`       INT UNSIGNED NOT NULL DEFAULT 0,
  `last_error`     VARCHAR(255) NULL,
  `progress`       LONGTEXT     NULL,                      -- récompenses déjà exécutées + détails (plaque…), JSON
  `created_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `delivered_at`   DATETIME     NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_delivery` (`transaction_id`, `product_key`, `action`),
  KEY `ix_delivery_account` (`account`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Grades / avantages actifs (réappliqués à chaque connexion, retirés à l'expiration)
CREATE TABLE IF NOT EXISTS `elyzea_shop_entitlements` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `account`        VARCHAR(32)  NOT NULL,
  `kind`           ENUM('group','perk') NOT NULL,
  `name`           VARCHAR(32)  NOT NULL,
  `product_key`    VARCHAR(48)  NOT NULL,
  `transaction_id` VARCHAR(64)  NOT NULL,
  `expires_at`     DATETIME     NULL,
  `active`         TINYINT(1)   NOT NULL DEFAULT 1,
  `created_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_entitlement` (`transaction_id`, `product_key`, `kind`, `name`),
  KEY `ix_ent_account` (`account`, `active`),
  KEY `ix_ent_expiry` (`active`, `expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Solde Elyzea Coins par compte. UNSIGNED : un débit supérieur au solde provoque une erreur SQL
-- (« out of range ») et annule toute la transaction : le solde ne peut jamais devenir négatif.
CREATE TABLE IF NOT EXISTS `elyzea_shop_coins` (
  `account`    VARCHAR(32)  NOT NULL,
  `balance`    INT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`account`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Historique des mouvements de coins
CREATE TABLE IF NOT EXISTS `elyzea_shop_coin_log` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `account`       VARCHAR(32)  NOT NULL,
  `delta`         INT          NOT NULL,
  `balance_after` INT UNSIGNED NOT NULL,
  `reason`        VARCHAR(64)  NOT NULL,
  `ref`           VARCHAR(96)  NULL,                       -- référence unique (transaction) : pas de double crédit
  `actor`         VARCHAR(64)  NULL,
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_coin_ref` (`ref`),
  KEY `ix_coin_account` (`account`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Journal (erreurs, actions administratives, commandes Tebex reçues)
CREATE TABLE IF NOT EXISTS `elyzea_shop_logs` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `level`      ENUM('info','warn','error') NOT NULL DEFAULT 'info',
  `action`     VARCHAR(48)  NOT NULL,
  `account`    VARCHAR(32)  NULL,
  `ref`        VARCHAR(96)  NULL,
  `details`    TEXT         NULL,
  `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `ix_logs` (`level`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
