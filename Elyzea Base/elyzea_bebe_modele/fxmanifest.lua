fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_bebe_modele'
author 'Elyzea FA'
description 'Modèle 3D original du bébé (4 poses, 6 teintes de peau, 5 couleurs d\'yeux, 10 coiffures) + API d\'affichage et commandes de test staff'
version '1.0.0'

-- Fichiers du jeu (dossier stream/, chargés automatiquement) : 84 modèles .ydr, textures ely_bebe_txd.ytd
data_file 'DLC_ITYP_REQUEST' 'stream/ely_bebe.ytyp'

shared_scripts {
    'shared/modeles.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}
