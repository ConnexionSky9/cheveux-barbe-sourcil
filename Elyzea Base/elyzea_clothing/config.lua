Config = {}

-- =====================================================================
--  ELYZEA CLOTHING · RÉGLAGES
--  Les rayons (hauts, pantalons…) sont dans shared/data.lua.
-- =====================================================================

Config.Currency = '$'
Config.Payments = { 'cash', 'bank' }   -- moyens de paiement proposés : 'cash' (liquide), 'bank' (banque)
Config.PesosItem = 'pesos'             -- boutique « pesos uniquement » (option du PNJ dans admin_menu) : objet payé
Config.PaymentBusiness = 'Vetements'    -- règle dollars / pesos dans elyzea_change (Config.Payment.Businesses)
Config.MaxDistance = 15.0               -- distance max entre le joueur et le vendeur pour payer
Config.MaxCart = 30                     -- articles au maximum dans un panier (plusieurs par rayon possibles)

-- La tenue achetée / portée est gardée dans l'apparence du personnage (ely_creator) : reste après reconnexion
Config.SaveOutfit = true

-- =====================================================================
--  PACKS DE VÊTEMENTS : DÉTECTION AUTOMATIQUE
--  Ajouter un pack = déposer son dossier dans  resources/[vetements]/  puis redémarrer.
--  Rien d'autre à faire : la boutique le trouve toute seule et l'affiche avec son nom.
--  (Une seule fois : la ligne  ensure [vetements]  dans server.cfg, AVANT elyzea_clothing.)
-- =====================================================================
Config.Packs = {
    showGTA = true,        -- vendre aussi les vêtements d'origine de GTA
    price = 100,           -- prix des vêtements de packs, en % du prix du rayon (150 = 50 % plus cher)

    -- Facultatif, pour un pack en particulier (nom du dossier du pack) :
    --   label  = nom affiché dans la boutique (sinon : nom du dossier, mis en forme)
    --   price  = % du prix du rayon pour ce pack
    --   hidden = true pour ne pas le vendre (tenues de métier, staff…)
    -- Exemple :
    --   ['eup_police'] = { hidden = true },
    --   ['ma_marque_luxe'] = { label = 'Maison Elyzea', price = 250 },
    list = {
        ['elyzea_staff_assets'] = { hidden = true },   -- tenues staff : pas vendues en boutique
    },
}

-- =====================================================================
--  VÊTEMENTS EN OBJETS D'INVENTAIRE (elyzea_inventory)
--  Chaque vêtement acheté devient un objet ; on le porte depuis l'inventaire.
-- =====================================================================
Config.Items = {
    enabled = true,
    -- Objet par rayon (déclarés dans elyzea_inventory/shared/items.lua, 10 g chacun)
    names = {
        tops = 'vet_haut', undershirts = 'vet_tshirt', pants = 'vet_pantalon', shoes = 'vet_chaussures',
        bags = 'vet_sac', vests = 'vet_gilet', arms = 'vet_gants', chains = 'vet_collier', masks = 'vet_masque',
        decals = 'vet_logo', hats = 'vet_chapeau', glasses = 'vet_lunettes', ears = 'vet_boucles',
        watches = 'vet_montre', bracelets = 'vet_bracelet',
    },
}

-- =====================================================================
--  CHAPEAU ET LUNETTES QUI TOMBENT
--  Comme de base dans GTA : un coup reçu (ou une chute) peut faire tomber le chapeau et les lunettes.
--  Ici, ce qui tombe devient le VRAI objet (vet_chapeau / vet_lunettes, même modèle et coloris) :
--  le propriétaire ou n'importe qui peut le ramasser (inventaire › « Au sol »).
--  ALT sur l'objet au sol : Ramasser (tout le monde) ou Casser les lunettes (« Lunettes cassées », impossibles à porter).
--  Ne marche qu'avec les vêtements en objets (Config.Items.enabled) ; jamais sur une tenue de service.
-- =====================================================================
Config.KnockOff = {
    enabled = true,
    window = 2500,      -- ms : la chute compte seulement si elle suit un coup reçu ou une chute (ragdoll)
    cooldown = 3000,    -- ms : pas deux chutes du même accessoire de suite
    -- Modèle affiché au sol (s'il n'existe pas dans le jeu : le sac de l'inventaire)
    props = { hats = 'prop_proxy_hat_01', glasses = 'prop_cs_sol_glasses' },
    altDistance = 2.0,  -- m : ALT sur le chapeau / les lunettes au sol (Ramasser, Casser les lunettes)
}

-- Panneau « Ma tenue » : voir ce qu'on porte, ranger une pièce, la renommer
Config.Wardrobe = { command = 'tenue', key = 'F3' }

-- =====================================================================
--  TENUES ENREGISTRÉES (onglet « Mes tenues » du panneau F3)
--  Une tenue = toutes les pièces des rayons (vêtements + accessoires, coloris, packs).
--  Gardées en base par personnage (citizenid) : tables elyzea_outfits / elyzea_outfit_categories.
--  Porter une tenue passe par l'inventaire : seules les pièces possédées sont mises,
--  ce qu'on portait à leur place revient en objet (rien n'est créé ni perdu).
-- =====================================================================
Config.Outfits = {
    enabled = true,
    max = 40,               -- tenues par personnage
    maxCategories = 12,     -- catégories personnelles par personnage (en plus de celles par défaut)
    nameMax = 32,           -- longueur max d'un nom
    -- Catégories par défaut (tous les personnages, non supprimables). La clé est enregistrée avec la tenue.
    categories = {
        { id = 'quotidien', label = 'Quotidien' },
        { id = 'travail',   label = 'Travail' },
        { id = 'soiree',    label = 'Soirée' },
        { id = 'sport',     label = 'Sport' },
        { id = 'ceremonie', label = 'Cérémonie' },
    },
}

