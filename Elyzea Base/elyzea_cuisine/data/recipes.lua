-- =====================================================================
--  ELYZEA CUISINE · 80 RECETTES (fichier unique à modifier)
--  Lu par elyzea_cuisine (client : objets en main + animations) ET par elyzea_inventory
--  (création des 80 objets). Aucune fonction ici : seulement des données.
--
--  Une recette : { id, cat, kind, label, desc, hunger, thirst, weight, time, emoji, anim, props, fb }
--    hunger / thirst : points rendus sur 100 (comme les objets existants : burger = 20, eau = 25)
--    time            : durée de consommation (ms)
--    anim            : geste (voir Anims) · props : objets tenus (voir Props), dans l'ordre
--    fb              : repli si un objet / une animation n'existe pas chez le joueur (toujours du GTA de base)
--
--  Origine de chaque objet / geste (champ src) :
--    'rpemotes'  : objet du jeu de base utilisé tel quel par un emote de rpemotes-reborn (même os, même position)
--    'custom'    : objet personnalisé fourni par rpemotes-reborn (dossier stream) : il faut rpemotes démarré
--    'gta'       : objet du jeu de base, nom non vérifié ici → contrôlé en jeu au moment de manger (repli sinon)
--    pos = 'estime' : position réglée à la main (pas reprise d'un emote) : à ajuster si besoin (/cuisine_essai)
-- =====================================================================
local D = {}

-- ---------------------------------------------------------------------
-- Gestes (animations). flag 49 = haut du corps en boucle, on peut marcher.
-- ---------------------------------------------------------------------
D.Anims = {
    bite    = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger', flag = 49, src = 'rpemotes' },      -- croquer (tenu en main)
    bite_fp = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger_fp', flag = 49, src = 'rpemotes' },   -- croquer, variante (déjà utilisée par l'inventaire)
    plate   = { dict = 'anim@scripted@island@special_peds@pavel@hs4_pavel_ig5_caviar_p1', clip = 'base_idle', flag = 49, src = 'rpemotes' }, -- manger à l'assiette / au bol avec un couvert
    snack   = { dict = 'mp_player_inteat@pnq', clip = 'loop', flag = 49, src = 'rpemotes' },          -- piocher dans un cornet / une boîte
    bottle  = { dict = 'mp_player_intdrink', clip = 'loop_bottle', flag = 49, src = 'rpemotes' },     -- boire à la bouteille / au mug
    cup     = { dict = 'amb@world_human_drinking@coffee@male@idle_a', clip = 'idle_c', flag = 49, src = 'rpemotes' }, -- boire une tasse / un verre / un gobelet
    straw   = { dict = 'smo@milkshake_idle', clip = 'milkshake_idle_clip', flag = 49, src = 'custom' }, -- siroter à la paille (animation de rpemotes)
}

