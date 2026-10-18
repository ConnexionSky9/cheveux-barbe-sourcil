fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_tags'
author 'Elyzea FA'
description 'Elyzea Tags : graffitis peints sur les murs des quartiers (bombe de peinture), sauvegardés après redémarrage, nettoyables (solvant) et modérés par le staff (admin_menu › Tags).'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
    'shared/filter.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/tag.html',
}

dependencies { 'elyzea_core', 'elyzea_inventory' }
