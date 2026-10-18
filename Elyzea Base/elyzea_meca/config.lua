-- =====================================================================
--  ELYZEA MÉCANO - configuration
--  Les tarifs, le catalogue, les grades, les permissions et les taux horaires
--  se gèrent EN JEU dans la tablette › Direction (ils sont gardés en base).
--  Les points d'atelier se placent aussi en jeu. Ici : les durées, les limites et les valeurs de départ.
-- =====================================================================
Config = {}

-- Métier et compte de société d'elyzea_core
Config.Job = { name = 'mechanic', label = 'Mécano', type = 'mechanic' }
-- Agences (elyzea_agences) : plusieurs agences de ce métier, chacune son métier elyzea_core,
-- ses grades, son compte, son téléphone et sa zone d'alerte. Config.Job ci-dessus = première agence.
Config.AgencyKind = 'meca'
Config.Society = 'mechanic'

Config.Keys = {
    menu = 'F6',
    acceptAlert = 'G', declineAlert = 'I',
    workshop = 38,                -- E (code de contrôle GTA) aux points d'atelier
}

Config.Distances = {
    vehicle = 5.0,                -- réparer / nettoyer / retourner : distance au véhicule
    quote = 6.0,                  -- envoyer un devis de prestations (F6) : distance du client
    workshopCustomer = 25.0,      -- atelier : distance entre le client et son véhicule sur le point
}

Config.Matricule = { prefix = 'MECA-', digits = 3 }
Config.Recruit = { distance = 5.0, timeout = 30, cooldown = 8 }

-- ---------------------------------------------------------------------
-- Réparations (ALT sur un véhicule) : durées en millisecondes
-- full = moteur + carrosserie + pneus + réservoir (permission « repair_full »)
-- ---------------------------------------------------------------------
Config.Repair = {
    engine = { label = 'Réparer le moteur',      duration = 12000 },
    body   = { label = 'Réparer la carrosserie', duration = 12000 },
    tyres  = { label = 'Réparer les pneus',      duration = 8000 },
    full   = { label = 'Réparation complète',    duration = 20000 },
    clean  = { label = 'Nettoyer le véhicule',   duration = 8000 },
    flip   = { label = 'Retourner le véhicule',  duration = 6000 },
}