-- ---------------------------------------------------------------------
-- Objets tenus. bone 60309 = main gauche, 28422 / 18905 = main droite (os GTA).
-- pos / rot = position et rotation par rapport à l'os.
-- ---------------------------------------------------------------------
D.Props = {
    -- Assiette, bol, coupelle + couvert (geste « plate »)
    plate        = { model = 'prop_cs_plate_01', bone = 60309, pos = { 0.0, 0.0, 0.0 }, rot = { 0.0, 0.0, 0.0 }, src = 'rpemotes', note = 'emote « dinner »' },
    spoon        = { model = 'h4_prop_h4_caviar_spoon_01a', bone = 28422, pos = { 0.0, 0.0, 0.0 }, rot = { 0.0, 0.0, 0.0 }, src = 'rpemotes', note = 'emote « dinner » (aucune fourchette dans GTA : cuillère)' },
    ramekin      = { model = 'h4_prop_h4_caviar_tin_01a', bone = 60309, pos = { 0.0, 0.03, 0.01 }, rot = { 0.0, 0.0, 0.0 }, src = 'rpemotes', note = 'emote « beans » (petit pot rond)' },
    bowl_noodle  = { model = 'scully_pho', bone = 60309, pos = { 0.0, 0.03, 0.01 }, rot = { 0.0, 0.0, 0.0 }, src = 'custom', note = 'emote « pho » (bol de nouilles)' },
    spoon_noodle = { model = 'scully_spoon_pho', bone = 28422, pos = { 0.0, 0.0, 0.0 }, rot = { 0.0, 0.0, 0.0 }, src = 'custom', note = 'emote « pho »' },
    dessert_cup  = { model = 'pata_christmasfood7', bone = 60309, pos = { -0.046, 0.0, -0.03 }, rot = { 0.0, 0.0, -50.0 }, src = 'custom', note = 'emote « xmasic » (coupelle)' },
    dessert_spoon = { model = 'h4_prop_h4_coke_spoon_01', bone = 28422, pos = { 0.0, 0.0, 0.0 }, rot = { 0.0, 20.0, 0.0 }, src = 'rpemotes', note = 'emote « xmasic »' },
    fork         = { model = 'prop_cs_fork', bone = 28422, pos = { 0.0, 0.0, 0.0 }, rot = { 0.0, 0.0, 0.0 }, src = 'gta', posSrc = 'estime', note = 'fourchette (jeu de base), tenue comme la cuillère de l\'emote « dinner »' },
    on_plate_steak = { model = 'prop_cs_steak', bone = 60309, pos = { 0.0, 0.0, 0.025 }, rot = { 0.0, 0.0, 0.0 }, src = 'gta', posSrc = 'estime', note = 'viande posée sur l\'assiette (même os que l\'assiette)' },
    on_plate_fish  = { model = 'prop_fish_slice_01', bone = 60309, pos = { 0.0, 0.0, 0.02 }, rot = { 0.0, 0.0, 0.0 }, src = 'gta', posSrc = 'estime', note = 'tranches de poisson posées sur l\'assiette (sushis, sashimis)' },
    noodle_box   = { model = 'prop_ff_noodle_01', bone = 60309, pos = { 0.0, 0.0, 0.0 }, rot = { 0.0, 0.0, 0.0 }, src = 'gta', posSrc = 'estime', note = 'boîte de nouilles à emporter (jeu de base)' },

    -- Tenu en main (geste « bite »)
    burger       = { model = 'prop_cs_burger_01', bone = 60309, pos = { 0.0, 0.0, -0.02 }, rot = { 30.0, 0.0, 0.0 }, src = 'rpemotes', note = 'emote « burger »' },
    burger_bs    = { model = 'prop_food_bs_burger2', bone = 60309, pos = { 0.0, 0.0, -0.02 }, rot = { 30.0, 0.0, 0.0 }, src = 'gta', posSrc = 'estime', note = 'burger du Burger Shot' },
    burger_cb    = { model = 'prop_food_cb_burg01', bone = 60309, pos = { 0.0, 0.0, -0.02 }, rot = { 30.0, 0.0, 0.0 }, src = 'gta', posSrc = 'estime', note = 'burger du Cluckin\' Bell (poulet)' },
    burger_b2    = { model = 'prop_food_burg2', bone = 60309, pos = { 0.0, 0.0, -0.02 }, rot = { 30.0, 0.0, 0.0 }, src = 'gta', posSrc = 'estime', note = 'burger emballé' },
    hotdog       = { model = 'prop_cs_hotdog_02', bone = 60309, pos = { -0.03, 0.01, -0.01 }, rot = { 95.1071, 94.7001, -66.9179 }, src = 'rpemotes', note = 'emote « hotdog »' },
    taco         = { model = 'prop_taco_01', bone = 60309, pos = { -0.017, 0.007, -0.021 }, rot = { 107.9846, -105.0251, 55.7779 }, src = 'rpemotes', note = 'emote « taco »' },
    sandwich     = { model = 'prop_sandwich_01', bone = 18905, pos = { 0.13, 0.05, 0.02 }, rot = { -50.0, 16.0, 60.0 }, src = 'rpemotes', note = 'emote « sandwich »' },
    bread        = { model = 'p_ing_bagel_01', bone = 18905, pos = { 0.14, 0.05, 0.03 }, rot = { 145.3975, -53.8984, 4.8412 }, src = 'rpemotes', note = 'emote « bagel »' },
    donut        = { model = 'prop_amb_donut', bone = 18905, pos = { 0.13, 0.05, 0.02 }, rot = { -50.0, 16.0, 60.0 }, src = 'rpemotes', note = 'emote « donut »' },
    chocobar     = { model = 'prop_choc_ego', bone = 60309, pos = { 0.0, 0.0, 0.0 }, rot = { 0.0, 0.0, 0.0 }, src = 'rpemotes', note = 'emote « egobar » (forme allongée)' },
    fish_slice   = { model = 'prop_fish_slice_01', bone = 60309, pos = { 0.0, 0.0, -0.02 }, rot = { 0.0, 0.0, 0.0 }, src = 'rpemotes', posSrc = 'estime', note = 'emote « bbqf » (tranche de poisson)' },
    pizza_jalap  = { model = 'knjgh_pizzaslice1', bone = 60309, pos = { 0.05, -0.02, -0.02 }, rot = { 73.6928, -66.7427, 68.3677 }, src = 'custom', note = 'emote « pizzas »' },
    pizza_pesto  = { model = 'knjgh_pizzaslice2', bone = 60309, pos = { 0.05, -0.02, -0.02 }, rot = { 73.6928, -66.7427, 68.3677 }, src = 'custom', note = 'emote « pizzas2 »' },
    pizza_mush   = { model = 'knjgh_pizzaslice3', bone = 60309, pos = { 0.05, -0.02, -0.02 }, rot = { 73.6928, -66.7427, 68.3677 }, src = 'custom', note = 'emote « pizzas3 »' },
    pizza_marg   = { model = 'knjgh_pizzaslice4', bone = 60309, pos = { 0.05, -0.02, -0.02 }, rot = { 73.6928, -66.7427, 68.3677 }, src = 'custom', note = 'emote « pizzas4 »' },
    pizza_slice  = { model = 'ng_proc_pizza01a', bone = 60309, pos = { 0.05, -0.02, -0.02 }, rot = { 73.6928, -66.7427, 68.3677 }, src = 'gta', posSrc = 'estime', note = 'part de pizza du jeu de base (repli des pizzas de rpemotes)' },
    pizza_pepp   = { model = 'knjgh_pizzaslice5', bone = 60309, pos = { 0.05, -0.02, -0.02 }, rot = { 73.6928, -66.7427, 68.3677 }, src = 'custom', note = 'emote « pizzas5 »' },
    icecream     = { model = 'bzzz_icecream_pistachio', bone = 18905, pos = { 0.14, 0.03, 0.01 }, rot = { 85.0, 70.0, -203.0 }, src = 'custom', note = 'emote « icecreamd » (cornet)' },
    croissant    = { model = 'bzzz_foodpack_croissant001', bone = 60309, pos = { 0.0, 0.0, -0.01 }, rot = { 0.0, 0.0, 90.0 }, src = 'custom', note = 'emote « croissant » (pâtisserie en croissant)' },
    cake_slice   = { model = 'bzzz_food_dessert_a', bone = 18905, pos = { 0.15, 0.03, 0.03 }, rot = { -42.0, -36.0, 0.0 }, src = 'custom', note = 'emote « desert »' },
    cupcake      = { model = 'pata_christmasfood6', bone = 60309, pos = { 0.01, 0.02, -0.01 }, rot = { -170.1788, 87.6716, 30.054 }, src = 'custom', note = 'emote « xmascc »' },
    macaron      = { model = 'bzzz_food_xmas_macaroon_a', bone = 18905, pos = { 0.15, 0.07, 0.0 }, rot = { 38.0, 7.0, 7.0 }, src = 'custom', note = 'emote « macaroon » (petite boule)' },
    skewer       = { model = 'bzzz_camp_food_kebab', bone = 18905, pos = { 0.14, 0.02, 0.01 }, rot = { -24.0, -80.0, 9.0 }, src = 'custom', note = 'emote « meat2 » (brochette)' },

    -- Cornets / boîtes (geste « snack »)
    candy_bag    = { model = 'prop_candy_pqs', bone = 60309, pos = { -0.03, 0.018, 0.0 }, rot = { 180.0, 180.0, -88.099 }, src = 'rpemotes', note = 'emote « candy »' },
    fries        = { model = 'prop_food_bs_chips', bone = 60309, pos = { -0.03, 0.018, 0.0 }, rot = { 0.0, 0.0, 0.0 }, src = 'gta', posSrc = 'estime', note = 'cornet de frites du Burger Shot' },
    nuggets_box  = { model = 'prop_food_cb_nugets', bone = 60309, pos = { -0.03, 0.018, 0.0 }, rot = { 0.0, 0.0, 0.0 }, src = 'gta', posSrc = 'estime', note = 'boîte du Cluckin\' Bell' },
    crisps       = { model = 'prop_cs_crisps_01', bone = 60309, pos = { -0.03, 0.018, 0.0 }, rot = { 0.0, 0.0, 0.0 }, src = 'gta', posSrc = 'estime', note = 'paquet de chips' },
    apple        = { model = 'sf_prop_sf_apple_01a', bone = 18905, pos = { 0.12, 0.04, 0.02 }, rot = { -50.0, 16.0, 60.0 }, src = 'gta', posSrc = 'estime', note = 'pomme (tenue comme le donut)' },
    chocobar2    = { model = 'prop_choc_meto', bone = 60309, pos = { 0.0, 0.0, 0.0 }, rot = { 0.0, 0.0, 0.0 }, src = 'gta', posSrc = 'estime', note = 'barre chocolatée (tenue comme l\'egobar)' },
    snack_cup    = { model = 'xs_prop_trinket_cup_01a', bone = 60309, pos = { -0.02, 0.01, -0.07 }, rot = { 0.0, 0.0, 0.0 }, src = 'rpemotes', posSrc = 'estime', note = 'gobelet de l\'emote « popcorn »' },

    -- Boissons
    espresso     = { model = 'p_ing_coffeecup_01', bone = 28422, pos = { 0.0, 0.0, -0.014 }, rot = { 0.0, 0.0, 90.0 }, src = 'rpemotes', note = 'emote « coffeecall » (petite tasse)' },
    coffee       = { model = 'p_amb_coffeecup_01', bone = 28422, pos = { 0.0, 0.0, 0.0 }, rot = { 0.0, 0.0, 0.0 }, src = 'rpemotes', note = 'emote « coffee »' },
    glass        = { model = 'prop_drink_whisky', bone = 28422, pos = { 0.01, -0.01, -0.06 }, rot = { 0.0, 0.0, 0.0 }, src = 'rpemotes', note = 'emote « whiskey » (verre)' },
    plastic_cup  = { model = 'prop_plastic_cup_02', bone = 28422, pos = { 0.0, 0.0, 0.0 }, rot = { 0.0, 0.0, 0.0 }, src = 'rpemotes', note = 'emote « cup »' },
    fastfood_cup = { model = 'prop_cs_bs_cup', bone = 28422, pos = { 0.006, 0.001, 0.0 }, rot = { 0.0, 0.0, -150.0 }, src = 'rpemotes', note = 'emote « soda4 » (gobelet avec paille)' },
    bottle       = { model = 'prop_ld_flow_bottle', bone = 18905, pos = { 0.12, 0.008, 0.03 }, rot = { 240.0, -60.0, 0.0 }, src = 'rpemotes', note = 'emote « drink »' },
    small_bottle = { model = 'prop_energy_drink', bone = 60309, pos = { 0.008, 0.001, 0.016 }, rot = { 3.569, 4.6611, -49.9065 }, src = 'rpemotes', note = 'emote « edrink » (petite bouteille)' },
    milkshake    = { model = 'brum_cherryshake_strawberry', bone = 28422, pos = { 0.085, 0.067, -0.035 }, rot = { -115.0862, -165.7841, 24.1318 }, src = 'custom', note = 'emote « sipshakei » (gobelet + paille)' },
    soda_cup     = { model = 'rpemotesreborn_soda02', bone = 28422, pos = { 0.047, 0.004, -0.06 }, rot = { -88.0263, -25.0367, -27.3898 }, src = 'custom', note = 'emote « sipsodab » (gobelet + paille)' },
    tea_mug      = { model = 'bzzz_food_xmas_mug_a', bone = 18905, pos = { 0.09, -0.01, 0.08 }, rot = { -44.0, 137.0, 9.0 }, src = 'custom', note = 'emote « xmasmug » (tasse de thé)' },
    can          = { model = 'prop_ecola_can', bone = 18905, pos = { 0.12, 0.008, 0.03 }, rot = { 240.0, -60.0, 0.0 }, src = 'gta', posSrc = 'estime', note = 'canette (tenue comme la bouteille)' },
    can_sprunk   = { model = 'prop_ld_can_01', bone = 18905, pos = { 0.12, 0.008, 0.03 }, rot = { 240.0, -60.0, 0.0 }, src = 'gta', posSrc = 'estime', note = 'canette Sprunk' },
    beer         = { model = 'prop_amb_beer_bottle', bone = 18905, pos = { 0.12, 0.008, 0.03 }, rot = { 240.0, -60.0, 0.0 }, src = 'gta', posSrc = 'estime', note = 'bouteille de bière' },
    mojito       = { model = 'prop_mojito', bone = 28422, pos = { 0.01, -0.01, -0.06 }, rot = { 0.0, 0.0, 0.0 }, src = 'gta', posSrc = 'estime', note = 'verre de mojito' },
    cocktail     = { model = 'prop_cocktail', bone = 28422, pos = { 0.01, -0.01, -0.06 }, rot = { 0.0, 0.0, 0.0 }, src = 'gta', posSrc = 'estime', note = 'verre à cocktail' },
    shot_glass   = { model = 'prop_tequila', bone = 28422, pos = { 0.01, -0.01, -0.06 }, rot = { 0.0, 0.0, 0.0 }, src = 'gta', posSrc = 'estime', note = 'petit verre (shot)' },
    champagne    = { model = 'prop_drink_champ', bone = 28422, pos = { 0.01, -0.01, -0.06 }, rot = { 0.0, 0.0, 0.0 }, src = 'gta', posSrc = 'estime', note = 'coupe de champagne' },
    wine         = { model = 'prop_drink_redwine', bone = 28422, pos = { 0.01, -0.01, -0.06 }, rot = { 0.0, 0.0, 0.0 }, src = 'gta', posSrc = 'estime', note = 'verre de vin' },
    mustard      = { model = 'prop_food_mustard', bone = 18905, pos = { 0.12, 0.008, 0.03 }, rot = { 240.0, -60.0, 0.0 }, src = 'gta', posSrc = 'estime', note = 'flacon de moutarde' },
    color_cup    = { model = 'scully_boba', bone = 28422, pos = { 0.0, 0.0, 0.0 }, rot = { 0.0, 0.0, 0.0 }, src = 'custom', note = 'emote « boba » (gobelet coloré)' },
}

