-- =====================================================================
--  ELYZEA SHOP — configuration
--  Aucun secret ici : la clé Tebex se met dans server.cfg (sv_tebexSecret, voir README).
--  Les prix, images, descriptions et avantages ci-dessous sont des EXEMPLES À REMPLACER.
-- =====================================================================
Config = {}

Config.ServerName = 'Elyzea RP'

-- ---------------------------------------------------------------------
-- Ouverture
-- ---------------------------------------------------------------------
Config.Command = 'boutique'       -- /boutique
Config.Key = 'F7'                 -- touche par défaut (chaque joueur peut la changer : Paramètres › Raccourcis › FiveM)
                                  -- ATTENTION : elyzea_animaux utilise déjà F7 (Config.Keys.menu). Choisissez une autre touche
                                  -- pour l'une des deux ressources, sinon F7 ouvrira les deux interfaces.

-- ---------------------------------------------------------------------
-- Framework et intégrations
-- ---------------------------------------------------------------------
Config.Framework = 'auto'         -- 'auto' (es_extended puis elyzea_core), 'esx' ou 'elyzea'
Config.Integrations = {
    vehicles = true,              -- livraison de véhicules (garage du serveur)
    items = true,                 -- livraison d'objets d'inventaire
    money = false,                -- livraison d'argent de jeu ESX/Elyzea (désactivée par défaut)
}

-- Véhicules ESX (si vous passez sur ESX) : table et colonnes de votre garage
Config.EsxVehicles = {
    table = 'owned_vehicles', owner = 'owner', plate = 'plate', vehicle = 'vehicle',
    extra = { type = 'car', stored = 1 },  -- colonnes supplémentaires ({} si votre table ne les a pas)
}
-- Véhicules elyzea_core (elyzea_garage) : table player_vehicles, garage par défaut
Config.ElyzeaVehicles = { garage = 'public' }
Config.PlatePrefix = 'EZ'         -- préfixe des plaques générées (8 caractères au total)

