fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_jobs'
author 'Elyzea FA'
description 'Socle commun des métiers : grades et accès, recrutement par proximité, finances, journal, menu ALT, pages Équipe / Patron des tablettes'
version '1.0.0'

dependency 'elyzea_core'

shared_script 'config.lua'

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua',
    'server/hr.lua',
    'server/finance.lua',
    'server/api.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/ejobs.js',
    'html/ejobs.css',
    'client/bridge.lua',
}
