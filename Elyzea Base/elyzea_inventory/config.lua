Config = {}

-- Touche d'ouverture
Config.OpenKey = 'TAB'

-- ⚖️ Poids : TOUT est en GRAMMES en interne (affiché en KG)
Config.BaseCapacity = 18000     -- 18 KG sans sac
Config.BagItem      = 'vet_sac' -- objet sac (son bonus est défini dans shared/items.lua : +10 KG)
Config.Slots        = 100       -- nombre d'emplacements (le poids maximum ne change pas)
Config.HotbarSlots  = 5         -- emplacements 1 à 5 = raccourcis rapides (touches 1 à 5)
Config.DefaultMaxStack = 100

-- 🧺 Objets au sol
Config.DropDistance = 2.5
Config.DropMaxItems = 25
Config.DropLifetime = 30 * 60
Config.DropProp = `prop_cs_heist_bag_02`

-- 💾 Sauvegarde en base (table players, colonne inventory) toutes les X secondes
Config.SaveInterval = 30

-- 🔐 Anti-spam
Config.RateLimit = { max = 14, window = 1000 }

-- Objets donnés à un NOUVEAU personnage (ex. { name = 'phone', count = 1 })
Config.StarterItems = {
    { name = 'phone', count = 1 },
    { name = 'carte_identite', count = 1 },
}

-- 🎥 Caméra du personnage
Config.Camera = {
    distance = 2.4, minDistance = 1.3, maxDistance = 3.4,
    height = 0.15, lookOffset = -0.05, fov = 40.0,
}

-- 👕 Emplacements autour du personnage = rayons d'elyzea_clothing (mêmes identifiants)
Config.EquipSlots = {
    { name = 'hats',        label = 'Chapeau',    icon = '👒', side = 'left'  },
    { name = 'glasses',     label = 'Lunettes',   icon = '👓', side = 'left'  },
    { name = 'ears',        label = 'Boucles',    icon = '💎', side = 'left'  },
    { name = 'masks',       label = 'Masque',     icon = '😷', side = 'left'  },
    { name = 'chains',      label = 'Collier',    icon = '📿', side = 'left'  },
    { name = 'tops',        label = 'Haut',       icon = '🧥', side = 'left'  },
    { name = 'undershirts', label = 'T-shirt',    icon = '👕', side = 'left'  },
    { name = 'vests',       label = 'Gilet',      icon = '🦺', side = 'left'  },
    { name = 'arms',        label = 'Gants',      icon = '🧤', side = 'right' },
    { name = 'decals',      label = 'Logo',       icon = '🏷️', side = 'right' },
    { name = 'watches',     label = 'Montre',     icon = '⌚', side = 'right' },
    { name = 'bracelets',   label = 'Bracelet',   icon = '💍', side = 'right' },
    { name = 'pants',       label = 'Pantalon',   icon = '👖', side = 'right' },
    { name = 'shoes',       label = 'Chaussures', icon = '👟', side = 'right' },
    { name = 'bags',        label = 'Sac',        icon = '🎒', side = 'right' },
}

Config.Messages = {
    too_heavy    = 'Poids maximum atteint : vous n\'avez pas assez de place dans votre inventaire.',
    no_space     = 'Aucun emplacement libre dans votre inventaire.',
    too_far      = 'Vous êtes trop loin de cet objet.',
    ground_full  = 'Il y a déjà trop d\'objets ici.',
    stack_full   = 'Cette pile est pleine.',
    not_usable   = 'Cet objet ne peut pas être utilisé.',
    bag_heavy    = 'Impossible de retirer le sac : vous passeriez à %.2f KG / %.0f KG. Déposez des objets d\'abord.',
    rate_limited = 'Doucement…',
    cant_open    = 'Impossible d\'ouvrir l\'inventaire maintenant.',
    unknown_item = 'Objet inconnu.',
    no_access    = 'Vous n\'avez pas accès à ce coffre.',
    container_heavy = 'Ce coffre est plein.',
    target_heavy = 'Cette personne ne peut pas porter plus.',
    no_money     = 'Vous n\'avez pas assez d\'argent.',
    no_ammo      = 'Vous n\'avez pas de munitions pour cette arme.',
    no_weapon    = 'Équipez d\'abord une arme compatible.',
}

