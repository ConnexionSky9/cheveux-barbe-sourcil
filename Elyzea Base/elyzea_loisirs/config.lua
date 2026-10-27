-- =====================================================================
--  ELYZEA LOISIRS : bowling, billard (8-ball), golf (stroke play)
--  Toutes les valeurs réglables sont ici. Les pistes, tables et parcours se posent EN JEU
--  depuis le menu admin (onglet « Loisirs ») : aucune coordonnée n'est écrite dans ce fichier.
--  Unités : mètres, secondes, mètres/seconde.
-- =====================================================================
Config = {}

Config.Debug = false              -- true : messages de débogage dans la console (F8 / serveur), jamais aux joueurs

-- ---------------------------------------------------------------- général
Config.InteractDistance = 2.2     -- distance pour l'invite [E] près d'une piste / table / départ de golf
Config.DrawDistance = 60.0        -- objets (quilles, boules, drapeaux) créés quand on est à moins de X m
Config.SpectateRadius = 40.0      -- les joueurs à moins de X m d'une installation voient les coups (sans jouer)
Config.Account = 'cash'           -- compte utilisé pour les droits d'entrée ('cash' ou 'bank')

Config.Games = {
    bowling   = { label = 'Bowling',  icon = '🎳', enabled = true, maxPlayers = 6, minPlayers = 1, price = 0 },
    billiards = { label = 'Billard',  icon = '🎱', enabled = true, maxPlayers = 2, minPlayers = 2, price = 0 },
    golf      = { label = 'Golf',     icon = '⛳', enabled = true, maxPlayers = 4, minPlayers = 1, price = 0 },
}

-- ---------------------------------------------------------------- parties (commun)
Config.Sessions = {
    lobbyTimeout = 900,           -- une partie en attente sans lancement est fermée après X s
    startDelay = 3,               -- compte à rebours STARTING → IN_PROGRESS (s)
    resultsTime = 20,             -- le tableau final reste affiché X s, puis l'équipement est libéré
    maxNameLength = 32,
    passwordMaxLength = 16,
    turnTimeout = { bowling = 60, billiards = 90, golf = 150 },      -- temps pour jouer son coup (s)
    afkStrikes = 2,               -- dépassements de temps consécutifs avant d'être retiré de la partie
    maxDuration = { bowling = 3600, billiards = 3600, golf = 7200 }, -- au-delà : partie terminée avec le classement actuel
    awayDistance = { bowling = 30.0, billiards = 20.0, golf = 450.0 },-- au-delà de cette distance de l'installation…
    awayGrace = 45,               -- … pendant X s : le joueur est retiré (abandon)
    deadGrace = 60,               -- joueur mort / inconscient pendant X s : retiré de la partie
    rate = { count = 6, window = 3000 },                             -- actions de jeu max par fenêtre (ms)
}

