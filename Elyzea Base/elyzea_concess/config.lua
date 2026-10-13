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

-- ---------------------------------------------------------------------
-- Import automatique des véhicules du jeu
-- À la première ouverture de l'administration automobile par un staff, TOUS les véhicules
-- chargés par le jeu (base + ajoutés par des ressources) sont ajoutés au catalogue global,
-- triés par catégorie selon leur classe GTA, avec un prix calculé (classe + performances).
-- Tout reste modifiable ensuite (catégorie, prix, nom, retrait). Le bouton « Synchroniser
-- avec le jeu » ajoute plus tard les nouveaux véhicules sans toucher aux modèles existants.
-- ---------------------------------------------------------------------
Config.Import = {
    auto = true,
    -- Classe GTA → catégorie (nom exact). Classe absente = non importée
    -- (14 bateaux, 15 hélicoptères, 16 avions, 17 services, 18 urgences, 19 militaire, 21 trains, 22 monoplaces)
    classes = {
        [0] = 'Compactes', [1] = 'Berlines', [2] = 'SUV', [3] = 'Coupés', [4] = 'Muscle', [5] = 'Véhicules anciens',
        [6] = 'Sportives', [7] = 'Supercars', [8] = 'Motos', [9] = 'Tout-terrain', [10] = 'Utilitaires', [11] = 'Utilitaires',
        [12] = 'Utilitaires', [13] = 'Vélos', [20] = 'Utilitaires',
    },
    -- Catégories créées si elles n'existent pas encore
    newCategories = { { name = 'Muscle', icon = '💪' }, { name = 'Vélos', icon = '🚲' } },
    -- Prix moyen par classe : le prix va de 60 % (moins performant de la classe) à 150 % (plus performant), arrondi à 500 $
    basePrice = {
        [0] = 18000, [1] = 32000, [2] = 60000, [3] = 75000, [4] = 55000, [5] = 160000, [6] = 190000, [7] = 950000,
        [8] = 22000, [9] = 45000, [10] = 140000, [11] = 40000, [12] = 38000, [13] = 900, [20] = 95000,
    },
    -- Ces modèles vont dans une autre catégorie que celle de leur classe
    override = {
        ['Véhicules électriques'] = { 'voltic', 'raiden', 'cyclone', 'cyclone2', 'tezeract', 'neon', 'imorgon', 'khamelion', 'surge', 'dilettante',
            'iwagen', 'omnisegt', 'virtue', 'powersurge', 'buffalo5' },
        ['Luxe'] = { 'cognoscenti', 'cognoscenti2', 'cog55', 'cog552', 'superd', 'windsor', 'windsor2', 'stafford', 'deity', 'jubilee',
            'schafter3', 'schafter4', 'schafter5', 'schafter6', 'exemplar', 'stretch', 'patriot2', 'baller5', 'baller6', 'xls', 'xls2' },
    },
    -- Jamais importés (armés, arène, missions, véhicules spéciaux)
    exclude = {
        'oppressor', 'oppressor2', 'deluxo', 'scramjet', 'vigilante', 'stromberg', 'toreador', 'ruiner2', 'ruiner3', 'voltic2', 'technical', 'technical2',
        'technical3', 'insurgent', 'insurgent2', 'insurgent3', 'nightshark', 'halftrack', 'apc', 'khanjali', 'rhino', 'dune2', 'dune3', 'dune4', 'dune5',
        'blazer5', 'boxville5', 'tampa3', 'menacer', 'caracara', 'marshall', 'monster', 'rcbandito', 'minitank', 'chernobog', 'trailersmall2',
        'bruiser', 'bruiser2', 'bruiser3', 'brutus', 'brutus2', 'brutus3', 'cerberus', 'cerberus2', 'cerberus3', 'deathbike', 'deathbike2', 'deathbike3',
        'dominator4', 'dominator5', 'dominator6', 'impaler2', 'impaler3', 'impaler4', 'imperator', 'imperator2', 'imperator3', 'issi4', 'issi5', 'issi6',
        'monster3', 'monster4', 'monster5', 'scarab', 'scarab2', 'scarab3', 'slamvan4', 'slamvan5', 'slamvan6', 'zr380', 'zr3802', 'zr3803',
        'speedo2', 'pbus2', 'zhaba', 'veto', 'veto2', 'kart',
    },
}
