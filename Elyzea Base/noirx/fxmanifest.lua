fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'noirx'
author 'NOIR X'
description 'NOIR X — Underground Network (Standalone)'
version '0.3.0'

shared_scripts {
    'config.lua',
    'shared/utils.lua',
}

server_scripts {
    -- ponts (adaptateurs vers ton serveur)
    'bridge/server/database.lua',
    'bridge/server/identity.lua',
    'bridge/server/devtest.lua',
    'bridge/server/inventory.lua',
    'bridge/server/custom_inventory.lua',
    'bridge/server/economy.lua',
    'bridge/server/custom_economy.lua',
    'bridge/server/admin.lua',
    -- cœur
    'server/audit.lua',
    'server/core/players.lua',
    'server/core/locks.lua',
    'server/core/settings.lua',
    'server/core/boot.lua',
    'server/phone.lua',
    'server/core/rpc.lua',
    'server/core/payouts.lua',
    -- applications
    'server/apps/wallet.lua',
    'server/apps/ghostline.lua',
    'server/apps/darkchat.lua',
    'server/apps/ratline.lua',
    'server/apps/launder.lua',
    'server/apps/mercs.lua',
    -- administration
    'server/admin_api.lua',
    'server/admin_menu.lua',
}

client_scripts {
    'client/phone.lua',
    'client/rpc.lua',
    'client/mercs.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
    'html/js/apps/*.js',
    'html/assets/*.svg',
    'html/assets/icons/*.svg',
}

-- Base Elyzea : base de données, personnages et argent (elyzea_core), objets (elyzea_inventory).
-- admin_menu, elyzea_illegal et elyzea_police sont facultatifs (détectés à l'exécution).
dependencies { 'elyzea_core', 'elyzea_inventory' }
