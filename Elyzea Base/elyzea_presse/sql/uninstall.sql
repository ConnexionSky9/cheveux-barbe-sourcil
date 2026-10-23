-- =====================================================================
--  ELYZEA PRESSE - retour arrière (désinstallation)
--  ⚠ Sauvegardez la base avant (phpMyAdmin › Exporter, ou mysqldump).
--  1. Retirez « ensure elyzea_presse » de server.cfg et redémarrez le serveur.
--  2. Exécutez ce fichier : il ne touche QU'AUX données du métier de journaliste.
--     Personnages, argent, autres métiers, véhicules et inventaires ne sont pas modifiés.
-- =====================================================================

-- Les journalistes redeviennent sans emploi (métier « journaliste » et rédactions créées dans /agences).
-- Ajoutez les autres métiers de rédaction créés en jeu à la liste si besoin (ex. 'ls_times').
UPDATE `players` SET `job` = '{"name":"unemployed","label":"Sans emploi","payment":10,"onduty":true,"isboss":false,"bankAuth":false,"grade":{"name":"Citoyen","level":0}}'
    WHERE JSON_UNQUOTE(JSON_EXTRACT(`job`, '$.name')) IN ('journaliste');
DELETE FROM `player_groups` WHERE `type` = 'job' AND `group` IN ('journaliste');

-- Rédactions enregistrées dans elyzea_agences
DELETE FROM `ely_agencies` WHERE `kind` = 'presse';

-- Coffre de la rédaction (elyzea_inventory). Videz-le d'abord en jeu si vous voulez récupérer les objets.
DELETE FROM `elyzea_stashes` WHERE `id` LIKE 'presse\_stash%';

-- Tables du métier (dont les commandes d'annonces et leurs diffusions ; `presse_ads` : ancienne version)
DROP TABLE IF EXISTS `presse_ad_slots`, `presse_ad_orders`, `presse_ads`, `presse_article_log`, `presse_articles`, `presse_interviews`, `presse_media`, `presse_flashes`, `presse_cards`,
    `presse_commission`, `presse_rates`, `presse_sessions`, `presse_transactions`, `presse_admin_log`, `presse_employees`, `presse_grades`, `presse_settings`;

-- Non supprimés volontairement (traçabilité) : le compte de société « journaliste » (elyzea_society) et son
-- journal (elyzea_society_logs). Pour les supprimer aussi :
--   DELETE FROM `elyzea_society_logs` WHERE `society` = 'journaliste';
--   DELETE FROM `elyzea_society` WHERE `name` = 'journaliste';
-- Les objets presse_* encore dans les inventaires des joueurs restent ; ils deviennent inutilisables
-- si vous retirez aussi leurs définitions de elyzea_inventory/shared/items.lua.
