fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_famille'
author 'Elyzea FA'
description 'Famille Elyzea : moment intime avec consentement, contraception, conception (grossesse, enfants, crèche : modules suivants)'
version '0.1.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
    'shared/regles.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/base.lua',
    'server/consentement.lua',
    'server/contraception.lua',
    'server/conception.lua',
    'server/intimite.lua',
    'server/staff.lua',
}

client_scripts {
    'client/intimite.lua',
    'client/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'sql/install.sql',
}

dependencies { 'elyzea_core', 'elyzea_inventory' }
