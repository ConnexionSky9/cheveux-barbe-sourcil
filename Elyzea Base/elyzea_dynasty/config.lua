-- =====================================================================
--  ELYZEA DYNASTY 8 - configuration
--  Les biens, les intérieurs, les points, les garages, les prix, les grades,
--  les permissions et les taux horaires se gèrent EN JEU (ils sont gardés en base) :
--   · admin_menu › Gestion immobilière : biens, intérieurs, points, garages, places ;
--   · tablette Dynasty 8 : commercialisation, tarifs, personnel, finance.
--  Ici : les durées, les limites, les couleurs et les valeurs de départ.
-- =====================================================================
Config = {}

-- Métier et compte de société d'elyzea_core
Config.Job = { name = 'realestate', label = 'Dynasty 8', type = 'realestate' }
-- Agences (elyzea_agences) : plusieurs agences de ce métier, chacune son métier elyzea_core,
-- ses grades, son compte, son téléphone et sa zone d'alerte. Config.Job ci-dessus = première agence.
Config.AgencyKind = 'dynasty'
Config.Society = 'realestate'

Config.Keys = {
    menu = 'F6',
    interact = 38,                -- E (code de contrôle GTA) sur les points
}

Config.Matricule = { prefix = 'D8-', digits = 3 }
Config.Recruit = { distance = 5.0, timeout = 30, cooldown = 8 }

-- ---------------------------------------------------------------------
-- Points en jeu (couleurs imposées : bleu gestion, orange coffre, rouge sortie)
-- ---------------------------------------------------------------------
Config.Points = {
    drawDistance = 20.0,
    defaultRadius = 1.2,
    colors = {
        enter = { 34, 197, 94 },        -- entrée de l'habitation (vert)
        bell = { 250, 204, 21 },        -- sonnette (jaune)
        garage_enter = { 59, 130, 246 },-- entrée du garage (véhicule)
        manage = { 59, 130, 246 },      -- zone de gestion : BLEU
        stash = { 249, 115, 22 },       -- coffre : ORANGE
        exit = { 239, 68, 68 },         -- sortie : ROUGE
        garage_exit = { 239, 68, 68 },  -- sortie du garage à pied : ROUGE
    },
}

-- Instances : chaque bien a son propre « monde » (routing bucket) pour que plusieurs biens
-- puissent utiliser le même intérieur sans se croiser.
Config.BucketBase = 40000

-- ---------------------------------------------------------------------
-- Ventes, locations, prolongations
-- ---------------------------------------------------------------------
Config.Rent = {
    minDays = 1, maxDays = 60,            -- durées proposées par défaut (réglables par bien)
    extendMaxDays = 60,                   -- prolongation maximale en une fois
    -- Prolongation d'un contrat déjà expiré (depuis moins de graceHours) : repart de maintenant
    graceHours = 48,
    warnHours = 24,                       -- « bientôt expirée » dans la tablette
}
Config.Prices = { max = 50000000 }
Config.CodeLength = { min = 4, max = 8 }  -- codes de porte (chiffres)

-- À la fin d'un contrat (expiration, résiliation, revente) :
Config.OnContractEnd = {
    -- Coffre : chaque contrat a son propre coffre. L'ancien n'est ni vidé ni transmis :
    -- il reste en base, consultable et vidable par le staff (admin_menu › Gestion immobilière).
    stash = 'archive',
    -- Véhicules rangés dans le garage du bien : renvoyés au garage public (elyzea_garage),
    -- toujours à leur propriétaire réel, sans copie ni perte.
    vehicles = 'public_garage',
    publicGarageName = 'public',
}

-- Visites commerciales et sonnette
Config.Visit = { maxMinutes = 30, inviteDistance = 6.0 }
Config.Bell = { timeout = 45, cooldown = 20, accessMinutes = 30 }