-- ---------------------------------------------------------------- bowling
-- Repère de piste : x = latéral (gauche < 0 < droite, vu du lanceur), y = le long de la piste depuis la ligne de faute.
Config.Bowling = {
    laneLength = 18.288,          -- ligne de faute → quille n°1 (60 pieds, règle officielle)
    laneWidth = 1.0541,           -- largeur de la piste (41,5 pouces)
    gutterWidth = 0.235,          -- largeur d'une gouttière
    approach = 4.6,               -- zone d'élan derrière la ligne de faute (le lanceur s'y place)
    pinSpacing = 0.3048,          -- 12 pouces entre deux quilles voisines
    ballRadius = 0.109,           -- boule de 8,5 pouces
    ballMass = 6.8,
    pinRadius = 0.06,             -- rayon de la quille au niveau du choc (ventre)
    pinMass = 1.55,
    -- lancer
    minSpeed = 5.0, maxSpeed = 9.5,  -- vitesse de la boule selon la puissance (0 → 1)
    maxStartX = 0.42,             -- position latérale de départ autorisée (± m)
    maxAngle = 3.0,               -- angle de lancer autorisé (± degrés)
    oilLength = 12.0,             -- la boule ne « crochète » qu'après la zone huilée
    maxHook = 0.55,               -- accélération latérale maximale due à l'effet (m/s²)
    releaseNoise = { angle = 0.18, speed = 0.12, x = 0.012 }, -- imprécision du lâcher (tirée par le serveur)
    -- simulation
    dt = 1 / 240, maxTime = 7.0,
    ballPinRestitution = 0.80, pinPinRestitution = 0.65,
    pinFriction = 1.6,            -- décélération d'une quille qui glisse / roule (m/s²)
    pinTipRadius = 0.09,          -- une quille qui bascule balaie plus large que sa base (rayon effectif)
    kickback = 0.55,              -- rebond des quilles sur les murs latéraux du plateau
    pinFallSpeed = 0.25,          -- une quille touchée à plus de X m/s tombe
    pinFallMove = 0.04,           -- … ou déplacée de plus de X m
    sample = 1 / 30,              -- fréquence des positions envoyées aux clients (rejeu)
    -- objets et animations (vérifiés dans les fichiers du jeu)
    models = { ball = 'prop_bowling_ball', pin = 'prop_bowling_pin' },
    pinZOffset = 0.0,             -- réglage de hauteur des quilles posées
    anims = {
        hold  = { dict = 'anim@heists@box_carry@', clip = 'idle', flag = 49 },
        throw = { dict = 'weapons@projectile@', clip = 'throw_l_fb_stand', flag = 0, release = 0.55, duration = 1.4 },
        cheer = { dict = 'anim@mp_player_intcelebrationmale@thumbs_up', clip = 'thumbs_up', flag = 48, duration = 2.5 },
        cheerF = { dict = 'anim@mp_player_intcelebrationfemale@thumbs_up', clip = 'thumbs_up', flag = 48, duration = 2.5 },
    },
    ballHand = { bone = 57005, pos = vector3(0.12, 0.0, -0.06), rot = vector3(0.0, 0.0, 0.0) }, -- SKEL_R_Hand
}

-- ---------------------------------------------------------------- billard (8-ball américain)
-- Repère de table : x = longueur (−L/2 tête … +L/2 pied), y = largeur. Le centre est le centre de la table.
Config.Billiards = {
    -- tables reconnues (modèles du jeu) ; dimensions de la surface de jeu et hauteur du tapis
    -- au-dessus de l'origine du modèle : réglables par table dans le menu admin si besoin
    tables = {
        prop_pooltable_02  = { length = 2.24, width = 1.12, height = 0.80 },
        prop_pooltable_3b  = { length = 2.24, width = 1.12, height = 0.80 },
    },
    defaultModel = 'prop_pooltable_02',
    ballRadius = 0.028575,        -- 2 1/4 pouces
    -- poches : rayon de capture (centre de la boule dans ce cercle = empochée)
    cornerPocket = 0.062, sidePocket = 0.056,
    pocketInset = 0.012,          -- centre des poches légèrement à l'extérieur des bandes
    -- physique
    dt = 1 / 360, maxTime = 25.0,
    rollingDecel = 0.16,          -- frottement du tapis (m/s²)
    linearDamping = 0.07,         -- amortissement supplémentaire (1/s)
    ballRestitution = 0.94,       -- choc entre boules
    cushionRestitution = 0.74,    -- rebond sur les bandes
    cushionFriction = 0.10,       -- perte de vitesse le long de la bande lors d'un rebond
    stopSpeed = 0.012,            -- en dessous : boule arrêtée
    jumpSpeed = 6.2,              -- choc sur une bande plus fort : la boule saute hors de la table
    minPower = 0.25, maxPower = 7.0, -- vitesse de la blanche (m/s) selon la puissance
    sample = 1 / 30,
    -- règles (8-ball, voir README)
    rules = {
        breakMinRails = 4,        -- casse légale : une boule empochée ou au moins X boules touchent une bande
        eightOnBreak = 'rerack',  -- noire empochée à la casse : 'rerack' (on recommence) ou 'win'
        groupFromFirstPocketed = true, -- table ouverte et deux groupes empochés : groupe de la 1re boule empochée
        ballInHand = 'anywhere',  -- après une faute : blanche placée n'importe où ('anywhere') ou derrière la ligne de tête ('kitchen')
        headString = 0.25,        -- ligne de tête : à X × longueur depuis la bande de tête
    },
    models = {
        cue = 'prop_pool_cue', cueBall = 'prop_poolball_cue',
        balls = { 'prop_poolball_1', 'prop_poolball_2', 'prop_poolball_3', 'prop_poolball_4', 'prop_poolball_5',
            'prop_poolball_6', 'prop_poolball_7', 'prop_poolball_8', 'prop_poolball_9', 'prop_poolball_10',
            'prop_poolball_11', 'prop_poolball_12', 'prop_poolball_13', 'prop_poolball_14', 'prop_poolball_15' },
    },
    ballZOffset = 0.0,            -- réglage de hauteur des boules (centre = tapis + rayon + ceci)
    -- animation : il n'existe pas d'animation de billard dans GTA V ; pose penchée sur une table
    -- (business coke) + queue tenue en main dont le mouvement de frappe est animé par le script
    anims = {
        lean = { dict = 'anim@amb@business@coc@coc_unpack_cut_left@', clip = 'coke_cut_v1_coccutter', flag = 1, speed = 0.0 },
        stand = { dict = 'anim@heists@box_carry@', clip = 'idle', flag = 49 },
    },
    cueHand = { bone = 57005, pos = vector3(0.10, 0.02, -0.02), rot = vector3(-80.0, 0.0, 0.0) },
    cueLength = 1.45,
    standOff = 0.55,              -- le joueur se place à X m derrière la blanche (hors de la table)
}

