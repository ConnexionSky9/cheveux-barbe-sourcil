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
-- Rubriques possibles : 'perf', 'cosmetic', 'paint', 'wheels', 'lights', 'interior', 'service'
-- ---------------------------------------------------------------------
Config.WorkshopDefaults = { radius = 3.5, categories = { 'perf', 'cosmetic', 'paint', 'wheels', 'lights', 'interior', 'service' }, minLevel = 1 }
Config.WorkshopMax = 30
Config.WorkshopMarker = true      -- marqueur au sol pour les mécaniciens en service

-- ---------------------------------------------------------------------
-- Installation d'un devis payé : points d'intervention + mini-jeux (client/install.lua)
-- Après paiement, « Installer » affiche la liste des interventions. Pour chacune, une flèche
-- montre où se placer autour du véhicule ; E lance le mini-jeu ; la pièce est posée à la fin.
-- ---------------------------------------------------------------------
Config.Install = {
    reach = 1.4,              -- distance au point d'intervention pour lancer le mini-jeu (E)
    maxDistance = 25.0,       -- le mécanicien qui s'éloigne plus que ça du véhicule interrompt l'intervention
    gameTimeout = 120,        -- secondes : un mini-jeu ne reste jamais ouvert plus longtemps (fermé, rien n'est posé)
    beat = 15,                -- secondes entre deux signes de vie envoyés au serveur
    handoverTimeout = 600,    -- secondes : sans remise des clés, le véhicule est rendu automatiquement au client
    handoverRange = 3.0,      -- distance mécanicien ↔ client pour remettre les clés (E)
    paintFx = true,           -- brume de peinture (effet du jeu) pendant le mini-jeu de peinture
    -- Animations jouées pendant les mini-jeux (le premier dictionnaire qui existe ; sinon le scénario)
    anims = {
        stand  = { { 'mini@repair', 'fixing_a_player', 1 } },
        hood   = { { 'mini@repair', 'fixing_a_ped', 1 } },
        kneel  = { { 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer', 1 }, { 'amb@medic@standing@kneel@base', 'base', 1 } },
        inside = { { 'anim@gangops@facility@servers@bodysearch@', 'player_search', 1 } },
        under  = { { 'amb@prop_human_movie_bulb@base', 'base', 1 } },        -- debout sous le véhicule levé (pont)
        spray  = { { 'switch@franklin@lamar_tagging_wall', 'lamar_tagging_wall_loop_lamar', 1 } },
        give   = { 'mp_common', 'givetake1_a', 48 },                       -- remise des clés (mécanicien)
        take   = { 'mp_common', 'givetake1_b', 48 },                       -- remise des clés (client)
    },
    scenarios = { stand = 'WORLD_HUMAN_WELDING', under = 'WORLD_HUMAN_VEHICLE_MECHANIC', spray = 'WORLD_HUMAN_MAID_CLEAN' },
    props = {
        wrench = { model = 'prop_cs_wrench', bone = 57005, pos = { 0.10, 0.03, -0.02 }, rot = { -90.0, 0.0, 0.0 } },
        spray  = { model = 'ng_proc_spraycan01b', bone = 57005, pos = { 0.10, 0.02, -0.03 }, rot = { -70.0, 0.0, 0.0 } },
        keys   = { model = 'p_car_keys_01', bone = 57005, pos = { 0.11, 0.03, -0.02 }, rot = { -90.0, 0.0, 0.0 } },
    },
}

-- Pneus DRIFT : vrai comportement de dérive du jeu (natif SetDriftTyresEnabled, build 2944 ou plus).
-- Seuls les véhicules équipés sont concernés ; enregistré sur la carte grise (driftTyres).
Config.Drift = { enabled = true }

-- Le CarPlay ne s'installe plus à l'atelier. true = elyzea_aura accepte le CarPlay sur tous les véhicules
-- (exports.elyzea_meca:HasCarPlay renvoie vrai) ; false = seuls les véhicules déjà équipés le gardent.
Config.CarPlayFree = true

-- Pont roulant (objet d'inventaire « pont_roulant ») : levage pendant les travaux de dessous de caisse
Config.Interventions = {
    serverTimeout = 120,      -- secondes sans nouvelle du mécanicien → intervention libérée, scène remise en état
    lift = { clearance = 1.95, wheelHeight = 0.5, liftTime = 2.5,
        -- Dessin du pont (aucun modèle de pont garanti dans le jeu de base) : couleurs et hauteur des colonnes
        color = { 235, 180, 20 }, darkColor = { 60, 60, 66 }, postHeight = 2.9, drawDistance = 45.0,
        armSwing = 1.0,       -- secondes pour que les 4 bras pivotent sous la voiture (ou se replient)
        -- Modèle réel (ta map ou un pack) à la place du dessin : models = { 'nom_du_modele' }, offsetZ, heading
        models = {},
    },
    -- Objet d'inventaire « Pont roulant » (5 kg)
    -- Posé (utilisé) à côté d'un véhicule garé sur un point d'atelier ; H à côté du pont pour le reprendre
    liftItem = { name = 'pont_roulant', perm = 'workshop', range = 3.0, vehicleRange = 5.0, pickupKey = 74 },
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
-- kind : service | perf | cosmetic | custom (le CarPlay ne s'installe plus à l'atelier)
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
    -- Pneus : neufs (à l'unité ou les 4, prix par pneu) et pneus DRIFT (vrai comportement de dérive)
    { code = 'cosmetic_newtyres', name = 'Pneus neufs',            category = 'wheels',   kind = 'cosmetic', mod = 'newtyres', price = 350,
      description = 'Prix par pneu. Les 4 pneus en une seule intervention, ou un seul pneu.' },
    { code = 'cosmetic_drift',    name = 'Pneus DRIFT',            category = 'wheels',   kind = 'cosmetic', mod = 'drift', price = 6500,
      description = 'Gomme dure de dérive : le véhicule glisse en virage (comportement réel du jeu). Retrait possible (pneus route).' },
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
      perms = { 'duty', 'repair', 'clean', 'flip', 'workshop', 'cosmetic', 'perf', 'quotes', 'tow', 'tablet', 'vehicles_view' } },
    { name = 'Mécanicien confirmé', level = 3, salary = 650,
      perms = { 'duty', 'repair', 'repair_full', 'clean', 'flip', 'workshop', 'cosmetic', 'perf', 'quotes', 'tow', 'tow_manage', 'tablet',
                'vehicles_view', 'stats_view', 'garage' } },
    { name = 'Chef d\'atelier',     level = 4, salary = 850,
      perms = { 'duty', 'repair', 'repair_full', 'clean', 'flip', 'workshop', 'cosmetic', 'perf', 'quotes', 'quotes_manage', 'tow', 'tow_manage',
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
