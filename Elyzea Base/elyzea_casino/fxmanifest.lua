fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_casino'
author 'Elyzea FA'
description 'Casino : blackjack et roulette (4 places), roues de la fortune personnalisables, guichet de jetons. Placement par l\'éditeur de map (PNJ rôle Casino), réglages dans le menu admin.'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
    'shared/rules.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/core.lua',
    'server/seats.lua',
    'server/cashier.lua',
    'server/blackjack.lua',
    'server/roulette.lua',
    'server/wheel.lua',
    'server/admin.lua',
}

client_scripts {
    'client/main.lua',
    'client/blackjack.lua',
    'client/roulette.lua',
    'client/wheel.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies { 'elyzea_core', 'elyzea_inventory', 'admin_menu' }
