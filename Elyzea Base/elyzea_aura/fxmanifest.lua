fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_aura'
author 'Elyzea'
description 'Elyzea Aura 5 - Téléphone complet pour FiveM (Elyzea / QBCore / ESX / Standalone)'
version '5.2.0'

shared_scripts {
    'config.lua',
    'config_elypick.lua',
    'config_elytok.lua',
    'config_elyfy.lua',
    'config_phones.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua',
    'server/elypick.lua',
    'server/elytok.lua',
    'server/elyfy.lua',
    'server/lasergame.lua',
    'server/maison.lua',
    'server/phones.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/brand.css',
    'html/brand.js',
    'html/cards.css',
    'html/cards.js',
    'html/js/*.js',
    'html/elypick.css',
    'html/elytok.css',
    'html/elyfy.css',
    'html/lasergame.css',
    'html/maison.css',
    'html/fold.css',
    'html/devices.css',
    'html/phoneshop.css'
}

dependencies {
    'elyzea_core'
}
