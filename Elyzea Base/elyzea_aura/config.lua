Config = {}

-- 'auto' (recommandé : détecte la base Elyzea, QBCore ou ESX) | 'elyzea' | 'esx' | 'qb' | 'standalone'
Config.Framework = 'auto'

-- Se déplacer (marcher, courir, conduire) avec le téléphone ouvert.
-- Clic droit maintenu = regarder autour. Chaque joueur peut le désactiver dans Réglages > Général.
Config.MoveWhileOpen = true

-- Heure affichée sur le téléphone :
-- 'real' = heure réelle (celle de l'ordinateur du joueur) | 'game' = heure du jeu
Config.ClockMode = 'real'

-- Touche d'ouverture (modifiable par chaque joueur dans Paramètres > Raccourcis > FiveM)
Config.OpenKey = 'F1'

-- Exiger un item "phone" dans l'inventaire (elyzea_inventory, ESX ou QBCore détectés automatiquement)
Config.RequireItem = false
Config.ItemName = 'phone'

-- Format des numéros (# = chiffre aléatoire)
Config.NumberFormat = '555-####'

-- Système vocal pour les appels : 'pma-voice' | 'mumble-voip' | 'saltychat' | 'none'
Config.Voice = 'pma-voice'

-- Appareil photo et caméra (photos + vidéos, directement dans la galerie)
-- Le viseur affiche le jeu en direct dans le téléphone : screenshot-basic n'est plus nécessaire.
Config.Camera = {
    Enabled = true,
    -- 'presigned' (recommandé avec Fivemanage) : le serveur demande un lien d'envoi à usage unique,
    --              puis le téléphone envoie le fichier directement. Rapide, fiable, et la clé reste secrète.
    -- 'server'    : le fichier transite par ton serveur (autres hébergeurs, webhook Discord)
    -- 'client'    : envoi direct avec la clé (déconseillé : la clé est visible côté joueur)
    UploadMethod = 'presigned',
    PresignedUrl = 'https://api.fivemanage.com/api/presigned-url?fileType=%s', -- %s = image ou video
    ImageUrl = 'https://api.fivemanage.com/api/image',
    VideoUrl = 'https://api.fivemanage.com/api/video',
    ImageField = 'file',       -- nom du champ d'envoi (Fivemanage : 'file' ; Discord : 'files[]')
    VideoField = 'file',
    -- Colle ici ta clé API Fivemanage (fivemanage.com > Tokens), entre les guillemets
    Headers = { Authorization = 'TA_CLE_API_FIVEMANAGE' },
    ResponsePath = 'url',      -- Discord : 'attachments.1.url'
    MaxVideoSeconds = 20,      -- durée maximale d'une vidéo
    VideoBitrate = 1500000,    -- qualité vidéo (bits/s) : plus haut = plus lourd
    FlipY = false,             -- mets true si le viseur s'affiche à l'envers
    Selfie = {
        Distance = 0.95,       -- distance caméra / visage (mètres), réglable en jeu à la molette
        MinDistance = 0.55,
        MaxDistance = 1.8,
        Fov = 50.0,
    },
}

-- Itoune : musique YouTube / Spotify, entendue autour du joueur en mode haut-parleur (aucune ressource externe nécessaire)
Config.Itoune = {
    Distance = 12.0,           -- portée en mètres quand le haut-parleur est activé
    MaxVolume = 0.6,           -- volume maximum (0.0 à 1.0)
    -- Clé API YouTube Data v3 (gratuite, console.cloud.google.com) : nécessaire pour les liens Spotify,
    -- qui sont convertis en recherche YouTube. Les liens YouTube fonctionnent sans clé.
    YouTubeApiKey = '',
}

-- Étincelle : application de rencontre
Config.Dating = {
    MinAge = 18,
    MaxPhotos = 4,
}

-- Services d'urgence joignables depuis l'app "Urgences"
Config.Services = {
    { id = 'police',   label = 'Police',      job = 'police',   color = '#8E7CFF', icon = 'shield' },
    { id = 'ambulance',label = 'Secours',     job = 'ambulance',color = '#FF8FA3', icon = 'cross' },
    { id = 'mechanic', label = 'Dépannage',   job = 'mechanic', color = '#F5C77E', icon = 'wrench' },
    { id = 'taxi',     label = 'Taxi',        job = 'taxi',     color = '#7ED6C1', icon = 'car' },
}
Config.AlertBlipDuration = 90 -- secondes

-- Destinations rapides de l'app Plans
Config.Places = {
    { label = 'Commissariat de Mission Row', coords = vector3(428.9, -984.5, 30.7) },
    { label = 'Hôpital Pillbox Hill',         coords = vector3(298.6, -584.5, 43.3) },
    { label = 'Banque centrale',              coords = vector3(150.2, -1040.2, 29.4) },
    { label = 'Garage Benny\'s',              coords = vector3(-205.6, -1308.6, 31.3) },
    { label = 'Aéroport de Los Santos',       coords = vector3(-1037.0, -2737.0, 20.2) },
}

-- Banque
Config.Bank = {
    Enabled = true,
    MinTransfer = 1,
    MaxTransfer = 1000000,
    OfflineTransfers = true, -- virer à un joueur déconnecté (crédité directement en base)
}

-- Sécurité du téléphone (code + Face ID)
Config.Security = {
    Salt = 'change-moi-elyzea',  -- mets une phrase unique à ton serveur
    MaxAttempts = 5,             -- essais avant blocage
    LockoutSeconds = 30,         -- durée du blocage
}

-- AuraDrop : partager son numéro avec les joueurs proches
Config.AuraDrop = {
    Enabled = true,
    Distance = 6.0, -- mètres
}

-- Réglages par défaut d'un nouveau téléphone
Config.DefaultSettings = {
    setup = false,        -- false = l'intro de premier démarrage s'affiche
    lang = 'fr',          -- 'fr' | 'en' | 'es'
    theme = 'dark',       -- 'dark' | 'light' | 'auto' (suit l'heure du jeu)
    wallpaper = 'halo',
    accent = 'plasma',
    iconStyle = 'prisme', -- 'prisme' | 'verre' | 'mono'
    clockStyle = 'stack', -- 'stack' | 'line' | 'minimal'
    frame = 'titane',     -- 'titane' | 'graphite' | 'nacre' | 'aurore'
    edgeLight = true,
    faceid = false,
    lockOnClose = true,
    showBankWidget = true,
    auraDrop = true,
    deviceName = '',
    cardName = '',
    ringtone = 'cristal',
    silent = false,
    airplane = false,
    notifications = true,
    notifPreview = true,
    moveWithPhone = true, -- se déplacer avec le téléphone ouvert  -- le téléphone remonte en bas à droite pour afficher les notifications
    zoom = 100,
    installed = {}        -- applications téléchargées depuis Appli
}

-- Limites anti-abus
Config.Limits = {
    MessageLength = 500,
    PostLength = 280,
    AdLength = 400,
    NoteLength = 4000,
    ContactsMax = 200,
    TracksMax = 150,
}

-- Applications téléchargeables depuis "Appli"
Config.StoreApps = { 'birdy', 'instapick', 'itoune', 'etincelle', 'livrezy', 'helpmecano', 'garage', 'carplay' }

-- =========================================================
--  Livrézy : courses livrées par un PNJ en voiture
-- =========================================================
Config.Delivery = {
    Enabled = true,
    Fee = 25,                       -- frais de livraison ($)
    PayWith = { 'bank', 'cash' },   -- moyens de paiement proposés
    PrepTime = { 20, 40 },          -- préparation (secondes, min / max) avant le départ du livreur
    MinSpawnDistance = 150.0,       -- le livreur part au moins à cette distance du joueur
    MaxSpawnDistance = 350.0,       -- et au plus à cette distance (au-delà, le jeu ne charge pas la route)
    DriveSpeed = 17.0,              -- vitesse du livreur (m/s, ~60 km/h)
    DrivingStyle = 786603,          -- conduite prudente (respecte la route)
    Timeout = 480,                  -- au-delà (secondes), la commande est remboursée
    StuckSeconds = 15,              -- sécurité : s'il ne se rapproche plus pendant 15 s, il est replacé à côté du joueur
    MaxDriveSeconds = 60,           -- trajet maximum (secondes) avant d'être replacé à côté ; 0 = désactivé
    MaxItems = 20,                  -- articles maximum par commande
    MaxPerItem = 10,
    Vehicles = { 'blista', 'panto', 'issi2', 'asea' },
    Peds = { 's_m_y_busboy_01', 'a_m_y_hipster_01', 'a_f_y_hipster_02', 'a_m_y_business_02' },
    -- Images des articles dans l'app : %s = nom de l'item (elyzea_inventory)
    ImagePath = 'nui://elyzea_inventory/html/img/%s.png',

    -- Points de départ des livreurs (le plus proche du joueur est choisi)
    Shops = {
        { label = 'Up-n-Atom Burger, Vinewood', coords = vector3(81.3, 274.6, 110.2) },
        { label = 'Pizza This, Little Seoul', coords = vector3(-562.9, -894.4, 25.0) },
        { label = 'Bean Machine, Pillbox Hill', coords = vector3(124.6, -1036.6, 29.3) },
        { label = '24/7, Strawberry', coords = vector3(26.2, -1347.6, 29.5) },
        { label = 'Burger Shot, Del Perro', coords = vector3(-1182.9, -884.1, 13.8) },
        { label = 'LTD Gasoline, Mirror Park', coords = vector3(1163.4, -323.8, 69.2) },
        { label = '24/7, Sandy Shores', coords = vector3(1961.2, 3740.6, 32.3) },
        { label = '24/7, Paleto Bay', coords = vector3(1729.2, 6414.1, 35.0) },
    },

    -- Catalogue : 'name' doit être le nom exact de l'item dans ton inventaire.
    -- Les prix sont volontairement plus élevés qu'en supérette ou chez les métiers de restauration.
    Categories = {
        { id = 'meals', label = 'Repas', items = {
            { name = 'burger', label = 'Burger maison', price = 22 },
            { name = 'sandwich', label = 'Sandwich club', price = 16 },
            { name = 'tosti', label = 'Croque-monsieur', price = 14 },
            { name = 'pizza', label = 'Pizza margherita', price = 28 },
        } },
        { id = 'snacks', label = 'Snacks', items = {
            { name = 'twerks_candy', label = 'Barre Twerks', price = 7 },
            { name = 'snikkel_candy', label = 'Barre Snikkel', price = 7 },
            { name = 'chips', label = 'Chips', price = 6 },
            { name = 'donut', label = 'Donut', price = 8 },
        } },
        { id = 'drinks', label = 'Boissons', items = {
            { name = 'water_bottle', label = 'Eau minérale', price = 5 },
            { name = 'kurkakola', label = 'Kurkakola', price = 7 },
            { name = 'sprunk', label = 'Sprunk', price = 7 },
            { name = 'coffee', label = 'Café', price = 8 },
        } },
        { id = 'alcohol', label = 'Alcool', items = {
            { name = 'beer', label = 'Bière', price = 12 },
            { name = 'wine', label = 'Vin rouge', price = 30 },
            { name = 'whiskey', label = 'Whisky', price = 45 },
            { name = 'vodka', label = 'Vodka', price = 40 },
        } },
    },
}

-- =========================================================
--  HelpMécano : dépannage par un mécanicien PNJ
-- =========================================================
Config.Mechanic = {
    Enabled = true,
    PayWith = { 'bank', 'cash' },
    DispatchDelay = { 8, 15 },      -- délai (secondes) avant le départ de la dépanneuse
    MinSpawnDistance = 150.0,
    MaxSpawnDistance = 350.0,
    DriveSpeed = 18.0,
    DrivingStyle = 786603,
    Timeout = 480,                  -- au-delà (secondes), l'intervention est remboursée
    StuckSeconds = 15,              -- sécurité : si la dépanneuse ne se rapproche plus pendant 15 s, elle est replacée à côté du véhicule
    MaxDriveSeconds = 60,           -- trajet maximum (secondes) avant d'être replacée à côté ; 0 = désactivé
    SearchRadius = 25.0,            -- distance max pour trouver le véhicule du joueur
    MaxVehicleDistance = 300.0,     -- un véhicule plus loin que ça ne peut pas être dépanné (rapprochez-vous)
    Truck = 'towtruck',             -- 'towtruck', 'towtruck2' ou 'flatbed'
    Peds = { 's_m_y_xmech_02', 's_m_m_autoshop_01', 's_m_y_xmech_01' },

    -- Bloquer l'app quand de vrais mécaniciens sont en service (pour favoriser le RP)
    BlockIfMechanicsOnline = false,
    MechanicJob = 'mechanic',

    -- Services : prix ($) et durée de l'intervention (secondes)
    Services = {
        { id = 'clean',  label = 'Nettoyage',          price = 150,  duration = 10, desc = 'Lavage complet de la carrosserie et des vitres.' },
        { id = 'repair', label = 'Réparation',         price = 850,  duration = 16, desc = 'Moteur, carrosserie, pneus et réservoir remis à neuf.' },
        { id = 'flip',   label = 'Remise sur roues',   price = 300,  duration = 8,  desc = 'Le véhicule retourné est remis sur ses roues.' },
        { id = 'full',   label = 'Formule complète',   price = 1100, duration = 24, desc = 'Remise sur roues, réparation et nettoyage en une seule visite.' },
    },

    -- Garages de départ (le plus proche du joueur est choisi)
    Garages = {
        { label = 'Benny\'s Original Motor Works', coords = vector3(-205.6, -1308.6, 31.3) },
        { label = 'Los Santos Customs, La Mesa', coords = vector3(731.6, -1088.9, 22.2) },
        { label = 'Los Santos Customs, Burton', coords = vector3(-337.4, -136.9, 39.0) },
        { label = 'Los Santos Customs, aéroport', coords = vector3(-1155.5, -2007.2, 13.2) },
        { label = 'Beeker\'s Garage, Paleto Bay', coords = vector3(110.9, 6626.4, 31.8) },
        { label = 'Garage de Sandy Shores', coords = vector3(1174.8, 2640.2, 37.8) },
    },
}

-- =========================================================
--  Garage : voir ses véhicules et se faire livrer par un voiturier PNJ
--  (tables utilisées : player_vehicles pour la base Elyzea / QBCore, owned_vehicles pour ESX)
-- =========================================================
Config.Garage = {
    Enabled = true,
    Price = 250,                    -- prix de la livraison ($)
    PayWith = { 'bank', 'cash' },
    DispatchDelay = { 10, 20 },     -- temps (secondes) pour sortir le véhicule du garage
    MinSpawnDistance = 150.0,
    MaxSpawnDistance = 350.0,
    DriveSpeed = 16.0,
    DrivingStyle = 786603,
    StuckSeconds = 15,              -- bloqué ou perdu 15 s : replacé à côté du joueur
    MaxDriveSeconds = 60,
    Timeout = 480,
    Peds = { 's_m_y_valet_01', 's_m_m_autoshop_02', 'a_m_y_business_03' },
    -- Noms affichés des garages (clé = nom technique enregistré en base)
    Labels = {
        pillboxgarage = 'Garage de Pillbox Hill',
        motelgarage = 'Garage du motel',
        legionsquare = 'Legion Square',
        spanishave = 'Spanish Avenue',
        caears24 = 'Caears 24',
        sapcounsel = 'San Andreas Avenue',
        haanparking = 'Parking Haan',
        palomino = 'Palomino Avenue',
        airportpublic = 'Aéroport',
        sandyshores = 'Sandy Shores',
        paletogarage = 'Paleto Bay',
    },
}

-- =========================================================
--  ElyzeaCarPlay : tablette de bord + contrôle à distance depuis le téléphone
-- =========================================================
Config.CarPlay = {
    Enabled = true,
    Key = 'F7',                  -- touche par défaut (chaque joueur peut la changer dans Paramètres > Raccourcis > FiveM)
    Seats = 'front',             -- qui peut ouvrir la tablette : 'driver', 'front' (conducteur + passager avant) ou 'all'
    Intro = true,                -- animation 3D de la voiture à l'ouverture
    IntroSeconds = 3.6,
    IntroEveryTime = false,      -- false = l'intro ne se joue qu'une fois par véhicule
    MusicDistance = 18.0,        -- distance (m) à laquelle on entend la musique hors de la voiture
    MaxVolume = 0.7,
    ClosedWindowsFactor = 0.55,  -- volume entendu dehors quand toutes les vitres sont fermées
    SummonDistance = 350.0,      -- « Venir à moi » : distance maximale pour que la voiture vienne seule
    SummonSpeed = 14.0,          -- vitesse de la conduite autonome (m/s, ~50 km/h)
    -- Couleurs proposées pour les LED (néons)
    NeonColors = {
        { 124, 108, 255 }, { 111, 231, 242 }, { 255, 111, 158 }, { 255, 181, 71 }, { 79, 224, 176 }, { 255, 255, 255 }, { 255, 59, 59 },
    },
}
