fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_bebe_modele'
author 'Elyzea FA'
description 'Bébé : modèle 3D original (4 poses, 6 teintes × 2 tenues, 5 couleurs d\'yeux, 10 coiffures), portage visible par tous (bras, face, porte-bébé), poser allongé / assis'
version '1.2.0'

-- Fichiers du jeu (dossier stream/, chargés automatiquement) : 108 modèles .ydr, textures ely_bebe_txd.ytd + ely_bebe_corps_txd.ytd
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
