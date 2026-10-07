fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'elyzea_ems'
description 'Elyzea - Métier EMS : tablette des employés, menu Alt, soins'

shared_scripts { 'config.lua', 'shared.lua' }
client_script 'client.lua'
server_scripts { '@elyzea_core/lib/MySQL.lua', 'server.lua' }

ui_page 'html/index.html'
files { 'html/index.html' }
