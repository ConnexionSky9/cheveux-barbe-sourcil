-- =====================================================================
--  ELYZEA RESTAURANT - permissions des grades (chaque restaurant a ses grades)
--  Le patron coche, grade par grade, ce que chacun peut faire (tablette ›
--  Direction › Permissions). Le client n'en décide jamais : chaque action
--  est revérifiée par le serveur.
-- =====================================================================
RSPerms = {
    -- Service
    { key = 'duty',           group = 'Service',     label = 'Prendre son service' },
    { key = 'tablet',         group = 'Service',     label = 'Accéder à la tablette' },
    -- Commandes
    { key = 'orders',         group = 'Commandes',   label = 'Appli « Commande » : voir et prendre en charge les commandes' },
    { key = 'cook',           group = 'Commandes',   label = 'Cuisiner aux stations (mini-jeux)' },
    { key = 'deliver',        group = 'Commandes',   label = 'Remettre le sac au client' },
    { key = 'orders_manage',  group = 'Commandes',   label = 'Annuler / rembourser une commande, libérer une commande prise' },
    -- Restaurant
    { key = 'menu',           group = 'Restaurant',  label = 'Modifier la carte (produits proposés, prix)' },
    { key = 'open',           group = 'Restaurant',  label = 'Ouvrir / fermer les commandes au public' },
    { key = 'sales_all',      group = 'Restaurant',  label = 'Voir toutes les commandes et ventes' },
    { key = 'stash',          group = 'Restaurant',  label = 'Ouvrir le coffre du restaurant' },
    -- Direction
    { key = 'stats',          group = 'Direction',   label = 'Consulter les statistiques' },
    { key = 'direction',      group = 'Direction',   label = 'Accéder à la direction' },
    { key = 'recruit',        group = 'Direction',   label = 'Recruter' },
    { key = 'employees_view', group = 'Direction',   label = 'Consulter les employés' },
    { key = 'employees_edit', group = 'Direction',   label = 'Modifier les fiches des employés' },
    { key = 'promote',        group = 'Direction',   label = 'Promouvoir' },
    { key = 'demote',         group = 'Direction',   label = 'Rétrograder' },
    { key = 'fire',           group = 'Direction',   label = 'Retirer un employé du métier' },
    { key = 'history_view',   group = 'Direction',   label = 'Consulter l\'historique du personnel' },
    { key = 'grades_manage',  group = 'Direction',   label = 'Créer, modifier et désactiver les grades' },
    { key = 'perms_manage',   group = 'Direction',   label = 'Choisir les permissions des grades' },
    -- Finance
    { key = 'finance',        group = 'Finance',     label = 'Voir les finances du restaurant' },
    { key = 'payroll',        group = 'Finance',     label = 'Régler salaires horaires, commissions et payer' },
}

RSPermSet = {}
for _, p in ipairs(RSPerms) do RSPermSet[p.key] = true end