-- ---------------------------------------------------------------------
-- Façons de consommer (geste + objets) réutilisées par plusieurs recettes
-- ---------------------------------------------------------------------
local PLATE   = { anim = 'plate', props = { 'plate', 'spoon' } }
local RAMEKIN = { anim = 'plate', props = { 'ramekin', 'spoon' } }
local NOODLES = { anim = 'plate', props = { 'bowl_noodle', 'spoon_noodle' } }
local DCUP    = { anim = 'plate', props = { 'dessert_cup', 'dessert_spoon' } }
-- Assiette + FOURCHETTE (plats salés) ; avec la viande ou le poisson posé dessus
local FORK    = { anim = 'plate', props = { 'plate', 'fork' } }
local STEAK   = { anim = 'plate', props = { 'plate', 'on_plate_steak', 'fork' } }
local SUSHIS  = { anim = 'plate', props = { 'plate', 'on_plate_fish', 'fork' } }
-- Pâtes : assiette creuse de nouilles + fourchette (aucun modèle « spaghetti » dans GTA : bol de nouilles de rpemotes)
local PASTA   = { anim = 'plate', props = { 'bowl_noodle', 'fork' } }
local function bite(p, fp) return { anim = fp and 'bite_fp' or 'bite', props = { p } } end
local function snack(p) return { anim = 'snack', props = { p } } end
local function drink(anim, p) return { anim = anim, props = { p } } end

