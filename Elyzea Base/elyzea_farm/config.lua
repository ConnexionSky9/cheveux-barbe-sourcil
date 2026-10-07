Config = {}

-- =====================================================================
--  MÉTIERS DE FARM
--  Un métier de farm se fait EN PLUS du métier principal (on peut être
--  concessionnaire ET bûcheron). On le commence et on l'arrête en parlant
--  au PNJ posé avec l'éditeur de map (rôle « 🪓 Métier de farm »).
--  Les valeurs ci-dessous sont celles de départ : tout se règle ensuite
--  dans admin_menu › Métiers › Métiers de farm (temps, quantités, prix,
--  zones, tenue…), sans redémarrage.
-- =====================================================================
Config.Farms = {
    bucheron = {
        label = 'Bûcheron',
        icon = '🪓',
        item = 'buche_bois',              -- objet obtenu (déclaré dans elyzea_inventory)
        action = 'Couper l\'arbre',       -- texte de l'invite (touche ALT)
        progress = 'Coupe du bois…',
        -- Animation et outil en main pendant la coupe
        anim = { dict = 'melee@hatchet@streamed_core', clip = 'plyr_front_takedown_b', flag = 1 },
        prop = { model = 'w_me_hatchet', bone = 57005, pos = vec3(0.1, -0.02, -0.02), rot = vec3(-80.0, 0.0, 0.0) },
        -- Arbres reconnus (objets de la carte du jeu). On peut aussi poser des arbres à la main dans le menu admin.
        targetModels = {
            'prop_tree_pine_01', 'prop_tree_pine_02', 'prop_tree_cedar_01', 'prop_tree_cedar_02', 'prop_tree_cedar_03',
            'prop_tree_cedar_04', 'prop_tree_cedar_s_01', 'prop_tree_cedar_s_02', 'prop_tree_cedar_s_04', 'prop_tree_cedar_s_05',
            'prop_tree_cedar_s_06', 'prop_tree_oak_01', 'prop_tree_birch_01', 'prop_tree_birch_02', 'prop_tree_birch_03',
            'prop_tree_birch_03b', 'prop_tree_birch_04', 'prop_tree_birch_05', 'prop_tree_maple_02', 'prop_tree_maple_03',
            'prop_tree_eucalip_01', 'prop_tree_olive_01', 'prop_tree_cypress_01', 'prop_tree_jacada_01', 'prop_tree_jacada_02',
            'prop_tree_mquite_01', 'prop_tree_lficus_02', 'prop_tree_lficus_03', 'prop_tree_lficus_05', 'prop_tree_lficus_06',
            'prop_tree_fallen_pine_01', 'prop_s_pine_dead_01', 'prop_w_r_cedar_01', 'prop_w_r_cedar_dead',
            'test_tree_cedar_trunk_001', 'test_tree_forest_trunk_01', 'test_tree_forest_trunk_04', 'test_tree_forest_trunk_base_01',
        },
        targetDistance = 3.0,             -- distance maximum de l'arbre

        -- Valeurs de départ (réglables dans le menu admin)
        defaults = {
            enabled = true,
            time = 8,                     -- secondes pour couper
            minAmount = 1, maxAmount = 2, -- bûches obtenues à chaque coupe
            sellPrice = 25,               -- prix de revente d'une bûche au PNJ
            payWith = 'cash',             -- revente payée en 'cash' (liquide) ou 'bank' (banque)
            requireTarget = true,         -- il faut être devant un arbre (sinon : n'importe où dans la zone)
            requireTool = false,          -- il faut avoir l'outil dans l'inventaire
            tool = 'WEAPON_HATCHET',
            maxPerHour = 0,               -- bûches maximum par heure et par joueur (0 = illimité)
            outfit = {                    -- tenue de bûcheron (remplaçable par « Copier ma tenue » dans le menu admin)
                male = { c = { ['11'] = { 43, 0 }, ['8'] = { 15, 0 }, ['3'] = { 11, 0 }, ['4'] = { 7, 0 }, ['6'] = { 25, 0 } },
                         p = { ['0'] = { 77, 0 } } },
                female = { c = { ['11'] = { 49, 0 }, ['8'] = { 14, 0 }, ['3'] = { 9, 0 }, ['4'] = { 30, 0 }, ['6'] = { 25, 0 } },
                           p = { ['0'] = { 76, 0 } } },
            },
            zones = {},                   -- zones de travail (posées dans le menu admin)
            points = {},                  -- arbres posés à la main (facultatif)
        },
    },
}

-- Touche pour couper : ALT (INPUT_CHARACTER_WHEEL)
Config.ActionControl = 19
Config.ActionKeyLabel = 'ALT'

-- Distance maximum du PNJ pour commencer / arrêter / vendre
Config.NpcDistance = 4.0
