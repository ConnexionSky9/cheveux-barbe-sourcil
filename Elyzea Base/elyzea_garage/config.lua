Config = {}

-- Distance maximum entre le joueur et le PNJ pour utiliser le garage
Config.UseDistance = 6.0

-- Distance maximum entre le PNJ et le véhicule à ranger
Config.StoreDistance = 40.0

-- Image d'un modèle du jeu de base (véhicules ajoutés : image par défaut)
Config.ImageUrl = 'https://docs.fivem.net/vehicles/%s.webp'

-- Fourrière : un véhicule enlevé par la police se récupère dans n'importe quel garage public, contre ce prix
-- (payé en banque, sinon en liquide ; l'argent va au compte de la police si toPolice = true)
Config.Impound = { fee = 500, toPolice = true }

-- Nom enregistré dans player_vehicles.garage (tous les garages publics partagent le même : ils sont connectés)
Config.GarageName = 'public'

-- Déformations de la carrosserie : enregistrées au rangement et remises à la sortie
Config.SaveDeformation = true
