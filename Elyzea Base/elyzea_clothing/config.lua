Config = {}

-- =====================================================================
--  ELYZEA CLOTHING · RÉGLAGES
--  Les rayons (hauts, pantalons…) sont dans shared/data.lua.
-- =====================================================================

Config.Currency = '$'
Config.Payments = { 'cash', 'bank' }   -- moyens de paiement proposés : 'cash' (liquide), 'bank' (banque)
Config.MaxDistance = 15.0               -- distance max entre le joueur et le vendeur pour payer

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

-- Panneau « Ma tenue » : voir ce qu'on porte, ranger une pièce, la renommer
Config.Wardrobe = { command = 'tenue', key = 'F3' }

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
