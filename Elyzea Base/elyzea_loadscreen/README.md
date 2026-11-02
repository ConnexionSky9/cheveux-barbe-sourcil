# Elyzea FA — Loading Screen v3 « Néon »

Loading screen construit autour du logo animé **ELYZEA FA** (vidéo fournie), en violet néon.

## Déroulé
1. **Intro (8 s)** : le logo animé est joué en **4K 120 i/s** (écran ≥ 2560 px de large) ou **1080p 60 i/s**.
   Effets synchronisés sur la vidéo :
   - « E » qui apparaît : éclair et halo ;
   - gerbe d'étincelles : explosion de particules et faisceaux lumineux ;
   - ville : onde de choc et sol néon ;
   - « ELYZEA FA » : reflet chromatique et pluie de particules.
   « Passer » (ou Échap / Entrée / Espace) saute l'intro.
2. **Interface** : le logo monte en haut, avec un reflet qui le balaie de temps en temps. Autour :
   - fond : photos du serveur teintées violet, qui avancent lentement, avec une aurore lumineuse et un sol néon en perspective ;
   - particules, traits lumineux et léger effet de profondeur à la souris ;
   - progression **réelle** de FiveM : pourcentage, étape en cours, 7 étapes cochées une à une ;
   - astuces avec minuterie, lieu de la photo (côté légal / illégal), slogan tapé à la machine ;
   - horloge, lien Discord, lecteur musical avec égaliseur.
3. **Sortie** : fondu violet → noir, quand `client.lua` le demande (comme avant).

Le logo vidéo est posé sur le décor en mode « screen » : le noir de la vidéo devient transparent, seul le logo lumineux reste.

## 4K et 120 i/s
- **Vidéo** : la vidéo d'origine (1080p 60 i/s) a été passée en **3840×2160** et en **120 images/s**.
  - Les images intermédiaires sont **calculées** par interpolation de mouvement : ce ne sont pas des images dupliquées.
  - La 4K est un **agrandissement** (Lanczos + netteté), pas une nouvelle source : elle est plus fine qu'un simple étirement, mais ne crée pas de détails qui n'existaient pas.
- **Effets et interface** : tout est dessiné en direct, à la **résolution native** de l'écran (net en 4K) et à sa **fréquence** (60, 120, 144 Hz…). Si le PC peine (moins de 45 i/s), le nombre de particules baisse tout seul.

## Installation
1. Remplacer le dossier `elyzea_loadscreen` sur le serveur.
2. `server.cfg` : `ensure elyzea_loadscreen` (rien ne change).
3. **Redémarrer le serveur** puis se reconnecter : un loading screen ne s'affiche qu'à la connexion.

L'ancienne version (street art) est gardée dans `ancien_v2/`. Elle n'est pas envoyée aux joueurs. Pour la remettre, recopie son contenu à la racine de la ressource.

## Réglages (`js/config.js`)
| Bloc | Rôle |
|---|---|
| `server` | nom, sous-titre, slogan |
| `video` | `quality` (`"auto"` / `"4k"` / `"1080"`), tailles et position du logo, moments forts (`beats`) |
| `slides` / `slideshow` | photos de fond, durée, fondu |
| `music` | playlist, volume, lecture auto |
| `loading` | textes des étapes |
| `tips` / `links` | astuces, liens |
| `effects` | particules, sol néon, faisceaux, traits, grain, parallaxe, effets réduits |

Couleurs : `css/style.css`, bloc `:root`.

## Refaire la vidéo (autre logo)
`bash tools/encode_logo.sh ma_video.mp4` (ffmpeg) recrée les 3 fichiers de `assets/video/`.
