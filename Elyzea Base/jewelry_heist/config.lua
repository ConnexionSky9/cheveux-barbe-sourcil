-- =====================================================================
--  JEWELRY HEIST - valeurs PAR DÉFAUT
--  Tout se règle ensuite en jeu : admin_menu › « Braquage bijouterie » (permission « heist_manage »).
--  Les réglages modifiés sont enregistrés en base (table jh_settings) et restaurés au démarrage.
--  « Valeurs par défaut » dans le menu revient à ce fichier.
--  Positions : x, y, z = position d'un joueur debout à l'endroit voulu (bouton « Placer ici »).
-- =====================================================================
Config = {}

Config.Defaults = {
    -- A. Général -------------------------------------------------------
    general = {
        enabled = true,
        locale = 'fr',              -- 'fr' ou 'en' (fichiers locales/)
        altFallbackKey = 'LMENU',   -- information : touche du menu autonome (si elyzea_police n'est pas démarré), modifiable par chaque joueur dans les touches FiveM
        dropKey = 38,               -- touche de dépôt du sac (38 = E)
        dropKeyLabel = 'E',
        interactDistance = 2.0,     -- distance pour parler à un PNJ
        notifyDuration = 6000,
    },

    -- F. Les cinq pierres (identifiants = objets de l'inventaire) --------
    gems = {
        diamond  = { label = 'Diamant',   description = 'Diamant taillé, pur et brillant.',       price = 1500, enabled = true, min = 1, max = 4,  chance = 45, maxPerHeist = 4,  shops = {}, buyers = {} },
        ruby     = { label = 'Rubis',     description = 'Rubis rouge intense, taille coussin.',    price = 1000, enabled = true, min = 1, max = 5,  chance = 60, maxPerHeist = 5,  shops = {}, buyers = {} },
        sapphire = { label = 'Saphir',    description = 'Saphir bleu profond, taille ovale.',      price = 800,  enabled = true, min = 1, max = 6,  chance = 70, maxPerHeist = 6,  shops = {}, buyers = {} },
        emerald  = { label = 'Émeraude',  description = 'Émeraude verte, taille à degrés.',        price = 1200, enabled = true, min = 1, max = 4,  chance = 50, maxPerHeist = 4,  shops = {}, buyers = {} },
        amethyst = { label = 'Améthyste', description = 'Améthyste violette, taille poire.',       price = 500,  enabled = true, min = 2, max = 8,  chance = 80, maxPerHeist = 8,  shops = {}, buyers = {} },
    },

    -- B, C, E. Bijouteries (PNJ bijoutier, braquage, butin, vente normale) --
    shops = {
        {
            id = 'vangelico', name = 'Vangelico', enabled = true,
            ped = { model = 's_f_m_shop_high', x = -622.19, y = -229.94, z = 38.06, h = 306.0 },
            bagSpot = { x = -622.95, y = -229.14, z = 38.06 },     -- où le PNJ pose le sac (vide = devant le PNJ)
            interactDistance = 2.0,
            sale = { buy = true, sell = true, buyMarkup = 180, sellRate = 55, maxPerTx = 10, payment = 'bank' },
            robbery = {
                enabled = true, minCops = 2, cooldown = 45, unavailable = 30,
                robDistance = 4.0, cancelDistance = 12.0,
                onLeave = 'cancel',      -- le braqueur s'éloigne : 'cancel' (annulé) ou 'continue'
                onDeath = 'cancel',      -- le braqueur tombe : 'cancel' ou 'continue'
                cooldownOnCancel = true, -- un braquage annulé déclenche quand même le délai
            },
            loot = { moneyMin = 5000, moneyMax = 10000, gems = {} },  -- gems = { diamond = { enabled, min, max, chance } } pour remplacer les valeurs globales
            blip = { enabled = true, sprite = 617, color = 3, scale = 0.8 },
        },
    },

    -- C. Conditions communes -------------------------------------------
    robbery = {
        weapons = { 'WEAPON_PISTOL', 'WEAPON_COMBATPISTOL', 'WEAPON_PISTOL50', 'WEAPON_SNSPISTOL', 'WEAPON_HEAVYPISTOL', 'WEAPON_VINTAGEPISTOL',
            'WEAPON_MICROSMG', 'WEAPON_SMG', 'WEAPON_ASSAULTSMG', 'WEAPON_MINISMG', 'WEAPON_ASSAULTRIFLE', 'WEAPON_CARBINERIFLE', 'WEAPON_PUMPSHOTGUN',
            'WEAPON_SAWNOFFSHOTGUN', 'WEAPON_KNIFE', 'WEAPON_SWITCHBLADE' },
        globalCooldown = 15,        -- minutes entre deux braquages, toutes bijouteries confondues
    },

    -- D. Animations ----------------------------------------------------
    anims = {
        panicTime = 8,              -- secondes de panique (mains levées)
        fillTime = 60,              -- secondes de remplissage du sac (30, 60, 90, 120…)
        handoverDelay = 3,          -- secondes avant la remise du sac
        progress = true,            -- barre de progression pour le braqueur
        panic = { dict = 'missminuteman_1ig_2', name = 'handsup_base', flag = 49 },
        fill = { dict = 'oddjobs@shop_robbery@rob_till', name = 'loop', flag = 1 },
        handover = { dict = 'mp_common', name = 'givetake1_a', flag = 0 },
        fallbackPanic = 'CODE_HUMAN_COWER',          -- scénario si l'animation ne charge pas
        fallbackFill = 'PROP_HUMAN_BUM_BIN',
        pickup = { dict = 'random@domestic', name = 'pickup_low', time = 1200 },
    },

    -- E. Butin (commun) ------------------------------------------------
    loot = {
        moneyType = 'cash',         -- 'cash' (liquide), 'bank' (compte) ou 'item' (objet ci-dessous)
        moneyItem = 'black_money',  -- objet utilisé si moneyType = 'item'
    },

    -- G. Sac -------------------------------------------------------------
    bag = {
        model = 'prop_cs_heist_bag_02',
        mode = 'prop',              -- 'prop' (objet attaché au dos) ou 'component' (sac de tenue GTA, mieux en véhicule)
        bone = 24818,               -- SKEL_Spine3 (dos)
        offset = { x = -0.05, y = -0.22, z = 0.0 },
        rotation = { x = 0.0, y = 90.0, z = 180.0 },
        component = { male = { drawable = 45, texture = 0 }, female = { drawable = 45, texture = 0 } },  -- composant 5 (sacs)
        pickupDistance = 2.0,
        dropAnim = { dict = 'random@domestic', name = 'pickup_low', time = 900 },
        pickupRule = 'anyone',      -- 'anyone' ou 'owner' (seul le braqueur peut ramasser)
        openRule = 'anyone',        -- 'anyone' ou 'owner'
        policeSeize = true,         -- policiers en service : « Saisir le contenu » (vide le sac, tracé)
        onDeath = 'drop',           -- le porteur tombe : 'drop' (sac au sol) ou 'keep'
        onDisconnect = 'drop',      -- déconnexion : 'drop' (sac au sol) ou 'keep' (rendu à la reconnexion)
        cleanupMinutes = 60,        -- sac au sol abandonné supprimé après N minutes (0 = jamais)
        maxGroundBags = 30,
    },

    -- H. Police ----------------------------------------------------------
    police = {
        jobs = { 'police' },        -- métiers destinataires (si elyzea_police n'est pas utilisé)
        dispatch = 'auto',          -- 'auto' (elyzea_police si démarré, sinon interne), 'elyzea_police', 'internal', 'both'
        alertKind = 'robbery',      -- type d'alerte elyzea_police
        title = 'Braquage de bijouterie en cours',
        notify = true,
        blip = { sprite = 617, color = 1, scale = 1.2, radius = 60.0, radiusColor = 1, duration = 180, flash = true },
    },

    -- I. Racheteurs ------------------------------------------------------
    buyers = {
        {
            id = 'receleur', name = 'Receleur', enabled = true,
            ped = { model = 'g_m_m_armboss_01', x = 707.32, y = -966.93, z = 30.41, h = 180.0 },
            interactDistance = 2.0,
            accepted = { diamond = true, ruby = true, sapphire = true, emerald = true, amethyst = true },
            prices = {},            -- { diamond = 1700 } pour remplacer le prix global
            maxPerTx = 20,
            payment = 'cash',       -- 'cash', 'bank' ou 'item' (loot.moneyItem)
            blip = { enabled = false, sprite = 500, color = 5, scale = 0.7 },
        },
    },

    -- J. Sécurité --------------------------------------------------------
    security = {
        rateLimit = 6,              -- actions max par joueur et par tranche de 3 s
        logRetentionDays = 30,
    },
}

-- Modèles de PNJ proposés dans le menu (on peut en saisir d'autres)
Config.PedModels = { 's_f_m_shop_high', 's_m_m_highsec_01', 'a_f_y_business_02', 'a_m_y_business_03', 'g_m_m_armboss_01', 'g_m_y_famca_01',
    'a_m_m_hasjew_01', 'u_m_m_jewelsec_01', 'u_m_m_jeweller', 'cs_gurk' }

-- Liste des armes proposées dans le menu (on peut en saisir d'autres)
Config.WeaponChoices = { 'WEAPON_PISTOL', 'WEAPON_COMBATPISTOL', 'WEAPON_APPISTOL', 'WEAPON_PISTOL50', 'WEAPON_SNSPISTOL', 'WEAPON_HEAVYPISTOL',
    'WEAPON_VINTAGEPISTOL', 'WEAPON_REVOLVER', 'WEAPON_MICROSMG', 'WEAPON_SMG', 'WEAPON_ASSAULTSMG', 'WEAPON_MINISMG', 'WEAPON_MACHINEPISTOL',
    'WEAPON_ASSAULTRIFLE', 'WEAPON_CARBINERIFLE', 'WEAPON_ADVANCEDRIFLE', 'WEAPON_COMPACTRIFLE', 'WEAPON_PUMPSHOTGUN', 'WEAPON_SAWNOFFSHOTGUN',
    'WEAPON_KNIFE', 'WEAPON_SWITCHBLADE', 'WEAPON_MACHETE', 'WEAPON_BAT' }

Config.GemOrder = { 'diamond', 'ruby', 'sapphire', 'emerald', 'amethyst' }
Config.ImagePath = 'nui://elyzea_inventory/html/img/%s.png'   -- icônes des bijoux (copie de secours : html/img de cette ressource)
