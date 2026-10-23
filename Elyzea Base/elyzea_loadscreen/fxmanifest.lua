-- =====================================================================
--  ELYZEA — LOADING SCREEN
-- =====================================================================
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'loading-screen'
author 'Elyzea'
description 'Loading screen cinématique Elyzea (street art : logo, ELYZEA, FA, légal / illégal)'
version '2.0.0'

-- Page affichée pendant le chargement
loadscreen 'index.html'

-- Le loading screen ne se ferme pas tout seul : client.lua le ferme
-- avec un fondu quand le joueur est prêt.
loadscreen_manual_shutdown 'yes'

-- Affiche le curseur de la souris (nécessaire pour le lecteur musical)
loadscreen_cursor 'yes'

client_script 'client.lua'

-- Tous les fichiers utilisés par la page doivent être déclarés ici.
-- Non déclarés exprès (donc jamais téléchargés par les joueurs) :
--   assets/images/originals/  captures d'origine (sources de la retouche)
--   assets/images/demo/       anciennes photos de démonstration
--   tools/                    script de retouche des photos
files {
    'index.html',
    'css/*.css',
    'js/*.js',
    'assets/logo/*.png',
    'assets/logo/*.jpg',
    'assets/logo/*.webp',
    'assets/images/*.jpg',
    'assets/images/*.jpeg',
    'assets/images/*.png',
    'assets/images/*.webp',
    'assets/images/stylised/*.webp',   -- photos retouchées affichées en jeu
    'assets/images/stylised/*.jpg',
    'assets/music/*.mp3',
    'assets/music/*.ogg'
}
