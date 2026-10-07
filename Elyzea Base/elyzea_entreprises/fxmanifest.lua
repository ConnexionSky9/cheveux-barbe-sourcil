fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_entreprises'
author 'Elyzea FA'
description 'Entreprises Elyzea : Taxi, Burger Shot, Boîte de nuit (tablette F6, factures, cuisine / bar, fournisseur, compteur, courses, entrée). Gestion dans admin_menu › Métiers'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/taxi.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua',
    'server/work.lua',
    'server/taxi.lua',
    'server/admin.lua',
}

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/logo.png',
}

dependencies { 'elyzea_core', 'elyzea_inventory' }
