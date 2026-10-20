-- =====================================================================
--  POINTS DE RÉCOLTE (placés par les administrateurs, ALT › Récolter)
--  item : objet obtenu (min..max) · respawn : secondes avant de pouvoir récolter à nouveau
--  duration : secondes de récolte · anim : animation (barre de progression du core)
--  Les plantes de cannabis des JOUEURS (pots) sont dans config/culture.lua.
-- =====================================================================
local A = {
    garden = { scenario = 'WORLD_HUMAN_GARDENER_PLANT' },
    pickup = { dict = 'random@domestic', clip = 'pickup_low', flag = 1 },
    kneel  = { scenario = 'CODE_HUMAN_MEDIC_KNEEL' },
}
Config.Harvest = {
    coca     = { label = 'Plant de coca',            drug = 'cocaine',   icon = '🌱', models = { 'h4_prop_bush_cocaplant_01' }, item = 'coca_leaf', min = 2, max = 4, respawn = 300, duration = 6, anim = A.garden },
    shroom   = { label = 'Champignons au sol',       drug = 'mushrooms', icon = '🍄', models = { 'prop_stoneshroom1', 'prop_stoneshroom2' }, item = 'magic_mushroom', min = 1, max = 3, respawn = 240, duration = 4, anim = A.pickup },
    chem     = { label = 'Fûts de produits chimiques', drug = 'meth',    icon = '🛢️', models = { 'prop_barrel_02a', 'prop_barrel_01a' }, item = 'meth_chemicals', min = 1, max = 2, respawn = 420, duration = 6, anim = A.kneel },
}
-- Plants de cannabis sauvages (un type par variété)
for id, v in pairs(Config.Varieties) do
    Config.Harvest['weed_' .. id] = { label = ('Plant de %s (sauvage)'):format(v.label), drug = 'weed', variety = id, icon = '🌿',
        models = { 'bkr_prop_weed_lrg_01a', 'bkr_prop_weed_lrg_01b', 'bkr_prop_weed_med_01a' }, item = v.leaf, min = 2, max = 4, respawn = 360, duration = 6, anim = A.garden }
end
