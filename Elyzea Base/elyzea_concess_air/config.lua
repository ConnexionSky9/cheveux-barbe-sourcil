Config = {}

-- =====================================================================
--  TOUCHES (modifiables par chaque joueur : Paramètres > Raccourcis > FiveM)
-- =====================================================================
Config.Keys = {
    tablet = 'F6',
}

-- Clé de véhicule (objet elyzea_inventory, déjà déclaré). La touche U (elyzea_core) ouvre / ferme avec cette clé.
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
Config.CategoryVehicleType = { helicos = 'heli', avions = 'plane', jets = 'plane', acrobatie = 'plane', utilitaires = 'plane' }

-- Image par défaut d'un modèle du jeu de base (si aucune image n'est donnée)
Config.ImageUrl = 'https://docs.fivem.net/vehicles/%s.webp'

-- =====================================================================
--  VALEURS DE DÉPART (premier démarrage)
-- =====================================================================
Config.Defaults = {
    enabled = true,
    job = {
        name = 'planedealer', label = 'Elyzea Aviation', type = 'planedealer', defaultDuty = false, offDutyPay = false,
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
        { id = 'helicos', label = 'Hélicoptères' }, { id = 'avions', label = 'Avions de tourisme' },
        { id = 'jets', label = 'Jets privés' },      { id = 'acrobatie', label = 'Voltige' },
        { id = 'utilitaires', label = 'Utilitaires' },
    },
    -- Aéroport international de Los Santos (positions approximatives, à ajuster dans le menu admin)
    zones = {
        { type = 'service',      label = 'Bureau',                 x = -1046.5, y = -2876.9, z = 13.9, h = 150.0, radius = 1.5 },
        { type = 'presentation', label = 'Hangar · emplacement 1', x = -1001.4, y = -3002.6, z = 13.9, h = 60.0,  radius = 8.0 },
        { type = 'presentation', label = 'Hélisurface',            x = -1112.3, y = -2884.0, z = 13.9, h = 150.0, radius = 6.0 },
        { type = 'delivery',     label = 'Livraison (tarmac)',     x = -1032.0, y = -3018.0, z = 13.9, h = 60.0,  radius = 8.0 },
        { type = 'garage',       label = 'Hangar privé',           x = -1037.5, y = -2865.6, z = 13.9, h = 150.0, radius = 1.5 },
        { type = 'garage_spawn', label = 'Sortie du hangar',       x = -1046.0, y = -2971.0, z = 13.9, h = 60.0,  radius = 8.0 },
        { type = 'parking',      label = 'Rangement',              x = -1068.0, y = -2985.0, z = 13.9, h = 60.0,  radius = 12.0 },
    },
    settings = {
        commission = 10,            -- % de chaque vente pour le vendeur (le reste va au compte du métier)
        societyDeposit = true,      -- verser au compte du métier (elyzea_core)
        offerTimeout = 60,          -- secondes pour accepter une proposition
        platePrefix = 'AV',         -- début des plaques (2 à 4 lettres), complété par des chiffres
        delivery = 'spawn',         -- 'spawn' : livré sur le parking ; 'garage' : rangé directement au garage
        ownGarage = true,           -- garage de la concession (désactive si tu utilises seulement elyzea_garage)
        showBlip = true,
    },
    showroom = {},                  -- [emplacement] = véhicule exposé (rempli depuis la tablette)
}

-- Catalogue de départ (base du jeu). Ensuite : tablette direction.
Config.DefaultCatalog = {
    { model = 'maverick',   label = 'Maverick',          price = 780000,  category = 'helicos' },
    { model = 'frogger',    label = 'Frogger',           price = 1100000, category = 'helicos' },
    { model = 'supervolito', label = 'SuperVolito',      price = 1650000, category = 'helicos' },
    { model = 'swift',      label = 'Swift',             price = 1500000, category = 'helicos' },
    { model = 'volatus',    label = 'Volatus',           price = 2200000, category = 'helicos' },
    { model = 'havok',      label = 'Havok',             price = 450000,  category = 'helicos' },
    { model = 'dodo',       label = 'Dodo (hydravion)',  price = 500000,  category = 'avions' },
    { model = 'duster',     label = 'Duster',            price = 275000,  category = 'avions' },
    { model = 'mammatus',   label = 'Mammatus',          price = 300000,  category = 'avions' },
    { model = 'velum',      label = 'Velum',             price = 450000,  category = 'avions' },
    { model = 'velum2',     label = 'Velum 5 places',    price = 550000,  category = 'avions' },
    { model = 'cuban800',   label = 'Cuban 800',         price = 240000,  category = 'avions' },
    { model = 'vestra',     label = 'Vestra',            price = 950000,  category = 'jets' },
    { model = 'luxor',      label = 'Luxor',             price = 1650000, category = 'jets' },
    { model = 'luxor2',     label = 'Luxor Deluxe',      price = 2500000, category = 'jets' },
    { model = 'nimbus',     label = 'Nimbus',            price = 1900000, category = 'jets' },
    { model = 'shamal',     label = 'Shamal',            price = 1150000, category = 'jets' },
    { model = 'miljet',     label = 'Miljet',            price = 1700000, category = 'jets' },
    { model = 'stunt',      label = 'Mallard',           price = 250000,  category = 'acrobatie' },
    { model = 'besra',      label = 'Besra',             price = 1150000, category = 'acrobatie' },
    { model = 'howard',     label = 'Howard NX-25',      price = 1300000, category = 'acrobatie' },
    { model = 'microlight', label = 'Ultralight',        price = 95000,   category = 'acrobatie' },
    { model = 'cargobob2',  label = 'Cargobob (civil)',  price = 1800000, category = 'utilitaires' },
    { model = 'skylift',    label = 'Skylift',           price = 1500000, category = 'utilitaires' },
}
