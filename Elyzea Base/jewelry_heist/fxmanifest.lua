fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'jewelry_heist'
author 'Elyzea FA'
description 'Braquage de bijouterie : PNJ bijoutiers, braquage, sac transportable (porter, déposer, ouvrir), 5 pierres précieuses, PNJ racheteurs, alerte police, réglages complets dans admin_menu'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
    'locales/fr.lua',
    'locales/en.lua',
    'shared/util.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'adapters/notifications.lua',
    'adapters/permissions.lua',
    'adapters/inventory.lua',
    'adapters/money.lua',
    'adapters/police.lua',
    'adapters/dispatch.lua',
    'server/main.lua',
    'server/settings.lua',
    'server/heist.lua',
    'server/bags.lua',
    'server/shops.lua',
    'server/admin.lua',
}

client_scripts {
    'client/main.lua',
    'client/peds.lua',
    'client/heist.lua',
    'client/bag.lua',
    'client/alt.lua',
    'client/police.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/img/*.png',
}

dependencies { 'elyzea_core', 'elyzea_inventory' }
