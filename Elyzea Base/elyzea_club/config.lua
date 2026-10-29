-- =====================================================================
--  ELYZEA BOÎTE DE NUIT - configuration
--  Les boîtes de nuit (plusieurs établissements, chacun son métier, son compte,
--  ses grades, ses points, sa carte, ses enceintes) se créent et se règlent
--  EN JEU, et sont gardées en base :
--   · admin_menu › Boîtes de nuit (staff, permission « club_manage ») ;
--   · tablette de l'établissement (carte, prix, stock, entrée, listes, musique,
--     personnel, grades, permissions, finances).
--  Ici : les limites, les valeurs de départ et les textes.
-- =====================================================================
Config = {}

Config.Keys = {
    menu = 'F6',
    interact = 38,                 -- E (code de contrôle GTA) sur les points
}

Config.Recruit = { distance = 5.0, timeout = 30, cooldown = 8 }
Config.Pay = { maxRate = 100000 }
Config.Points = { drawDistance = 25.0, defaultRadius = 1.5 }

Config.Statuses = {
    { id = 'available', label = 'Disponible',  color = '#22c55e' },
    { id = 'bar',       label = 'Au bar',      color = '#f59e0b' },
    { id = 'door',      label = 'À l\'entrée', color = '#3b82f6' },
    { id = 'dj',        label = 'Aux platines', color = '#d946ef' },
    { id = 'vip',       label = 'Carré VIP',   color = '#eab308' },
    { id = 'break',     label = 'En pause',    color = '#94a3b8' },
}

-- Grades créés pour chaque nouvelle boîte de nuit (modifiables ensuite dans la tablette :
-- noms, salaires, et surtout PERMISSIONS : le patron choisit par exemple quels grades
-- ont le droit d'utiliser les enceintes « music »).
Config.DefaultGrades = {
    { name = 'Serveur', level = 1, salary = 350, default = true, perms = { 'duty', 'tablet', 'bar' } },
    { name = 'Videur',  level = 2, salary = 400, perms = { 'duty', 'tablet', 'door', 'lists' } },
    { name = 'DJ',      level = 3, salary = 450, perms = { 'duty', 'tablet', 'music' } },
    { name = 'Gérant',  level = 4, salary = 800, perms = { 'duty', 'tablet', 'bar', 'door', 'lists', 'music', 'speakers', 'menu', 'stock', 'open',
        'announce', 'stash', 'sales_all', 'stats', 'direction', 'recruit', 'employees_view', 'history_view' } },
    { name = 'Patron',  level = 5, salary = 1200, perms = 'all' },
}

-- ---------------------------------------------------------------------
-- Bar : boissons vendues (objets déjà déclarés dans elyzea_inventory).
-- price = prix de vente de départ (le patron le change dans la tablette)
-- cost  = prix d'achat d'une unité de stock, payé par le compte de la boîte
-- ---------------------------------------------------------------------
Config.Drinks = {
    { item = 'nc_mojito',      label = 'Mojito',                 cat = 'Cocktails',  price = 45,  cost = 12 },
    { item = 'nc_whiskycoca',  label = 'Whisky-coca',            cat = 'Cocktails',  price = 40,  cost = 11 },
    { item = 'nc_vodkaenergy', label = 'Vodka énergie',          cat = 'Cocktails',  price = 40,  cost = 11 },
    { item = 'nc_shot',        label = 'Shot',                   cat = 'Shots',      price = 15,  cost = 4 },
    { item = 'nc_coupe',       label = 'Coupe de champagne',     cat = 'Champagne',  price = 60,  cost = 18 },
    { item = 'nc_champagne',   label = 'Bouteille de champagne', cat = 'Bouteilles', price = 450, cost = 140 },
    { item = 'nc_whisky',      label = 'Bouteille de whisky',    cat = 'Bouteilles', price = 300, cost = 90 },
    { item = 'nc_vodka',       label = 'Bouteille de vodka',     cat = 'Bouteilles', price = 280, cost = 85 },
    { item = 'nc_rhum',        label = 'Bouteille de rhum',      cat = 'Bouteilles', price = 260, cost = 80 },
    { item = 'nc_soda',        label = 'Soda',                   cat = 'Softs',      price = 10,  cost = 2 },
    { item = 'nc_energy',      label = 'Boisson énergisante',    cat = 'Softs',      price = 15,  cost = 4 },
}
Config.Bar = {
    distance = 4.0,          -- le client est à moins de X m du serveur
    barDistance = 6.0,       -- le serveur est à moins de X m du point « Bar »
    timeout = 45,            -- secondes pour accepter la commande
    maxLines = 10, maxQty = 20,
    maxPrice = 100000,
    maxStock = 5000,         -- stock maximal par boisson
    startStock = 20,         -- stock offert à la création de la boîte
}

-- ---------------------------------------------------------------------
-- Entrée : point « Entrée » (dehors) et point « Intérieur » facultatif.
-- Avec un point Intérieur, payer l'entrée téléporte à l'intérieur, et E à
-- l'intérieur ressort. Sans point Intérieur, l'entrée vend seulement un bracelet.
-- ---------------------------------------------------------------------
Config.Entry = {
    maxFee = 10000,
    defaultFee = 50,
    wristband = 4 * 3600,    -- un bracelet payé reste valable X secondes (entrer / sortir sans repayer)
    checkDistance = 4.0,     -- contrôle du videur : personne à moins de X m
    maxBanDays = 365,
}

Config.Announce = { cooldown = 600, maxLength = 200 }   -- annonce à toute la ville
Config.Stash = { slots = 60, weight = 300 }              -- coffre de la boîte (kg)

-- ---------------------------------------------------------------------
-- Musique : enceintes posées par la boîte, playlist YouTube qui défile.
-- Seuls les employés de LA boîte qui a posé les enceintes, avec la permission
-- « music » de leur grade, peuvent les utiliser.
-- ---------------------------------------------------------------------
Config.Music = {
    maxSpeakers = 10,        -- enceintes par boîte
    maxTracks = 100,         -- titres par playlist
    controlDistance = 60.0,  -- distance maximale d'une enceinte de la boîte pour piloter la musique
    placeDistance = 12.0,    -- distance maximale entre le joueur et l'enceinte qu'il pose
    defaultRange = 35.0,     -- portée du son autour des enceintes (m)
    minRange = 8.0, maxRange = 120.0,
    defaultVolume = 70,
    maxActive = 2,           -- musiques de boîtes différentes entendues en même temps par un joueur
    unknownSkip = 600,       -- durée inconnue (personne n'écoute) : titre suivant au bout de X s
    models = {
        { model = 'ba_prop_battle_club_speaker_large', label = 'Grande enceinte de club' },
        { model = 'ba_prop_battle_club_speaker_med',   label = 'Enceinte de club moyenne' },
        { model = 'ba_prop_battle_club_speaker_small', label = 'Petite enceinte de club' },
        { model = 'prop_speaker_06',                   label = 'Enceinte sur pied' },
        { model = 'prop_speaker_05',                   label = 'Enceinte de sono' },
        { model = 'none',                              label = 'Invisible (enceintes déjà dans la carte)' },
    },
}
