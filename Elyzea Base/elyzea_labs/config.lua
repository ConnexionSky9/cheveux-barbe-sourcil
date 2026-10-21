-- =====================================================================
--  ELYZEA LABS · CONFIGURATION
--  Laboratoires illégaux des groupes d'elyzea_illegal.
--  · Tout ce qui est marqué (menu) se règle aussi en jeu : admin_menu › Laboratoires.
--  · Les laboratoires (emplacement, nom, prix, intérieur) se créent en jeu dans le menu admin.
-- =====================================================================
Config = {}

Config.Debug = false
Config.BucketBase = 52000          -- instance d'un laboratoire = 52000 + id (Dynasty 8 : 40000+, PvP : 61000+)
Config.InteractKey = 38            -- E
Config.InteractDistance = 2.0      -- distance des points (entrée, sortie, cercles)
Config.Account = 'dirty'           -- compte du GROUPE débité pour les achats : 'dirty' (argent sale) ou 'clean'
Config.DefaultLabPrice = 250000    -- prix d'achat proposé à la création d'un laboratoire (menu)

-- Tablette « Laboratoire » : F5 à l'intérieur (intégrée au F5 d'elyzea_illegal), ou /laboratoire
Config.Tablet = { command = 'laboratoire', useIllegalF5 = true }

-- Code d'accès
Config.Code = {
    length = { min = 4, max = 8 },     -- chiffres
    maxFails = 3,                       -- essais ratés avant blocage
    lockSeconds = 120,                  -- blocage après maxFails
    notifyOwnersOnFail = true,          -- prévient le groupe propriétaire d'une tentative ratée
}

