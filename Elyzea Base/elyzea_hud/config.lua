Config = {}

-- Fréquence de mise à jour du HUD (ms)
Config.UpdateRate = 200

-- Commande pour afficher / masquer le HUD
Config.ToggleCommand = 'hud'

-- Mini-carte supprimée : true = jamais affichée, pour tout le monde, quoi que fassent les autres scripts.
-- (La grande carte du menu Échap, le GPS et les points sur la carte restent.) false = mini-carte comme avant.
Config.HideMinimap = false
-- true (conseillé) : mini-carte d'origine de GTA, jamais déplacée ; le cadre du HUD se cale dessus.
Config.MinimapNative = true

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
