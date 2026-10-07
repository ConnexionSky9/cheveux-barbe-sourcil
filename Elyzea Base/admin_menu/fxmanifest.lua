fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'admin_menu'
author 'Elyzea FA'
description 'Menu administrateur complet (base Elyzea) - noclip 3e personne, grades, permissions, sanctions, véhicules, météo'
version '1.10.0'

dependencies { 'elyzea_core', 'elyzea_inventory' }

shared_scripts {
    'config.lua',
    'barber_data.lua',
    'npc_area.lua',
}

client_scripts {
    'client/main.lua',
    'client/noclip.lua',
    'client/spectate.lua',
    'client/vehicles.lua',
    'client/world.lua',
    'client/wallhack.lua',
    'client/editor.lua',
    'client/revive.lua',
    'client/zones.lua',
    'client/doors.lua',
    'client/jail.lua',
    'client/transform.lua',
    'client/gofast.lua',
    'client/zombies.lua',
    'client/quick.lua',
    'client/ems.lua',
    'client/police.lua',
    'client/uniforms.lua',
    'client/minimap.lua',
    'client/mapicons.lua',
    'client/vehcustom.lua',
    'client/respawn.lua',
    'client/welcome.lua',
    'client/jobsmgr.lua',
    'client/barber.lua',
    'client/tattoo.lua',
    'client/market.lua',
    'client/gunshop.lua',
    'client/garage.lua',
    'client/drops.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'tattoo_data.lua',
    'server/storage.lua',
    'server/main.lua',
    'server/bridge.lua',
    'server/editor.lua',
    'server/gofast.lua',
    'server/zombies.lua',
    'server/zombies_loot.lua',
    'server/messages.lua',
    'server/ems.lua',
    'server/police.lua',
    'server/jobtools.lua',
    'server/lscustom.lua',
    'server/concess.lua',
    'server/permis.lua',
    'server/debts.lua',
    'server/respawn.lua',
    'server/welcome.lua',
    'server/wipe.lua',
    'server/jobsmgr.lua',
    'server/illegal.lua',
    'server/barber.lua',
    'server/tattoo.lua',
    'server/market.lua',
    'server/gunshop.lua',
    'server/map.lua',
    'server/drops.lua',
    'server/farm.lua',
    'server/entreprises.lua',
    'server/concessair.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/catalog.js',
    'html/gofast.js',
    'html/zombies.js',
    'html/quick.js',
    'html/ems.js',
    'html/police.js',
    'html/jobtools.js',
    'html/lscustom.js',
    'html/concess.js',
    'html/permis.js',
    'html/debts.js',
    'html/respawn.js',
    'html/welcome.js',
    'html/wipe.js',
    'html/jobsmgr.js',
    'html/illegal.js',
    'html/barber.js',
    'html/barber.css',
    'html/tattoo.js',
    'html/market.js',
    'html/market.css',
    'html/jobs.js',
    'html/map.js',
    'html/vehcustom.js',
    'html/stashes.js',
    'html/drops.js',
    'html/farm.js',
    'html/entreprises.js',
    'html/concessair.js',
    'html/logo.png',
}
