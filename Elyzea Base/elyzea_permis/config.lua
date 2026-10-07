Config = {}

-- Objet du permis (déjà déclaré dans elyzea_inventory/shared/items.lua)
Config.Item = 'permis'

-- Les trois permis
Config.Categories = {
    car   = { short = 'B', label = 'Permis B · Voiture',       icon = '🚗', model = 'asea',  license = 'driver' },
    moto  = { short = 'A', label = 'Permis A · Moto',          icon = '🏍️', model = 'pcj',   license = 'moto' },
    truck = { short = 'C', label = 'Permis C · Poids lourd',   icon = '🚚', model = 'mule',  license = 'truck' },
}
Config.Order = { 'car', 'moto', 'truck' }

-- Valeurs par défaut (chaque PNJ auto-école peut les changer dans le menu admin)
-- Prix de départ par permis (ensuite : menu admin › Métiers › Auto-école › Prix)
Config.Prices = {
    car   = { code = 250, drive = 500 },
    moto  = { code = 250, drive = 450 },
    truck = { code = 400, drive = 900 },
}

Config.Defaults = {    questions = 10,         -- questions par examen de code
    passScore = 8,          -- bonnes réponses nécessaires
    maxFaults = 5,          -- fautes autorisées pendant la conduite (au-delà : échec)
    speedTolerance = 8,     -- km/h tolérés au-dessus de la limite avant une faute
}

-- Une faute pour excès de vitesse est comptée au plus toutes les 6 s, une faute pour choc toutes les 4 s
Config.SpeedFaultCooldown = 6000
Config.CrashFaultCooldown = 4000
Config.CheckpointRadius = 7.0

