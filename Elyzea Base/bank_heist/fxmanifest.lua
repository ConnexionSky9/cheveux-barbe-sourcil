fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'bank_heist'
author 'Elyzea FA'
description 'Braquage de banque : marchand de matériel, menace de l\'employé, piratage (5 mini-jeux, 3 tentatives par ordinateur), C4, collecte des billets dans le sac de la bijouterie, dépôt, alerte police, onglet admin_menu'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
    'shared/util.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'adapters/notifications.lua',
    'adapters/permissions.lua',
    'adapters/inventory.lua',
    'adapters/money.lua',
    'adapters/police.lua',
    'adapters/bag.lua',
    'server/main.lua',
    'server/settings.lua',
    'server/laptop.lua',
    'server/shop.lua',
    'server/heist.lua',
    'server/hack.lua',
    'server/loot.lua',
    'server/admin.lua',
}

client_scripts {
    'client/main.lua',
    'client/peds.lua',
    'client/bank.lua',
    'client/hack.lua',
    'client/loot.lua',
    'client/alt.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/games.js',
    'html/img/*.png',
}

-- jewelry_heist : système de sac partagé (porter, poser avec E, ramasser avec ALT)
dependencies { 'elyzea_core', 'elyzea_inventory', 'jewelry_heist' }
