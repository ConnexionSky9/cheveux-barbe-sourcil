fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_hud'
author 'Elyzea'
description 'HUD Elyzea : nom, vie, bouclier, faim, soif, voix, mini-carte et compteur de vitesse en véhicule'
version '1.0.0'

ui_page 'html/index.html'

client_scripts {
    'config.lua',
    'client.lua'
}

files {
    'html/index.html',
    'minimap/radarmask.png',
}
