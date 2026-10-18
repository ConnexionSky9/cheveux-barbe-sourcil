fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_vetements_correctifs'
author 'Elyzea FA'
description 'Correctifs de vêtements (fichiers corrigés dans stream/) + diagnostic en jeu (/vet_diag, /vet_essai)'
version '1.0.0'

-- stream/    : fichiers .ydd / .ytd CORRIGÉS, avec EXACTEMENT le nom du fichier d'origine.
--              Ils remplacent ceux du pack tant que cette ressource est lancée APRÈS le pack.
-- originaux/ : copie des fichiers d'origine (jamais envoyée aux joueurs) pour revenir en arrière.

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'
