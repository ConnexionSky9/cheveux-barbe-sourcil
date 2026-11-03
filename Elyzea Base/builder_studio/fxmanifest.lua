fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'builder_studio'
author 'Elyzea FA'
description 'Builder Studio : éditeur de construction et de mapping 3D en jeu (aucune base requise ; permissions staff admin_menu ou ACE)'
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
    'server/textures.lua',
    'server/projects.lua',
    'server/export.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/brand.css',
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/panels.js',
    'html/tex.html',
    'textures/custom/*.png',
}