-- ---------------------------------------------------------------- golf (stroke play)
Config.Golf = {
    gravity = 9.81,
    ballRadius = 0.0214,
    cupRadius = 0.054,            -- trou de 4,25 pouces
    captureSpeed = 1.5,           -- balle qui passe sur le trou moins vite que X m/s : elle tombe
    flightDt = 1 / 120, rollDt = 1 / 120, maxTime = 30.0, sample = 1 / 20,
    drag = 0.0042,                -- résistance de l'air (accélération = −drag × |v| × v)
    lift = 0.0011,                -- portance due à l'effet rétro (accélération verticale = lift × vitesse horizontale²)
    landingKeep = 0.35,           -- vitesse horizontale gardée au premier impact (+ rebond de la zone)
    -- terrain : chaque trou est un plan incliné entre le départ et le drapeau (hauteurs relevées à la pose)
    lies = {   -- état de la balle selon la zone : puissance disponible, rebond, freinage au roulement (m/s²)
        tee     = { label = 'Départ',   power = 1.00, bounce = 0.30, roll = 2.2 },
        fairway = { label = 'Fairway',  power = 1.00, bounce = 0.30, roll = 2.2 },
        rough   = { label = 'Rough',    power = 0.80, bounce = 0.18, roll = 5.5 },
        bunker  = { label = 'Bunker',   power = 0.60, bounce = 0.05, roll = 12.0 },
        green   = { label = 'Green',    power = 1.00, bounce = 0.22, roll = 0.75 },
    },
    clubs = {   -- vitesse de balle maximale (m/s), angle de départ (degrés), courbe d'effet, objet, animation
        { id = 'driver', label = 'Driver',  speed = 84, loft = 11, curve = 9.0, model = 'prop_golf_driver',    anim = 'wood' },
        { id = 'wood3',  label = 'Bois 3',  speed = 75, loft = 15, curve = 8.0, model = 'prop_golf_wood_01',   anim = 'wood' },
        { id = 'hybrid', label = 'Hybride', speed = 64, loft = 19, curve = 7.0, model = 'prop_golf_wood_01',   anim = 'iron' },
        { id = 'iron5',  label = 'Fer 5',   speed = 56, loft = 24, curve = 6.0, model = 'prop_golf_iron_01',   anim = 'iron' },
        { id = 'iron7',  label = 'Fer 7',   speed = 50, loft = 31, curve = 5.0, model = 'prop_golf_iron_01',   anim = 'iron' },
        { id = 'iron9',  label = 'Fer 9',   speed = 44, loft = 39, curve = 4.0, model = 'prop_golf_iron_01',   anim = 'iron' },
        { id = 'pw',     label = 'Pitching wedge', speed = 40, loft = 45, curve = 3.0, model = 'prop_golf_pitcher_01', anim = 'wedge' },
        { id = 'sw',     label = 'Sand wedge',     speed = 33, loft = 55, curve = 2.0, model = 'prop_golf_pitcher_01', anim = 'wedge' },
        { id = 'putter', label = 'Putter',  speed = 8.5, loft = 0, curve = 0.0, model = 'prop_golf_putter_01', anim = 'putt' },
    },
    noise = { angle = 1.6, speed = 0.03, overswing = 0.92 }, -- imprécision (degrés, fraction) ; au-delà de 92 % de puissance elle triple
    maxSpin = 1.0,                -- effet (draw / fade) demandé par le joueur : −1 … 1
    addressDistance = 3.0,        -- le joueur doit être à moins de X m de sa balle pour jouer
    stanceOffset = 0.75,          -- le golfeur se place à X m de la balle (à corriger si le club ne touche pas la balle)
    stanceHeight = 0.98,          -- hauteur du bassin au-dessus du sol pendant le swing
    defaultPar = 4, defaultGreenRadius = 14.0, defaultFairwayWidth = 34.0,
    roughWidth = 45.0,            -- au-delà du fairway + X m de chaque côté : hors limites
    behindTee = 25.0, beyondFlag = 45.0, -- limites avant le départ / après le drapeau
    teeRadius = 4.0,
    maxStrokesOverPar = 6,        -- coups maximum par trou = par + X (le joueur relève sa balle)
    penalties = { water = 1, ob = 1, lost = 1, unplayable = 1 },
    unplayableDrop = 2.0,         -- balle injouable : replacée X m en arrière, sur la ligne drapeau-balle
    waterDropBack = 1.5,          -- balle dans l'eau : replacée X m avant le point d'entrée
    models = { ball = 'prop_golf_ball', flag = 'prop_golfflag', tee = 'prop_golf_tee' },
    clubHand = { bone = 28422, pos = vector3(0.0, 0.0, 0.0), rot = vector3(0.0, 0.0, 0.0) }, -- PH_R_Hand
    -- animations du mini-jeu de golf de GTA V (dictionnaire mini@golf, vérifié)
    anims = {
        dict = 'mini@golf',
        wood   = { intro = 'wood_swing_intro_high',  idle = 'wood_swing_idle_high',  action = 'wood_swing_action_high' },
        iron   = { intro = 'iron_swing_intro_high',  idle = 'iron_swing_idle_high',  action = 'iron_swing_action_high' },
        wedge  = { intro = 'wedge_swing_intro_high', idle = 'wedge_swing_idle_high', action = 'wedge_swing_action_high' },
        putt   = { intro = 'putt_intro_high',        idle = 'putt_idle_high',        action = 'putt_action_high' },
        good   = 'swing_react_good_01_face', bad = 'swing_react_bad_01_face',
        impact = 0.45,            -- moment du contact dans l'animation de frappe (fraction)
    },
}

-- ---------------------------------------------------------------- touches (contrôles GTA)
Config.Keys = {
    interact = 38,      -- E
    power = 22,         -- ESPACE (maintenir puis relâcher)
    left = 34, right = 35, up = 32, down = 33, -- A / D / W / S (QWERTY : Q / D / Z / S sur AZERTY)
    rotL = 44, rotR = 51, -- Q / E (A / E en AZERTY)
    nextClub = 15, prevClub = 14, -- molette
    camera = 26,        -- C
    cancel = 177,       -- RETOUR ARRIÈRE
    special = 47,       -- G (golf : balle injouable)
}