-- r(id, catégorie, type, nom, description, faim, soif, poids g, durée ms, emoji, façon, repli)
local R = {}
local function r(id, cat, kind, label, desc, hunger, thirst, weight, time, emoji, use, fb)
    R[#R + 1] = { id = id, cat = cat, kind = kind, label = label, desc = desc, hunger = hunger, thirst = thirst, weight = weight,
        time = time, emoji = emoji, anim = use.anim, props = use.props, fb = fb }
end

-- =========================== ITALIEN ===========================
r('it_spaghetti_bolo', 'italien', 'plat', 'Spaghetti Bolognaise', 'Spaghetti, sauce tomate mijotée au bœuf haché et parmesan.', 38, 4, 450, 9000, { '🍝' }, PASTA, FORK)
r('it_lasagnes', 'italien', 'plat', 'Lasagnes à la viande', 'Feuilles de pâtes, bolognaise, béchamel gratinée.', 42, 2, 480, 9000, { '🍝', '🧀' }, FORK, PLATE)
r('it_pizza_margherita', 'italien', 'plat', 'Pizza Margherita', 'Part de pizza tomate, mozzarella, basilic frais.', 28, 0, 220, 5500, { '🍕' }, bite('pizza_marg'), bite('pizza_slice'))
r('it_pizza_4fromages', 'italien', 'plat', 'Pizza 4 Fromages', 'Part de pizza mozzarella, gorgonzola, parmesan, fontina.', 30, 0, 230, 5500, { '🍕', '🧀' }, bite('pizza_pesto'), bite('pizza_slice'))
r('it_pizza_pepperoni', 'italien', 'plat', 'Pizza Pepperoni', 'Part de pizza tomate, mozzarella et pepperoni épicé.', 30, 0, 230, 5500, { '🍕', '🌶️' }, bite('pizza_pepp'), bite('pizza_slice'))
r('it_carbonara', 'italien', 'plat', 'Carbonara', 'Spaghetti, jaune d\'œuf, pecorino, guanciale croustillant.', 38, 2, 420, 9000, { '🍝', '🥓' }, PASTA, FORK)
r('it_risotto_champi', 'italien', 'plat', 'Risotto aux champignons', 'Riz arborio crémeux, cèpes et parmesan.', 34, 6, 400, 9000, { '🍚', '🍄' }, PLATE)
r('it_raviolis', 'italien', 'plat', 'Raviolis ricotta épinards', 'Raviolis maison farcis ricotta-épinards, beurre de sauge.', 34, 2, 380, 8500, { '🥟', '🌿' }, FORK, PLATE)
r('it_gnocchis', 'italien', 'plat', 'Gnocchis sauce tomate', 'Gnocchis de pomme de terre, sauce tomate et basilic.', 32, 4, 380, 8500, { '🥔', '🍅' }, FORK, PLATE)
r('it_tagliatelles_saumon', 'italien', 'plat', 'Tagliatelles au saumon', 'Tagliatelles fraîches, saumon, crème et aneth.', 36, 2, 420, 9000, { '🍝', '🐟' }, PASTA, FORK)
r('it_penne_arrabbiata', 'italien', 'plat', 'Penne Arrabbiata', 'Penne, sauce tomate pimentée à l\'ail.', 32, 2, 380, 8500, { '🍝', '🌶️' }, PASTA, FORK)
r('it_escalope_milanaise', 'italien', 'plat', 'Escalope Milanaise', 'Escalope de veau panée, citron et roquette.', 40, 0, 400, 9500, { '🥩', '🍋' }, STEAK, FORK)
r('it_parmigiana', 'italien', 'plat', 'Parmigiana d\'aubergines', 'Aubergines, tomate, mozzarella et parmesan gratinés.', 30, 4, 380, 8500, { '🍆', '🧀' }, FORK, PLATE)
r('it_focaccia', 'italien', 'plat', 'Focaccia italienne', 'Pain moelleux à l\'huile d\'olive, romarin et sel.', 18, 0, 160, 5000, { '🫓', '🌿' }, bite('bread'))
r('it_tiramisu', 'italien', 'dessert', 'Tiramisu', 'Mascarpone, biscuits imbibés de café, cacao.', 16, 2, 160, 7000, { '🍰', '☕' }, DCUP, RAMEKIN)
r('it_panna_cotta', 'italien', 'dessert', 'Panna Cotta', 'Crème vanillée, coulis de fruits rouges.', 14, 2, 150, 6500, { '🍮', '🍓' }, RAMEKIN)
r('it_cannoli', 'italien', 'dessert', 'Cannoli siciliens', 'Tube croustillant garni de ricotta sucrée et pistaches.', 14, 0, 120, 5000, { '🥐', '🍦' }, bite('croissant'), bite('bread'))
r('it_gelato', 'italien', 'dessert', 'Gelato italien', 'Cornet de glace artisanale à la pistache.', 10, 6, 140, 6000, { '🍦' }, bite('icecream'), RAMEKIN)
r('it_limonata', 'italien', 'boisson', 'Limonata italienne', 'Citronnade pétillante aux citrons de Sicile.', 0, 30, 330, 4500, { '🍋', '🥤' }, drink('cup', 'glass'))
r('it_espresso', 'italien', 'boisson', 'Café Espresso', 'Petit café serré, crème noisette.', 0, 10, 60, 3500, { '☕' }, drink('cup', 'espresso'))

