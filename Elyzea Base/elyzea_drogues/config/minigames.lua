-- =====================================================================
--  ÉTAPES IMMERSIVES : mini-jeu + scène (position, animation, objets) pour chaque étape de fabrication
--  Utilisé par elyzea_drogues (postes, récolte, pots) ET elyzea_labs (équipements des laboratoires).
--  Les quantités, recettes, prix et durées NE CHANGENT PAS : le mini-jeu remplace seulement la barre
--  de progression. Le serveur garde la durée minimale de la recette et revérifie tout.
--
--  Modèles : listes de candidats, le premier présent dans le jeu est utilisé (IsModelInCdimage),
--  un modèle absent est ignoré sans rien bloquer. Commande /drogues_verif (staff) : liste en F8
--  les modèles et animations absents du jeu chez toi.
--  Animations : { dict, clip, flag } ou { scenario }, avec « fb » = solution de repli si le dictionnaire
--  n'existe pas. Les replis marqués (v) sont repris des données d'animations du serveur (rpemotes).
-- =====================================================================
Config.Minigames = {
    enabled = true,          -- false : retour à l'ancienne barre de progression partout
    walkToStation = true,    -- le personnage se place devant le poste avant de commencer
    limitFactor = 1.0,       -- multiplie le temps maximum des mini-jeux (1.0 = normal)
    networkProps = true,     -- objets temporaires visibles des autres joueurs (supprimés par le serveur à la fin)
}

-- ---------------------------------------------------------------- animations
local AN = {
    seat_trim  = { dict = 'anim@amb@business@weed@weed_sorting_seated@', clip = 'sorter_right_sort_v3_sorter02', flag = 1,
                   fb = { dict = 'anim@amb@business@bgen@bgen_no_work@', clip = 'sit_phone_phoneputdown_idle_nowork', flag = 1 } },        -- (v) repli
    crouch_weed= { dict = 'anim@amb@business@weed@weed_inspecting_lo_med_hi@', clip = 'weed_crouch_checkingleaves_idle_01_inspector', flag = 1, fb = { scenario = 'WORLD_HUMAN_GARDENER_PLANT' } },
    stand_weed = { dict = 'anim@amb@business@weed@weed_inspecting_lo_med_hi@', clip = 'weed_stand_checkingleaves_idle_01_inspector', flag = 1, fb = { scenario = 'WORLD_HUMAN_GARDENER_PLANT' } },
    dry_check  = { dict = 'anim@amb@business@weed@weed_inspecting_high_dry@', clip = 'weed_inspecting_high_base_inspector', flag = 1,
                   fb = { dict = 'amb@prop_human_movie_bulb@idle_a', clip = 'idle_b', flag = 1 } },                                        -- (v) repli
    table_cut  = { dict = 'anim@amb@business@coc@coc_unpack_cut_left@', clip = 'coke_cut_v1_coccutter', flag = 1,
                   fb = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 1 } },                                                       -- (v) repli
    table_pack = { dict = 'anim@amb@business@coc@coc_packing_hi@', clip = 'full_cycle_v1_pressoperator', flag = 1,
                   fb = { scenario = 'PROP_HUMAN_PARKING_METER' } },
    pour       = { dict = 'anim@amb@business@meth@meth_monitoring_cooking@cooking@', clip = 'chemical_pour_short_cooker', flag = 1,
                   fb = { scenario = 'PROP_HUMAN_BBQ' } },
    smash      = { dict = 'anim@amb@business@meth@meth_smash_weight_check@', clip = 'break_weigh_v3_char01', flag = 1,
                   fb = { scenario = 'WORLD_HUMAN_HAMMERING' } },
    machine    = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer', flag = 1, fb = { scenario = 'PROP_HUMAN_PARKING_METER' } }, -- (v)
    bulb       = { dict = 'amb@prop_human_movie_bulb@idle_a', clip = 'idle_b', flag = 1, fb = { scenario = 'PROP_HUMAN_PARKING_METER' } },  -- (v)
    shaker     = { dict = 'anim@amb@clubhouse@bar@drink@idle_a', clip = 'idle_a_bartender', flag = 1, fb = { scenario = 'PROP_HUMAN_PARKING_METER' } }, -- (v)
    stove      = { scenario = 'PROP_HUMAN_BBQ' },
    kneel      = { scenario = 'CODE_HUMAN_MEDIC_KNEEL' },
    pickup     = { dict = 'random@domestic', clip = 'pickup_low', flag = 1, fb = { scenario = 'CODE_HUMAN_MEDIC_KNEEL' } },                 -- (v)
    garden     = { scenario = 'WORLD_HUMAN_GARDENER_PLANT' },
    clipboard  = { dict = 'missheistdockssetup1clipboard@base', clip = 'base', flag = 49, fb = { scenario = 'PROP_HUMAN_PARKING_METER' } }, -- (v)
}
Config.SceneAnims = AN