-- 🚗 Coffres de véhicules (ouverts avec ALT) : valeurs par défaut par catégorie.
-- Le staff les modifie en jeu (menu admin › Coffres véhicules) ; slots = 0 ou kg = 0 : pas de coffre.
Config.Trunks = {
    distance = 5.0,   -- distance max entre le joueur et le véhicule
    classes = {
        [0]  = { label = 'Compactes',            slots = 20, kg = 40 },
        [1]  = { label = 'Berlines',             slots = 30, kg = 60 },
        [2]  = { label = 'SUV',                  slots = 40, kg = 90 },
        [3]  = { label = 'Coupés',               slots = 20, kg = 40 },
        [4]  = { label = 'Muscle cars',          slots = 20, kg = 45 },
        [5]  = { label = 'Sportives classiques', slots = 15, kg = 30 },
        [6]  = { label = 'Sportives',            slots = 15, kg = 30 },
        [7]  = { label = 'Supersportives',       slots = 10, kg = 20 },
        [8]  = { label = 'Motos',                slots = 5,  kg = 10 },
        [9]  = { label = 'Tout-terrain',         slots = 30, kg = 70 },
        [10] = { label = 'Industriels',          slots = 60, kg = 400 },
        [11] = { label = 'Utilitaires',          slots = 50, kg = 200 },
        [12] = { label = 'Fourgons',             slots = 60, kg = 250 },
        [13] = { label = 'Vélos',                slots = 0,  kg = 0 },
        [14] = { label = 'Bateaux',              slots = 20, kg = 60 },
        [15] = { label = 'Hélicoptères',         slots = 20, kg = 60 },
        [16] = { label = 'Avions',               slots = 30, kg = 120 },
        [17] = { label = 'Services',             slots = 30, kg = 90 },
        [18] = { label = 'Urgences',             slots = 30, kg = 90 },
        [19] = { label = 'Militaires',           slots = 40, kg = 150 },
        [20] = { label = 'Commerciaux',          slots = 60, kg = 400 },
        [21] = { label = 'Trains',               slots = 0,  kg = 0 },
        [22] = { label = 'Monoplaces',           slots = 0,  kg = 0 },
    },
}

-- 🔫 Armes
Config.Weapons = {
    maxLoadedAmmo = 250,   -- munitions chargées au maximum dans une arme
    holsterAnim = true,    -- animation pour sortir / ranger une arme
}

-- 🎒 Armes visibles sur le personnage (vues par tous les joueurs)
-- Dans l'inventaire : clic droit sur l'arme › « Mettre dans le dos » / « Retirer du dos ».
-- Dos : fusils, mitraillettes, fusils à pompe, fusils de précision, armes lourdes (UNE seule arme).
-- Ceinture : pistolet glissé à l'arrière du pantalon (UN seul). L'arme en main n'est jamais affichée en double.
-- Réglage des positions en jeu : /positionarme dos|ceinture x y z rx ry rz  (puis recopier la ligne affichée en F8)
Config.BodyWeapons = {
    enabled = true,
    distance = 60.0,           -- distance d'affichage (mètres)
    hideInVehicle = true,      -- cacher les armes quand le joueur est dans un véhicule
    back = { bone = 24818, pos = vec3(0.075, -0.15, -0.02), rot = vec3(0.0, 165.0, 0.0) },   -- haut du dos (SKEL_Spine3)
    waist = { bone = 11816, pos = vec3(-0.08, -0.17, -0.06), rot = vec3(0.0, 95.0, 180.0) },  -- bas du dos (SKEL_Pelvis)
    -- Emplacement forcé pour une arme : 'back', 'waist' ou false (jamais affichée)
    override = {
        WEAPON_STUNGUN = false,
        WEAPON_FLAREGUN = false,
    },
}
