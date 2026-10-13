-- =====================================================================
--  ELYZEA CONCESSION - configuration
--  Les concessions, le catalogue global, les catégories, les prix, les points,
--  les emplacements d'exposition, les grades et les permissions se gèrent EN JEU
--  (gardés en base) :
--   · admin_menu › Administration automobile (staff, permission « dealer_manage ») ;
--   · tablette de la concession (prix, exposition, personnel, finance).
--  Ici : les limites, les valeurs de départ et les textes.
-- =====================================================================
Config = {}

Config.Keys = {
    menu = 'F6',
    interact = 38,                 -- E (code de contrôle GTA) sur les points
}

-- Clé physique remise à l'acheteur (objet déjà déclaré dans elyzea_inventory)
Config.KeyItem = 'concess_key'
-- Garage public où le véhicule est enregistré à l'achat (elyzea_garage : Config.GarageName)
Config.GarageName = 'public'
-- Image par défaut des véhicules du jeu de base (%s = nom du modèle)
Config.ImageUrl = 'https://docs.fivem.net/vehicles/%s.webp'

Config.Plate = { prefix = '', length = 8 }       -- plaque : lettres et chiffres aléatoires, unique
Config.Recruit = { distance = 5.0, timeout = 30, cooldown = 8 }
Config.Sale = {
    distance = 6.0,                -- client à moins de X m du vendeur
    timeout = 60,                  -- secondes pour accepter l'offre
    maxPrice = 50000000,
    deliveryDistance = 80.0,       -- le client doit être à moins de X m de la zone de sortie
}
Config.Pay = { maxRate = 100000 }
Config.Points = { drawDistance = 25.0, defaultRadius = 1.5 }
Config.Display = { drawDistance = 120.0 }       -- distance d'affichage des véhicules exposés

Config.Statuses = {
    { id = 'available', label = 'Disponible', color = '#22c55e' },
    { id = 'client',    label = 'Avec un client', color = '#f59e0b' },
    { id = 'delivery',  label = 'Livraison', color = '#3b82f6' },
    { id = 'office',    label = 'Bureau', color = '#a855f7' },
    { id = 'busy',      label = 'Occupé', color = '#ef4444' },
}

-- Grades créés pour chaque nouvelle concession (modifiables ensuite dans la tablette)
Config.DefaultGrades = {
    { name = 'Employé', level = 1, salary = 400, default = true, perms = { 'duty', 'tablet', 'catalog' } },
    { name = 'Commercial', level = 2, salary = 600, perms = { 'duty', 'tablet', 'catalog', 'sell', 'delivery' } },
    { name = 'Responsable', level = 3, salary = 900, perms = { 'duty', 'tablet', 'catalog', 'sell', 'delivery', 'discount', 'sales_all', 'display', 'prices', 'stats',
        'direction', 'employees_view', 'history_view' } },
    { name = 'Directeur', level = 4, salary = 1300, perms = 'all' },
}

-- Catégories proposées au premier démarrage (modifiables / désactivables en jeu)
Config.DefaultCategories = {
    { name = 'Compactes', icon = '🚗' }, { name = 'Berlines', icon = '🚘' }, { name = 'Coupés', icon = '🏎️' },
    { name = 'Sportives', icon = '🏁' }, { name = 'Supercars', icon = '⚡' }, { name = 'Luxe', icon = '💎' },
    { name = 'SUV', icon = '🚙' }, { name = 'Tout-terrain', icon = '⛰️' }, { name = 'Motos', icon = '🏍️' },
    { name = 'Utilitaires', icon = '🚐' }, { name = 'Véhicules anciens', icon = '🕰️' }, { name = 'Véhicules de collection', icon = '🏆' },
    { name = 'Véhicules électriques', icon = '🔋' },
}

-- Classe GTA → type de véhicule pour CreateVehicleServerSetter
Config.ClassType = { [8] = 'bike', [13] = 'bike', [14] = 'boat', [15] = 'heli', [16] = 'plane', [21] = 'train' }
