# Elyzea — Loading Screen FiveM (v2, street art)

Loading screen cinématique pour le serveur Elyzea :

1. **Intro** : le logo arrive en impact (flash, onde, éclats, secousse), puis les lettres **E-L-Y-Z-E-A** sortent du logo une par une, chacune avec son propre trajet et des traînées, et se placent à côté du logo ; tout explose et le tag graffiti **FA** claque à l'écran (éclaboussures, gouttelettes, coulures) ; un coup de peinture au rouleau révèle l'interface.
2. **Interface** : photos retouchées du serveur (légal / illégal), astuces, liens, logo + nom + slogan, progression **réelle** du chargement FiveM, lecteur musical en bas à droite.

Aucune librairie externe. Seules les polices viennent de Google Fonts (Cinzel, Barlow Semi Condensed, Permanent Marker) ; sans internet, des polices de secours prennent le relais.

---

## 1. Structure

```text
elyzea_loadscreen/
├── fxmanifest.lua        Déclaration de la ressource FiveM
├── client.lua            Ferme le loading screen (fondu) quand le joueur est prêt
├── index.html            Structure de la page (dont le tag « FA » en SVG)
├── css/style.css         Styles, couleurs, animations
├── js/config.js          ⭐ TOUTE la configuration (textes, photos, musique, intro, effets)
├── js/script.js          Moteur (pas besoin d'y toucher)
├── tools/stylise_images.py   Script de retouche des photos (non envoyé aux joueurs)
└── assets/
    ├── logo/             logo.webp (utilisé) + logo.png
    ├── music/            loading.mp3
    └── images/
        ├── stylised/     ⭐ photos retouchées affichées en jeu
        ├── originals/    captures d'origine (sources, non envoyées aux joueurs)
        └── demo/         anciennes photos de démonstration (non envoyées aux joueurs)
```

Les dossiers `originals/`, `demo/` et `tools/` ne sont **pas** déclarés dans `fxmanifest.lua` : ils restent sur le serveur mais ne sont jamais téléchargés par les joueurs.

---

## 2. Installation / mise à jour

1. Remplace le dossier `elyzea_loadscreen` sur ton serveur par celui-ci.
2. `server.cfg` : `ensure elyzea_loadscreen` (une seule ressource `loadscreen` active).
3. **Redémarre complètement le serveur** : un loading screen ne s'affiche qu'à la connexion, `restart` ne suffit pas pour le voir. Côté joueur, il faut se reconnecter.

Si tu avais modifié `js/config.js` (textes, Discord, titre de la musique…), recopie tes valeurs dans le nouveau fichier : les blocs `slides`, `intro` et `effects` ont changé.

---

## 3. Intro (`js/config.js` → `intro`)

Tous les temps sont réunis ici (en millisecondes) :

| Réglage | Rôle |
|---|---|
| `enabled` | `false` = pas d'intro |
| `speed` | `1` normal, `0.7` plus rapide, `1.3` plus lent |
| `skippable` | bouton « Passer » + touches Échap / Entrée |
| `words` | lettres qui sortent du logo (`"ELYZEA"`) |
| `logoAt`, `logoDuration` | impact du logo |
| `lettersAt`, `letterStagger`, `letterFlight`, `trails` | sortie des lettres |
| `chargeAt`, `explodeAt`, `tagHold` | charge, explosion, durée du « FA » |
| `wipeIn`, `wipeOut` | coup de peinture vers l'interface |
| `shards`, `sprayDots` | nombre d'éclats et de gouttelettes |

Le tag « FA » est dessiné en SVG dans `index.html` (bloc `intro__fa`).

---

## 4. Photos

Les 5 captures fournies ont été retouchées par `tools/stylise_images.py` (Python 3 + Pillow + numpy). Pour chaque image :

- effacement du « + » rouge du viseur GTA resté au centre des captures ;
- exposition / gamma / contraste, étalonnage ombres-lumières aux couleurs du logo ;
- saturation sélective (néons bleus / rouges, végétation…), clarté (contraste local), halo lumineux (bloom) sur les sources de lumière ;
- fuite de lumière colorée dans un coin, vignettage, grain fin ;
- touches de peinture (trait de bombe avec coulures, éclaboussure) placées sur le sol, un mur ou le ciel, jamais sur les enseignes ni les bâtiments principaux, et hors des emplacements de l'interface.

Aucune déformation, aucun texte ajouté. Export WebP 1920 px (≈ 190 à 280 Ko).

Relancer la retouche (après avoir changé un réglage dans `PRESETS`) :

```bash
cd elyzea_loadscreen
python3 tools/stylise_images.py            # toutes les images
python3 tools/stylise_images.py mrpd       # une seule
```

**Ajouter une photo** : mets-la dans `assets/images/stylised/` (webp ou jpg) et ajoute une ligne dans `slides` :

```js
{ src: "assets/images/stylised/ma_photo.webp", title: "Texte de la légende", side: "legal" }
```

`side` : `legal` (bleu), `illegal` (rouge), `neutral` (or). `label` (facultatif) remplace « Côté légal / illégal ».

---

## 5. Musique (bas droite)

`js/config.js` → `music` (fichier, titre, artiste, volume, playlist…). La musique actuelle (`assets/music/loading.mp3`) est conservée.

- Temps écoulé et durée totale lus **depuis le fichier** (`--:--` tant que la durée est inconnue).
- Lecture / pause, **stop** (retour à 00:00), précédent / suivant (si playlist), barre de progression cliquable, volume mémorisé, muet.
- Indicateur d'état : En lecture · En pause · Arrêté · Chargement… · En attente d'un clic · Musique indisponible.
- Si l'autoplay est refusé, le premier clic ou la première touche lance la musique.
- Fichier introuvable : le lecteur l'indique, la page continue normalement.
- Clavier : `Espace` lecture/pause, `S` stop, `M` muet, `←` / `→` ±5 s.
- Un seul lecteur et une seule balise `<audio>` ; le script refuse de s'initialiser deux fois.

---

## 6. Performances et effets réduits

- Animations en `transform` / `opacity` ; aucun flou animé dans l'intro.
- Particules de l'intro sur un canvas qui ne tourne que s'il reste des particules.
- Pendant l'intro, le décor caché derrière (grain, particules, interface) est mis en pause.
- À la fin de l'intro, tout son DOM est supprimé. À la fermeture, minuteurs, boucles et animations sont arrêtés.
- `effects.reduced` : `"auto"` (suit le réglage système « réduire les animations »), `true` (toujours réduits : pas d'éclats, de traînées, de particules, de flash ni de flou), `false`.

---

## 7. Fermeture (`client.lua`, inchangé)

`loadscreen_manual_shutdown 'yes'` : `client.lua` envoie `elyzea:fadeOut` puis ferme l'écran quand `elyzea_multichar` est prêt (ou au chargement du personnage, avec sécurités). Si la fermeture arrive pendant l'intro, l'intro est arrêtée proprement.

---

## 8. Tester sans FiveM

Sers le dossier avec un petit serveur web (ex. `npx http-server`) et ouvre `index.html` dans Chrome : une simulation de chargement se lance. Utilise un serveur qui gère les requêtes « Range » : sinon le clic sur la barre de progression de la musique ne peut pas se déplacer dans le morceau.
