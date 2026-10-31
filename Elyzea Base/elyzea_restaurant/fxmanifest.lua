fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_restaurant'
author 'Elyzea FA'
description 'Restaurants Elyzea (plusieurs établissements) : métier par restaurant, grades et permissions, service, paie, commissions, carte et prix, point de commande avec panier, commandes envoyées au personnel, appli « Commande » du téléphone de service, stations de cuisine avec mini-jeux validés par le serveur, sac de commande, remise au client, F6, tablette, administration staff'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
    'shared/perms.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'shared/games.lua',
    'server/main.lua',
    'server/service.lua',
    'server/finance.lua',
    'server/commission.lua',
    'server/direction.lua',
    'server/resto.lua',
    'server/orders.lua',
    'server/kitchen.lua',
    'server/bag.lua',
    'server/admin.lua',
    'server/phone.lua',
    'server/api.lua',
}

client_scripts {
    'client/main.lua',
    'client/points.lua',
    'client/order.lua',
    'client/kitchen.lua',
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
    'html/order.js',
    'html/kitchen.js',
    'html/tablet.js',
    'html/admin.js',
}

dependencies { 'elyzea_core', 'elyzea_inventory' }
