fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_labs'
author 'Elyzea FA'
description 'Laboratoires illégaux : propriété des groupes (elyzea_illegal), intérieur instancié, code et autorisations, équipements achetables et plaçables (cercle bleu), fabrication, niveaux et expérience, coffre, tablette F5, attaques et capture. Administration : admin_menu › Laboratoires.'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
    'shared/sha256.lua',
    'shared/rules.lua',
    -- étapes immersives (mini-jeux et scènes) communes avec elyzea_drogues
    '@elyzea_drogues/config/minigames.lua',
    '@elyzea_drogues/shared/steps.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua',
    'server/permissions.lua',
    'server/ownership.lua',
    'server/access.lua',
    'server/equipment.lua',
    'server/production.lua',
    'server/storage.lua',
    'server/upgrades.lua',
    'server/raids.lua',
    'server/tablet.lua',
    'server/admin.lua',
}

client_scripts {
    'client/main.lua',
    'client/entrance.lua',
    'client/editor.lua',
    'client/production.lua',
    'client/tablet.lua',
    'client/raids.lua',
}

ui_page 'web/index.html'
files { 'web/index.html', 'web/style.css', 'web/app.js' }

dependencies { 'elyzea_core', 'elyzea_inventory', 'elyzea_illegal', 'elyzea_drogues' }
