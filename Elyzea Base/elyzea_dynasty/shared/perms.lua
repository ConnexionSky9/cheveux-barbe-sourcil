-- =====================================================================
--  ELYZEA DYNASTY 8 - liste des permissions (serveur, client, tablette)
--  Le client n'en décide jamais : chaque action est revérifiée par le serveur.
--  La configuration technique des biens (points, intérieurs, garages) est réservée
--  au staff : admin_menu › Gestion immobilière (permission « property_manage »).
-- =====================================================================
D8Perms = {
    -- Service
    { key = 'duty',             group = 'Service',     label = 'Prendre son service' },
    { key = 'tablet',           group = 'Service',     label = 'Accéder à la tablette' },
    -- Immobilier
    { key = 'visits',           group = 'Immobilier',  label = 'Faire visiter les biens disponibles' },
    { key = 'sell',             group = 'Immobilier',  label = 'Vendre un bien' },
    { key = 'rent',             group = 'Immobilier',  label = 'Louer un bien' },
    { key = 'properties_view',  group = 'Immobilier',  label = 'Voir les biens occupés, leurs occupants et contrats' },
    { key = 'contracts_manage', group = 'Immobilier',  label = 'Résilier un contrat, gérer les réservations' },
    { key = 'prices_manage',    group = 'Immobilier',  label = 'Fixer les prix et les durées de location' },
    -- Direction
    { key = 'direction',        group = 'Direction',   label = 'Accéder à la direction (Métier / Staff)' },
    { key = 'recruit',          group = 'Direction',   label = 'Recruter' },
    { key = 'employees_view',   group = 'Direction',   label = 'Consulter les employés' },
    { key = 'employees_edit',   group = 'Direction',   label = 'Modifier les fiches des employés' },
    { key = 'promote',          group = 'Direction',   label = 'Promouvoir' },
    { key = 'demote',           group = 'Direction',   label = 'Rétrograder' },
    { key = 'fire',             group = 'Direction',   label = 'Retirer un employé du métier' },
    { key = 'history_view',     group = 'Direction',   label = 'Consulter l\'historique du personnel' },
    { key = 'grades_manage',    group = 'Direction',   label = 'Créer, modifier et désactiver les grades' },
    { key = 'perms_manage',     group = 'Direction',   label = 'Gérer les permissions des grades' },
    -- Finance
    { key = 'finance',          group = 'Finance',     label = 'Voir les finances de l\'entreprise' },
    { key = 'payroll',          group = 'Finance',     label = 'Régler les taux horaires et payer les employés' },
}

D8PermSet = {}
for _, p in ipairs(D8Perms) do D8PermSet[p.key] = true end
