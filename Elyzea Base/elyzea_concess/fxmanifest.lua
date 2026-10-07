fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_concess'
description 'Concessionnaire automobile complet (base Elyzea) : tablette employé et direction, catalogue, ventes, essais, garage. Structure du métier dans admin_menu > Métiers > Concession'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/tablet.lua',
    'client/garage.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua',
    'server/tablet.lua',
    'server/sales.lua',
    'server/showroom.lua',
    'server/garage.lua',
    'server/admin.lua',
}

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/logo.png',
}

dependencies {
    'elyzea_core',
    'elyzea_inventory',
}
