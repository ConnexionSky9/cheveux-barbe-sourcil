-- =====================================================================
--  ELYZEA EMS - liste des permissions (serveur, client, tablette)
--  Le client n'en décide jamais : chaque action est revérifiée par le serveur.
-- =====================================================================
EmsPerms = {
    -- Terrain
    { key = 'duty',          group = 'Terrain',     label = 'Prendre son service' },
    { key = 'medical',       group = 'Terrain',     label = 'Examiner un patient (actions médicales de base)' },
    { key = 'heal',          group = 'Terrain',     label = 'Soigner' },
    { key = 'stabilize',     group = 'Terrain',     label = 'Stabiliser un patient à terre' },
    { key = 'revive',        group = 'Terrain',     label = 'Réanimer (soin avancé)' },
    { key = 'escort',        group = 'Terrain',     label = 'Accompagner un patient' },
    { key = 'vehicle',       group = 'Terrain',     label = 'Installer / sortir un patient d\'une ambulance' },
    { key = 'garage',        group = 'Terrain',     label = 'Sortir et ranger les véhicules EMS' },
    -- Appels et soutien
    { key = 'calls',         group = 'Appels',      label = 'Recevoir et prendre les appels d\'urgence' },
    { key = 'calls_manage',  group = 'Appels',      label = 'Attribuer, clôturer ou annuler n\'importe quel appel' },
    { key = 'support',       group = 'Appels',      label = 'Envoyer une demande de soutien' },
    { key = 'support_close', group = 'Appels',      label = 'Clôturer les demandes de soutien des autres' },
    -- Tablette
    { key = 'tablet',        group = 'Tablette',    label = 'Accéder à la tablette' },
    { key = 'map',           group = 'Tablette',    label = 'Voir la carte' },
    { key = 'records_view',  group = 'Tablette',    label = 'Consulter les dossiers médicaux' },
    { key = 'records_write', group = 'Tablette',    label = 'Modifier les dossiers médicaux' },
    { key = 'reports_write', group = 'Tablette',    label = 'Rédiger des comptes rendus' },
    { key = 'reports_manage', group = 'Tablette',   label = 'Modifier et archiver tous les comptes rendus' },
    { key = 'stats_view',    group = 'Tablette',    label = 'Consulter les statistiques et historiques' },
    -- Laboratoire (analyse sanguine : alcool et substances)
    { key = 'lab_sample',    group = 'Laboratoire', label = 'Faire un prélèvement sanguin (ALT sur le patient)' },
    { key = 'lab_analyze',   group = 'Laboratoire', label = 'Lancer l\'analyse d\'un prélèvement (médecin responsable)' },
    { key = 'lab_view',      group = 'Laboratoire', label = 'Consulter les résultats et l\'historique des analyses' },
    -- Facturation et PPA
    { key = 'billing',       group = 'Facturation', label = 'Facturer un patient' },
    { key = 'ppa_civil',     group = 'Facturation', label = 'Délivrer un PPA civil' },
    { key = 'ppa_fdo',       group = 'Facturation', label = 'Délivrer un PPA force de l\'ordre' },
    -- Direction
    { key = 'direction',     group = 'Direction',   label = 'Accéder à la direction (Métier / Staff)' },
    { key = 'recruit',       group = 'Direction',   label = 'Recruter' },
    { key = 'employees_view', group = 'Direction',  label = 'Consulter les employés' },
    { key = 'employees_edit', group = 'Direction',  label = 'Modifier les fiches des employés (matricule, note)' },
    { key = 'promote',       group = 'Direction',   label = 'Promouvoir (jusqu\'au grade Direction)' },
    { key = 'demote',        group = 'Direction',   label = 'Rétrograder' },
    { key = 'fire',          group = 'Direction',   label = 'Retirer un employé du métier' },
    { key = 'history_view',  group = 'Direction',   label = 'Consulter l\'historique du personnel' },
    { key = 'grades_manage', group = 'Direction',   label = 'Créer et modifier les grades' },
    { key = 'perms_manage',  group = 'Direction',   label = 'Gérer les permissions des grades' },
    { key = 'garage_manage', group = 'Direction',   label = 'Garage et pharmacie : placer les points, choisir les véhicules' },
    -- Finance
    { key = 'finance',       group = 'Finance',     label = 'Voir les finances de l\'entreprise' },
    { key = 'payroll',       group = 'Finance',     label = 'Régler les salaires horaires et payer les employés' },
    { key = 'billing_manage', group = 'Finance',    label = 'Tarifs des soins, annulation et remboursement des factures' },
    { key = 'ppa_manage',    group = 'Finance',     label = 'Gestion des PPA : prix et activation' },
}

EmsPermSet = {}
for _, p in ipairs(EmsPerms) do EmsPermSet[p.key] = true end
