-- =====================================================================
--  ELYZEA LASERGAME - CONFIGURATION AVANCÉE
--  Armes laser, rangs, mode Zombie (manches, zombies, atouts, prix).
--  Les valeurs « staff » (prix, dégâts, difficulté) sont aussi modifiables en jeu (/lgadmin).
-- =====================================================================
LG = LG or {}

-- ---------------------------------------------------------------- catégories d'armes
LG.WeaponCategories = {
    { id = 'melee',  label = 'Mêlée',           icon = 'melee'  },
    { id = 'pistol', label = 'Pistolet',        icon = 'pistol' },
    { id = 'smg',    label = 'Mitraillette',    icon = 'smg'    },
    { id = 'rifle',  label = 'Fusil d\'assaut', icon = 'rifle'  },
    { id = 'sniper', label = 'Sniper',          icon = 'sniper' },
}

-- ---------------------------------------------------------------- armes laser
-- model    : modèle GTA tenu en main (visuel et animations seulement : le tir GTA est désactivé,
--            chaque tir est un laser calculé par la ressource et vérifié par le serveur)
-- damage   : dégâts sur le bouclier d'un joueur (PVP) · zDamage : dégâts sur un zombie
-- range    : portée (m) · rpm : cadence (tirs / minute) · spread : dispersion (degrés)
-- mag      : tirs avant recharge (0 = jamais) · reload : durée de recharge (ms)
-- beam     : 'pulse' (impulsion courte), 'beam' (rayon continu), 'rail' (rayon épais longue durée),
--            'scatter' (plusieurs rayons), 'blade' (arc de mêlée)
-- pellets  : nombre de rayons par tir (scatter)
LG.Weapons = {
    -- MÊLÉE ------------------------------------------------------------
    { id = 'ion_blade',    label = 'Lame Ionique',        cat = 'melee',  model = 'WEAPON_MACHETE',
      damage = 100, zDamage = 260, range = 2.8, rpm = 90,  spread = 0,   mag = 0,  reload = 0,
      beam = 'blade', width = 0.05, life = 180, sound = 'blade', tier = 1 },
    { id = 'photon_baton', label = 'Matraque Photonique', cat = 'melee',  model = 'WEAPON_NIGHTSTICK',
      damage = 60,  zDamage = 180, range = 2.6, rpm = 140, spread = 0,   mag = 0,  reload = 0,
      beam = 'blade', width = 0.04, life = 150, sound = 'blade', tier = 1 },

    -- PISTOLETS --------------------------------------------------------
    { id = 'photon_p9',    label = 'Photon P9',           cat = 'pistol', model = 'WEAPON_PISTOL',
      damage = 25,  zDamage = 45,  range = 60,  rpm = 240, spread = 1.2, mag = 12, reload = 1400,
      beam = 'pulse', width = 0.018, life = 90, sound = 'pistol', tier = 1 },
    { id = 'vector_x',     label = 'Vector-X',            cat = 'pistol', model = 'WEAPON_COMBATPISTOL',
      damage = 30,  zDamage = 60,  range = 65,  rpm = 210, spread = 1.0, mag = 10, reload = 1500,
      beam = 'pulse', width = 0.02, life = 90, sound = 'pistol', tier = 2 },
    { id = 'atomizer',     label = 'Atomiseur Néon',      cat = 'pistol', model = 'WEAPON_RAYPISTOL',
      damage = 45,  zDamage = 140, range = 55,  rpm = 100, spread = 0.4, mag = 6,  reload = 1800,
      beam = 'rail', width = 0.035, life = 160, sound = 'heavy', tier = 3 },

    -- MITRAILLETTES ----------------------------------------------------
    { id = 'pulse_smg',    label = 'Pulse SMG',           cat = 'smg',    model = 'WEAPON_SMG',
      damage = 14,  zDamage = 40,  range = 45,  rpm = 720, spread = 2.4, mag = 30, reload = 1800,
      beam = 'pulse', width = 0.014, life = 60, sound = 'smg', tier = 2 },
    { id = 'hornet',       label = 'Hornet MK2',          cat = 'smg',    model = 'WEAPON_MICROSMG',
      damage = 12,  zDamage = 35,  range = 40,  rpm = 840, spread = 3.0, mag = 32, reload = 1600,
      beam = 'pulse', width = 0.012, life = 55, sound = 'smg', tier = 2 },
    { id = 'hellbringer',  label = 'Hellbringer',         cat = 'smg',    model = 'WEAPON_RAYCARBINE',
      damage = 16,  zDamage = 70,  range = 55,  rpm = 780, spread = 2.0, mag = 50, reload = 2400,
      beam = 'beam', width = 0.02, life = 70, sound = 'smg', tier = 4 },

    -- FUSILS D'ASSAUT --------------------------------------------------
    { id = 'nova_ar',      label = 'Nova AR',             cat = 'rifle',  model = 'WEAPON_CARBINERIFLE',
      damage = 20,  zDamage = 65,  range = 90,  rpm = 560, spread = 1.4, mag = 30, reload = 2000,
      beam = 'beam', width = 0.018, life = 70, sound = 'rifle', tier = 2 },
    { id = 'spectre',      label = 'Spectre-7',           cat = 'rifle',  model = 'WEAPON_SPECIALCARBINE',
      damage = 22,  zDamage = 85,  range = 95,  rpm = 520, spread = 1.2, mag = 30, reload = 2100,
      beam = 'beam', width = 0.02, life = 70, sound = 'rifle', tier = 3 },
    { id = 'quasar',       label = 'Quasar Bullpup',      cat = 'rifle',  model = 'WEAPON_BULLPUPRIFLE',
      damage = 26,  zDamage = 120, range = 100, rpm = 480, spread = 1.0, mag = 36, reload = 2200,
      beam = 'beam', width = 0.022, life = 80, sound = 'rifle', tier = 4 },

    -- SNIPERS ----------------------------------------------------------
    { id = 'longbow',      label = 'Longbow L-1',         cat = 'sniper', model = 'WEAPON_MARKSMANRIFLE',
      damage = 55,  zDamage = 260, range = 180, rpm = 90,  spread = 0.2, mag = 8,  reload = 2600,
      beam = 'rail', width = 0.03, life = 220, sound = 'sniper', tier = 3 },
    { id = 'helios',       label = 'Hélios Railgun',      cat = 'sniper', model = 'WEAPON_SNIPERRIFLE',
      damage = 90,  zDamage = 600, range = 250, rpm = 45,  spread = 0.05, mag = 5, reload = 3000,
      beam = 'rail', width = 0.045, life = 320, sound = 'sniper', tier = 4 },

    -- ARMES SPÉCIALES (Zombie seulement : murs des salles éloignées) -----
    { id = 'scatter_x',    label = 'Scatter-X',           cat = 'rifle',  model = 'WEAPON_PUMPSHOTGUN', zombieOnly = true,
      damage = 12,  zDamage = 90,  range = 22,  rpm = 75,  spread = 6.0, mag = 8,  reload = 2600, pellets = 6,
      beam = 'scatter', width = 0.012, life = 70, sound = 'heavy', tier = 3 },
    { id = 'widowmaker',   label = 'Widowmaker',          cat = 'smg',    model = 'WEAPON_RAYMINIGUN', zombieOnly = true,
      damage = 14,  zDamage = 150, range = 60,  rpm = 900, spread = 2.5, mag = 120, reload = 3500,
      beam = 'beam', width = 0.026, life = 70, sound = 'smg', tier = 5 },
}

