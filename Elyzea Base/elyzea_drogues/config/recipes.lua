-- =====================================================================
--  RECETTES (étapes de fabrication) — recettes fictives de jeu
--  Champs : label, drug, step (n° d'étape affiché), station (config/stations.lua),
--           inputs / outputs = { { 'objet', quantité } }, duration (s), loss (% de chance de perdre
--           chaque unité produite), enabled.
--  Le moteur (server/crafting.lua) est le même pour toutes les drogues : ajouter une étape = ajouter une ligne.
--  Tout se modifie aussi dans admin_menu › Gestion des drogues › Recettes (gardé en base).
--  La récolte (étape 1 de cannabis, coca, champignons) est dans config/harvest.lua et la culture.
-- =====================================================================
Config.Recipes = {}
local R = Config.Recipes

-- ------------------------------------------------------------ Cannabis (une chaîne par variété)
-- 1 Récolter (plante) · 2 Effeuiller assis (têtes fraîches) · 3 Sécher (désactivable par variété) · 4 Préparer (désactivable) · 5 Rouler · 6 Ensacher
for id, v in pairs(Config.Varieties) do
    R['weed_trim_' .. id] = { label = ('Têtes de %s'):format(v.label), drug = 'weed', variety = id, step = 2, station = 'weed_trim',
        inputs = { { v.leaf, 3 } }, outputs = { { v.bud, 2 } }, duration = 8, loss = 0, trimStep = true }
    -- Séchage : têtes fraîches → têtes séchées (1 pour 1). La manucure donne des têtes fraîches quand le séchage est actif.
    R['weed_dry_' .. id] = { label = ('Sécher les têtes de %s'):format(v.label), drug = 'weed', variety = id, step = 3, station = 'weed_dry',
        inputs = { { v.wet, 1 } }, outputs = { { v.bud, 1 } }, duration = 6, loss = 0, dryStep = true }
    R['weed_grind_' .. id] = { label = ('Préparer la %s'):format(v.label), drug = 'weed', variety = id, step = 4, station = 'weed_grind',
        inputs = { { v.bud, 1 } }, outputs = { { v.ground, 2 } }, duration = 6, loss = 0, prepStep = true }
    -- Rouler : avec le cannabis préparé, ou directement avec les têtes si la préparation est désactivée
    R['weed_roll_' .. id] = { label = ('Rouler un joint de %s'):format(v.label), drug = 'weed', variety = id, step = 5, station = 'weed_roll',
        inputs = { { v.ground, 1 }, { 'rolling_paper', 1 } }, outputs = { { v.joint, 1 } }, duration = 5, loss = 0, rollStep = true }
    R['weed_pack_' .. id] = { label = ('Pochon de %s'):format(v.label), drug = 'weed', variety = id, step = 6, station = 'weed_pack',
        inputs = { { v.bud, 2 }, { 'drug_bag', 1 } }, outputs = { { v.pouch, 1 } }, duration = 4, loss = 0 }
end

-- ------------------------------------------------------------ Cocaïne (6 étapes, basique + améliorée)
-- 1 Récolte (coca) · 2 Broyage · 3 Préparation · 4 Ensachage (basique) · 5 Transformation avancée · 6 Finition (pure)
R.coca_grind   = { label = 'Broyer les feuilles de coca', drug = 'cocaine', step = 2, station = 'coca_grind',
    inputs = { { 'coca_leaf', 4 } }, outputs = { { 'coca_ground', 2 } }, duration = 8, loss = 0 }
R.coca_paste   = { label = 'Préparer la pâte de coca', drug = 'cocaine', step = 3, station = 'coca_process',
    inputs = { { 'coca_ground', 2 }, { 'drg_solvent', 1 } }, outputs = { { 'coca_paste', 1 } }, duration = 12, loss = 5 }
R.coca_bag     = { label = 'Ensacher la cocaïne', drug = 'cocaine', step = 4, station = 'coca_pack',
    inputs = { { 'coca_paste', 1 }, { 'drug_bag', 2 } }, outputs = { { 'cokebaggy', 2 } }, duration = 6, loss = 0 }
R.coca_refine  = { label = 'Raffiner la pâte (avancé)', drug = 'cocaine', step = 5, station = 'coca_refine',
    inputs = { { 'coca_paste', 2 }, { 'drg_reagent', 1 } }, outputs = { { 'coca_refined', 1 } }, duration = 15, loss = 10 }
R.coca_pure    = { label = 'Finition : cocaïne pure', drug = 'cocaine', step = 6, station = 'coca_finish',
    inputs = { { 'coca_refined', 1 }, { 'drug_bag', 2 } }, outputs = { { 'coke_premium', 2 } }, duration = 10, loss = 0 }

-- ------------------------------------------------------------ Crack (5 étapes)
R.crack_mix    = { label = 'Mélanger la base (crack)', drug = 'crack', step = 1, station = 'crack_mix',
    inputs = { { 'coca_paste', 1 }, { 'baking_soda', 1 } }, outputs = { { 'crack_mix', 1 } }, duration = 8, loss = 0 }
R.crack_cook   = { label = 'Chauffer le mélange', drug = 'crack', step = 2, station = 'crack_cook',
    inputs = { { 'crack_mix', 1 }, { 'water', 1 } }, outputs = { { 'crack_paste', 1 } }, duration = 12, loss = 5 }
R.crack_dry    = { label = 'Faire sécher la pâte', drug = 'crack', step = 3, station = 'crack_dry',
    inputs = { { 'crack_paste', 1 } }, outputs = { { 'crack_block', 1 } }, duration = 10, loss = 0 }
R.crack_cut    = { label = 'Découper en cailloux', drug = 'crack', step = 4, station = 'crack_cut',
    inputs = { { 'crack_block', 1 } }, outputs = { { 'crack_rocks', 4 } }, duration = 6, loss = 0 }
R.crack_bag    = { label = 'Ensacher le crack', drug = 'crack', step = 5, station = 'crack_pack',
    inputs = { { 'crack_rocks', 2 }, { 'drug_bag', 1 } }, outputs = { { 'crack_baggy', 1 } }, duration = 4, loss = 0 }

-- ------------------------------------------------------------ Méthamphétamine (5 étapes)
-- 1 Ingrédients (produits chimiques récoltés + acide acheté au fournisseur)
R.meth_mix     = { label = 'Préparer le mélange (méth)', drug = 'meth', step = 2, station = 'meth_prep',
    inputs = { { 'meth_chemicals', 2 }, { 'drg_acid', 1 } }, outputs = { { 'meth_mix', 1 } }, duration = 10, loss = 0 }
R.meth_cook    = { label = 'Cuire le mélange', drug = 'meth', step = 3, station = 'meth_cook',
    inputs = { { 'meth_mix', 1 } }, outputs = { { 'meth_liquid', 1 } }, duration = 15, loss = 8 }
R.meth_cool    = { label = 'Cristalliser', drug = 'meth', step = 4, station = 'meth_cool',
    inputs = { { 'meth_liquid', 1 } }, outputs = { { 'meth_crystal', 3 } }, duration = 12, loss = 0 }
R.meth_bag     = { label = 'Ensacher la méth', drug = 'meth', step = 5, station = 'meth_pack',
    inputs = { { 'meth_crystal', 1 }, { 'drug_bag', 1 } }, outputs = { { 'meth', 1 } }, duration = 4, loss = 0 }

-- ------------------------------------------------------------ Ecstasy (5 étapes, 3 comprimés)
-- 1 Ingrédients (huile achetée au fournisseur)
R.xtc_base     = { label = 'Préparer la base (ecstasy)', drug = 'ecstasy', step = 2, station = 'xtc_prep',
    inputs = { { 'drg_safrole', 1 }, { 'drg_solvent', 1 } }, outputs = { { 'xtc_base', 1 } }, duration = 10, loss = 0 }
R.xtc_powder   = { label = 'Synthèse de la poudre', drug = 'ecstasy', step = 3, station = 'xtc_synth',
    inputs = { { 'xtc_base', 1 } }, outputs = { { 'xtc_powder', 2 } }, duration = 14, loss = 5 }
R.xtc_press_pink   = { label = 'Presser : comprimés roses', drug = 'ecstasy', step = 4, station = 'xtc_press',
    inputs = { { 'xtc_powder', 1 }, { 'drg_dye_pink', 1 } }, outputs = { { 'xtc_tabs_pink', 1 } }, duration = 8, loss = 0 }
R.xtc_press_blue   = { label = 'Presser : comprimés bleus', drug = 'ecstasy', step = 4, station = 'xtc_press',
    inputs = { { 'xtc_powder', 1 }, { 'drg_dye_blue', 1 } }, outputs = { { 'xtc_tabs_blue', 1 } }, duration = 8, loss = 0 }
R.xtc_press_yellow = { label = 'Presser : comprimés jaunes', drug = 'ecstasy', step = 4, station = 'xtc_press',
    inputs = { { 'xtc_powder', 1 }, { 'drg_dye_yellow', 1 } }, outputs = { { 'xtc_tabs_yellow', 1 } }, duration = 8, loss = 0 }
R.xtc_pack_pink    = { label = 'Conditionner : ecstasy rose', drug = 'ecstasy', step = 5, station = 'xtc_pack',
    inputs = { { 'xtc_tabs_pink', 1 }, { 'drug_bag', 1 } }, outputs = { { 'xtc_pink', 4 } }, duration = 4, loss = 0 }
R.xtc_pack_blue    = { label = 'Conditionner : ecstasy bleue', drug = 'ecstasy', step = 5, station = 'xtc_pack',
    inputs = { { 'xtc_tabs_blue', 1 }, { 'drug_bag', 1 } }, outputs = { { 'xtc_blue', 4 } }, duration = 4, loss = 0 }
R.xtc_pack_yellow  = { label = 'Conditionner : ecstasy jaune', drug = 'ecstasy', step = 5, station = 'xtc_pack',
    inputs = { { 'xtc_tabs_yellow', 1 }, { 'drug_bag', 1 } }, outputs = { { 'xtc_yellow', 4 } }, duration = 4, loss = 0 }

-- ------------------------------------------------------------ Opiacés (5 étapes, 2 produits)
-- 1 Matière première (résine achetée au fournisseur)
R.opi_macerate = { label = 'Macérer la résine', drug = 'opiates', step = 2, station = 'opi_prep',
    inputs = { { 'drg_opium_raw', 1 }, { 'water', 1 } }, outputs = { { 'opi_solution', 1 } }, duration = 10, loss = 0 }
R.opi_filter   = { label = 'Filtrer la solution', drug = 'opiates', step = 3, station = 'opi_refine',
    inputs = { { 'opi_solution', 1 }, { 'drg_solvent', 1 } }, outputs = { { 'opi_base', 2 } }, duration = 12, loss = 5 }
R.opi_powder   = { label = 'Finition : poudre pour comprimés', drug = 'opiates', step = 4, station = 'opi_finish',
    inputs = { { 'opi_base', 1 } }, outputs = { { 'opi_powder', 1 } }, duration = 8, loss = 0 }
R.opi_inject   = { label = 'Finition : préparation injectable', drug = 'opiates', step = 4, station = 'opi_finish',
    inputs = { { 'opi_base', 1 }, { 'drg_syringe_empty', 2 } }, outputs = { { 'opi_syringe_raw', 2 } }, duration = 8, loss = 0 }
R.opi_pills    = { label = 'Conditionner les comprimés', drug = 'opiates', step = 5, station = 'opi_pack',
    inputs = { { 'opi_powder', 1 }, { 'drug_bag', 1 } }, outputs = { { 'oxy', 4 } }, duration = 5, loss = 0 }
R.opi_syringe  = { label = 'Conditionner les seringues', drug = 'opiates', step = 5, station = 'opi_pack',
    inputs = { { 'opi_syringe_raw', 1 } }, outputs = { { 'opi_syringe', 1 } }, duration = 3, loss = 0 }

-- ------------------------------------------------------------ Kétamine (5 étapes)
-- 1 Ingrédient (flacon acheté au fournisseur)
R.keta_evap    = { label = 'Évaporer le liquide', drug = 'ketamine', step = 2, station = 'keta_prep',
    inputs = { { 'drg_keta_liquid', 1 } }, outputs = { { 'keta_wet', 1 } }, duration = 12, loss = 0 }
R.keta_dry     = { label = 'Sécher les cristaux', drug = 'ketamine', step = 3, station = 'keta_dry',
    inputs = { { 'keta_wet', 1 } }, outputs = { { 'keta_crystal', 1 } }, duration = 10, loss = 5 }
R.keta_grind   = { label = 'Broyer en poudre', drug = 'ketamine', step = 4, station = 'keta_grind',
    inputs = { { 'keta_crystal', 1 } }, outputs = { { 'keta_powder', 2 } }, duration = 6, loss = 0 }
R.keta_bag     = { label = 'Ensacher la kétamine', drug = 'ketamine', step = 5, station = 'keta_pack',
    inputs = { { 'keta_powder', 1 }, { 'drug_bag', 1 } }, outputs = { { 'ketamine', 2 } }, duration = 4, loss = 0 }

-- ------------------------------------------------------------ Champignons (6 étapes)
-- 1-2 Récolte au sol avec ramassage (config/harvest.lua) · 3 champignon frais · 4 Tri · 5 Séchage · 6 Sachet
R.shroom_sort  = { label = 'Trier les champignons', drug = 'mushrooms', step = 4, station = 'shroom_sort',
    inputs = { { 'magic_mushroom', 3 } }, outputs = { { 'shroom_sorted', 2 } }, duration = 6, loss = 0 }
R.shroom_dry   = { label = 'Faire sécher', drug = 'mushrooms', step = 5, station = 'shroom_dry',
    inputs = { { 'shroom_sorted', 1 } }, outputs = { { 'dried_mushroom', 1 } }, duration = 10, loss = 0 }
R.shroom_bag   = { label = 'Ensacher les champignons séchés', drug = 'mushrooms', step = 6, station = 'shroom_pack',
    inputs = { { 'dried_mushroom', 3 }, { 'drug_bag', 1 } }, outputs = { { 'shroom_bag', 1 } }, duration = 4, loss = 0 }
-- Gâteaux aux champignons : 7 pâte au plan de travail (doser chaque ingrédient) · 8 cuisson au four (régler la température)
-- Plus le gâteau est gros, plus il faut d'ingrédients et plus l'effet est long et fort (config/products.lua, réglable dans le menu)
for k, c in pairs(Config.CakeSizes) do   -- tailles et quantités : config/cakes.lua
    R['shroom_batter_' .. k] = { label = ('Pâte à %s'):format(c.label), drug = 'mushrooms', step = 7, station = 'shroom_prep',
        inputs = { { 'cake_flour', c.flour }, { 'cake_sugar', c.sugar }, { 'cake_yeast', c.yeast }, { 'cake_milk', c.milk }, { 'dried_mushroom', c.shroom } },
        outputs = { { 'shroom_batter_' .. k, 1 } }, duration = c.prep, loss = 0 }
    R['shroom_cake_' .. k] = { label = ('Cuire le %s'):format(c.label), drug = 'mushrooms', step = 8, station = 'shroom_oven',
        inputs = { { 'shroom_batter_' .. k, 1 } }, outputs = { { 'shroom_cake_' .. k, 1 } }, duration = c.bake, loss = 0 }
end

-- Fabrication en série : jusqu'à X fois la recette d'affilée (une seule barre de progression)
Config.MaxBatch = 5
