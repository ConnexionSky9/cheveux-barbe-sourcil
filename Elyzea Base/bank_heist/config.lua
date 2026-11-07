-- =====================================================================
--  BANK HEIST 2.0 - valeurs PAR DÉFAUT
--  Tout se règle ensuite en jeu : admin_menu › « Braquage de banque » (permission « bankheist_manage »).
--  Les réglages modifiés sont enregistrés en base (table bh_settings) et restaurés au démarrage.
--  Positions : x, y, z = position d'un joueur debout à l'endroit voulu (bouton « Placer ici »).
--
--  Déroulé : indic (adresse du marchand) → marchand (matériel) → banquier (ALT, arme en main :
--  « BRAQUER LA BANQUE ») → alarme + police prévenue → porte du coffre : décryptage (ordinateur,
--  mini-jeu) ou C4 → butin (chariots, liasses, lingots, coffres individuels à la perceuse) dans le sac
--  → couper l'alarme (pinces, mini-jeu) → fuite → encaissement à une planque.
--  Hors braquage, le banquier tient le guichet : dépôt, retrait, virement, historique (ALT).
-- =====================================================================
Config = {}

Config.Defaults = {
    general = {
        enabled = true,
        maxSimultaneous = 1,        -- braquages de banque en même temps sur le serveur
        globalCooldown = 30,        -- minutes entre deux braquages (toutes banques)
        participantRadius = 15.0,   -- joueurs pris comme braqueurs autour du banquier au lancement
        lateJoin = true,            -- un joueur arrivé après le départ peut participer (dans la limite du maximum)
        bankRadius = 45.0,          -- zone de la banque (alarme, abandon)
        abandonMinutes = 8,         -- braquage abandonné si personne dans la banque pendant N minutes
        interactDistance = 2.0,
        depositKey = 38,            -- E
        depositKeyLabel = 'E',
    },

    -- Objets (noms = objets de l'inventaire)
    items = {
        laptop = { name = 'bank_laptop', label = 'Ordinateur de décryptage', price = 25000, maxOwned = 1 },
        bag = { name = 'bank_bag', label = 'Sac de braqueur', price = 5000, maxOwned = 2 },
        c4 = { name = 'bank_c4', label = 'Charge C4', price = 15000, maxOwned = 2, sell = true },
        drill = { name = 'bank_drill', label = 'Perceuse de coffre', price = 18000, maxOwned = 1, sell = true },
    },

    -- Marchands de matériel (PNJ)
    merchants = {
        {
            id = 'fournisseur', name = 'Fournisseur', enabled = true,
            ped = { model = 'g_m_m_chicold_01', x = 1240.62, y = -3179.31, z = 7.10, h = 270.0 },
            scenario = 'WORLD_HUMAN_SMOKING', interactDistance = 2.0,
            payment = 'cash',               -- 'cash', 'bank' ou 'item' (loot.moneyItem)
            sells = { laptop = true, bag = true, c4 = true, drill = true },
            jobs = {},                      -- métiers autorisés (vide = tout le monde)
            forbidPolice = true,            -- les policiers en service ne peuvent pas acheter
            blip = { enabled = false, sprite = 500, color = 1, scale = 0.7 },
        },
    },

    -- Indics : contre un billet, donnent l'emplacement d'un marchand (point GPS + repère temporaire)
    informants = {
        {
            id = 'indic_sud', name = 'Lenny « l\'Oreille »', enabled = true,
            ped = { model = 'a_m_m_tramp_01', x = 126.34, y = -1281.55, z = 29.27, h = 120.0 },
            scenario = 'WORLD_HUMAN_LEANING', interactDistance = 2.2,
            price = 750, payment = 'cash',
            merchant = '',                  -- identifiant du marchand indiqué (vide = le plus proche actif)
            blipMinutes = 10,               -- durée du repère sur la carte
            cooldown = 15,                  -- minutes avant de pouvoir lui reparler (par personnage)
            forbidPolice = true,
            hours = { from = 0, to = 0 },   -- heures de présence (0 -> 0 = toute la journée)
            greeting = 'T\'as la tête de quelqu\'un qui cherche du matos… Moi je sais où trouver le fournisseur. Mais rien n\'est gratuit, ici.',
            answer = 'Il traîne du côté indiqué sur ta carte. Tu dis pas que ça vient de moi, compris ?',
        },
    },

    -- Porte du coffre : méthodes d'ouverture
    door = {
        hack = true,                -- décryptage avec l'ordinateur (mini-jeu)
        c4 = true,                  -- charge C4
        c4OnlyAfterHack = false,    -- true : C4 seulement quand le décryptage a échoué (ordinateur grillé)
        openTime = 5,               -- durée de l'animation d'ouverture (s)
    },

    -- Décryptage
    hack = {
        attempts = 3,               -- tentatives par ordinateur (enregistrées sur le serveur, par numéro de série)
        retryDelay = 5,             -- secondes entre deux tentatives
        requireThreat = true,       -- le banquier doit avoir été braqué (mains en l'air) avant le décryptage
        games = {
            sequence = { enabled = true, weight = 1, time = 30, difficulty = 1 },
            circuit  = { enabled = true, weight = 1, time = 35, difficulty = 1 },
            code     = { enabled = true, weight = 1, time = 75, difficulty = 1 },
            sync     = { enabled = true, weight = 1, time = 35, difficulty = 1 },
            logic    = { enabled = true, weight = 1, time = 60, difficulty = 1 },
        },
    },

    -- C4
    c4 = {
        delay = 10,                 -- secondes entre la pose et l'explosion
        plantTime = 5,              -- durée de la pose (s)
        prop = 'prop_c4_final_green',
        explosionType = 2,          -- 2 = charge collante (effet et son, sans dégâts)
        shake = 0.6,                -- secousse de caméra pour les joueurs proches (0 = aucune)
        alertPolice = true,         -- l'explosion envoie une seconde alerte à la police
    },

    -- Perceuse (coffres individuels)
    drill = {
        time = 25,                  -- secondes de perçage efficace
        heatRate = 1.0,             -- vitesse de chauffe (1 = normale)
        prop = 'hei_prop_heist_drill',
    },

    -- Alarme de la banque : déclenchée au lancement, à couper au boîtier (pinces : mini-jeu des fils)
    alarm = {
        enabled = true,
        maxMinutes = 10,            -- coupée d'elle-même au bout de N minutes
        volume = 0.6,               -- volume maximal (0 à 1)
        lights = true,              -- lumières rouges clignotantes dans la banque
        robbersCanDisable = true,   -- les braqueurs peuvent la couper (mini-jeu des fils)
        policeCanDisable = true,    -- les policiers en service la coupent directement
        wiresTime = 20,             -- durée du mini-jeu des fils (s)
        failRealert = true,         -- fil coupé au mauvais endroit : nouvelle alerte police
    },

    -- Butin
    loot = {
        rewardType = 'item',        -- encaissement : 'cash', 'bank' ou 'item' (argent sale)
        moneyItem = 'black_money',
        depositRate = 100,          -- % du contenu du sac versé au dépôt
        bagCapacity = 250000,       -- montant maximal dans un sac
        perTick = 5000,             -- montant ramassé par seconde
        openDuration = 420,         -- secondes pendant lesquelles le coffre reste ouvert
        bonus = { enabled = true, chance = 20, min = 110, max = 130 },   -- % appliqué au butin (bonus)
        malus = { enabled = false, chance = 15, min = 70, max = 90 },    -- % appliqué au butin (malus)
    },

    -- Banques
    banks = {
        {
            id = 'fleeca_legion', name = 'Fleeca Legion Square', enabled = true,
            banker = { model = 'u_m_m_bankman', x = 149.47, y = -1042.08, z = 29.37, h = 340.0 },
            door = { enabled = true, model = 'v_ilev_gb_vauldr', x = 148.03, y = -1044.36, z = 29.51, closedHeading = 250.0, openOffset = -90.0 },
            doorPoint = { x = 147.04, y = -1044.89, z = 29.37, h = 245.0 },   -- où le braqueur se tient pour décrypter / poser la C4
            alarm = { x = 150.80, y = -1036.90, z = 29.37 },                  -- boîtier de l'alarme
            loot = {
                -- type : trolley_cash, trolley_gold, trolley_diamond, stack_cash, stack_gold, boxes (perceuse), custom (model)
                { type = 'trolley_cash', x = 149.43, y = -1050.42, z = 29.35, h = 340.0, min = 30000, max = 50000 },
                { type = 'trolley_cash', x = 147.12, y = -1049.82, z = 29.35, h = 340.0, min = 30000, max = 50000 },
                { type = 'boxes', x = 151.20, y = -1046.60, z = 29.35, h = 250.0, min = 15000, max = 30000 },
            },
            minCops = 3, minRobbers = 2, maxRobbers = 6, cooldown = 90,
            hours = { from = 0, to = 0 },           -- heures autorisées (0 -> 0 = toute la journée ; ex. 18 -> 4)
            required = { tool = 'any', bag = true }, -- outil exigé au lancement : 'any' (ordinateur ou C4), 'laptop', 'c4', 'none'
            threatTime = 8,                          -- durée des mains en l'air avant que le banquier se mette à genoux (s)
            blip = { enabled = true, sprite = 108, color = 2, scale = 0.7 },
        },
    },

    -- Guichet (banquier hors braquage)
    banking = {
        enabled = true,
        minAmount = 1,
        maxTransfer = 1000000,
        transferFee = 0,            -- % prélevé sur un virement (0 = gratuit)
    },

    -- Points de dépôt (encaissement du sac)
    deposits = {
        { id = 'blanchisseur', name = 'Planque', enabled = true, x = 2341.10, y = 3127.12, z = 48.21, radius = 2.5, allowPassenger = false },
    },

    -- Animations (dictionnaire, nom, option)
    visuals = {
        bankerHandsUp = { dict = 'missminuteman_1ig_2', name = 'handsup_base', flag = 49 },
        bankerKneel = { dict = 'random@arrests@busted', name = 'idle_a', flag = 1 },
        depositAnim = { dict = 'random@domestic', name = 'pickup_low', time = 1000 },
    },

    police = {
        title = 'Braquage de banque en cours',
        alertKind = 'robbery',
        jobs = { 'police' },        -- si elyzea_police n'est pas démarré
    },

    security = { rateLimit = 10, logRetentionDays = 30 },
}

-- Types de butin proposés au staff (modèle plein / vide, animation, outil exigé)
Config.LootTypes = {
    trolley_cash    = { label = 'Chariot de billets', model = 'hei_prop_hei_cash_trolly_01', empty = 'hei_prop_hei_cash_trolly_03', anim = 'trolley', pile = 'hei_prop_heist_cash_pile' },
    trolley_gold    = { label = 'Chariot de lingots', model = 'ch_prop_gold_trolly_01a', empty = 'hei_prop_hei_cash_trolly_03', anim = 'trolley', pile = 'ch_prop_gold_bar_01a' },
    trolley_diamond = { label = 'Chariot de diamants', model = 'ch_prop_diamond_trolly_01a', empty = 'hei_prop_hei_cash_trolly_03', anim = 'trolley', pile = 'ch_prop_vault_dimaondbox_01a' },
    stack_cash      = { label = 'Liasses de billets (table)', model = 'h4_prop_h4_cash_stack_01a', anim = 'table' },
    stack_gold      = { label = 'Pile de lingots (table)', model = 'h4_prop_h4_gold_stack_01a', anim = 'table' },
    boxes           = { label = 'Coffres individuels (perceuse)', model = '', anim = 'drill', tool = 'drill' },
    custom          = { label = 'Modèle personnalisé', model = '', anim = 'table' },
}
Config.LootTypeList = { 'trolley_cash', 'trolley_gold', 'trolley_diamond', 'stack_cash', 'stack_gold', 'boxes', 'custom' }

Config.PedModels = { 'u_m_m_bankman', 'a_f_y_business_02', 'a_m_y_business_03', 's_m_m_highsec_01', 'g_m_m_chicold_01', 'g_m_y_lost_01', 'a_m_m_tramp_01', 'a_m_o_soucent_02' }
-- Multiplicateur du temps des mini-jeux (1.5 = 50 % de temps en plus que la valeur réglée dans le menu staff)
Config.HackTimeFactor = 1.5
Config.GameList = { 'sequence', 'circuit', 'code', 'sync', 'logic' }
Config.GameLabels = { sequence = 'Séquence de symboles', circuit = 'Connexion de circuits', code = 'Déchiffrement de code', sync = 'Synchronisation', logic = 'Décryptage de données' }
Config.ImagePath = 'nui://elyzea_inventory/html/img/%s.png'
