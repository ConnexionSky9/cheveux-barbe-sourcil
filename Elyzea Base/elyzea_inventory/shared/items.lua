-- Définitions des objets. Le SERVEUR est la seule source de vérité.
-- weight : GRAMMES par unité · stack : empilable · max : taille de pile
-- image : fichier dans html/img · clothing : rayon elyzea_clothing
-- bonus : grammes de capacité ajoutés quand l'objet est porté (sac)
-- buttons : actions du clic droit { label, export = 'ressource.fonction', close = true }
-- client = { status = { hunger = 200000 } (1 000 000 = 100 %), anim, prop, usetime, notification, export = 'ressource.fonction' }
-- server = { export = 'ressource.fonction' }
--
-- Les objets de data/items.lua et les armes / munitions de data/weapons.lua sont ajoutés
-- automatiquement (voir shared/import.lua). Ceux définis ICI sont prioritaires.

local function food(label, weight, hunger, thirst, opts)
    opts = opts or {}
    local drink = (thirst or 0) > (hunger or 0)
    return {
        label = label, weight = weight, stack = true, max = 20, icon = drink and '🥤' or '🍔', description = opts.description,
        client = {
            status = { hunger = (hunger or 0) * 10000, thirst = (thirst or 0) * 10000 },
            anim = drink and { dict = 'mp_player_intdrink', clip = 'loop_bottle' } or { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger_fp' },
            prop = opts.prop or (drink and { model = `prop_ld_flow_bottle`, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) }
                or { model = `prop_cs_burger_01`, pos = vec3(0.02, 0.02, -0.02), rot = vec3(0.0, 0.0, 0.0) }),
            usetime = opts.usetime or 2500,
            notification = opts.notification,
        },
    }
end

