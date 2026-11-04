-- =====================================================================
--  ELYZEA MANUTENTION - INTÉRIM : MANUTENTIONNAIRE
--  Ce fichier ne contient que les VALEURS DE DÉPART.
--  Tout se règle ensuite en jeu : admin_menu › Économie et services › Manutentionnaire
--  (emplacements, prix, nombre de cartons, course, modèles, Fenwick…).
--  Les réglages faits en jeu sont enregistrés en base (table manut_settings) et
--  REMPLACENT ces valeurs : inutile de revenir ici après l'installation.
-- =====================================================================
Config = {}

Config.Permission = 'manut_manage'       -- permission admin_menu (Staff › Rangs › case « Manutentionnaire »)
Config.AcePermission = 'elyzea_manutention.admin'   -- seulement si admin_menu n'est pas démarré

-- Réglages de départ (modifiables dans le menu admin)
Config.Defaults = {
    enabled = true,                      -- métier ouvert
    boxesPerPallet = 20,                 -- cartons pour une palette complète (1 à 40)
    allowSprint = false,                 -- courir avec un carton dans les bras
    account = 'bank',                    -- paiement sur 'bank' (banque) ou 'cash' (liquide)

    pay = {
        delivery = 250,                  -- RÉMUNÉRATION PAR PALETTE LIVRÉE (payée seulement à la livraison complète)
        perBox = 0, perBoxOn = false,    -- par carton déposé sur la palette
        palletDone = 0, palletDoneOn = false, -- palette complète (20/20)
        transport = 0, transportOn = false,   -- palette chargée sur le Fenwick
    },

    models = {
        npc = 's_m_y_construct_01',
        box = 'hei_prop_heist_box',      -- carton porté dans les bras
        boxOnPallet = 'prop_cs_cardbox_01', -- cartons empilés sur la palette
        pallet = 'prop_pallet_02a',
        forklift = 'forklift',
    },

    npc = { enabled = true, x = 0.0, y = 0.0, z = 0.0, h = 0.0, scenario = 'WORLD_HUMAN_CLIPBOARD', placed = false },

    forklift = {
        enabled = true,                  -- désactivé : pas de Fenwick, la palette ne peut pas être livrée
        max = 10,                        -- Fenwick en même temps sur le serveur (0 = autant que de points de spawn)
        idleMinutes = 20,                -- mission sans aucune action pendant N minutes : travail terminé, Fenwick retiré (0 = jamais)
    },

    -- Emplacements (posés en jeu : « Enregistrer ma position actuelle »)
    pickups = {},                        -- { x, y, z, h, label }
    pallets = {},                        -- { x, y, z, h, label }
    spawns = {},                         -- { x, y, z, h, label }
    deliveries = {},                     -- { x, y, z, h, radius, label }

    -- Tenue (homme / femme) : remplaçable par « Copier ma tenue actuelle » dans le menu admin
    -- c = vêtements { [n° GTA] = { modèle, texture } }, p = accessoires
    outfit = {
        male = { c = { ['3'] = { 0, 0 }, ['4'] = { 9, 7 }, ['6'] = { 25, 0 }, ['8'] = { 59, 1 }, ['11'] = { 56, 0 } },
                 p = { ['0'] = { 0, 2 } } },
        female = { c = { ['3'] = { 14, 0 }, ['4'] = { 9, 7 }, ['6'] = { 25, 0 }, ['8'] = { 36, 1 }, ['11'] = { 49, 0 } },
                   p = { ['0'] = { 0, 2 } } },
    },
}

-- Règles fixes (sécurité, pas d'intérêt à les changer en jeu)
Config.NpcDistance = 3.0                 -- distance max du PNJ pour accepter / terminer
Config.PickupDistance = 2.5              -- distance max d'un point de récupération
Config.PalletDistance = 2.6              -- distance max de la palette pour y poser un carton
Config.ForkDistance = 3.2                -- distance max entre l'avant du Fenwick et la palette pour la soulever
Config.DeliveryRadius = 4.0              -- rayon par défaut d'une zone de livraison (réglable par point)
Config.MinBoxInterval = 2500             -- ms minimum entre deux cartons (anti-triche)
Config.SpawnFreeRadius = 3.5             -- un point de spawn est occupé si un véhicule est à moins de N m
Config.MaxBoxes = 40                     -- limite haute du nombre de cartons par palette
Config.MaxPay = 1000000                  -- montant maximum réglable pour un paiement
