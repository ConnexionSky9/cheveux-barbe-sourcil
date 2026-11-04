fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_manutention'
author 'Elyzea'
description 'Intérim : manutentionnaire (cartons, palette de 20, Fenwick, livraison) - en plus du métier principal, tout se règle dans admin_menu'
version '1.0.0'

shared_scripts {
    'config.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua',
    'server/admin.lua',
}

client_scripts {
    '@elyzea_core/lib/clothing.lua',
    'client/main.lua',
    'client/forklift.lua',
    'client/admin.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/brand.css',
}

dependencies {
    'elyzea_core',
    '/onesync',
}
