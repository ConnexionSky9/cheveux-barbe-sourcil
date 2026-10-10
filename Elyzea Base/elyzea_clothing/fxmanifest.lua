fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_clothing'
author 'Elyzea FA'
description 'Boutique de vêtements Elyzea : essayage en direct, panier, vêtements en objets, packs de vêtements détectés automatiquement'
version '3.0.0'

dependencies { 'elyzea_core', 'elyzea_inventory' }

shared_scripts {
    'config.lua',
    'shared/data.lua',
}

client_scripts {
    '@elyzea_core/lib/clothing.lua',
    'client/catalog.lua',
    'client/items.lua',
    'client/shop.lua',
}

server_scripts {
    'server/packs.lua',
    'server/items.lua',
    'server/shop.lua',
}

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/logo.png',
    'html/images/**/*',
}
