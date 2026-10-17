fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_police'
author 'Elyzea FA'
description 'Métier Police Elyzea : interactions ALT, menu F6, service, alertes (générales et agent), amendes, tablette (tableau de bord, rapports, carte, agents, direction, employés, grades et permissions)'
version '2.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
    'shared/perms.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua',
    'server/agencies.lua',
    'server/service.lua',
    'server/interactions.lua',
    'server/alerts.lua',
    'server/reports.lua',
    'server/direction.lua',
    'server/finance.lua',
    'server/commission.lua',
    'server/records.lua',
    'server/citizen.lua',
    'server/phone.lua',
    'server/api.lua',
}

client_scripts {
    'client/main.lua',
    'client/interactions.lua',
    'client/alt.lua',
    'client/citizen.lua',
    'client/alerts.lua',
    'client/f6.lua',
    'client/tablet.lua',
    'client/phone.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/tablet.js',
    'html/map.js',
    'html/img/*',      -- image facultative de la carte (html/img/map.jpg)
}

dependencies { 'elyzea_core' }