-- =========================== FAST-FOOD ===========================
r('ff_cheeseburger', 'fastfood', 'plat', 'Cheeseburger', 'Steak haché, cheddar fondu, cornichons, ketchup.', 26, 0, 230, 5500, { '🍔' }, bite('burger'))
r('ff_double_burger', 'fastfood', 'plat', 'Double Burger', 'Deux steaks, double cheddar, oignons, sauce maison.', 36, 0, 330, 6500, { '🍔', '🍔' }, bite('burger_bs', true), bite('burger', true))
r('ff_chicken_burger', 'fastfood', 'plat', 'Chicken Burger', 'Filet de poulet croustillant, salade, mayonnaise.', 28, 0, 250, 5500, { '🍔', '🍗' }, bite('burger_cb'), bite('burger'))
r('ff_fish_burger', 'fastfood', 'plat', 'Fish Burger', 'Poisson pané, sauce tartare, cheddar.', 26, 0, 230, 5500, { '🍔', '🐟' }, bite('burger_b2'), bite('burger'))
r('ff_hotdog', 'fastfood', 'plat', 'Hot-Dog', 'Saucisse grillée, moutarde, oignons frits.', 22, 0, 200, 5000, { '🌭' }, bite('hotdog'))
r('ff_tacos_us', 'fastfood', 'plat', 'Tacos américain', 'Coque de maïs croustillante, bœuf haché, cheddar, salade.', 22, 0, 180, 5000, { '🌮', '🇺🇸' }, bite('taco', true))
r('ff_nuggets', 'fastfood', 'plat', 'Nuggets de poulet', 'Boîte de 9 nuggets croustillants et leur sauce.', 22, 0, 200, 6000, { '🍗' }, snack('nuggets_box'), snack('candy_bag'))
r('ff_frites', 'fastfood', 'plat', 'Frites classiques', 'Cornet de frites dorées et salées.', 16, 0, 150, 6000, { '🍟' }, snack('fries'), snack('candy_bag'))
r('ff_onion_rings', 'fastfood', 'plat', 'Onion Rings', 'Rondelles d\'oignon panées, sauce barbecue.', 14, 0, 140, 6000, { '🧅', '⭕' }, snack('snack_cup'), snack('candy_bag'))
r('ff_wrap_poulet', 'fastfood', 'plat', 'Wrap au poulet', 'Galette roulée, poulet grillé, crudités, sauce blanche.', 24, 0, 220, 5500, { '🌯', '🍗' }, bite('sandwich', true))
r('ff_club_sandwich', 'fastfood', 'plat', 'Club Sandwich', 'Pain de mie toasté, poulet, bacon, œuf, tomate.', 26, 0, 250, 5500, { '🥪' }, bite('sandwich'))
r('ff_panini', 'fastfood', 'plat', 'Panini poulet', 'Pain grillé au poulet, mozzarella et pesto.', 24, 0, 220, 5000, { '🥖', '🍗' }, bite('bread', true))
r('ff_pizza_slice', 'fastfood', 'plat', 'Pizza Slice Fast-Food', 'Grande part de pizza pepperoni-jalapeños.', 24, 0, 220, 5500, { '🍕', '🫑' }, bite('pizza_jalap', true), bite('pizza_slice'))
r('ff_chicken_wings', 'fastfood', 'plat', 'Chicken Wings', 'Ailes de poulet marinées sauce piquante.', 24, 0, 220, 6000, { '🍗', '🔥' }, snack('nuggets_box'), snack('candy_bag'))
r('ff_tenders', 'fastfood', 'plat', 'Tenders de poulet', 'Aiguillettes de poulet panées, sauce miel-moutarde.', 24, 0, 220, 5500, { '🍗', '🍯' }, { anim = 'bite_fp', props = { 'nuggets_box' } }, bite('burger', true))
r('ff_donut', 'fastfood', 'dessert', 'Donut', 'Beignet glacé au sucre et vermicelles.', 12, 0, 90, 4500, { '🍩' }, bite('donut'))
r('ff_brownie', 'fastfood', 'dessert', 'Brownie au chocolat', 'Carré fondant au chocolat noir et noix de pécan.', 14, 0, 100, 4500, { '🟫', '🍫' }, bite('cake_slice'), bite('chocobar'))
r('ff_muffin', 'fastfood', 'dessert', 'Muffin aux myrtilles', 'Muffin moelleux aux myrtilles fraîches.', 14, 0, 110, 4500, { '🧁', '🫐' }, bite('cupcake'), bite('donut'))
r('ff_milkshake_fraise', 'fastfood', 'boisson', 'Milkshake à la fraise', 'Grand gobelet de milkshake fraise, chantilly, paille.', 8, 26, 450, 5500, { '🥤', '🍓' }, drink('straw', 'milkshake'), drink('cup', 'fastfood_cup'))
r('ff_soda', 'fastfood', 'boisson', 'Soda en gobelet', 'Gobelet de soda glacé avec paille.', 0, 30, 420, 4500, { '🥤' }, drink('straw', 'soda_cup'), drink('cup', 'fastfood_cup'))

