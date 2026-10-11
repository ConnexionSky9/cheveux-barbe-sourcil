fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_fuel'
author 'Elyzea FA'
description 'Essence Elyzea : consommation selon le régime moteur, panne sèche à 0 %, stations-service réglées dans admin_menu › Stations essence'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
}
client_script 'client/main.lua'
server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua',
}

dependencies { 'elyzea_core' }
