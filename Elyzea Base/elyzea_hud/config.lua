Config = {}

-- Fréquence de mise à jour du HUD (ms)
Config.UpdateRate = 200

-- true = la mini-carte n'apparaît qu'en véhicule, false = toujours affichée
Config.MapOnlyInVehicle = false

-- Commande pour afficher / masquer le HUD
Config.ToggleCommand = 'hud'

-- Position du radar natif, ancré en haut à droite.
-- Si le radar ne tombe pas pile dans le cadre doré, ajuste ces valeurs
-- (ou les variables --map-top / --map-right / --map-w / --map-h dans html/index.html).
Config.Minimap = {
    map  = { x = -0.1725, y = 0.030, w = 0.156, h = 0.181 },
    mask = { x = -0.1575, y = 0.045, w = 0.128, h = 0.155 },
    blur = { x = -0.1925, y = 0.010, w = 0.262, h = 0.215 },
}

-- Portées de pma-voice (affichées si l'état ne remonte pas la distance)
Config.VoiceRanges = { [1] = 3.0, [2] = 8.0, [3] = 15.0 }
