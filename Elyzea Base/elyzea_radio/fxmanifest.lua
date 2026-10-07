fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_radio'
author 'Elyzea FA'
description 'Radio Elyzea (remplace mm_radio) : objet « radio », fréquences, canaux réservés aux métiers, batterie, brouilleur. Basée sur pma-voice.'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
}
client_script 'client.lua'
server_script 'server.lua'

ui_page 'html/index.html'
files { 'html/index.html', 'html/logo.png' }

dependencies { 'elyzea_core', 'elyzea_inventory', 'pma-voice' }
