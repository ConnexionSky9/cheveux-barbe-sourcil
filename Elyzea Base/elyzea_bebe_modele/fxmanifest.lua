fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_bebe_modele'
author 'Elyzea FA'
description 'Bébé V4 : modèle 3D original (4 poses, 6 teintes × 2 tenues, 5 yeux, 10 coiffures, endormi), portage visible par tous (bras, face), porte-bébés ventral et dorsal 3D, poussette 3D'
version '2.0.0'

-- Fichiers du jeu (dossier stream/, chargés automatiquement) : 132 modèles .ydr (bébé, porte-bébés, poussette), 3 dictionnaires .ytd
data_file 'DLC_ITYP_REQUEST' 'stream/ely_bebe.ytyp'

shared_scripts {
    'shared/modeles.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/portage.lua',
}

server_scripts {
    'server/main.lua',
    'server/bebes.lua',
}
