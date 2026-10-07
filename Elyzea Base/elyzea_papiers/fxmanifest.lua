fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_papiers'
author 'Elyzea FA'
description 'Papiers Elyzea : guichet du gouvernement (carte d\'identité, changement d\'identité) et PPA (test et remise par les EMS)'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
}
client_script 'client.lua'
server_scripts {
    'questions.lua',
    'server.lua',
}

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/logo.png',
}

dependencies { 'elyzea_core', 'elyzea_inventory' }
