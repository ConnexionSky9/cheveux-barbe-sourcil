Config = {}

Config.Slots = 2

-- Où le personnage est affiché pendant la sélection (x, y, z, heading)
Config.PreviewPed = vector4(-75.2, -818.8, 326.18, 180.0)  -- toit de la Maze Bank

-- Caméra
Config.CamDistance = 2.6
Config.CamHeight = 0.35
Config.CamFov = 40.0

-- Apparition d'un NOUVEAU personnage
Config.FirstSpawn = vector4(-1037.6, -2737.6, 20.17, 330.0) -- aéroport

-- Création et connexion : gérées par ely_creator (Config.MaxCharacters doit être égal à Config.Slots)

Config.RotateStep = 30.0

-- Liaison avec ton loading screen
Config.LoadscreenCloseEvent = 'elyzea:closeLoadingScreen'
Config.LoadscreenFadeMs = 1200

Config.Debug = false
