-- =====================================================================
--  ELYZEA FUEL - réglages par défaut
--  Tout ce qui suit se change ensuite en jeu : admin_menu › Stations essence
--  (permission « fuel_manage »). Ces valeurs ne servent qu'au premier démarrage.
-- =====================================================================
Config = {}

Config.Defaults = {
    enabled     = true,     -- consommation active
    consumption = 1.0,      -- multiplicateur global (2.0 = deux fois plus vite)
    price       = 3,        -- prix par litre proposé pour une nouvelle station ($)
    payWith     = 'auto',   -- 'auto' (liquide puis banque), 'cash' ou 'bank'
    showBlips   = true,     -- stations sur la carte
    refuelTime  = 120,      -- millisecondes par litre ajouté (animation du plein)
}

-- Consommation (pourcentage du réservoir par seconde) : ralenti + part liée au régime moteur.
-- Valeurs moyennes : ~55 min de conduite normale, ~16 min à fond, plusieurs heures au ralenti.
Config.Idle = 0.005
Config.Max  = 0.10

-- Multiplicateur par classe de véhicule (GetVehicleClass)
Config.ClassMultiplier = {
    [0] = 0.8,  -- compactes
    [1] = 1.0,  -- berlines
    [2] = 1.2,  -- SUV
    [3] = 1.0,  -- coupés
    [4] = 1.2,  -- muscle
    [5] = 1.1,  -- sport classiques
    [6] = 1.2,  -- sport
    [7] = 1.4,  -- super
    [8] = 0.6,  -- motos
    [9] = 1.2,  -- tout-terrain
    [10] = 1.5, -- industriels
    [11] = 1.2, -- utilitaires
    [12] = 1.2, -- vans
    [13] = 0.0, -- vélos : pas d'essence
    [14] = 1.0, -- bateaux
    [15] = 1.3, -- hélicoptères
    [16] = 1.3, -- avions
    [17] = 1.0, -- services
    [18] = 1.0, -- urgences
    [19] = 1.3, -- militaires
    [20] = 1.4, -- commerciaux
    [21] = 0.0, -- trains
}

-- Véhicules électriques : pas de consommation d'essence
Config.Electric = {
    'voltic', 'voltic2', 'raiden', 'cyclone', 'cyclone2', 'tezeract', 'neon', 'imorgon', 'khamelion', 'surge', 'iwagen',
    'caddy', 'caddy2', 'caddy3', 'airtug', 'rcbandito', 'omnisegt', 'virtue', 'powersurge', 'dilettante', 'dilettante2',
}

-- Réservoir utilisé pour le prix quand le véhicule n'en donne pas (litres pour 100 %)
Config.DefaultTank = 60
Config.TankMin, Config.TankMax = 20, 120

-- Distance autour d'une station pour faire le plein (mètres), si la station n'a pas son propre rayon
Config.DefaultRadius = 12.0
-- Distance max entre le joueur et le véhicule pour faire le plein à pied
Config.VehicleDistance = 5.0

-- Niveau d'un véhicule qui n'a encore jamais été suivi (voiture sortie par le staff, PNJ volé…)
Config.NewVehicleMin, Config.NewVehicleMax = 40, 80

Config.Blip = { sprite = 361, color = 1, scale = 0.7 }

-- Stations au premier démarrage (stations-service de la carte GTA). Modifiables ensuite dans le menu admin.
Config.DefaultStations = {
    { x = 49.42, y = 2778.79, z = 58.04 }, { x = 263.89, y = 2606.46, z = 44.98 }, { x = 1039.96, y = 2671.13, z = 39.55 },
    { x = 1207.26, y = 2660.18, z = 37.90 }, { x = 2539.69, y = 2594.19, z = 37.94 }, { x = 2679.86, y = 3263.95, z = 55.24 },
    { x = 2005.06, y = 3773.89, z = 32.40 }, { x = 1687.16, y = 4929.39, z = 42.08 }, { x = 1701.31, y = 6416.03, z = 32.76 },
    { x = 179.86, y = 6602.84, z = 31.87 }, { x = -94.46, y = 6419.59, z = 31.49 }, { x = -2555.00, y = 2334.40, z = 33.08 },
    { x = -1800.38, y = 803.66, z = 138.65 }, { x = -1437.62, y = -276.75, z = 46.21 }, { x = -2096.24, y = -320.29, z = 13.17 },
    { x = -724.62, y = -935.16, z = 19.21 }, { x = -526.02, y = -1211.00, z = 18.18 }, { x = -70.21, y = -1761.79, z = 29.53 },
    { x = 265.65, y = -1261.31, z = 29.29 }, { x = 819.65, y = -1028.85, z = 26.40 }, { x = 1208.95, y = -1402.57, z = 35.22 },
    { x = 1181.38, y = -330.85, z = 69.32 }, { x = 620.84, y = 269.10, z = 103.09 }, { x = 2581.32, y = 362.04, z = 108.47 },
    { x = 176.63, y = -1562.03, z = 29.26 }, { x = -319.29, y = -1471.72, z = 30.55 }, { x = 1784.32, y = 3330.55, z = 41.25 },
}
