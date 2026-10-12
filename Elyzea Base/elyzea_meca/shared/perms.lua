-- =====================================================================
--  ELYZEA MÉCANO - liste des permissions (serveur, client, tablette)
--  Le client n'en décide jamais : chaque action est revérifiée par le serveur.
-- =====================================================================
MecaPerms = {
    -- Atelier
    { key = 'duty',          group = 'Atelier',     label = 'Prendre son service' },
    { key = 'repair',        group = 'Atelier',     label = 'Réparer (moteur, carrosserie, pneus)' },
    { key = 'repair_full',   group = 'Atelier',     label = 'Réparation complète' },
    { key = 'clean',         group = 'Atelier',     label = 'Nettoyer un véhicule' },
    { key = 'flip',          group = 'Atelier',     label = 'Retourner un véhicule' },
    { key = 'workshop',      group = 'Atelier',     label = 'Utiliser les points d\'atelier' },
    { key = 'perf',          group = 'Atelier',     label = 'Installer des améliorations de performance' },
    { key = 'cosmetic',      group = 'Atelier',     label = 'Installer des modifications esthétiques' },
    { key = 'carplay',       group = 'Atelier',     label = 'Installer le CarPlay' },
    { key = 'garage',        group = 'Atelier',     label = 'Sortir et ranger les véhicules de service' },
    -- Clients
    { key = 'quotes',        group = 'Clients',     label = 'Créer des devis et facturer' },
    { key = 'quotes_manage', group = 'Clients',     label = 'Annuler et rembourser n\'importe quelle facture' },
    { key = 'tow',           group = 'Clients',     label = 'Recevoir et prendre les dépannages' },
    { key = 'tow_manage',    group = 'Clients',     label = 'Attribuer, clôturer ou annuler tout dépannage' },
    -- Tablette
    { key = 'tablet',        group = 'Tablette',    label = 'Accéder à la tablette' },
    { key = 'vehicles_view', group = 'Tablette',    label = 'Consulter les véhicules clients et leur historique' },
    { key = 'stats_view',    group = 'Tablette',    label = 'Consulter les statistiques' },
    -- Stock
    { key = 'stock_view',    group = 'Stock',       label = 'Consulter le stock de pièces' },
    { key = 'stock_manage',  group = 'Stock',       label = 'Commander et régler le stock (dépense du compte société)' },
    -- Direction
    { key = 'direction',     group = 'Direction',   label = 'Accéder à la direction (Métier / Staff)' },
    { key = 'recruit',       group = 'Direction',   label = 'Recruter' },
    { key = 'employees_view', group = 'Direction',  label = 'Consulter les employés' },
    { key = 'employees_edit', group = 'Direction',  label = 'Modifier les fiches des employés' },
    { key = 'promote',       group = 'Direction',   label = 'Promouvoir' },
    { key = 'demote',        group = 'Direction',   label = 'Rétrograder' },
    { key = 'fire',          group = 'Direction',   label = 'Retirer un employé du métier' },
    { key = 'history_view',  group = 'Direction',   label = 'Consulter l\'historique du personnel' },
    { key = 'grades_manage', group = 'Direction',   label = 'Créer, modifier et désactiver les grades' },
    { key = 'perms_manage',  group = 'Direction',   label = 'Gérer les permissions des grades' },
    { key = 'catalog_manage', group = 'Direction',  label = 'Catalogue et tarifs' },
    { key = 'garage_manage', group = 'Direction',   label = 'Garage : placer les points, choisir les véhicules' },
    -- Finance
    { key = 'finance',       group = 'Finance',     label = 'Voir les finances de l\'entreprise' },
    { key = 'payroll',       group = 'Finance',     label = 'Régler les taux horaires et payer les employés' },
}

MecaPermSet = {}
for _, p in ipairs(MecaPerms) do MecaPermSet[p.key] = true end
