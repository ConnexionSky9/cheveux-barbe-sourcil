fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_inventory'
author 'ELYZEA FA'
description 'Inventaire de la base Elyzea : objets, armes, coffres, boutiques, fouille, objets au sol'
version '4.0.0'

dependency 'elyzea_core'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
    'shared/items.lua',
    'shared/utils.lua',
    'shared/import.lua',
}

client_scripts {
    'client/camera.lua',
    'client/drops.lua',
    'client/main.lua',
    'client/use.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua',
    'server/weapons.lua',
    'server/usables.lua',
    'server/migrate.lua',
}

files {
    'data/items.lua',
    'data/weapons.lua',
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'html/img/*.png',
    'html/img/*.webp',
}
