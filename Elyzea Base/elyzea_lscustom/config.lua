Config = {}

-- =====================================================================
--  TOUCHES (modifiables par chaque joueur : Paramètres > Raccourcis > FiveM)
-- =====================================================================
Config.Keys = {
    menu = 'F6',   -- menu de l'atelier (mécaniciens)
    neons = '',    -- allumer / éteindre ses néons au volant (à assigner, ou /neons)
}

-- =====================================================================
--  PERMISSIONS DE GRADE (cases à cocher dans admin_menu > Métiers > LsCustom)
-- =====================================================================
Config.Permissions = {
    { key = 'repair',  label = 'Réparer' },
    { key = 'clean',   label = 'Nettoyer' },
    { key = 'modify',  label = 'Modifier (personnalisation)' },
    { key = 'invoice', label = 'Facturer' },
    { key = 'garage',  label = 'Sortir un véhicule de service' },
    { key = 'prices',  label = 'Gérer les prix (en jeu)' },
}

-- =====================================================================
--  TYPES DE ZONES
-- =====================================================================
Config.ZoneTypes = {
    { key = 'modification', label = 'Modification',   color = { 217, 181, 106 } },
    { key = 'service',      label = 'Service',        color = { 79, 179, 169 } },
    { key = 'vestiaire',    label = 'Vestiaire',      color = { 140, 120, 220 } },
    { key = 'garage',       label = 'Garage',         color = { 59, 111, 224 } },
    { key = 'spawn',        label = 'Spawn véhicule', color = { 59, 111, 224 } },
    { key = 'parking',      label = 'Parking',        color = { 120, 140, 170 } },
    { key = 'reparation',   label = 'Réparation',     color = { 224, 67, 59 } },
    { key = 'nettoyage',    label = 'Nettoyage',      color = { 90, 190, 240 } },
}

