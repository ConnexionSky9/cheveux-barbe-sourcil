-- =====================================================================
--  Boutique Elyzea : schéma initial (MySQL 8 / MariaDB 10.6+, InnoDB, utf8mb4)
--  Appliqué par `npm run migrate` (backend). Ne pas modifier une migration
--  déjà appliquée : en ajouter une nouvelle (002_..., 003_...).
-- =====================================================================

-- Comptes joueurs du site (créés à la première liaison avec le jeu)
CREATE TABLE users (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  cfx_id        VARCHAR(32)  NOT NULL,                 -- identifiant Cfx.re (fivem:xxxx), stable
  display_name  VARCHAR(64)  NOT NULL,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_login_at DATETIME     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_cfx (cfx_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Identifiants du jeu relevés par le serveur FiveM au moment de la liaison
CREATE TABLE linked_accounts (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id    INT UNSIGNED NOT NULL,
  kind       VARCHAR(16)  NOT NULL,                    -- fivem, license, license2, discord, steam
  value      VARCHAR(96)  NOT NULL,
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_linked (kind, value),
  KEY ix_linked_user (user_id),
  CONSTRAINT fk_linked_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Codes de liaison à usage unique, générés en jeu (/boutique_lier), stockés hachés
CREATE TABLE link_codes (
  code_hash    CHAR(64)    NOT NULL,
  cfx_id       VARCHAR(32) NOT NULL,
  display_name VARCHAR(64) NOT NULL,
  identifiers  JSON        NOT NULL,
  expires_at   DATETIME    NOT NULL,
  used_at      DATETIME    NULL,
  created_at   DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (code_hash),
  KEY ix_link_cfx (cfx_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Administrateurs du panel (mots de passe bcrypt)
CREATE TABLE admins (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  username        VARCHAR(32)  NOT NULL,
  password_hash   VARCHAR(100) NOT NULL,
  role            ENUM('owner','admin','support') NOT NULL DEFAULT 'support',
  active          TINYINT(1)   NOT NULL DEFAULT 1,
  failed_attempts INT UNSIGNED NOT NULL DEFAULT 0,
  locked_until    DATETIME     NULL,
  created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_login_at   DATETIME     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_admin_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Sessions (joueurs et admins) : seul le hachage du jeton est stocké
CREATE TABLE sessions (
  token_hash CHAR(64)     NOT NULL,
  kind       ENUM('user','admin') NOT NULL,
  user_id    INT UNSIGNED NULL,
  admin_id   INT UNSIGNED NULL,
  csrf_token CHAR(64)     NOT NULL,
  ip         VARCHAR(64)  NULL,
  expires_at DATETIME     NOT NULL,
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (token_hash),
  KEY ix_sessions_exp (expires_at),
  CONSTRAINT fk_sess_user  FOREIGN KEY (user_id)  REFERENCES users (id)  ON DELETE CASCADE,
  CONSTRAINT fk_sess_admin FOREIGN KEY (admin_id) REFERENCES admins (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Catalogue (source unique pour le site ET la boutique en jeu)
CREATE TABLE categories (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  slug        VARCHAR(48)  NOT NULL,
  name        VARCHAR(64)  NOT NULL,
  description VARCHAR(255) NOT NULL DEFAULT '',
  icon        VARCHAR(32)  NOT NULL DEFAULT 'star',
  sort        INT          NOT NULL DEFAULT 0,
  active      TINYINT(1)   NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  UNIQUE KEY uq_cat_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE products (
  id                INT UNSIGNED NOT NULL AUTO_INCREMENT,
  slug              VARCHAR(64)  NOT NULL,
  category_id       INT UNSIGNED NOT NULL,
  name              VARCHAR(80)  NOT NULL,
  short_description VARCHAR(160) NOT NULL DEFAULT '',
  description       TEXT         NOT NULL,
  image_url         VARCHAR(255) NOT NULL DEFAULT '',
  price_cents       INT UNSIGNED NOT NULL,             -- prix affiché ; le prix payé est celui de Tebex
  currency          CHAR(3)      NOT NULL DEFAULT 'EUR',
  duration_days     INT UNSIGNED NULL,                 -- NULL = permanent
  max_quantity      INT UNSIGNED NOT NULL DEFAULT 1,
  perks             JSON         NOT NULL,             -- liste de textes « avantages » affichés
  tebex_package_id  BIGINT UNSIGNED NULL,              -- paquet Tebex correspondant (obligatoire pour vendre)
  featured          TINYINT(1)   NOT NULL DEFAULT 0,
  popular           TINYINT(1)   NOT NULL DEFAULT 0,
  active            TINYINT(1)   NOT NULL DEFAULT 1,
  sort              INT          NOT NULL DEFAULT 0,
  created_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_prod_slug (slug),
  UNIQUE KEY uq_prod_tebex (tebex_package_id),
  KEY ix_prod_cat (category_id, active, sort),
  CONSTRAINT fk_prod_cat FOREIGN KEY (category_id) REFERENCES categories (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Ce que donne un produit en jeu (une ligne par récompense)
CREATE TABLE product_rewards (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  product_id INT UNSIGNED NOT NULL,
  type       ENUM('group','perk','vehicle','item','money','command') NOT NULL,
  params     JSON         NOT NULL,
  sort       INT          NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY ix_prew_prod (product_id),
  CONSTRAINT fk_prew_prod FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Commandes : créées au passage en caisse (pending) ou à la réception d'un paiement Tebex
CREATE TABLE orders (
  id                   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_ref           CHAR(36)     NOT NULL,          -- référence publique (UUID), jamais l'id interne
  user_id              INT UNSIGNED NULL,
  cfx_id               VARCHAR(32)  NULL,              -- compte attendu (site/jeu) puis compte payeur
  source               ENUM('web','game','tebex') NOT NULL,
  status               ENUM('pending','paid','failed','cancelled','refunded','chargeback') NOT NULL DEFAULT 'pending',
  tebex_basket_ident   VARCHAR(64)  NULL,
  tebex_transaction_id VARCHAR(64)  NULL,
  packages_added       TINYINT(1)   NOT NULL DEFAULT 0,
  total_cents          INT UNSIGNED NOT NULL DEFAULT 0,
  currency             CHAR(3)      NOT NULL DEFAULT 'EUR',
  created_at           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  paid_at              DATETIME     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_orders_ref (public_ref),
  UNIQUE KEY uq_orders_basket (tebex_basket_ident),
  UNIQUE KEY uq_orders_tx (tebex_transaction_id),
  KEY ix_orders_user (user_id, created_at),
  KEY ix_orders_cfx (cfx_id, created_at),
  KEY ix_orders_status (status, created_at),
  CONSTRAINT fk_orders_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE order_items (
  id               INT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id         INT UNSIGNED NOT NULL,
  product_id       INT UNSIGNED NULL,
  tebex_package_id BIGINT UNSIGNED NULL,
  name_snapshot    VARCHAR(80)  NOT NULL,
  quantity         INT UNSIGNED NOT NULL,
  unit_price_cents INT UNSIGNED NOT NULL,
  recipient_cfx_id VARCHAR(32)  NULL,                  -- qui reçoit (le payeur, ou le destinataire d'un cadeau Tebex)
  PRIMARY KEY (id),
  KEY ix_oi_order (order_id),
  CONSTRAINT fk_oi_order FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
  CONSTRAINT fk_oi_prod  FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Événements de paiement reçus pour une commande (historique)
CREATE TABLE transactions (
  id                   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id             INT UNSIGNED NOT NULL,
  tebex_transaction_id VARCHAR(64)  NOT NULL,
  event_type           VARCHAR(48)  NOT NULL,
  status               VARCHAR(48)  NOT NULL,
  amount_cents         INT          NULL,
  currency             CHAR(3)      NULL,
  created_at           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY ix_tx_order (order_id),
  KEY ix_tx_tebex (tebex_transaction_id),
  CONSTRAINT fk_tx_order FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Webhooks Tebex reçus : l'id unique empêche de traiter deux fois le même événement
CREATE TABLE webhook_events (
  id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  tebex_id     VARCHAR(64)  NOT NULL,
  type         VARCHAR(64)  NOT NULL,
  status       ENUM('received','processed','ignored','error') NOT NULL DEFAULT 'received',
  error        VARCHAR(500) NULL,
  payload      JSON         NOT NULL,
  received_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  processed_at DATETIME     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_wh_tebex (tebex_id),
  KEY ix_wh_status (status, received_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Récompenses accordées (une par unité achetée et par récompense du produit)
CREATE TABLE rewards (
  id               INT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_item_id    INT UNSIGNED NOT NULL,
  unit_index       INT UNSIGNED NOT NULL,
  reward_def_id    INT UNSIGNED NOT NULL,              -- product_rewards.id au moment de l'achat
  type             VARCHAR(16)  NOT NULL,
  params           JSON         NOT NULL,              -- copie figée des paramètres au moment de l'achat
  recipient_cfx_id VARCHAR(32)  NOT NULL,
  status           ENUM('pending','delivered','failed','cancelled','revoke_pending','revoked') NOT NULL DEFAULT 'pending',
  expires_at       DATETIME     NULL,
  delivered_at     DATETIME     NULL,
  revoked_at       DATETIME     NULL,
  delivery_meta    JSON         NULL,                  -- ex. plaque du véhicule, personnage qui l'a reçu
  created_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_reward_unit (order_item_id, unit_index, reward_def_id),
  KEY ix_reward_recipient (recipient_cfx_id, status),
  KEY ix_reward_expiry (status, expires_at),
  CONSTRAINT fk_reward_oi FOREIGN KEY (order_item_id) REFERENCES order_items (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- File de livraison : ce que le serveur de jeu doit faire (donner / retirer)
CREATE TABLE delivery_jobs (
  id               INT UNSIGNED NOT NULL AUTO_INCREMENT,
  reward_id        INT UNSIGNED NOT NULL,
  action           ENUM('grant','revoke') NOT NULL,
  recipient_cfx_id VARCHAR(32)  NOT NULL,
  status           ENUM('pending','claimed','done','failed','cancelled') NOT NULL DEFAULT 'pending',
  attempts         INT UNSIGNED NOT NULL DEFAULT 0,
  next_attempt_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  claimed_at       DATETIME     NULL,
  claimed_by       VARCHAR(64)  NULL,
  last_error       VARCHAR(500) NULL,
  created_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  done_at          DATETIME     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_job (reward_id, action),
  KEY ix_job_pick (status, recipient_cfx_id, next_attempt_at),
  CONSTRAINT fk_job_reward FOREIGN KEY (reward_id) REFERENCES rewards (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Journal : actions sensibles, erreurs, événements système
CREATE TABLE audit_logs (
  id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  level      ENUM('info','warn','error') NOT NULL DEFAULT 'info',
  actor_type ENUM('admin','user','game','webhook','system') NOT NULL,
  actor_id   VARCHAR(64)  NULL,
  action     VARCHAR(64)  NOT NULL,
  target     VARCHAR(96)  NULL,
  details    JSON         NULL,
  ip         VARCHAR(64)  NULL,
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY ix_audit_level (level, created_at),
  KEY ix_audit_action (action, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
