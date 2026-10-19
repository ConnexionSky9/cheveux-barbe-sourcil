fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'blackphone'
author 'Elyzea FA'
description 'BLACKPHONE : téléphone noir utilisable depuis l\'inventaire (applications : Réglages, À propos, Grossesse)'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
}
server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua',
}
client_scripts { 'client/main.lua' }

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
    'html/js/apps/*.js',
    'html/assets/*.png',
    'html/assets/*.svg',
}

dependencies { 'elyzea_core', 'elyzea_inventory' }
