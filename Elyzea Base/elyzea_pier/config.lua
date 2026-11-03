-- =====================================================================
--  ELYZEA PIER - PARC D'ATTRACTIONS DE DEL PERRO : CONFIGURATION
--  Grande roue et montagnes russes ORIGINALES de GTA V (modèles, rail et animations du jeu,
--  mêmes valeurs que le script de GTA Online). Tout ce qui se règle est ici.
-- =====================================================================
Config = {}

Config.Debug = false

-- ---------------------------------------------------------------- touches et interaction
Config.InteractKey = 'E'                 -- touche par défaut (chaque joueur peut la changer : Paramètres › Raccourcis › FiveM)
Config.HandsUpKey = 'X'                  -- montagnes russes : lever / baisser les bras pendant le trajet
Config.InteractDistance = 2.0            -- distance (m) pour parler au PNJ

-- ---------------------------------------------------------------- argent
-- Comptes acceptés pour acheter des tickets (le joueur choisit dans le menu)
Config.Accounts = { cash = true, bank = true }
Config.MaxTicketsPerPurchase = 10
Config.MaxTicketsOwned = 50              -- par type de ticket (0 = sans limite)

-- ---------------------------------------------------------------- PNJ vendeur de tickets
Config.Npc = {
    enabled = true,
    model = 's_m_m_strvend_01',
    coords = vector4(-1658.10, -1131.85, 13.02, 49.0),   -- devant la grande roue (à ajuster avec /pier_here si besoin)
    scenario = 'WORLD_HUMAN_STAND_IMPATIENT',            -- ou nil pour utiliser anim
    anim = nil,                                          -- { dict = '...', name = '...' }
    label = 'Billetterie de Del Perro',
    blip = { enabled = true, sprite = 266, color = 27, scale = 0.85, label = 'Parc de Del Perro' },
}

-- ---------------------------------------------------------------- tickets (objets d'elyzea_inventory)
Config.Tickets = {
    wheel   = { item = 'ticket_grande_roue',      label = 'Grande roue',       price = 150 },
    coaster = { item = 'ticket_montagnes_russes', label = 'Montagnes russes',  price = 250 },
}

-- ---------------------------------------------------------------- GRANDE ROUE (« The Ferris Whale »)
Config.Wheel = {
    enabled = true,
    label = 'Grande roue',
    -- valeurs du jeu original (script am_ferriswheel de GTA Online)
    wheelModel = 'prop_ld_ferris_wheel',
    cabinModel = 'prop_ferris_car_01',
    center = vector3(-1663.97, -1126.70, 30.70),
    radius = 15.3,
    cabins = 16,
    seatsPerCabin = 2,                   -- le jeu original anime 2 passagers par cabine (places « one » et « two »)
    animDict = 'anim@mp_ferris_wheel',
    boardAngleOffset = 1.0,              -- décalage de l'arrêt en gare (degrés), valeur du jeu : 22,5 × i − 21,5
    entry = vector3(-1661.95, -1127.011, 12.6973),     -- point d'embarquement original
    entryRadius = 2.5,                   -- rayon de la zone d'entrée (m)
    queueLeaveRadius = 8.0,              -- s'éloigner davantage fait quitter la file d'attente
    exitPoint = vector4(-1659.40, -1128.30, 12.70, 230.0),  -- où le joueur est déposé en fin de tour (sécurité)
    -- durée d'un tour complet, hors arrêts en gare (le jeu original : 180 s = 2°/s)
    turnDuration = 180,
    stopDuration = 14,                   -- temps d'arrêt en gare pour monter / descendre (s)
    idleRotation = true,                 -- la roue tourne en permanence quand personne n'attend (comme dans le jeu)
    streamDistance = 300.0,              -- la roue n'est créée que pour les joueurs à moins de N m
}

-- ---------------------------------------------------------------- MONTAGNES RUSSES (« Leviathan »)
Config.Coaster = {
    enabled = true,
    label = 'Montagnes russes',
    frontModel = 'ind_prop_dlc_roller_car',
    carModel = 'ind_prop_dlc_roller_car_02',
    cars = 4,                            -- 4 wagons comme dans le jeu
    seatsPerCar = 2,                     -- 2 places par wagon (8 passagers)
    carSpacing = 2.55,                   -- distance entre deux wagons sur le rail (m), valeur du jeu
    animDict = 'anim@mp_rollarcoaster',
    -- placement des passagers (repère du wagon), valeurs du jeu : la scène d'animation part de cette origine
    seats = {
        { suffix = 'one', origin = vector3(0.0, -1.017, 0.0) },
        { suffix = 'two', origin = vector3(0.0, 0.0, 0.0) },
    },
    entry = vector3(-1646.0, -1128.7, 17.34),           -- centre du quai d'embarquement
    entryRadius = 6.0,
    queueLeaveRadius = 12.0,
    exitPoint = vector4(-1648.60, -1132.80, 17.34, 140.0),
    boardingTime = 25,                   -- secondes d'attente en gare après le premier passager
    fullDepartDelay = 6,                 -- départ anticipé quand le train est plein (s)
    barTime = 3,                         -- descente de la barre de sécurité avant le départ (s)
    unloadTime = 7,                      -- descente des passagers à l'arrivée (s)
    -- durée du parcours : nil = vitesse réelle du jeu (≈ 60 s), sinon nombre de secondes (le trajet est ralenti / accéléré)
    duration = nil,
    streamDistance = 300.0,
}

-- ---------------------------------------------------------------- sécurité
Config.Security = {
    maxRequestsPerSecond = 6,            -- au-delà, les requêtes du joueur sont ignorées
    maxRideDistance = 90.0,              -- un passager plus loin que ça de l'attraction est retiré (téléportation)
}

-- ---------------------------------------------------------------- staff
Config.AcePermission = 'elyzea_pier.admin'   -- ou permission admin_menu « editor_peds »
