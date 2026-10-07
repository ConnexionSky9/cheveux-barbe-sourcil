--[[
    GO FAST - Configuration centrale
    -------------------------------------------------------------------------
    * Toutes les coordonnées sont au NIVEAU DU SOL (z = sol).
      Active Config.Debug puis tape /gofastcoords pour relever de nouvelles positions.
    * Le webhook Discord ne se met PAS ici (ce fichier est envoyé aux clients) :
      il se règle dans server.cfg -> set gofast_webhook "https://discord.com/api/webhooks/..."
]]

Config = {}

-- 'auto' | 'esx' | 'qbcore' | 'standalone'   (Qbox est géré via 'qbcore' grâce à sa compatibilité qb-core)
Config.Framework = 'auto'
Config.Debug = false
Config.CurrencySymbol = '$'
Config.SpeedUnit = 'kmh' -- 'kmh' | 'mph'

-- =========================================================================
-- INTERACTIONS
-- =========================================================================
Config.Interaction = {
    Mode = 'key',              -- 'key' | 'ox_target' | 'qb-target' (contact de mission)
    Key = 38,                  -- 38 = E (INPUT_CONTEXT) - utilisé aussi pour le véhicule et la livraison
    Distance = 2.0,            -- distance d'interaction en mode 'key'
    TargetDistance = 2.5,      -- distance d'interaction en mode target
    TargetIcon = 'fas fa-route',
    SpawnDistance = 60.0,      -- le PNJ contact n'existe que si un joueur est à moins de X m
}

-- =========================================================================
-- ENCADRÉ D'OBJECTIFS (affiché du lancement à la fin du Go Fast)
-- =========================================================================
Config.Objectives = {
    Enabled = true,
    Position = 'left',   -- 'left' (milieu gauche, entre le chat et la minimap) | 'right' (sous le HUD) | 'bottom' (au-dessus de la minimap)
    KeyLabel = 'E',      -- touche affichée dans les consignes (doit correspondre à Config.Interaction.Key)
    Refresh = 400,       -- ms entre deux mises à jour
}

-- =========================================================================
-- NOTIFICATIONS / SONS
-- =========================================================================
Config.Notify = {
    Type = 'nui',              -- 'nui' | 'esx' | 'qbcore' | 'ox_lib' | 'gta'
    Duration = 6000,
}

