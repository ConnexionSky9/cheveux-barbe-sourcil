-- =====================================================================
--  CULTURE DU CANNABIS PAR LES JOUEURS
--  Pot (objet « plant_pot ») posé au sol → ALT : planter une graine → ALT : installer une lampe
--  (« grow_lamp ») → arroser (« watering_can » + « water ») → croissance par étapes → récolte.
--  La croissance est calculée à partir des dates enregistrées : elle continue quand le propriétaire
--  est déconnecté et après un redémarrage, sans boucle par plante.
-- =====================================================================
Config.Culture = {
    maxPotsPerPlayer = 6,        -- pots posés par personnage
    minDistance = 1.2,           -- distance minimale entre deux pots (m)
    placeMaxDistance = 3.0,      -- le pot est posé à X m max du joueur
    ownerOnlyPlant = true,       -- seul le propriétaire plante / installe la lampe / reprend le pot
    ownerOnlyHarvest = false,    -- false : n'importe qui peut récolter (vol de plantes possible)
    policeCanDestroy = true,     -- policier en service : « Détruire la plante » (ALT)

    water = {
        max = 100,               -- réserve d'eau du pot (%)
        perUse = 50,             -- un arrosage (1 objet « water ») ajoute X %
        decayPerHour = 20,       -- la réserve baisse de X % par heure
        needBelow = 60,          -- « Arroser » est proposé sous X %
    },
    healthLossPerHourDry = 25,   -- santé perdue par heure sans eau (0 = morte)
    lampFactor = 1.0,            -- vitesse de croissance avec lampe
    noLampFactor = 0.25,         -- sans lampe (0 = ne pousse pas)
    fertilizerBoost = 1.25,      -- engrais : croissance × X jusqu'à la récolte
    deadRemoveHours = 24,        -- une plante morte disparaît (pot vide) au bout de X h

    potModel = 'bkr_prop_weed_bucket_open_01a',
    lampModel = 'prop_worklight_03a',
    lampOffset = { x = 0.7, y = 0.0, z = 0.0 },
    -- Étapes visibles : à partir de pct %, la plante prend ce modèle (biker DLC, présents dans GTA)
    stages = {
        { pct = 0,   label = 'Germination', model = 'bkr_prop_weed_01_small_01b' },
        { pct = 25,  label = 'Pousse',      model = 'bkr_prop_weed_01_small_01c' },
        { pct = 55,  label = 'Croissance',  model = 'bkr_prop_weed_med_01a' },
        { pct = 85,  label = 'Floraison',   model = 'bkr_prop_weed_lrg_01a' },
        { pct = 100, label = 'Mature',      model = 'bkr_prop_weed_lrg_01b' },
    },
    -- Zones interdites (cercles) : x, y, rayon. Ex. : { x = 441.0, y = -982.0, r = 80.0 } (commissariat)
    forbidden = {},
}
