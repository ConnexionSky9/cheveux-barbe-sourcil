fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_jobphone'
author 'Elyzea FA'
description 'Téléphone de service des métiers (police, EMS, mécano, Dynasty 8, concession) : service, annuaire, messages, appels pma-voice, carte des collègues, alertes, temps de service, tablette'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
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
}

dependencies { 'elyzea_core' }
