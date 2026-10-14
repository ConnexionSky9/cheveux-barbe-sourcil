Config = {}

-- Toutes les valeurs de ce fichier peuvent être modifiées en jeu par le staff via l'API
-- d'administration (exports.noirx:AdminSetSetting). Les modifications sont enregistrées
-- en base (table noirx_settings) et rechargées au démarrage ; elles priment sur ce fichier.

-- ─────────────────────────────────────────────────────────────
--  GÉNÉRAL
-- ─────────────────────────────────────────────────────────────
Config.Debug = false
Config.Locale = 'fr'

-- ─────────────────────────────────────────────────────────────
--  ITEM
-- ─────────────────────────────────────────────────────────────
Config.Item = {
    name = 'noirphone',
    label = 'NOIR X',
    description = 'Terminal clandestin sécurisé. Accès au réseau privé NOIR X.',
    image = 'noirphone.png',
}

-- ─────────────────────────────────────────────────────────────
--  INVENTAIRE / ÉCONOMIE
--  'custom'  → bridge/server/custom_inventory.lua (elyzea_inventory)
--              et custom_economy.lua (elyzea_core). DÉJÀ RELIÉS à ton serveur.
--  'devtest' → MODE TEST : inventaire et argent SIMULÉS EN MÉMOIRE pour les joueurs ayant
--              l'ACE 'noirx.devtest'. Ne JAMAIS laisser actif en production.
-- ─────────────────────────────────────────────────────────────
Config.Inventory = {
    provider = 'custom',
    recheckInterval = 5000,   -- ms : possession du téléphone + rafraîchissement du portefeuille
}
Config.Economy = {
    provider = 'custom',
}
Config.DevTest = {
    startDirty = 50000,
    startClean = 10000,
}

-- ─────────────────────────────────────────────────────────────
--  ARGENT
--  Mêmes valeurs que elyzea_illegal (Config.DirtyMoney / Config.CleanMoney).
-- ─────────────────────────────────────────────────────────────
Config.Money = {
    dirtyItem = 'black_money',   -- objet elyzea_inventory « argent sale »
    cleanAccount = 'cash',       -- compte elyzea_core de l'argent propre : 'cash' ou 'bank'
    symbol = '$',
}

-- ─────────────────────────────────────────────────────────────
--  OUVERTURE
-- ─────────────────────────────────────────────────────────────
Config.Phone = {
    command = 'noirx',
    keybind = false,
    openCooldownMs = 1500,
    animation = true,
    disableControlsWhileOpen = true,
    allowWalkWhileOpen = true,
}

-- ─────────────────────────────────────────────────────────────
--  INTERFACE
-- ─────────────────────────────────────────────────────────────
Config.UI = {
    bootDuration = 1800,
    showBootEveryOpen = false,
    battery = { enabled = true, drainPerMinute = 0.4, min = 8 },
    sounds = {
        enabled = true,
        volume = 0.35,
        open = true, close = true, tap = true, notify = true, alert = true,
    },
    wallpapers = { 'void', 'grid', 'ember' },
    defaultWallpaper = 'void',
}

-- ─────────────────────────────────────────────────────────────
--  APPLICATIONS
-- ─────────────────────────────────────────────────────────────
Config.Apps = {
    { id = 'darkchat',    label = 'Dark Chat',     enabled = true },
    { id = 'ghostline',   label = 'Ghostline',     enabled = true },
    { id = 'ratline',     label = 'Ratline',       enabled = true },
    { id = 'launder',     label = 'Blanchiment',   enabled = true },
    { id = 'market',      label = 'Dark Market',   enabled = true },
    { id = 'contracts',   label = 'Contrats',      enabled = true },
    { id = 'blackbreach', label = 'Blackbreach',   enabled = true },
    { id = 'mercs',       label = 'Mercenaires',   enabled = true },
    { id = 'blackfile',   label = 'Blackfile',     enabled = true },
    { id = 'burner',      label = 'Burner',        enabled = true },
    { id = 'deaddrop',    label = 'Dead Drop',     enabled = true },
    { id = 'auction',     label = 'Black Auction', enabled = true },
    { id = 'settings',    label = 'Réglages',      enabled = true },
}