-- =====================================================================
--  CATALOGUE DES PRESTATIONS (les prix se règlent en jeu)
--  kind : mod (pièce GTA), toggle, wheels, paint, pearl, wheelcolor,
--         neon, xenon, tint, plate, livery, smoke, service
--  perLevel = true : prix × niveau (niveau 1, 2, 3…)
-- =====================================================================
Config.Catalog = {
    -- Services
    { key = 'repair', label = 'Réparation complète', group = 'service', kind = 'service' },
    { key = 'clean',  label = 'Nettoyage',           group = 'service', kind = 'service' },
    { key = 'tyres',  label = 'Réparation des roues', group = 'service', kind = 'service' },

    -- Esthétique : carrosserie
    { key = 'fbumper', label = 'Pare-choc avant',     group = 'esthetique', kind = 'mod', mod = 1 },
    { key = 'rbumper', label = 'Pare-choc arrière',   group = 'esthetique', kind = 'mod', mod = 2 },
    { key = 'skirts',  label = 'Bas de caisse',       group = 'esthetique', kind = 'mod', mod = 3 },
    { key = 'spoiler', label = 'Aileron',             group = 'esthetique', kind = 'mod', mod = 0 },
    { key = 'hood',    label = 'Capot',               group = 'esthetique', kind = 'mod', mod = 7 },
    { key = 'grille',  label = 'Calandre',            group = 'esthetique', kind = 'mod', mod = 6 },
    { key = 'exhaust', label = 'Échappement',         group = 'esthetique', kind = 'mod', mod = 4 },
    { key = 'frame',   label = 'Arceau',              group = 'esthetique', kind = 'mod', mod = 5 },
    { key = 'lfender', label = 'Aile gauche',         group = 'esthetique', kind = 'mod', mod = 8 },
    { key = 'rfender', label = 'Aile droite',         group = 'esthetique', kind = 'mod', mod = 9 },
    { key = 'roof',    label = 'Toit',                group = 'esthetique', kind = 'mod', mod = 10 },
    { key = 'archcover', label = 'Passages de roue',  group = 'esthetique', kind = 'mod', mod = 42 },
    { key = 'aerials', label = 'Antennes',            group = 'esthetique', kind = 'mod', mod = 43 },
    { key = 'trim2',   label = 'Garnitures extérieures', group = 'esthetique', kind = 'mod', mod = 44 },
    { key = 'tank',    label = 'Réservoir',           group = 'esthetique', kind = 'mod', mod = 45 },
    { key = 'windows', label = 'Fenêtres',            group = 'esthetique', kind = 'mod', mod = 46 },
    { key = 'trunk',   label = 'Coffre',              group = 'esthetique', kind = 'mod', mod = 37 },
    { key = 'hydraulics', label = 'Hydraulique',      group = 'esthetique', kind = 'mod', mod = 38 },
    { key = 'engineblock', label = 'Bloc moteur',     group = 'esthetique', kind = 'mod', mod = 39 },
    { key = 'airfilter', label = 'Filtre à air',      group = 'esthetique', kind = 'mod', mod = 40 },
    { key = 'struts',  label = 'Barres de renfort',   group = 'esthetique', kind = 'mod', mod = 41 },

    -- Esthétique : roues, peinture, lumières
    { key = 'wheels',     label = 'Jantes',               group = 'esthetique', kind = 'wheels' },
    { key = 'paint1',     label = 'Peinture principale',  group = 'esthetique', kind = 'paint' },
    { key = 'paint2',     label = 'Peinture secondaire',  group = 'esthetique', kind = 'paint' },
    { key = 'pearl',      label = 'Nacrage',              group = 'esthetique', kind = 'pearl' },
    { key = 'wheelcolor', label = 'Couleur des jantes',   group = 'esthetique', kind = 'wheelcolor' },
    { key = 'neon',       label = 'Néons',                group = 'esthetique', kind = 'neon' },
    { key = 'xenon',      label = 'Phares xénon',         group = 'esthetique', kind = 'xenon' },
    { key = 'tint',       label = 'Vitres teintées',      group = 'esthetique', kind = 'tint' },
    { key = 'plate',      label = 'Plaques',              group = 'esthetique', kind = 'plate' },
    { key = 'livery',     label = 'Livrées',              group = 'esthetique', kind = 'livery' },
    { key = 'smoke',      label = 'Fumée des pneus',      group = 'esthetique', kind = 'smoke' },
    { key = 'horn',       label = 'Klaxon',               group = 'esthetique', kind = 'mod', mod = 14 },

    -- Esthétique : intérieur
    { key = 'plateholder', label = 'Support de plaque',  group = 'esthetique', kind = 'mod', mod = 25 },
    { key = 'vanity',      label = 'Plaque personnalisée', group = 'esthetique', kind = 'mod', mod = 26 },
    { key = 'trim',        label = 'Garnitures',         group = 'esthetique', kind = 'mod', mod = 27 },
    { key = 'ornaments',   label = 'Ornements',          group = 'esthetique', kind = 'mod', mod = 28 },
    { key = 'dashboard',   label = 'Tableau de bord',    group = 'esthetique', kind = 'mod', mod = 29 },
    { key = 'dials',       label = 'Compteurs',          group = 'esthetique', kind = 'mod', mod = 30 },
    { key = 'doorspeakers',label = 'Haut-parleurs de portes', group = 'esthetique', kind = 'mod', mod = 31 },
    { key = 'seats',       label = 'Sièges',             group = 'esthetique', kind = 'mod', mod = 32 },
    { key = 'steering',    label = 'Volant',             group = 'esthetique', kind = 'mod', mod = 33 },
    { key = 'shifter',     label = 'Levier de vitesse',  group = 'esthetique', kind = 'mod', mod = 34 },
    { key = 'plaques',     label = 'Plaques décoratives', group = 'esthetique', kind = 'mod', mod = 35 },
    { key = 'speakers',    label = 'Sono',               group = 'esthetique', kind = 'mod', mod = 36 },

    -- Performance
    { key = 'engine',       label = 'Moteur',       group = 'performance', kind = 'mod', mod = 11, perLevel = true },
    { key = 'brakes',       label = 'Freins',       group = 'performance', kind = 'mod', mod = 12, perLevel = true },
    { key = 'transmission', label = 'Transmission', group = 'performance', kind = 'mod', mod = 13, perLevel = true },
    { key = 'suspension',   label = 'Suspension',   group = 'performance', kind = 'mod', mod = 15, perLevel = true },
    { key = 'armor',        label = 'Blindage',     group = 'performance', kind = 'mod', mod = 16, perLevel = true },
    { key = 'turbo',        label = 'Turbo',        group = 'performance', kind = 'toggle', mod = 18 },
}

