fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_cuisine'
description 'Elyzea - 80 recettes (italien, fast-food, japonais, mexicain) : objets d\'inventaire, objets en main et animations adaptés à chaque plat'
version '1.0.0'

-- data/recipes.lua est lu aussi par elyzea_inventory (création des 80 objets) : démarrer cette ressource AVANT elyzea_inventory
files { 'data/recipes.lua' }
client_scripts { 'client.lua' }
server_scripts { 'server.lua' }
