fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_fourriere'
author 'Elyzea FA'
description 'Fourrières terrestre, aérienne et maritime : PNJ placés avec admin_menu, paiement dollars / pesos, réparation persistante des véhicules détruits'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
}
client_scripts { 'client/main.lua' }
server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'html/index.html'
files {
    'html/brand.css', 'html/index.html', 'html/style.css', 'html/app.js' }

dependencies { 'elyzea_core', 'elyzea_garage' }
