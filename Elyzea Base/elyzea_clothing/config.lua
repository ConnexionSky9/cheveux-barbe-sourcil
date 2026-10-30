Config = {}

-- =====================================================================
--  ELYZEA CLOTHING · RÉGLAGES
--  Les rayons (hauts, pantalons…) sont dans shared/data.lua.
-- =====================================================================

Config.Currency = '$'
Config.Payments = { 'cash', 'bank' }   -- moyens de paiement proposés : 'cash' (liquide), 'bank' (banque)
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
--  CHAPEAU ET LUNETTES QUI TOMBENT (pousser, coup de poing, arme de mêlée)
--  Ils tombent au sol en VRAIS objets (vet_chapeau / vet_lunettes, même modèle et coloris) :
--  le propriétaire ou n'importe qui peut les ramasser (inventaire › « Au sol »).
--  Lunettes au sol : G à côté pour les écraser (elles deviennent « Lunettes cassées », impossibles à porter).
--  Ne marche qu'avec les vêtements en objets (Config.Items.enabled) ; jamais sur une tenue de service.
-- =====================================================================
Config.KnockOff = {
    enabled = true,
    push = { hats = 70, glasses = 60 },   -- % de chance de tomber quand on est poussé (ALT › Pousser)
    hit  = { hats = 35, glasses = 30 },   -- % de chance par coup de poing / arme de mêlée reçu d'un joueur
    victimCooldown = 4000,                -- ms : pas deux chutes de suite pour la même personne
    pushDistance = 1.8,                   -- m : distance max pour pousser
    pushCooldown = 6000,                  -- ms entre deux poussées du même joueur
    -- Modèle affiché au sol (s'il n'existe pas dans le jeu : le sac de l'inventaire)
    props = { hats = 'prop_proxy_hat_01', glasses = 'prop_cs_sol_glasses' },
    breakKey = 47,                        -- G : écraser des lunettes tombées au sol
    breakDistance = 1.6,
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
