fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_clothing_photos'
author 'Elyzea FA'
description 'Studio photo : capture les vraies images des vêtements GTA/addons pour elyzea_clothing'
version '1.0.0'

dependencies { 'screenshot-basic', 'elyzea_clothing' }

-- Réutilise les rayons et les valeurs « rien » de la boutique
shared_scripts { '@elyzea_clothing/config.lua', 'config.lua' }
client_script 'client.lua'
server_script 'server.lua'

ui_page 'html/index.html'
files { 'html/index.html' }
