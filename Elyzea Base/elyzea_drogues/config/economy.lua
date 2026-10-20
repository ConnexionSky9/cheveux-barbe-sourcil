-- =====================================================================
--  ÉCONOMIE : prix de vente (acheteurs) et matériel (fournisseurs)
--  Tout se modifie dans admin_menu › Gestion des drogues › Prix (gardé en base, appliqué tout de suite).
-- =====================================================================
Config.Sale = {
    -- payment : { type = 'item', item = 'black_money' } (argent sale, comme la vente de rue) ou { type = 'money', account = 'cash' }
    payment = { type = 'item', item = 'black_money' },
    cooldown = 4,          -- secondes entre deux ventes d'un joueur
    hourlyLimit = 0,       -- unités max vendues par joueur et par heure, tous produits (0 = illimité)
}

-- Prix de vente à l'unité. 0 = l'acheteur ne prend pas cet objet. max : unités max par vente
Config.Prices = {
    joint = { price = 30, max = 10 },  joint_ww = { price = 40, max = 10 }, joint_ph = { price = 45, max = 10 }, joint_custom = { price = 42, max = 10 },
    weed_pouch = { price = 90, max = 10 }, weed_pouch_ww = { price = 110, max = 10 }, weed_pouch_ph = { price = 120, max = 10 }, weed_pouch_custom = { price = 115, max = 10 },
    cokebaggy = { price = 180, max = 5 }, coke_premium = { price = 290, max = 5 }, cocaine = { price = 160, max = 5 },
    crack_baggy = { price = 150, max = 5 }, meth = { price = 220, max = 5 },
    xtc_pink = { price = 70, max = 10 }, xtc_blue = { price = 85, max = 10 }, xtc_yellow = { price = 60, max = 10 }, xtcbaggy = { price = 70, max = 10 },
    oxy = { price = 90, max = 10 }, opi_syringe = { price = 150, max = 5 }, ketamine = { price = 140, max = 5 },
    shroom_bag = { price = 110, max = 5 }, dried_mushroom = { price = 45, max = 10 },
    -- produits intermédiaires : 0 (non achetés) par défaut, activables dans le menu
    weed_bud = { price = 0, max = 10 }, coca_paste = { price = 0, max = 5 }, meth_crystal = { price = 0, max = 5 },
}

-- Matériel vendu par les fournisseurs (boutique de l'inventaire, payée en liquide puis banque)
Config.Shop = {
    { item = 'plant_pot', price = 150 }, { item = 'grow_lamp', price = 400 }, { item = 'watering_can', price = 60 },
    { item = 'water', price = 5 }, { item = 'fertilizer', price = 80 },
    { item = 'weed_seed', price = 50 }, { item = 'weed_white-widow_seed', price = 90 }, { item = 'weed_purple-haze_seed', price = 100 }, { item = 'weed_seed_custom', price = 95 },
    { item = 'rolling_paper', price = 5 }, { item = 'drug_bag', price = 3 },
    { item = 'baking_soda', price = 20 }, { item = 'drg_solvent', price = 50 }, { item = 'drg_reagent', price = 120 }, { item = 'drg_acid', price = 60 },
    { item = 'drg_safrole', price = 90 }, { item = 'drg_dye_pink', price = 30 }, { item = 'drg_dye_blue', price = 30 }, { item = 'drg_dye_yellow', price = 30 },
    { item = 'drg_opium_raw', price = 110 }, { item = 'drg_syringe_empty', price = 15 }, { item = 'drg_keta_liquid', price = 130 },
}