-- Plus simple : en jeu, le staff (permission admin_menu « clothing_manage ») cache un vêtement depuis la boutique
-- avec « 🙈 Cacher pour tout le monde » (voir README). La liste ci-dessous reste possible pour les vêtements de GTA.
-- Vêtements de GTA cachés dans la boutique (n° du modèle), par sexe et par rayon
-- Exemple : male = { tops = { 55, 56 } }
Config.Blacklist = {
    male = {},
    female = {},
}

-- =====================================================================
--  IMAGES DES VÊTEMENTS (facultatif) : html/images/
--    Vêtement GTA  : <sexe>/<rayon>/<n°>_<coloris>.webp       ex. male/tops/12_0.webp
--    Vêtement pack : <sexe>/<rayon>/<pack>/<n°>_<coloris>.webp ex. male/tops/ma_marque/3_0.webp
--  Le studio photo (elyzea_clothing_photos) les crée tout seul. Sans image : icône du rayon.
-- =====================================================================
Config.Images = {
    enabled = true,
    base = '',               -- '' = html/images/ de cette ressource, ou une adresse https://monsite.fr/images/
    ext = 'webp',
    fallbackExt = { 'png' },
    textureFallback = true,  -- coloris sans image : image du coloris 1 du même modèle
}

-- Commande de test réservée au staff (permission ACE). nil pour la désactiver.
Config.TestCommand = 'boutique_vetements'
Config.TestAce = 'elyzea.clothing.test'

-- =====================================================================
--  SACS DE SHOPPING (server/bags.lua, client/bags.lua, html/bags.js)
--  Au paiement, le joueur choisit « avec un sac » ou « sans sac ».
--  Avec un sac : les vêtements achetés vont dans un ou plusieurs sacs (objets sac_shopping_<couleur>),
--  pas directement dans l'inventaire. Le CONTENU de chaque sac est gardé par le serveur
--  (table elyzea_shopping_bags) : l'objet n'est qu'une clé, impossible de dupliquer un vêtement.
--  Utiliser le sac (inventaire) : fenêtre pour récupérer les vêtements. ALT : ranger dans le coffre
--  du véhicule, le reprendre, l'offrir à quelqu'un (il accepte ou refuse).
-- =====================================================================
Config.Bags = {
    enabled     = true,
    perBag      = 6,            -- vêtements max par sac (au-delà : un sac de plus)
    maxBags     = 5,            -- sacs max par achat
    default     = 'auto',       -- couleur des boutiques sans couleur choisie : 'auto' (une couleur au hasard) ou une couleur ci-dessous
    giftDistance = 3.0,         -- distance max pour offrir un sac (mètres)
    giftTimeout  = 20,          -- secondes pour accepter un cadeau
    acceptKey    = 'Y',         -- accepter un cadeau (modifiable dans Paramètres GTA > Raccourcis > FiveM)
    refuseKey    = 'L',         -- refuser un cadeau
    -- Couleurs : objet d'inventaire, nom affiché, couleur de l'interface, modèle 3D tenu en main.
    -- Les modèles sont ceux du jeu (aucun sac de couleur n'existe dans GTA) : remplace « model » par
    -- ton propre sac streamé (ex. 'ely_bag_rose') pour avoir la vraie couleur en 3D.
    colors = {
        rose    = { item = 'sac_shopping_rose',   label = 'rose',        hex = '#ff5fa8', model = 'vw_prop_casino_shopping_bag_01a' },
        violet  = { item = 'sac_shopping_violet', label = 'violet',      hex = '#9b6bff', model = 'vw_prop_casino_shopping_bag_01a' },
        bleu    = { item = 'sac_shopping_bleu',   label = 'bleu',        hex = '#3d9bff', model = 'prop_cs_shopping_bag' },
        jaune   = { item = 'sac_shopping_jaune',  label = 'jaune',       hex = '#ffc93c', model = 'prop_cs_shopping_bag' },
        orange  = { item = 'sac_shopping_orange', label = 'orange',      hex = '#ff8a3d', model = 'prop_cs_shopping_bag' },
        multi   = { item = 'sac_shopping_multi',  label = 'multicolore', hex = '#ff5fa8', model = 'prop_shopping_bags02' },
    },
    order = { 'rose', 'violet', 'bleu', 'jaune', 'orange', 'multi' },
    -- Sacs tenus en main : main droite (1er sac), main gauche (2e sac). 3 sacs ou plus : un paquet de sacs à droite.
    hold = {
        right = { bone = 28422, pos = { 0.24, 0.03, -0.04 }, rot = { 0.0, -90.0, 10.0 } },
        left  = { bone = 60309, pos = { 0.20, -0.03, 0.04 }, rot = { 0.0, -90.0, -170.0 } },
        bunch = { model = 'prop_shopping_bags02', bone = 28422, pos = { 0.05, 0.02, 0.0 }, rot = { 178.8, 91.19, 9.97 } },
        anim  = { dict = 'move_weapon@jerrycan@generic', name = 'idle' },   -- bras tendu, sac à la main (on peut marcher)
    },
}