Config.Sounds = {
    Enabled = true,
    MissionStart = { name = 'Mission_Pass_Notify', set = 'DLC_HEISTS_GENERAL_FRONTEND_SOUNDS' },
    Unlock       = { name = 'SELECT', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    Checkpoint   = { name = 'CHECKPOINT_NORMAL', set = 'HUD_MINI_GAME_SOUNDSET' },
    Delivery     = { name = 'CHECKPOINT_PERFECT', set = 'HUD_MINI_GAME_SOUNDSET' },
    Success      = { name = 'BASE_JUMP_PASSED', set = 'HUD_AWARDS' },
    Fail         = { name = 'ScreenFlash', set = 'MissionFailedSounds' },
    Alert        = { name = 'TIMER_STOP', set = 'HUD_MINI_GAME_SOUNDSET' },
    Warning      = { name = '5_SEC_WARNING', set = 'HUD_MINI_GAME_SOUNDSET' },
    LevelUp      = { name = 'RANK_UP', set = 'HUD_AWARDS' },
    PoliceAlert  = { name = 'Lose_1st', set = 'GTAO_FM_Events_Soundset' },
}

-- =========================================================================
-- LOGS (console + Discord via convar gofast_webhook)
-- =========================================================================
Config.Logs = {
    Enabled = true,
    Console = true,
    BotName = 'Go Fast',
    Categories = { start = true, success = true, fail = true, exploit = true, police = true, admin = true },
    Colors = { start = 3447003, success = 3066993, fail = 15105570, exploit = 15158332, police = 10181046, admin = 9807270 },
}

-- =========================================================================
-- COMMANDES
-- =========================================================================
Config.Commands = {
    Abandon = 'gofastabandon',   -- abandonner sa mission
    ToggleHud = 'gofasthud',     -- masquer / afficher le HUD
    Admin = 'gofastadmin',       -- administration (ace : command.gofastadmin)
    Coords = 'gofastcoords',     -- relevé de coordonnées (uniquement si Config.Debug = true)
}

-- =========================================================================
-- COOLDOWNS (secondes) - stockés par licence Rockstar : se reconnecter ou changer de perso ne les contourne pas
-- =========================================================================
Config.Cooldown = {
    Success = 600,
    Fail = 900,
    Abandon = 1200,
    Disconnect = 1800,
    Global = 30,   -- délai minimum entre deux lancements sur tout le serveur (0 = désactivé)
}

-- =========================================================================
-- RÈGLES DE MISSION
-- =========================================================================
Config.Mission = {
    MaxActive = 8,                 -- Go Fast simultanés maximum sur le serveur
    PickupTimeout = 300,           -- secondes pour récupérer le véhicule
    AwayDistance = 150.0,          -- distance joueur <-> véhicule au-delà de laquelle le compte à rebours démarre
    AwayTimeout = 45,              -- secondes tolérées loin du véhicule
    DestroyedEngineHealth = -3000.0, -- moteur sous ce seuil = véhicule détruit
    DeliveryRadius = 7.0,          -- rayon (client) pour proposer la livraison
    DeliveryMaxSpeed = 2.0,        -- vitesse max (m/s) pour livrer
    RequireKeyToDeliver = true,    -- false = livraison automatique à l'arrêt
    TickInterval = 2000,           -- intervalle (ms) de la boucle serveur de surveillance
    RecentDestinationsMemory = 6,  -- nb de destinations récentes évitées pour un même joueur
    ClearWantedOnEnd = true,
    LeaveVehicleOnEnd = true,      -- le joueur sort du véhicule à la fin
}

-- =========================================================================
-- SÉCURITÉ (toutes ces valeurs sont vérifiées côté serveur)
-- =========================================================================
Config.Security = {
    RateLimitMs = 1200,            -- délai minimum entre deux appels d'un même event
    SpamThreshold = 8,             -- nb d'appels bloqués avant avertissement
    MaxAverageSpeed = 80.0,        -- m/s moyen max entre deux étapes (~290 km/h) : au-delà = téléportation
    MinMissionDuration = 40,       -- secondes minimum entre le lancement et la livraison finale
    GiverDistance = 6.0,           -- distance max au contact pour ouvrir/lancer
    VehicleDistance = 6.0,         -- distance max au véhicule pour le déverrouiller
    DeliveryCheckRadius = 18.0,    -- distance max véhicule <-> point de livraison (serveur)
    CheckpointCheckRadius = 30.0,  -- distance max véhicule <-> checkpoint (serveur)
    KickOnExploit = false,
    MaxFlags = 3,                  -- nb d'avertissements avant kick (si KickOnExploit)
}

-- =========================================================================
-- VÉHICULE DE MISSION
-- =========================================================================
Config.Vehicle = {
    PlatePattern = 'GF##@@##',     -- # = chiffre, @ = lettre, * = l'un ou l'autre, le reste est conservé (8 car. max)
    ClearRadius = 4.5,             -- rayon qui doit être libre (véhicules / joueurs) pour faire apparaître le véhicule
    UnlockDistance = 3.0,          -- distance (client) pour proposer le déverrouillage
    AutoUnlock = false,            -- true = déverrouillage automatique en approchant
    FuelLevel = 100.0,
    DeleteDelay = 6000,            -- ms avant suppression après la fin
    DeleteTimeout = 30000,         -- ms max d'attente si quelqu'un est encore dedans
    Marker = { Enabled = true, Type = 2, Scale = 0.45, ZOffset = 1.6, Color = { r = 242, g = 165, b = 65, a = 200 }, Bob = true, Rotate = true },

    -- Carburant : adapté automatiquement aux scripts les plus courants
    SetFuel = function(vehicle, level)
        if GetResourceState('LegacyFuel') == 'started' then
            exports['LegacyFuel']:SetFuel(vehicle, level)
        elseif GetResourceState('cdn-fuel') == 'started' then
            exports['cdn-fuel']:SetFuel(vehicle, level)
        elseif GetResourceState('ox_fuel') == 'started' then
            Entity(vehicle).state:set('fuel', level, true)
        else
            SetVehicleFuelLevel(vehicle, level + 0.0)
        end
    end,

    -- Clés : adapté aux scripts de clés les plus courants (exécuté côté client)
    GiveKeys = function(vehicle, plate)
        if GetResourceState('qb-vehiclekeys') == 'started' then
            TriggerEvent('vehiclekeys:client:SetOwner', plate)
        elseif GetResourceState('wasabi_carlock') == 'started' then
            exports.wasabi_carlock:GiveKey(plate)
        elseif GetResourceState('MrNewbVehicleKeys') == 'started' then
            exports.MrNewbVehicleKeys:GiveKeys(vehicle)
        end
    end,
}

-- =========================================================================
-- LIVRAISONS / CHECKPOINTS
-- =========================================================================
Config.Delivery = {
    Marker = { Type = 1, Scale = vector3(7.0, 7.0, 1.2), ZOffset = -0.95, Color = { r = 229, g = 56, b = 59, a = 110 } },
    Ped = {
        Enabled = true,
        Models = { 'g_m_m_armlieut_01', 'g_m_y_lost_02', 'a_m_m_hillbilly_02', 'g_m_y_famdnf_01' },
        Scenario = 'WORLD_HUMAN_SMOKING',
        SpawnDistance = 120.0,
        Offset = vector3(3.0, 3.0, 0.0),
        Heading = 0.0,
    },
}

Config.Checkpoints = {
    Enabled = true,
    Radius = 12.0,               -- rayon de passage (client)
    CorridorRatio = 1.35,        -- 1.35 = le checkpoint ne rallonge pas le trajet de plus de 35 %
    MinDistanceFromEnds = 400.0, -- distance minimum au départ et à l'arrivée de l'étape
    Marker = { Type = 6, Scale = vector3(10.0, 10.0, 10.0), ZOffset = 4.0, Color = { r = 242, g = 165, b = 65, a = 120 } },
}

-- =========================================================================
-- BLIPS
-- =========================================================================
Config.Blips = {
    Vehicle    = { Sprite = 225, Color = 47, Scale = 0.9, Route = true, RouteColor = 47 },
    Drop       = { Sprite = 38, Color = 1, Scale = 0.95, Route = true, RouteColor = 1 },
    Checkpoint = { Sprite = 1, Color = 47, Scale = 0.65 },
}

-- =========================================================================
-- POLICE / RISQUE
-- =========================================================================
Config.Police = {
    Enabled = true,
    Jobs = { 'police', 'sheriff', 'gendarmerie' },
    RequireOnDuty = true,
    AcePermission = 'gofast.police',  -- standalone : add_ace group.police gofast.police allow
    BlockPoliceFromMissions = true,   -- un policier ne peut pas lancer de Go Fast
    Mode = 'builtin',                 -- 'builtin' (blips + notification intégrés) | 'custom' (fonction ci-dessous)
    NotifyDriver = true,              -- prévient le conducteur quand l'alerte part
    ShowPlate = true,
    ShowVehicleModel = true,
    Blip = { Sprite = 161, Color = 1, Scale = 1.3, Radius = 150.0, RadiusAlpha = 90, Duration = 90, Label = 'Go Fast signalé' },

    -- Exécutée côté SERVEUR quand Mode = 'custom'. Exemple fourni pour cd_dispatch.
    CustomDispatch = function(policeSources, coords, data)
        TriggerClientEvent('cd_dispatch:AddNotification', -1, {
            job_table = Config.Police.Jobs,
            coords = coords,
            title = '10-80 - Go Fast',
            message = ('%s | %s | plaque %s'):format(data.tierLabel, data.vehicleLabel or 'véhicule inconnu', data.plate or 'inconnue'),
            flash = 0,
            unique_id = data.id,
            sound = 1,
            blip = { sprite = 161, scale = 1.2, colour = 1, flashes = true, text = 'Go Fast', time = 5, radius = 0 },
        })
    end,
}

-- =========================================================================
-- ÉVÉNEMENTS ALÉATOIRES (activés par palier via tier.events.pool)
-- =========================================================================
Config.RandomEvents = {
    Enabled = true,
    wanted = { Level = { 1, 3 } },
    rivals = {
        Vehicles = { 'baller2', 'cavalcade2', 'granger' },
        Peds = { 'g_m_y_ballaeast_01', 'g_m_y_mexgoon_02', 'g_m_y_salvagoon_01' },
        Weapons = { 'WEAPON_MICROSMG', 'WEAPON_PISTOL' },
        Count = { 2, 3 },
        Accuracy = 25,
        SpawnDistance = 110.0,
        Duration = 180,         -- secondes avant disparition
        DespawnDistance = 350.0,
    },
    tracker = { Duration = 120, Interval = 8 }, -- balise GPS : la police suit le véhicule
}

-- =========================================================================
-- MISSIONS RARES
-- =========================================================================
Config.Rare = {
    RewardMultiplier = 1.8,
    XPMultiplier = 2.0,
    RiskBonus = 1,
    EventChanceMultiplier = 1.5,
    PoliceChanceMultiplier = 1.25,
}

-- =========================================================================
-- RÉCOMPENSES (calculées UNIQUEMENT côté serveur)
-- =========================================================================
Config.Rewards = {
    Account = { esx = 'black_money', qbcore = 'cash', standalone = 'cash' }, -- ESX : 'money' | 'bank' | 'black_money'
    LevelBonusPerLevel = 0.03,   -- +3 % de la base par niveau au-dessus de 1
    FastBonus = { Enabled = true, Threshold = 0.65, Percent = 0.25, XPPercent = 0.2 }, -- livré en moins de 65 % du temps = +25 %
    DamagePenalty = { Enabled = true, Threshold = 850.0, MaxPercent = 0.6 },          -- santé moyenne /1000
    CheckpointBonus = 0.04,      -- +4 % par checkpoint franchi
}

-- Utilisé seulement en standalone (exécuté côté serveur)
Config.Standalone = {
    AddMoney = function(source, account, amount)
        TriggerEvent('gofast:standalone:addMoney', source, account, amount)
        return true
    end,
}

-- =========================================================================
-- XP / NIVEAUX
-- =========================================================================
Config.XP = {
    Enabled = true,
    Storage = 'kvp',            -- 'kvp' (aucune base nécessaire) | 'oxmysql' (table créée automatiquement)
    FailPenalty = 15,
    AbandonPenalty = 25,
    DisconnectPenalty = 25,
}

Config.Levels = {
    -- XP cumulée nécessaire pour atteindre chaque niveau (index = niveau)
    Thresholds = { 0, 150, 350, 600, 900, 1300, 1800, 2400, 3100, 3900, 4800, 5800, 6900, 8100, 9400 },
}

Config.RiskLabels = { 'Faible', 'Modéré', 'Élevé', 'Extrême', 'Suicidaire' }

-- =========================================================================
-- CONTACTS (PNJ qui donnent les missions)
-- Les contacts se créent et se gèrent EN JEU : menu staff › Événements › GoFast.
-- Ils sont sauvegardés dans data/gofast.json (ne pas supprimer ce fichier lors d'une mise à jour).
-- =========================================================================
Config.Manage = {
    DataFile = 'data/gofast.json',
    -- true : au tout premier démarrage, les exemples ci-dessous (Config.MissionGivers) sont créés
    -- comme contacts modifiables. false : tu crées toi-même tes contacts depuis le menu staff.
    SeedDefaultContacts = false,
    NewContact = {
        Model = 'g_m_m_chicold_01',
        Scenario = 'WORLD_HUMAN_SMOKING',
        BlipSprite = 500,
        BlipColor = 47,
    },
    Blip = { Scale = 0.8, ShortRange = true },
    Marker = { Enabled = true, Type = 27, Scale = 1.2, ZOffset = -0.98, Color = { r = 242, g = 165, b = 65, a = 160 }, DrawDistance = 15.0 },
    MoveCheckRadius = 60.0,      -- option « attendre qu'il soit seul » : aucun joueur à moins de X m
    MoveRetryDelay = 30,         -- secondes avant de réessayer un déplacement bloqué
    AutoRoadPointDistance = 60.0,-- point véhicule automatique : route la plus proche à moins de X m
    MaxContacts = 30,
    MaxLocations = 20,
    MaxVehiclePoints = 8,
    MaxDialogueLines = 25,
    MaxDialogueLength = 220,
}

-- Répliques des contacts. Chaque contact peut avoir les siennes (menu staff) ;
-- une catégorie laissée vide utilise ces répliques par défaut.
-- Variables : {joueur} {contact} {niveau} {palier} {temps}
Config.DialogueCategories = {
    { id = 'greet',   label = 'Accueil',          hint = 'Affiché quand le joueur ouvre la liste des contrats.' },
    { id = 'refuse',  label = 'Refus / attente',  hint = 'À l\'ouverture, si le joueur est en attente (cooldown) ou déjà en mission.' },
    { id = 'accept',  label = 'Contrat accepté',  hint = 'Envoyé au joueur quand il accepte un contrat.' },
    { id = 'success', label = 'Livraison réussie', hint = 'Message du contact à la fin d\'un Go Fast réussi.' },
    { id = 'fail',    label = 'Échec',            hint = 'Message du contact quand le Go Fast échoue.' },
}

Config.DefaultDialogues = {
    greet = {
        'T\'es {joueur} ? On m\'a parlé de toi. J\'ai du boulot si t\'as les nerfs.',
        'Pas de nom, pas de questions. Choisis ton contrat.',
        'Le moteur est chaud, la marchandise aussi. Tu prends quoi ?',
    },
    refuse = {
        'Fais-toi oublier un moment. Reviens dans {temps}.',
        'T\'es déjà sur un coup. Finis ce que t\'as commencé.',
    },
    accept = {
        'Le {palier}, c\'est parti. La caisse t\'attend, ne la raye pas.',
        'Tu roules vite, tu roules propre. Et tu ne m\'as jamais vu.',
    },
    success = {
        'Propre. L\'argent est passé, on se recontacte.',
        'Livraison reçue. Tu montes dans l\'estime du réseau.',
    },
    fail = {
        'T\'as tout fait foirer. Ne reviens pas tout de suite.',
        'La marchandise est perdue. Ça va se payer.',
    },
}

-- Exemples utilisés seulement si Config.Manage.SeedDefaultContacts = true (coordonnées au sol)
Config.MissionGivers = {
    {
        id = 'lsia',
        label = 'Hangar 17',
        subtitle = 'Aéroport de Los Santos',
        coords = vector4(-1260.0, -3390.0, 13.94, 60.0),
        ped = { model = 'g_m_m_chicold_01', scenario = 'WORLD_HUMAN_SMOKING' },
        tiers = { 'street', 'express', 'ghost' },
        spawnPoints = {
            vector4(-1275.0, -3370.0, 13.94, 330.0),
            vector4(-1283.0, -3375.0, 13.94, 330.0),
            vector4(-1267.0, -3365.0, 13.94, 330.0),
        },
    },
    {
        id = 'sandy',
        label = 'Piste de Sandy',
        subtitle = 'Aérodrome de Sandy Shores',
        coords = vector4(1738.0, 3283.0, 41.13, 195.0),
        ped = { model = 'a_m_m_hillbilly_01', scenario = 'WORLD_HUMAN_CLIPBOARD' },
        tiers = { 'express', 'heavy', 'ghost' },
        spawnPoints = {
            vector4(1720.0, 3260.0, 41.10, 105.0),
            vector4(1712.0, 3256.0, 41.10, 105.0),
            vector4(1704.0, 3252.0, 41.10, 105.0),
        },
    },
}

-- =========================================================================
-- DESTINATIONS (le générateur pioche ici selon les zones du palier)
-- zone : 'city' | 'county' | 'north'   (tu peux créer tes propres zones)
-- Les destinations non choisies servent aussi de checkpoints facultatifs.
-- =========================================================================
Config.Destinations = {
    { label = 'Davis - Strawberry Ave',     zone = 'city',   coords = vector3(176.63, -1562.02, 29.26) },
    { label = 'Davis - Grove Street',       zone = 'city',   coords = vector3(-70.21, -1761.79, 29.53) },
    { label = 'Strawberry',                 zone = 'city',   coords = vector3(265.65, -1261.31, 29.29) },
    { label = 'La Mesa',                    zone = 'city',   coords = vector3(819.65, -1028.85, 26.40) },
    { label = 'El Burro Heights',           zone = 'city',   coords = vector3(1208.95, -1402.57, 35.22) },
    { label = 'Mirror Park',                zone = 'city',   coords = vector3(1181.38, -330.85, 69.32) },
    { label = 'Downtown Vinewood',          zone = 'city',   coords = vector3(620.84, 269.10, 103.09) },
    { label = 'Little Seoul',               zone = 'city',   coords = vector3(-724.62, -935.16, 19.21) },
    { label = 'Vespucci - Calais Ave',      zone = 'city',   coords = vector3(-526.02, -1211.00, 18.18) },
    { label = 'Morningwood',                zone = 'city',   coords = vector3(-1437.62, -276.75, 46.21) },
    { label = 'Pacific Bluffs',             zone = 'city',   coords = vector3(-2096.24, -320.29, 13.17) },
    { label = 'Richman Glen',               zone = 'city',   coords = vector3(-1800.38, 803.66, 138.65) },
    { label = 'Tataviam',                   zone = 'county', coords = vector3(2581.32, 362.04, 108.47) },
    { label = 'Route 68 - Harmony',         zone = 'county', coords = vector3(263.89, 2606.46, 44.98) },
    { label = 'Route 68 - Ouest',           zone = 'county', coords = vector3(49.42, 2778.79, 58.04) },
    { label = 'Route 68 - Est',             zone = 'county', coords = vector3(1039.96, 2671.13, 39.55) },
    { label = 'Grand Senora',               zone = 'county', coords = vector3(1207.26, 2660.18, 37.90) },
    { label = 'Senora Way',                 zone = 'county', coords = vector3(2539.69, 2594.19, 37.94) },
    { label = 'Senora Freeway',             zone = 'county', coords = vector3(2679.86, 3263.95, 55.24) },
    { label = 'Sandy Shores',               zone = 'county', coords = vector3(2005.06, 3773.89, 32.40) },
    { label = 'Fort Zancudo - Route 68',    zone = 'county', coords = vector3(-2554.99, 2334.40, 33.08) },
    { label = 'Grapeseed',                  zone = 'north',  coords = vector3(1687.16, 4929.39, 42.08) },
    { label = 'Mont Chiliad - Great Ocean', zone = 'north',  coords = vector3(1701.31, 6416.03, 32.76) },
    { label = 'Paleto Bay - Est',           zone = 'north',  coords = vector3(179.86, 6602.84, 31.87) },
    { label = 'Paleto Bay - Centre',        zone = 'north',  coords = vector3(-94.46, 6419.59, 31.49) },
}

-- =========================================================================
-- PALIERS DE MISSION (difficulté progressive)
-- =========================================================================
Config.Tiers = {
    {
        id = 'street',
        label = 'Livraison de quartier',
        description = 'Un ou deux arrêts en ville. Peu de témoins, petite enveloppe.',
        minLevel = 1,
        risk = 1,
        zones = { 'city' },
        drops = { 1, 2 },
        minLegDistance = 900.0,
        maxLegDistance = 4500.0,
        time = { base = 150, perKm = 75 },            -- temps limite = base + km * perKm (secondes)
        reward = { min = 3500, max = 6000, perKm = 300 },
        xp = 50,
        checkpoints = 1,
        vehicleUpgrade = 0.4,                          -- 0 = d'origine, 1 = performances max
        vehicles = {
            { model = 'sultan', label = 'Karin Sultan' },
            { model = 'buffalo', label = 'Bravado Buffalo' },
            { model = 'oracle2', label = 'Ubermacht Oracle XS' },
        },
        rareVehicles = { { model = 'sultanrs', label = 'Karin Sultan RS' } },
        rareChance = 0.05,
        police = { chance = 0.10, delay = { 90, 150 }, tracker = false, trackerDuration = 0, trackerInterval = 10, minCops = 0 },
        events = { chance = 0.10, max = 1, pool = { 'wanted' }, window = { 60, 180 } },
        items = {},
    },
    {
        id = 'express',
        label = 'Express interurbain',
        description = 'Deux étapes entre la ville et le comté. Les flics commencent à s\'intéresser à toi.',
        minLevel = 3,
        risk = 2,
        zones = { 'city', 'county' },
        drops = { 2, 2 },
        minLegDistance = 1500.0,
        maxLegDistance = 6000.0,
        time = { base = 150, perKm = 65 },
        reward = { min = 7500, max = 11000, perKm = 350 },
        xp = 90,
        checkpoints = 2,
        vehicleUpgrade = 0.6,
        vehicles = {
            { model = 'kuruma', label = 'Karin Kuruma' },
            { model = 'schafter3', label = 'Benefactor Schafter V12' },
            { model = 'jester', label = 'Dinka Jester' },
        },
        rareVehicles = { { model = 'jester3', label = 'Dinka Jester Classic' } },
        rareChance = 0.07,
        police = { chance = 0.30, delay = { 60, 120 }, tracker = false, trackerDuration = 0, trackerInterval = 10, minCops = 1 },
        events = { chance = 0.25, max = 1, pool = { 'wanted', 'rivals' }, window = { 60, 240 } },
        items = {},
    },
    {
        id = 'heavy',
        label = 'Cargaison lourde',
        description = 'Deux à trois arrêts jusqu\'au nord. Rivaux et balises possibles.',
        minLevel = 6,
        risk = 3,
        zones = { 'county', 'north' },
        drops = { 2, 3 },
        minLegDistance = 1800.0,
        maxLegDistance = 7000.0,
        time = { base = 180, perKm = 60 },
        reward = { min = 14000, max = 20000, perKm = 400 },
        xp = 150,
        checkpoints = 3,
        vehicleUpgrade = 0.75,
        vehicles = {
            { model = 'baller2', label = 'Gallivanter Baller' },
            { model = 'granger', label = 'Declasse Granger' },
            { model = 'dubsta2', label = 'Benefactor Dubsta' },
        },
        rareVehicles = { { model = 'xls2', label = 'Benefactor XLS blindé' } },
        rareChance = 0.10,
        police = { chance = 0.55, delay = { 45, 90 }, tracker = false, trackerDuration = 0, trackerInterval = 10, minCops = 2 },
        events = { chance = 0.45, max = 2, pool = { 'wanted', 'rivals', 'tracker' }, window = { 45, 300 } },
        items = {},
    },
    {
        id = 'ghost',
        label = 'Opération Fantôme',
        description = 'Trois ou quatre arrêts à travers l\'État, supercar, police sur les talons dès le départ.',
        minLevel = 10,
        risk = 5,
        zones = { 'city', 'county', 'north' },
        drops = { 3, 4 },
        minLegDistance = 2000.0,
        maxLegDistance = 9000.0,
        time = { base = 180, perKm = 55 },
        reward = { min = 26000, max = 38000, perKm = 500 },
        xp = 260,
        checkpoints = 4,
        vehicleUpgrade = 1.0,
        vehicles = {
            { model = 't20', label = 'Progen T20' },
            { model = 'zentorno', label = 'Pegassi Zentorno' },
            { model = 'italigtb', label = 'Progen Itali GTB' },
        },
        rareVehicles = { { model = 'tezeract', label = 'Pegassi Tezeract' } },
        rareChance = 0.15,
        police = { chance = 0.85, delay = { 20, 45 }, tracker = true, trackerDuration = 90, trackerInterval = 10, minCops = 3 },
        events = { chance = 0.70, max = 2, pool = { 'wanted', 'rivals', 'tracker' }, window = { 30, 300 } },
        items = {
            -- exemple : { name = 'goldbar', label = 'Lingot', count = { 1, 2 }, chance = 0.25 },
        },
    },
}

-- =========================================================================
-- TEXTES
-- =========================================================================
Config.Lang = {
    already_active = 'Tu as déjà un Go Fast en cours.',
    too_far_giver = 'Tu es trop loin du contact.',
    level_required = 'Niveau %s requis pour ce contrat.',
    cooldown = 'Le contact ne veut pas te voir. Reviens dans %s.',
    global_cooldown = 'Le réseau est sous surveillance. Réessaie dans %s.',
    max_active = 'Trop de Go Fast en cours en ville. Réessaie plus tard.',
    not_enough_cops = 'Le contact attend plus de monde dans les rues (%s policiers requis).',
    police_forbidden = 'Les forces de l\'ordre ne peuvent pas lancer de Go Fast.',
    no_spawn = 'La zone du véhicule est encombrée. Réessaie dans un instant.',
    no_route = 'Aucun itinéraire disponible pour ce contrat.',
    spawn_failed = 'Impossible de préparer le véhicule. Préviens un administrateur.',
    not_loaded = 'Ton personnage n\'est pas encore chargé.',
    invalid_contract = 'Ce contrat n\'est pas disponible ici.',
    mission_started = 'Contrat accepté : récupère la %s (plaque %s).',
    mission_started_rare = 'Cargaison rare ! Récupère la %s (plaque %s).',
    vehicle_unlocked = 'Véhicule récupéré. Direction : %s.',
    too_far_vehicle = 'Approche-toi du véhicule.',
    checkpoint = 'Point de passage validé (+%s %%).',
    next_drop = 'Livraison %s/%s effectuée. Prochaine étape : %s.',
    must_drive = 'Tu dois être au volant du véhicule de mission.',
    not_at_drop = 'Tu n\'es pas au point de livraison.',
    stop_vehicle = 'Arrête complètement le véhicule.',
    mission_success = 'Go Fast terminé : +%s (XP +%s).',
    level_up = 'Niveau supérieur : tu es maintenant niveau %s.',
    bonus_fast = 'Bonus rapidité : +%s',
    penalty_damage = 'Pénalité de dégâts : -%s',
    item_reward = 'Bonus : %sx %s',
    fail_timeout = 'Temps écoulé : le client a annulé la livraison.',
    fail_pickup_timeout = 'Tu as mis trop de temps à récupérer le véhicule.',
    fail_destroyed = 'Le véhicule a été détruit. Contrat perdu.',
    fail_lost = 'Le véhicule a été perdu. Contrat perdu.',
    fail_water = 'Le véhicule a fini à l\'eau. Contrat perdu.',
    fail_away = 'Tu as laissé le véhicule trop longtemps. Contrat perdu.',
    fail_abandon = 'Tu as abandonné le Go Fast.',
    fail_exploit = 'Livraison invalide détectée. Contrat annulé.',
    fail_admin = 'Ton Go Fast a été annulé par un administrateur.',
    fail_disconnect = 'Déconnexion pendant le Go Fast.',
    xp_lost = 'Tu perds %s XP.',
    police_alerted = 'Un témoin a appelé la police !',
    tracker_detected = 'Une balise GPS est cachée dans le véhicule : la police te suit.',
    event_wanted = 'Une patrouille t\'a repéré !',
    event_rivals = 'Des rivaux veulent ta cargaison !',
    police_alert = 'Go Fast signalé : %s - %s',
    police_alert_vehicle = 'Véhicule : %s | Plaque : %s',
    police_tracker = 'Balise GPS active sur le véhicule suspect.',
    interact_giver = 'Appuie sur ~INPUT_CONTEXT~ pour parler au contact',
    interact_vehicle = 'Appuie sur ~INPUT_CONTEXT~ pour récupérer le véhicule',
    interact_delivery = 'Appuie sur ~INPUT_CONTEXT~ pour livrer',
    target_label = 'Parler au contact',
    no_mission = 'Tu n\'as aucun Go Fast en cours.',
    hud_on = 'HUD Go Fast affiché.',
    hud_off = 'HUD Go Fast masqué.',
    hud_pickup = 'Récupération',
    hud_transit = 'Livraison',
    hud_pickup_destination = 'Récupérer : %s',
    blip_vehicle = 'Véhicule Go Fast',
    blip_drop = 'Livraison Go Fast',
    blip_checkpoint = 'Point de passage',
    kick_exploit = 'Go Fast : comportement suspect détecté.',
    unknown = 'inconnu',
    gofast_disabled = 'Le réseau Go Fast est fermé pour le moment.',
    contact_unavailable = 'Ce contact n\'est plus disponible ici.',
    tier_disabled = 'Ce contrat n\'est plus proposé.',
    contact_says = '%s : « %s »',
    obj_title = 'Go Fast',
    obj_step_pickup = 'Récupérer le véhicule',
    obj_step_drop = 'Livraison %s',
    obj_goto_vehicle = 'Va chercher la %s',
    obj_goto_vehicle_hint = 'Plaque %s · %s · suis le GPS',
    obj_unlock_key = 'Appuie sur %s près du véhicule',
    obj_unlock_auto = 'Approche-toi du véhicule',
    obj_deliver = 'Livre la marchandise',
    obj_deliver_hint = '%s · %s',
    obj_back_in = 'Remonte dans le véhicule',
    obj_back_in_hint = 'Il est marqué sur ta carte',
    obj_away = 'Retourne au véhicule !',
    obj_away_hint = 'Contrat perdu dans %s s',
    obj_stop = 'Arrête-toi pour livrer',
    obj_stop_hint = 'Le véhicule doit être à l\'arrêt',
    obj_deliver_key = 'Appuie sur %s pour livrer',
    obj_deliver_auto = 'Livraison en cours…',
    obj_checkpoints = '%s point(s) de passage facultatif(s) : bonus',
    obj_police = 'Police prévenue : sème-la',
    obj_tracker = 'Balise GPS : la police te suit',
    obj_rivals = 'Des rivaux te poursuivent',
    obj_wanted = 'Une patrouille t\'a repéré',
    obj_time_low = 'Moins de 30 s : fonce !',
}