-- ─────────────────────────────────────────────────────────────
--  DARK CHAT / GHOSTLINE
-- ─────────────────────────────────────────────────────────────
Config.Chat = {
    maxMessageLength = 500,
    historyPage = 40,
    maxGroupMembers = 25,
    maxGroupsOwned = 5,
    ephemeralOptions = { 0, 300, 3600, 86400 },   -- secondes (0 = permanent)
    readReceipts = true,
    sendRate = { count = 8, per = 10 },           -- messages max par fenêtre (s)
    handleMin = 3,
    handleMax = 20,
}

-- ─────────────────────────────────────────────────────────────
--  BURNER (pseudonymes temporaires)
-- ─────────────────────────────────────────────────────────────
-- Connexion : le téléphone ne donne accès au réseau qu'une fois connecté avec un burner actif.
-- Quand le burner expire (ou est révoqué), la connexion est coupée.
Config.Auth = {
    requireBurner = true,
}

Config.Burner = {
    price = 2500,
    currency = 'clean',                 -- 'clean' (argent propre) ou 'dirty' (argent sale)
    durations = { 3600, 21600, 86400 }, -- secondes réelles
    maxActive = 1,
}

-- ─────────────────────────────────────────────────────────────
--  RATLINE (informateurs PNJ)
--  Les informateurs et leurs informations se gèrent depuis l'admin (exports Admin*).
-- ─────────────────────────────────────────────────────────────
Config.Ratline = {
    typingDelayMs = { 700, 1800 },
    historyLimit = 60,
    askCooldownSeconds = 3,
    maxFreeTextLength = 160,
    -- Catégories proposées dans l'admin (clé → libellé affiché)
    categories = {
        weed = 'Champs',
        dealer = 'Revendeurs',
        opportunity = 'Opportunités',
        rival = 'Rivalités',
        rumor = 'Rumeurs',
        other = 'Divers',
    },
}

-- ─────────────────────────────────────────────────────────────
--  BLANCHIMENT
-- ─────────────────────────────────────────────────────────────
Config.Laundering = {
    minAmount = 1000,
    maxAmount = 100000,
    feePercent = 30,            -- part retenue par le réseau
    baseSeconds = 60,           -- durée de base
    secondsPer1000 = 6,         -- + durée par tranche de 1 000
    maxSeconds = 900,
    cooldownSeconds = 120,      -- délai entre deux blanchiments
    hack = {
        npcChance = 35,             -- % de chance qu'un pirate PNJ attaque pendant un blanchiment
        windowSeconds = 25,         -- temps maximum du duel de frappe
        lossPercentMin = 15,        -- perte en cas de défaite (% du montant blanchi)
        lossPercentMax = 40,
        npcCharsPerSecond = { 3.2, 5.5 },  -- vitesse de frappe du pirate PNJ
        maxHumanCps = 16,           -- anti-triche : frappe plus rapide = rejetée
        lineLength = { 26, 40 },    -- longueur de la ligne de code à recopier
        vulnerableAfterSeconds = 10,-- un blanchiment n'est attaquable qu'après X s
        maxAttacksPerJob = 2,
        playerInterception = false, -- réservé : aucune interface d'intrusion entre joueurs dans cette version
        interceptCost = 500,
        interceptCurrency = 'dirty',
        interceptCooldownSeconds = 600,
        attackerRewardPercent = 100,-- part du montant volé reversée au pirate joueur
    },
}

