-- Définitions des objets. Le SERVEUR est la seule source de vérité.
-- weight : GRAMMES par unité · stack : empilable · max : taille de pile
-- image : fichier dans html/img · clothing : rayon elyzea_clothing
-- bonus : grammes de capacité ajoutés quand l'objet est porté (sac)
-- buttons : actions du clic droit { label, export = 'ressource.fonction', close = true }
-- client = { status = { hunger = 200000 } (1 000 000 = 100 %), anim, prop, usetime, notification, export = 'ressource.fonction' }
-- server = { export = 'ressource.fonction' }
--
-- Les objets de data/items.lua et les armes / munitions de data/weapons.lua sont ajoutés
-- automatiquement (voir shared/import.lua). Ceux définis ICI sont prioritaires.

local function food(label, weight, hunger, thirst, opts)
    opts = opts or {}
    local drink = (thirst or 0) > (hunger or 0)
    return {
        label = label, weight = weight, stack = true, max = 20, icon = drink and '🥤' or '🍔', description = opts.description,
        client = {
            status = { hunger = (hunger or 0) * 10000, thirst = (thirst or 0) * 10000 },
            anim = drink and { dict = 'mp_player_intdrink', clip = 'loop_bottle' } or { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger_fp' },
            prop = opts.prop or (drink and { model = `prop_ld_flow_bottle`, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) }
                or { model = `prop_cs_burger_01`, pos = vec3(0.02, 0.02, -0.02), rot = vec3(0.0, 0.0, 0.0) }),
            usetime = opts.usetime or 2500,
            notification = opts.notification,
        },
    }
end

Items = {
    phone   = { label = 'Téléphone', weight = 200, icon = '📱', stack = false, description = 'Smartphone personnel.' },
    burger  = food('Burger', 220, 20, 0, { notification = 'Vous avez mangé un burger.' }),
    water   = food('Bouteille d\'eau', 500, 0, 25, { notification = 'Vous avez bu de l\'eau.' }),
    water_bottle = food('Bouteille d\'eau', 500, 0, 25),
    cola    = food('eCola', 350, 0, 20, { prop = { model = `prop_ecola_can`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) } }),
    kurkakola = food('Kurkakola', 350, 0, 20, { prop = { model = `prop_ecola_can`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) } }),
    bread   = food('Pain', 150, 15, 0),
    chips   = food('Chips', 100, 8, 0),
    donut   = food('Donut', 120, 10, 0),
    pizza   = food('Part de pizza', 250, 25, 0),
    tosti   = food('Croque-monsieur', 200, 18, 0),
    twerks_candy = food('Barre Twerks', 60, 6, 0),
    snikkel_candy = food('Barre Snikkel', 60, 6, 0),

    carte_identite = { label = 'Carte d\'identité', weight = 10, stack = false, image = 'carte_identite.png', icon = '🪪', close = true,
        description = 'Pièce d\'identité. Utilise-la pour la regarder ou la montrer.',
        client = { export = 'elyzea_papiers.useDocument' } },
    ppa = { label = 'PPA · Civil', weight = 10, stack = false, image = 'ppa.png', icon = '🪪', close = true,
        description = 'Permis de port d\'arme civil (pistolet), délivré par les EMS après le test. Utilise-le pour le regarder ou le montrer.',
        client = { export = 'elyzea_papiers.useDocument' } },
    ppa_fdo = { label = 'PPA · Forces de l\'ordre', weight = 10, stack = false, image = 'ppa_fdo.png', icon = '🪪', close = true,
        description = 'Permis de port d\'arme des forces de l\'ordre (arme légère, arme lourde). Utilise-le pour le regarder ou le montrer.',
        client = { export = 'elyzea_papiers.useDocument' } },
    concess_key = { label = 'Clé de véhicule', weight = 50, stack = false, icon = '🔑',
        description = 'Clé d\'un véhicule acheté en concession. U près du véhicule pour l\'ouvrir ou le fermer.' },
    permis = { label = 'Permis de conduire', weight = 10, stack = false, image = 'permis.png', icon = '🪪',
        description = 'Permis de conduire Elyzea. Utilise-le pour le regarder ou le montrer.',
        client = { export = 'elyzea_permis.useLicense' } },

    -- Soins (elyzea_ems)
    bandage       = { label = 'Bandage', weight = 100, stack = true, max = 20, icon = '🩹', description = 'Soigne légèrement.' },
    gauze         = { label = 'Compresse', weight = 100, stack = true, max = 20, icon = '🩹' },
    painkiller    = { label = 'Antidouleur', weight = 100, stack = true, max = 20, icon = '💊' },
    medical_kit   = { label = 'Medical Kit', weight = 1000, stack = true, max = 5, icon = '🧰' },
    defibrillator = { label = 'Défibrillateur', weight = 3000, stack = true, max = 2, icon = '⚡' },
    morphine      = { label = 'Morphine', weight = 100, stack = true, max = 10, icon = '💉' },
    blood_bag     = { label = 'Poche de sang', weight = 500, stack = true, max = 10, icon = '🩸' },
    splint        = { label = 'Attelle', weight = 300, stack = true, max = 10, icon = '🦴' },

    -- Récoltes et ateliers (admin_menu)
    weed_leaf        = { label = 'Feuille de weed', weight = 20, stack = true, max = 500 },
    coca_leaf        = { label = 'Feuille de coca', weight = 20, stack = true, max = 500 },
    magic_mushroom   = { label = 'Champignon', weight = 20, stack = true, max = 500 },
    meth_chemicals   = { label = 'Produits chimiques', weight = 250, stack = true, max = 100 },
    weed_pouch       = { label = 'Pochon de weed', weight = 50, stack = true, max = 200 },
    cocaine          = { label = 'Cocaïne', weight = 50, stack = true, max = 200 },
    dried_mushroom   = { label = 'Champignons séchés', weight = 30, stack = true, max = 200 },
    metal_scrap      = { label = 'Ferraille', weight = 200, stack = true, max = 500 },
    gun_parts_light  = { label = 'Pièces d\'armes légères', weight = 300, stack = true, max = 100 },
    gun_parts_medium = { label = 'Pièces d\'armes moyennes', weight = 500, stack = true, max = 100 },
    gun_parts_heavy  = { label = 'Pièces d\'armes lourdes', weight = 800, stack = true, max = 100 },
    crowbar          = { label = 'Pied-de-biche', weight = 1500, stack = false },
}