-- Arme donnée au départ d'une partie Zombie (munitions illimitées)
LG.ZombieStartWeapon = 'photon_p9'

-- ---------------------------------------------------------------- rangs PVP (8 rangs exclusifs)
-- min : points de classement nécessaires (modifiables). Tout joueur commence à LG.Ranking.start points.
LG.Ranks = {
    { id = 'bronze',      label = 'ELYZEA BRONZE',      min = 0,    color = '#C98A55', tier = 1 },
    { id = 'silver',      label = 'ELYZEA SILVER',      min = 1100, color = '#C9D3E0', tier = 2 },
    { id = 'gold',        label = 'ELYZEA GOLD',        min = 1250, color = '#FFC94A', tier = 3 },
    { id = 'platinum',    label = 'ELYZEA PLATINUM',    min = 1400, color = '#7FE3D8', tier = 4 },
    { id = 'diamond',     label = 'ELYZEA DIAMOND',     min = 1550, color = '#6FB6FF', tier = 5 },
    { id = 'master',      label = 'ELYZEA MASTER',      min = 1700, color = '#B57BFF', tier = 6 },
    { id = 'grandmaster', label = 'ELYZEA GRANDMASTER', min = 1850, color = '#FF4D8D', tier = 7 },
    { id = 'legend',      label = 'ELYZEA LEGEND',      min = 2000, color = '#FFE7A3', tier = 8 },
}

