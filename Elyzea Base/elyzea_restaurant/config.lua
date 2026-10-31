-- =====================================================================
--  ELYZEA RESTAURANT - configuration centrale
--  Plusieurs restaurants (chacun : son métier, son compte de société, ses
--  grades, son personnel, sa carte, ses stations, ses commandes).
--  · Ici : les valeurs de départ, le catalogue des produits, les stations,
--    les mini-jeux, les réglages des commandes et de la livraison.
--  · Les restaurants se créent et se règlent EN JEU (admin_menu › Restaurants,
--    permission « resto_manage ») ou au démarrage via Config.Restaurants (plus bas).
--  · Le patron règle sa carte (produits proposés, prix) dans la tablette.
-- =====================================================================
Config = {}

Config.Keys = {
    menu = 'F6',
    interact = 38,                 -- E (code de contrôle GTA) sur les points
}

Config.Recruit = { distance = 5.0, timeout = 30, cooldown = 8 }
Config.Pay = { maxRate = 100000 }
Config.Points = { drawDistance = 25.0, defaultRadius = 1.2 }

Config.Statuses = {
    { id = 'available', label = 'Disponible',  color = '#22c55e' },
    { id = 'kitchen',   label = 'En cuisine',  color = '#f97316' },
    { id = 'counter',   label = 'Au comptoir', color = '#3b82f6' },
    { id = 'delivery',  label = 'En livraison', color = '#a855f7' },
    { id = 'break',     label = 'En pause',    color = '#94a3b8' },
}

-- Grades créés pour chaque nouveau restaurant (modifiables ensuite dans la tablette :
-- noms, salaires et PERMISSIONS, grade par grade).
Config.DefaultGrades = {
    { name = 'Commis',     level = 1, salary = 300, default = true, perms = { 'duty', 'tablet', 'orders', 'cook' } },
    { name = 'Cuisinier',  level = 2, salary = 380, perms = { 'duty', 'tablet', 'orders', 'cook', 'deliver' } },
    { name = 'Serveur',    level = 3, salary = 380, perms = { 'duty', 'tablet', 'orders', 'cook', 'deliver' } },
    { name = 'Gérant',     level = 4, salary = 750, perms = { 'duty', 'tablet', 'orders', 'cook', 'deliver', 'orders_manage', 'menu', 'open',
        'stash', 'sales_all', 'stats', 'direction', 'recruit', 'employees_view', 'history_view' } },
    { name = 'Patron',     level = 5, salary = 1100, perms = 'all' },
}