-- =========================== JAPONAIS ===========================
r('jp_sushi_saumon', 'japonais', 'plat', 'Sushi Saumon', 'Nigiri de riz vinaigré et tranche de saumon.', 10, 0, 60, 4000, { '🍣' }, bite('fish_slice'))
r('jp_sushi_thon', 'japonais', 'plat', 'Sushi Thon', 'Nigiri de riz vinaigré et tranche de thon rouge.', 10, 0, 60, 4000, { '🍣', '🐟' }, bite('fish_slice', true))
r('jp_makis_saumon', 'japonais', 'plat', 'Makis Saumon', 'Assiette de 6 makis au saumon, algue nori.', 20, 0, 180, 8000, { '🍙', '🐟' }, SUSHIS, FORK)
r('jp_california', 'japonais', 'plat', 'California Rolls', 'Assiette de rolls avocat, surimi, sésame.', 20, 0, 180, 8000, { '🍣', '🥑' }, SUSHIS, FORK)
r('jp_sashimi', 'japonais', 'plat', 'Sashimi Saumon', 'Fines tranches de saumon cru, wasabi et gingembre.', 18, 0, 160, 7500, { '🐟', '🟠' }, SUSHIS, FORK)
r('jp_ramen_porc', 'japonais', 'plat', 'Ramen au porc', 'Bol de nouilles, bouillon tonkotsu, chashu, œuf mollet.', 36, 14, 550, 10000, { '🍜', '🥓' }, NOODLES, PLATE)
r('jp_ramen_poulet', 'japonais', 'plat', 'Ramen au poulet', 'Bol de nouilles, bouillon shoyu, poulet grillé, ciboule.', 34, 14, 550, 10000, { '🍜', '🍗' }, NOODLES, PLATE)
r('jp_udon', 'japonais', 'plat', 'Udon', 'Bol de nouilles de blé épaisses, bouillon dashi, tempura.', 32, 14, 520, 10000, { '🍜', '🍥' }, NOODLES, PLATE)
r('jp_yakitori', 'japonais', 'plat', 'Yakitori poulet', 'Brochette de poulet grillé, sauce tare.', 14, 0, 100, 5000, { '🍢' }, bite('skewer'), bite('chocobar'))
r('jp_gyoza', 'japonais', 'plat', 'Gyoza', 'Raviolis grillés au porc et chou, sauce soja.', 18, 0, 160, 7500, { '🥟' }, FORK, PLATE)
r('jp_tempura', 'japonais', 'plat', 'Tempura de crevettes', 'Crevettes en tempura légère, sauce tentsuyu.', 20, 0, 180, 8000, { '🍤' }, FORK, PLATE)
r('jp_donburi', 'japonais', 'plat', 'Donburi au bœuf', 'Bol de riz, bœuf mijoté aux oignons (gyudon).', 36, 4, 480, 9500, { '🍚', '🥩' }, NOODLES, PLATE)
r('jp_katsudon', 'japonais', 'plat', 'Katsudon', 'Bol de riz, porc pané et œuf.', 38, 4, 500, 9500, { '🍛' }, NOODLES, PLATE)
r('jp_bento', 'japonais', 'plat', 'Bento japonais', 'Boîte repas : riz, poisson grillé, légumes, tamagoyaki.', 34, 2, 450, 9000, { '🍱' }, RAMEKIN)
r('jp_onigiri', 'japonais', 'plat', 'Onigiri', 'Triangle de riz au saumon, enveloppé de nori.', 14, 0, 110, 4500, { '🍙' }, bite('sandwich', true))
r('jp_mochi', 'japonais', 'dessert', 'Mochi', 'Petite boule de pâte de riz à la pâte de haricot.', 10, 0, 50, 4000, { '🍡' }, bite('macaron'), bite('donut'))
r('jp_dorayaki', 'japonais', 'dessert', 'Dorayaki', 'Deux pancakes garnis de pâte de haricot rouge.', 12, 0, 90, 4500, { '🥞', '🫘' }, bite('bread', true))
r('jp_taiyaki', 'japonais', 'dessert', 'Taiyaki', 'Gâteau en forme de poisson, fourré au haricot rouge.', 12, 0, 90, 4500, { '🐟', '🍪' }, bite('croissant', true), bite('bread'))
r('jp_matcha', 'japonais', 'boisson', 'Thé Matcha', 'Thé vert matcha fouetté, servi chaud.', 0, 24, 250, 5000, { '🍵' }, drink('bottle', 'tea_mug'), drink('cup', 'coffee'))
r('jp_ramune', 'japonais', 'boisson', 'Ramune japonais', 'Limonade japonaise en bouteille à bille.', 0, 28, 200, 4000, { '🍾', '🫧' }, drink('bottle', 'small_bottle'))

