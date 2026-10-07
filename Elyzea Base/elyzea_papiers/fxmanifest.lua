fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_papiers'
author 'Elyzea FA'
description 'Papiers Elyzea : carte d\'identité et permis de port d\'arme (PPA) délivré par les EMS'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
}
client_script 'client.lua'
server_script 'server.lua'

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/logo.png',
}

dependencies { 'elyzea_core', 'elyzea_inventory' }
