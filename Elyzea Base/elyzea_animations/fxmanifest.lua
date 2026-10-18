fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_animations'
description 'Menu des animations Elyzea (K) : animations, danses solo, lentes, en duo et en groupe'

ui_page 'html/index.html'
files { 'html/index.html' }

shared_scripts { 'danses/config.lua', 'danses/catalog.lua' }

client_scripts {
    'danses/client/anim.lua',
    'danses/client/positioning.lua',
    'danses/client/session.lua',
    'danses/client/calibrate.lua',
    'anim_data.lua',
    'client.lua',
}

server_scripts {
    'danses/server/security.lua',
    'danses/server/sessions.lua',
    'danses/server/invitations.lua',
    'danses/server/main.lua',
    'shared_emotes.lua',
    'server.lua',
}
