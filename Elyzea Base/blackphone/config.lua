-- =====================================================================
--  BLACKPHONE - valeurs PAR DÉFAUT
--  Tout se règle ensuite en jeu : admin_menu › « BLACKPHONE » (permission « blackphone_manage »).
--  Les réglages modifiés sont enregistrés en base (bp_settings) et restaurés au démarrage.
-- =====================================================================
Config = {}

Config.Defaults = {
    general = {
        enabled = true,
        phoneItem = 'blackphone',
        laptopItem = 'police_laptop',
        moneyType = 'cash',             -- argent utilisé par le réseau : 'cash', 'bank' ou 'item' (argent sale)
        moneyItem = 'black_money',
        sounds = true, volume = 35,     -- sons de l'interface (0-100)
        auditDays = 60,                 -- conservation du journal (jours)
        messageDays = 30,               -- conservation des messages non éphémères (jours)
    },
    apps = { chat = true, ghostline = true, market = true, contracts = true, breach = true },

    profile = { aliasMin = 3, aliasMax = 18, renameCooldownHours = 72, renameCost = 5000 },

    chat = { maxGroupMembers = 12, maxGroups = 6, maxLength = 500, ephemeralOptions = { 0, 300, 3600, 86400 }, readReceipts = true, perMinute = 20 },

    market = {
        fee = 8,                        -- % prélevé sur chaque vente
        minPrice = 50, maxPrice = 5000000,
        durationHours = 48, maxActive = 6,
        -- seuls les objets EMPILABLES sont vendables (les objets uniques, armes et ordinateurs numérotés, sont refusés)
        categories = {
            { id = 'munitions', label = 'Munitions', items = { 'ammo-9', 'ammo-rifle', 'ammo-rifle2' } },
            { id = 'drogue', label = 'Substances', items = { 'weed_pouch', 'cokebaggy', 'meth' } },
            { id = 'outils', label = 'Outils', items = { 'lockpick', 'advancedlockpick', 'bank_c4', 'bank_bag' } },
            { id = 'bijoux', label = 'Bijoux et pierres', items = { 'diamond', 'ruby', 'sapphire', 'emerald', 'amethyst', 'goldbar', 'rolex' } },
        },
    },

    contracts = {
        categories = { 'transport', 'livraison', 'recuperation', 'escorte', 'information', 'autre' },
        minReward = 500, maxReward = 1000000, fee = 5, maxActive = 4, maxDeadlineHours = 168,
    },

    breach = {
        cost = 15000, cooldownMinutes = 45, maxConcurrent = 2,
        durationMin = 60, durationMax = 120,    -- secondes (entre 60 et 120)
        steps = 3, difficulty = 2,              -- 1 à 3
        effectMinutes = 10,                     -- suspension des signalements automatiques de tirs
        minPolice = 0,
        tracking = { enabled = true, interval = 5, precision = 35, maxOfficers = 6 },   -- s, m (flou), nombre max de policiers informés
        counter = { enabled = true, chance = 45, cooldown = 30, shieldMinutes = 15 },  -- %, s entre deux contre-mesures d'un agent
    },

    police = {
        jobs = { 'police' },
        grades = { laptop = 1, cyber = 2, tracking = 2, counter = 3, history = 4 },   -- niveau de grade minimal (elyzea_police)
    },
}

Config.MarketPayment = { cash = 'Liquide', bank = 'Compte bancaire', item = 'Argent sale' }
