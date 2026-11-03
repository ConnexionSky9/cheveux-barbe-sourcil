fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_change'
description 'Elyzea - Bureau de change : argent liquide <-> pesos (PNJ placé avec admin_menu)'

ui_page 'html/index.html'
files {
    'html/brand.css', 'html/index.html', 'html/pesos.png' }

shared_scripts { 'config.lua' }
client_scripts { 'client.lua' }
server_scripts { 'server.lua', 'server_payment.lua' }

dependencies { 'elyzea_core', 'elyzea_inventory' }