Items = {
    phone   = { label = 'Téléphone', weight = 200, icon = '📱', stack = false, description = 'Smartphone personnel.' },
    burger  = food('Burger', 220, 20, 0, { notification = 'Vous avez mangé un burger.' }),
    water   = food('Bouteille d\'eau', 500, 0, 25, { notification = 'Vous avez bu de l\'eau.' }),
    water_bottle = food('Bouteille d\'eau', 500, 0, 25),
    cola    = food('eCola', 350, 0, 20, { prop = { model = `prop_ecola_can`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) } }),
    kurkakola = food('Kurkakola', 350, 0, 20, { prop = { model = `prop_ecola_can`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) } }),
    bread   = food('Pain', 150, 15, 0),
    chips   = food('Chips', 100, 8, 0),
    donut   = food('Donut', 120, 10, 0),
    pizza   = food('Part de pizza', 250, 25, 0),
    tosti   = food('Croque-monsieur', 200, 18, 0),
    twerks_candy = food('Barre Twerks', 60, 6, 0),
    snikkel_candy = food('Barre Snikkel', 60, 6, 0),

    carte_identite = { label = 'Carte d\'identité', weight = 10, stack = false, image = 'carte_identite.png', icon = '🪪', close = true,
        description = 'Pièce d\'identité. Utilise-la pour la regarder ou la montrer.',
        client = { export = 'elyzea_papiers.useDocument' } },
    ppa = { label = 'PPA · Civil', weight = 10, stack = false, image = 'ppa.png', icon = '🪪', close = true,
        description = 'Permis de port d\'arme civil (pistolet), délivré par les EMS après le test. Utilise-le pour le regarder ou le montrer.',
        client = { export = 'elyzea_papiers.useDocument' } },
    ppa_fdo = { label = 'PPA · Forces de l\'ordre', weight = 10, stack = false, image = 'ppa_fdo.png', icon = '🪪', close = true,
        description = 'Permis de port d\'arme des forces de l\'ordre (arme légère, arme lourde). Utilise-le pour le regarder ou le montrer.',
        client = { export = 'elyzea_papiers.useDocument' } },
    concess_key = { label = 'Clé de véhicule', weight = 50, stack = false, icon = '🔑',
        description = 'Clé d\'un véhicule acheté en concession. U près du véhicule pour l\'ouvrir ou le fermer.' },
    permis = { label = 'Permis de conduire', weight = 10, stack = false, image = 'permis.png', icon = '🪪',
        description = 'Permis de conduire Elyzea. Utilise-le pour le regarder ou le montrer.',
        client = { export = 'elyzea_permis.useLicense' } },

    -- Soins (elyzea_ems)
    bandage       = { label = 'Bandage', weight = 100, stack = true, max = 20, icon = '🩹', description = 'Soigne légèrement.' },
    gauze         = { label = 'Compresse', weight = 100, stack = true, max = 20, icon = '🩹' },
    painkiller    = { label = 'Antidouleur', weight = 100, stack = true, max = 20, icon = '💊' },
    medical_kit   = { label = 'Medical Kit', weight = 1000, stack = true, max = 5, icon = '🧰' },
    defibrillator = { label = 'Défibrillateur', weight = 3000, stack = true, max = 2, icon = '⚡' },
    morphine      = { label = 'Morphine', weight = 100, stack = true, max = 10, icon = '💉' },
    blood_bag     = { label = 'Poche de sang', weight = 500, stack = true, max = 10, icon = '🩸' },
    splint        = { label = 'Attelle', weight = 300, stack = true, max = 10, icon = '🦴' },

    -- Récoltes et ateliers (admin_menu)
    weed_leaf        = { label = 'Feuille de weed', weight = 20, stack = true, max = 500 },
    coca_leaf        = { label = 'Feuille de coca', weight = 20, stack = true, max = 500 },
    magic_mushroom   = { label = 'Champignon', weight = 20, stack = true, max = 500 },
    meth_chemicals   = { label = 'Produits chimiques', weight = 250, stack = true, max = 100 },
    weed_pouch       = { label = 'Pochon de weed', weight = 50, stack = true, max = 200 },
    cocaine          = { label = 'Cocaïne', weight = 50, stack = true, max = 200 },
    dried_mushroom   = { label = 'Champignons séchés', weight = 30, stack = true, max = 200 },
    metal_scrap      = { label = 'Ferraille', weight = 200, stack = true, max = 500 },
    gun_parts_light  = { label = 'Pièces d\'armes légères', weight = 300, stack = true, max = 100 },
    gun_parts_medium = { label = 'Pièces d\'armes moyennes', weight = 500, stack = true, max = 100 },
    gun_parts_heavy  = { label = 'Pièces d\'armes lourdes', weight = 800, stack = true, max = 100 },
    crowbar          = { label = 'Pied-de-biche', weight = 1500, stack = false },

    -- Burger Shot (elyzea_entreprises) : ingrédients et produits
    bs_pain     = { label = 'Pain à burger', weight = 80, stack = true, max = 50, icon = '🍞', description = 'Ingrédient du Burger Shot.' },
    bs_viande   = { label = 'Steak haché', weight = 150, stack = true, max = 50, icon = '🥩', description = 'Ingrédient du Burger Shot.' },
    bs_legumes  = { label = 'Salade et tomates', weight = 80, stack = true, max = 50, icon = '🥬', description = 'Ingrédient du Burger Shot.' },
    bs_fromage  = { label = 'Tranches de cheddar', weight = 50, stack = true, max = 50, icon = '🧀', description = 'Ingrédient du Burger Shot.' },
    bs_patates  = { label = 'Pommes de terre', weight = 300, stack = true, max = 50, icon = '🥔', description = 'Ingrédient du Burger Shot.' },
    bs_sirop    = { label = 'Sirop de soda', weight = 200, stack = true, max = 50, icon = '🧃', description = 'Ingrédient du Burger Shot.' },
    bs_lait     = { label = 'Lait', weight = 300, stack = true, max = 50, icon = '🥛', description = 'Ingrédient du Burger Shot.' },
    bs_bleeder      = food('The Bleeder', 250, 30, 0, { notification = 'Vous avez mangé un Bleeder.' }),
    bs_heartstopper = food('Heart Stopper', 350, 45, 0, { notification = 'Vous avez mangé un Heart Stopper.' }),
    bs_frites       = food('Frites', 150, 15, 0, { prop = { model = `prop_food_bs_chips`, pos = vec3(0.02, 0.02, -0.02), rot = vec3(0.0, 0.0, 0.0) } }),
    bs_soda         = food('Soda Burger Shot', 400, 0, 30, { prop = { model = `prop_food_bs_juice01`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) } }),
    bs_milkshake    = food('Milkshake', 400, 5, 25, { prop = { model = `prop_food_bs_juice02`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) } }),
    -- Burger Shot : borne de commande (ingrédients en plus)
    bs_bacon      = { label = 'Tranches de bacon', weight = 80, stack = true, max = 50, icon = '🥓', description = 'Ingrédient du Burger Shot.' },
    bs_poulet     = { label = 'Poulet pané', weight = 150, stack = true, max = 50, icon = '🍗', description = 'Ingrédient du Burger Shot.' },
    bs_cafe       = { label = 'Café moulu', weight = 100, stack = true, max = 50, icon = '☕', description = 'Ingrédient du Burger Shot.' },
    bs_patisserie = { label = 'Pâte et sucre', weight = 150, stack = true, max = 50, icon = '🥐', description = 'Ingrédient des desserts du Burger Shot.' },
    -- Burger Shot : 6 burgers
    bs_burger_classic = food('Le Classic Shot', 280, 35, 0, { description = 'Steak, cheddar, salade, tomate, sauce maison.', notification = 'Vous avez mangé un Classic Shot.' }),
    bs_burger_double  = food('Double Shot', 380, 50, 0, { description = 'Deux steaks, double cheddar, oignons, cornichons.', notification = 'Vous avez mangé un Double Shot.' }),
    bs_burger_bacon   = food('Bacon Blaster', 360, 45, 0, { description = 'Steak, bacon croustillant, cheddar, oignons.', notification = 'Vous avez mangé un Bacon Blaster.' }),
    bs_burger_chicken = food('Chicken Crunch', 300, 40, 0, { description = 'Poulet pané, salade, tomate, mayonnaise.', notification = 'Vous avez mangé un Chicken Crunch.' }),
    bs_burger_veggie  = food('Green Shot', 260, 32, 0, { description = 'Galette de légumes, salade, tomate, oignons rouges.', notification = 'Vous avez mangé un Green Shot.' }),
    bs_burger_monster = food('The Monster', 520, 70, 0, { description = 'Trois steaks, triple cheddar, bacon. Pour les affamés.', notification = 'Vous avez dévoré un Monster.' }),
    -- Burger Shot : 6 boissons
    bs_drink_cola   = food('Shot Cola', 400, 0, 35, { description = 'Le cola maison du Burger Shot.', prop = { model = `prop_food_bs_juice01`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) } }),
    bs_drink_orange = food('Orangeade Sunset', 400, 0, 35, { description = 'Soda pétillant à l\'orange.', prop = { model = `prop_food_bs_juice03`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) } }),
    bs_drink_lemon  = food('Citronnade glacée', 400, 0, 40, { description = 'Citronnade maison avec glaçons.', prop = { model = `prop_food_bs_juice03`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) } }),
    bs_drink_icetea = food('Thé glacé pêche', 400, 0, 40, { description = 'Thé infusé à froid, saveur pêche.', prop = { model = `prop_food_bs_juice03`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) } }),
    bs_drink_shake  = food('Milkshake fraise', 450, 10, 30, { description = 'Milkshake à la fraise et chantilly.', prop = { model = `prop_food_bs_juice02`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) } }),
    bs_drink_coffee = food('Café Shot', 250, 0, 20, { description = 'Café serré, servi chaud.', prop = { model = `prop_fib_coffee`, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) } }),
    -- Burger Shot : 6 desserts
    bs_dessert_sundae     = food('Sundae caramel', 200, 15, 5, { description = 'Glace vanille, caramel, noisettes.', prop = { model = `prop_food_bs_juice02`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) } }),
    bs_dessert_donut      = food('Donut glacé', 120, 15, 0, { description = 'Glaçage rose et vermicelles.', prop = { model = `prop_donut_02`, pos = vec3(0.01, 0.01, -0.02), rot = vec3(0.0, 0.0, 0.0) } }),
    bs_dessert_cookie     = food('Cookie géant', 100, 12, 0, { description = 'Pépites de chocolat, tout juste sorti du four.', prop = { model = `prop_donut_01`, pos = vec3(0.01, 0.01, -0.02), rot = vec3(0.0, 0.0, 0.0) } }),
    bs_dessert_pie        = food('Chausson aux pommes', 140, 15, 0, { description = 'Pâte feuilletée, compote de pommes chaude.' }),
    bs_dessert_cheesecake = food('Cheesecake', 160, 20, 0, { description = 'Coulis de fruits rouges.' }),
    bs_dessert_muffin     = food('Muffin chocolat', 120, 15, 0, { description = 'Cœur fondant au chocolat.' }),

    -- Boîte de nuit (elyzea_entreprises) : ingrédients et cocktails
    nc_rhum      = { label = 'Bouteille de rhum', weight = 800, stack = true, max = 20, icon = '🥃', description = 'Pour le bar de la boîte de nuit.' },
    nc_whisky    = { label = 'Bouteille de whisky', weight = 800, stack = true, max = 20, icon = '🥃', description = 'Pour le bar de la boîte de nuit.' },
    nc_vodka     = { label = 'Bouteille de vodka', weight = 800, stack = true, max = 20, icon = '🍶', description = 'Pour le bar de la boîte de nuit.' },
    nc_champagne = { label = 'Bouteille de champagne', weight = 1000, stack = true, max = 20, icon = '🍾', description = 'Pour le bar de la boîte de nuit.' },
    nc_citron    = { label = 'Citron vert', weight = 50, stack = true, max = 50, icon = '🍋', description = 'Pour le bar de la boîte de nuit.' },
    nc_glace     = { label = 'Glaçons', weight = 100, stack = true, max = 50, icon = '🧊', description = 'Pour le bar de la boîte de nuit.' },
    nc_soda      = { label = 'Soda (bar)', weight = 300, stack = true, max = 50, icon = '🥤', description = 'Pour le bar de la boîte de nuit.' },
    nc_energy    = { label = 'Boisson énergisante', weight = 300, stack = true, max = 50, icon = '⚡', description = 'Pour le bar de la boîte de nuit.' },
    nc_mojito      = food('Mojito', 300, 0, 20, { prop = { model = `prop_mojito`, pos = vec3(0.01, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) } }),
    nc_whiskycoca  = food('Whisky-coca', 300, 0, 20, { prop = { model = `prop_drink_whisky`, pos = vec3(0.01, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) } }),
    nc_vodkaenergy = food('Vodka énergie', 300, 0, 20, { prop = { model = `prop_cocktail`, pos = vec3(0.01, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) } }),
    nc_shot        = food('Shot', 60, 0, 5, { prop = { model = `prop_tequila`, pos = vec3(0.01, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) } }),
    nc_coupe       = food('Coupe de champagne', 150, 0, 10, { prop = { model = `prop_drink_champ`, pos = vec3(0.01, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) } }),

    -- Métiers de farm (elyzea_farm)
    buche_bois       = { label = 'Bûche de bois', weight = 1500, stack = true, max = 100, image = 'buche_bois.png', icon = '🪵',
        description = 'Bûche coupée par un bûcheron. Se revend au responsable du chantier.' },
}