-- ---------------------------------------------------------------- objets (candidats par ordre de préférence)
local M = {
    chair      = { 'bkr_prop_weed_chair_01a', 'prop_chair_01a', 'prop_chair_01b' },
    budpile    = { 'bkr_prop_weed_bud_02a', 'bkr_prop_weed_01_small_01b' },
    bud        = { 'bkr_prop_weed_bud_pruned_01a', 'bkr_prop_weed_01_small_01c' },
    leaves     = { 'bkr_prop_weed_leaf_01a', 'bkr_prop_weed_01_small_01c' },
    weedbucket = { 'bkr_prop_weed_bucket_open_01a' },
    weedbag    = { 'bkr_prop_weed_bag_01a', 'bkr_prop_weed_bigbag_01a' },
    smallbag   = { 'bkr_prop_weed_smallbag_01a', 'prop_drug_package_02' },
    weedblock  = { 'prop_weed_block_01' },
    weedbottle = { 'prop_weed_bottle' },
    joint      = { 'p_cs_joint_01' },
    scales     = { 'bkr_prop_weed_scales_01a', 'bkr_prop_coke_scale_01' },
    cokescale  = { 'bkr_prop_coke_scale_01', 'bkr_prop_weed_scales_01a' },
    fan        = { 'bkr_prop_weed_fan_floor_01a' },
    cokeblock  = { 'bkr_prop_coke_block_01a', 'prop_coke_block_01' },
    cutblock   = { 'bkr_prop_coke_cutblock_01', 'bkr_prop_coke_block_01a' },
    powder     = { 'bkr_prop_coke_tablepowder' },
    spoon      = { 'h4_prop_h4_coke_spoon_01' },
    package    = { 'prop_drug_package_02', 'prop_drug_package' },
    bottle     = { 'prop_ld_flow_bottle' },
    ammonia    = { 'bkr_prop_meth_ammonia', 'prop_ld_flow_bottle' },
    acid       = { 'bkr_prop_meth_sacid', 'prop_ld_flow_bottle' },
    gas        = { 'prop_gascyl_01a' },
    methtray   = { 'bkr_prop_meth_tray_01a', 'prop_food_tray_03' },
    methbag    = { 'bkr_prop_meth_openbag_01a', 'prop_drug_package_02' },
    hammer     = { 'bkr_prop_meth_hammer_01', 'prop_tool_hammer' },
    tray       = { 'prop_food_tray_02', 'prop_food_tray_03' },
    plate      = { 'prop_cs_plate_01' },
    knife      = { 'prop_cs_bowie_knife' },
    card       = { 'prop_cs_credit_card', 'p_ld_id_card_002' },
    scissors   = { 'prop_cs_scissors' },
    syringe    = { 'prop_syringe_01' },
    press      = { 'bkr_prop_coke_press_01aa' },
    toolbox    = { 'imp_prop_tool_box_01a', 'prop_tool_box_01' },
}
Config.SceneModels = M