-- =========================== MEXICAIN ===========================
r('mx_tacos_pastor', 'mexicain', 'plat', 'Tacos Al Pastor', 'Porc mariné à l\'ananas, coriandre, oignon.', 20, 0, 160, 5000, { '🌮', '🍍' }, bite('taco'))
r('mx_tacos_carnitas', 'mexicain', 'plat', 'Tacos Carnitas', 'Porc confit effiloché, salsa verde, citron vert.', 20, 0, 160, 5000, { '🌮', '🐖' }, bite('taco', true))
r('mx_burrito_boeuf', 'mexicain', 'plat', 'Burrito au bœuf', 'Tortilla roulée, bœuf, riz, haricots, fromage.', 34, 0, 350, 6500, { '🌯', '🥩' }, bite('sandwich'))
r('mx_burrito_poulet', 'mexicain', 'plat', 'Burrito au poulet', 'Tortilla roulée, poulet, riz, guacamole.', 32, 0, 340, 6500, { '🌯', '🍗' }, bite('sandwich', true))
r('mx_quesadilla', 'mexicain', 'plat', 'Quesadilla au fromage', 'Part de tortilla grillée au fromage fondu.', 22, 0, 180, 5000, { '🧀', '🫓' }, bite('pizza_mush', true), bite('pizza_slice'))
r('mx_nachos', 'mexicain', 'plat', 'Nachos au fromage', 'Assiette de chips de maïs, cheddar fondu, jalapeños.', 20, 0, 200, 7000, { '🧀', '🌽' }, { anim = 'snack', props = { 'plate' } })
r('mx_enchiladas', 'mexicain', 'plat', 'Enchiladas', 'Tortillas garnies, sauce chili, fromage gratiné.', 34, 2, 400, 9000, { '🫔' }, FORK, PLATE)
r('mx_fajitas', 'mexicain', 'plat', 'Fajitas au poulet', 'Poulet, poivrons et oignons grillés, tortillas.', 34, 2, 400, 9000, { '🫑', '🍗' }, STEAK, FORK)
r('mx_chimichanga', 'mexicain', 'plat', 'Chimichanga', 'Burrito frit croustillant, bœuf et fromage.', 32, 0, 320, 6000, { '🌯', '🔥' }, bite('sandwich'))
r('mx_tamales', 'mexicain', 'plat', 'Tamales', 'Pâte de maïs vapeur farcie au porc, en feuille de maïs.', 24, 0, 220, 5500, { '🫔', '🌽' }, bite('bread'))
r('mx_tostadas', 'mexicain', 'plat', 'Tostadas', 'Tortillas croustillantes, haricots, poulet, avocat.', 24, 0, 220, 8000, { '🫓', '🥑' }, FORK, PLATE)
r('mx_chilaquiles', 'mexicain', 'plat', 'Chilaquiles', 'Chips de tortilla en sauce rouge, crème, œuf.', 30, 2, 350, 8500, { '🍳', '🌶️' }, FORK, PLATE)
r('mx_elote', 'mexicain', 'plat', 'Elote (maïs grillé)', 'Épi de maïs grillé, mayonnaise, cotija, piment.', 14, 0, 200, 5000, { '🌽' }, bite('skewer', true), bite('chocobar'))
r('mx_empanadas', 'mexicain', 'plat', 'Empanadas', 'Chaussons dorés farcis au bœuf épicé.', 20, 0, 160, 5000, { '🥟', '🥩' }, bite('croissant'), bite('bread'))
r('mx_pozole', 'mexicain', 'plat', 'Pozole', 'Bol de soupe de maïs hominy et porc, radis, origan.', 34, 16, 550, 10000, { '🍲' }, NOODLES, PLATE)
r('mx_churros', 'mexicain', 'dessert', 'Churros', 'Beignets allongés au sucre-cannelle.', 12, 0, 100, 4500, { '🥖', '🍫' }, bite('chocobar', true))
r('mx_flan', 'mexicain', 'dessert', 'Flan mexicain', 'Crème renversée au caramel.', 12, 2, 140, 6500, { '🍮' }, DCUP, RAMEKIN)
r('mx_tres_leches', 'mexicain', 'dessert', 'Tres Leches', 'Gâteau imbibé de trois laits, crème fouettée.', 16, 2, 160, 5000, { '🍰', '🥛' }, bite('cake_slice', true), PLATE)
r('mx_horchata', 'mexicain', 'boisson', 'Horchata', 'Boisson de riz à la cannelle, bien fraîche.', 4, 28, 400, 4500, { '🥛', '🍚' }, drink('cup', 'plastic_cup'))
r('mx_agua_fresca', 'mexicain', 'boisson', 'Agua Fresca', 'Eau fraîche aux fruits (pastèque, hibiscus).', 0, 32, 400, 4500, { '🍉', '🥤' }, drink('cup', 'color_cup'), drink('cup', 'plastic_cup'))

D.Recipes = R
D.Categories = {
    { id = 'italien', label = 'Restaurant italien', color = '#2e9e5b' },
    { id = 'fastfood', label = 'Fast-Food', color = '#e63946' },
    { id = 'japonais', label = 'Restaurant japonais', color = '#d62f5c' },
    { id = 'mexicain', label = 'Restaurant mexicain', color = '#f4a020' },
}
-- Repli final si même le repli manque (jamais de consommation sans visuel cohérent : burger / bouteille du jeu de base)
D.LastResort = {
    food = { anim = 'bite', props = { 'burger' } },
    drink = { anim = 'bottle', props = { 'bottle' } },
}

