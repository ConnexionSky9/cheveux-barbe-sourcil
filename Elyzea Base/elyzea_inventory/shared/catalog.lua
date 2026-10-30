--[[
    Catalogue : catégories de l'inventaire et poids revus
    Chargé APRÈS shared/import.lua (tous les objets sont connus).

    Catégories (onglets de l'inventaire) :
      all     = tout
      weapons = armes, munitions, accessoires d'armes
      food    = nourriture et boissons
      papers  = papiers : carte d'identité, PPA, permis, carte de presse…
      other   = le reste (visible dans « Tout »)
    Une catégorie peut être forcée dans la définition d'un objet : category = 'food'.

    Poids (grammes) : la capacité est de 18 KG (28 KG avec un sac).
    Repères : papier 10 g · téléphone 200 g · canette 350 g · bouteille 0,5 L 500 g ·
    pistolet ~1 KG · fusil 3 à 5 KG · aucun objet au-dessus de la capacité maximale.
]]

ItemCategories = {
    { id = 'all',     label = 'Tout',              icon = '◈' },
    { id = 'weapons', label = 'Armes & munitions', icon = '⌖' },
    { id = 'food',    label = 'Nourriture',        icon = '◍' },
    { id = 'papers',  label = 'Papiers',           icon = '▤' },
}

-- Poids revus (grammes). Objets absents : poids d'origine, déjà cohérent.
WeightFix = {
    -- Impossibles à porter ou très exagérés
    diving_gear = 12000, WEAPON_MINIGUN = 15000, jammer = 4000, parachute = 5000, toaster = 2000, drill = 2500,
    -- Trop légers pour ce qu'ils sont
    small_tv = 3000, wheelchair = 5000, stretcher = 6000, crutch = 900, bodybag = 1500, advanced_medical_kit = 1200,
    defibrilator = 2500, defibrillator = 2500, garbage = 300, nitrous = 2000,
    -- Trop lourds pour ce qu'ils sont
    radiocell = 50, radio = 350, walking_stick = 500, firstaid = 800, ifaks = 500, repairkit = 1500, advancedrepairkit = 2500,
    lockpick = 50, advancedlockpick = 150, binoculars = 600, security_card_01 = 10, security_card_02 = 10, diving_fill = 2000,
    goldbar = 1000, goldchain = 60, ['10kgoldchain'] = 80, diamond_ring = 10, rolex = 150, coke_brick = 1000, coke_small_brick = 500,
    weed_ak47 = 5, weed_amnesia = 5, weed_og_kush = 5, ['weed_og-kush'] = 5, weed_skunk = 5, weed_nutrition = 1000, mustard = 300,
    WEAPON_MOLOTOV = 700, WEAPON_PISTOL50 = 1400, WEAPON_CROWBAR = 1500, WEAPON_WRENCH = 1200, crowbar = 1500,
    WEAPON_BATTLEAXE = 2500, WEAPON_FIREEXTINGUISHER = 4500, WEAPON_FERTILIZERCAN = 5000, WEAPON_HAZARDCAN = 5000,
    -- Boissons : contenant compris
    beer = 350, coffee = 250, whiskey = 750, vodka = 750, wine = 800,
    -- Papiers : jamais 0 g
    id_card = 10, driver_license = 10, weaponlicense = 10, lawyerpass = 10, stickynote = 5, empty_weed_bag = 1,
}

-- Papiers (en plus de la règle sur les noms ci-dessous)
local PAPERS = {
    carte_identite = true, ppa = true, ppa_fdo = true, permis = true, presse_carte = true,
    id_card = true, driver_license = true, weaponlicense = true, lawyerpass = true,
}
local PAPER_PATTERNS = { '^carte_', '^permis', '^ppa', 'license', 'licence', 'passport', 'passeport', '^papier', '^document' }

-- Nourriture et boissons qui n'ont pas d'effet faim / soif déclaré
local FOOD = {
    sandwich = true, beer = true, coffee = true, whiskey = true, vodka = true, wine = true, grapejuice = true, grape = true,
    biberon = true, nc_champagne = true, nc_whisky = true, nc_vodka = true, nc_rhum = true, nc_soda = true, nc_energy = true,
}

local function isPaper(name)
    if PAPERS[name] then return true end
    local n = name:lower()
    for _, p in ipairs(PAPER_PATTERNS) do if n:find(p) then return true end end
    return false
end
local function isFood(name, d)
    if FOOD[name] then return true end
    local st = d.client and d.client.status
    return type(st) == 'table' and ((tonumber(st.hunger) or 0) > 0 or (tonumber(st.thirst) or 0) > 0)
end

function ItemCategoryOf(name, d)
    d = d or Items[name] or {}
    if d.category then return d.category end
    if d.kind == 'weapon' or d.kind == 'ammo' or d.kind == 'component' then return 'weapons' end
    if isPaper(name) then return 'papers' end
    if isFood(name, d) then return 'food' end
    return 'other'
end

for name, w in pairs(WeightFix) do
    local real = ResolveItemName and ResolveItemName(name) or name
    if real and Items[real] then Items[real].weight = w end
end
for name, d in pairs(Items) do d.category = ItemCategoryOf(name, d) end