-- Positions : at = 'top' (posé sur le dessus du poste) ou 'ground' (au sol, à côté)
--   fx / fy : position relative dans l'emprise du poste (-1 = bord gauche/avant, 1 = bord droit/arrière)
--   out : décalage en mètres hors de l'emprise (pour 'ground') · h : rotation (degrés)
-- La hauteur est calculée avec les dimensions réelles des modèles : jamais d'objet flottant ou enfoncé.
local function P(models, at, fx, fy, h, out) return { models = models, at = at, fx = fx or 0.0, fy = fy or 0.0, h = h or 0.0, out = out } end

-- Main (objet tenu) : os 28422 = main droite, 60309 = main gauche
local HAND = {
    scissors = { models = M.scissors, bone = 28422, pos = { 0.05, 0.0, -0.02 }, rot = { 0.0, 0.0, 90.0 } },
    joint    = { models = M.joint,    bone = 28422, pos = { 0.02, 0.0, 0.0 },   rot = { 0.0, 0.0, 0.0 } },
    bud      = { models = M.bud,      bone = 60309, pos = { 0.08, 0.02, 0.0 },  rot = { 0.0, 0.0, 0.0 } },
    spoon    = { models = M.spoon,    bone = 28422, pos = { 0.03, 0.0, 0.0 },   rot = { 0.0, 90.0, 0.0 } },
    bottle   = { models = M.bottle,   bone = 28422, pos = { 0.0, 0.0, -0.05 },  rot = { 0.0, 0.0, 0.0 } },
    knife    = { models = M.knife,    bone = 28422, pos = { 0.03, 0.0, 0.0 },   rot = { 0.0, 0.0, 0.0 } },
    card     = { models = M.card,     bone = 28422, pos = { 0.05, 0.0, 0.0 },   rot = { 0.0, 0.0, 90.0 } },
    hammer   = { models = M.hammer,   bone = 28422, pos = { 0.05, 0.0, 0.0 },   rot = { 0.0, 0.0, 90.0 } },
    syringe  = { models = M.syringe,  bone = 28422, pos = { 0.03, 0.0, 0.0 },   rot = { 0.0, 0.0, 0.0 } },
}

