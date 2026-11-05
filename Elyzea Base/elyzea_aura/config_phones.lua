-- =========================================================
--  ELYZEA AURA - LES 6 TÉLÉPHONES (ElyAura 1 à 6)
--  Chaque modèle est un objet d'inventaire. Le téléphone utilisé est celui choisi
--  (« Utiliser » dans l'inventaire), sinon le meilleur que le joueur a sur lui.
--  Numéro, contacts, messages et photos suivent le personnage, pas l'appareil.
--  Applications : 'all' = toutes, sauf celles de « exclude ».
--  Personnalisation : niveau 1 (rien) à 6 (tout), voir html/js/devices.js.
--  Objet en main (prop) : modèles GTA faits pour l'animation téléphone (bien droits dans la main).
--  Réglage fin en jeu (staff « editor_props ») : /elyaura_main — enregistré pour tout le serveur.
-- =========================================================
Config.Phones = {
    -- Ancien objet « phone » : quel modèle il représente
    LegacyItems = { phone = 2 },

    -- Abonnements (elyzea_shop) qui donnent accès à l'ElyAura 6 : Royale (juste au-dessus de Sapphire) et au-delà
    Model6Perks = { 'vip_royale', 'vip_divinity' },

    -- Vendeur de téléphones (PNJ de l'éditeur de map : rôle « Vendeur de téléphones »)
    Shop = { account = 'cash', allowBank = true },

    Models = {
        [1] = {
            item = 'elyaura_1', label = 'ElyAura 1', price = 500, tier = 1,
            tagline = 'L\'essentiel : appels, messages, banque, papiers.',
            apps = { 'phone', 'messages', 'contacts', 'bank', 'identite', 'settings' },
            faceId = false, store = false,
            prop = { model = 'prop_npc_phone', bone = 28422, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
        },
        [2] = {
            item = 'elyaura_2', label = 'ElyAura 2', price = 2500, tier = 2,
            tagline = 'Toutes les applications du quotidien.',
            apps = 'all', exclude = { 'livrezy', 'helpmecano', 'lasergame', 'carplay', 'itoune', 'garage' },
            faceId = true, store = true,
            prop = { model = 'prop_npc_phone_02', bone = 28422, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
        },
        [3] = {
            item = 'elyaura_3', label = 'ElyAura 3', price = 6000, tier = 3,
            tagline = 'Livrézy et HelpMécano inclus, écran bord à bord.',
            apps = 'all', exclude = { 'lasergame', 'carplay', 'itoune', 'garage' },
            faceId = true, store = true,
            prop = { model = 'prop_phone_ing_02', bone = 28422, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
        },
        [4] = {
            item = 'elyaura_4', label = 'ElyAura 4', price = 12000, tier = 4,
            tagline = 'Itoune, effets animés, designs et coques à personnaliser.',
            apps = 'all', exclude = { 'carplay', 'garage' },
            faceId = true, store = true,
            prop = { model = 'prop_phone_ing', bone = 28422, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
        },
        [5] = {
            item = 'elyaura_5', label = 'ElyAura 5 Fold', price = 25000, tier = 5,
            tagline = 'Pliable : deux écrans, widgets, sonnerie personnalisée.',
            apps = 'all', exclude = { 'carplay', 'garage' },
            faceId = true, store = true, fold = true,
            prop = { model = 'prop_phone_ing_03', bone = 28422, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
            -- Déplié : tenu à deux mains (pose « lire une carte »), deux moitiés côte à côte
            unfolded = {
                dict = 'amb@world_human_tourist_map@male@base', clip = 'base',
                halves = {
                    { model = 'prop_phone_ing_03', bone = 28422, pos = vec3(0.02, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
                    { model = 'prop_phone_ing_03', bone = 28422, pos = vec3(-0.055, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
                },
            },
        },
        [6] = {
            item = 'elyaura_6', label = 'ElyAura 6 Ultra Fold', price = 60000, tier = 6,
            tagline = 'Réservé aux abonnés Royale : pliable, CarPlay, Garage, personnalisation totale.',
            apps = 'all', exclude = {},
            faceId = true, store = true, vip = true, fold = true,
            prop = { model = 'prop_phone_ing', bone = 28422, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
            -- Déplié : tenu à deux mains, comme l'ElyAura 5
            unfolded = {
                dict = 'amb@world_human_tourist_map@male@base', clip = 'base',
                halves = {
                    { model = 'prop_phone_ing', bone = 28422, pos = vec3(0.02, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
                    { model = 'prop_phone_ing', bone = 28422, pos = vec3(-0.055, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
                },
            },
        },
    },
}
