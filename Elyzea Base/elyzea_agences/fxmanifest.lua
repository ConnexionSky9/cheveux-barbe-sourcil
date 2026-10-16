fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_agences'
author 'Elyzea FA'
description 'Agences des métiers : plusieurs polices, EMS, garages mécano et agences Dynasty 8 (métier, grades, compte, téléphone de service, zone d\'alerte dessinée sur la carte ou en jeu)'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
    'shared/zone.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/img/map.jpg',
}

dependencies { 'elyzea_core' }