-- =====================================================================
--  AUTRES ALIMENTS DU SERVEUR (objets d'elyzea_inventory qui ne sont pas des recettes)
--  Burger Shot, pizza, boîte de nuit, supérette… : chacun reçoit SES objets en main et SON geste.
--  item = { use = façon, fb = repli }   (mêmes façons que les recettes)
-- =====================================================================
local function I(use, fb) return { use = use, fb = fb } end
local BURGER = I(bite('burger_bs'), bite('burger'))
local SODA = I(drink('straw', 'soda_cup'), drink('cup', 'fastfood_cup'))
local SHAKE = I(drink('straw', 'milkshake'), drink('cup', 'fastfood_cup'))
D.Items = {
    -- de base
    burger = I(bite('burger')), testburger = I(bite('burger')),
    bread = I(bite('bread')), chips = I(snack('crisps'), snack('candy_bag')), donut = I(bite('donut')),
    pizza = I(bite('pizza_pepp'), bite('pizza_slice')), tosti = I(bite('sandwich')),
    twerks_candy = I(bite('chocobar')), snikkel_candy = I(bite('chocobar2'), bite('chocobar')),
    water = I(drink('bottle', 'bottle')), water_bottle = I(drink('bottle', 'bottle')),
    cola = I(drink('bottle', 'can')), kurkakola = I(drink('bottle', 'can')), sprunk = I(drink('bottle', 'can_sprunk'), drink('bottle', 'can')),
    mustard = I(drink('bottle', 'mustard'), drink('bottle', 'bottle')),
    -- Burger Shot
    bs_bleeder = BURGER, bs_heartstopper = I(bite('burger_bs', true), bite('burger', true)),
    bs_burger_classic = BURGER, bs_burger_double = I(bite('burger_bs', true), bite('burger', true)), bs_burger_bacon = BURGER,
    bs_burger_chicken = I(bite('burger_cb'), bite('burger')), bs_burger_veggie = I(bite('burger_b2'), bite('burger')),
    bs_burger_monster = I(bite('burger_bs', true), bite('burger', true)),
    bs_frites = I(snack('fries'), snack('candy_bag')),
    bs_soda = SODA, bs_drink_cola = SODA, bs_drink_orange = SODA, bs_drink_lemon = SODA, bs_drink_icetea = SODA,
    bs_milkshake = SHAKE, bs_drink_shake = SHAKE, bs_drink_coffee = I(drink('cup', 'coffee')),
    bs_dessert_sundae = I(DCUP, RAMEKIN), bs_dessert_donut = I(bite('donut')), bs_dessert_cookie = I(bite('macaron'), bite('donut')),
    bs_dessert_pie = I(bite('croissant'), bite('bread')), bs_dessert_cheesecake = I(bite('cake_slice'), DCUP),
    bs_dessert_muffin = I(bite('cupcake'), bite('donut')),
    -- boîte de nuit
    nc_mojito = I(drink('cup', 'mojito'), drink('cup', 'glass')), nc_whiskycoca = I(drink('cup', 'glass')),
    nc_vodkaenergy = I(drink('cup', 'cocktail'), drink('cup', 'glass')), nc_shot = I(drink('cup', 'shot_glass'), drink('cup', 'glass')),
    nc_coupe = I(drink('cup', 'champagne'), drink('cup', 'glass')), nc_soda = I(drink('bottle', 'can')), nc_energy = I(drink('bottle', 'small_bottle')),
}

-- =====================================================================
--  RECONNAISSANCE PAR LE NOM (tout aliment ajouté plus tard, sans rien configurer)
--  Le nom affiché + l'identifiant de l'objet sont comparés à ces mots (minuscules, sans accents),
--  dans l'ordre : la première règle qui correspond gagne. drink = true : seulement pour une boisson.
-- =====================================================================
D.Guess = {
    -- boissons
    { drink = true, words = { 'milkshake', 'smoothie', 'frappe', 'bubble' }, use = SHAKE.use, fb = SHAKE.fb },
    { drink = true, words = { 'cafe', 'coffee', 'expresso', 'espresso', 'cappuccino', 'latte', 'chocolat chaud' }, use = drink('cup', 'coffee') },
    { drink = true, words = { 'the ', 'the_', 'tea', 'tisane', 'infusion', 'matcha' }, use = drink('bottle', 'tea_mug'), fb = drink('cup', 'coffee') },
    { drink = true, words = { 'biere', 'beer', 'pisswasser', 'logger' }, use = drink('bottle', 'beer') },
    { drink = true, words = { 'champagne', 'coupe' }, use = drink('cup', 'champagne'), fb = drink('cup', 'glass') },
    { drink = true, words = { 'vin ', 'vin_', 'wine', 'rose', 'rouge' }, use = drink('cup', 'wine'), fb = drink('cup', 'glass') },
    { drink = true, words = { 'mojito' }, use = drink('cup', 'mojito'), fb = drink('cup', 'glass') },
    { drink = true, words = { 'shot', 'tequila' }, use = drink('cup', 'shot_glass'), fb = drink('cup', 'glass') },
    { drink = true, words = { 'cocktail', 'margarita', 'daiquiri', 'pina' }, use = drink('cup', 'cocktail'), fb = drink('cup', 'glass') },
    { drink = true, words = { 'whisky', 'vodka', 'rhum', 'gin ', 'gin_', 'cognac', 'liqueur' }, use = drink('cup', 'glass') },
    { drink = true, words = { 'energ', 'redbull', 'monster' }, use = drink('bottle', 'small_bottle') },
    { drink = true, words = { 'cola', 'soda', 'sprunk', 'limonade', 'orangina', 'canette' }, use = drink('bottle', 'can') },
    { drink = true, words = { 'jus', 'juice', 'gobelet' }, use = drink('cup', 'plastic_cup') },
    -- plats
    { words = { 'pizza' }, use = bite('pizza_pepp'), fb = bite('pizza_slice') },
    { words = { 'burger' }, use = bite('burger') },
    { words = { 'hot dog', 'hotdog', 'hot-dog', 'saucisse' }, use = bite('hotdog') },
    { words = { 'taco' }, use = bite('taco') },
    { words = { 'burrito', 'wrap', 'kebab', 'sandwich', 'panini', 'tosti', 'croque', 'bagel', 'baguette' }, use = bite('sandwich') },
    { words = { 'pates', 'pasta', 'spaghet', 'tagliat', 'penne', 'fettucc', 'linguin', 'macaroni', 'carbonar', 'bolognai' }, use = PASTA, fb = FORK },
    { words = { 'lasagn', 'ravioli', 'gnocch', 'canneloni', 'cannelloni' }, use = FORK, fb = PLATE },
    { words = { 'nouille', 'noodle', 'ramen', 'udon', 'pho', 'wok' }, use = NOODLES, fb = { anim = 'snack', props = { 'noodle_box' } } },
    { words = { 'soupe', 'veloute', 'bouillon', 'potage', 'chili' }, use = NOODLES, fb = PLATE },
    { words = { 'sushi', 'nigiri' }, use = bite('fish_slice') },
    { words = { 'maki', 'california', 'sashimi', 'poisson', 'saumon', 'fish' }, use = SUSHIS, fb = FORK },
    { words = { 'steak', 'entrecote', 'escalope', 'cote de', 'viande', 'roti', 'grillade', 'cotelette' }, use = STEAK, fb = FORK },
    { words = { 'salade', 'riz', 'curry', 'couscous', 'tajine', 'paella', 'puree', 'gratin', 'omelette', 'assiette', 'plat du jour', 'menu' }, use = FORK, fb = PLATE },
    { words = { 'brochette', 'yakitori', 'skewer' }, use = bite('skewer'), fb = bite('chocobar') },
    { words = { 'frite', 'fries', 'chips', 'nugget', 'popcorn', 'bonbon', 'candy', 'cacahuete' }, use = snack('candy_bag') },
    { words = { 'donut', 'beignet' }, use = bite('donut') },
    { words = { 'glace', 'ice cream', 'icecream', 'sorbet', 'gelato' }, use = bite('icecream'), fb = DCUP },
    { words = { 'yaourt', 'creme', 'mousse', 'flan', 'compote', 'tiramisu', 'pudding' }, use = DCUP, fb = RAMEKIN },
    { words = { 'gateau', 'cake', 'tarte', 'cheesecake', 'brownie', 'part de' }, use = bite('cake_slice'), fb = bite('donut') },
    { words = { 'muffin', 'cupcake' }, use = bite('cupcake'), fb = bite('donut') },
    { words = { 'croissant', 'viennoiserie', 'chausson', 'brioche', 'pain au' }, use = bite('croissant'), fb = bite('bread') },
    { words = { 'chocolat', 'barre', 'snikkel', 'twerks', 'egochaser', 'meteorite' }, use = bite('chocobar') },
    { words = { 'pomme', 'apple', 'fruit', 'poire', 'peche' }, use = bite('apple'), fb = bite('donut') },
    { words = { 'pain', 'bread', 'cookie', 'biscuit', 'gaufre', 'crepe' }, use = bite('bread') },
}
-- Rien ne correspond : un plat consistant se mange à l'assiette, un en-cas se croque, une boisson se boit à la bouteille
D.Default = { meal = { use = FORK, fb = PLATE }, snack = { use = bite('sandwich') }, drink = { use = drink('bottle', 'bottle') } }

return D
