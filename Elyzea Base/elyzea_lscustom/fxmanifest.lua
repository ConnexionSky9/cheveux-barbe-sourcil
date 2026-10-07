fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_lscustom'
description 'Métier LsCustom complet (Qbox) : atelier, personnalisation, réparation, factures. Gestion dans admin_menu > Métiers > LsCustom'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/camera.lua',
    'client/neon.lua',
    'client/mods.lua',
    'client/work.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/work.lua',
    'server/admin.lua',
}

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/logo.png',
}

dependencies {
    'qbx_core',
    'ox_lib',
    'oxmysql',
}
