fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_drogues'
author 'Elyzea FA'
description 'Système de drogues : filières de fabrication (cannabis 4 variétés, cocaïne, crack, méth, ecstasy, opiacés, kétamine, champignons), culture du cannabis, consommation et effets, vente, gestion dans l\'admin_menu, interactions ALT (elyzea_police)'
version '2.1.0'

dependencies { 'elyzea_core', 'elyzea_inventory' }

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
    'config/varieties.lua',
    'config/culture.lua',
    'config/stations.lua',
    'config/cakes.lua',     -- gâteaux aux champignons : tailles, quantités, cuisson
    'config/recipes.lua',
    'config/harvest.lua',
    'config/products.lua',
    'config/economy.lua',
    'config/minigames.lua',
    'shared/rules.lua',
    'shared/steps.lua',
    'shared/growth.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/core.lua',
    'server/crafting.lua',
    'server/culture.lua',
    'server/sale.lua',
    'server/main.lua',
    'server/admin.lua',
}

client_scripts {
    'client/scene.lua',
    'client/steps.lua',
    'client/effects.lua',
    'client/trip.lua',
    'client/consume.lua',
    'client/world.lua',
    'client/placement.lua',
    'client/alt.lua',
}

ui_page 'html/index.html'
files { 'html/index.html', 'html/mg.css', 'html/mg.js', 'html/mg_games1.js', 'html/mg_games2.js', 'html/mg_games3.js' }
