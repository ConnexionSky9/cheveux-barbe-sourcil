fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_multichar'
description 'Elyzea FA - Intro + sélection de personnage (après le loading screen) - base Elyzea'
version '2.0.0'

shared_script 'config.lua'
client_script 'client.lua'
server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server.lua'
}

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/logo.webp'
}

dependencies {
    'elyzea_core',
    'ely_creator'
}
