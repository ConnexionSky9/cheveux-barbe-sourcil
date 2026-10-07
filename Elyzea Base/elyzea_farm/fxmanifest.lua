fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_farm'
author 'Elyzea FA'
description 'Métiers de farm Elyzea (bûcheron…) : PNJ de l\'éditeur de map, zones de travail, tenue, revente. Réglages dans admin_menu › Métiers'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
}
client_script 'client.lua'
server_scripts {
    '@elyzea_core/lib/MySQL.lua',
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