-- ---------------------------------------------------------------------
-- Tebex (paiement en argent réel)
-- ---------------------------------------------------------------------
Config.Tebex = {
    -- Adresse publique de votre boutique Tebex (affichée/ouverte dans le navigateur du joueur)
    storeUrl = 'https://elyzea.tebex.io',
    -- Page d'un paquet : {store} et {id} sont remplacés
    packageUrl = '{store}/package/{id}',
    -- Connexion directe (clé sv_tebexSecret) : paquets, prix et images lus sur Tebex toutes les X minutes
    syncMinutes = 10,
    autoStoreUrl = true,          -- l'adresse de la boutique est celle donnée par Tebex (storeUrl ci-dessus sert de secours)
    directCheckout = true,        -- « Acheter » crée un lien de paiement personnel lié au compte Cfx.re du joueur
                                  -- (en cas d'erreur Tebex : page du paquet à la place)
}

-- ---------------------------------------------------------------------
-- Livraison
-- ---------------------------------------------------------------------
Config.Delivery = {
    retrySeconds = 60,            -- nouvel essai des livraisons en échec pour les joueurs connectés
    maxAttempts = 10,             -- au-delà : « échouée », à relancer par un admin (/shopadmin retry)
    notify = true,
}

-- Droits administrateur (ACE). Exemple dans server.cfg : add_ace group.admin elyzea_shop.admin allow
Config.AdminAce = 'elyzea_shop.admin'

-- Admin menu : ressource autorisée à modifier la boutique (onglet « Boutique », réservé aux Fondateurs).
-- Les modifications faites dans l'admin menu sont enregistrées en base (elyzea_shop_catalog) et remplacent
-- les produits / catégories de ce fichier, qui ne servent alors plus que de valeurs de départ.
Config.AdminMenuResource = 'admin_menu'

-- Commandes serveur prédéfinies utilisables comme récompense (type 'command'). Jamais de texte libre.
-- Variables : {source} (id du joueur), {account} (identifiant Cfx.re numérique), {char} (personnage).
Config.Commands = {
    -- exemple : vip_queue = { grant = 'add_ace identifier.fivem:{account} queue.priority allow', revoke = 'remove_ace identifier.fivem:{account} queue.priority allow' },
}

-- ---------------------------------------------------------------------
-- Elyzea Coins (monnaie virtuelle interne, distincte de l'argent de jeu)
-- ---------------------------------------------------------------------
Config.Coins = {
    enabled = true,
    label = 'Elyzea Coins',
    short = 'EC',
    maxBalance = 10000000,        -- plafond par compte
    -- Remboursement Tebex d'un pack de coins : retirer les coins (dans la limite du solde)
    revokeOnRefund = true,
}

-- ---------------------------------------------------------------------
-- Catalogue
-- ---------------------------------------------------------------------
Config.Categories = {
    { id = 'vip',      label = 'VIP',               icon = 'crown',  description = 'Les grades premium d\'Elyzea RP.' },
    { id = 'coins',    label = 'Elyzea Coins',      icon = 'coin',   description = 'La monnaie de la boutique, utilisable en jeu.' },
    { id = 'vehicles', label = 'Véhicules premium', icon = 'car',    description = 'Livrés dans votre garage.' },
}

--[[ Produit :
    key (clé du tableau)  identifiant interne, utilisé dans la commande Tebex (lettres, chiffres, _)
    category, label, description, image (html/assets/...), perks = { 'texte', ... }
    displayPrice          prix affiché (texte libre, ex. '9,99 €') ; nil = « voir sur Tebex »
    tebexPackageId        ID du paquet Tebex → bouton « Acheter avec Tebex » (nil = pas vendu en argent réel)
    coinsPrice            prix en Elyzea Coins → bouton « Acheter avec des coins » (nil = non achetable en coins)
    durationDays          durée (nil = permanent) ; pour un paquet Tebex à durée, la fin est gérée par la commande d'expiration Tebex
    rewards = {
        { type = 'group',   name = 'vip_sapphire' }          -- ACE group.vip_sapphire + exports HasPerk
        { type = 'perk',    name = 'custom_plate' }          -- avantage lisible par vos scripts
        { type = 'coins',   amount = 1000 }                  -- crédit d'Elyzea Coins
        { type = 'vehicle', model = 'sultanrs', garage = nil }
        { type = 'item',    name = 'phone', count = 1 }
        { type = 'money',   account = 'bank', amount = 1000 } -- seulement si Config.Integrations.money = true
        { type = 'command', name = 'vip_queue' }             -- commande de Config.Commands
    }
]]
Config.Products = {
    -- ----- VIP (exemples : avantages et prix à définir) -----
    sapphire = {
        category = 'vip', label = 'Elyzea Sapphire', image = 'assets/products/sapphire.webp',
        description = 'Premier grade premium d\'Elyzea RP. Décrivez ici ce que le grade apporte réellement sur votre serveur.',
        perks = { 'Avantage à définir dans config.lua' },
        displayPrice = nil, tebexPackageId = nil, coinsPrice = nil, durationDays = 30,
        rewards = { { type = 'group', name = 'vip_sapphire' } },
    },
    royale = {
        category = 'vip', label = 'Elyzea Royale', image = 'assets/products/royale.webp',
        description = 'Grade premium intermédiaire. Décrivez ici ses avantages réels.',
        perks = { 'Avantage à définir dans config.lua' },
        displayPrice = nil, tebexPackageId = nil, coinsPrice = nil, durationDays = 30,
        rewards = { { type = 'group', name = 'vip_royale' } },
    },
    divinity = {
        category = 'vip', label = 'Elyzea Divinity', image = 'assets/products/divinity.webp',
        description = 'Le plus haut grade premium d\'Elyzea RP. Décrivez ici ses avantages réels.',
        perks = { 'Avantage à définir dans config.lua' },
        displayPrice = nil, tebexPackageId = nil, coinsPrice = nil, durationDays = 30,
        rewards = { { type = 'group', name = 'vip_divinity' } },
    },
    -- ----- Elyzea Coins (packs vendus via Tebex : vérifiez les règles Cfx.re / Tebex avant de les activer) -----
    coins_1000 = {
        category = 'coins', label = '1 000 Elyzea Coins', image = 'assets/products/coins.webp',
        description = 'Crédite 1 000 Elyzea Coins sur votre compte.',
        perks = {}, displayPrice = nil, tebexPackageId = nil,
        rewards = { { type = 'coins', amount = 1000 } },
    },
    -- ----- Véhicules premium (exemple : achetable en coins) -----
    vehicle_example = {
        category = 'vehicles', label = 'Véhicule premium (exemple)', image = 'assets/products/vehicle.webp',
        description = 'Exemple : remplacez le modèle par un véhicule installé sur votre serveur.',
        perks = { 'Livré dans votre garage' },
        displayPrice = nil, tebexPackageId = nil, coinsPrice = nil,
        rewards = { { type = 'vehicle', model = 'sultanrs' } },
    },
}

Config.Locale = {
    delivered = '%s : livré. Merci pour votre soutien !',
    revoked = '%s : terminé.',
    no_account = 'Votre jeu n\'est pas relié à un compte Cfx.re : connectez-vous dans FiveM pour utiliser la boutique.',
    wait = 'Patientez un instant.',
}