-- Couleurs de peinture (index GTA)
Config.Colors = {
    { id = 0,   label = 'Noir',              type = 'Métallisé' },
    { id = 1,   label = 'Graphite',          type = 'Métallisé' },
    { id = 4,   label = 'Argent',            type = 'Métallisé' },
    { id = 111, label = 'Blanc',             type = 'Métallisé' },
    { id = 27,  label = 'Rouge',             type = 'Métallisé' },
    { id = 28,  label = 'Rouge Torino',      type = 'Métallisé' },
    { id = 35,  label = 'Rouge bonbon',      type = 'Métallisé' },
    { id = 38,  label = 'Orange',            type = 'Métallisé' },
    { id = 88,  label = 'Jaune',             type = 'Métallisé' },
    { id = 89,  label = 'Jaune course',      type = 'Métallisé' },
    { id = 53,  label = 'Vert',              type = 'Métallisé' },
    { id = 55,  label = 'Vert lime',         type = 'Métallisé' },
    { id = 49,  label = 'Vert foncé',        type = 'Métallisé' },
    { id = 64,  label = 'Bleu',              type = 'Métallisé' },
    { id = 70,  label = 'Bleu ultra',        type = 'Métallisé' },
    { id = 62,  label = 'Bleu foncé',        type = 'Métallisé' },
    { id = 61,  label = 'Bleu nuit',         type = 'Métallisé' },
    { id = 145, label = 'Violet',            type = 'Métallisé' },
    { id = 135, label = 'Rose vif',          type = 'Métallisé' },
    { id = 90,  label = 'Bronze',            type = 'Métallisé' },
    { id = 96,  label = 'Chocolat',          type = 'Métallisé' },
    { id = 99,  label = 'Beige',             type = 'Métallisé' },
    { id = 12,  label = 'Noir mat',          type = 'Mat' },
    { id = 13,  label = 'Gris mat',          type = 'Mat' },
    { id = 131, label = 'Blanc mat',         type = 'Mat' },
    { id = 39,  label = 'Rouge mat',         type = 'Mat' },
    { id = 128, label = 'Vert mat',          type = 'Mat' },
    { id = 83,  label = 'Bleu mat',          type = 'Mat' },
    { id = 117, label = 'Acier brossé',      type = 'Métal' },
    { id = 118, label = 'Noir brossé',       type = 'Métal' },
    { id = 119, label = 'Aluminium brossé',  type = 'Métal' },
    { id = 158, label = 'Or pur',            type = 'Métal' },
    { id = 159, label = 'Or brossé',         type = 'Métal' },
    { id = 120, label = 'Chrome',            type = 'Métal' },
}

Config.LightColors = {   -- néons et fumée des pneus
    { id = 1,  label = 'Blanc',          rgb = { 255, 255, 255 } },
    { id = 2,  label = 'Bleu',           rgb = { 2, 21, 255 } },
    { id = 3,  label = 'Bleu électrique', rgb = { 3, 83, 255 } },
    { id = 4,  label = 'Vert menthe',    rgb = { 0, 255, 140 } },
    { id = 5,  label = 'Vert lime',      rgb = { 94, 255, 1 } },
    { id = 6,  label = 'Jaune',          rgb = { 255, 255, 0 } },
    { id = 7,  label = 'Or',             rgb = { 255, 150, 5 } },
    { id = 8,  label = 'Orange',         rgb = { 255, 62, 0 } },
    { id = 9,  label = 'Rouge',          rgb = { 255, 1, 1 } },
    { id = 10, label = 'Rose',           rgb = { 255, 50, 100 } },
    { id = 11, label = 'Rose vif',       rgb = { 255, 5, 190 } },
    { id = 12, label = 'Violet',         rgb = { 35, 1, 255 } },
}

-- Néons animés (proposés dans la catégorie « Néons » de la personnalisation)
Config.NeonEffects = {
    { id = 'rainbow', label = '🌈 Arc-en-ciel animé' },
    { id = 'elyzea',  label = '✨ Elyzea animé (bleu · or · rouge)' },
}
Config.NeonSpeed = 0.12       -- vitesse de l'arc-en-ciel (tours de couleur par seconde)
Config.NeonViewDistance = 120.0

Config.XenonColors = {
    { id = 0, label = 'Blanc' }, { id = 1, label = 'Bleu' }, { id = 2, label = 'Bleu électrique' }, { id = 3, label = 'Vert menthe' },
    { id = 4, label = 'Vert lime' }, { id = 5, label = 'Jaune' }, { id = 6, label = 'Or' }, { id = 7, label = 'Orange' },
    { id = 8, label = 'Rouge' }, { id = 9, label = 'Rose' }, { id = 10, label = 'Rose vif' }, { id = 11, label = 'Violet' },
    { id = 12, label = 'Lumière noire' },
}

Config.Tints = {
    { id = 0, label = 'Aucune' }, { id = 3, label = 'Fumé clair' }, { id = 2, label = 'Fumé foncé' },
    { id = 5, label = 'Limousine' }, { id = 1, label = 'Noir pur' }, { id = 6, label = 'Vert' },
}

Config.Plates = {
    { id = 0, label = 'Bleu sur blanc' }, { id = 3, label = 'Bleu sur blanc (2)' }, { id = 4, label = 'Bleu sur blanc (3)' },
    { id = 1, label = 'Jaune sur noir' }, { id = 2, label = 'Jaune sur bleu' }, { id = 5, label = 'North Yankton' },
}

Config.WheelTypes = {
    { id = 0, label = 'Sport' }, { id = 1, label = 'Muscle' }, { id = 2, label = 'Lowrider' }, { id = 3, label = 'SUV' },
    { id = 4, label = 'Tout-terrain' }, { id = 5, label = 'Tuner' }, { id = 7, label = 'Haut de gamme' },
    { id = 8, label = "Benny's Original" }, { id = 9, label = "Benny's Bespoke" }, { id = 11, label = 'Street' },
    { id = 12, label = 'Track' }, { id = 6, label = 'Moto' },
}

