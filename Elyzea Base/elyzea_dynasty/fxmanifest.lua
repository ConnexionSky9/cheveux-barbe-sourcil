fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_dynasty'
author 'Elyzea FA'
description 'Métier Dynasty 8 Elyzea : biens immobiliers (appartements, maisons, villas, garages), intérieurs, vente et location, accès, sonnette, visites, coffre, décoration, garages persistants, tablette (carte, finance, personnel)'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
    'shared/perms.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua',
    'server/service.lua',
    'server/finance.lua',
    'server/commission.lua',
    'server/properties.lua',
    'server/access.lua',
    'server/contracts.lua',
    'server/garage.lua',
    'server/deco.lua',
    'server/direction.lua',
    'server/api.lua',
}

client_scripts {
    'client/main.lua',
    'client/points.lua',
    'client/interior.lua',
    'client/deco.lua',
    'client/f6.lua',
    'client/tablet.lua',
    'client/admin.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/tablet.js',
    'html/admin.js',
    'html/map.js',
    'html/img/*',
}

dependencies { 'elyzea_core' }
