fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pvp_arena'
author 'Elyzea FA'
description 'Arène PvP compétitive : lobbies, équipes, mises et paris, manches, instance isolée, armes prêtées, retour au RP.'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
    'locales/*.lua',
    'shared/rules.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/core.lua',
    'server/lobby.lua',
    'server/match.lua',
    'server/admin.lua',
}

client_scripts {
    'client/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/lang.js',
}

dependencies { 'elyzea_core', 'elyzea_inventory', 'admin_menu' }
