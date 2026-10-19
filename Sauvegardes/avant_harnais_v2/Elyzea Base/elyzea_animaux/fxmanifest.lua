fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_animaux'
author 'Elyzea FA'
description 'Elyzea Animaux : animaux de compagnie achetés auprès de PNJ (animalerie, exotiques), pelages réels, harnais et laisse visibles, besoins sauvegardés, ferme indépendante de Cayo Perico. Administration : admin_menu › Gestion des animaux.'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
    'shared/utils.lua',
}

client_scripts {
    'client/main.lua',
    'client/scan.lua',
    'client/vendors.lua',
    'client/pets.lua',
    'client/gear.lua',
    'client/farm.lua',
    'client/alt.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/settings.lua',
    'server/main.lua',
    'server/pets.lua',
    'server/shop.lua',
    'server/farm.lua',
    'server/admin.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies { 'elyzea_core', 'elyzea_inventory' }
