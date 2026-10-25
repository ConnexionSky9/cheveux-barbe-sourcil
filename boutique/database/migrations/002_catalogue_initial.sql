-- =====================================================================
--  Catalogue de départ (exemples modifiables dans le panel d'administration).
--  Les produits n'ont PAS d'identifiant de paquet Tebex : ils s'affichent
--  « Indisponible » tant qu'un administrateur ne les a pas reliés à un
--  paquet Tebex (Panel › Produits › Paquet Tebex).
-- =====================================================================

INSERT INTO categories (slug, name, description, icon, sort) VALUES
  ('vip',         'VIP & grades',        'Grades premium et avantages de statut.',        'crown',   10),
  ('vehicules',   'Véhicules',           'Véhicules personnalisés livrés dans votre garage.', 'car',  20),
  ('packs',       'Packs & avantages',   'Packs de démarrage et bonus.',                  'package', 30),
  ('cosmetiques', 'Cosmétiques',         'Tenues, accessoires et style.',                 'sparkles',40),
  ('autres',      'Autres',              'Produits divers.',                              'star',    50);

INSERT INTO products (slug, category_id, name, short_description, description, image_url, price_cents, currency, duration_days, max_quantity, perks, featured, popular, sort)
SELECT 'vip-or', id, 'VIP Or', 'Le statut premium d''Elyzea pendant 30 jours.',
       'Le grade VIP Or vous donne accès aux avantages réservés aux soutiens du serveur pendant 30 jours. Le grade est retiré automatiquement à la fin de la période.',
       '/images/produits/vip-or.webp', 1500, 'EUR', 30, 1,
       JSON_ARRAY('Badge VIP Or en jeu', 'Accès prioritaire à la file d''attente', 'Salon Discord réservé'), 1, 1, 10
FROM categories WHERE slug = 'vip';

INSERT INTO products (slug, category_id, name, short_description, description, image_url, price_cents, currency, duration_days, max_quantity, perks, featured, popular, sort)
SELECT 'vip-diamant', id, 'VIP Diamant', 'Tous les avantages VIP, pendant 90 jours.',
       'Le grade VIP Diamant reprend les avantages du VIP Or pendant 90 jours.',
       '/images/produits/vip-diamant.webp', 3500, 'EUR', 90, 1,
       JSON_ARRAY('Avantages du VIP Or', 'Durée de 90 jours'), 1, 0, 20
FROM categories WHERE slug = 'vip';

INSERT INTO products (slug, category_id, name, short_description, description, image_url, price_cents, currency, duration_days, max_quantity, perks, featured, popular, sort)
SELECT 'pack-demarrage', id, 'Pack de démarrage', 'Un coup de pouce pour vos premiers jours.',
       'Livré à votre personnage actif lors de votre prochaine connexion.',
       '/images/produits/pack-demarrage.webp', 800, 'EUR', NULL, 1,
       JSON_ARRAY('Téléphone', 'Kit de soins'), 0, 1, 10
FROM categories WHERE slug = 'packs';

-- Récompenses d'exemple (à adapter dans le panel)
INSERT INTO product_rewards (product_id, type, params, sort)
SELECT id, 'group', JSON_OBJECT('name', 'vip_or'), 0 FROM products WHERE slug = 'vip-or';
INSERT INTO product_rewards (product_id, type, params, sort)
SELECT id, 'group', JSON_OBJECT('name', 'vip_diamant'), 0 FROM products WHERE slug = 'vip-diamant';
INSERT INTO product_rewards (product_id, type, params, sort)
SELECT id, 'item', JSON_OBJECT('name', 'phone', 'count', 1), 0 FROM products WHERE slug = 'pack-demarrage';
INSERT INTO product_rewards (product_id, type, params, sort)
SELECT id, 'item', JSON_OBJECT('name', 'bandage', 'count', 5), 1 FROM products WHERE slug = 'pack-demarrage';
