fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_bebe_modele'
author 'Elyzea FA'
description 'Bébé V6 : modèle 3D original, portage visible par tous, porte-bébés ventral et dorsal 3D, poussette 3D à roues et physique simulée, bébés et poussettes enregistrés en base'
version '3.0.0'

-- Fichiers du jeu (dossier stream/, chargés automatiquement) : 132 modèles .ydr (bébé, porte-bébés, poussette), 3 dictionnaires .ytd
data_file 'DLC_ITYP_REQUEST' 'stream/ely_bebe.ytyp'

shared_scripts {
    'shared/modeles.lua',
    'config.lua',
    'shared/physique.lua',
}

client_scripts {
    'client/main.lua',
    'client/suivi.lua',
    'client/portage.lua',
    'client/poussette.lua',
    'client/soins.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua',
    'server/bebes.lua',
    'server/persistance.lua',
    'server/soins.lua',
}

dependencies { 'elyzea_core' }
