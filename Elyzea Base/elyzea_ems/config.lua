Config = {}
Config.Framework = 'elyzea' -- base Elyzea (elyzea_core)
Config.Job = 'ambulance'
Config.Label = 'EMS Pillbox'
Config.BossGrade = 6
Config.Grades = { -- index 1 = grade 0
    { name = 'stagiaire', label = 'Stagiaire', salary = 350, reviveShare = 20, healShare = 20 }, -- grade 0 (part EMS en %)
    { name = 'ambulancier', label = 'Ambulancier', salary = 550, reviveShare = 25, healShare = 25 }, -- grade 1 (part EMS en %)
    { name = 'infirmier', label = 'Infirmier', salary = 700, reviveShare = 30, healShare = 30 }, -- grade 2 (part EMS en %)
    { name = 'medecin', label = 'Médecin', salary = 900, reviveShare = 35, healShare = 35 }, -- grade 3 (part EMS en %)
    { name = 'chirurgien', label = 'Chirurgien', salary = 1150, reviveShare = 40, healShare = 40 }, -- grade 4 (part EMS en %)
    { name = 'chef_service', label = 'Chef de service', salary = 1350, reviveShare = 45, healShare = 45 }, -- grade 5 (part EMS en %)
    { name = 'boss', label = 'Directeur', salary = 1600, reviveShare = 50, healShare = 50 }, -- grade 6 (part EMS en %)
}
Config.Fees = {
    { label = 'Consultation', amount = 150 },
    { label = 'Soins légers (bandage, désinfection)', amount = 300 },
    { label = 'Pose d\'attelle', amount = 450 },
    { label = 'Réanimation sur place', amount = 800 },
    { label = 'Transport en ambulance', amount = 600 },
    { label = 'Transport héliporté', amount = 1500 },
    { label = 'Opération chirurgicale', amount = 2500 },
    { label = 'Certificat médical', amount = 200 },
}
Config.Target = 'elyzea' -- menu intégré (maintenir la touche, puis cliquer)
Config.Blip = { coords = vec3(307.70, -595.30, 43.30), sprite = 61, color = 1, scale = 0.9 }

Config.Settings = {
    duty = true,
    whitelist = true,
    dispatch = true,
    deathSystem = 'auto',
    reviveEvent = '',
    bleedoutTime = 600,
    respawnTime = 300,
    respawnHold = 3,
    respawnCost = 2500,
    removeItems = true,
    removeCash = false,
    forceRespawn = true,
    recallCooldown = 60,
    invincibleDown = true,
    reviveReward = 0,
    receptionEnabled = true,
    receptionPrice = 500,
    receptionMaxEms = 0,
    receptionTime = 10,
    callEnabled = true,
    callCommand = 'ems',
    callCooldown = 120,
    alertSound = true,
    alertSprite = 153,
    alertColor = 1,
    alertArrive = 15,
    alertExpire = 15,
    alertMax = 3,
    billCommission = 10,
    billTimeout = 20,
    billMax = 50000,
    billDistance = 6,
    platePrefix = 'EMS',
    fuel = 100,
    keyTablet = 'F6',
    keyAccept = 'G',
    keyIgnore = 'I',
    altControl = 19,
    markerDist = 15,
    interactDist = 1.5,
    altDist = 3,
    staffGroups = 'admin, superadmin',
    staffAce = 'elyzea.ems.staff',
    reviveCommand = 'ems_revive',
    healCommand = 'ems_heal',
    outfitsEnabled = true,
}

Config.Outfits = {
    male = {
        tshirt = { 15, 0 }, -- T-shirt
        torso = { 250, 0 }, -- Veste
        decals = { 58, 0 }, -- Logos
        arms = { 85, 0 }, -- Bras / gants
        pants = { 96, 0 }, -- Pantalon
        shoes = { 54, 0 }, -- Chaussures
        chain = { 126, 0 }, -- Accessoire de cou
        bproof = { 0, 0 }, -- Gilet
        mask = { 0, 0 }, -- Masque
        bags = { 0, 0 }, -- Sac
        helmet = { -1, 0 }, -- Chapeau / casque
    },
    female = {
        tshirt = { 15, 0 }, -- T-shirt
        torso = { 258, 0 }, -- Veste
        decals = { 66, 0 }, -- Logos
        arms = { 109, 0 }, -- Bras / gants
        pants = { 99, 0 }, -- Pantalon
        shoes = { 55, 0 }, -- Chaussures
        chain = { 96, 0 }, -- Accessoire de cou
        bproof = { 0, 0 }, -- Gilet
        mask = { 0, 0 }, -- Masque
        bags = { 0, 0 }, -- Sac
        helmet = { -1, 0 }, -- Chapeau / casque
    },
}

