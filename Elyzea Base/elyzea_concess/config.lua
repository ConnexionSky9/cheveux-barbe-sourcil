Config = {}

-- =====================================================================
--  TOUCHES (modifiables par chaque joueur : Paramètres > Raccourcis > FiveM)
-- =====================================================================
Config.Keys = {
    tablet = 'F6',
    lock = 'U',     -- verrouiller / déverrouiller son véhicule (avec sa clé dans l'inventaire)
}

-- Clé de véhicule (objet ox_inventory, à déclarer : voir install/ox_inventory_items.lua)
Config.KeyItem = 'concess_key'

-- =====================================================================
--  PERMISSIONS PAR GRADE (tablette direction ou admin_menu > Métiers > Concession)
-- =====================================================================
Config.Permissions = {
    { key = 'sell',        label = 'Vendre' },
    { key = 'present',     label = 'Mettre en exposition (showroom)' },
    { key = 'showroom',    label = 'Gérer les emplacements du showroom' },
    { key = 'catalog',     label = 'Ajouter / modifier les véhicules' },
    { key = 'prices',      label = 'Modifier les prix' },
    { key = 'hide',        label = 'Masquer / afficher' },
    { key = 'delete',      label = 'Supprimer un véhicule' },
    { key = 'categories',  label = 'Gérer les catégories' },
    { key = 'finances',    label = 'Voir les finances' },
    { key = 'employees',   label = 'Gérer les employés' },
    { key = 'permissions', label = 'Gérer les permissions' },
}

-- =====================================================================
--  TYPES DE ZONES (posées dans admin_menu > Métiers > Concession > Zones)
-- =====================================================================
Config.ZoneTypes = {
    { key = 'service',      label = 'Prise de service' },
    { key = 'presentation', label = 'Emplacement d\'exposition (showroom)' },
    { key = 'delivery',     label = 'Livraison des véhicules vendus' },
    { key = 'garage',       label = 'Garage (sortir ses véhicules)' },
    { key = 'garage_spawn', label = 'Sortie du garage' },
    { key = 'parking',      label = 'Rangement au garage' },
}

-- Type de véhicule pour la création côté serveur, selon la catégorie
Config.CategoryVehicleType = { motos = 'bike', bateaux = 'boat', helicos = 'heli', avions = 'plane' }

-- Image par défaut d'un modèle du jeu de base (si aucune image n'est donnée)
Config.ImageUrl = 'https://docs.fivem.net/vehicles/%s.webp'

-- =====================================================================
--  VALEURS DE DÉPART (premier démarrage)
-- =====================================================================
Config.Defaults = {
    enabled = true,
    job = {
        name = 'cardealer', label = 'Premium Deluxe Motorsport', type = 'cardealer', defaultDuty = false, offDutyPay = false,
        grades = {
            { id = 'stagiaire', label = 'Stagiaire',        payment = 50 },
            { id = 'vendeur',   label = 'Vendeur',          payment = 80 },
            { id = 'confirme',  label = 'Vendeur confirmé', payment = 110 },
            { id = 'manager',   label = 'Manager',          payment = 150 },
            { id = 'directeur', label = 'Directeur',        payment = 200, isboss = true },
        },
    },
    -- [grade] = permissions ; discount = remise maximum (%)
    perms = {
        ['0'] = { present = true, discount = 0 },
        ['1'] = { sell = true, present = true, discount = 5 },
        ['2'] = { sell = true, present = true, discount = 10 },
        ['3'] = { sell = true, present = true, showroom = true, catalog = true, prices = true, hide = true, categories = true, finances = true, employees = true, discount = 15 },
        ['4'] = { sell = true, present = true, showroom = true, catalog = true, prices = true, hide = true, delete = true, categories = true, finances = true, employees = true, permissions = true, discount = 30 },
    },
    categories = {
        { id = 'compacts',  label = 'Compactes' },  { id = 'coupes',  label = 'Coupés' },
        { id = 'berlines',  label = 'Berlines' },   { id = 'sports',  label = 'Sportives' },
        { id = 'supercars', label = 'Supercars' },  { id = 'muscle',  label = 'Muscle' },
        { id = 'suv',       label = 'SUV' },        { id = 'offroad', label = 'Tout-terrain' },
        { id = 'motos',     label = 'Motos' },      { id = 'utilitaires', label = 'Utilitaires' },
        { id = 'luxe',      label = 'Luxe' },
    },
    -- Premium Deluxe Motorsport (positions approximatives, à ajuster en jeu)
    zones = {
        { type = 'service',      label = 'Bureau',             x = -31.2,  y = -1106.6, z = 26.4, h = 70.0,  radius = 1.5 },
        { type = 'presentation', label = 'Podium central',     x = -44.6,  y = -1097.0, z = 26.0, h = 120.0, radius = 3.0 },
        { type = 'presentation', label = 'Vitrine gauche',     x = -47.5,  y = -1092.0, z = 26.0, h = 160.0, radius = 3.0 },
        { type = 'presentation', label = 'Vitrine droite',     x = -38.5,  y = -1100.5, z = 26.0, h = 70.0,  radius = 3.0 },
        { type = 'delivery',     label = 'Parking de livraison', x = -29.8, y = -1089.4, z = 26.0, h = 340.0, radius = 3.0 },
        { type = 'garage',       label = 'Garage',             x = -46.5,  y = -1081.3, z = 26.7, h = 70.0,  radius = 1.5 },
        { type = 'garage_spawn', label = 'Sortie du garage',   x = -52.4,  y = -1076.1, z = 26.6, h = 70.0,  radius = 3.0 },
        { type = 'parking',      label = 'Rangement',          x = -48.6,  y = -1071.0, z = 26.6, h = 70.0,  radius = 5.0 },
    },
    settings = {
        commission = 10,            -- % de chaque vente pour le vendeur (le reste va au compte du métier)
        societyDeposit = true,      -- verser au compte du métier (Renewed-Banking)
        offerTimeout = 60,          -- secondes pour accepter une proposition
        platePrefix = 'EL',         -- début des plaques (2 à 4 lettres), complété par des chiffres
        delivery = 'spawn',         -- 'spawn' : livré sur le parking ; 'garage' : rangé directement au garage
        ownGarage = true,           -- garage de la concession (désactive si tu utilises qbx_garages)
        showBlip = true,
    },
    showroom = {},                  -- [emplacement] = véhicule exposé (rempli depuis la tablette)
}

