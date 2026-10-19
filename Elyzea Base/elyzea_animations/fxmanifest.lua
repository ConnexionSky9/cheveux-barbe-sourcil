fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_animations'
description 'Menu des animations Elyzea + interactions ALT (copier une animation, proposer une animation)'

ui_page 'html/index.html'
files { 'html/index.html' }

-- Données chargées des deux côtés : le serveur vérifie les animations demandées
shared_scripts { 'anim_data.lua', 'shared_emotes.lua', 'interactions.lua' }
client_scripts { 'client.lua', 'client_interactions.lua' }
server_scripts { 'server.lua' }
