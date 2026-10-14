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
--  BASE DE DONNÉES / IDENTITÉ / ADMIN
-- ─────────────────────────────────────────────────────────────
Config.Database = {
    driver = 'auto',          -- 'auto' : elyzea_core, puis oxmysql, puis mysql-async
    autoInstall = true,       -- crée les tables au démarrage (CREATE TABLE IF NOT EXISTS, rejouable)
    installFiles = { 'sql/001_noirx_core.sql', 'sql/002_noirx_network.sql' },
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
