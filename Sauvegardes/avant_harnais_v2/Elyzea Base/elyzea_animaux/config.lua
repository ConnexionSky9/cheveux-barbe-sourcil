-- =========================================================
--  ELYZEA ANIMAUX - CONFIGURATION INITIALE
--  Tout ce qui est marqué (menu) se change aussi en jeu :
--  admin_menu › Économie et services › Gestion des animaux.
--  Les valeurs du menu sont enregistrées en base (table
--  elyzea_animaux_config) et remplacent celles d'ici ; ce fichier
--  ne sert alors que de « valeurs par défaut » (bouton Restaurer).
--  Ce qui n'est PAS dans le menu (objets, touches, profils
--  d'animations) demande un redémarrage de la ressource.
-- =========================================================
Config = {}

Config.AdminResource = 'admin_menu'
Config.AdminPerms = {
    manage = 'animaux_manage',   -- vendeurs, prix, catalogue, équipements, besoins, ferme, diagnostic
    owned = 'animaux_owned',     -- animaux possédés : consulter, ranger, corriger, retirer
}
Config.Debug = false

-- Touche « Mes animaux » (Paramètres FiveM › Raccourcis › FiveM) et commande /animaux
Config.Keys = { menu = 'F7' }

-- Argent accepté chez les vendeurs (comptes de elyzea_core)
Config.Payments = { cash = 'Espèces', bank = 'Carte bancaire' }

-- ---------------------------------------------------------
--  Objets (déclarés dans elyzea_inventory/shared/items.lua)
-- ---------------------------------------------------------
Config.Items = {
    harness = 'pet_harness',   -- harnais (métadonnées : style, couleur) : rendu sur le chien quand on l'équipe
    leash = 'pet_leash',       -- laisse : reste dans l'inventaire tant qu'elle est tenue
    food = 'pet_food',         -- croquettes : faim
    treat = 'pet_treat',       -- friandise : un peu de faim, débloque les tours
    water = 'water',           -- bouteille d'eau (objet existant) : soif
    medkit = 'pet_medkit',     -- trousse vétérinaire : soins (et remet sur pattes un animal blessé)
    feed = 'farm_feed',        -- aliment pour bétail (ferme)
    egg = 'farm_egg',          -- œuf frais (production des poules)
    milk = 'bs_lait',          -- lait (objet existant du Burger Shot) : production des vaches
}

-- Effet réel des soins (points sur 100, enregistrés en base)
Config.Care = {
    food = { hunger = 40 },
    treat = { hunger = 10 },
    water = { thirst = 45 },
    medkit = { health = 50 },    -- un animal blessé (indisponible) redevient disponible avec cette santé
    useDistance = 3.5,           -- m entre le joueur et son animal
}