-- ───────── Vêtements elyzea_clothing : 10 GRAMMES chacun ─────────
local CLOTHING_WEIGHT = 10
local clothes = {
    { 'vet_haut',       'Haut',               'tops' },
    { 'vet_tshirt',     'T-shirt',            'undershirts' },
    { 'vet_pantalon',   'Pantalon',           'pants' },
    { 'vet_chaussures', 'Chaussures',         'shoes' },
    { 'vet_sac',        'Sac',                'bags' },
    { 'vet_gilet',      'Gilet',              'vests' },
    { 'vet_gants',      'Gants',              'arms' },
    { 'vet_collier',    'Collier / cravate',  'chains' },
    { 'vet_masque',     'Masque',             'masks' },
    { 'vet_logo',       'Logo',               'decals' },
    { 'vet_chapeau',    'Chapeau',            'hats' },
    { 'vet_lunettes',   'Lunettes',           'glasses' },
    { 'vet_boucles',    'Boucles d\'oreilles','ears' },
    { 'vet_montre',     'Montre',             'watches' },
    { 'vet_bracelet',   'Bracelet',           'bracelets' },
}
for _, c in ipairs(clothes) do
    Items[c[1]] = {
        label = c[2], weight = CLOTHING_WEIGHT, stack = false, image = c[1] .. '.png', icon = '👕',
        clothing = c[3],
        description = 'Vêtement : glissez-le sur le personnage ou clic droit > Porter.',
        buttons = {
            { label = 'Porter',   export = 'elyzea_clothing.EquipFromSlot' },
            { label = 'Renommer', export = 'elyzea_clothing.RenameSlot', close = true },
        },
    }
