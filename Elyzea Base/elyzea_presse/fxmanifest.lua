fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_presse'
author 'Elyzea FA'
description 'Métier de journaliste Elyzea : rédactions (agences), articles (brouillons, validation, publication, archives), journal pour tous, interviews avec accord, photos et séquences, flash info, annonces payantes, matériel, carte de presse, vestiaire, garage, tablette (direction, finance, paie au taux horaire)'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
    'shared/perms.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua',
    'server/agencies.lua',
    'server/service.lua',
    'server/finance.lua',
    'server/commission.lua',
    'server/public.lua',
    'server/articles.lua',
    'server/interviews.lua',
    'server/media.lua',
    'server/flash.lua',
    'server/ads.lua',
    'server/gear.lua',
    'server/points.lua',
    'server/direction.lua',
    'server/phone.lua',
    'server/api.lua',
}

client_scripts {
    '@elyzea_core/lib/clothing.lua',   -- tenues du vestiaire : pièces de packs (collection + n° local)
    'client/main.lua',
    'client/items.lua',
    'client/interview.lua',
    'client/points.lua',
    'client/wardrobe.lua',
    'client/reader.lua',
    'client/alt.lua',
    'client/f6.lua',
    'client/tablet.lua',
    'client/phone.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/tablet.js',
}

dependencies { 'elyzea_core', 'elyzea_inventory' }