-- ---------------------------------------------------------------- décor permanent des postes (visible de tous)
--  seat : chaise devant le poste (étape assise). Sert aussi de point d'interaction (ALT sur la chaise).
Config.Decor = {
    weed_trim   = { seat = true, props = { P(M.budpile, 'top', -0.55, 0.25, 20), P(M.leaves, 'top', 0.15, 0.35, 0), P(M.scissors, 'top', 0.45, -0.25, 70), P(M.weedbucket, 'ground', 1.0, 0.0, 0, 0.35) } },
    weed_dry    = { props = { P(M.fan, 'ground', -1.0, 0.0, 90, 0.6), P(M.weedbucket, 'ground', 1.0, -0.4, 0, 0.35) } },
    weed_grind  = { props = { P(M.budpile, 'top', -0.5, 0.2, 0), P(M.weedbag, 'top', 0.5, 0.3, 30) } },
    weed_grind_seat = { seat = true, props = { P(M.budpile, 'top', -0.5, 0.2, 0), P(M.weedbag, 'top', 0.5, 0.3, 30), P(M.weedbucket, 'ground', 1.0, 0.0, 0, 0.35) } },
    weed_roll   = { seat = true, props = { P(M.weedbottle, 'top', -0.5, 0.3, 0), P(M.joint, 'top', 0.3, -0.2, 40), P(M.joint, 'top', 0.4, -0.1, 70) } },
    weed_pack   = { props = { P(M.scales, 'top', 0.0, 0.1, 0), P(M.smallbag, 'top', 0.55, 0.2, 20), P(M.weedblock, 'top', -0.55, 0.25, 10) } },
    coca_grind  = { props = { P(M.cokeblock, 'ground', 1.0, 0.0, 0, 0.3) } },
    coca_process= { props = { P(M.powder, 'top', -0.3, 0.2, 0), P(M.cokescale, 'top', 0.45, 0.25, 0), P(M.bottle, 'top', 0.6, -0.3, 0) } },
    coca_pack   = { props = { P(M.cokescale, 'top', 0.0, 0.15, 0), P(M.package, 'top', 0.55, 0.25, 15), P(M.cokeblock, 'top', -0.5, 0.2, 0) } },
    coca_refine = { props = { P(M.bottle, 'ground', 1.0, 0.0, 0, 0.25), P(M.gas, 'ground', -1.0, 0.0, 0, 0.35) } },
    coca_finish = { props = { P(M.cutblock, 'top', 0.0, 0.1, 0), P(M.spoon, 'top', 0.4, -0.2, 40), P(M.powder, 'top', -0.4, 0.2, 0) } },
    crack_mix   = { props = { P(M.plate, 'top', 0.0, 0.0, 0), P(M.bottle, 'top', 0.5, 0.3, 0) } },
    crack_cook  = { props = { P(M.gas, 'ground', -1.0, 0.0, 0, 0.35) } },
    crack_dry   = { props = { P(M.tray, 'ground', 0.0, -1.0, 0, 0.45) } },
    crack_cut   = { props = { P(M.plate, 'top', 0.0, 0.0, 0), P(M.knife, 'top', 0.45, -0.2, 80) } },
    crack_pack  = { props = { P(M.package, 'top', 0.4, 0.2, 0), P(M.plate, 'top', -0.3, 0.0, 0) } },
    meth_prep   = { props = { P(M.ammonia, 'ground', 1.0, 0.2, 0, 0.25), P(M.acid, 'ground', 1.0, -0.3, 0, 0.25) } },
    meth_cook   = { props = { P(M.gas, 'ground', -1.0, 0.0, 0, 0.35), P(M.acid, 'ground', 1.0, 0.0, 0, 0.25) } },
    meth_cool   = { props = { P(M.methtray, 'top', 0.0, 0.1, 0), P(M.hammer, 'top', 0.55, -0.2, 60) } },
    meth_pack   = { props = { P(M.cokescale, 'top', 0.0, 0.1, 0), P(M.methbag, 'top', -0.5, 0.2, 0) } },
    xtc_prep    = { props = { P(M.bottle, 'top', -0.5, 0.25, 0), P(M.bottle, 'top', -0.35, 0.3, 0), P(M.plate, 'top', 0.3, 0.0, 0) } },
    xtc_synth   = { props = { P(M.gas, 'ground', -1.0, 0.0, 0, 0.35) } },
    xtc_press   = { props = { P(M.press, 'ground', 1.0, 0.0, 0, 0.4) } },
    xtc_pack    = { props = { P(M.package, 'top', 0.5, 0.2, 0), P(M.plate, 'top', -0.2, 0.0, 0) } },
    opi_prep    = { props = { P(M.weedbucket, 'ground', 1.0, 0.0, 0, 0.3) } },
    opi_refine  = { props = { P(M.bottle, 'top', -0.5, 0.25, 0), P(M.plate, 'top', 0.2, 0.0, 0) } },
    opi_finish  = { props = { P(M.syringe, 'top', 0.4, -0.2, 70), P(M.plate, 'top', -0.2, 0.1, 0) } },
    opi_pack    = { props = { P(M.package, 'top', 0.4, 0.2, 0) } },
    keta_prep   = { props = { P(M.gas, 'ground', -1.0, 0.0, 0, 0.35) } },
    keta_dry    = { props = { P(M.tray, 'ground', 0.0, -1.0, 0, 0.45) } },
    keta_grind  = { props = { P(M.plate, 'ground', 1.0, 0.0, 0, 0.3) } },
    keta_pack   = { props = { P(M.cokescale, 'top', 0.0, 0.1, 0), P(M.package, 'top', 0.5, 0.2, 0) } },
    shroom_sort = { props = { P(M.plate, 'top', 0.3, 0.0, 0), P(M.weedbucket, 'ground', 1.0, 0.0, 0, 0.35) } },
    shroom_dry  = { props = { P(M.tray, 'ground', 0.0, -1.0, 0, 0.45) } },
    shroom_pack = { props = { P(M.cokescale, 'top', 0.0, 0.1, 0), P(M.smallbag, 'top', 0.5, 0.2, 0) } },
}
-- Équipements des laboratoires (elyzea_labs) → décor équivalent
Config.LabDecor = {
    weed_dryer = 'weed_dry', weed_trim = 'weed_grind_seat', weed_roll = 'weed_roll', weed_pack = 'weed_pack',
    coca_grinder = 'coca_grind', coca_extract = 'coca_refine', coca_table = 'coca_finish', coca_refinery = 'coca_refine',
    crack_stove = 'crack_cook', crack_bench = 'crack_cut', meth_mixer = 'meth_prep', meth_reactor = 'meth_cook', meth_tray = 'meth_cool',
    xtc_reactor = 'xtc_synth', xtc_press = 'xtc_press', keta_evaporator = 'keta_prep', keta_grinder = 'keta_grind', opi_tank = 'opi_prep', opi_bench = 'opi_finish',
}

