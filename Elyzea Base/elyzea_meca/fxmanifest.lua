fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_meca'
author 'Elyzea FA'
description 'Métier Mécano Elyzea : réparations ALT, points d\'atelier, catalogue et tarifs, devis et factures, CarPlay vendu (elyzea_aura), dépannage, tablette (direction, finance, paie au taux horaire)'
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
    'server/catalog.lua',
    'server/vehicles.lua',
    'server/repair.lua',
    'server/workshop.lua',
    'server/tow.lua',
    'server/direction.lua',
    'server/garage.lua',
    'server/api.lua',
}

client_scripts {
    'client/main.lua',
    'client/alt.lua',
    'client/tow.lua',
    'client/quotes.lua',
    'client/workshop.lua',
    'client/f6.lua',
    'client/tablet.lua',
    'client/garage.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/tablet.js',
    'html/map.js',
    'html/img/*',
}

dependencies { 'elyzea_core' }
