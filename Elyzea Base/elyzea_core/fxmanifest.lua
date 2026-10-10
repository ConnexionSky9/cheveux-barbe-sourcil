fx_version 'cerulean'
game 'gta5'
lua54 'yes'
node_version '22'

name 'elyzea_core'
author 'Elyzea FA'
description 'Base Elyzea : personnages, argent, métiers, sociétés, clés, base de données, notifications'
version '1.0.0'

shared_scripts {
    'config.lua',
    'shared/utils.lua',
    'shared/groups.lua',
}

server_scripts {
    'server/db/database.js',
    'lib/MySQL.lua',
    'server/install.lua',
    'server/groups.lua',
    'server/players.lua',
    'server/society.lua',
    'server/keys.lua',
    'server/loops.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
    'client/ui.lua',
    'client/vehicle.lua',
    'client/keys.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'lib/ely.lua',
    'lib/clothing.lua',   -- vêtements par collection (packs) : '@elyzea_core/lib/clothing.lua'
}

