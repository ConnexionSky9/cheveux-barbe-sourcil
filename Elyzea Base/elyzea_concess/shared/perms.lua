-- =====================================================================
--  ELYZEA CONCESSION - permissions des grades (chaque concession a ses grades)
--  Le client n'en décide jamais : chaque action est revérifiée par le serveur.
--  Le catalogue global, les catégories et la configuration des concessions sont
--  réservés au staff : admin_menu › Administration automobile (« dealer_manage »).
-- =====================================================================
CDPerms = {
    -- Service
    { key = 'duty',           group = 'Service',     label = 'Prendre son service' },
    { key = 'tablet',         group = 'Service',     label = 'Accéder à la tablette' },
    -- Commercial
    { key = 'catalog',        group = 'Commercial',  label = 'Consulter le catalogue de la concession' },
    { key = 'sell',           group = 'Commercial',  label = 'Vendre un véhicule' },
    { key = 'discount',       group = 'Commercial',  label = 'Accorder une remise (dans la limite de la concession)' },
    { key = 'delivery',       group = 'Commercial',  label = 'Suivre et relancer les livraisons' },
    { key = 'sales_all',      group = 'Commercial',  label = 'Voir toutes les ventes et les clients' },
    -- Exposition et prix
    { key = 'display',        group = 'Exposition',  label = 'Mettre en exposition, retirer, remplacer' },
    { key = 'prices',         group = 'Exposition',  label = 'Modifier les prix de la concession' },
    { key = 'stats',          group = 'Exposition',  label = 'Consulter les statistiques' },
    -- Direction
    { key = 'direction',      group = 'Direction',   label = 'Accéder à la direction' },
    { key = 'recruit',        group = 'Direction',   label = 'Recruter' },
    { key = 'employees_view', group = 'Direction',   label = 'Consulter les employés' },
    { key = 'employees_edit', group = 'Direction',   label = 'Modifier les fiches des employés' },
    { key = 'promote',        group = 'Direction',   label = 'Promouvoir (et nommer un responsable)' },
    { key = 'demote',         group = 'Direction',   label = 'Rétrograder' },
    { key = 'fire',           group = 'Direction',   label = 'Retirer un employé du métier' },
    { key = 'history_view',   group = 'Direction',   label = 'Consulter l\'historique du personnel' },
    { key = 'grades_manage',  group = 'Direction',   label = 'Créer, modifier et désactiver les grades' },
    { key = 'perms_manage',   group = 'Direction',   label = 'Gérer les permissions des grades' },
    -- Finance
    { key = 'finance',        group = 'Finance',     label = 'Voir les finances de la concession' },
    { key = 'payroll',        group = 'Finance',     label = 'Régler salaires horaires, commissions et payer' },
}

CDPermSet = {}
for _, p in ipairs(CDPerms) do CDPermSet[p.key] = true end