-- ───────── Vêtements elyzea_clothing : 10 GRAMMES chacun ─────────
local CLOTHING_WEIGHT = 10
local clothes = {
    { 'vet_haut',       'Haut',               'tops' },
    { 'vet_tshirt',     'T-shirt',            'undershirts' },
    { 'vet_pantalon',   'Pantalon',           'pants' },
    { 'vet_chaussures', 'Chaussures',         'shoes' },
    { 'vet_sac',        'Sac',                'bags' },
    { 'vet_gilet',      'Gilet',              'vests' },
    { 'vet_gants',      'Gants',              'arms' },
    { 'vet_collier',    'Collier / cravate',  'chains' },
    { 'vet_masque',     'Masque',             'masks' },
    { 'vet_logo',       'Logo',               'decals' },
    { 'vet_chapeau',    'Chapeau',            'hats' },
    { 'vet_lunettes',   'Lunettes',           'glasses' },
    { 'vet_boucles',    'Boucles d\'oreilles','ears' },
    { 'vet_montre',     'Montre',             'watches' },
    { 'vet_bracelet',   'Bracelet',           'bracelets' },
}
for _, c in ipairs(clothes) do
    Items[c[1]] = {
        label = c[2], weight = CLOTHING_WEIGHT, stack = false, image = c[1] .. '.png', icon = '👕',
        clothing = c[3],
        description = 'Vêtement : glissez-le sur le personnage ou clic droit > Porter.',
        buttons = {
            { label = 'Porter',   export = 'elyzea_clothing.EquipFromSlot' },
            { label = 'Renommer', export = 'elyzea_clothing.RenameSlot', close = true },
        },
    }
end
Items.vet_sac.bonus = 10000 -- +10 KG de capacité quand il est porté
Items.vet_sac.description = 'Sac : +10 KG de capacité une fois porté.'

-- Objets ignorés (l'argent liquide est un compte de la base Elyzea, pas un objet)
IgnoredItems = { money = true, testburger = true }

-- ───────── Images partagées ─────────
-- Objets sans image à leur nom : on réutilise une image existante de html/img.
-- Pour en ajouter : ['nom_objet'] = 'fichier.png'
ImageAlias = {
    weed_ak47 = 'weed_baggy.png', weed_amnesia = 'weed_baggy.png', ['weed_og-kush'] = 'weed_baggy.png',
    ['weed_purple-haze'] = 'weed_baggy.png', weed_skunk = 'weed_baggy.png', ['weed_white-widow'] = 'weed_baggy.png',
    weed_ak47_seed = 'weed_seed.png', weed_amnesia_seed = 'weed_seed.png', ['weed_og-kush_seed'] = 'weed_seed.png',
    ['weed_purple-haze_seed'] = 'weed_seed.png', weed_skunk_seed = 'weed_seed.png', ['weed_white-widow_seed'] = 'weed_seed.png',
    weed_pouch = 'weed_baggy.png', weed_leaf = 'weed.png', empty_weed_bag = 'weed_baggy_empty.png',
    coca_leaf = 'cocaineleaf.png', cokebaggy = 'cocaine_baggy.png', xtcbaggy = 'xtc_baggy.png',
    meth_chemicals = 'hydrochloricacid.png', metal_scrap = 'metalscrap.png',
    empty_evidence_bag = 'evidence.png', filled_evidence_bag = 'evidence.png',
    blood_bag = 'blood_bag_500.png', defibrillator = 'defibrilator.png', painkiller = 'painkillers.png',
    pizza = 'pizza_ham_slice.png', bread = 'WEAPON_BREAD.png', kurkakola = 'cola.png',
    weaponlicense = 'WEAPON_LICENSE.png',
    crowbar = 'WEAPON_CROWBAR.png', walking_stick = 'walkstick.png',
    advancedrepairkit = 'repairkit.png', trojan_usb = 'usb_device.png',
    at_scope_macro = 'at_scope_small.png', at_compensator = 'at_muzzle_tactical.png',
}