end
Items.vet_sac.bonus = 10000 -- +10 KG de capacité quand il est porté
Items.vet_sac.description = 'Sac : +10 KG de capacité une fois porté.'

-- ───────── Pierres précieuses (ressource jewelry_heist : braquage de bijouterie, racheteurs) ─────────
-- Images : html/img/diamond.png, ruby.png, sapphire.png, emerald.png, amethyst.png (256 × 256, fond transparent)
Items.diamond  = { label = 'Diamant',   weight = 20, stack = true, image = 'diamond.png',  icon = '💎', description = 'Diamant taillé, pur et brillant. Se revend à un receleur.' }
Items.ruby     = { label = 'Rubis',     weight = 20, stack = true, image = 'ruby.png',     icon = '💎', description = 'Rubis rouge intense, taille coussin. Se revend à un receleur.' }
Items.sapphire = { label = 'Saphir',    weight = 20, stack = true, image = 'sapphire.png', icon = '💎', description = 'Saphir bleu profond, taille ovale. Se revend à un receleur.' }
Items.emerald  = { label = 'Émeraude',  weight = 20, stack = true, image = 'emerald.png',  icon = '💎', description = 'Émeraude verte, taille à degrés. Se revend à un receleur.' }
Items.amethyst = { label = 'Améthyste', weight = 20, stack = true, image = 'amethyst.png', icon = '💎', description = 'Améthyste violette, taille poire. Se revend à un receleur.' }

