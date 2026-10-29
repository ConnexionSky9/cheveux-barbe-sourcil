-- =====================================================================
--  ELYZEA BOÎTE DE NUIT - permissions des grades (chaque boîte a ses grades)
--  Le patron coche, grade par grade, ce que chacun peut faire (tablette ›
--  Direction › Permissions). Le client n'en décide jamais : chaque action
--  est revérifiée par le serveur.
-- =====================================================================
CLPerms = {
    -- Service
    { key = 'duty',           group = 'Service',     label = 'Prendre son service' },
    { key = 'tablet',         group = 'Service',     label = 'Accéder à la tablette' },
    -- Bar
    { key = 'bar',            group = 'Bar',         label = 'Servir au bar (encaisser une commande)' },
    { key = 'menu',           group = 'Bar',         label = 'Modifier la carte et les prix' },
    { key = 'stock',          group = 'Bar',         label = 'Commander du stock (payé par la boîte)' },
    { key = 'sales_all',      group = 'Bar',         label = 'Voir toutes les ventes' },
    { key = 'stash',          group = 'Bar',         label = 'Ouvrir le coffre de la boîte' },
    -- Entrée
    { key = 'door',           group = 'Entrée',      label = 'Contrôler l\'entrée (bracelet, VIP, liste noire)' },
    { key = 'lists',          group = 'Entrée',      label = 'Gérer la liste VIP et la liste noire' },
    { key = 'open',           group = 'Entrée',      label = 'Ouvrir / fermer la boîte au public, prix d\'entrée' },
    { key = 'announce',       group = 'Entrée',      label = 'Faire une annonce à toute la ville' },
    -- Musique
    { key = 'music',          group = 'Musique',     label = 'Utiliser les enceintes : playlist, lecture, volume' },
    { key = 'speakers',       group = 'Musique',     label = 'Poser et retirer les enceintes de la boîte' },
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
    { key = 'perms_manage',   group = 'Direction',   label = 'Choisir les permissions des grades (ex. qui peut utiliser les enceintes)' },
    -- Finance
    { key = 'finance',        group = 'Finance',     label = 'Voir les finances de la boîte' },
    { key = 'payroll',        group = 'Finance',     label = 'Régler salaires horaires, commissions et payer' },
}

CLPermSet = {}
for _, p in ipairs(CLPerms) do CLPermSet[p.key] = true end
