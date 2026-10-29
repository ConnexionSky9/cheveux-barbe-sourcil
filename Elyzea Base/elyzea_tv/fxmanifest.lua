fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_tv'
author 'Elyzea FA'
description 'Télévisions fonctionnelles : vidéos YouTube (image + son) sur les télés à écran plat (ALT › Télécommande) et sur des écrans posés n\'importe où, à n\'importe quelle taille, depuis le menu admin (onglet Écrans / TV).'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
    'shared/youtube.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
    'client/render.lua',
    'client/remote.lua',
    'client/editor.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/player.html',
}

dependencies { 'elyzea_core' }