-- ───────── Mécano (ressource elyzea_meca) ─────────
-- Image : html/img/pont_roulant.png (256 × 256, fond transparent)
-- Utilisé à côté d'un véhicule garé sur un point d'atelier (mécanicien en service) : le pont est
-- posé sous le véhicule (levage, travail debout dessous). H à côté du pont : il revient dans l'inventaire.
Items.pont_roulant = { label = 'Pont roulant', weight = 5000, stack = false, close = true, image = 'pont_roulant.png', icon = '🛠️',
    description = 'Pont élévateur à deux colonnes (5 kg). Utilisez-le à côté d\'un véhicule garé sur un point d\'atelier ; H à côté du pont pour le reprendre.' }

-- ───────── Braquage de banque (ressource bank_heist) ─────────
-- Images : html/img/bank_laptop.png, bank_bag.png, bank_c4.png (256 × 256, fond transparent)
-- L'ordinateur n'est pas empilable : chacun a un numéro de série (métadonnée « serial »)
-- et ses tentatives de piratage sont enregistrées sur le serveur (table bh_laptops).
Items.bank_laptop = { label = 'Ordinateur de piratage', weight = 2500, stack = false, image = 'bank_laptop.png', icon = '💻',
    description = 'Ordinateur modifié pour pirater un coffre de banque. 3 tentatives par ordinateur.' }
