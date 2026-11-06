Config = {}

-- Fréquence de mise à jour du HUD (ms)
Config.UpdateRate = 200

-- Commande pour afficher / masquer le HUD
Config.ToggleCommand = 'hud'

-- Mini-carte de GTA supprimée pour tout le monde, quoi que fassent les autres scripts
-- (la grande carte du menu Échap et le GPS restent). Elle est remplacée par la carte Elyzea ci-dessous,
-- dessinée exactement dans le cadre du HUD.
Config.HideMinimap = true
Config.MinimapNative = true   -- position du cadre : celle de la mini-carte d'origine (même disposition qu'avant)

-- Carte Elyzea (dessinée par le HUD, dans le cadre)
Config.CustomMap = {
    enabled = true,
    -- Image de la carte : une seule image, ou des tuiles (cols × rows) nommées avec {x} et {y} (à partir de 0).
    -- Pour une carte plus nette : remplacez par une image haute définition (ex. 8192 px découpée en tuiles 4096).
    image = { path = 'img/map_{x}_{y}.jpg', cols = 2, rows = 2 },   -- carte 4096 px (4 tuiles)
    -- Coordonnées du jeu aux bords de l'image (gauche, droite, bas, haut)
    bounds = { minX = -5661.2, maxX = 6694.0, minY = -4058.5, maxY = 8429.3 },
    zoom = { foot = 480, vehicle = 720, fast = 1200 },   -- mètres visibles en largeur (à pied, en véhicule, à grande vitesse)
    rotate = true,          -- la carte tourne avec la caméra (comme GTA) ; false = nord toujours en haut
    blips = true,           -- points de la carte (commerces, métiers, GPS…) affichés
    blipRefresh = 2500,     -- ms entre deux lectures des points
    onlyInVehicle = false,  -- true = carte seulement en véhicule
}

-- Mini-carte : c'est admin_menu (onglet 🗺️ Carte) qui la place, pour tous les joueurs.
-- Le HUD se colle à droite de la carte, où qu'elle soit.
-- Sans admin_menu (ou pendant son redémarrage), cette position est utilisée (bas gauche, rectangle),
-- identique à celle d'admin_menu pour que la carte ne bouge jamais :
Config.Minimap = {
    position = 'bottom-left',
    size = 0.183,          -- hauteur visible (part de l'écran)
    widthAdjust = 160,     -- % de largeur (100 = carré)
    marginX = 0.010,       -- écart avec le bord gauche
    marginY = 0.000,       -- écart supplémentaire avec le bas
    onlyInVehicle = false, -- true = mini-carte seulement en véhicule
}

-- Portées de pma-voice (affichées si l'état ne remonte pas la distance)
Config.VoiceRanges = { [1] = 3.0, [2] = 8.0, [3] = 15.0 }

-- Cadre de la mini-carte (pixels pour un écran 1080p, mis à l'échelle sur les autres résolutions).
-- La bordure du cadre est opaque : elle recouvre le bord de la carte (inner) et déborde vers l'extérieur (outer).
-- Si un bout de carte dépasse encore chez toi, augmente « outer » ; si le cadre mange trop la carte, baisse « inner ».
-- Décalage fin du cadre si besoin : dx, dy (px), dw, dh (px en plus / en moins).
Config.Frame = { inner = 8, outer = 12, dx = 0, dy = 0, dw = 0, dh = 0 }
