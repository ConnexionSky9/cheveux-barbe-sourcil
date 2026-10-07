Config = {}

-- La tenue achetée / portée est enregistrée dans l'apparence du personnage (ely_creator)
-- pour la garder après reconnexion. 'none' : rien (la tenue reste jusqu'à la reconnexion)
Config.Appearance = 'auto'

Config.Currency = '$'
Config.Payments = { 'cash', 'bank' }          -- moyens de paiement proposés dans le panier
Config.MaxDistance = 15.0                      -- distance max entre le joueur et le PNJ pour payer

-- Catégories : type = 'component' (vêtement) ou 'prop' (accessoire), index = n° GTA
-- price = prix de base (multiplié par le % de la boutique), cam = vue de la caméra
Config.Categories = {
    { id = 'tops',        label = 'Hauts',              icon = 'top',      type = 'component', index = 11, price = 120, cam = 'torso' },
    { id = 'undershirts', label = 'T-shirts',           icon = 'tshirt',   type = 'component', index = 8,  price = 60,  cam = 'torso' },
    { id = 'pants',       label = 'Pantalons',          icon = 'pants',    type = 'component', index = 4,  price = 90,  cam = 'legs' },
    { id = 'shoes',       label = 'Chaussures',         icon = 'shoe',     type = 'component', index = 6,  price = 80,  cam = 'feet' },
    { id = 'bags',        label = 'Sacs',               icon = 'bag',      type = 'component', index = 5,  price = 150, cam = 'back' },
    { id = 'vests',       label = 'Gilets',             icon = 'vest',     type = 'component', index = 9,  price = 110, cam = 'torso' },
    { id = 'arms',        label = 'Gants et bras',      icon = 'glove',    type = 'component', index = 3,  price = 40,  cam = 'torso' },
    { id = 'chains',      label = 'Colliers, cravates', icon = 'chain',    type = 'component', index = 7,  price = 70,  cam = 'torso' },
    { id = 'masks',       label = 'Masques',            icon = 'mask',     type = 'component', index = 1,  price = 100, cam = 'head' },
    { id = 'decals',      label = 'Logos',              icon = 'decal',    type = 'component', index = 10, price = 30,  cam = 'torso' },
    { id = 'hats',        label = 'Chapeaux',           icon = 'hat',      type = 'prop',      index = 0,  price = 60,  cam = 'head' },
    { id = 'glasses',     label = 'Lunettes',           icon = 'glasses',  type = 'prop',      index = 1,  price = 80,  cam = 'head' },
    { id = 'ears',        label = 'Boucles d\'oreilles',icon = 'earring',  type = 'prop',      index = 2,  price = 90,  cam = 'head' },
    { id = 'watches',     label = 'Montres',            icon = 'watch',    type = 'prop',      index = 6,  price = 200, cam = 'hand' },
    { id = 'bracelets',   label = 'Bracelets',          icon = 'bracelet', type = 'prop',      index = 7,  price = 70,  cam = 'hand' },
}

-- =========================================================
--  VÊTEMENTS EN OBJETS D'INVENTAIRE (elyzea_inventory)
--  Chaque vêtement acheté devient un objet qui garde son modèle et son coloris.
--  Le porter : « Utiliser » dans l'inventaire (ou le glisser sur le personnage avec
--  elyzea_inventory). Ce qu'on portait avant retourne dans l'inventaire.
-- =========================================================
Config.Items = {
    enabled = true,
    -- Poids : 10 grammes par vêtement. Le poids RÉELLEMENT utilisé est celui défini dans
    -- elyzea_inventory/shared/items.lua (CLOTHING_WEIGHT = 10). Cette valeur n'est qu'indicative.
    weight = 10,
    -- Nom de l'objet par rayon (déclarés dans elyzea_inventory/shared/items.lua)
    names = {
        tops = 'vet_haut', undershirts = 'vet_tshirt', pants = 'vet_pantalon', shoes = 'vet_chaussures',
        bags = 'vet_sac', vests = 'vet_gilet', arms = 'vet_gants', chains = 'vet_collier', masks = 'vet_masque',
        decals = 'vet_logo', hats = 'vet_chapeau', glasses = 'vet_lunettes', ears = 'vet_boucles',
        watches = 'vet_montre', bracelets = 'vet_bracelet',
    },
}