-- Calcul des points (type Elo par équipe, voir shared/utils.lua › LGU.RatingDelta)
LG.Ranking = {
    start = 1000,          -- points de départ
    k = 40,                -- amplitude d'un match « normal »
    kNewPlayer = 60,       -- amplitude pendant les placementMatches premiers matchs
    placementMatches = 5,
    perfBonusMax = 8,      -- bonus/malus de performance individuelle (éliminations - morts), plafonné
    streakBonus = 2,       -- +2 points par victoire consécutive au-delà de 2
    streakBonusMax = 10,
    drawFactor = 0.5,      -- une égalité compte comme un demi-résultat
    floor = 0,             -- points minimum
    -- Anti-farm : même adversaire(s) dans les 24 h → points multipliés par ces facteurs (1er, 2e, 3e match…)
    repeatFactors = { 1.0, 0.75, 0.5, 0.25, 0.0 },
    repeatWindowHours = 24,
    leaverPenalty = 25,    -- points retirés à un joueur qui quitte une partie classée en cours
}

-- ---------------------------------------------------------------- mode Zombie
LG.Zombie = {
    enabled = true,
    maxPlayers = 4,
    minPlayers = 1,
    lobbyIdleTimeout = 15 * 60,

    player = {
        health = 100,               -- 3 coups de zombie classique (34) avant d'être à terre
        regenDelay = 4000,          -- ms sans être touché avant la régénération
        regenPerSecond = 35,
        bleedout = 30,              -- secondes à terre avant d'être éliminé (jusqu'à la manche suivante)
        reviveTime = 4.0,           -- secondes pour réanimer
        reviveRange = 2.2,
        respawnNextRound = true,    -- un joueur éliminé revient à la manche suivante (perd ses atouts)
        keepPerksOnRespawn = false,
    },

    rounds = {
        intermission = 10,          -- secondes entre deux manches
        firstDelay = 8,             -- secondes avant la manche 1
        -- nombre de zombies de la manche n : base + perRound * (n-1), multiplié selon le nombre de joueurs
        countBase = 6, countPerRound = 3, countMax = 120,
        playerMultiplier = { 1.0, 1.6, 2.2, 2.8 },
        maxAlive = 22,              -- zombies présents en même temps (le reste attend)
        spawnInterval = 1500,       -- ms entre deux apparitions
        -- résistance : hp = hpBase + hpPerRound*(n-1) jusqu'à la manche hpLinearUntil, puis ×hpGrowth par manche
        hpBase = 110, hpPerRound = 40, hpLinearUntil = 9, hpGrowth = 1.10, hpMax = 25000,
        -- dégâts : base + perRound*(n-1), plafonnés
        damageBase = 34, damagePerRound = 1.5, damageMax = 60,
        -- vitesse : proportion de zombies qui courent / sprintent selon la manche
        runFromRound = 3, sprintFromRound = 7, speedRamp = 0.12,
        specialEvery = 0,           -- 0 = les spéciaux apparaissent selon leur poids ; N = manche spéciale toutes les N manches
        maxRound = 999,
    },

    -- Types de zombies. weight : poids d'apparition à partir de minRound.
    types = {
        classic = { label = 'Zombie',          models = { 'u_m_y_zombie_01', 'a_m_m_tramp_01', 'a_m_m_skidrow_01', 'a_m_o_tramp_01' },
                    hp = 1.0, damage = 1.0, speed = 1.0, reward = 100, minRound = 1, weight = 100, range = 1.6, cooldown = 1300 },
        fast    = { label = 'Zombie rapide',   models = { 'a_m_y_methhead_01', 'a_f_y_rurmeth_01', 'a_m_y_hippy_01' },
                    hp = 0.7, damage = 0.8, speed = 1.45, reward = 150, minRound = 3, weight = 30, range = 1.5, cooldown = 1000 },
        tank    = { label = 'Zombie résistant',models = { 'u_m_y_juggernaut_01', 's_m_y_construct_02', 'a_m_m_hillbilly_01' },
                    hp = 3.0, damage = 1.5, speed = 0.8, reward = 250, minRound = 5, weight = 12, range = 1.9, cooldown = 1700 },
        special = { label = 'Zombie spécial',  models = { 's_m_m_scientist_01', 's_m_y_hazmatworker_01' },
                    hp = 5.0, damage = 2.0, speed = 1.2, reward = 500, minRound = 8, weight = 4, range = 2.0, cooldown = 1500, maxAlive = 2 },
        spitter = { label = 'Cracheur d\'acide',models = { 'a_m_m_hillbilly_02', 'u_m_y_zombie_01' },
                    hp = 1.4, damage = 0.6, speed = 0.9, reward = 300, minRound = 4, weight = 10, range = 1.6, cooldown = 1400, maxAlive = 3,
                    acid = { minRange = 5.0, maxRange = 22.0, cooldown = 7000, windup = 900, radius = 2.6, duration = 6000,
                             tickDamage = 9, tick = 500, flight = 900 } },
    },

    money = {
        hit = 10,                   -- par impact sur un zombie
        meleeKillBonus = 30,        -- en plus de la récompense, élimination au corps à corps
        reviveBonus = 100,
        roundBonus = 0,             -- versé à chaque joueur vivant en fin de manche
        startMoney = 500,
    },

    -- Atouts (perks). Chaque machine posée sur la map référence un de ces id.
    maxPerks = 4,
    perks = {
        juggernaut  = { label = 'Mastodonte',          price = 2500, icon = 'juggernaut',  color = '#FF3355',
                        desc = 'Encaisse 5 à 6 coups avant d\'être à terre (au lieu de 3).', health = 200 },
        speed       = { label = 'Rapidité',            price = 2000, icon = 'speed',       color = '#FFB020',
                        desc = 'Vitesse de course augmentée de 20 %.', runMultiplier = 1.20 },
        fastreload  = { label = 'Rechargement rapide', price = 3000, icon = 'fastreload',  color = '#3EE6B0',
                        desc = 'Recharge deux fois plus vite.', reloadMultiplier = 0.5 },
        doubledmg   = { label = 'Double dégâts',       price = 5000, icon = 'doubledmg',   color = '#B57BFF',
                        desc = 'Dégâts doublés contre les zombies.', damageMultiplier = 2.0 },
        acidres     = { label = 'Résistance acide',    price = 2000, icon = 'acidres',     color = '#9BFF3E',
                        desc = 'Dégâts de l\'acide réduits de 75 %.', acidMultiplier = 0.25 },
        quickrevive = { label = 'Réanimation rapide',  price = 1500, icon = 'quickrevive', color = '#5FD3FF',
                        desc = 'Réanime deux fois plus vite.', reviveMultiplier = 0.5 },
        regen       = { label = 'Régénération',        price = 2500, icon = 'regen',       color = '#FF77D0',
                        desc = 'Régénération deux fois plus rapide et plus tôt.', regenMultiplier = 2.0 },
        armor       = { label = 'Protection',          price = 3000, icon = 'armor',       color = '#C9D3E0',
                        desc = 'Tous les dégâts reçus réduits de 25 %.', damageTaken = 0.75 },
    },
}