-- ---------------------------------------------------------------- profils d'étape (clé = recette sans suffixe de variété / couleur)
--  game  : mini-jeu (html/mg_games*.js) · skin : variante visuelle · per : objectifs par unité fabriquée
--  min / cap : bornes du nombre d'objectifs · maxMistakes : erreurs tolérées · secPer : secondes max par objectif
--  pose  : 'stand' (debout face au poste), 'seat' (chaise du décor), 'seatIfChair' (assis si le poste a une chaise,
--          sinon debout), 'here' (sur place : plantes, sol)
--  anim  : animation pendant le mini-jeu · hand : objet tenu · temp : objets posés le temps de l'étape
local S = {}
Config.Steps = S
-- Cannabis
S.weed_trim  = { game = 'trim', per = 6, min = 6, cap = 30, maxMistakes = 3, secPer = 3, pose = 'seat', anim = AN.seat_trim, hand = HAND.bud,
    temp = { P(M.bud, 'top', 0.0, -0.45, 0) },
    title = 'Effeuiller les têtes', hint = 'Attrape chaque petite feuille et tire-la vers l\'extérieur pour la décrocher de la fleur. Ne pince pas la fleur.' }
S.weed_dry   = { game = 'hang', skin = 'weed', per = 3, min = 3, cap = 9, plusOne = true, maxMistakes = 3, secPer = 5, pose = 'stand', anim = AN.dry_check, hand = HAND.bud,
    title = 'Suspendre les têtes au séchoir', hint = 'Glisse chaque tête sur un crochet libre, puis règle la ventilation.' }
S.weed_grind = { game = 'grind', skin = 'grinder', per = 3, min = 3, cap = 15, maxMistakes = 3, secPer = 4, pose = 'seatIfChair', anim = AN.table_cut,
    title = 'Effriter au moulin', hint = 'Maintiens le clic et tourne autour du moulin, sans aller trop vite.' }
S.weed_roll  = { game = 'roll', per = 3, min = 3, cap = 15, maxMistakes = 3, secPer = 7, pose = 'seatIfChair', anim = AN.table_cut, hand = HAND.joint,
    title = 'Rouler un joint', hint = 'Répartis le cannabis : clique les 3 repères sur la feuille.' }
S.weed_pack  = { game = 'scale', skin = 'bud', per = 1, min = 1, cap = 5, maxMistakes = 3, secPer = 10, pose = 'stand', anim = AN.dry_check, extra = { grams = 3.5 },
    title = 'Peser et ensacher', hint = 'Maintiens le clic sur le bocal pour remplir le sachet. Relâche au bon poids : il continue de couler un peu.' }
-- Cocaïne
S.coca_grind  = { game = 'grind', skin = 'crank', per = 3, min = 3, cap = 15, maxMistakes = 3, secPer = 4, pose = 'stand', anim = AN.machine,
    title = 'Broyer les feuilles', hint = 'Tourne la manivelle en maintenant le clic, à vitesse régulière.' }