-- « Rien » pour chaque rayon : quand on retire un vêtement, le personnage repasse sur ce modèle,
-- et ce modèle n'est jamais rendu en objet (on ne range pas « torse nu » dans l'inventaire).
-- Accessoires (chapeaux, lunettes…) : -1 = aucun.
Config.Naked = {
    male = {
        tops = { 15, 0 }, undershirts = { 15, 0 }, pants = { 61, 0 }, shoes = { 34, 0 }, bags = { 0, 0 },
        vests = { 0, 0 }, arms = { 15, 0 }, chains = { 0, 0 }, masks = { 0, 0 }, decals = { 0, 0 },
        hats = { -1, 0 }, glasses = { -1, 0 }, ears = { -1, 0 }, watches = { -1, 0 }, bracelets = { -1, 0 },
    },
    female = {
        tops = { 15, 0 }, undershirts = { 14, 0 }, pants = { 15, 0 }, shoes = { 35, 0 }, bags = { 0, 0 },
        vests = { 0, 0 }, arms = { 15, 0 }, chains = { 0, 0 }, masks = { 0, 0 }, decals = { 0, 0 },
        hats = { -1, 0 }, glasses = { -1, 0 }, ears = { -1, 0 }, watches = { -1, 0 }, bracelets = { -1, 0 },
    },
}

-- Panneau « Ma tenue » : voir ce qu'on porte et ranger une pièce dans l'inventaire
Config.WardrobeCommand = 'tenue'
Config.WardrobeKey = 'F7'        -- touche par défaut ('' = aucune), modifiable par chaque joueur

-- Modèles cachés dans la boutique (vêtements de métier, tenues staff…), par sexe et catégorie
-- Exemple : male = { tops = { 55, 56 } }  -> les hauts n°55 et 56 ne sont pas vendus aux hommes
Config.Blacklist = {
    male = {},
    female = {},
}

-- =========================================================
--  IMAGES RÉELLES DES VÊTEMENTS (cartes, coloris, panier)
--  Une image par modèle ET par coloris :  html/images/<sexe>/<rayon>/<drawable>_<texture>.<ext>
--    html/images/male/tops/12_0.webp     haut homme n°12, coloris 1 (texture 0)
--    html/images/male/tops/12_1.webp     même haut, coloris 2 (texture 1)
--    html/images/female/pants/25_0.webp  pantalon femme n°25, coloris 1
--  Rayons : tops, undershirts, pants, shoes, bags, vests, arms, chains, masks, decals,
--           hats, glasses, ears, watches, bracelets
--  Image absente → coloris 0 du même modèle (si textureFallback) → icône générique.
-- =========================================================
Config.Images = {
    enabled = true,
    base = '',                 -- '' = html/images/ de cette ressource, ou une adresse https://monsite.fr/images/
    ext = 'webp',              -- extension principale
    fallbackExt = { 'png' },   -- extensions essayées ensuite si la principale n'existe pas ({} pour aucune)
    textureFallback = true,    -- coloris sans image : montrer l'image du coloris 0 du même modèle
    -- Nommage des fichiers. Jetons : {sex} male/female, {gender} m/f, {cat} rayon, {type} component/prop,
    -- {index} n° GTA du composant/accessoire, {d} drawable, {t} texture, {ext} extension
    pattern = '{sex}/{cat}/{d}_{t}.{ext}',
}

-- Commande de test réservée au staff (permission ACE). nil pour la désactiver.
Config.TestCommand = 'boutique_vetements'
Config.TestAce = 'elyzea.clothing.test'
