fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_club'
author 'Elyzea FA'
description 'Boîtes de nuit Elyzea (plusieurs établissements) : métier par boîte, grades et permissions, service, paie, commissions, bar (carte, prix, stock, encaissement), entrée payante, bracelets, liste VIP, liste noire, annonces, coffre, enceintes posées par la boîte et playlist YouTube synchronisée, F6, tablette, administration staff'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
    'shared/perms.lua',
    'shared/youtube.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua',
    'server/service.lua',
    'server/finance.lua',
    'server/commission.lua',
    'server/direction.lua',
    'server/bar.lua',
    'server/door.lua',
    'server/music.lua',
    'server/club.lua',
    'server/admin.lua',
    'server/phone.lua',
    'server/api.lua',
}

client_scripts {
    'client/main.lua',
    'client/points.lua',
    'client/bar.lua',
    'client/door.lua',
    'client/music.lua',
    'client/f6.lua',
    'client/tablet.lua',
    'client/phone.lua',
    'client/admin.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/club.js',
    'html/music.js',
    'html/tablet.js',
    'html/admin.js',
}

dependencies { 'elyzea_core' }
