-- =========================================================
--  BUILDER STUDIO - CONFIGURATION
-- =========================================================
Config = {}

Config.Command = 'mapping'          -- /mapping ouvre le studio
Config.Locale = 'fr'

-- Permissions ACE (à donner dans permissions.cfg, voir README)
--   add_ace group.admin builder.access allow   (et les suivantes)
Config.Ace = {
    access = 'builder.access',   -- ouvrir l'éditeur, voir les projets
    build  = 'builder.build',    -- créer des éléments / projets
    edit   = 'builder.edit',     -- modifier (déplacer, matériaux, paramètres)
    delete = 'builder.delete',   -- supprimer éléments / projets
    import = 'builder.import',   -- objets et textures personnalisés
    export = 'builder.export',   -- exporter en ressource FiveM
    admin  = 'builder.admin',    -- tout + projets des autres
}
-- La console serveur (source 0) a tous les droits.

-- Permissions staff d'admin_menu (éditeur de grades du menu admin, catégorie « Gestion »).
-- « builder_manage » = tout ; sinon une case par droit. Les ACE ci-dessus restent valables en plus.
Config.AdminMenu = {
    enabled = true,
    resource = 'admin_menu',
    all = 'builder_manage',
    perms = {
        access = 'builder_access',
        build  = 'builder_build',
        edit   = 'builder_edit',
        delete = 'builder_delete',
        import = 'builder_import',
        export = 'builder_export',
        admin  = 'builder_manage',
    },
}

-- Bibliothèque de textures importées EN JEU (image de ton PC ou lien https)
Config.Textures = {
    max = 150,                 -- textures dans la bibliothèque
    maxBytes = 3000000,        -- taille maximale d'une image importée (base64)
    sizes = { 128, 256, 512, 1024, 2048 },   -- résolutions proposées (puissances de 2)
    maxActive = 64,            -- textures chargées en même temps par un joueur
}

-- Limites (protègent le serveur et les clients)
Config.Limits = {
    maxProjects = 200,
    maxElementsPerProject = 5000,
    maxPiecesPerProject = 25000,       -- modules réellement créés en jeu
    maxElementsPerOp = 600,            -- par action (un immeuble = beaucoup d'éléments)
    maxOpsPerSecond = 25,              -- anti-spam par joueur
    maxVersionsPerProject = 30,        -- points de restauration conservés
    maxHistory = 300,                  -- lignes de l'historique conservées
}

-- Sauvegarde automatique (secondes) des projets modifiés
Config.AutosaveSeconds = 30
-- Point de restauration automatique toutes les N minutes d'édition (0 = jamais)
Config.AutoRestoreMinutes = 15

-- Chargement progressif (client)
Config.Stream = {
    radius = 250.0,        -- distance de chargement des éléments
    unloadMargin = 40.0,   -- marge avant déchargement (évite le clignotement)
    spawnPerFrame = 12,    -- entités créées au maximum par image
    maxEntities = 6000,    -- garde-fou global
    lightDistance = 60.0,  -- les lumières ne sont dessinées que près de la caméra
    maxLights = 48,        -- lumières dessinées au maximum par image
}

-- Éditeur
Config.Editor = {
    camSpeed = 0.35,         -- m par image
    camFastMul = 4.0,        -- Maj
    camSlowMul = 0.25,       -- Ctrl
    mouseSens = 0.18,
    grid = 0.5,              -- pas de la grille (m)
    angleSnap = 15.0,        -- pas de rotation (°)
    gizmoSize = 1.5,         -- longueur des axes (m) à 10 m de la caméra
    pickDistance = 400.0,
    maxUndo = 100,
}

-- Export : dossier de sortie (dans cette ressource)
Config.ExportFolder = 'exports'
-- Préfixe des ressources exportées
Config.ExportPrefix = 'map_'
