Config = {}

-- =====================================================================
--  ENTREPRISES ELYZEA : Taxi, Burger Shot, Boîte de nuit
--  Les valeurs ci-dessous sont celles de DÉPART. Tout se règle ensuite en
--  jeu, sans redémarrage : admin_menu › Métiers › (nom de l'entreprise) :
--  grades, salaires, permissions, zones, carte et prix, recettes,
--  fournisseur, véhicules, compteur du taxi, courses, entrée, tenues.
-- =====================================================================

-- Tablette des employés (modifiable par chaque joueur : Paramètres › Raccourcis › FiveM)
Config.TabletKey = 'F6'

-- Types de zones (posées par le staff à sa position)
Config.ZoneTypes = {
    { key = 'service',     label = 'Prise de service',          color = { 79, 179, 169 } },
    { key = 'stash',       label = 'Coffre',                    color = { 217, 181, 106 } },
    { key = 'cuisine',     label = 'Préparation (cuisine / bar)', color = { 224, 140, 59 } },
    { key = 'fournisseur', label = 'Réserve (fournisseur)',     color = { 140, 120, 220 } },
    { key = 'comptoir',    label = 'Comptoir / caisse',         color = { 59, 111, 224 } },
    { key = 'entree',      label = 'Entrée (boîte de nuit)',    color = { 224, 67, 59 } },
    { key = 'garage',      label = 'Garage de service',         color = { 59, 111, 224 } },
    { key = 'spawn',       label = 'Sortie des véhicules',      color = { 59, 111, 224 } },
    { key = 'parking',     label = 'Rangement des véhicules',   color = { 120, 140, 170 } },
}

-- Permissions possibles (cochées par grade dans le menu admin)
Config.Permissions = {
    { key = 'invoice',    label = 'Facturer un client' },
    { key = 'prepare',    label = 'Préparer (cuisine / bar)',              feature = 'production' },
    { key = 'stock',      label = 'Commander au fournisseur (compte de l\'entreprise)', feature = 'production' },
    { key = 'stash',      label = 'Ouvrir le coffre' },
    { key = 'garage',     label = 'Sortir un véhicule de service' },
    { key = 'meter',      label = 'Utiliser le compteur',                  feature = 'meter' },
    { key = 'missions',   label = 'Faire des courses (clients PNJ)',       feature = 'missions' },
    { key = 'entry',      label = 'Faire payer l\'entrée',                  feature = 'entry' },
    { key = 'boss_staff', label = 'Gérer les employés (recruter, grades, renvoyer)' },
    { key = 'boss_money', label = 'Gérer l\'argent de l\'entreprise (déposer, retirer)' },
}

-- Courses des taxis : points de départ et d'arrivée des clients PNJ (réglables dans le menu admin)
local TAXI_POINTS = {
    { x = 293.5, y = -590.2, z = 43.1 }, { x = -1037.7, y = -2737.9, z = 20.2 }, { x = -556.1, y = -191.4, z = 38.2 },
    { x = 128.3, y = -1029.1, z = 29.3 }, { x = -1388.5, y = -586.5, z = 30.2 }, { x = 1153.6, y = -326.8, z = 69.2 },
    { x = -261.7, y = -973.5, z = 31.2 }, { x = 389.1, y = -987.4, z = 29.4 }, { x = -712.6, y = -824.6, z = 23.5 },
    { x = 230.1, y = -785.1, z = 30.7 }, { x = -1196.7, y = -887.3, z = 13.8 }, { x = 818.9, y = -1290.3, z = 26.3 },
    { x = -1606.4, y = -1015.2, z = 13.0 }, { x = 41.3, y = -1739.6, z = 29.3 }, { x = -1284.9, y = 296.6, z = 64.9 },
}

local function grades(list)
    local out = {}
    for _, g in ipairs(list) do out[#out + 1] = { id = g[1], label = g[2], payment = g[3], isboss = g[4] == true } end
    return out
end
local function perms(list)   -- { [grade] = 'invoice prepare …' }
    local out = {}
    for grade, keys in pairs(list) do
        out[tostring(grade)] = {}
        for k in keys:gmatch('%S+') do out[tostring(grade)][k] = true end
    end
    return out
end

-- =====================================================================
--  LES ENTREPRISES
--  features : meter (compteur), missions (courses PNJ), production
--  (recettes + fournisseur), entry (entrée payante)
-- =====================================================================
Config.Companies = {
    -- ─────────────────────────── TAXI ───────────────────────────
    taxi = {
        icon = '🚕', color = '#e8b53a',
        features = { meter = true, missions = true },
        defaults = {
            enabled = true,
            job = { name = 'taxi', label = 'Downtown Cab Co.', type = 'taxi', defaultDuty = false, offDutyPay = false,
                grades = grades({ { 'apprenti', 'Apprenti chauffeur', 40 }, { 'chauffeur', 'Chauffeur', 60 }, { 'confirme', 'Chauffeur confirmé', 80 },
                    { 'responsable', 'Responsable', 110 }, { 'patron', 'Patron', 150, true } }) },
            perms = perms({ [0] = 'invoice meter missions garage', [1] = 'invoice meter missions garage stash', [2] = 'invoice meter missions garage stash',
                [3] = 'invoice meter missions garage stash boss_staff', [4] = 'invoice meter missions garage stash boss_staff boss_money' }),
            -- Zones de départ (Downtown Cab Co., positions approximatives : à ajuster dans le menu admin)
            zones = {
                { type = 'service', label = 'Accueil', x = 895.4, y = -179.2, z = 74.7, h = 240.0, radius = 1.5 },
                { type = 'garage',  label = 'Garage des taxis', x = 903.1, y = -173.4, z = 74.1, h = 240.0, radius = 1.5 },
                { type = 'spawn',   label = 'Sortie des taxis', x = 911.5, y = -164.6, z = 74.3, h = 196.0, radius = 3.0 },
                { type = 'parking', label = 'Rangement', x = 917.9, y = -170.8, z = 74.4, h = 196.0, radius = 5.0 },
                { type = 'stash',   label = 'Coffre', x = 893.0, y = -183.0, z = 74.7, h = 240.0, radius = 1.5 },
            },
            menu = {},
            recipes = {}, supplies = {},
            settings = {
                commission = 30, invoiceTimeout = 60, maxInvoice = 20000, showBlips = true, blipSprite = 198, blipColor = 5,
                serviceVehicles = { { model = 'taxi', label = 'Taxi', grade = 0 } }, maxServiceVehicles = 1,
                meterBase = 30, meterPerKm = 40, meterPerMin = 5,          -- compteur : prise en charge, prix au km, prix par minute d'attente
                missionsEnabled = true, missionPayMin = 120, missionPayMax = 450, missionDriverShare = 60,   -- courses PNJ : paie, part du chauffeur (%)
                missionPoints = TAXI_POINTS,
            },
        },
    },

    -- ─────────────────────────── BURGER SHOT ───────────────────────────
    burgershot = {
        icon = '🍔', color = '#e0433b',
        features = { production = true },
        defaults = {
            enabled = true,
            job = { name = 'burgershot', label = 'Burger Shot', type = 'restaurant', defaultDuty = false, offDutyPay = false,
                grades = grades({ { 'equipier', 'Équipier', 40 }, { 'cuisinier', 'Cuisinier', 60 }, { 'chef', 'Chef de cuisine', 85 },
                    { 'manager', 'Manager', 110 }, { 'patron', 'Patron', 150, true } }) },
            perms = perms({ [0] = 'invoice prepare', [1] = 'invoice prepare stash', [2] = 'invoice prepare stash stock garage',
                [3] = 'invoice prepare stash stock garage boss_staff', [4] = 'invoice prepare stash stock garage boss_staff boss_money' }),
            -- Burger Shot de Del Perro (positions approximatives : à ajuster dans le menu admin)
            zones = {
                { type = 'service',     label = 'Vestiaire du personnel', x = -1178.0, y = -896.0, z = 13.9, h = 300.0, radius = 1.5 },
                { type = 'cuisine',     label = 'Cuisine', x = -1200.9, y = -897.6, z = 14.0, h = 34.0, radius = 2.0 },
                { type = 'fournisseur', label = 'Réserve', x = -1203.9, y = -894.9, z = 14.0, h = 34.0, radius = 1.5 },
                { type = 'comptoir',    label = 'Caisse', x = -1195.3, y = -892.2, z = 14.0, h = 124.0, radius = 1.5 },
                { type = 'stash',       label = 'Frigo', x = -1198.2, y = -901.1, z = 14.0, h = 34.0, radius = 1.5 },
            },
            -- Carte : prix de vente proposés à la caisse (facture)
            menu = {
                { label = 'The Bleeder', price = 60 }, { label = 'Heart Stopper', price = 90 }, { label = 'Frites', price = 25 },
                { label = 'Soda', price = 20 }, { label = 'Milkshake', price = 35 }, { label = 'Menu The Bleeder (burger + frites + soda)', price = 95 },
            },
            -- Recettes : ingrédients -> produit, au poste de préparation
            recipes = {
                { id = 'bleeder', label = 'The Bleeder', item = 'bs_bleeder', amount = 1, time = 6, ingredients = { { item = 'bs_pain', count = 1 }, { item = 'bs_viande', count = 1 }, { item = 'bs_legumes', count = 1 } } },
                { id = 'heartstopper', label = 'Heart Stopper', item = 'bs_heartstopper', amount = 1, time = 8, ingredients = { { item = 'bs_pain', count = 1 }, { item = 'bs_viande', count = 2 }, { item = 'bs_fromage', count = 1 } } },
                { id = 'frites', label = 'Frites', item = 'bs_frites', amount = 2, time = 5, ingredients = { { item = 'bs_patates', count = 1 } } },
                { id = 'soda', label = 'Soda', item = 'bs_soda', amount = 2, time = 3, ingredients = { { item = 'bs_sirop', count = 1 } } },
                { id = 'milkshake', label = 'Milkshake', item = 'bs_milkshake', amount = 1, time = 5, ingredients = { { item = 'bs_lait', count = 1 }, { item = 'bs_sirop', count = 1 } } },
            },
            -- Fournisseur : ingrédients achetés avec l'argent de l'entreprise
            supplies = {
                { item = 'bs_pain', price = 4 }, { item = 'bs_viande', price = 10 }, { item = 'bs_legumes', price = 3 }, { item = 'bs_fromage', price = 5 },
                { item = 'bs_patates', price = 3 }, { item = 'bs_sirop', price = 3 }, { item = 'bs_lait', price = 4 },
            },
            settings = {
                commission = 20, invoiceTimeout = 60, maxInvoice = 10000, showBlips = true, blipSprite = 106, blipColor = 1,
                serviceVehicles = { { model = 'stalion2', label = 'Voiture de livraison', grade = 2 } }, maxServiceVehicles = 1,
            },
        },
    },

    -- ─────────────────────────── BOÎTE DE NUIT ───────────────────────────
    nightclub = {
        icon = '🍸', color = '#a35bd8',
        features = { production = true, entry = true },
        defaults = {
            enabled = true,
            job = { name = 'nightclub', label = 'Bahama Mamas', type = 'nightclub', defaultDuty = false, offDutyPay = false,
                grades = grades({ { 'serveur', 'Serveur', 40 }, { 'barman', 'Barman', 60 }, { 'videur', 'Videur', 60 },
                    { 'gerant', 'Gérant', 110 }, { 'patron', 'Patron', 150, true } }) },
            perms = perms({ [0] = 'invoice prepare', [1] = 'invoice prepare stash', [2] = 'invoice entry',
                [3] = 'invoice prepare stash stock entry garage boss_staff', [4] = 'invoice prepare stash stock entry garage boss_staff boss_money' }),
            -- Bahama Mamas (positions approximatives : à ajuster dans le menu admin)
            zones = {
                { type = 'service',     label = 'Loge du personnel', x = -1376.8, y = -628.3, z = 30.8, h = 120.0, radius = 1.5 },
                { type = 'cuisine',     label = 'Bar', x = -1391.4, y = -604.3, z = 30.3, h = 120.0, radius = 2.0 },
                { type = 'fournisseur', label = 'Réserve', x = -1381.2, y = -632.0, z = 30.8, h = 120.0, radius = 1.5 },
                { type = 'comptoir',    label = 'Comptoir du bar', x = -1393.4, y = -606.7, z = 30.3, h = 300.0, radius = 1.5 },
                { type = 'entree',      label = 'Entrée', x = -1388.5, y = -586.5, z = 30.2, h = 30.0, radius = 2.5 },
                { type = 'stash',       label = 'Coffre', x = -1371.6, y = -625.9, z = 30.8, h = 120.0, radius = 1.5 },
            },
            menu = {
                { label = 'Entrée', price = 50 }, { label = 'Entrée VIP', price = 200 }, { label = 'Mojito', price = 40 },
                { label = 'Whisky-coca', price = 45 }, { label = 'Vodka énergie', price = 40 }, { label = 'Shot', price = 20 },
                { label = 'Coupe de champagne', price = 60 }, { label = 'Bouteille VIP', price = 600 },
            },
            recipes = {
                { id = 'mojito', label = 'Mojito', item = 'nc_mojito', amount = 1, time = 6, ingredients = { { item = 'nc_rhum', count = 1 }, { item = 'nc_citron', count = 1 }, { item = 'nc_glace', count = 1 } } },
                { id = 'whiskycoca', label = 'Whisky-coca', item = 'nc_whiskycoca', amount = 1, time = 4, ingredients = { { item = 'nc_whisky', count = 1 }, { item = 'nc_soda', count = 1 }, { item = 'nc_glace', count = 1 } } },
                { id = 'vodkaenergy', label = 'Vodka énergie', item = 'nc_vodkaenergy', amount = 1, time = 4, ingredients = { { item = 'nc_vodka', count = 1 }, { item = 'nc_energy', count = 1 } } },
                { id = 'shot', label = 'Shots (x3)', item = 'nc_shot', amount = 3, time = 3, ingredients = { { item = 'nc_vodka', count = 1 } } },
                { id = 'champagne', label = 'Coupes de champagne (x6)', item = 'nc_coupe', amount = 6, time = 5, ingredients = { { item = 'nc_champagne', count = 1 } } },
            },
            supplies = {
                { item = 'nc_rhum', price = 12 }, { item = 'nc_whisky', price = 15 }, { item = 'nc_vodka', price = 12 }, { item = 'nc_champagne', price = 60 },
                { item = 'nc_citron', price = 2 }, { item = 'nc_glace', price = 1 }, { item = 'nc_soda', price = 2 }, { item = 'nc_energy', price = 3 },
            },
            settings = {
                commission = 20, invoiceTimeout = 60, maxInvoice = 20000, showBlips = true, blipSprite = 121, blipColor = 27,
                serviceVehicles = {}, maxServiceVehicles = 1,
                entryPrice = 50, vipPrice = 200,          -- prix de l'entrée (facture rapide du videur)
            },
        },
    },
}