-- ---------------------------------------------------------------------
-- Questions du code. answer = numéro de la bonne réponse (1, 2, 3 ou 4).
-- « common » : posées pour tous les permis ; puis les questions propres à chaque permis.
-- ---------------------------------------------------------------------
Config.Questions = {
    common = {
        { q = 'En ville, sauf panneau contraire, la vitesse est limitée à :', a = { '30 km/h', '50 km/h', '70 km/h', '90 km/h' }, answer = 2 },
        { q = 'Un feu orange fixe signifie :', a = { 'Accélérer pour passer', 'S\'arrêter, sauf si c\'est dangereux', 'Priorité à droite', 'Rien de particulier' }, answer = 2 },
        { q = 'À une intersection sans signalisation, qui a la priorité ?', a = { 'Le véhicule le plus gros', 'Celui qui vient de gauche', 'Celui qui vient de droite', 'Le plus rapide' }, answer = 3 },
        { q = 'Un panneau STOP impose :', a = { 'De ralentir', 'L\'arrêt complet et de céder le passage', 'De klaxonner', 'De passer si personne ne vient, sans s\'arrêter' }, answer = 2 },
        { q = 'Une ambulance arrive derrière vous, sirène allumée :', a = { 'Vous accélérez', 'Vous vous écartez pour la laisser passer', 'Vous freinez fort au milieu de la voie', 'Vous l\'ignorez' }, answer = 2 },
        { q = 'Avant de changer de voie, vous devez :', a = { 'Klaxonner', 'Regarder dans le rétroviseur et mettre le clignotant', 'Accélérer fort', 'Freiner' }, answer = 2 },
        { q = 'Le téléphone tenu en main en conduisant est :', a = { 'Autorisé à l\'arrêt au feu', 'Autorisé en ville', 'Interdit', 'Autorisé avec les feux de détresse' }, answer = 3 },
        { q = 'Sous la pluie, la distance de freinage :', a = { 'Diminue', 'Ne change pas', 'Augmente', 'Dépend seulement du véhicule' }, answer = 3 },
        { q = 'La nuit, en croisant un autre véhicule, vous utilisez :', a = { 'Les feux de route', 'Les feux de croisement', 'Les feux de détresse', 'Aucun feu' }, answer = 2 },
        { q = 'Sur une ligne continue, vous pouvez :', a = { 'La franchir pour doubler', 'La chevaucher', 'Ni la franchir ni la chevaucher', 'La franchir la nuit' }, answer = 3 },
        { q = 'Un piéton s\'engage sur un passage piéton :', a = { 'Vous klaxonnez', 'Vous le laissez traverser', 'Vous passez avant lui', 'Vous l\'évitez sans ralentir' }, answer = 2 },
        { q = 'Conduire après avoir bu de l\'alcool :', a = { 'Est sans risque si on roule doucement', 'Augmente fortement le risque d\'accident', 'Est autorisé la nuit', 'Améliore les réflexes' }, answer = 2 },
        { q = 'Sur autoroute, la vitesse maximale (temps sec) est de :', a = { '90 km/h', '110 km/h', '130 km/h', '150 km/h' }, answer = 3 },
        { q = 'Un panneau triangulaire à bord rouge indique :', a = { 'Une obligation', 'Un danger', 'Une interdiction', 'Une information' }, answer = 2 },
        { q = 'Après un accident avec des blessés, vous devez d\'abord :', a = { 'Partir', 'Protéger, alerter, secourir', 'Déplacer les blessés', 'Prendre des photos' }, answer = 2 },
        { q = 'La police vous fait signe de vous arrêter :', a = { 'Vous continuez', 'Vous vous arrêtez dès que possible en sécurité', 'Vous accélérez', 'Vous faites demi-tour' }, answer = 2 },
    },
    car = {
        { q = 'La ceinture de sécurité est obligatoire :', a = { 'Seulement pour le conducteur', 'Seulement sur autoroute', 'Pour tous les occupants', 'Seulement la nuit' }, answer = 3 },
        { q = 'Pour stationner en pente, vous :', a = { 'Laissez le frein desserré', 'Serrez le frein à main et braquez les roues', 'Laissez le moteur tourner', 'Mettez le point mort sans frein' }, answer = 2 },
        { q = 'La distance de sécurité avec le véhicule devant correspond à au moins :', a = { '1 seconde', '2 secondes', '5 mètres', 'Un mètre par 10 km/h' }, answer = 2 },
        { q = 'Un enfant de 4 ans doit voyager :', a = { 'Sur les genoux d\'un adulte', 'Dans un siège adapté', 'À l\'avant sans ceinture', 'Debout à l\'arrière' }, answer = 2 },
    },
    moto = {
        { q = 'Le casque à moto est :', a = { 'Conseillé', 'Obligatoire pour le conducteur et le passager', 'Obligatoire seulement sur autoroute', 'Facultatif en ville' }, answer = 2 },
        { q = 'Remonter une file de voitures arrêtées à grande vitesse est :', a = { 'Recommandé', 'Dangereux et interdit', 'Obligatoire', 'Autorisé partout' }, answer = 2 },
        { q = 'En virage à moto, on freine :', a = { 'Au milieu du virage', 'Avant d\'entrer dans le virage', 'Jamais', 'Uniquement avec le frein avant, fort' }, answer = 2 },
        { q = 'Les gants homologués à moto sont :', a = { 'Interdits', 'Obligatoires', 'Facultatifs', 'Réservés à l\'hiver' }, answer = 2 },
    },
    truck = {
        { q = 'Un poids lourd a besoin d\'une distance de freinage :', a = { 'Plus courte qu\'une voiture', 'Identique', 'Plus longue qu\'une voiture', 'Nulle' }, answer = 3 },
        { q = 'Les angles morts d\'un camion sont :', a = { 'Inexistants', 'Plus grands que ceux d\'une voiture', 'Plus petits', 'Seulement à l\'avant' }, answer = 2 },
        { q = 'Avant un pont bas, le chauffeur vérifie :', a = { 'La couleur du pont', 'La hauteur autorisée', 'Le nombre de voies', 'Rien' }, answer = 2 },
        { q = 'Dans une longue descente, un poids lourd utilise :', a = { 'Seulement les freins', 'Le frein moteur et un rapport adapté', 'Le point mort', 'Les feux de détresse' }, answer = 2 },
    },
}
