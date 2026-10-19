fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_famille'
author 'Elyzea FA'
description 'Famille Elyzea : moment intime avec consentement, contraception, conception, test, suivi, symptômes et fin de grossesse (accouchement EMS), ventre'
version '0.7.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config/config.lua',
    'locales/fr.lua',
    'shared/regles.lua',
    'grossesse/shared/ventre.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/base.lua',
    'server/reglages.lua',
    'moment_intime/server/consentement.lua',
    'contraception/server/contraception.lua',
    'grossesse/server/conception.lua',
    'moment_intime/server/intimite.lua',
    'grossesse/server/grossesse.lua',
    'grossesse/server/suivi.lua',
    'server/staff.lua',
}

client_scripts {
    '@elyzea_core/lib/clothing.lua',
    'moment_intime/client/intimite.lua',
    'client/main.lua',
    'grossesse/client/grossesse.lua',
    'grossesse/client/ventre.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'sql/install.sql',
}

dependencies { 'elyzea_core', 'elyzea_inventory' }
