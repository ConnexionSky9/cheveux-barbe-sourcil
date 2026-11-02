-- =====================================================================
--  ELYZEA FOURRIÈRE · CONFIGURATION (le seul fichier à modifier)
--  Trois fourrières indépendantes, chacune avec ses PNJ et ses places de
--  sortie (posés dans l'éditeur de map, admin_menu → PNJ → rôle « Fourrière ») :
--    land = terrestre (voitures + motos)   air = aérienne (hélicoptères + avions)   sea = maritime (bateaux)
--  Monnaie (dollars / pesos) : elyzea_change/config.lua → Config.Payment.Businesses
--    FourriereVoiture / FourriereAvion / FourriereBateau (Currency + ForceCurrency).
-- =====================================================================
Config = {}

-- Catégories de véhicules et fourrière qui les garde
Config.Classes = {
    car   = { label = 'Voiture',     icon = '🚗', kind = 'land', spawnType = 'automobile' },
    moto  = { label = 'Moto',        icon = '🏍️', kind = 'land', spawnType = 'bike' },
    heli  = { label = 'Hélicoptère', icon = '🚁', kind = 'air',  spawnType = 'heli' },
    plane = { label = 'Avion',       icon = '✈️', kind = 'air',  spawnType = 'plane' },
    boat  = { label = 'Bateau',      icon = '🚤', kind = 'sea',  spawnType = 'boat' },
}

Config.Kinds = {
    land = { label = 'Fourrière terrestre', short = 'terrestre', business = 'FourriereVoiture', blip = 68, blipColor = 47 },
    air  = { label = 'Fourrière aérienne',  short = 'aérienne',  business = 'FourriereAvion',   blip = 359, blipColor = 47 },
    sea  = { label = 'Fourrière maritime',  short = 'maritime',  business = 'FourriereBateau',  blip = 410, blipColor = 47 },
}

-- Prix en dollars (convertis en pesos par elyzea_change si le joueur paie en pesos)
--   impound   : véhicule non détruit (sortie immédiate)
--   destroyed : véhicule complètement détruit (réparation puis retour au garage)
Config.Prices = {
    car   = { impound = 500,  destroyed = 1500 },
    moto  = { impound = 300,  destroyed = 900 },
    heli  = { impound = 2500, destroyed = 7500 },
    plane = { impound = 3000, destroyed = 9000 },
    boat  = { impound = 1200, destroyed = 3500 },
}

-- Durée de la réparation d'un véhicule détruit (minutes réelles, comptées par la base de données :
-- elles continuent pendant les déconnexions et les redémarrages du serveur)
Config.RepairMinutes = 60

-- Garage où revient un véhicule réparé (nom enregistré dans player_vehicles.garage,
-- le même que elyzea_garage : Config.GarageName) et nom affiché par catégorie
Config.ReturnGarage = 'public'
Config.ReturnGarageLabel = {
    car = 'Garage public', moto = 'Garage public', heli = 'Garage aérien', plane = 'Garage aérien', boat = 'Garage maritime',
}

-- L'argent payé va à une société (nil = à personne). Clé = raison de la mise en fourrière.
Config.Society = { police = 'police', destroyed = nil }

-- Distances
Config.UseDistance = 6.0          -- joueur ↔ PNJ pour payer
Config.SpotFreeRadius = { car = 3.0, moto = 2.0, heli = 9.0, plane = 14.0, boat = 7.0 }   -- place libre si aucun véhicule dans ce rayon

-- Véhicule « complètement détruit » (relevé par le serveur au moment de la mise en fourrière)
Config.Destroyed = {
    engine = -1000.0,   -- moteur à ou sous cette valeur (en feu / explosé : -4000)
    body = 0.0,         -- ou carrosserie à ou sous cette valeur
}

-- Épaves dans le monde : un véhicule possédé détruit (explosé, moteur ou carrosserie à zéro) part à la fourrière
Config.Wrecks = {
    enabled = true,
    scanEvery = 3000,       -- ms, côté joueur : véhicules détruits autour de lui
    scanRadius = 120.0,
    deleteAfter = 20,       -- s avant que l'épave disparaisse du monde
}

-- Vérification des réparations terminées (s) ; aussi à la connexion d'un joueur et à l'ouverture
Config.RepairCheckEvery = 60

-- Modèles fantômes affichés pendant la pose des places de sortie (admin_menu)
Config.GhostModels = { car = 'blista', moto = 'bati', heli = 'frogger', plane = 'dodo', boat = 'dinghy', all = 'blista' }
