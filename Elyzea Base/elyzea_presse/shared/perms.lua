-- =====================================================================
--  ELYZEA PRESSE - liste des permissions (serveur, client, tablette)
--  Le client n'en décide jamais : chaque action est revérifiée par le serveur.
-- =====================================================================
PrPerms = {
    -- Service
    { key = 'duty',           group = 'Service',    label = 'Prendre son service' },
    { key = 'tablet',         group = 'Service',    label = 'Accéder à la tablette (lire les articles de la rédaction)' },
    -- Rédaction
    { key = 'write',          group = 'Rédaction',  label = 'Rédiger, modifier et soumettre ses brouillons' },
    { key = 'publish',        group = 'Rédaction',  label = 'Publier ses articles sans validation' },
    { key = 'review',         group = 'Rédaction',  label = 'Valider, corriger ou renvoyer les articles soumis' },
    { key = 'edit_any',       group = 'Rédaction',  label = 'Corriger un article publié d\'un autre journaliste' },
    { key = 'archive',        group = 'Rédaction',  label = 'Archiver / remettre en ligne les articles' },
    { key = 'delete',         group = 'Rédaction',  label = 'Retirer définitivement l\'article d\'un autre' },
    -- Terrain
    { key = 'interview',      group = 'Terrain',    label = 'Demander des interviews' },
    { key = 'media',          group = 'Terrain',    label = 'Photos et séquences (appareil photo, caméra)' },
    -- Diffusion
    { key = 'flash',          group = 'Diffusion',  label = 'Flash info à tout le serveur (et annonce des nouveaux articles)' },
    { key = 'ads',            group = 'Diffusion',  label = 'Planning : envoyer les annonces commandées (commission)' },
    { key = 'ads_manage',     group = 'Diffusion',  label = 'Tarif des annonces, commissions, annulation et remboursement des commandes' },
    -- Matériel et locaux
    { key = 'gear',           group = 'Matériel',   label = 'Retirer / rendre le matériel de service' },
    { key = 'wardrobe',       group = 'Matériel',   label = 'Utiliser le vestiaire' },
    { key = 'stash',          group = 'Matériel',   label = 'Ouvrir le coffre de la rédaction' },
    { key = 'garage',         group = 'Matériel',   label = 'Sortir les véhicules de service' },
    { key = 'cards_manage',   group = 'Matériel',   label = 'Délivrer et révoquer les cartes de presse' },
    { key = 'points_manage',  group = 'Matériel',   label = 'Placer les points, régler le garage, les tenues et le matériel' },
    -- Direction
    { key = 'direction',      group = 'Direction',  label = 'Accéder à la direction' },
    { key = 'recruit',        group = 'Direction',  label = 'Recruter' },
    { key = 'employees_view', group = 'Direction',  label = 'Consulter les employés' },
    { key = 'employees_edit', group = 'Direction',  label = 'Modifier les fiches des employés' },
    { key = 'promote',        group = 'Direction',  label = 'Promouvoir' },
    { key = 'demote',         group = 'Direction',  label = 'Rétrograder' },
    { key = 'fire',           group = 'Direction',  label = 'Retirer un employé du métier' },
    { key = 'history_view',   group = 'Direction',  label = 'Consulter l\'historique du personnel' },
    { key = 'grades_manage',  group = 'Direction',  label = 'Créer, modifier et désactiver les grades' },
    { key = 'perms_manage',   group = 'Direction',  label = 'Gérer les permissions des grades' },
    -- Finance
    { key = 'finance',        group = 'Finance',    label = 'Voir les finances de la rédaction' },
    { key = 'payroll',        group = 'Finance',    label = 'Régler les taux horaires et payer les employés' },
}

PrPermSet = {}
for _, p in ipairs(PrPerms) do PrPermSet[p.key] = true end