S.coca_paste  = { game = 'pour', per = 2, min = 2, cap = 10, maxMistakes = 3, secPer = 7, pose = 'stand', anim = AN.pour, hand = HAND.bottle,
    extra = { reagents = { { label = 'Feuilles broyées', color = 'oil' }, { label = 'Solvant', color = 'solvent' } } },
    title = 'Préparer la pâte de coca', hint = 'Verse chaque produit dans l\'ordre et arrête-toi sur le trait.' }
S.coca_bag    = { game = 'scale', skin = 'powder', per = 2, min = 2, cap = 10, maxMistakes = 3, secPer = 10, pose = 'stand', anim = AN.table_pack, hand = HAND.spoon, extra = { grams = 1.0 },
    title = 'Peser et ensacher la cocaïne', hint = 'Maintiens le clic sur le pot pour verser. Vise le poids exact.' }
S.coca_refine = { game = 'heat', skin = 'refinery', per = 8, min = 8, cap = 40, maxMistakes = 3, secPer = 2.5, pose = 'stand', anim = AN.pour,
    title = 'Raffiner la pâte', hint = 'Maintiens le clic pour chauffer, relâche pour refroidir : reste dans la zone verte.' }
S.coca_pure   = { game = 'cut', skin = 'coke', per = 2, min = 4, cap = 12, maxMistakes = 3, secPer = 4, pose = 'stand', anim = AN.table_cut, hand = HAND.card, extra = { per = 2 },
    title = 'Finition : affiner la cocaïne', hint = 'Avec la carte, suis chaque trait d\'un bout à l\'autre sans dévier.' }
-- Crack
S.crack_mix   = { game = 'pour', per = 2, min = 2, cap = 10, maxMistakes = 3, secPer = 7, pose = 'stand', anim = AN.pour, hand = HAND.bottle,
    extra = { reagents = { { label = 'Pâte de coca', color = 'base' }, { label = 'Bicarbonate', color = 'soda' } } },
    title = 'Mélanger la base', hint = 'Ajoute chaque produit dans l\'ordre, jusqu\'au trait.' }
S.crack_cook  = { game = 'heat', skin = 'stove', per = 8, min = 8, cap = 40, maxMistakes = 3, secPer = 2.5, pose = 'stand', anim = AN.stove,
    title = 'Chauffer le mélange', hint = 'Maintiens le clic pour chauffer. Garde la température dans la zone verte.' }
S.crack_dry   = { game = 'hang', skin = 'crack', per = 2, min = 2, cap = 8, plusOne = true, maxMistakes = 3, secPer = 5, pose = 'stand', anim = AN.bulb,
    title = 'Faire sécher la pâte', hint = 'Étale chaque portion sur une case du plateau, puis règle la lampe.' }
S.crack_cut   = { game = 'cut', skin = 'crack', per = 3, min = 3, cap = 15, maxMistakes = 3, secPer = 4, pose = 'stand', anim = AN.table_cut, hand = HAND.knife, extra = { per = 3 },
    title = 'Découper en cailloux', hint = 'Pars d\'un point et suis le trait jusqu\'à l\'autre bout.' }
S.crack_bag   = { game = 'count', skin = 'rocks', per = 2, min = 2, cap = 10, maxMistakes = 3, secPer = 4, pose = 'stand', anim = AN.table_pack,
    title = 'Ensacher les cailloux', hint = 'Glisse les bons cailloux dans les cases, les miettes au rebut.' }
-- Méthamphétamine
S.meth_mix    = { game = 'pour', per = 2, min = 2, cap = 10, maxMistakes = 3, secPer = 7, pose = 'stand', anim = AN.pour, hand = HAND.bottle,
    extra = { reagents = { { label = 'Produits chimiques', color = 'base' }, { label = 'Acide', color = 'acid' } } },
    title = 'Préparer le mélange', hint = 'Verse dans l\'ordre et arrête-toi pile sur le trait.' }