Items.bank_bag    = { label = 'Sac de braqueur', weight = 800, stack = true, max = 5, image = 'bank_bag.png', icon = '🎒',
    description = 'Sac vide pour ramasser les billets d\'un coffre de banque.' }
Items.bank_c4     = { label = 'Charge C4', weight = 1200, stack = true, max = 5, image = 'bank_c4.png', icon = '🧨',
    description = 'Charge explosive pour forcer un coffre quand le piratage a échoué.' }

-- Téléphone clandestin NOIR X (ressource noirx) · image : html/img/noirphone.png
-- noirx l'enregistre lui-même comme utilisable ; il n'est jamais consommé.
Items.noirphone = { label = 'NOIR X', weight = 180, stack = false, image = 'noirphone.png', icon = '📱',
    description = 'Terminal clandestin sécurisé. Accès au réseau privé NOIR X.' }

-- ───────── Famille (ressource elyzea_famille) ─────────
-- Images : html/img/preservatif.png, pilule_contraceptive.png, implant_contraceptif.png, test_grossesse.png (256 × 256)
-- En vente : supérette (rayon « Santé ») et préréglage « Pharmacie » de l'éditeur de PNJ (admin_menu)
-- Utilisés et retirés par elyzea_famille lui-même, après vérification par le serveur (pas de consommation automatique).
Items.preservatif = { label = 'Préservatif', weight = 5, stack = true, max = 20, image = 'preservatif.png', icon = '🛡️', close = true,
    description = 'À cocher dans une demande de moment intime, ou à utiliser pendant le moment. Fiabilité : 98 %.' }
Items.pilule_contraceptive = { label = 'Pilule contraceptive', weight = 5, stack = true, max = 30, image = 'pilule_contraceptive.png', icon = '💊', close = true,
    description = 'Une prise protège 48 h (renouvelable dans les 12 dernières heures). « /contraception » pour voir votre état.' }
Items.implant_contraceptif = { label = 'Implant contraceptif', weight = 10, stack = true, max = 5, image = 'implant_contraceptif.png', icon = '💉',
    description = 'Posé par un EMS en service (menu ALT sur le patient). Protège 30 jours.' }
Items.test_grossesse = { label = 'Test de grossesse', weight = 20, stack = true, max = 10, image = 'test_grossesse.png', icon = '🧪', close = true,
    description = 'Résultat privé. Fiable à partir de 24 h après la conception (1 faux négatif sur 100).' }
-- Équipements bébé (ressource elyzea_bebe_modele) : jamais consommés
Items.porte_bebe_ventral = { label = 'Porte-bébé ventral', weight = 900, stack = false, max = 1, image = 'porte_bebe_ventral.png', icon = '🤱', close = true,
    description = 'Utiliser : équiper / retirer. Puis ALT sur le bébé › « Porte-bébé ventral ». Bébé contre la poitrine, mains libres.' }
Items.porte_bebe_dorsal = { label = 'Porte-bébé dorsal', weight = 1100, stack = false, max = 1, image = 'porte_bebe_dorsal.png', icon = '🎒', close = true,
    description = 'Utiliser : équiper / retirer. Puis ALT sur le bébé › « Porte-bébé dorsal ». Bébé dans le dos, mains libres.' }
Items.poussette = { label = 'Poussette', weight = 7500, stack = false, max = 1, image = 'poussette.png', icon = '🛒', close = true,
    description = 'Utiliser : sortir la poussette devant soi. ALT dessus : pousser, garer, installer le bébé, ranger.' }

