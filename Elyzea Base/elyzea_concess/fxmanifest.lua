fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_concess'
author 'Elyzea FA'
description 'Concessionnaire automobile Elyzea multi-concessions : catalogue global (staff), concessions indépendantes (catégories, modèles, prix), catalogue client, exposition, vente, livraison, clés, F6, tablette, finance, personnel'
version '2.0.0'

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
    'server/direction.lua',
    'server/catalog.lua',
    'server/admin.lua',
    'server/display.lua',
    'server/sales.lua',
    'server/phone.lua',
    'server/api.lua',
}

client_scripts {
    'client/main.lua',
    'client/points.lua',
    'client/catalog.lua',
    'client/display.lua',
    'client/f6.lua',
    'client/tablet.lua',
    'client/phone.lua',
    'client/admin.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/catalog.js',
    'html/tablet.js',
    'html/admin.js',
}

dependencies { 'elyzea_core' }
