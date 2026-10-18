fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_eau'
description 'Eau du jeu + zones d\'eau dessinées en jeu (/eau_editeur)'
version '1.1.0'

-- water.xml = eau d'origine du jeu (water_base.xml) + zones ajoutées (added.json), régénéré par /eau_ajouter
data_file 'WATER_FILE' 'water.xml'
files { 'water.xml' }

shared_script 'shared.lua'
client_script 'client.lua'
server_script 'server.lua'
