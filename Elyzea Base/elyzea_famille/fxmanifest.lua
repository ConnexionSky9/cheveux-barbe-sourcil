fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_famille'
author 'Elyzea FA'
description 'Famille Elyzea : moment intime avec consentement, contraception, conception, test, suivi, symptômes et fin de grossesse (accouchement EMS), ventre'
version '0.5.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
    'shared/regles.lua',
    'shared/ventre.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/base.lua',
    'server/reglages.lua',
    'server/consentement.lua',
    'server/contraception.lua',
    'server/conception.lua',
    'server/intimite.lua',
    'server/grossesse.lua',
    'server/suivi.lua',
    'server/staff.lua',
}

client_scripts {
    '@elyzea_core/lib/clothing.lua',
    'client/intimite.lua',
    'client/main.lua',
    'client/grossesse.lua',
    'client/ventre.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'sql/install.sql',
}

dependencies { 'elyzea_core', 'elyzea_inventory' }
