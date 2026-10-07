fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_clothing'
author 'Elyzea FA'
description 'Boutique de vêtements Elyzea (catégories, essayage en direct, panier) - ouverte depuis un PNJ du menu admin'
version '2.0.0'

dependencies { 'elyzea_core', 'elyzea_inventory', 'ely_creator' }

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/logo.png',
    'html/images/**/*',
}
