fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_clothing'
author 'Elyzea FA'
description 'Boutique de vêtements Elyzea : essayage en direct, panier, vêtements en objets, packs de vêtements détectés automatiquement'
version '3.1.0'

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
    'client/outfits.lua',
    'client/knockoff.lua',   -- pousser, coups : chapeau et lunettes qui tombent ; écraser des lunettes
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',   -- tenues enregistrées (tables elyzea_outfits / elyzea_outfit_categories)
    'server/packs.lua',
    'server/items.lua',
    'server/hidden.lua',   -- vêtements cachés par le staff (table elyzea_clothing_hidden)
    'server/shop.lua',
    'server/outfits.lua',
    'server/knockoff.lua',
}

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/logo.png',
    'html/images/**/*',
}
