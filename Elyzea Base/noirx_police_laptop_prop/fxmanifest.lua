fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'noirx_police_laptop_prop'
author 'NOIR X / Elyzea'
description 'PC Police posé sur la map (éditeur staff › Props › PC Police), ouverture avec E'
version '0.3.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
}
server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua' }

ui_page 'html/index.html'
files { 'html/index.html', 'html/style.css', 'html/app.js' }

-- Les PC sont des props de l'éditeur d'admin_menu (rôle « police_pc »), l'accès est vérifié par elyzea_police.
dependencies { 'elyzea_core', 'admin_menu', 'elyzea_police' }
