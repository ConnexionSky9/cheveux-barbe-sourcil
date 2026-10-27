fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_loisirs'
author 'Elyzea FA'
description 'Loisirs multijoueurs : bowling (10 frames officielles), billard 8-ball, golf en stroke play. Physique calculée par le serveur, rejouée à l\'identique chez tous les joueurs. Pistes, tables et parcours posés depuis le menu admin (onglet Loisirs).'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
    'shared/utils.lua',
    'shared/bowling.lua',
    'shared/billiards.lua',
    'shared/golf.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua',
    'server/sessions.lua',
    'server/bowling.lua',
    'server/billiards.lua',
    'server/golf.lua',
}

client_scripts {
    'client/main.lua',
    'client/anim.lua',
    'client/bowling.lua',
    'client/billiards.lua',
    'client/golf.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies { 'elyzea_core' }