-- Coffre et décoration par défaut (réglables par bien dans l'administration)
Config.Stash = { slots = 50, weight = 150 }      -- poids en kg
Config.Deco = {
    defaultLimit = 40, maxLimit = 200,
    maxDistance = 30.0,                            -- distance max d'un objet par rapport à l'entrée intérieure
    -- Modèles autorisés (l'administration peut en ajouter dans la tablette › Décoration)
    catalog = {
        { model = 'prop_couch_01', label = 'Canapé', cat = 'Salon' },
        { model = 'v_res_tre_sofa_mess_a', label = 'Canapé (2)', cat = 'Salon' },
        { model = 'prop_t_sofa', label = 'Canapé d\'angle', cat = 'Salon' },
        { model = 'prop_table_03', label = 'Table basse', cat = 'Salon' },
        { model = 'prop_tv_flat_01', label = 'Télévision', cat = 'Salon' },
        { model = 'prop_tv_flat_michael', label = 'Grande télévision', cat = 'Salon' },
        { model = 'v_res_m_armchair', label = 'Fauteuil', cat = 'Salon' },
        { model = 'apa_mp_h_stn_chairarm_01', label = 'Fauteuil design', cat = 'Salon' },
        { model = 'prop_table_04', label = 'Table', cat = 'Cuisine' },
        { model = 'prop_chair_04a', label = 'Chaise', cat = 'Cuisine' },
        { model = 'prop_fridge_01', label = 'Réfrigérateur', cat = 'Cuisine' },
        { model = 'prop_micro_01', label = 'Micro-ondes', cat = 'Cuisine' },
        { model = 'v_res_msonbed', label = 'Lit double', cat = 'Chambre' },
        { model = 'v_res_tre_bed2', label = 'Lit simple', cat = 'Chambre' },
        { model = 'v_res_tre_wardrobe', label = 'Armoire', cat = 'Chambre' },
        { model = 'v_res_m_lampstand', label = 'Lampadaire', cat = 'Éclairage' },
        { model = 'v_res_d_lampa', label = 'Lampe', cat = 'Éclairage' },
        { model = 'prop_plant_int_01a', label = 'Plante', cat = 'Décoration' },
        { model = 'prop_plant_int_03a', label = 'Grande plante', cat = 'Décoration' },
        { model = 'v_res_rubberplant', label = 'Caoutchouc', cat = 'Décoration' },
        { model = 'v_ilev_trev_pictureframe', label = 'Tableau', cat = 'Décoration' },
        { model = 'prop_rug_01', label = 'Tapis', cat = 'Décoration' },
        { model = 'v_res_tt_bookcase', label = 'Bibliothèque', cat = 'Rangement' },
        { model = 'prop_toilet_01', label = 'Toilettes', cat = 'Salle de bain' },
        { model = 'prop_sink_02', label = 'Lavabo', cat = 'Salle de bain' },
        { model = 'prop_bar_stool_01', label = 'Tabouret de bar', cat = 'Divers' },
        { model = 'prop_laptop_01a', label = 'Ordinateur portable', cat = 'Divers' },
        { model = 'prop_boombox_01', label = 'Radio', cat = 'Divers' },
    },
}

-- ---------------------------------------------------------------------
-- Garages
-- ---------------------------------------------------------------------
Config.GarageSizes = {
    small = { label = 'Petit garage', capacity = 2 },
    medium = { label = 'Garage moyen', capacity = 6 },
    large = { label = 'Grand garage', capacity = 10 },
}
Config.GarageMaxCapacity = 50

-- ---------------------------------------------------------------------
-- Intérieurs de départ (intérieurs du jeu de base, sans ressource supplémentaire).
-- Coordonnées d'usage courant dans la communauté FiveM : vérifiez-les en jeu
-- (admin_menu › Gestion immobilière › Intérieurs › Tester) et ajustez si besoin.
-- D'autres intérieurs (MLO, shells, IPL) s'ajoutent EN JEU sans toucher au code :
-- se placer dans l'intérieur › « Créer un intérieur ici ».
-- ipls : IPL à charger (laisser vide pour les intérieurs toujours présents).
-- ---------------------------------------------------------------------
Config.Interiors = {
    { code = 'low_apartment',    label = 'Appartement modeste',            kind = 'apartment', x = 261.4586, y = -998.8196, z = -99.00863, h = 0.0 },
    { code = 'mid_apartment',    label = 'Appartement standing moyen',     kind = 'apartment', x = 347.2686, y = -999.2955, z = -99.19622, h = 0.0 },
    { code = 'integrity_28',     label = '4 Integrity Way · Apt 28',       kind = 'apartment', x = -18.07856, y = -583.6725, z = 79.46569, h = 0.0 },
    { code = 'integrity_30',     label = '4 Integrity Way · Apt 30',       kind = 'apartment', x = -35.31277, y = -580.4199, z = 88.71221, h = 0.0 },
    { code = 'delperro_4',       label = 'Del Perro Heights · Apt 4',      kind = 'apartment', x = -1468.14, y = -541.815, z = 73.4442, h = 0.0 },
    { code = 'delperro_7',       label = 'Del Perro Heights · Apt 7',      kind = 'apartment', x = -1477.14, y = -538.7499, z = 55.5264, h = 0.0 },
    { code = 'richard_2',        label = 'Richard Majestic · Apt 2',       kind = 'apartment', x = -915.811, y = -379.432, z = 113.6748, h = 0.0 },
    { code = 'tinsel_42',        label = 'Tinsel Towers · Apt 42',         kind = 'apartment', x = -614.86, y = 40.6783, z = 97.60007, h = 0.0 },
    { code = 'eclipse_3',        label = 'Eclipse Towers · Apt 3',         kind = 'apartment', x = -773.407, y = 341.766, z = 211.397, h = 0.0 },
    { code = 'wildoats_3655',    label = '3655 Wild Oats Drive',           kind = 'house',     x = -169.286, y = 486.4938, z = 137.4436, h = 0.0 },
    { code = 'conker_2044',      label = '2044 North Conker Avenue',       kind = 'house',     x = 340.9412, y = 437.1798, z = 149.3925, h = 0.0 },
    { code = 'conker_2045',      label = '2045 North Conker Avenue',       kind = 'house',     x = 373.023, y = 416.105, z = 145.7006, h = 0.0 },
    { code = 'hillcrest_2862',   label = '2862 Hillcrest Avenue',          kind = 'villa',     x = -676.127, y = 588.612, z = 145.1698, h = 0.0 },
    { code = 'hillcrest_2868',   label = '2868 Hillcrest Avenue',          kind = 'villa',     x = -763.107, y = 615.906, z = 144.1401, h = 0.0 },
    { code = 'hillcrest_2874',   label = '2874 Hillcrest Avenue',          kind = 'villa',     x = -857.798, y = 682.563, z = 152.6529, h = 0.0 },
    { code = 'whispymound_2677', label = '2677 Whispymound Drive',         kind = 'villa',     x = 120.5, y = 549.952, z = 184.097, h = 0.0 },
    { code = 'madwayne_2133',    label = '2133 Mad Wayne Thunder',         kind = 'villa',     x = -1288.0, y = 440.748, z = 97.69459, h = 0.0 },
    { code = 'garage_2',         label = 'Garage 2 places',                kind = 'garage',    x = 173.2903, y = -1003.6, z = -99.65707, h = 0.0 },
    { code = 'garage_6',         label = 'Garage 6 places',                kind = 'garage',    x = 197.8153, y = -1002.293, z = -99.65749, h = 0.0 },
    { code = 'garage_10',        label = 'Garage 10 places',               kind = 'garage',    x = 229.9559, y = -981.7928, z = -99.66071, h = 0.0 },
}

Config.Categories = { apartment = 'Appartement', house = 'Maison', villa = 'Villa', garage = 'Garage' }
Config.PropertyStatuses = {
    available = { label = 'Disponible', color = '#22c55e' },
    reserved = { label = 'Réservé', color = '#a855f7' },
    rented = { label = 'En location', color = '#f97316' },
    sold = { label = 'Vendu', color = '#ef4444' },
    disabled = { label = 'Désactivé', color = '#64748b' },
}

-- Statuts de service (tablette, carte)
Config.Statuses = {
    { id = 'available', label = 'Disponible', color = '#22c55e' },
    { id = 'visit', label = 'En visite', color = '#3b82f6' },
    { id = 'office', label = 'Au bureau', color = '#a855f7' },
    { id = 'busy', label = 'Occupé', color = '#f59e0b' },
}

Config.Pay = { maxRate = 100000 }
Config.MapRefresh = 5000
Config.MapImage = { file = 'img/map.jpg', minX = -5661.2, maxX = 6694.0, minY = -4058.5, maxY = 8429.3 }

-- Grades du premier démarrage (salary = taux horaire de départ, réglé ensuite dans Finance)
Config.DefaultGrades = {
    { name = 'Stagiaire',          level = 1, salary = 300, default = true,
      perms = { 'duty', 'tablet', 'visits' } },
    { name = 'Agent immobilier',   level = 2, salary = 500,
      perms = { 'duty', 'tablet', 'visits', 'sell', 'rent', 'properties_view' } },
    { name = 'Agent confirmé',     level = 3, salary = 650,
      perms = { 'duty', 'tablet', 'visits', 'sell', 'rent', 'properties_view', 'contracts_manage' } },
    { name = 'Responsable d\'agence', level = 4, salary = 850,
      perms = { 'duty', 'tablet', 'visits', 'sell', 'rent', 'properties_view', 'contracts_manage', 'prices_manage', 'direction',
                'recruit', 'employees_view', 'promote', 'demote', 'history_view', 'finance' } },
    { name = 'Directeur',          level = 5, salary = 1100, perms = 'all' },
}
