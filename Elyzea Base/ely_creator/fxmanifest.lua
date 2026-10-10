fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ely_creator'
description 'Création de personnage complète (identité, hérédité, visage, pilosité, maquillage, vêtements)'
version '1.0.0'

shared_script 'config.lua'

client_scripts {
    '@elyzea_core/lib/clothing.lua',   -- vêtements de packs : gardés juste même si on ajoute / retire des packs
    'client/main.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/logo.jpg'
}

dependency 'elyzea_core'