-- ─────────────────────────────────────────────────────────────
--  DARK MARKET (place de marché entre joueurs)
--  Les objets mis en vente quittent l'inventaire du vendeur (séquestre) ; l'acheteur paie, reçoit
--  un colis, le vendeur est payé par la file de paiements (exactement une fois). Objets invendus,
--  annonces annulées ou expirées : rendus en colis à récupérer dans l'application.
-- ─────────────────────────────────────────────────────────────
Config.Market = {
    currencies = { 'dirty', 'clean' },  -- devises proposées au vendeur
    feePercent = 10,                    -- commission du réseau sur chaque vente (retenue au vendeur)
    listingFee = 0,                     -- frais fixes de publication (devise de l'annonce), 0 = gratuit
    durations = { 21600, 86400, 259200 },   -- durées de publication proposées (s) : 6 h, 24 h, 72 h
    maxActiveListings = 5,              -- annonces actives par vendeur
    maxPendingOffers = 5,               -- offres en attente par acheteur
    offerHours = 24,                    -- durée de validité d'une offre privée
    minPrice = 1, maxPrice = 10000000,  -- prix unitaire
    maxQuantity = 9999,
    requireIdentity = true,             -- vendre exige un pseudo Ghostline (profil vendeur)
    categories = {
        drugs = 'Stupéfiants', heist = 'Matériel de braquage', tools = 'Outillage',
        valuables = 'Objets de valeur', other = 'Divers',
    },
    -- Objets autorisés à la vente (empilables uniquement) → catégorie
    items = {
        weed_pouch = 'drugs', weed_leaf = 'drugs', cokebaggy = 'drugs', crack_baggy = 'drugs', xtcbaggy = 'drugs',
        meth = 'drugs', oxy = 'drugs', coke_brick = 'drugs', coke_small_brick = 'drugs', coca_leaf = 'drugs', meth_chemicals = 'drugs',
        weed_ak47 = 'drugs', weed_skunk = 'drugs', weed_amnesia = 'drugs', ['weed_og-kush'] = 'drugs',
        ['weed_white-widow'] = 'drugs', ['weed_purple-haze'] = 'drugs',
        weed_ak47_seed = 'drugs', weed_skunk_seed = 'drugs', weed_amnesia_seed = 'drugs',
        thermite = 'heist', trojan_usb = 'heist', bank_c4 = 'heist', bank_bag = 'heist', drill = 'heist',
        lockpick = 'tools', advancedlockpick = 'tools', electronickit = 'tools',
        goldbar = 'valuables', rolex = 'valuables', goldchain = 'valuables',
        diamond = 'valuables', ruby = 'valuables', sapphire = 'valuables', emerald = 'valuables', amethyst = 'valuables',
    },
    imagePath = 'nui://elyzea_inventory/html/img/%s',
}

-- ─────────────────────────────────────────────────────────────
--  MERCENAIRES (contrats de PNJ armés contre un joueur connecté)
--  Le serveur décide de tout : cible, prix, nombre de PNJ, armes, durée, remboursement.
--  Les PNJ sont créés par le serveur (OneSync) et pilotés par le jeu du joueur le plus proche.
-- ─────────────────────────────────────────────────────────────
Config.Mercs = {
    currency = 'dirty',             -- 'dirty' (argent sale) ou 'clean' (argent propre)
    -- Formules (1, 3 ou 5 mercenaires). accuracy : précision 0-100 · armour : gilet 0-100 · health : 100-400
    tiers = {
        { id = 'solo',  label = 'Tireur isolé', size = 1, price = 15000, accuracy = 30, armour = 25,  health = 200,
          weapons = { 'WEAPON_PISTOL50', 'WEAPON_HEAVYPISTOL' } },
        { id = 'team',  label = 'Équipe',       size = 3, price = 40000, accuracy = 35, armour = 50,  health = 200,
          weapons = { 'WEAPON_MICROSMG', 'WEAPON_SMG', 'WEAPON_PISTOL50' } },
        { id = 'squad', label = 'Escouade',     size = 5, price = 75000, accuracy = 40, armour = 100, health = 250,
          weapons = { 'WEAPON_CARBINERIFLE', 'WEAPON_SMG', 'WEAPON_PUMPSHOTGUN' } },
    },
    models = { 's_m_y_blackops_01', 's_m_y_blackops_02', 'g_m_m_chicold_01', 'g_m_y_lost_02', 'mp_g_m_pros_01' },
    vehicle = { enabled = true, models = { 'granger', 'baller', 'cavalcade2' }, seats = 4 },   -- arrivée en véhicule (4 par véhicule)

    deployDelaySeconds = 60,        -- délai entre la commande et l'arrivée de l'équipe
    validityMinutes = 20,           -- l'équipe doit avoir trouvé la cible avant ce délai, sinon contrat expiré
    engageSeconds = 480,            -- durée maximale du combat une fois la cible trouvée
    engageDistance = 70.0,          -- distance (m) à laquelle la cible est considérée « trouvée »
    spawnDistance = { 140, 240 },   -- distance d'apparition autour de la cible (m)
    leaveSeconds = 45,              -- après la mission, les PNJ s'en vont puis sont supprimés

    -- Anti-abus
    cooldownMinutes = 30,           -- délai entre deux commandes d'un même commanditaire
    maxActivePerBuyer = 1,
    maxActiveGlobal = 3,
    targetCooldownMinutes = 60,     -- délai minimum entre deux contrats contre la même cible
    maxPerTargetPerDay = 2,         -- contrats max contre une même cible sur 24 h
    minPolice = 0,                  -- policiers en service requis (elyzea_police), 0 = aucun
    protectedAce = 'noirx.protected',   -- joueurs intouchables (add_ace identifier.xxx noirx.protected allow)
    protectStaffOnDuty = true,      -- staff admin_menu en service intouchable
    protectedJobs = {},             -- métiers intouchables EN SERVICE, ex. { 'police', 'ambulance' }
    quoteSeconds = 60,              -- validité d'un devis

    -- Remboursement (% du prix) selon la fin du contrat
    refund = { expired = 100, target_left = 75, failed = 0, timeout = 0 },

    policeAlert = true,             -- alerte « Coups de feu » à la police quand l'équipe engage la cible
    hostileToAll = false,           -- false : les PNJ ne s'en prennent qu'à la cible (et à ceux qui les attaquent)
}

-- ─────────────────────────────────────────────────────────────
--  BASE DE DONNÉES / IDENTITÉ / ADMIN
-- ─────────────────────────────────────────────────────────────
Config.Database = {
    driver = 'auto',          -- 'auto' : elyzea_core, puis oxmysql, puis mysql-async
    autoInstall = true,       -- crée les tables au démarrage (CREATE TABLE IF NOT EXISTS, rejouable)
    installFiles = { 'sql/001_noirx_core.sql', 'sql/002_noirx_network.sql', 'sql/004_noirx_mercs.sql', 'sql/005_noirx_market.sql' },
}
Config.Identity = {
    provider = 'elyzea',      -- 'elyzea' : citizenid du personnage · 'license' : licence Rockstar
    priority = { 'license2', 'license', 'fivem', 'discord' },
}
Config.Admin = {
    resource = 'admin_menu',     -- même menu que elyzea_illegal
    permission = 'noirx_staff',  -- à ajouter dans admin_menu/config.lua (Config.Permissions)
    ace = 'noirx.admin',         -- repli si admin_menu n'est pas démarré
}

-- ─────────────────────────────────────────────────────────────
--  AUTRES RESSOURCES ELYZEA
-- ─────────────────────────────────────────────────────────────
Config.Integrations = {
    -- Messages « numéro inconnu » d'elyzea_illegal (livraisons, missions) reçus sur NOIR X
    -- si le joueur a le téléphone sur lui. Voir INTEGRATION.md § 5.
    illegalPhone = true,
}