-- Coffre du laboratoire (elyzea_inventory gère jusqu'à 500 emplacements ; poids en kg)
Config.Stash = { slots = 500, weight = 1000 }

-- ---------------------------------------------------------------------
--  INTÉRIEURS (intérieurs du jeu de base : aucun MLO requis)
--  check : point de l'intérieur (activation des « entity sets »)
--  spawn : arrivée / sortie · manage : cercle bleu (éditeur) · stash : cercle orange (coffre)
--  bounds : zone où les équipements peuvent être posés (centre, rayon, hauteur min/max)
--  Coordonnées d'usage courant dans la communauté : à vérifier en jeu. Chaque point se
--  corrige EN JEU : admin_menu › Laboratoires › Intérieurs › « Définir ici » (gardé en base).
-- ---------------------------------------------------------------------
Config.Interiors = {
    bunker = {
        label = 'Bunker industriel (grand)',
        check = { x = 899.5518, y = -3246.038, z = -98.04907 },
        spawn = { x = 894.10, y = -3245.80, z = -98.26, h = 90.0 },
        manage = { x = 905.50, y = -3238.20, z = -98.29 },
        stash = { x = 909.30, y = -3222.10, z = -98.29 },
        bounds = { x = 902.0, y = -3228.0, z = -98.3, r = 45.0, minZ = -102.0, maxZ = -92.0 },
        entitySets = { 'Bunker_Style_C', 'upgrade_bunker_set', 'security_upgrade', 'Office_Upgrade_set', 'gun_wall_blocker', 'gun_range_blocker_set' },
    },
    meth = {
        label = 'Laboratoire (biker, méth)',
        check = { x = 1009.5, y = -3196.6, z = -38.99682 },
        spawn = { x = 997.24, y = -3200.65, z = -38.99, h = 270.0 },
        manage = { x = 1003.10, y = -3199.60, z = -38.99 },
        stash = { x = 1011.80, y = -3194.90, z = -38.99 },
        bounds = { x = 1006.0, y = -3197.0, z = -39.0, r = 16.0, minZ = -41.0, maxZ = -35.0 },
        entitySets = { 'meth_lab_upgrade', 'meth_lab_setup', 'meth_lab_security_high' },
    },
    coke = {
        label = 'Laboratoire (biker, cocaïne)',
        check = { x = 1093.6, y = -3196.6, z = -38.99841 },
        spawn = { x = 1088.68, y = -3187.68, z = -38.99, h = 180.0 },
        manage = { x = 1090.40, y = -3193.70, z = -38.99 },
        stash = { x = 1100.10, y = -3199.30, z = -38.99 },
        bounds = { x = 1094.0, y = -3195.0, z = -39.0, r = 18.0, minZ = -41.0, maxZ = -35.0 },
        entitySets = { 'set_up', 'security_high', 'equipment_upgrade', 'production_upgrade', 'table_equipment_upgrade', 'coke_press_upgrade' },
    },
    weed = {
        label = 'Entrepôt (biker, culture)',
        check = { x = 1051.491, y = -3196.536, z = -39.14842 },
        spawn = { x = 1066.30, y = -3183.40, z = -39.16, h = 90.0 },
        manage = { x = 1060.20, y = -3186.50, z = -39.16 },
        stash = { x = 1044.80, y = -3194.80, z = -39.16 },
        bounds = { x = 1053.0, y = -3193.0, z = -39.2, r = 22.0, minZ = -41.0, maxZ = -35.0 },
        -- pas de plantes de culture : aucune récolte à l'intérieur
        entitySets = { 'weed_upgrade_equip', 'weed_security_upgrade', 'weed_chairs', 'weed_drying' },
    },
}
Config.DefaultInterior = 'bunker'

-- ---------------------------------------------------------------------
--  CATÉGORIES DE FABRICATION ET NIVEAUX
--  Le niveau appartient au LABORATOIRE (gardé si le propriétaire change).
--  xp : expérience requise pour POUVOIR acheter ce niveau · price : prix de l'amélioration (compte du groupe)
--  unlocks : catégories débloquées · maxEquipment : équipements posés au maximum
-- ---------------------------------------------------------------------
Config.Categories = {
    weed     = { label = 'Cannabis',        icon = '🌿' },
    cocaine  = { label = 'Cocaïne',         icon = '❄️' },
    crack    = { label = 'Crack',           icon = '💎' },
    meth     = { label = 'Méthamphétamine', icon = '⚗️' },
    ecstasy  = { label = 'Ecstasy',         icon = '💊' },
    ketamine = { label = 'Kétamine',        icon = '🐴' },
    opiates  = { label = 'Opiacés',         icon = '💉' },
}

Config.Levels = {
    { label = 'Niveau 1', xp = 0,     price = 0,       unlocks = { 'weed' },                           maxEquipment = 8 },
    { label = 'Niveau 2', xp = 1500,  price = 150000,  unlocks = { 'cocaine' },                        maxEquipment = 14 },
    { label = 'Niveau 3', xp = 5000,  price = 400000,  unlocks = { 'crack', 'meth' },                  maxEquipment = 20 },
    { label = 'Niveau 4', xp = 12000, price = 900000,  unlocks = { 'ecstasy', 'ketamine', 'opiates' }, maxEquipment = 28 },
}

-- ---------------------------------------------------------------------
--  ÉQUIPEMENTS (achetés avec le compte du groupe, posés avec l'éditeur du cercle bleu)
--  models : modèles possibles, le premier présent dans le jeu est utilisé (vérifié en jeu)
--  anim : animation de fabrication ({ scenario } ou { dict, clip, flag })
-- ---------------------------------------------------------------------
local A = {
    table   = { scenario = 'PROP_HUMAN_PARKING_METER' },
    bench   = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 1 },
    machine = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer', flag = 1 },
    cook    = { scenario = 'PROP_HUMAN_BBQ' },
    write   = { dict = 'missheistdockssetup1clipboard@base', clip = 'base', flag = 49 },
}
Config.Equipment = {
    -- Cannabis (niveau 1)
    weed_dryer     = { label = 'Séchoir à cannabis',          category = 'weed',     price = 25000, models = { 'bkr_prop_weed_dry_02b', 'bkr_prop_weed_dry_01a', 'prop_worklight_03a' }, anim = A.bench },
    weed_trim      = { label = 'Table de manucure',            category = 'weed',     price = 20000, models = { 'bkr_prop_weed_table_01a', 'prop_table_03' }, anim = A.table },
    weed_roll      = { label = 'Table de roulage',             category = 'weed',     price = 10000, models = { 'prop_table_01', 'prop_table_04' }, anim = A.table },
    weed_pack      = { label = 'Poste de conditionnement',     category = 'weed',     price = 15000, models = { 'prop_table_05', 'prop_table_02' }, anim = A.write },
    -- Cocaïne (niveau 2)
    coca_grinder   = { label = 'Broyeur industriel',           category = 'cocaine',  price = 45000, models = { 'prop_tool_box_04', 'prop_barrel_01a' }, anim = A.machine },
    coca_extract   = { label = 'Cuve d\'extraction',           category = 'cocaine',  price = 60000, models = { 'prop_barrel_02a', 'prop_barrel_02b' }, anim = A.cook },
    coca_table     = { label = 'Table de coupe (cocaïne)',     category = 'cocaine',  price = 40000, models = { 'bkr_prop_coke_table01a', 'prop_table_08' }, anim = A.table },
    coca_refinery  = { label = 'Raffinerie',                   category = 'cocaine',  price = 90000, models = { 'prop_barrel_02b', 'prop_barrel_03a' }, anim = A.cook },
    -- Crack (niveau 3)
    crack_stove    = { label = 'Réchaud industriel',           category = 'crack',    price = 50000, models = { 'prop_barrel_03a', 'prop_barrel_02b' }, anim = A.cook },
    crack_bench    = { label = 'Plan de travail (crack)',      category = 'crack',    price = 35000, models = { 'prop_table_04', 'prop_table_07' }, anim = A.table },
    -- Méthamphétamine (niveau 3)
    meth_mixer     = { label = 'Cuve de mélange',              category = 'meth',     price = 70000, models = { 'prop_barrel_01a', 'prop_barrel_exp_01a' }, anim = A.machine },
    meth_reactor   = { label = 'Laboratoire de cuisson',       category = 'meth',     price = 110000, models = { 'bkr_prop_meth_table01a', 'prop_table_06' }, anim = A.cook },
    meth_tray      = { label = 'Bac de cristallisation',       category = 'meth',     price = 50000, models = { 'prop_table_06', 'prop_tool_box_02' }, anim = A.bench },
    -- Ecstasy (niveau 4)
    xtc_reactor    = { label = 'Réacteur de synthèse',         category = 'ecstasy',  price = 90000, models = { 'prop_barrel_02a', 'prop_barrel_01a' }, anim = A.cook },
    xtc_press      = { label = 'Presse à comprimés',           category = 'ecstasy',  price = 70000, models = { 'prop_tool_box_02', 'prop_tool_box_04' }, anim = A.machine },
    -- Kétamine (niveau 4)
    keta_evaporator= { label = 'Évaporateur',                  category = 'ketamine', price = 80000, models = { 'prop_barrel_02b', 'prop_barrel_03a' }, anim = A.cook },
    keta_grinder   = { label = 'Broyeur de cristaux',          category = 'ketamine', price = 50000, models = { 'prop_tool_box_04', 'prop_tool_box_02' }, anim = A.machine },
    -- Opiacés (niveau 4)
    opi_tank       = { label = 'Bassine de macération',        category = 'opiates',  price = 70000, models = { 'prop_barrel_03a', 'prop_barrel_01a' }, anim = A.bench },
    opi_bench      = { label = 'Paillasse de finition',        category = 'opiates',  price = 60000, models = { 'prop_table_08', 'prop_table_06' }, anim = A.table },
}
Config.SellRefund = 50             -- % du prix rendu au groupe quand un équipement est revendu
Config.MinSpacing = 1.2            -- distance minimale entre deux équipements (m)
Config.KeepClear = 1.6             -- rayon interdit autour de la sortie, du cercle bleu et du coffre (m)

-- ---------------------------------------------------------------------
--  RECETTES (fabrication à l'intérieur seulement ; les matières premières se récoltent DEHORS :
--  plants et pots de cannabis, plants de coca, fûts de produits chimiques d'elyzea_drogues,
--  ingrédients chez les fournisseurs). Objets : ceux d'elyzea_drogues (vérifiés au démarrage).
--  inputs / outputs = { { 'objet', quantité } } · duration (s) · xp : expérience du laboratoire
-- ---------------------------------------------------------------------
Config.MaxBatch = 5
Config.Recipes = {}
local R = Config.Recipes
local VARIETIES = {
    { id = 'classic',    label = 'Weed',           leaf = 'weed_leaf',        bud = 'weed_bud',          ground = 'weed_ground',        joint = 'joint',        pouch = 'weed_pouch' },
    { id = 'whitewidow', label = 'White Widow',    leaf = 'weed_leaf_ww',     bud = 'weed_white-widow',  ground = 'weed_ground_ww',     joint = 'joint_ww',     pouch = 'weed_pouch_ww' },
    { id = 'purplehaze', label = 'Purple Haze',    leaf = 'weed_leaf_ph',     bud = 'weed_purple-haze',  ground = 'weed_ground_ph',     joint = 'joint_ph',     pouch = 'weed_pouch_ph' },
    { id = 'custom',     label = 'Variété maison', leaf = 'weed_leaf_custom', bud = 'weed_bud_custom',   ground = 'weed_ground_custom', joint = 'joint_custom', pouch = 'weed_pouch_custom' },
}
for i, v in ipairs(VARIETIES) do
    R['weed_dry_' .. v.id]   = { label = ('Sécher : %s'):format(v.label), equipment = 'weed_dryer', order = i,
        inputs = { { v.leaf, 3 } }, outputs = { { v.bud, 2 } }, duration = 10, xp = 5 }
    R['weed_grind_' .. v.id] = { label = ('Préparer : %s'):format(v.label), equipment = 'weed_trim', order = i,
        inputs = { { v.bud, 1 } }, outputs = { { v.ground, 2 } }, duration = 6, xp = 3 }
    R['weed_roll_' .. v.id]  = { label = ('Rouler : joint de %s'):format(v.label), equipment = 'weed_roll', order = i,
        inputs = { { v.ground, 1 }, { 'rolling_paper', 1 } }, outputs = { { v.joint, 1 } }, duration = 5, xp = 2 }
    R['weed_pack_' .. v.id]  = { label = ('Pochon de %s'):format(v.label), equipment = 'weed_pack', order = i,
        inputs = { { v.bud, 2 }, { 'drug_bag', 1 } }, outputs = { { v.pouch, 1 } }, duration = 5, xp = 4 }
end
-- Cocaïne
R.coca_grind  = { label = 'Broyer les feuilles de coca', equipment = 'coca_grinder', inputs = { { 'coca_leaf', 4 } }, outputs = { { 'coca_ground', 2 } }, duration = 8, xp = 6 }
R.coca_paste  = { label = 'Extraire la pâte de coca', equipment = 'coca_extract', inputs = { { 'coca_ground', 2 }, { 'drg_solvent', 1 } }, outputs = { { 'coca_paste', 1 } }, duration = 12, xp = 10 }
R.coca_bag    = { label = 'Couper et ensacher (cocaïne)', equipment = 'coca_table', inputs = { { 'coca_paste', 1 }, { 'drug_bag', 2 } }, outputs = { { 'cokebaggy', 2 } }, duration = 6, xp = 8 }
R.coca_refine = { label = 'Raffiner la pâte', equipment = 'coca_refinery', inputs = { { 'coca_paste', 2 }, { 'drg_reagent', 1 } }, outputs = { { 'coca_refined', 1 } }, duration = 15, xp = 15 }
R.coca_pure   = { label = 'Finition : cocaïne pure', equipment = 'coca_table', inputs = { { 'coca_refined', 1 }, { 'drug_bag', 2 } }, outputs = { { 'coke_premium', 2 } }, duration = 10, xp = 20 }
-- Crack
R.crack_mix   = { label = 'Mélanger la base', equipment = 'crack_stove', inputs = { { 'coca_paste', 1 }, { 'baking_soda', 1 } }, outputs = { { 'crack_mix', 1 } }, duration = 8, xp = 8 }
R.crack_cook  = { label = 'Chauffer le mélange', equipment = 'crack_stove', inputs = { { 'crack_mix', 1 }, { 'water', 1 } }, outputs = { { 'crack_paste', 1 } }, duration = 12, xp = 10 }
R.crack_dry   = { label = 'Faire durcir', equipment = 'crack_bench', inputs = { { 'crack_paste', 1 } }, outputs = { { 'crack_block', 1 } }, duration = 10, xp = 6 }
R.crack_cut   = { label = 'Découper en cailloux', equipment = 'crack_bench', inputs = { { 'crack_block', 1 } }, outputs = { { 'crack_rocks', 4 } }, duration = 6, xp = 6 }
R.crack_bag   = { label = 'Ensacher le crack', equipment = 'crack_bench', inputs = { { 'crack_rocks', 2 }, { 'drug_bag', 1 } }, outputs = { { 'crack_baggy', 1 } }, duration = 4, xp = 5 }
-- Méth
R.meth_mix    = { label = 'Préparer le mélange', equipment = 'meth_mixer', inputs = { { 'meth_chemicals', 2 }, { 'drg_acid', 1 } }, outputs = { { 'meth_mix', 1 } }, duration = 10, xp = 10 }
R.meth_cook   = { label = 'Cuire le mélange', equipment = 'meth_reactor', inputs = { { 'meth_mix', 1 } }, outputs = { { 'meth_liquid', 1 } }, duration = 15, xp = 15 }
R.meth_cool   = { label = 'Cristalliser', equipment = 'meth_tray', inputs = { { 'meth_liquid', 1 } }, outputs = { { 'meth_crystal', 3 } }, duration = 12, xp = 12 }
R.meth_bag    = { label = 'Ensacher la méth', equipment = 'meth_tray', inputs = { { 'meth_crystal', 1 }, { 'drug_bag', 1 } }, outputs = { { 'meth', 1 } }, duration = 4, xp = 5 }
-- Ecstasy
R.xtc_base    = { label = 'Préparer la base', equipment = 'xtc_reactor', inputs = { { 'drg_safrole', 1 }, { 'drg_solvent', 1 } }, outputs = { { 'xtc_base', 1 } }, duration = 10, xp = 10 }
R.xtc_powder  = { label = 'Synthèse de la poudre', equipment = 'xtc_reactor', inputs = { { 'xtc_base', 1 } }, outputs = { { 'xtc_powder', 2 } }, duration = 14, xp = 12 }
for _, c in ipairs({ { 'pink', 'roses' }, { 'blue', 'bleus' }, { 'yellow', 'jaunes' } }) do
    R['xtc_press_' .. c[1]] = { label = ('Presser : comprimés %s'):format(c[2]), equipment = 'xtc_press',
        inputs = { { 'xtc_powder', 1 }, { 'drg_dye_' .. c[1], 1 } }, outputs = { { 'xtc_tabs_' .. c[1], 1 } }, duration = 8, xp = 8 }
    R['xtc_pack_' .. c[1]] = { label = ('Conditionner : ecstasy %s'):format(c[2]:sub(1, -2)), equipment = 'xtc_press',
        inputs = { { 'xtc_tabs_' .. c[1], 1 }, { 'drug_bag', 1 } }, outputs = { { 'xtc_' .. c[1], 4 } }, duration = 4, xp = 5 }
end
-- Kétamine
R.keta_evap   = { label = 'Évaporer le liquide', equipment = 'keta_evaporator', inputs = { { 'drg_keta_liquid', 1 } }, outputs = { { 'keta_wet', 1 } }, duration = 12, xp = 10 }
R.keta_dry    = { label = 'Sécher les cristaux', equipment = 'keta_evaporator', inputs = { { 'keta_wet', 1 } }, outputs = { { 'keta_crystal', 1 } }, duration = 10, xp = 8 }
R.keta_grind  = { label = 'Broyer en poudre', equipment = 'keta_grinder', inputs = { { 'keta_crystal', 1 } }, outputs = { { 'keta_powder', 2 } }, duration = 6, xp = 6 }
R.keta_bag    = { label = 'Ensacher la kétamine', equipment = 'keta_grinder', inputs = { { 'keta_powder', 1 }, { 'drug_bag', 1 } }, outputs = { { 'ketamine', 2 } }, duration = 4, xp = 5 }
-- Opiacés
R.opi_macerate= { label = 'Macérer la résine', equipment = 'opi_tank', inputs = { { 'drg_opium_raw', 1 }, { 'water', 1 } }, outputs = { { 'opi_solution', 1 } }, duration = 10, xp = 10 }
R.opi_filter  = { label = 'Filtrer la solution', equipment = 'opi_tank', inputs = { { 'opi_solution', 1 }, { 'drg_solvent', 1 } }, outputs = { { 'opi_base', 2 } }, duration = 12, xp = 12 }
R.opi_powder  = { label = 'Poudre pour comprimés', equipment = 'opi_bench', inputs = { { 'opi_base', 1 } }, outputs = { { 'opi_powder', 1 } }, duration = 8, xp = 8 }
R.opi_pills   = { label = 'Conditionner les comprimés', equipment = 'opi_bench', inputs = { { 'opi_powder', 1 }, { 'drug_bag', 1 } }, outputs = { { 'oxy', 4 } }, duration = 5, xp = 6 }
R.opi_inject  = { label = 'Préparation injectable', equipment = 'opi_bench', inputs = { { 'opi_base', 1 }, { 'drg_syringe_empty', 2 } }, outputs = { { 'opi_syringe', 2 } }, duration = 8, xp = 10 }

-- ---------------------------------------------------------------------
--  PERMISSIONS DES GRADES (réglées par le chef dans la tablette, grade par grade)
--  Le chef du groupe (grade « boss ») a toujours tout.
-- ---------------------------------------------------------------------
Config.Perms = {
    { key = 'enter',     label = 'Entrer sans code' },
    { key = 'craft',     label = 'Fabriquer' },
    { key = 'stash',     label = 'Utiliser le coffre' },
    { key = 'equipment', label = 'Acheter / placer les équipements' },
    { key = 'tablet',    label = 'Ouvrir la tablette' },
    { key = 'security',  label = 'Changer le code' },
    { key = 'upgrade',   label = 'Acheter les améliorations' },
    { key = 'raid',      label = 'Voir les attaques' },
}
-- Droits par défaut d'un grade non réglé (tous les membres du groupe propriétaire)
Config.DefaultGradePerms = { enter = true, craft = true, stash = false, equipment = false, tablet = true, security = false, upgrade = false, raid = true }

-- ---------------------------------------------------------------------
--  ATTAQUES (valeurs par défaut ; menu admin › Laboratoires › Attaques)
-- ---------------------------------------------------------------------
Config.Raids = {
    enabled = true,
    utcOffset = 1,               -- fuseau horaire du serveur (heures par rapport à UTC ; 1 = Paris en hiver, 2 = en été)
    slots = {                    -- créneaux autorisés : jours (1 = lundi … 7 = dimanche), heures « HH:MM »
        { days = { 1, 2, 3, 4, 5, 6, 7 }, from = '20:00', to = '23:30' },
    },
    prepSeconds = 60,            -- préparation : les défenseurs sont prévenus avant le début
    duration = 600,              -- durée de capture (s) : 10 minutes
    radius = 60.0,               -- rayon de la zone de capture autour de l'entrée (m)
    minAttackers = 2,            -- attaquants vivants dans la zone pour lancer l'attaque
    minDefendersOnline = 1,      -- membres du groupe propriétaire connectés (0 = possible même absents)
    starterBossOnly = true,      -- seul un chef peut lancer l'attaque (sinon : tout membre)
    emptyGrace = 30,             -- s : plus aucun attaquant vivant dans la zone pendant ce délai = échec
    winRule = 'present',         -- 'present' : au moins 1 attaquant vivant dans la zone à la fin
                                 -- 'majority' : plus d'attaquants que de défenseurs vivants dans la zone à la fin
    labCooldown = 120,           -- minutes avant qu'un laboratoire puisse être attaqué à nouveau
    groupCooldown = 60,          -- minutes avant qu'un groupe puisse relancer une attaque
    lockDuringRaid = true,       -- personne n'entre dans le laboratoire pendant l'attaque
    kickOnCapture = true,        -- capture : les joueurs qui n'ont plus accès sont sortis du laboratoire
    notifyAllMembers = true,     -- prévient tous les membres connectés des deux groupes (sinon : chef seulement)
}
