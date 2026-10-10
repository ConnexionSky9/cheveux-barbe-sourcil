-- =====================================================================
--  ELYZEA CLOTHING · RAYONS
--  type = 'component' (vêtement) ou 'prop' (accessoire), index = n° GTA
--  price = prix de base (× % de la boutique), cam = vue de la caméra
-- =====================================================================
Config.Categories = {
    { id = 'tops',        label = 'Hauts',               single = 'Haut',               icon = 'top',      type = 'component', index = 11, price = 120, cam = 'torso' },
    { id = 'undershirts', label = 'T-shirts',            single = 'T-shirt',            icon = 'tshirt',   type = 'component', index = 8,  price = 60,  cam = 'torso' },
    { id = 'pants',       label = 'Pantalons',           single = 'Pantalon',           icon = 'pants',    type = 'component', index = 4,  price = 90,  cam = 'legs' },
    { id = 'shoes',       label = 'Chaussures',          single = 'Chaussures',         icon = 'shoe',     type = 'component', index = 6,  price = 80,  cam = 'feet' },
    { id = 'bags',        label = 'Sacs',                single = 'Sac',                icon = 'bag',      type = 'component', index = 5,  price = 150, cam = 'back' },
    { id = 'vests',       label = 'Gilets',              single = 'Gilet',              icon = 'vest',     type = 'component', index = 9,  price = 110, cam = 'torso' },
    { id = 'arms',        label = 'Gants et bras',       single = 'Gants',              icon = 'glove',    type = 'component', index = 3,  price = 40,  cam = 'torso' },
    { id = 'chains',      label = 'Colliers, cravates',  single = 'Collier',            icon = 'chain',    type = 'component', index = 7,  price = 70,  cam = 'torso' },
    { id = 'masks',       label = 'Masques',             single = 'Masque',             icon = 'mask',     type = 'component', index = 1,  price = 100, cam = 'head' },
    { id = 'decals',      label = 'Logos',               single = 'Logo',               icon = 'decal',    type = 'component', index = 10, price = 30,  cam = 'torso' },
    { id = 'hats',        label = 'Chapeaux',            single = 'Chapeau',            icon = 'hat',      type = 'prop',      index = 0,  price = 60,  cam = 'head' },
    { id = 'glasses',     label = 'Lunettes',            single = 'Lunettes',           icon = 'glasses',  type = 'prop',      index = 1,  price = 80,  cam = 'head' },
    { id = 'ears',        label = 'Boucles d\'oreilles', single = 'Boucles d\'oreilles', icon = 'earring', type = 'prop',      index = 2,  price = 90,  cam = 'head' },
    { id = 'watches',     label = 'Montres',             single = 'Montre',             icon = 'watch',    type = 'prop',      index = 6,  price = 200, cam = 'hand' },
    { id = 'bracelets',   label = 'Bracelets',           single = 'Bracelet',           icon = 'bracelet', type = 'prop',      index = 7,  price = 70,  cam = 'hand' },
}

-- « Rien » de chaque rayon : retirer un vêtement remet ce modèle, qui n'est jamais rangé en objet.
-- Accessoires : -1 = aucun.
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

-- Accès rapide par identifiant
Cat = {}
for _, c in ipairs(Config.Categories) do Cat[c.id] = c end

-- Nom d'un vêtement : « Haut n°12 » (GTA) ou « Haut Ma marque n°3 » (pack)
function ClothingLabel(catId, p, packLabel)
    local c = Cat[catId]
    local single = c and c.single or catId
    p = type(p) == 'table' and p or {}
    if packLabel and p.li then return ('%s %s n°%d'):format(single, packLabel, math.floor(p.li)) end
    return ('%s n°%d'):format(single, math.floor(tonumber(p.drawable) or 0))
end
