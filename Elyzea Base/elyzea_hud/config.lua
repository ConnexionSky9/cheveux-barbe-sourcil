Config = {}

-- Fréquence de mise à jour du HUD (ms)
Config.UpdateRate = 200

-- Commande pour afficher / masquer le HUD
Config.ToggleCommand = 'hud'

-- Mini-carte : c'est admin_menu (onglet 🗺️ Carte) qui la place, pour tous les joueurs.
-- Le HUD se colle à droite de la carte, où qu'elle soit.
-- Sans admin_menu (ou pendant son redémarrage), cette position est utilisée (bas droite, rectangle),
-- identique à celle d'admin_menu pour que la carte ne bouge jamais :
Config.Minimap = {
    position = 'bottom-right',
    size = 0.185,          -- hauteur (part de l'écran)
    widthAdjust = 160,     -- % de largeur (100 = carré)
    marginX = 0.014,       -- écart avec le bord droit
    marginY = 0.030,       -- écart avec le bas
    onlyInVehicle = false, -- true = mini-carte seulement en véhicule
}

-- Portées de pma-voice (affichées si l'état ne remonte pas la distance)
Config.VoiceRanges = { [1] = 3.0, [2] = 8.0, [3] = 15.0 }