-- =====================================================================
--  VALEURS DE DÉPART (premier démarrage). Ensuite : admin_menu > Métiers > LsCustom
-- =====================================================================
Config.Defaults = {
    enabled = true,
    job = {
        name = 'lscustom', label = 'Los Santos Customs', type = 'mechanic', defaultDuty = false, offDutyPay = false,
        grades = {
            { id = 'stagiaire',  label = 'Stagiaire',           payment = 50 },
            { id = 'mecanicien', label = 'Mécanicien',          payment = 80 },
            { id = 'confirme',   label = 'Mécanicien confirmé', payment = 110 },
            { id = 'chef',       label = "Chef d'atelier",      payment = 140 },
            { id = 'patron',     label = 'Patron',              payment = 180, isboss = true },
        },
    },
    -- [grade] = permissions
    perms = {
        ['0'] = { repair = true, clean = true },
        ['1'] = { repair = true, clean = true, modify = true, invoice = true },
        ['2'] = { repair = true, clean = true, modify = true, invoice = true, garage = true },
        ['3'] = { repair = true, clean = true, modify = true, invoice = true, garage = true },
        ['4'] = { repair = true, clean = true, modify = true, invoice = true, garage = true, prices = true },
    },
    -- Zones de départ : LS Customs de Burton (positions approximatives, à ajuster en jeu)
    zones = {
        { type = 'modification', label = 'Atelier principal',  x = -337.4, y = -136.9, z = 39.0,  h = 70.0,  radius = 7.0 },
        { type = 'reparation',   label = 'Baie de réparation', x = -324.2, y = -132.8, z = 39.0,  h = 70.0,  radius = 5.0 },
        { type = 'nettoyage',    label = 'Station de lavage',  x = -330.6, y = -146.2, z = 39.0,  h = 70.0,  radius = 4.0 },
        { type = 'service',      label = 'Accueil',            x = -347.3, y = -133.4, z = 39.0,  h = 160.0, radius = 1.5 },
        { type = 'vestiaire',    label = 'Vestiaire',          x = -345.0, y = -123.4, z = 39.0,  h = 160.0, radius = 1.5 },
        { type = 'garage',       label = 'Garage de service',  x = -357.2, y = -114.3, z = 38.7,  h = 70.0,  radius = 1.5 },
        { type = 'spawn',        label = 'Sortie des véhicules', x = -369.8, y = -107.6, z = 38.7, h = 70.0, radius = 3.0 },
        { type = 'parking',      label = 'Rangement',          x = -365.6, y = -116.0, z = 38.7,  h = 70.0,  radius = 5.0 },
    },
    prices = {
        repair = 500, clean = 100, tyres = 250,
        fbumper = 900, rbumper = 900, skirts = 700, spoiler = 1200, hood = 1100, grille = 450, exhaust = 600, frame = 800,
        lfender = 500, rfender = 500, roof = 650, archcover = 400, aerials = 250, trim2 = 300, tank = 300, windows = 300,
        trunk = 400, hydraulics = 2500, engineblock = 600, airfilter = 350, struts = 450,
        wheels = 1500, paint1 = 1200, paint2 = 800, pearl = 900, wheelcolor = 500, neon = 2000, xenon = 900, tint = 600,
        plate = 300, livery = 1500, smoke = 700, horn = 250,
        plateholder = 200, vanity = 250, trim = 400, ornaments = 200, dashboard = 450, dials = 300, doorspeakers = 300,
        seats = 600, steering = 400, shifter = 250, plaques = 200, speakers = 500,
        engine = 2500, brakes = 1500, transmission = 2000, suspension = 1200, armor = 3000, turbo = 5000,
    },
    settings = {
        commission = 20,          -- % de chaque facture pour le mécanicien (le reste va au métier)
        societyDeposit = true,    -- verser le reste au compte du métier (Renewed-Banking)
        maxInvoice = 100000,      -- facture maximum
        invoiceTimeout = 60,      -- secondes pour accepter une facture
        repairTime = 12,          -- secondes de réparation
        cleanTime = 6,            -- secondes de nettoyage
        workInZonesOnly = true,   -- réparer / nettoyer / modifier seulement dans les zones prévues
        showBlips = true,         -- icône sur la carte pour les zones « Modification »
        maxServiceVehicles = 1,   -- véhicules de service par mécanicien
        serviceVehicles = {
            { model = 'towtruck2', label = 'Dépanneuse',   grade = 0 },
            { model = 'flatbed',   label = 'Plateau',      grade = 2 },
        },
    },
}
