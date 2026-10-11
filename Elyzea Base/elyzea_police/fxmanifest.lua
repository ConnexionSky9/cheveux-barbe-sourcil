fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_police'
description 'Métier Police complet (base Elyzea) : tablette, dispatch, interactions ALT, amendes, prison, casiers, retrait du PPA'
version '1.0.0'

shared_script 'config.lua'

client_scripts {
    '@elyzea_jobs/client/bridge.lua',
    'client/main.lua',
    'client/dispatch.lua',
    'client/interactions.lua',
    'client/alt.lua',
    'client/jail.lua',
    'client/points.lua',
    'client/tablet.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua',
    'server/dispatch.lua',
    'server/interactions.lua',
    'server/mdt.lua',
    'server/ppa.lua',
    'server/staff.lua',
}

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'elyzea_core',
    'elyzea_jobs',
    'elyzea_inventory',
}
