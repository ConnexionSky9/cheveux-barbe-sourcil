fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'blackphone'
author 'Elyzea FA'
description 'BLACKPHONE : terminal clandestin (Dark Chat, Ghostline, Dark Market, Contracts, BLACKBREACH) et PC portable police (Cyber Defense, contre-mesures)'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
    'shared/util.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/bridge.lua',
    'server/main.lua',
    'server/settings.lua',
    'server/profile.lua',
    'server/chat.lua',
    'server/claims.lua',
    'server/market.lua',
    'server/contracts.lua',
    'server/breach.lua',
    'server/police.lua',
    'server/admin.lua',
}

client_scripts {
    'client/main.lua',
    'client/police.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
    'html/assets/*.png',
    'html/assets/*.svg',
}

dependencies { 'elyzea_core', 'elyzea_inventory' }
