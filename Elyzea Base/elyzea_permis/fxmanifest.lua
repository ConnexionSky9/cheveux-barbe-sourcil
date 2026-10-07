fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_permis'
description 'Auto-école Elyzea : code de la route, examen de conduite, permis voiture / moto / camion (objet à montrer)'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}
client_script 'client.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/logo.png',
}

dependencies { 'qbx_core', 'ox_lib', 'oxmysql' }
