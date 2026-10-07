PhotoConfig = {}

PhotoConfig.Size = 256           -- images carrées de 256 × 256 px (.webp transparent)
PhotoConfig.Quality = 0.88       -- qualité webp (0 à 1)
PhotoConfig.Delay = 220          -- ms d'attente après chaque changement (laisse le jeu charger le vêtement)
PhotoConfig.Studio = vector4(-1266.0, -2960.0, 300.0, 330.0)   -- point isolé en hauteur (x, y, z, cap)
PhotoConfig.Ace = 'elyzea.photos'

-- Cadrage par rayon : bone = os visé, dz = décalage vertical, dist = distance caméra,
-- fov = champ de vision, side = angle autour du personnage (0 = de face, 180 = de dos)
PhotoConfig.Views = {
    tops        = { bone = 24818, dz = -0.05, dist = 1.45, fov = 42 },
    undershirts = { bone = 24818, dz = -0.05, dist = 1.30, fov = 42 },
    vests       = { bone = 24818, dz = -0.05, dist = 1.30, fov = 42 },
    decals      = { bone = 24818, dz = 0.00,  dist = 1.10, fov = 40 },
    chains      = { bone = 39317, dz = -0.10, dist = 0.80, fov = 40 },
    arms        = { bone = 24818, dz = -0.25, dist = 1.60, fov = 44 },
    pants       = { bone = 11816, dz = -0.40, dist = 1.60, fov = 44 },
    shoes       = { bone = 11816, dz = -0.92, dist = 0.95, fov = 42 },
    bags        = { bone = 24818, dz = -0.05, dist = 1.45, fov = 42, side = 180 },
    masks       = { bone = 31086, dz = 0.02,  dist = 0.70, fov = 40 },
    hats        = { bone = 31086, dz = 0.10,  dist = 0.80, fov = 40 },
    glasses     = { bone = 31086, dz = 0.03,  dist = 0.55, fov = 40 },
    ears        = { bone = 31086, dz = 0.00,  dist = 0.42, fov = 40, side = 75 },
    watches     = { bone = 18905, dz = 0.00,  dist = 0.45, fov = 40, side = -80 },
    bracelets   = { bone = 57005, dz = 0.00,  dist = 0.45, fov = 40, side = 80 },
}

-- Pendant la capture d'un rayon, ces autres rayons passent sur « rien » pour bien voir l'objet
PhotoConfig.Isolate = {
    tops        = { 'vests', 'chains', 'bags' },
    undershirts = { 'tops', 'vests', 'chains', 'bags' },
    vests       = { 'bags' },
    decals      = { 'vests', 'bags' },
    chains      = { 'bags' },
    bags        = {},
    masks       = { 'hats', 'glasses' },
    hats        = { 'masks' },
    glasses     = { 'masks' },
    ears        = { 'hats', 'masks' },
}
