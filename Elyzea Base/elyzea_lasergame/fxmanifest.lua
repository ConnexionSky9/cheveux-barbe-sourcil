fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_lasergame'
author 'Elyzea FA'
description 'LaserGame ElyzeaFA : PVP Arena (1v1 à 6v6, mises, rangs) et mode Zombie (1 à 4 joueurs), armes laser, 5 cartes, classements, staff.'
version '1.0.0'

shared_scripts {
    'shared/constants.lua',
    'config.lua',
    'shared/config.lua',
    'shared/utils.lua',
    'shared/rpc.lua',
}

server_scripts {
    -- Base Elyzea. Avec ESX / QBCore : remplace par '@oxmysql/lib/MySQL.lua' (voir docs/installation.md)
    '@elyzea_core/lib/MySQL.lua',
    'server/bridge.lua',
    'server/logs.lua',
    'server/security.lua',
    'server/database.lua',
    'server/players.lua',
    'server/settings.lua',
    'server/maps.lua',
    'server/economy.lua',
    'server/restoration.lua',
    'server/games.lua',
    'server/lobby.lua',
    'server/combat.lua',
    'server/ranking.lua',
    'server/pvp.lua',
    'server/zombie.lua',
    'server/admin.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
    'client/interface.lua',
    'client/npc.lua',
    'client/maps.lua',
    'client/laser.lua',
    'client/weapons.lua',
    'client/restoration.lua',
    'client/pvp.lua',
    'client/spectator.lua',
    'client/zombie.lua',
    'client/doors.lua',
    'client/perks.lua',
    'client/admin.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/brand.css',
    'html/brand.js',
    'html/assets/*.svg',
    'html/assets/*.png',
    'html/assets/*.jpg',
    'html/assets/*.webp',
    'html/images/*.png',
    'html/images/*.svg',
    'html/images/maps/*.png',
    'html/sounds/*.ogg',
    'html/ranks/*.svg',
    'html/ranks/*.png',
    'maps/*/map.json',
}

dependencies {
    '/onesync',
}