-- Argent en billets : 1 000 $ = 1 g, une seule pile sans limite (pas de « inventaire plein »)
Items.black_money = { label = 'Argent sale', weight = 0, perGram = 1000, stack = true, max = 999999999, image = 'black_money.png', icon = '💵',
    description = 'Billets d\'origine douteuse. 1 000 $ = 1 g.' }
Items.markedbills = { label = 'Billets marqués', weight = 0, perGram = 1000, stack = true, max = 999999999, image = 'markedbills.png', icon = '💵',
    description = 'Liasses marquées par la banque. 1 000 $ = 1 g.' }
-- Casino (elyzea_casino) : jetons achetés / revendus au guichet, misés aux tables et à la roue. 1 000 jetons = 1 g
Items.jetons_casino = { label = 'Jetons de casino', weight = 0, perGram = 1000, stack = true, max = 999999999, image = 'jetons_casino.png', icon = '🎰',
    description = 'Jetons du casino. S\'achètent et se revendent au guichet, se misent au blackjack, à la roulette et à la roue de la fortune.' }

-- Tags (elyzea_tags) : peindre / effacer un graffiti
Items.spraycan = { label = 'Bombe de peinture', weight = 350, stack = true, max = 10, image = 'spraycan.png', icon = '🎨',
    description = 'Peins un tag sur un mur de ton quartier.' }
Items.sprayremover = { label = 'Solvant anti-graffiti', weight = 500, stack = true, max = 10, image = 'sprayremover.png', icon = '🧽',
    description = 'Efface un tag peint sur un mur.' }

-- Objets ignorés (l'argent liquide est un compte de la base Elyzea, pas un objet)
IgnoredItems = { money = true, testburger = true }

-- ───────── Images partagées ─────────
-- Objets sans image à leur nom : on réutilise une image existante de html/img.
-- Pour en ajouter : ['nom_objet'] = 'fichier.png'
ImageAlias = {
    jammer = 'radiojammer.png',
    weed_ak47 = 'weed_baggy.png', weed_amnesia = 'weed_baggy.png', ['weed_og-kush'] = 'weed_baggy.png',
    ['weed_purple-haze'] = 'weed_baggy.png', weed_skunk = 'weed_baggy.png', ['weed_white-widow'] = 'weed_baggy.png',
    weed_ak47_seed = 'weed_seed.png', weed_amnesia_seed = 'weed_seed.png', ['weed_og-kush_seed'] = 'weed_seed.png',
    ['weed_purple-haze_seed'] = 'weed_seed.png', weed_skunk_seed = 'weed_seed.png', ['weed_white-widow_seed'] = 'weed_seed.png',
    weed_pouch = 'weed_baggy.png', weed_leaf = 'weed.png', empty_weed_bag = 'weed_baggy_empty.png',
    coca_leaf = 'cocaineleaf.png', cokebaggy = 'cocaine_baggy.png', xtcbaggy = 'xtc_baggy.png',
    meth_chemicals = 'hydrochloricacid.png', metal_scrap = 'metalscrap.png',
    empty_evidence_bag = 'evidence.png', filled_evidence_bag = 'evidence.png', kit_gravure = 'cleaningkit.png',
    blood_bag = 'blood_bag_500.png', defibrillator = 'defibrilator.png', painkiller = 'painkillers.png',
    pizza = 'pizza_ham_slice.png', bread = 'WEAPON_BREAD.png', kurkakola = 'cola.png',
    weaponlicense = 'WEAPON_LICENSE.png',
    crowbar = 'WEAPON_CROWBAR.png', walking_stick = 'walkstick.png',
    advancedrepairkit = 'repairkit.png', trojan_usb = 'usb_device.png',
    at_scope_macro = 'at_scope_small.png', at_compensator = 'at_muzzle_tactical.png',
}
