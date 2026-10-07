fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_patron'
author 'Elyzea FA'
description 'Menu patron Elyzea : recruter, changer le grade, renvoyer ses employés (tous les métiers, grade patron)'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
}
client_script 'client.lua'
server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server.lua',
}

ui_page 'html/index.html'
files { 'html/index.html', 'html/logo.png' }

dependencies { 'elyzea_core' }
