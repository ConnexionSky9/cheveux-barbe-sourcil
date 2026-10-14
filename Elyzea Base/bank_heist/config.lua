-- =====================================================================
--  BANK HEIST - valeurs PAR DÉFAUT
--  Tout se règle ensuite en jeu : admin_menu › « Braquage de banque » (permission « bankheist_manage »).
--  Les réglages modifiés sont enregistrés en base (table bh_settings) et restaurés au démarrage.
--  Positions : x, y, z = position d'un joueur debout à l'endroit voulu (bouton « Placer ici »).
--  Les positions de la Fleeca de Legion Square ci-dessous sont des valeurs de départ :
--  avec un intérieur modifié (MLO), replacez chaque point en jeu.
-- =====================================================================
Config = {}

Config.Defaults = {
    general = {
        enabled = true,
        maxSimultaneous = 1,        -- braquages de banque en même temps sur le serveur
        globalCooldown = 30,        -- minutes entre deux braquages (toutes banques)
        participantRadius = 15.0,   -- joueurs pris comme braqueurs autour du point de départ
        lateJoin = true,            -- un joueur arrivé après le départ peut participer (dans la limite du maximum)
        bankRadius = 45.0,          -- zone de la banque (abandon si plus aucun braqueur dedans)
        abandonMinutes = 8,         -- braquage abandonné si personne dans la banque pendant N minutes
        interactDistance = 2.0,
        depositKey = 38,            -- E
        depositKeyLabel = 'E',
    },

    -- Objets (noms = objets de l'inventaire)
    items = {
        laptop = { name = 'bank_laptop', label = 'Ordinateur de piratage', price = 25000, maxOwned = 1 },
        bag = { name = 'bank_bag', label = 'Sac de braqueur', price = 5000, maxOwned = 2 },
        c4 = { name = 'bank_c4', label = 'Charge C4', price = 15000, maxOwned = 2, sell = true },
    },

    -- Marchands de matériel (PNJ)
    merchants = {
        {
            id = 'fournisseur', name = 'Fournisseur', enabled = true,
            ped = { model = 'g_m_m_chicold_01', x = 1240.62, y = -3179.31, z = 7.10, h = 270.0 },
            scenario = 'WORLD_HUMAN_SMOKING', interactDistance = 2.0,
            payment = 'cash',               -- 'cash', 'bank' ou 'item' (loot.moneyItem)
            sells = { laptop = true, bag = true, c4 = true },
            jobs = {},                      -- métiers autorisés (vide = tout le monde)
            forbidPolice = true,            -- les policiers en service ne peuvent pas acheter
            blip = { enabled = false, sprite = 500, color = 1, scale = 0.7 },
        },
    },

    -- Piratage
    hack = {
        attempts = 3,               -- tentatives par ordinateur (enregistrées sur le serveur, par numéro de série)
        retryDelay = 5,             -- secondes entre deux tentatives
        requireThreat = true,       -- l'employé doit avoir été menacé avant le piratage
        anim = { dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base', name = 'base', flag = 49 },
        prop = 'prop_laptop_01a',
        games = {
            sequence = { enabled = true, weight = 1, time = 25, difficulty = 2 },
            circuit  = { enabled = true, weight = 1, time = 30, difficulty = 2 },
            code     = { enabled = true, weight = 1, time = 60, difficulty = 2 },
            sync     = { enabled = true, weight = 1, time = 30, difficulty = 2 },
            logic    = { enabled = true, weight = 1, time = 45, difficulty = 2 },
        },
    },

    -- C4
    c4 = {
        delay = 10,                 -- secondes entre la pose et l'explosion
        plantTime = 5,              -- durée de l'animation de pose (s)
        prop = 'prop_c4_final_green',
        anim = { dict = 'anim@heists@ornate_bank@thermal_charge', name = 'thermal_charge', flag = 0 },
        explosionType = 2,          -- 2 = charge collante (explosion modérée, sans dégâts : damageScale 0)
    },

    -- Coffre et butin
    loot = {
        rewardType = 'item',        -- encaissement : 'cash', 'bank' ou 'item' (argent sale)
        moneyItem = 'black_money',
        depositRate = 100,          -- % du contenu du sac versé au dépôt
        bagCapacity = 200000,       -- montant maximal dans un sac
        perTick = 5000,             -- montant ramassé par seconde
        openDuration = 300,         -- secondes pendant lesquelles le coffre reste ouvert
        bonus = { enabled = true, chance = 20, min = 110, max = 130 },   -- % appliqué au butin (bonus)
        malus = { enabled = false, chance = 15, min = 70, max = 90 },    -- % appliqué au butin (malus)
        extras = {                  -- objets en plus dans le coffre (tirés à l'ouverture, « Prendre les objets »)
            { item = 'goldbar', chance = 30, min = 1, max = 3, enabled = true },
        },
    },

    -- Banques
    banks = {
        {
            id = 'fleeca_legion', name = 'Fleeca Legion Square', enabled = true,
            start = { x = 150.27, y = -1040.23, z = 29.37 },
            clerk = { model = 'u_m_m_bankman', x = 149.47, y = -1042.08, z = 29.37, h = 340.0 },
            vault = { x = 147.04, y = -1044.89, z = 29.37, h = 245.0 },
            -- porte du coffre (objet de la carte) : cherchée près de x, y, z. Elle est FERMÉE (orientation closedHeading)
            -- tant que le coffre n'est pas ouvert, puis tourne de openOffset degrés après un piratage réussi ou la C4.
            -- closedHeading = -1 : orientation d'origine de l'objet sur la carte.
            door = { enabled = true, model = 'v_ilev_gb_vaultdr', x = 148.03, y = -1044.36, z = 29.51, closedHeading = 250.0, openOffset = -90.0 },
            cash = { { x = 149.43, y = -1050.42, z = 29.35, h = 340.0 }, { x = 147.12, y = -1049.82, z = 29.35, h = 340.0 } },
            minCops = 3, minRobbers = 2, maxRobbers = 6, cooldown = 90,
            hours = { from = 0, to = 0 },           -- heures autorisées (0 -> 0 = toute la journée ; ex. 18 -> 4)
            required = { laptop = true, bag = true, c4 = true },   -- matériel nécessaire pour lancer (au moins un braqueur l'a)
            threatTime = 8,                          -- durée de la séquence de menace (s)
            loot = { min = 80000, max = 140000 },
            blip = { enabled = true, sprite = 108, color = 2, scale = 0.7 },
        },
    },

    -- Points de dépôt (encaissement du sac)
    deposits = {
        { id = 'blanchisseur', name = 'Planque', enabled = true, x = 2341.10, y = 3127.12, z = 48.21, radius = 2.5, allowPassenger = false },
    },

    -- Visuels
    visuals = {
        trolleyFull = 'hei_prop_hei_cash_trolly_01',
        trolleyEmpty = 'hei_prop_hei_cash_trolly_03',
        collectAnim = { dict = 'anim@heists@ornate_bank@grab_cash', name = 'grab', flag = 1 },
        threatPanic = { dict = 'missminuteman_1ig_2', name = 'handsup_base', flag = 49 },
        threatKneel = { dict = 'random@arrests@busted', name = 'idle_a', flag = 1 },
        depositAnim = { dict = 'random@domestic', name = 'pickup_low', time = 1000 },
    },

    police = {
        title = 'Braquage de banque en cours',
        alertKind = 'robbery',
        jobs = { 'police' },        -- si elyzea_police n'est pas démarré
    },

    security = { rateLimit = 8, logRetentionDays = 30 },
}

Config.PedModels = { 'u_m_m_bankman', 'a_f_y_business_02', 'a_m_y_business_03', 's_m_m_highsec_01', 'g_m_m_chicold_01', 'g_m_y_lost_01', 'a_m_m_hasjew_01' }
Config.GameList = { 'sequence', 'circuit', 'code', 'sync', 'logic' }
Config.GameLabels = { sequence = 'Séquence de symboles', circuit = 'Connexion de circuits', code = 'Déchiffrement de code', sync = 'Synchronisation', logic = 'Décryptage de données' }
Config.ImagePath = 'nui://elyzea_inventory/html/img/%s.png'
