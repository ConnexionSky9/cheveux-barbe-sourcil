fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gofast'
author 'gofast'
description 'Missions Go Fast dynamiques : niveaux, risque, police, NUI. ESX / QBCore / Qbox / standalone.'
version '1.1.0'

-- OneSync est obligatoire : le véhicule de mission est créé côté serveur
dependencies {
    '/onesync',
}

shared_scripts {
    'config.lua',
    'shared/utils.lua',
}

client_scripts {
    'client/utils.lua',
    'client/vehicle.lua',
    'client/missions.lua',
    'client/objectives.lua',
    'client/main.lua',
}

server_scripts {
    'server/security.lua',
    'server/rewards.lua',
    'server/storage.lua',
    'server/contacts.lua',
    'server/main.lua',
    'server/admin.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
}
