fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'bank_heist'
author 'Elyzea FA'
description 'Braquage de banque 2.1 : indic, marchand, banquier (guichet et braquage), alarme, décryptage ou C4 de la porte, butin au choix (chariots, liasses, lingots, coffres à la perceuse), sac, HUD, alerte police, onglet admin_menu'
version '2.1.0'

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
    'server/main.lua',
    'adapters/bag.lua',          -- après server/main.lua (utilise BHS)
    'server/settings.lua',
    'server/laptop.lua',
    'server/shop.lua',
    'server/heist.lua',
    'server/hack.lua',
    'server/loot.lua',
    'server/alarm.lua',
    'server/informant.lua',
    'server/banking.lua',
    'server/admin.lua',
}

client_scripts {
    'client/main.lua',
    'client/peds.lua',
    'client/bank.lua',
    'client/scenes.lua',
    'client/hack.lua',
    'client/loot.lua',
    'client/bags.lua',
    'client/alarm.lua',
    'client/banking.lua',
    'client/alt.lua',
}

ui_page 'html/index.html'

files {
    'html/brand.css',
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/games.js',
    'html/brand.js',
    'html/sounds.js',
    'html/img/*.png',
}

-- Sac de billets : système propre à la banque (adapters/bag.lua + client/bags.lua)
dependencies { 'elyzea_core', 'elyzea_inventory' }
