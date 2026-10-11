-- =====================================================================
--  ELYZEA POLICE - liste des permissions (serveur, client et tablette)
--  Une permission n'est jamais décidée par le client : le serveur vérifie tout.
-- =====================================================================
PolicePerms = {
    -- Terrain
    { key = 'duty',           group = 'Terrain',    label = 'Prendre son service' },
    { key = 'alt',            group = 'Terrain',    label = 'Utiliser les interactions ALT' },
    { key = 'cuff',           group = 'Terrain',    label = 'Menotter et démenotter' },
    { key = 'escort',         group = 'Terrain',    label = 'Escorter une personne' },
    { key = 'vehicle',        group = 'Terrain',    label = 'Mettre / sortir une personne d\'un véhicule' },
    { key = 'fine',           group = 'Terrain',    label = 'Mettre des amendes' },
    { key = 'impound',        group = 'Terrain',    label = 'Mettre un véhicule en fourrière' },
    -- Alertes
    { key = 'alerts_receive', group = 'Alertes',    label = 'Recevoir les alertes' },
    { key = 'alert_agent',    group = 'Alertes',    label = 'Déclencher une alerte agent' },
    { key = 'alert_close',    group = 'Alertes',    label = 'Clôturer les alertes des autres agents' },
    -- Tablette
    { key = 'tablet',         group = 'Tablette',   label = 'Accéder à la tablette' },
    { key = 'reports_view',   group = 'Tablette',   label = 'Consulter les rapports' },
    { key = 'reports_write',  group = 'Tablette',   label = 'Créer et modifier ses rapports' },
    { key = 'reports_manage', group = 'Tablette',   label = 'Modifier et archiver tous les rapports' },
    { key = 'map',            group = 'Tablette',   label = 'Voir la carte des agents' },
    { key = 'agents_view',    group = 'Tablette',   label = 'Voir la liste des agents en service' },
    { key = 'search',         group = 'Tablette',   label = 'Rechercher un citoyen (fiche, amendes, rapports, avis)' },
    { key = 'wanted_view',    group = 'Tablette',   label = 'Voir les personnes recherchées' },
    { key = 'wanted_manage',  group = 'Tablette',   label = 'Créer, modifier et lever un avis de recherche' },
    -- Direction
    { key = 'direction',      group = 'Direction',  label = 'Accéder à la direction' },
    { key = 'recruit',        group = 'Direction',  label = 'Recruter' },
    { key = 'employees_view', group = 'Direction',  label = 'Consulter les employés' },
    { key = 'employees_edit', group = 'Direction',  label = 'Modifier les informations des employés (matricule, note)' },
    { key = 'promote',        group = 'Direction',  label = 'Promouvoir' },
    { key = 'demote',         group = 'Direction',  label = 'Rétrograder' },
    { key = 'fire',           group = 'Direction',  label = 'Retirer un employé de la police' },
    { key = 'history_view',   group = 'Direction',  label = 'Consulter l\'historique administratif' },
    { key = 'grades_manage',  group = 'Direction',  label = 'Créer et modifier les grades' },
    { key = 'perms_manage',   group = 'Direction',  label = 'Gérer les permissions des grades' },
    { key = 'finance',        group = 'Direction',  label = 'Finance : argent de l\'entreprise, salaires horaires, payer les employés' },
}

PolicePermSet = {}
for _, p in ipairs(PolicePerms) do PolicePermSet[p.key] = true end
