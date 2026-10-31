fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'builder_studio'
author 'Elyzea FA'
description 'Builder Studio : éditeur de construction et de mapping 3D en jeu (standalone, aucune base requise)'
version '1.0.0'

shared_scripts {
    'config.lua',
    'shared/mathx.lua',
    'shared/kits.lua',
    'shared/geometry.lua',
    'shared/catalog.lua',
    'shared/schema.lua',
    'shared/compose.lua',
}

client_scripts {
    'client/runtime.lua',
    'client/editor.lua',
    'client/main.lua',
}

server_scripts {
    'server/storage.lua',
    'server/projects.lua',
    'server/export.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/panels.js',
    'textures/custom/*.png',
}
