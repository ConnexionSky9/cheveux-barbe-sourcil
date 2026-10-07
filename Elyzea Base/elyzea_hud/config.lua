Config = {}

-- Fréquence de mise à jour du HUD (ms)
Config.UpdateRate = 200

-- Commande pour afficher / masquer le HUD
Config.ToggleCommand = 'hud'

-- Mini-carte : c'est admin_menu (onglet 🗺️ Carte) qui la place, pour tous les joueurs.
-- Le HUD se colle à droite de la carte, où qu'elle soit.
-- Sans admin_menu, cette position est utilisée (bas gauche, rectangle) :
Config.Minimap = {
    size = 0.185,          -- hauteur (part de l'écran)
    widthAdjust = 160,     -- % de largeur (100 = carré)
    marginX = 0.014,       -- écart avec le bord gauche
    marginY = 0.030,       -- écart avec le bas
    onlyInVehicle = false, -- true = mini-carte seulement en véhicule
}

-- Portées de pma-voice (affichées si l'état ne remonte pas la distance)
Config.VoiceRanges = { [1] = 3.0, [2] = 8.0, [3] = 15.0 }
