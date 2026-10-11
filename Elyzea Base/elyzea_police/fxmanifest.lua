fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_police'
description 'Métier Police complet (base Elyzea) : tablette, dispatch, interactions ALT, amendes, prison, casiers, PPA, police scientifique'
version '1.0.0'

shared_script 'config.lua'

client_scripts {
    '@elyzea_jobs/client/bridge.lua',
    'client/main.lua',
    'client/dispatch.lua',
    'client/interactions.lua',
    'client/alt.lua',
    'client/forensics.lua',
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
    'server/forensics.lua',
    'server/lab.lua',
    'server/staff.lua',
}

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/sci.js',
}

dependencies {
    'elyzea_core',
    'elyzea_jobs',
    'elyzea_inventory',
}
