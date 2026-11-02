-- =====================================================================
--  ELYZEA — LOADING SCREEN
-- =====================================================================
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'loading-screen'
author 'Elyzea'
description 'Loading screen Elyzea FA v3 « Néon » : logo animé 4K 120 i/s, effets synchronisés, progression réelle, musique'
version '3.0.0'

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
--   ancien_v2/                ancienne version (street art), gardée pour revenir en arrière
--   assets/images/originals/  captures d'origine (sources de la retouche)
--   assets/images/demo/       anciennes photos de démonstration
--   tools/                    scripts (retouche des photos, encodage de la vidéo)
files {
    'index.html',
    'css/*.css',
    'js/*.js',
    'assets/video/*.webm',                 -- logo animé : 4K 120 i/s + 1080p 60 i/s
    'assets/video/*.webp',                 -- dernière image du logo (secours)
    'assets/images/stylised/*.webp',       -- photos retouchées affichées en fond
    'assets/images/stylised/*.jpg',
    'assets/music/*.mp3',
    'assets/music/*.ogg'
}