-- ---------------------------------------------------------------------
-- Catégories de la carte (ordre d'affichage)
-- ---------------------------------------------------------------------
Config.Categories = {
    { id = 'burgers',  label = 'Burgers',  icon = '🍔' },
    { id = 'pizzas',   label = 'Pizzas',   icon = '🍕' },
    { id = 'sides',    label = 'Accompagnements', icon = '🍟' },
    { id = 'drinks',   label = 'Boissons', icon = '🥤' },
    { id = 'desserts', label = 'Desserts', icon = '🍰' },
}

-- ---------------------------------------------------------------------
-- Stations de cuisine : chaque type accepte un ou plusieurs mini-jeux.
-- Le staff pose les stations en jeu (coordonnées) et choisit leurs types.
-- ---------------------------------------------------------------------
Config.StationTypes = {
    grill    = { label = 'Grill à burgers',  icon = '🔥', color = { 249, 115, 22 } },
    oven     = { label = 'Four à pizza',     icon = '🍕', color = { 239, 68, 68 } },
    fryer    = { label = 'Friteuse',         icon = '🍟', color = { 234, 179, 8 } },
    fountain = { label = 'Fontaine à boissons', icon = '🥤', color = { 59, 130, 246 } },
    pastry   = { label = 'Plan de pâtisserie', icon = '🍰', color = { 236, 72, 153 } },
}

-- ---------------------------------------------------------------------
-- Mini-jeux (le moteur est dans shared/games.lua + html/kitchen.js) :
-- burger · pizza · drink · dessert · fries. Pour en ajouter un : voir README.
--   minMs : durée minimale crédible d'une réussite (en dessous : refusée)
-- ---------------------------------------------------------------------
Config.MiniGames = {
    burger  = { label = 'Cuisson + montage du burger', minMs = 3500 },
    pizza   = { label = 'Garniture + cuisson au four', minMs = 3500 },
    drink   = { label = 'Remplissage au bon niveau',   minMs = 1200 },
    dessert = { label = 'Choix des bons ingrédients',  minMs = 1500 },
    fries   = { label = 'Cuisson des frites',          minMs = 1500 },
}

-- ---------------------------------------------------------------------
-- Catalogue des produits (commun à tous les restaurants ; chaque restaurant
-- choisit dans sa tablette lesquels il propose et à quel prix).
--   id          : identifiant unique (ne pas changer une fois en service)
--   item        : objet donné au client (déjà déclaré dans elyzea_inventory)
--   cat         : catégorie (Config.Categories)
--   price       : prix de départ (le patron le change ensuite)
--   image       : fichier de elyzea_inventory/html/img (vide : image de l'objet)
--   game        : mini-jeu · difficulty : 1 facile, 2 normal, 3 difficile
--   duration    : secondes pour réussir le mini-jeu · steps : nombre d'étapes
--   station     : type de station où le produit se prépare
--   default     : proposé à la création d'un restaurant
-- ---------------------------------------------------------------------
Config.Products = {
    -- Burgers
    { id = 'classic',  item = 'bs_burger_classic', cat = 'burgers', label = 'Le Classic', price = 25, desc = 'Steak, cheddar, salade, tomate, sauce maison.',
      game = 'burger', difficulty = 1, duration = 30, steps = 4, station = 'grill', default = true },
    { id = 'double',   item = 'bs_burger_double', cat = 'burgers', label = 'Double Cheese', price = 32, desc = 'Deux steaks, double cheddar, oignons, cornichons.',
      game = 'burger', difficulty = 2, duration = 30, steps = 5, station = 'grill', default = true },
    { id = 'bacon',    item = 'bs_burger_bacon', cat = 'burgers', label = 'Bacon Blaster', price = 34, desc = 'Steak, bacon croustillant, cheddar, oignons.',
      game = 'burger', difficulty = 2, duration = 30, steps = 5, station = 'grill', default = true },
    { id = 'chicken',  item = 'bs_burger_chicken', cat = 'burgers', label = 'Chicken Crunch', price = 28, desc = 'Poulet pané, salade, tomate, mayonnaise.',
      game = 'burger', difficulty = 1, duration = 30, steps = 4, station = 'grill', default = true },
    { id = 'veggie',   item = 'bs_burger_veggie', cat = 'burgers', label = 'Green Burger', price = 26, desc = 'Galette de légumes, salade, tomate, oignons rouges.',
      game = 'burger', difficulty = 1, duration = 30, steps = 4, station = 'grill' },
    { id = 'monster',  item = 'bs_burger_monster', cat = 'burgers', label = 'The Monster', price = 45, desc = 'Trois steaks, triple cheddar, bacon. Pour les affamés.',
      game = 'burger', difficulty = 3, duration = 35, steps = 6, station = 'grill' },
    -- Pizzas
    { id = 'pizza_ham', item = 'pizza', cat = 'pizzas', label = 'Pizza jambon', price = 30, desc = 'Sauce tomate, mozzarella, jambon. Servie en parts.', image = 'pizza_ham.png',
      game = 'pizza', difficulty = 2, duration = 35, steps = 4, station = 'oven', default = true },
    -- Accompagnements
    { id = 'fries',    item = 'bs_frites', cat = 'sides', label = 'Frites', price = 10, desc = 'Frites dorées, sel fin.',
      game = 'fries', difficulty = 1, duration = 20, steps = 1, station = 'fryer', default = true },
    -- Boissons
    { id = 'cola',     item = 'bs_drink_cola', cat = 'drinks', label = 'Cola', price = 8, desc = 'Le cola maison, servi frais.',
      game = 'drink', difficulty = 1, duration = 15, steps = 1, station = 'fountain', default = true },
    { id = 'orange',   item = 'bs_drink_orange', cat = 'drinks', label = 'Orangeade', price = 8, desc = 'Soda pétillant à l\'orange.',
      game = 'drink', difficulty = 1, duration = 15, steps = 1, station = 'fountain', default = true },
    { id = 'lemon',    item = 'bs_drink_lemon', cat = 'drinks', label = 'Citronnade glacée', price = 9, desc = 'Citronnade maison avec glaçons.',
      game = 'drink', difficulty = 2, duration = 15, steps = 1, station = 'fountain' },
    { id = 'icetea',   item = 'bs_drink_icetea', cat = 'drinks', label = 'Thé glacé pêche', price = 9, desc = 'Thé infusé à froid, saveur pêche.',
      game = 'drink', difficulty = 2, duration = 15, steps = 1, station = 'fountain' },
    { id = 'shake',    item = 'bs_drink_shake', cat = 'drinks', label = 'Milkshake fraise', price = 12, desc = 'Milkshake à la fraise et chantilly.',
      game = 'drink', difficulty = 3, duration = 15, steps = 1, station = 'fountain', default = true },
    { id = 'coffee',   item = 'bs_drink_coffee', cat = 'drinks', label = 'Café', price = 6, desc = 'Café serré, servi chaud.',
      game = 'drink', difficulty = 2, duration = 15, steps = 1, station = 'fountain' },
    -- Desserts
    { id = 'sundae',   item = 'bs_dessert_sundae', cat = 'desserts', label = 'Sundae caramel', price = 11, desc = 'Glace vanille, caramel, noisettes.',
      game = 'dessert', difficulty = 1, duration = 20, steps = 3, station = 'pastry', default = true },
    { id = 'donut',    item = 'bs_dessert_donut', cat = 'desserts', label = 'Donut glacé', price = 7, desc = 'Glaçage rose et vermicelles.',
      game = 'dessert', difficulty = 1, duration = 20, steps = 3, station = 'pastry', default = true },
    { id = 'cookie',   item = 'bs_dessert_cookie', cat = 'desserts', label = 'Cookie géant', price = 6, desc = 'Pépites de chocolat, tout juste sorti du four.',
      game = 'dessert', difficulty = 1, duration = 20, steps = 3, station = 'pastry' },
    { id = 'cheesecake', item = 'bs_dessert_cheesecake', cat = 'desserts', label = 'Cheesecake', price = 12, desc = 'Coulis de fruits rouges.',
      game = 'dessert', difficulty = 2, duration = 25, steps = 4, station = 'pastry' },
    { id = 'muffin',   item = 'bs_dessert_muffin', cat = 'desserts', label = 'Muffin chocolat', price = 7, desc = 'Cœur fondant au chocolat.',
      game = 'dessert', difficulty = 2, duration = 20, steps = 4, station = 'pastry' },
}

-- ---------------------------------------------------------------------
-- Commandes
-- ---------------------------------------------------------------------
Config.Orders = {
    maxLines = 12,            -- produits différents par commande
    maxQty = 10,              -- quantité maximale d'un produit
    maxUnits = 25,            -- unités au total par commande
    maxActivePerCustomer = 2, -- commandes non livrées en même temps par client
    maxPerEmployee = 3,       -- commandes prises en charge en même temps par un employé
    orderDistance = 3.0,      -- le client est à moins de X m du point de commande
    methods = { 'bank', 'cash' },
    expireMinutes = 60,       -- commande jamais prise en charge : annulée et remboursée après X minutes
    notifyOffDuty = false,    -- prévenir aussi les employés hors service
    maxPrice = 100000,
    historyLimit = 40,
}

-- Cuisine : unités préparées par mini-jeu réussi (ex. 2 : une commande de 3 colas = 2 mini-jeux)
Config.Kitchen = {
    unitsPerGame = 2,
    stationDistance = 2.5,     -- l'employé reste près de la station pendant le mini-jeu
    graceSeconds = 4,          -- marge réseau ajoutée à la durée d'un mini-jeu
}

-- ---------------------------------------------------------------------
-- Sac de commande et livraison
-- ---------------------------------------------------------------------
Config.Bag = {
    item = 'restaurant_bag',   -- objet déclaré dans elyzea_inventory/shared/items.lua
}
Config.Delivery = {
    distance = 3.0,            -- l'employé est à moins de X m du client pour lui remettre le sac
}

Config.Stash = { slots = 60, weight = 300 }   -- coffre du restaurant (kg)

-- ---------------------------------------------------------------------
-- Restaurants créés au démarrage (facultatif). Un restaurant déjà en base
-- (même « job ») n'est jamais modifié ni recréé : le réglage en jeu prime.
-- Exemple (retirez les -- pour l'utiliser) :
-- ---------------------------------------------------------------------
Config.Restaurants = {
    -- {
    --     name = 'Pizza This', job = 'resto_pizzathis', society = 'resto_pizzathis', matPrefix = 'PT-',
    --     address = 'Vespucci', logo = '🍕', color = '#ef4444',
    --     points = {
    --         order  = { x = 0.0, y = 0.0, z = 0.0, h = 0.0 },     -- point de commande (comptoir)
    --         manage = { x = 0.0, y = 0.0, z = 0.0, h = 0.0 },     -- bureau (tablette)
    --         stash  = { x = 0.0, y = 0.0, z = 0.0, h = 0.0 },     -- coffre
    --         stations = {
    --             { x = 0.0, y = 0.0, z = 0.0, h = 0.0, types = { 'oven' } },
    --             { x = 0.0, y = 0.0, z = 0.0, h = 0.0, types = { 'fountain', 'pastry' } },
    --         },
    --     },
    --     products = { 'pizza_ham', 'cola', 'orange', 'sundae' },   -- vide : produits « default »
    --     enabled = true,
    -- },
}
