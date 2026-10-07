fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_aura'
author 'Elyzea'
description 'Elyzea Aura 5 - Téléphone complet pour FiveM (Qbox / QBCore / ESX / Standalone)'
version '5.2.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/js/*.js'
}

dependencies {
    'oxmysql'
}
