fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_fuel'
author 'Elyzea FA'
description 'Essence Elyzea : pistolet de la pompe, clic droit pour remplir, débordement au sol, écran de pompe, consommation selon le régime, panne sèche, stations dans admin_menu'
version '2.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
}
client_scripts {
    'client/main.lua',
    'client/pump.lua',
}
server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/brand.css',
    'html/brand.js',
}

dependencies { 'elyzea_core' }
