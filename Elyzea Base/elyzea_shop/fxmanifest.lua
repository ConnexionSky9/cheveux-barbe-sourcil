fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_shop'
author 'Elyzea RP'
description 'Boutique Elyzea RP 100 % en jeu : catalogue NUI, paiements Tebex (connexion directe + intégration officielle FiveM), livraison automatique, Elyzea Coins'
version '1.0.0'

shared_script 'config.lua'

server_scripts {
    'server/db.lua',
    'server/framework.lua',
    'server/rewards.lua',
    'server/coins.lua',
    'server/tebex.lua',
    'server/tebex_api.lua',
    'server/images.lua',
    'server/main.lua',
    'server/admin.lua',
}

client_script 'client/main.lua'

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/assets/*.webp',
    'html/assets/products/*.webp',
}
