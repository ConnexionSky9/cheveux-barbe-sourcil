fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_meca'
author 'Elyzea FA'
description 'Métier Mécano Elyzea : réparations ALT, atelier (esthétique, performances, pneus DRIFT), devis payés, installation par mini-jeux, remise des clés, dépannage, tablette'
version '2.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
    'shared/perms.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua',
    'server/agencies.lua',
    'server/service.lua',
    'server/finance.lua',
    'server/commission.lua',
    'server/catalog.lua',
    'server/vehicles.lua',
    'server/repair.lua',
    'server/workshop.lua',
    'server/lift.lua',
    'server/tow.lua',
    'server/direction.lua',
    'server/garage.lua',
    'server/phone.lua',
    'server/api.lua',
}

client_scripts {
    'client/main.lua',
    'client/alt.lua',
    'client/tow.lua',
    'client/quotes.lua',
    'client/lift.lua',
    'client/install.lua',
    'client/workshop.lua',
    'client/f6.lua',
    'client/tablet.lua',
    'client/phone.lua',
    'client/garage.lua',
}

ui_page 'html/index.html'

files {
    'html/brand.css',
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/workshop.js',
    'html/minigames.js',
    'html/tablet.js',
    'html/map.js',
    'html/img/*',
}

dependencies { 'elyzea_core' }
