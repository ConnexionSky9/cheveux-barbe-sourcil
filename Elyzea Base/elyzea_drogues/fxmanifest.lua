fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_drogues'
author 'Elyzea FA'
description 'Drogues consommables : effets différents par drogue, champignons hallucinogènes (créatures visibles du seul consommateur), réglages dans l\'admin_menu, détection par le laboratoire EMS'
version '1.0.0'

dependencies { 'elyzea_core', 'elyzea_inventory' }

shared_scripts {
    'config.lua',
    'shared/rules.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua',
}

client_scripts {
    'client/effects.lua',
    'client/trip.lua',
}
