-- NOIR X — EXEMPLES Ratline (facultatif)
-- Deux informateurs et quelques informations de démonstration pour tester l'application.
-- Les positions sont des exemples sur la carte de base de GTA V : remplace-les par TES
-- emplacements (champs de weed, revendeurs PNJ…) ou supprime ces lignes et crée les tiennes
-- depuis l'admin. À n'importer qu'une seule fois.

INSERT INTO `noirx_informants` (`name`, `tagline`, `greeting`, `enabled`, `sort_order`, `created_at`) VALUES
('Le Fermier', 'Connaît chaque champ du comté', 'Ouais ? Fais vite, j''ai du monde à surveiller.', 1, 1, UNIX_TIMESTAMP()),
('Silk',       'Les rues de Los Santos, les vendeurs, les rumeurs', 'Tiens, une nouvelle tête. Qu''est-ce que tu cherches ?', 1, 2, UNIX_TIMESTAMP());

SET @fermier = (SELECT `id` FROM `noirx_informants` WHERE `name` = 'Le Fermier' ORDER BY `id` DESC LIMIT 1);
SET @silk    = (SELECT `id` FROM `noirx_informants` WHERE `name` = 'Silk' ORDER BY `id` DESC LIMIT 1);

INSERT INTO `noirx_intel` (`informant_id`, `category`, `title`, `keywords`, `answer`, `x`, `y`, `z`, `price`, `currency`, `reliability`, `enabled`, `expires_at`, `sort_order`, `created_at`, `updated_at`) VALUES
(@fermier, 'weed', 'Où pousse la weed en ce moment ?', 'weed,beuh,champ,champs,plantation,cannabis',
 'Derrière les serres de Grapeseed, côté est. Pas de patrouille avant la tombée de la nuit. Je te mets le point.',
 2220.0, 5577.0, 53.0, 1500, 'dirty', 90, 1, NULL, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(@fermier, 'weed', 'Un autre coin plus discret ?', 'discret,autre,second,planque',
 'Il y a un petit lot près de Sandy Shores, au nord de l''aérodrome. Ça bouge souvent, vérifie avant d''y aller.',
 1700.0, 3300.0, 41.0, 2500, 'dirty', 55, 1, NULL, 2, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(@silk, 'dealer', 'Qui vend dans Grove Street ?', 'grove,dealer,vendeur,revendeur,acheter',
 'Un type en survêt vert près du terrain de basket. Il vend de la weed et des pochons de coke, cash uniquement.',
 105.0, -1940.0, 20.8, 1000, 'dirty', 85, 1, NULL, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(@silk, 'rumor', 'Des nouvelles du quartier ?', 'news,nouvelles,rumeur,quoi de neuf',
 'Les flics ont doublé les patrouilles à Davis cette semaine. Évite de traîner là-bas.',
 NULL, NULL, NULL, 0, 'dirty', 70, 1, NULL, 2, UNIX_TIMESTAMP(), UNIX_TIMESTAMP());
