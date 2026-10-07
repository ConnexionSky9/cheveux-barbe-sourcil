Config = {}

-- =====================================================================
--  VALEURS DE DÉPART
--  Utilisées UNIQUEMENT au premier démarrage. Ensuite tout se règle en
--  jeu dans la tablette staff Police (/police_staff) et est sauvegardé
--  en base de données.
-- =====================================================================

-- Touches par défaut (chaque joueur peut les changer : Paramètres > Raccourcis > FiveM)
Config.Keys = {
    tablet   = 'F6',   -- tablette de l'agent
    actions  = 'F7',   -- menu d'interaction (menottes, escorte, fouille…)
    accept   = 'G',    -- accepter l'appel (même touche que les EMS)
    ignore   = 'I',    -- ignorer l'appel (même touche que les EMS)
    panic    = '',     -- bouton panique (à assigner)
}

-- Commandes pour les citoyens
Config.Commands = {
    call  = '112',      -- /112 <message> : appeler la police
    fines = 'amendes',  -- /amendes : voir et payer ses amendes
}

Config.Defaults = {
    -- Métiers considérés comme police (reçoivent le dispatch, ouvrent la tablette)
    policeJobs = { 'police' },

    -- Métier géré par la tablette staff (créé / mis à jour dans elyzea_core)
    job = {
        name = 'police', label = 'LSPD', type = 'leo', defaultDuty = false, offDutyPay = false,
        grades = {
            { name = 'Cadet',          payment = 50 },
            { name = 'Officier',       payment = 75 },
            { name = 'Sergent',        payment = 100 },
            { name = 'Lieutenant',     payment = 125 },
            { name = 'Capitaine',      payment = 150, isboss = true },
        },
    },

    -- Grade minimum (niveau) pour chaque action
    permGrades = {
        mdt = 0,             -- ouvrir la tablette
        dispatch = 0,        -- accepter les appels
        cuff = 0,            -- menotter, escorter, véhicule
        search = 0,          -- fouiller
        fines = 0,           -- mettre une amende
        records_write = 0,   -- écrire un rapport
        jail = 1,            -- envoyer en prison / libérer
        warrants = 1,        -- avis de recherche
        licenses = 2,        -- donner / retirer des permis
        records_delete = 3,  -- supprimer un rapport
        roster = 4,          -- recruter, promouvoir, renvoyer
    },

    -- Catalogue des amendes
    fines = {
        { id = 'speed',    label = 'Excès de vitesse',             amount = 250,  jail = 0,  category = 'Route' },
        { id = 'redlight', label = 'Feu rouge grillé',             amount = 150,  jail = 0,  category = 'Route' },
        { id = 'reckless', label = 'Conduite dangereuse',          amount = 750,  jail = 0,  category = 'Route' },
        { id = 'nolicense',label = 'Conduite sans permis',         amount = 1000, jail = 0,  category = 'Route' },
        { id = 'insult',   label = 'Outrage à agent',              amount = 500,  jail = 5,  category = 'Personnes' },
        { id = 'assault',  label = 'Agression',                    amount = 1500, jail = 15, category = 'Personnes' },
        { id = 'theft',    label = 'Vol',                          amount = 1000, jail = 10, category = 'Biens' },
        { id = 'carjack',  label = 'Vol de véhicule',              amount = 2500, jail = 20, category = 'Biens' },
        { id = 'weapon',   label = 'Port d\'arme illégal',         amount = 3000, jail = 20, category = 'Armes' },
        { id = 'drugs',    label = 'Possession de stupéfiants',    amount = 2000, jail = 15, category = 'Stupéfiants' },
        { id = 'evade',    label = 'Délit de fuite',               amount = 2000, jail = 15, category = 'Route' },
    },

    -- Armurerie (elyzea_inventory)
    armory = {
        { item = 'WEAPON_STUNGUN',     price = 0,   grade = 0 },
        { item = 'WEAPON_NIGHTSTICK',  price = 0,   grade = 0 },
        { item = 'WEAPON_FLASHLIGHT',  price = 0,   grade = 0 },
        { item = 'WEAPON_COMBATPISTOL',price = 0,   grade = 1 },
        { item = 'ammo-9',             price = 0,   grade = 1 },
        { item = 'WEAPON_CARBINERIFLE',price = 0,   grade = 3 },
        { item = 'ammo-rifle',         price = 0,   grade = 3 },
        { item = 'armour',             price = 0,   grade = 0 },
        { item = 'radio',              price = 0,   grade = 0 },
    },

    -- Points sur la carte : posés en jeu depuis la tablette staff
    points = {
        duty   = { { label = 'Mission Row - Accueil', x = 441.1, y = -981.9, z = 30.69 } },
        armory = { { label = 'Mission Row - Armurerie', x = 482.6, y = -995.3, z = 30.69 } },
        jail   = { { label = 'Bolingbroke - Cour', x = 1691.6, y = 2565.6, z = 45.56 } },
        release= { { label = 'Bolingbroke - Sortie', x = 1847.2, y = 2585.8, z = 45.67 } },
    },

    settings = {
        alertTimeout   = 60,     -- secondes d'affichage d'un appel
        blipSprite     = 161,
        blipColor      = 3,
        colleagueBlips = true,   -- les agents en service se voient sur la carte
        shotsAlert     = true,   -- alerte automatique « coups de feu »
        shotsCooldown  = 60,     -- secondes entre deux alertes d'un même tireur
        searchNeedsCuff= true,   -- fouille seulement si menotté (ou mains en l'air)
        maxJail        = 120,    -- minutes de prison max
        jailRadius     = 120.0,  -- au-delà, le prisonnier est ramené
        maxFine        = 50000,  -- amende max
        fineToSociety  = true,   -- l'argent des amendes va au compte du métier (compte d'entreprise elyzea_core)
        callCooldown   = 30,     -- secondes entre deux /112 d'un citoyen
    },
}