-- Catalogue de départ (base du jeu). Ensuite : tablette direction.
Config.DefaultCatalog = {
    { model = 'blista',     label = 'Blista',            price = 18000,   category = 'compacts' },
    { model = 'brioso',     label = 'Brioso R/A',        price = 22000,   category = 'compacts' },
    { model = 'issi2',      label = 'Issi',              price = 16000,   category = 'compacts' },
    { model = 'panto',      label = 'Panto',             price = 12000,   category = 'compacts' },
    { model = 'prairie',    label = 'Prairie',           price = 19000,   category = 'compacts' },
    { model = 'f620',       label = 'F620',              price = 85000,   category = 'coupes' },
    { model = 'felon',      label = 'Felon',             price = 65000,   category = 'coupes' },
    { model = 'jackal',     label = 'Jackal',            price = 58000,   category = 'coupes' },
    { model = 'oracle2',    label = 'Oracle XS',         price = 72000,   category = 'coupes' },
    { model = 'sentinel2',  label = 'Sentinel XS',       price = 60000,   category = 'coupes' },
    { model = 'zion',       label = 'Zion',              price = 55000,   category = 'coupes' },
    { model = 'asea',       label = 'Asea',              price = 21000,   category = 'berlines' },
    { model = 'fugitive',   label = 'Fugitive',          price = 32000,   category = 'berlines' },
    { model = 'premier',    label = 'Premier',           price = 25000,   category = 'berlines' },
    { model = 'schafter2',  label = 'Schafter',          price = 68000,   category = 'berlines' },
    { model = 'tailgater',  label = 'Tailgater',         price = 54000,   category = 'berlines' },
    { model = 'washington', label = 'Washington',        price = 30000,   category = 'berlines' },
    { model = 'banshee',    label = 'Banshee',           price = 145000,  category = 'sports' },
    { model = 'carbonizzare', label = 'Carbonizzare',    price = 175000,  category = 'sports' },
    { model = 'comet2',     label = 'Comet',             price = 160000,  category = 'sports' },
    { model = 'elegy2',     label = 'Elegy RH8',         price = 120000,  category = 'sports' },
    { model = 'feltzer2',   label = 'Feltzer',           price = 150000,  category = 'sports' },
    { model = 'jester',     label = 'Jester',            price = 190000,  category = 'sports' },
    { model = 'sultan',     label = 'Sultan',            price = 95000,   category = 'sports' },
    { model = 'adder',      label = 'Adder',             price = 1000000, category = 'supercars' },
    { model = 'entityxf',   label = 'Entity XF',         price = 795000,  category = 'supercars' },
    { model = 'infernus',   label = 'Infernus',          price = 440000,  category = 'supercars' },
    { model = 'turismor',   label = 'Turismo R',         price = 500000,  category = 'supercars' },
    { model = 'zentorno',   label = 'Zentorno',          price = 725000,  category = 'supercars' },
    { model = 'dominator',  label = 'Dominator',         price = 75000,   category = 'muscle' },
    { model = 'gauntlet',   label = 'Gauntlet',          price = 70000,   category = 'muscle' },
    { model = 'phoenix',    label = 'Phoenix',           price = 52000,   category = 'muscle' },
    { model = 'sabregt',    label = 'Sabre Turbo',       price = 48000,   category = 'muscle' },
    { model = 'baller',     label = 'Baller',            price = 90000,   category = 'suv' },
    { model = 'cavalcade',  label = 'Cavalcade',         price = 60000,   category = 'suv' },
    { model = 'granger',    label = 'Granger',           price = 70000,   category = 'suv' },
    { model = 'huntley',    label = 'Huntley S',         price = 110000,  category = 'suv' },
    { model = 'bifta',      label = 'Bifta',             price = 40000,   category = 'offroad' },
    { model = 'dubsta3',    label = 'Dubsta 6x6',        price = 220000,  category = 'offroad' },
    { model = 'mesa3',      label = 'Mesa',              price = 55000,   category = 'offroad' },
    { model = 'rebel2',     label = 'Rebel',             price = 38000,   category = 'offroad' },
    { model = 'akuma',      label = 'Akuma',             price = 28000,   category = 'motos' },
    { model = 'bati',       label = 'Bati 801',          price = 32000,   category = 'motos' },
    { model = 'faggio2',    label = 'Faggio',            price = 4000,    category = 'motos' },
    { model = 'sanchez',    label = 'Sanchez',           price = 12000,   category = 'motos' },
    { model = 'burrito3',   label = 'Burrito',           price = 45000,   category = 'utilitaires' },
    { model = 'speedo',     label = 'Speedo',            price = 42000,   category = 'utilitaires' },
    { model = 'cogcabrio',  label = 'Cognoscenti Cabrio', price = 180000, category = 'luxe' },
    { model = 'exemplar',   label = 'Exemplar',          price = 200000,  category = 'luxe' },
    { model = 'superd',     label = 'Super Diamond',     price = 250000,  category = 'luxe' },
}
