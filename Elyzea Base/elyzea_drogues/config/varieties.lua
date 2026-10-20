-- =====================================================================
--  CANNABIS : QUATRE VARIÉTÉS
--  Chaque variété a ses propres objets à chaque étape : une graine White Widow donne une
--  plante White Widow, des feuilles, têtes, joints et pochons White Widow. Jamais de mélange.
--  color : couleur de la fumée du joint et de la lueur de la plante (R, V, B)
--  prepStep : étape « préparer le cannabis » (effriter) ; false = on roule directement les têtes
--  growMinutes : durée totale de croissance (avec lampe et arrosée) · yield : feuilles récoltées
--  seedChance : % de chance de récupérer une graine à la récolte
--  Les objets doivent exister dans elyzea_inventory/shared/items.lua (bloc « Drogues »).
-- =====================================================================
Config.Varieties = {
    classic = {
        label = 'Weed', colorName = 'verte', color = { 60, 200, 80 }, order = 1,
        seed = 'weed_seed', leaf = 'weed_leaf', bud = 'weed_bud', ground = 'weed_ground', joint = 'joint', pouch = 'weed_pouch',
        prepStep = true, growMinutes = 90, yield = { min = 4, max = 6 }, seedChance = 35,
    },
    whitewidow = {
        label = 'White Widow', colorName = 'violette', color = { 170, 90, 230 }, order = 2,
        seed = 'weed_white-widow_seed', leaf = 'weed_leaf_ww', bud = 'weed_white-widow', ground = 'weed_ground_ww', joint = 'joint_ww', pouch = 'weed_pouch_ww',
        prepStep = true, growMinutes = 120, yield = { min = 4, max = 6 }, seedChance = 25,
    },
    purplehaze = {
        label = 'Purple Haze', colorName = 'violet foncé', color = { 95, 25, 150 }, order = 3,
        seed = 'weed_purple-haze_seed', leaf = 'weed_leaf_ph', bud = 'weed_purple-haze', ground = 'weed_ground_ph', joint = 'joint_ph', pouch = 'weed_pouch_ph',
        prepStep = true, growMinutes = 120, yield = { min = 3, max = 6 }, seedChance = 25,
    },
    -- Variété personnalisable : nom, couleur, temps, rendement et prix se changent ici ou dans le menu admin.
    -- (le nom dans l'inventaire est celui de elyzea_inventory/shared/items.lua : « Variété maison »)
    custom = {
        label = 'Variété maison', colorName = 'orange', color = { 255, 140, 0 }, order = 4,
        seed = 'weed_seed_custom', leaf = 'weed_leaf_custom', bud = 'weed_bud_custom', ground = 'weed_ground_custom', joint = 'joint_custom', pouch = 'weed_pouch_custom',
        prepStep = true, growMinutes = 110, yield = { min = 4, max = 6 }, seedChance = 30,
    },
}
