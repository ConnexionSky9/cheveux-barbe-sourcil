fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_animations'
description 'Menu des animations Elyzea (moteur intégré) + interactions ALT (copier une animation, proposer une animation)'

ui_page 'html/index.html'
files {
    'html/brand.css', 'html/index.html', 'html/style.css', 'html/app.js', 'html/emotes.js' }

-- Données chargées des deux côtés : le serveur vérifie les animations demandées
shared_scripts { 'anim_data.lua', 'shared_emotes.lua', 'interactions.lua' }
client_scripts { 'client_engine.lua', 'client.lua', 'client_interactions.lua' }
server_scripts { 'server.lua' }