-- ---------------------------------------------------------------------
-- Points d'atelier (touche E) : placés EN JEU par la direction
-- (tablette › Direction › Points d'atelier), autant que vous voulez.
-- Rubriques possibles : 'perf', 'cosmetic', 'paint', 'wheels', 'lights', 'interior', 'carplay', 'service'
-- ---------------------------------------------------------------------
Config.WorkshopDefaults = { radius = 3.5, categories = { 'perf', 'cosmetic', 'paint', 'wheels', 'lights', 'interior', 'carplay', 'service' }, minLevel = 1 }
Config.WorkshopMax = 30
Config.WorkshopMarker = true      -- marqueur au sol pour les mécaniciens en service

-- ---------------------------------------------------------------------
-- Interventions animées à l'installation d'un devis (client/interventions.lua)
-- Après paiement, « Installer » lance le vrai travail : pont / chandelles, sous le véhicule,
-- roue par roue, capot, carrosserie… chaque pièce apparaît au moment où elle est posée.
-- Animations et modèles : noms du jeu, vérifiés au chargement (absent = étape sans l'objet).
-- ---------------------------------------------------------------------
Config.Interventions = {
    speed = 0.6,              -- multiplie toutes les durées (0.5 = deux fois plus rapide, 1.0 = lent et détaillé)
    walkSpeed = 1.6,          -- vitesse de marche du mécanicien autour du véhicule (1.0 = marche, 2.0 = course)
    maxDistance = 12.0,       -- le mécanicien qui s'éloigne plus que ça du véhicule interrompt l'intervention
    serverTimeout = 120,      -- secondes sans nouvelle du mécanicien → intervention libérée, scène remise en état
    debug = false,            -- détails dans la console F8 (modèle ou animation manquants, lignes posées)

    -- Levage pour moteur-dessous / freins / transmission / suspension / échappement :
    --  · sans modèle de pont : chandelles (crics) sous les roues, véhicule levé de standsHeight,
    --    le mécanicien travaille allongé sur un chariot (scénario WORLD_HUMAN_VEHICLE_MECHANIC) ;
    --  · avec le modèle d'un pont de ta map (model = 'nom_du_modele') : posé sous le véhicule,
    --    véhicule levé de height, le mécanicien travaille debout dessous (underLiftScenario).
    --    platformMoves = true si le modèle est un plateau qui doit monter avec le véhicule.
    lift = { model = nil, height = 1.6, offsetZ = 0.0, heading = 0.0, platformMoves = false, standsHeight = 0.5,
        -- Pont roulant posé avec l'objet (points équipés) : véhicule levé pour laisser clearance mètres
        -- sous la caisse (le mécanicien passe dessous debout), puis wheelHeight pour les roues / freins.
        clearance = 1.95, wheelHeight = 0.5,
        -- Dessin du pont (aucun modèle de pont garanti dans le jeu de base) : couleurs et hauteur des colonnes
        color = { 235, 180, 20 }, darkColor = { 60, 60, 66 }, postHeight = 2.9, drawDistance = 45.0,
        armSwing = 1.0,       -- secondes pour que les 4 bras pivotent sous la voiture (ou se replient)
        -- Modèle réel (ta map ou un pack) à la place du dessin : models = { 'nom_du_modele' }, offsetZ, heading
        models = {},
    },
    -- Objet d'inventaire « Pont roulant » (5 kg)
    -- Posé (utilisé) à côté d'un véhicule garé sur un point d'atelier ; H à côté du pont pour le reprendre
    liftItem = { name = 'pont_roulant', perm = 'workshop', range = 3.0, vehicleRange = 5.0, pickupKey = 74 },
    underLiftScenarios = { 'PROP_HUMAN_MOVIE_BULB', 'WORLD_HUMAN_WELDING' },   -- debout sous le véhicule, bras levés
    walkMargin = 0.85,        -- distance gardée autour de la carrosserie quand le mécanicien fait le tour
    collisionPad = 0.3,
    jackHeight = 0.12,        -- roue changée sans pont : le véhicule se soulève légèrement au cric
    underSide = 'left',       -- côté par lequel le mécanicien se glisse sous le véhicule
    underOffset = 0.35,       -- distance au bord du véhicule avant de s'allonger (à ajuster selon le rendu)
    underHeadingOffset = 0.0, -- correction d'orientation (degrés) si le mécanicien s'allonge dans le mauvais sens
    paintScenario = 'WORLD_HUMAN_MAID_CLEAN',
    allWheels = true,         -- jantes / pneus : passer aux 4 roues (false = une seule roue)
    brakesRear = false,       -- freins : aussi les roues arrière
    detachHood = true,        -- capot : l'ancien capot disparaît pendant le remplacement (seulement si la carrosserie est intacte)
    removeTyres = true,       -- roues : le pneu est retiré visuellement (seulement s'il n'était pas déjà crevé)

    -- Durées de chaque travail (ms, avant « speed »)
    durations = {
        liftUp = 4000, liftDown = 3500, liftArms = 1200, carry = 4000,
        transmission = 14000, exhaust = 12000, suspension = 12000, brakes = 8000, brakesSwap = 3000, wheel = 9000, wheelpaint = 7000,
        engine = 14000, turbo = 14000, enginebay = 10000, hood = 12000, armor = 14000, panel = 10000, roof = 9000,
        paint = 16000, tint = 9000, lights = 8000, neon = 9000, plate = 7000, interior = 10000, carplay = 10000,
    },

    -- Animations { dictionnaire, nom, drapeau }
    anims = {
        hoodWork  = { 'mini@repair', 'fixing_a_ped', 1 },                                          -- penché sur le moteur
        standWork = { 'mini@repair', 'fixing_a_player', 1 },                                       -- travail debout sur la carrosserie
        kneelWork = { 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer', 1 }, -- accroupi (roues, bas de caisse)
        kneel     = { 'amb@medic@standing@kneel@base', 'base', 1 },                                -- à genoux (plaque)
        carry     = { 'anim@heists@box_carry@', 'idle', 49 },                                      -- porter une pièce en marchant
        interior  = { 'anim@gangops@facility@servers@bodysearch@', 'player_search', 1 },           -- penché dans l'habitacle
        tablet    = { 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base', 49 },    -- CarPlay (tablette)
        finish    = { 'anim@mp_player_intmenu@key_fob@', 'fob_click', 48 },                        -- fin : clé du véhicule
    },

    -- Objets : liste de modèles (le premier qui existe est utilisé), os de la main, position, rotation
    -- 57005 = main droite, 60309 = main gauche (prise « carton » des deux mains avec l'animation carry)
    props = {
        wrench  = { models = { 'prop_cs_wrench' }, bone = 57005, pos = { 0.10, 0.03, -0.02 }, rot = { -90.0, 0.0, 0.0 } },
        tablet  = { models = { 'prop_cs_tablet' }, bone = 60309, pos = { 0.03, 0.002, 0.0 }, rot = { 10.0, 160.0, 0.0 } },
        jack    = { 'prop_carjack', 'imp_prop_car_jack_01a' },
        wheel   = { models = { 'imp_prop_impexp_tyre_01a', 'prop_wheel_tyre' }, bone = 60309, pos = { 0.025, 0.08, 0.255 }, rot = { -145.0, 290.0, 0.0 } },
        caliper = { models = { 'imp_prop_impexp_brake_caliper_01a' }, bone = 57005, pos = { 0.10, 0.02, -0.02 }, rot = { 0.0, 0.0, 0.0 } },
        hood    = { models = { 'imp_prop_impexp_bonnet_02a', 'imp_prop_impexp_bonnet_01a' }, bone = 60309, pos = { 0.025, 0.08, 0.255 }, rot = { -145.0, 290.0, 0.0 } },
        frontBumper = { models = { 'imp_prop_impexp_front_bumper_01a' }, bone = 60309, pos = { 0.025, 0.08, 0.255 }, rot = { -145.0, 290.0, 0.0 } },
        rearBumper  = { models = { 'imp_prop_impexp_rear_bumper_01a' }, bone = 60309, pos = { 0.025, 0.08, 0.255 }, rot = { -145.0, 290.0, 0.0 } },
        spoiler = { models = { 'imp_prop_impexp_spoiler_01a' }, bone = 60309, pos = { 0.025, 0.08, 0.255 }, rot = { -145.0, 290.0, 0.0 } },
        panel   = { models = { 'imp_prop_impexp_car_panel_01a' }, bone = 60309, pos = { 0.025, 0.08, 0.255 }, rot = { -145.0, 290.0, 0.0 } },
        door    = { models = { 'imp_prop_impexp_car_door_04a' }, bone = 60309, pos = { 0.025, 0.08, 0.255 }, rot = { -145.0, 290.0, 0.0 } },
    },
}

-- ---------------------------------------------------------------------
-- Devis et paiement
-- ---------------------------------------------------------------------
Config.Quotes = {
    acceptTimeout = 90,           -- secondes pour que le client accepte le devis
    installTimeout = 1800,        -- secondes après acceptation pour installer (sinon remboursement automatique)
    maxItems = 40,
    payWith = 'bank_then_cash',   -- prélevé à l'acceptation : banque, puis liquide
    allowSelf = true,             -- le mécanicien peut s'envoyer le devis à lui-même (ses propres customs : il paie à l'envoi)
    selfCommission = false,       -- commission du mécanicien sur ses propres devis
}

-- Catalogue de départ : copié en base au premier démarrage, ensuite modifiable dans la tablette.
-- kind : service | perf | cosmetic | carplay | custom
-- mod / level : modification GTA concernée et niveau (perf) ; category : rubrique de l'atelier
Config.DefaultCatalog = {
    -- Prestations
    { code = 'repair_engine', name = 'Réparation moteur',        category = 'service', kind = 'service', price = 600 },
    { code = 'repair_body',   name = 'Réparation carrosserie',   category = 'service', kind = 'service', price = 500 },
    { code = 'repair_tyres',  name = 'Réparation des pneus',     category = 'service', kind = 'service', price = 250 },
    { code = 'repair_full',   name = 'Réparation complète',      category = 'service', kind = 'service', price = 1200, minLevel = 2 },
    { code = 'clean',         name = 'Nettoyage',                category = 'service', kind = 'service', price = 150 },
    { code = 'flip',          name = 'Remise sur roues',         category = 'service', kind = 'service', price = 300 },
    { code = 'tow',           name = 'Remorquage / déplacement', category = 'service', kind = 'service', price = 400 },
    -- Performances (un article par niveau)
    { code = 'engine_1', name = 'Moteur niveau 1', category = 'perf', kind = 'perf', mod = 'engine', level = 1, price = 2500 },
    { code = 'engine_2', name = 'Moteur niveau 2', category = 'perf', kind = 'perf', mod = 'engine', level = 2, price = 4500 },
    { code = 'engine_3', name = 'Moteur niveau 3', category = 'perf', kind = 'perf', mod = 'engine', level = 3, price = 7500, minLevel = 2 },
    { code = 'engine_4', name = 'Moteur niveau 4', category = 'perf', kind = 'perf', mod = 'engine', level = 4, price = 11000, minLevel = 3 },
    { code = 'brakes_1', name = 'Freins niveau 1', category = 'perf', kind = 'perf', mod = 'brakes', level = 1, price = 1500 },
    { code = 'brakes_2', name = 'Freins niveau 2', category = 'perf', kind = 'perf', mod = 'brakes', level = 2, price = 2800 },
    { code = 'brakes_3', name = 'Freins niveau 3', category = 'perf', kind = 'perf', mod = 'brakes', level = 3, price = 4200 },
    { code = 'transmission_1', name = 'Transmission niveau 1', category = 'perf', kind = 'perf', mod = 'transmission', level = 1, price = 2000 },
    { code = 'transmission_2', name = 'Transmission niveau 2', category = 'perf', kind = 'perf', mod = 'transmission', level = 2, price = 3800 },
    { code = 'transmission_3', name = 'Transmission niveau 3', category = 'perf', kind = 'perf', mod = 'transmission', level = 3, price = 5600 },
    { code = 'suspension_1', name = 'Suspension niveau 1', category = 'perf', kind = 'perf', mod = 'suspension', level = 1, price = 1000 },
    { code = 'suspension_2', name = 'Suspension niveau 2', category = 'perf', kind = 'perf', mod = 'suspension', level = 2, price = 1800 },
    { code = 'suspension_3', name = 'Suspension niveau 3', category = 'perf', kind = 'perf', mod = 'suspension', level = 3, price = 2600 },
    { code = 'suspension_4', name = 'Suspension niveau 4', category = 'perf', kind = 'perf', mod = 'suspension', level = 4, price = 3400 },
    { code = 'armor_1', name = 'Blindage 20 %', category = 'perf', kind = 'perf', mod = 'armor', level = 1, price = 3000, enabled = false },
    { code = 'armor_2', name = 'Blindage 40 %', category = 'perf', kind = 'perf', mod = 'armor', level = 2, price = 5000, enabled = false },
    { code = 'turbo', name = 'Turbo', category = 'perf', kind = 'perf', mod = 'turbo', level = 1, price = 6000 },
    -- Esthétique : un prix par pièce installée dans chaque rubrique
    { code = 'cosmetic_body',     name = 'Pièce de carrosserie',     category = 'cosmetic', kind = 'cosmetic', mod = 'body', price = 750 },
    { code = 'cosmetic_paint',    name = 'Peinture',                 category = 'paint',    kind = 'cosmetic', mod = 'paint', price = 900 },
    { code = 'cosmetic_pearl',    name = 'Nacrage',                  category = 'paint',    kind = 'cosmetic', mod = 'pearl', price = 600 },
    { code = 'cosmetic_livery',   name = 'Livrée',                   category = 'paint',    kind = 'cosmetic', mod = 'livery', price = 1200 },
    { code = 'cosmetic_tint',     name = 'Vitres teintées',          category = 'paint',    kind = 'cosmetic', mod = 'tint', price = 500 },
    { code = 'cosmetic_plate',    name = 'Style de plaque',          category = 'paint',    kind = 'cosmetic', mod = 'plate', price = 300 },
    { code = 'cosmetic_wheels',   name = 'Jantes',                   category = 'wheels',   kind = 'cosmetic', mod = 'wheels', price = 1500 },
    { code = 'cosmetic_wheelcolor', name = 'Couleur des jantes',     category = 'wheels',   kind = 'cosmetic', mod = 'wheelcolor', price = 400 },
    { code = 'cosmetic_smoke',    name = 'Fumée des pneus',          category = 'wheels',   kind = 'cosmetic', mod = 'smoke', price = 800 },
    { code = 'cosmetic_neon',     name = 'Néons',                    category = 'lights',   kind = 'cosmetic', mod = 'neon', price = 1500 },
    { code = 'cosmetic_xenon',    name = 'Phares xénon',             category = 'lights',   kind = 'cosmetic', mod = 'xenon', price = 900 },
    { code = 'cosmetic_interior', name = 'Pièce d\'intérieur',       category = 'interior', kind = 'cosmetic', mod = 'interior', price = 450 },
    { code = 'cosmetic_intcolor', name = 'Couleur de l\'intérieur',   category = 'interior', kind = 'cosmetic', mod = 'intcolor', price = 400 },
    { code = 'cosmetic_dashcolor', name = 'Couleur du tableau de bord', category = 'interior', kind = 'cosmetic', mod = 'dashcolor', price = 300 },
    { code = 'cosmetic_roofliv',  name = 'Livrée de toit',           category = 'paint',    kind = 'cosmetic', mod = 'roofliv', price = 900 },
    { code = 'cosmetic_tyres',    name = 'Pneus (flancs)', category = 'wheels', kind = 'cosmetic', mod = 'tyres', price = 2500 },
    { code = 'cosmetic_extras',   name = 'Éléments optionnels',      category = 'cosmetic', kind = 'cosmetic', mod = 'extras', price = 250 },
    { code = 'cosmetic_platetext', name = 'Plaque personnalisée',    category = 'paint',    kind = 'cosmetic', mod = 'platetext', price = 5000,
      description = 'Texte de plaque au choix (1 à 8 caractères), réservé aux véhicules avec carte grise.' },
    -- CarPlay (téléphone elyzea_aura)
    { code = 'carplay', name = 'Installation CarPlay', category = 'carplay', kind = 'carplay', price = 3500,
      description = 'Rend le véhicule compatible avec ElyzeaCarPlay (tablette F4 et contrôle depuis le téléphone). Liée au véhicule.' },
    { code = 'carplay_reinstall', name = 'Réinstallation CarPlay', category = 'carplay', kind = 'carplay', price = 1000, enabled = false,
      description = 'Remplacement sur un véhicule déjà équipé (désactivé par défaut).' },
}

-- ---------------------------------------------------------------------
-- Dépannage : demandes des joueurs (app Urgences du téléphone › Dépannage, ou /depannage)
-- ---------------------------------------------------------------------
Config.Tow = {
    command = 'depannage',
    commandCooldown = 60,
    lifetime = 1800,
    statuses = {
        pending = 'En attente', accepted = 'Acceptée', enroute = 'En route', onsite = 'Sur place',
        diagnostic = 'Diagnostic en cours', quote = 'Devis en attente', repair = 'Réparation en cours',
        done = 'Terminée', cancelled = 'Annulée',
    },
}

Config.Statuses = {
    { id = 'available', label = 'Disponible',     color = '#22c55e' },
    { id = 'enroute',   label = 'En route',       color = '#3b82f6' },
    { id = 'busy',      label = 'En intervention', color = '#f59e0b' },
    { id = 'pause',     label = 'Indisponible',   color = '#94a3b8' },
}

-- Véhicules de service (garage placé en jeu par la direction)
Config.Garage = {
    vehicles = {
        { model = 'flatbed',   label = 'Plateau',    minLevel = 1 },
        { model = 'towtruck',  label = 'Dépanneuse', minLevel = 1 },
        { model = 'towtruck2', label = 'Dépanneuse légère', minLevel = 1 },
    },
    storeRadius = 8.0,
    pharmacy = { slots = 60, weight = 300000 },   -- coffre d'atelier (elyzea_inventory)
}

Config.Pay = { maxRate = 100000 }
Config.Catalog = { maxPrice = 1000000 }
Config.MapRefresh = 3000
Config.MapImage = { file = 'img/map.jpg', minX = -5661.2, maxX = 6694.0, minY = -4058.5, maxY = 8429.3 }

-- Grades du premier démarrage (salary = taux horaire de départ, réglé ensuite dans Finance)
Config.DefaultGrades = {
    { name = 'Apprenti',            level = 1, salary = 350, default = true,
      perms = { 'duty', 'repair', 'clean', 'flip', 'workshop', 'cosmetic', 'tow', 'tablet', 'vehicles_view' } },
    { name = 'Mécanicien',          level = 2, salary = 500,
      perms = { 'duty', 'repair', 'clean', 'flip', 'workshop', 'cosmetic', 'perf', 'carplay', 'quotes', 'tow', 'tablet', 'vehicles_view' } },
    { name = 'Mécanicien confirmé', level = 3, salary = 650,
      perms = { 'duty', 'repair', 'repair_full', 'clean', 'flip', 'workshop', 'cosmetic', 'perf', 'carplay', 'quotes', 'tow', 'tow_manage', 'tablet',
                'vehicles_view', 'stats_view', 'garage' } },
    { name = 'Chef d\'atelier',     level = 4, salary = 850,
      perms = { 'duty', 'repair', 'repair_full', 'clean', 'flip', 'workshop', 'cosmetic', 'perf', 'carplay', 'quotes', 'quotes_manage', 'tow', 'tow_manage',
                'tablet', 'vehicles_view', 'stats_view', 'garage', 'direction', 'recruit', 'employees_view', 'promote',
                'demote', 'history_view' } },
    { name = 'Directeur',           level = 5, salary = 1100, perms = 'all' },
}

-- Couleurs de néons / fumée proposées par l'atelier (les néons n'acceptent QUE ces couleurs :
-- les couleurs libres et les effets multicolores des néons, phares et plaques sont réservés au staff, admin_menu)
Config.Lights = {
    { 'Blanc', 255, 255, 255 }, { 'Bleu', 2, 21, 255 }, { 'Bleu électrique', 3, 83, 255 }, { 'Vert menthe', 0, 255, 140 }, { 'Vert lime', 94, 255, 1 },
    { 'Jaune', 255, 255, 0 }, { 'Or', 255, 150, 5 }, { 'Orange', 255, 62, 0 }, { 'Rouge', 255, 1, 1 }, { 'Rose', 255, 50, 100 }, { 'Rose vif', 255, 5, 190 }, { 'Violet', 35, 1, 255 },
    { 'Lumière noire', 15, 3, 255 }, { 'Cyan', 0, 255, 255 }, { 'Turquoise', 0, 200, 150 }, { 'Magenta', 255, 0, 255 }, { 'Corail', 255, 110, 70 }, { 'Ambre', 255, 191, 0 },
    { 'Bleu ciel', 120, 200, 255 }, { 'Lavande', 180, 140, 255 }, { 'Noir (fumée)', 1, 1, 1 },
}