S.meth_cook   = { game = 'heat', skin = 'reactor', per = 10, min = 10, cap = 45, maxMistakes = 3, secPer = 2.5, pose = 'stand', anim = AN.pour,
    title = 'Cuire le mélange', hint = 'Maintiens le clic (ou Espace) pour chauffer. Attention aux bouillonnements.' }
S.meth_cool   = { game = 'smash', per = 6, min = 6, cap = 25, maxMistakes = 4, secPer = 2.5, pose = 'stand', anim = AN.smash, hand = HAND.hammer,
    title = 'Casser les cristaux', hint = 'Frappe chaque fissure pendant qu\'elle brille.' }
S.meth_bag    = { game = 'scale', skin = 'crystal', per = 1, min = 1, cap = 5, maxMistakes = 3, secPer = 10, pose = 'stand', anim = AN.table_pack, hand = HAND.spoon, extra = { grams = 1.0 },
    title = 'Peser et ensacher la méth', hint = 'Maintiens le clic sur le pot pour verser les cristaux.' }
-- Ecstasy
S.xtc_base    = { game = 'pour', per = 2, min = 2, cap = 10, maxMistakes = 3, secPer = 7, pose = 'stand', anim = AN.pour, hand = HAND.bottle,
    extra = { reagents = { { label = 'Huile de safrole', color = 'oil' }, { label = 'Solvant', color = 'solvent' } } },
    title = 'Préparer la base', hint = 'Verse chaque produit jusqu\'au trait, dans l\'ordre.' }
S.xtc_powder  = { game = 'heat', skin = 'reactor', per = 9, min = 9, cap = 40, maxMistakes = 3, secPer = 2.5, pose = 'stand', anim = AN.pour,
    title = 'Synthèse de la poudre', hint = 'Garde la température du réacteur dans la zone verte.' }
S.xtc_press   = { game = 'press', per = 4, min = 4, cap = 20, maxMistakes = 3, secPer = 3, pose = 'stand', anim = AN.machine,
    title = 'Presser les comprimés', hint = 'Clique (ou Espace) quand l\'anneau touche le trait de la matrice.' }
S.xtc_pack    = { game = 'count', skin = 'pills', per = 4, min = 4, cap = 20, maxMistakes = 3, secPer = 3, pose = 'stand', anim = AN.table_pack,
    title = 'Mettre en blister', hint = 'Glisse les comprimés intacts dans les cases, les cassés au rebut.' }
-- Opiacés
S.opi_macerate= { game = 'pour', per = 2, min = 2, cap = 10, maxMistakes = 3, secPer = 7, pose = 'stand', anim = AN.pour, hand = HAND.bottle,
    extra = { reagents = { { label = 'Eau', color = 'water' }, { label = 'Résine', color = 'opium' } } },
    title = 'Macérer la résine', hint = 'Ajoute l\'eau puis la résine, chacune jusqu\'à son trait.' }
S.opi_filter  = { game = 'shake', skin = 'filter', per = 8, min = 8, cap = 35, maxMistakes = 3, secPer = 2, pose = 'stand', anim = AN.shaker,
    title = 'Filtrer la solution', hint = 'Maintiens le clic et secoue de gauche à droite, sans aller trop vite.' }
S.opi_powder  = { game = 'grind', skin = 'mortar', per = 3, min = 3, cap = 15, maxMistakes = 3, secPer = 4, pose = 'stand', anim = AN.table_cut,
    title = 'Réduire en poudre', hint = 'Écrase au mortier en tournant, à vitesse régulière.' }
S.opi_inject  = { game = 'syringe', per = 1, min = 2, cap = 10, maxMistakes = 3, secPer = 10, pose = 'stand', anim = AN.table_cut, hand = HAND.syringe,
    title = 'Préparer les seringues', hint = 'Tire le piston jusqu\'au trait, puis chasse les bulles.' }