Config.Points = {
    { type = 'reception', coords = vec3(307.70, -595.30, 43.30), minGrade = 0 }, -- Accueil
    { type = 'cloakroom', coords = vec3(298.60, -598.40, 43.30), minGrade = 0 }, -- Vestiaire
    { type = 'pharmacy', coords = vec3(309.60, -561.90, 43.30), minGrade = 0 }, -- Pharmacie
    { type = 'beds', coords = vec3(322.60, -587.20, 43.30), minGrade = 0 }, -- Lits de soin
    { type = 'boss', coords = vec3(335.00, -594.00, 43.30), minGrade = 6 }, -- Bureau direction
    { type = 'respawn', coords = vec3(341.20, -582.50, 43.30), minGrade = 0 }, -- Réapparition
}

Config.VehicleSpawns = {
    { label = 'Parking ambulances', type = 'car', coords = vec3(294.60, -574.40, 43.20), spawn = vec4(291.20, -581.60, 43.20, 340.00), minGrade = 0 },
    { label = 'Parking souterrain', type = 'car', coords = vec3(339.40, -583.90, 28.80), spawn = vec4(333.00, -576.50, 28.80, 340.00), minGrade = 1 },
    { label = 'Héliport', type = 'heli', coords = vec3(341.40, -580.80, 74.20), spawn = vec4(351.60, -588.00, 74.20, 250.00), minGrade = 3 },
}

Config.VehicleStores = {
    { label = 'Retour parking', type = 'car', coords = vec3(290.10, -590.20, 43.10), radius = 4.0 },
    { label = 'Retour souterrain', type = 'car', coords = vec3(326.70, -578.30, 28.80), radius = 4.0 },
    { label = 'Retour héliport', type = 'heli', coords = vec3(351.60, -588.00, 74.20), radius = 7.0 },
}

Config.Inventory = 'elyzea'
Config.Stashes = {
    { id = 'ems_personnel', label = 'Coffre du personnel', coords = vec3(306.40, -601.40, 43.30), weight = 1000, slots = 250, minGrade = 0 }, -- poids en kg
    { id = 'ems_reserve', label = 'Réserve médicale', coords = vec3(310.90, -565.10, 43.30), weight = 1000, slots = 250, minGrade = 2 }, -- poids en kg
    { id = 'ems_direction', label = 'Coffre de direction', coords = vec3(337.20, -591.80, 43.30), weight = 500, slots = 120, minGrade = 6 }, -- poids en kg
}

Config.Supplies = {
    { label = 'Armoire à bandages', item = 'bandage', coords = vec3(309.20, -568.30, 43.30), amount = 5, max = 15, minGrade = 0 },
    { label = 'Medical Kits (réanimation)', item = 'medical_kit', coords = vec3(311.60, -566.20, 43.30), amount = 1, max = 3, minGrade = 1 },
    { label = 'Bandages (urgences)', item = 'bandage', coords = vec3(296.40, -589.80, 43.30), amount = 5, max = 15, minGrade = 0 },
}

Config.Care = {
    distance = 2.0,
    autoCharge = true, -- prélèvement automatique au patient
    revive = { item = 'medical_kit', price = 800, time = 10, health = 50, consume = true },
    inspect = { time = 4 },
    heal = { item = 'bandage', price = 300, time = 5, amount = 100, consume = true, self = true },
}

Config.Vehicles = {
    { model = 'ambulance', label = 'Ambulance', type = 'car', minGrade = 0 },
    { model = 'lguard', label = '4x4 Secours', type = 'car', minGrade = 1 },
    { model = 'fbi2', label = 'SUV Médecin', type = 'car', minGrade = 3 },
    { model = 'polmav', label = 'Hélico médical', type = 'heli', minGrade = 3, livery = 1 },
}

Config.Pharmacy = {
    { item = 'bandage', label = 'Bandage', price = 30, minGrade = 0 },
    { item = 'gauze', label = 'Compresse', price = 20, minGrade = 0 },
    { item = 'painkiller', label = 'Antidouleur', price = 60, minGrade = 0 },
    { item = 'medical_kit', label = 'Medical Kit', price = 250, minGrade = 1 },
    { item = 'defibrillator', label = 'Défibrillateur', price = 900, minGrade = 2 },
    { item = 'morphine', label = 'Morphine', price = 180, minGrade = 3 },
    { item = 'blood_bag', label = 'Poche de sang', price = 300, minGrade = 3 },
    { item = 'splint', label = 'Attelle', price = 80, minGrade = 1 },
}


