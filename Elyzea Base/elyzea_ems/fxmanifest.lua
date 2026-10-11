fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'elyzea_ems'
description 'Elyzea - Métier EMS : tablette des employés (Équipe / Direction communes), soins via le menu ALT commun'

shared_scripts { 'config.lua', 'shared.lua' }
client_scripts { '@elyzea_jobs/client/bridge.lua', 'client.lua' }
server_scripts { '@elyzea_core/lib/MySQL.lua', 'server.lua' }

ui_page 'html/index.html'
files { 'html/index.html' }

dependencies { 'elyzea_core', 'elyzea_jobs' }