S.opi_pills   = { game = 'count', skin = 'pills', per = 4, min = 4, cap = 20, maxMistakes = 3, secPer = 3, pose = 'stand', anim = AN.table_pack, extra = { color = 'oxy' },
    title = 'Conditionner les comprimés', hint = 'Glisse les comprimés intacts dans les cases, les cassés au rebut.' }
S.opi_syringe = { game = 'count', skin = 'syringe', per = 1, min = 2, cap = 10, maxMistakes = 3, secPer = 4, pose = 'stand', anim = AN.table_pack,
    title = 'Ranger les seringues', hint = 'Range les seringues pleines dans l\'étui, les abîmées au rebut.' }
-- Kétamine
S.keta_evap   = { game = 'heat', skin = 'evaporator', per = 9, min = 9, cap = 40, maxMistakes = 3, secPer = 2.5, pose = 'stand', anim = AN.pour,
    title = 'Évaporer le liquide', hint = 'Chauffe doucement : garde la température dans la zone verte.' }
S.keta_dry    = { game = 'hang', skin = 'keta', per = 2, min = 2, cap = 8, plusOne = true, maxMistakes = 3, secPer = 5, pose = 'stand', anim = AN.bulb,
    title = 'Sécher les cristaux', hint = 'Étale les cristaux sur le plateau, puis règle la lampe.' }
S.keta_grind  = { game = 'cut', skin = 'keta', per = 3, min = 3, cap = 15, maxMistakes = 3, secPer = 4, pose = 'stand', anim = AN.table_cut, hand = HAND.card, extra = { per = 3 },
    title = 'Écraser les cristaux', hint = 'Écrase à la carte en suivant chaque trait d\'un bout à l\'autre.' }
S.keta_bag    = { game = 'scale', skin = 'keta', per = 2, min = 2, cap = 10, maxMistakes = 3, secPer = 10, pose = 'stand', anim = AN.table_pack, hand = HAND.spoon, extra = { grams = 0.5 },
    title = 'Peser et ensacher', hint = 'Maintiens le clic sur le pot. Vise le demi-gramme.' }
-- Champignons
S.shroom_sort = { game = 'sort', per = 3, min = 3, cap = 15, maxMistakes = 3, secPer = 4, pose = 'stand', anim = AN.table_cut,
    title = 'Trier les champignons', hint = 'Bons champignons au panier, pourris au rebut. N\'en laisse pas filer.' }
S.shroom_dry  = { game = 'hang', skin = 'mush', per = 3, min = 3, cap = 9, plusOne = true, maxMistakes = 3, secPer = 5, pose = 'stand', anim = AN.bulb,
    title = 'Faire sécher', hint = 'Suspends chaque champignon, puis règle la ventilation.' }
S.shroom_bag  = { game = 'scale', skin = 'mush', per = 1, min = 1, cap = 5, maxMistakes = 3, secPer = 10, pose = 'stand', anim = AN.table_pack, extra = { grams = 2.0 },
    title = 'Peser et ensacher', hint = 'Maintiens le clic sur le bocal et vise le poids exact.' }

-- ---------------------------------------------------------------- récolte (champs placés avec l'admin_menu, pots)
-- Pas de mini-jeu : barre de progression avec une animation adaptée à la plante et un objet tenu.
Config.HarvestScenes = {
    weed   = { anim = AN.stand_weed, hand = HAND.scissors },   -- grands plants de cannabis : debout, on coupe les têtes
    pot    = { anim = AN.crouch_weed, hand = HAND.scissors },  -- plante en pot : accroupi
    coca   = { anim = AN.garden },                             -- buisson de coca : cueillette accroupie
    shroom = { anim = AN.pickup },                             -- champignons au sol : on se baisse pour ramasser
    chem   = { anim = AN.kneel },                              -- fûts : à genoux au robinet
}
function Config.HarvestSceneOf(siteType)
    siteType = tostring(siteType or '')
    if siteType:find('^weed_') then return Config.HarvestScenes.weed end
    return Config.HarvestScenes[siteType]
end
