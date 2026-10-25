fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'server_shop'
author 'Elyzea'
description 'Boutique Elyzea en jeu : catalogue partagé avec le site, achats via Tebex, livraison automatique (ESX ou elyzea_core)'
version '1.0.0'

shared_script 'config.lua'

server_scripts {
    'server/db.lua',
    'server/api.lua',
    'server/adapters/elyzea.lua',
    'server/adapters/esx.lua',
    'server/rewards.lua',
    'server/main.lua',
}

client_script 'client/main.lua'

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/theme.css',
    'html/app.css',
    'html/app.js',
    'html/logo.webp',
}
