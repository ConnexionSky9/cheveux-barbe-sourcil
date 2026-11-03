fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_pier'
author 'Elyzea FA'
description 'Parc d\'attractions de Del Perro : grande roue et montagnes russes ORIGINALES de GTA V, multijoueur synchronisé par le serveur, tickets dans elyzea_inventory.'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
    'shared/track.lua',
    'shared/ride.lua',
}

server_scripts {
    'server.lua',
    'server/wheel.lua',
    'server/coaster.lua',
}

client_scripts {
    'client.lua',
    'client/wheel.lua',
    'client/coaster.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/brand.css',
}

dependencies {
    '/onesync',
    'elyzea_core',
    'elyzea_inventory',
}
