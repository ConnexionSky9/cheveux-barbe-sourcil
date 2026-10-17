fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rp_animations'
author 'Elyzea FA'
description 'Danses, slows et animations romantiques en solo et en duo, avec invitations et consentement'
version '1.0.0'

shared_scripts {
    'config.lua',
    'shared/catalog.lua',
}

server_scripts {
    'server/security.lua',
    'server/sessions.lua',
    'server/invitations.lua',
    'server/main.lua',
}

client_scripts {
    'client/anim.lua',
    'client/positioning.lua',
    'client/session.lua',
    'client/menu.lua',
    'client/calibrate.lua',
}

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

-- Animations personnalisées : aucun fichier .ycd n'est fourni pour l'instant.
-- Quand une animation est produite, place ses fichiers dans stream/ (voir docs/ANIMATIONS_PERSONNALISEES.md).
