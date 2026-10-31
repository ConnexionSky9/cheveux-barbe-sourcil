-- =====================================================================
--  POSTES DE FABRICATION (placés par les administrateurs : admin_menu › Gestion des drogues › Installations)
--  models : modèles possibles (le premier par défaut). Tous vérifiés dans le catalogue de l'éditeur
--  ou les données d'animations du serveur ; un modèle absent du jeu est ignoré sans bloquer.
--  anim : { scenario = '...' } ou { dict = '...', clip = '...', flag = 1 }
--  Les recettes de chaque poste sont dans config/recipes.lua (champ « station »).
-- =====================================================================
local A = {
    table   = { scenario = 'PROP_HUMAN_PARKING_METER' },
    bench   = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 1 },
    machine = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer', flag = 1 },
    cook    = { scenario = 'PROP_HUMAN_BBQ' },
    bulb    = { dict = 'amb@prop_human_movie_bulb@idle_a', clip = 'idle_b', flag = 1 },
    write   = { dict = 'missheistdockssetup1clipboard@base', clip = 'base', flag = 49 },
    kneel   = { scenario = 'CODE_HUMAN_MEDIC_KNEEL' },
}
Config.StationAnims = A

Config.Stations = {
    -- Cannabis
    weed_trim   = { label = 'Table de manucure (têtes)',   drug = 'weed',     icon = '✂️', models = { 'bkr_prop_weed_table_01a', 'prop_table_03' }, anim = A.table },
    weed_dry    = { label = 'Séchoir à cannabis',          drug = 'weed',     icon = '💨', models = { 'bkr_prop_weed_drying_02a', 'bkr_prop_weed_drying_01a', 'prop_worklight_03a' }, anim = A.bulb },
    weed_grind  = { label = 'Poste de préparation',        drug = 'weed',     icon = '🌿', models = { 'prop_table_06', 'prop_table_02' }, anim = A.bench },
    weed_roll   = { label = 'Table de roulage',            drug = 'weed',     icon = '🚬', models = { 'prop_table_01', 'prop_table_04' }, anim = A.table },
    weed_pack   = { label = 'Ensachage (cannabis)',        drug = 'weed',     icon = '🛍️', models = { 'prop_table_05', 'prop_weed_block_01' }, anim = A.write },
    -- Cocaïne
    coca_grind  = { label = 'Broyeur à feuilles',          drug = 'cocaine',  icon = '⚙️', models = { 'prop_tool_box_04', 'prop_barrel_01a' }, anim = A.machine },
    coca_process= { label = 'Table de transformation',     drug = 'cocaine',  icon = '🧪', models = { 'bkr_prop_coke_table01a', 'prop_table_08' }, anim = A.table },
    coca_pack   = { label = 'Ensachage (cocaïne)',         drug = 'cocaine',  icon = '🛍️', models = { 'prop_table_07', 'prop_coke_block_01' }, anim = A.write },
    coca_refine = { label = 'Cuve de raffinage',           drug = 'cocaine',  icon = '⚗️', models = { 'prop_barrel_02a', 'prop_barrel_02b' }, anim = A.cook },
    coca_finish = { label = 'Poste de finition (pure)',    drug = 'cocaine',  icon = '💠', models = { 'bkr_prop_coke_table01a', 'prop_table_08' }, anim = A.bulb },
    -- Crack
    crack_mix   = { label = 'Plan de mélange (crack)',     drug = 'crack',    icon = '🥣', models = { 'prop_table_04', 'prop_table_02' }, anim = A.bench },
    crack_cook  = { label = 'Réchaud (crack)',             drug = 'crack',    icon = '🔥', models = { 'prop_barrel_03a', 'prop_barrel_02b' }, anim = A.cook },
    crack_dry   = { label = 'Séchoir (crack)',             drug = 'crack',    icon = '💨', models = { 'prop_worklight_04a', 'prop_worklight_02a' }, anim = A.bulb },
    crack_cut   = { label = 'Planche de découpe (crack)',  drug = 'crack',    icon = '🔪', models = { 'prop_table_05', 'prop_table_07' }, anim = A.table },
    crack_pack  = { label = 'Ensachage (crack)',           drug = 'crack',    icon = '🛍️', models = { 'prop_table_02', 'prop_drug_package' }, anim = A.write },
    -- Méthamphétamine
    meth_prep   = { label = 'Bidons de préparation (méth)',drug = 'meth',     icon = '🛢️', models = { 'prop_barrel_01a', 'prop_barrel_exp_01a' }, anim = A.machine },
    meth_cook   = { label = 'Laboratoire de cuisson (méth)', drug = 'meth',   icon = '⚗️', models = { 'bkr_prop_meth_table01a' }, anim = A.cook },
    meth_cool   = { label = 'Bac de cristallisation',      drug = 'meth',     icon = '❄️', models = { 'prop_table_06', 'prop_tool_box_02' }, anim = A.bulb },
    meth_pack   = { label = 'Ensachage (méth)',            drug = 'meth',     icon = '🛍️', models = { 'prop_tool_box_01', 'prop_table_01' }, anim = A.write },
    -- Ecstasy
    xtc_prep    = { label = 'Paillasse de préparation (ecstasy)', drug = 'ecstasy', icon = '🧫', models = { 'prop_table_03', 'prop_table_08' }, anim = A.bench },
    xtc_synth   = { label = 'Réacteur (ecstasy)',          drug = 'ecstasy',  icon = '⚗️', models = { 'prop_barrel_02a', 'prop_barrel_01a' }, anim = A.cook },
    xtc_press   = { label = 'Presse à comprimés',          drug = 'ecstasy',  icon = '🗜️', models = { 'prop_tool_box_02', 'prop_tool_box_04' }, anim = A.machine },
    xtc_pack    = { label = 'Conditionnement (ecstasy)',   drug = 'ecstasy',  icon = '💊', models = { 'prop_table_01', 'prop_table_05' }, anim = A.write },
    -- Opiacés
    opi_prep    = { label = 'Bassine de macération (opiacés)', drug = 'opiates', icon = '🥣', models = { 'prop_barrel_03a', 'prop_barrel_01a' }, anim = A.bench },
    opi_refine  = { label = 'Filtration (opiacés)',        drug = 'opiates',  icon = '🧪', models = { 'prop_table_07', 'prop_table_04' }, anim = A.bulb },
    opi_finish  = { label = 'Finition (opiacés)',          drug = 'opiates',  icon = '💉', models = { 'prop_table_08', 'prop_table_06' }, anim = A.table },
    opi_pack    = { label = 'Conditionnement (opiacés)',   drug = 'opiates',  icon = '📦', models = { 'prop_tool_box_01', 'prop_table_02' }, anim = A.write },
    -- Kétamine
    keta_prep   = { label = 'Évaporateur (kétamine)',      drug = 'ketamine', icon = '♨️', models = { 'prop_barrel_02b', 'prop_barrel_03a' }, anim = A.cook },
    keta_dry    = { label = 'Lampe de séchage (kétamine)', drug = 'ketamine', icon = '💡', models = { 'prop_worklight_01a', 'prop_worklight_03b' }, anim = A.bulb },
    keta_grind  = { label = 'Broyeur (kétamine)',          drug = 'ketamine', icon = '⚙️', models = { 'prop_tool_box_04', 'prop_tool_box_02' }, anim = A.machine },
    keta_pack   = { label = 'Ensachage (kétamine)',        drug = 'ketamine', icon = '🛍️', models = { 'prop_table_05', 'prop_table_01' }, anim = A.write },
    -- Champignons
    shroom_sort = { label = 'Table de tri (champignons)',  drug = 'mushrooms', icon = '🍄', models = { 'prop_table_04', 'prop_table_03' }, anim = A.table },
    shroom_dry  = { label = 'Séchoir (champignons)',       drug = 'mushrooms', icon = '💡', models = { 'prop_worklight_03a', 'prop_worklight_04a' }, anim = A.bulb },
    shroom_pack = { label = 'Ensachage (champignons)',     drug = 'mushrooms', icon = '🛍️', models = { 'prop_table_06', 'prop_table_02' }, anim = A.write },
    shroom_prep = { label = 'Plan de travail (pâte à gâteau)', drug = 'mushrooms', icon = '🥣', models = { 'prop_table_04', 'prop_table_02', 'prop_table_06' }, anim = A.bench },
    shroom_oven = { label = 'Four (gâteaux aux champignons)', drug = 'mushrooms', icon = '🎂', models = { 'prop_cooker_03', 'prop_bbq_5', 'prop_table_04' }, anim = A.cook },
}

-- PNJ (vente et fournisseur) : modèles de personnages
Config.NpcSites = {
    buyer    = { label = 'Acheteur de drogue', icon = '💰', models = { 'g_m_y_famca_01', 'a_m_y_hipster_01', 'g_m_y_ballaeast_01', 'a_m_m_tramp_01' }, scenario = 'WORLD_HUMAN_DRUG_DEALER' },
    supplier = { label = 'Fournisseur de matériel', icon = '🧰', models = { 'a_m_m_mexlabor_01', 'a_m_y_methhead_01', 's_m_m_chemsec_01' }, scenario = 'WORLD_HUMAN_CLIPBOARD' },
}
