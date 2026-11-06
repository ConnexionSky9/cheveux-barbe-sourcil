-- =====================================================================
--  ELYZEA LASERGAME - CONFIGURATION AVANCÉE
--  Armes laser et rangs PVP.
--  Les valeurs « staff » (dégâts, portée, cadence, seuils des rangs) sont aussi modifiables en jeu (/lgadmin).
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
-- damage   : dégâts sur le bouclier d'un joueur
-- range    : portée (m) · rpm : cadence (tirs / minute) · spread : dispersion (degrés)
-- mag      : tirs avant recharge (0 = jamais) · reload : durée de recharge (ms)
-- beam     : 'pulse' (impulsion courte), 'beam' (rayon continu), 'rail' (rayon épais longue durée),
--            'scatter' (plusieurs rayons), 'blade' (arc de mêlée)
-- pellets  : nombre de rayons par tir (scatter)
LG.Weapons = {
    -- MÊLÉE ------------------------------------------------------------
    { id = 'ion_blade',    label = 'Lame Ionique',        cat = 'melee',  model = 'WEAPON_MACHETE',
      damage = 100, range = 2.8, rpm = 90,  spread = 0,   mag = 0,  reload = 0,
      beam = 'blade', width = 0.05, life = 180, sound = 'blade', tier = 1 },
    { id = 'photon_baton', label = 'Matraque Photonique', cat = 'melee',  model = 'WEAPON_NIGHTSTICK',
      damage = 60, range = 2.6, rpm = 140, spread = 0,   mag = 0,  reload = 0,
      beam = 'blade', width = 0.04, life = 150, sound = 'blade', tier = 1 },

    -- PISTOLETS --------------------------------------------------------
    { id = 'photon_p9',    label = 'Photon P9',           cat = 'pistol', model = 'WEAPON_PISTOL',
      damage = 25, range = 60,  rpm = 240, spread = 1.2, mag = 12, reload = 1400,
      beam = 'pulse', width = 0.018, life = 90, sound = 'pistol', tier = 1 },
    { id = 'vector_x',     label = 'Vector-X',            cat = 'pistol', model = 'WEAPON_COMBATPISTOL',
      damage = 30, range = 65,  rpm = 210, spread = 1.0, mag = 10, reload = 1500,
      beam = 'pulse', width = 0.02, life = 90, sound = 'pistol', tier = 2 },
    { id = 'atomizer',     label = 'Atomiseur Néon',      cat = 'pistol', model = 'WEAPON_RAYPISTOL',
      damage = 45, range = 55,  rpm = 100, spread = 0.4, mag = 6,  reload = 1800,
      beam = 'rail', width = 0.035, life = 160, sound = 'heavy', tier = 3 },

    -- MITRAILLETTES ----------------------------------------------------
    { id = 'pulse_smg',    label = 'Pulse SMG',           cat = 'smg',    model = 'WEAPON_SMG',
      damage = 14, range = 45,  rpm = 720, spread = 2.4, mag = 30, reload = 1800,
      beam = 'pulse', width = 0.014, life = 60, sound = 'smg', tier = 2 },
    { id = 'hornet',       label = 'Hornet MK2',          cat = 'smg',    model = 'WEAPON_MICROSMG',
      damage = 12, range = 40,  rpm = 840, spread = 3.0, mag = 32, reload = 1600,
      beam = 'pulse', width = 0.012, life = 55, sound = 'smg', tier = 2 },
    { id = 'hellbringer',  label = 'Hellbringer',         cat = 'smg',    model = 'WEAPON_RAYCARBINE',
      damage = 16, range = 55,  rpm = 780, spread = 2.0, mag = 50, reload = 2400,
      beam = 'beam', width = 0.02, life = 70, sound = 'smg', tier = 4 },

    -- FUSILS D'ASSAUT --------------------------------------------------
    { id = 'nova_ar',      label = 'Nova AR',             cat = 'rifle',  model = 'WEAPON_CARBINERIFLE',
      damage = 20, range = 90,  rpm = 560, spread = 1.4, mag = 30, reload = 2000,
      beam = 'beam', width = 0.018, life = 70, sound = 'rifle', tier = 2 },
    { id = 'spectre',      label = 'Spectre-7',           cat = 'rifle',  model = 'WEAPON_SPECIALCARBINE',
      damage = 22, range = 95,  rpm = 520, spread = 1.2, mag = 30, reload = 2100,
      beam = 'beam', width = 0.02, life = 70, sound = 'rifle', tier = 3 },
    { id = 'quasar',       label = 'Quasar Bullpup',      cat = 'rifle',  model = 'WEAPON_BULLPUPRIFLE',
      damage = 26, range = 100, rpm = 480, spread = 1.0, mag = 36, reload = 2200,
      beam = 'beam', width = 0.022, life = 80, sound = 'rifle', tier = 4 },

    -- SNIPERS ----------------------------------------------------------
    { id = 'longbow',      label = 'Longbow L-1',         cat = 'sniper', model = 'WEAPON_MARKSMANRIFLE',
      damage = 55, range = 180, rpm = 90,  spread = 0.2, mag = 8,  reload = 2600,
      beam = 'rail', width = 0.03, life = 220, sound = 'sniper', tier = 3 },
    { id = 'helios',       label = 'Hélios Railgun',      cat = 'sniper', model = 'WEAPON_SNIPERRIFLE',
      damage = 90, range = 250, rpm = 45,  spread = 0.05, mag = 5, reload = 3000,
      beam = 'rail', width = 0.045, life = 320, sound = 'sniper', tier = 4 },
}

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