-- ---------------------------------------------------------
--  Réglages généraux (menu)
-- ---------------------------------------------------------
Config.Defaults = {
    general = {
        enabled = true,
        maxOwned = 3,              -- animaux par personnage
        maxOut = 1,                -- animaux sortis en même temps par personnage
        invincible = false,        -- false : un animal peut être blessé (il devient « indisponible » jusqu'aux soins)
        autoStoreDistance = 250,   -- m : propriétaire trop loin trop longtemps -> l'animal rentre (rangé)
        storeDelay = 30,           -- s au-delà de cette distance avant de ranger
    },
    follow = {
        distance = 2.2,            -- m derrière le propriétaire
        side = 0.9,                -- m sur le côté (évite qu'il marche dans les jambes)
        stuckTeleport = true,      -- animal bloqué loin et hors de vue : replacé près du propriétaire
        teleportDistance = 45,     -- m (seulement s'il est bloqué et hors de l'écran)
    },
    needs = {
        enabled = true,
        interval = 10,             -- minutes entre deux baisses
        hungerRate = 4,            -- points perdus par intervalle (sur 100), animal sorti
        thirstRate = 5,
        storedFactor = 0.0,        -- 0 : rien ne baisse quand l'animal est rangé (soigné à la maison)
        lowThreshold = 25,         -- en dessous : animal fatigué (plus lent, refuse les tours)
        damage = 6,                -- santé perdue par intervalle à 0 de faim ou de soif
        recoveryHours = 0,         -- 0 : un animal blessé reste indisponible jusqu'aux soins ; sinon guérit seul après N h
    },
    harness = { enabled = true, requireDog = true },
    leash = {
        enabled = true,
        requireItem = true,        -- la laisse doit être dans l'inventaire
        requireHarness = false,    -- false : accrochée au collier si pas de harnais
        length = 2.6,              -- m : distance de promenade
        breakDistance = 12,        -- m : au-delà (téléportation, chute…) la laisse se détache
    },
    vehicle = { enabled = true, boardDistance = 8 },
    exotic = {
        enabled = true,
        maxOwned = 1,              -- animaux exotiques par personnage
        requireItem = '',          -- objet obligatoire pour acheter (ex. un permis) ; vide = aucun
    },
    vet = { price = 250 },         -- soins au comptoir d'un vendeur « vétérinaire »
    accessories = {               -- vendus par les vendeurs qui ont « accessoires »
        harness = { enabled = true, price = 120 },
        leash   = { enabled = true, price = 60 },
        food    = { enabled = true, price = 15 },
        treat   = { enabled = true, price = 8 },
        medkit  = { enabled = true, price = 180 },
        feed    = { enabled = true, price = 10 },
    },
}

-- ---------------------------------------------------------
--  Harnais : styles dessinés sur le chien (aucun fichier 3D requis)
--  bands : sangles autour du corps (at = 'chest' poitrail, 'neck' encolure, 'belly' ventre)
--  width : largeur de la sangle (m) · back : sangle dorsale entre les bandes
-- ---------------------------------------------------------
Config.HarnessStyles = {
    { id = 'simple',   label = 'Sangle simple',      bands = { { at = 'chest', width = 0.045 } } },
    { id = 'h',        label = 'Harnais en H',       bands = { { at = 'neck', width = 0.035 }, { at = 'chest', width = 0.045 } }, back = true },
    { id = 'plastron', label = 'Harnais à plastron', bands = { { at = 'neck', width = 0.04 }, { at = 'chest', width = 0.09 }, { at = 'belly', width = 0.04 } }, back = true },
}
Config.HarnessColors = {
    { id = 'noir',   label = 'Noir',   rgb = { 22, 22, 24 } },
    { id = 'rouge',  label = 'Rouge',  rgb = { 170, 24, 30 } },
    { id = 'bleu',   label = 'Bleu',   rgb = { 28, 70, 170 } },
    { id = 'vert',   label = 'Vert',   rgb = { 34, 120, 52 } },
    { id = 'rose',   label = 'Rose',   rgb = { 220, 90, 150 } },
    { id = 'orange', label = 'Orange fluo', rgb = { 245, 120, 20 } },
    { id = 'camel',  label = 'Cuir camel', rgb = { 150, 96, 48 } },
}
Config.LeashColor = { 30, 28, 26, 255 }   -- couleur de la laisse dessinée

-- ---------------------------------------------------------
--  Profils de comportement (commandes par type d'animal)
--  Chaque commande essaie ses scénarios du jeu, puis son animation ;
--  si rien ne marche sur ce modèle, la commande est signalée au diagnostic.
-- ---------------------------------------------------------
Config.Profiles = {
    dog_large = {
        label = 'Chien (grand)', dog = true, harness = true, leash = true, vehicle = true,
        commands = {
            sit  = { label = 'Assis', scenarios = { 'WORLD_DOG_SITTING_ROTTWEILER', 'WORLD_DOG_SITTING_RETRIEVER', 'WORLD_DOG_SITTING_SHEPHERD' },
                     anim = { 'creatures@rottweiler@amb@world_dog_sitting@base', 'base' } },
            lie  = { label = 'Couché', anim = { 'creatures@rottweiler@amb@sleep_in_kennel@', 'sleep_in_kennel' } },
            bark = { label = 'Aboyer', scenarios = { 'WORLD_DOG_BARKING_ROTTWEILER', 'WORLD_DOG_BARKING_RETRIEVER', 'WORLD_DOG_BARKING_SHEPHERD' },
                     anim = { 'creatures@rottweiler@amb@world_dog_barking@idle_a', 'idle_a' }, duration = 6000 },
            paw  = { label = 'Donner la patte', trick = true, anim = { 'creatures@rottweiler@tricks@', 'paw_right_loop' }, duration = 5000 },
            beg  = { label = 'Faire le beau', trick = true, anim = { 'creatures@rottweiler@tricks@', 'beg_loop' }, duration = 5000 },
        },
        petting = { player = { 'creatures@rottweiler@tricks@', 'petting_franklin' }, pet = { 'creatures@rottweiler@tricks@', 'petting_chop' } },
        vehicleOffset = { 0.0, 0.0, 0.32 },
    },
    dog_small = {
        label = 'Chien (petit)', dog = true, harness = true, leash = true, vehicle = true,
        commands = {
            sit  = { label = 'Assis', scenarios = { 'WORLD_DOG_SITTING_SMALL' }, anim = { 'creatures@pug@amb@world_dog_sitting@base', 'base' } },
            bark = { label = 'Aboyer', scenarios = { 'WORLD_DOG_BARKING_SMALL' }, anim = { 'creatures@pug@amb@world_dog_barking@idle_a', 'idle_a' }, duration = 6000 },
        },
        vehicleOffset = { 0.0, 0.0, 0.42 },
    },
    cat = {
        label = 'Chat', harness = false, leash = false, vehicle = true,
        commands = {
            lie = { label = 'Se coucher', scenarios = { 'WORLD_CAT_SLEEPING_GROUND' }, anim = { 'creatures@cat@amb@world_cat_sleeping_ground@base', 'base' } },
        },
        vehicleOffset = { 0.0, 0.0, 0.42 },
        followFactor = 1.6,         -- un chat suit de plus loin
    },
    rabbit = {
        label = 'Lapin', vehicle = true,
        commands = { graze = { label = 'Grignoter', scenarios = { 'WORLD_RABBIT_EATING' } } },
        vehicleOffset = { 0.0, 0.0, 0.42 },
    },
    rodent = { label = 'Rongeur', vehicle = true, commands = {}, vehicleOffset = { 0.0, 0.0, 0.45 } },
    hen = { label = 'Volaille', vehicle = false, commands = { graze = { label = 'Picorer', scenarios = { 'WORLD_HEN_PECKING' } } } },
    pig = { label = 'Cochon', vehicle = false, commands = { graze = { label = 'Fouiller le sol', scenarios = { 'WORLD_PIG_GRAZING' } } } },
    cow = { label = 'Bovin', vehicle = false, commands = { graze = { label = 'Brouter', scenarios = { 'WORLD_COW_GRAZING' } } }, followFactor = 1.8 },
    feline = {
        label = 'Grand félin', vehicle = false,
        commands = { lie = { label = 'Se coucher', scenarios = { 'WORLD_MOUNTAIN_LION_REST' } } }, followFactor = 1.5,
    },
    canid_wild = {
        label = 'Canidé sauvage', vehicle = false,
        commands = { lie = { label = 'Se reposer', scenarios = { 'WORLD_COYOTE_REST' } }, bark = { label = 'Hurler', scenarios = { 'WORLD_COYOTE_HOWL' }, duration = 7000 } },
    },
    primate = { label = 'Primate', vehicle = true, commands = {}, vehicleOffset = { 0.0, 0.0, 0.1 } },
}

-- ---------------------------------------------------------
--  Espèces et pelages (menu : prix, activation, libellés, suppléments)
--  Un pelage = une vraie texture du modèle (composant c, modèle d, texture t),
--  ou un autre modèle de la même race (model = ...).
--  Seuls les pelages qui existent réellement sur le client sont proposés
--  (vérifiés avec GetNumberOfPedTextureVariations). addon = true : texture
--  d'un pack à installer, cachée tant que le scan staff ne l'a pas trouvée.
--  Les libellés sont à confirmer avec l'aperçu (admin › Catalogue › Aperçu).
-- ---------------------------------------------------------
local function robes(list) local out = {} for i, l in ipairs(list) do out[i] = { id = 't' .. (i - 1), label = l, c = 0, d = 0, t = i - 1 } end return out end

Config.Species = {
    -- Chiens
    rottweiler = { label = 'Rottweiler', cat = 'chien', profile = 'dog_large', model = 'a_c_rottweiler', price = 1600, radius = 0.21, neck = 0.13,
        variants = (function() local v = robes({ 'Noir et feu', 'Noir et feu foncé', 'Noir et acajou' })
            v[#v + 1] = { id = 'chop', label = 'Lignée « Chop »', model = 'a_c_chop', c = 0, d = 0, t = 0, extra = 250 }
            v[#v + 1] = { id = 'chop2', label = 'Lignée « Chop » (2)', model = 'a_c_chop_02', c = 0, d = 0, t = 0, extra = 250 }
            return v end)() },
    berger = { label = 'Berger allemand', cat = 'chien', profile = 'dog_large', model = 'a_c_shepherd', price = 1800, radius = 0.21, neck = 0.13,
        variants = robes({ 'Noir et feu (classique)', 'Gris loup', 'Noir et crème' }) },
    husky = { label = 'Husky', cat = 'chien', profile = 'dog_large', model = 'a_c_husky', price = 2000, radius = 0.21, neck = 0.14,
        variants = robes({ 'Gris et blanc', 'Roux et blanc', 'Noir et blanc' }) },
    retriever = { label = 'Retriever (labrador)', cat = 'chien', profile = 'dog_large', model = 'a_c_retriever', price = 1500, radius = 0.21, neck = 0.13,
        variants = robes({ 'Sable', 'Noir', 'Chocolat', 'Crème' }) },
    caniche = { label = 'Caniche', cat = 'chien', profile = 'dog_small', model = 'a_c_poodle', price = 1100, radius = 0.12, neck = 0.08,
        variants = robes({ 'Blanc' }) },
    carlin = { label = 'Carlin', cat = 'chien', profile = 'dog_small', model = 'a_c_pug', price = 1000, radius = 0.13, neck = 0.09,
        variants = (function() local v = robes({ 'Fauve', 'Noir', 'Fauve masque noir', 'Crème' })
            v[#v + 1] = { id = 'pug2', label = 'Fauve (morphologie 2)', model = 'a_c_pug_02', c = 0, d = 0, t = 0 }
            return v end)() },
    westie = { label = 'West Highland (westie)', cat = 'chien', profile = 'dog_small', model = 'a_c_westy', price = 1200, radius = 0.12, neck = 0.08,
        variants = robes({ 'Blanc', 'Blanc crème', 'Gris clair' }) },
    -- Chats (robes 3 et plus : pack de textures à installer, voir README « Pelages de chats »)
    chat = { label = 'Chat européen', cat = 'chat', profile = 'cat', model = 'a_c_cat_01', price = 700, radius = 0.09, neck = 0.06,
        variants = (function() local v = robes({ 'Tigré gris', 'Noir et blanc', 'Roux' })
            local extra = { 'Unicolore noir', 'Unicolore blanc', 'Tricolore (écaille de tortue)', 'Tacheté', 'Roux tigré clair', 'Bicolore gris et blanc', 'Crème' }
            for i, l in ipairs(extra) do v[#v + 1] = { id = 't' .. (i + 2), label = l, c = 0, d = 0, t = i + 2, addon = true } end
            return v end)() },
    lapin = { label = 'Lapin', cat = 'nac', profile = 'rabbit', model = 'a_c_rabbit_01', price = 250,
        variants = { { id = 'r1', label = 'Lapin de garenne', c = 0, d = 0, t = 0 }, { id = 'r2', label = 'Lapin (modèle 2)', model = 'a_c_rabbit_02', c = 0, d = 0, t = 0 } } },
    rat = { label = 'Rat domestique', cat = 'nac', profile = 'rodent', model = 'a_c_rat', price = 120, variants = robes({ 'Brun', 'Gris', 'Clair' }) },
    -- Exotiques
    chimpanze = { label = 'Chimpanzé', cat = 'exotique', exotic = true, profile = 'primate', model = 'a_c_chimp', price = 18000, fees = 2500,
        variants = { { id = 'c1', label = 'Chimpanzé', c = 0, d = 0, t = 0 }, { id = 'c2', label = 'Chimpanzé (modèle 2)', model = 'a_c_chimp_02', c = 0, d = 0, t = 0 } } },
    rhesus = { label = 'Macaque rhésus', cat = 'exotique', exotic = true, profile = 'primate', model = 'a_c_rhesus', price = 9000, fees = 1500, variants = robes({ 'Brun' }) },
    panthere = { label = 'Panthère noire', cat = 'exotique', exotic = true, profile = 'feline', model = 'a_c_panther', price = 45000, fees = 5000, variants = robes({ 'Noire' }) },
    puma = { label = 'Puma', cat = 'exotique', exotic = true, profile = 'feline', model = 'a_c_mtlion', price = 38000, fees = 5000,
        variants = { { id = 'p1', label = 'Fauve', c = 0, d = 0, t = 0 }, { id = 'p2', label = 'Fauve (modèle 2)', model = 'a_c_mtlion_02', c = 0, d = 0, t = 0 } } },
    coyote = { label = 'Coyote', cat = 'exotique', exotic = true, profile = 'canid_wild', model = 'a_c_coyote', price = 7000, fees = 1000,
        variants = { { id = 'k1', label = 'Gris fauve', c = 0, d = 0, t = 0 }, { id = 'k2', label = 'Coyote (modèle 2)', model = 'a_c_coyote_02', c = 0, d = 0, t = 0 } } },
    -- Ferme (achetables seulement chez un vendeur « ferme », désactivé par défaut)
    poule = { label = 'Poule', cat = 'ferme', farm = true, profile = 'hen', model = 'a_c_hen', price = 80, variants = robes({ 'Rousse' }) },
    cochon = { label = 'Cochon', cat = 'ferme', farm = true, profile = 'pig', model = 'a_c_pig', price = 900, variants = robes({ 'Rose', 'Rose tacheté', 'Brun', 'Noir' }) },
    vache = { label = 'Vache', cat = 'ferme', farm = true, profile = 'cow', model = 'a_c_cow', price = 3500, variants = robes({ 'Pie noire', 'Brune', 'Pie rouge', 'Blanche' }) },
}

Config.Categories = {
    { id = 'chien', label = 'Chiens', icon = '🐕' }, { id = 'chat', label = 'Chats', icon = '🐈' },
    { id = 'nac', label = 'Petits animaux', icon = '🐇' }, { id = 'exotique', label = 'Exotiques', icon = '🐆' },
    { id = 'ferme', label = 'Ferme', icon = '🐄' },
}

-- Espèces demandées mais SANS modèle dans le jeu de base (il faut un modèle addon) :
-- affichées au diagnostic pour ne pas faire croire qu'elles existent.
Config.MissingSpecies = { { label = 'Mouton', reason = 'aucun modèle a_c_sheep dans GTA V' }, { label = 'Chèvre', reason = 'aucun modèle a_c_goat dans GTA V' } }

-- ---------------------------------------------------------
--  Vendeurs PNJ par défaut (menu : tout est modifiable, ajout / suppression)
--  Aucun ne dépend de Cayo Perico. Les hauteurs sont recalées au sol en jeu.
-- ---------------------------------------------------------
Config.Vendors = {
    { id = 'animalerie_ls', label = 'Animalerie de Los Santos', enabled = true,
      x = 181.2, y = -925.5, z = 30.69, h = 235.0, model = 'a_f_y_hipster_02', scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
      catalog = { 'rottweiler', 'berger', 'husky', 'retriever', 'caniche', 'carlin', 'westie', 'chat', 'lapin', 'rat' },
      prices = {}, accessories = true, vet = true, distance = 2.5, blip = { enabled = true, sprite = 463, color = 5 } },
    { id = 'exotiques_ls', label = 'Animaux exotiques', enabled = true,
      x = -1165.0, y = -1566.0, z = 4.4, h = 125.0, model = 'a_m_m_hillbilly_02', scenario = 'WORLD_HUMAN_CLIPBOARD',
      catalog = { 'chimpanze', 'rhesus', 'panthere', 'puma', 'coyote' },
      prices = {}, accessories = false, vet = false, distance = 2.5, blip = { enabled = true, sprite = 442, color = 46 } },
    { id = 'ferme_vente', label = 'Vente d\'animaux de ferme', enabled = false,
      x = 2441.0, y = 4760.0, z = 34.3, h = 90.0, model = 'a_m_m_farmer_01', scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
      catalog = { 'poule', 'cochon', 'vache' }, prices = {}, accessories = true, vet = false, distance = 2.5, blip = { enabled = false, sprite = 141, color = 25 } },
}
Config.VendorModels = { 'a_f_y_hipster_02', 'a_m_y_hipster_01', 'a_m_m_hillbilly_02', 'a_m_m_farmer_01', 's_f_y_shop_mid', 'a_m_y_business_01', 'a_f_m_bevhills_01', 's_m_m_gardener_01', 'a_m_m_rurmeth_01', 'cs_old_man2' }
Config.VendorScenarios = { 'WORLD_HUMAN_STAND_IMPATIENT', 'WORLD_HUMAN_CLIPBOARD', 'WORLD_HUMAN_SMOKING', 'WORLD_HUMAN_AA_COFFEE', 'WORLD_HUMAN_STAND_MOBILE', 'WORLD_HUMAN_GUARD_STAND', '' }
Config.PreviewOffset = { 1.8, 0.8, 0.0 }   -- aperçu de l'animal : à droite du vendeur, un peu devant (m) ; pas là où se tient le joueur

-- ---------------------------------------------------------
--  Ferme (menu) : enclos indépendants de tout mapping
--  Les animaux d'enclos appartiennent à la ferme, jamais à un joueur.
-- ---------------------------------------------------------
Config.Farm = {
    enabled = true,
    activation = 150,               -- m : les animaux apparaissent quand un joueur est à moins de cette distance
    hungerRate = 3,                 -- points perdus toutes les 10 min (sur 100)
    produce = { enabled = true, cooldown = 30, minHunger = 50, minHealth = 60 },  -- minutes entre deux collectes par animal
    feedValue = 35,                 -- faim rendue par un aliment pour bétail
    careValue = 40,                 -- santé rendue par une trousse
    enclosures = {
        { id = 'grapeseed_vaches', label = 'Pré des vaches (Grapeseed)', x = 2441.0, y = 4760.0, z = 34.3, radius = 18.0, animals = { vache = 4 } },
        { id = 'grapeseed_basse_cour', label = 'Basse-cour (Grapeseed)', x = 2420.0, y = 4775.0, z = 34.6, radius = 9.0, animals = { poule = 6 } },
        { id = 'grapeseed_cochons', label = 'Porcherie (Grapeseed)', x = 2455.0, y = 4740.0, z = 34.3, radius = 8.0, animals = { cochon = 3 } },
    },
}
-- Production des animaux d'enclos (si activée) : objet donné à la collecte
Config.FarmProduce = {
    poule = { item = 'egg', label = 'Ramasser les œufs', count = { 1, 3 } },
    vache = { item = 'milk', label = 'Traire', count = { 1, 2 } },
}
