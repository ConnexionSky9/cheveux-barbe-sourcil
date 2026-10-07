# Elyzea — Loading Screen FiveM

Loading screen cinématique pour serveur RP : logo animé, nom et slogan révélés, slideshow légal / illégal avec effets Ken Burns, progression réelle du chargement FiveM, lecteur musical complet et fondu de sortie.

Aucune librairie externe. Seules les polices sont chargées depuis Google Fonts (Cinzel et Barlow Semi Condensed) ; si elles ne se chargent pas, des polices de secours prennent le relais automatiquement.

---

## 1. Structure

```text
loading-screen/
├── fxmanifest.lua        Déclaration de la ressource FiveM
├── client.lua            Ferme le loading screen (fondu) quand le joueur est prêt
├── index.html            Structure de la page
├── README.md
├── css/
│   └── style.css         Styles, couleurs, animations
├── js/
│   ├── config.js         ⭐ TOUTE la configuration (textes, photos, musique, effets)
│   └── script.js         Moteur (pas besoin d'y toucher)
└── assets/
    ├── images/           Photos du slideshow (photo1.jpg … photo6.jpg fournies en démo)
    ├── music/            Ta musique (loading.mp3)
    └── logo/             Ton logo (logo.png)
```

---

## 2. Installation

1. Copie le dossier `loading-screen` dans le dossier `resources` de ton serveur, par exemple :
   `resources/[ui]/loading-screen/`
2. Ajoute ta musique dans `assets/music/loading.mp3` (voir section 6).
3. Remplace les photos de démonstration par tes captures (voir section 5).
4. Dans ton `server.cfg`, ajoute :

```cfg
ensure loading-screen
```

5. **Retire ou désactive tout autre loading screen** (une seule ressource `loadscreen` peut être active). Si tu en avais un autre, commente sa ligne `ensure`.
6. Redémarre complètement le serveur (un `restart` de la ressource ne suffit pas : le loading screen s'affiche à la connexion).

> Le nom du dossier est le nom de la ressource. Si tu renommes le dossier (ex. `elyzea_loading`), mets le même nom dans `ensure`.

### Exemple de `server.cfg`

```cfg
# --- Ressources de base ---
ensure mapmanager
ensure chat
ensure spawnmanager
ensure sessionmanager
ensure hardcap

# --- Interface ---
ensure loading-screen

# --- Framework ---
# ensure es_extended   ou   ensure qb-core
```

---

## 3. Le fxmanifest

```lua
fx_version 'cerulean'
game 'gta5'

loadscreen 'index.html'          -- page affichée pendant le chargement
loadscreen_manual_shutdown 'yes' -- c'est client.lua qui ferme l'écran
loadscreen_cursor 'yes'          -- affiche la souris (pour le lecteur musical)

client_script 'client.lua'

files { ... }                    -- tous les fichiers utilisés par la page
```

Le bloc `files` utilise des jokers (`assets/images/*.jpg`, `assets/music/*.mp3`, etc.). **Tu n'as donc pas besoin de modifier le manifest quand tu ajoutes des photos ou des musiques**, tant que tu utilises les extensions prévues :

- images : `.jpg`, `.jpeg`, `.png`, `.webp`
- musique : `.mp3`, `.ogg`
- logo : `.png`, `.jpg`, `.webp`

### Fermeture du loading screen (`client.lua`)

Grâce à `loadscreen_manual_shutdown`, l'écran reste affiché jusqu'à ce que `client.lua` le ferme. Il le fait avec un fondu (image + musique) dès que l'un de ces événements arrive :

- `playerSpawned` (spawnmanager et la plupart des frameworks)
- `esx:playerLoaded` (ESX)
- `QBCore:Client:OnPlayerLoaded` (QBCore / Qbox)
- sécurité : 4 secondes après le démarrage de la session réseau

Réglages en haut de `client.lua` :

```lua
fadeOutDuration = 1200,       -- durée du fondu (ms)
sessionFallbackDelay = 4000   -- sécurité (ms), 0 pour la désactiver
```

> Si ton menu de sélection de personnage reste caché derrière le loading screen, diminue `sessionFallbackDelay`. S'il ferme trop tôt, augmente-le.

---

## 4. Logo

Remplace `assets/logo/logo.png` par ton logo (même nom). Un **PNG avec fond transparent** donne le meilleur rendu : le reflet lumineux qui traverse le logo suit exactement sa forme.

Pour changer le nom du fichier ou la taille, dans `js/config.js` :

```js
const server = {
    logo: "assets/logo/logo.png",
    logoSize: "min(40vh, 62vw)",   // ex. "420px" ou "min(45vh, 70vw)"
    ...
};
```

---

## 5. Photos

1. Place tes images dans `assets/images/` (idéalement 1920×1080 ou plus, en `.jpg` de moins de 600 Ko pour un chargement rapide).
2. Déclare-les dans `js/config.js`, tableau `slides` :

```js
const slides = [
    { src: "assets/images/lspd.jpg",   title: "Los Santos Police Department", side: "legal" },
    { src: "assets/images/braquo.jpg", title: "Braquage de la Fleeca",        side: "illegal" },
    "assets/images/ville.jpg"          // version courte, sans texte
];
```

- `title` : texte affiché en bas à gauche.
- `side` : `"legal"` (ambiance bleue), `"illegal"` (ambiance rouge) ou `"neutral"` (doré).
- `effect` (facultatif) : mouvement de la photo → `zoom-in`, `zoom-out`, `pan-left`, `pan-right`, `pan-up`, `pan-down`, `rotate`, `drift`.
- `transition` (facultatif) : entrée de la photo → `fade`, `blur`, `zoom`, `wipe-left`, `wipe-right`, `iris`.

Sans `effect` / `transition`, le script les fait tourner automatiquement pour que chaque photo soit différente.

**Ajouter une photo** : copie le fichier dans `assets/images/` et ajoute une ligne dans `slides`.
**Supprimer une photo** : retire sa ligne dans `slides` (et le fichier si tu veux).

Une image introuvable est simplement ignorée (un avertissement apparaît dans la console F8). Si aucune image n'est disponible, un fond dégradé bleu/rouge animé s'affiche.

> Les 6 images fournies sont des visuels de démonstration générés : remplace-les par tes propres captures du serveur.

---

## 6. Musique

### Emplacement

Place ton fichier ici, avec exactement ce nom :

```text
loading-screen/assets/music/loading.mp3
```

### Changer le fichier, le titre, l'artiste, le volume

Dans `js/config.js` :

```js
const music = {
    file: "assets/music/loading.mp3",  // chemin du fichier
    title: "Nom de la musique",        // affiché dans le lecteur
    artist: "Nom de l'artiste",
    duration: "",                      // facultatif, ex. "03:42"
    volume: 0.35,                      // 0 = muet, 1 = maximum
    autoplay: true,
    loop: true,
    shuffle: false,
    fadeIn: 2500,                      // montée progressive du son (ms)
    playlist: []
};
```

### Durée

La durée est lue **automatiquement** depuis le fichier (`audio.duration`) et affichée `00:00 / 03:42`. Le champ `duration` ne sert que si le fichier ne fournit pas sa durée (cas rare).

### Plusieurs musiques (précédent / suivant)

Remplis `playlist` ; elle remplace alors `file` :

```js
playlist: [
    { file: "assets/music/loading.mp3", title: "Night Drive",  artist: "Artiste A" },
    { file: "assets/music/track2.mp3",  title: "Code 3",       artist: "Artiste B" }
]
```

Les boutons précédent / suivant s'activent automatiquement dès qu'il y a au moins deux musiques.

### Autoplay

La musique démarre seule si FiveM l'autorise (c'est normalement le cas). Si l'autoplay est bloqué, un bouton « Cliquer pour lancer la musique » apparaît au-dessus du lecteur, et le premier clic ou la première touche lance la musique.

### Contrôles

- bouton lecture / pause, précédent, suivant
- barre de progression cliquable et glissable
- curseur de volume + bouton muet (le volume choisi est mémorisé)
- clavier : `Espace` lecture/pause, `M` muet, `←` / `→` reculer / avancer de 5 s

---

## 7. Configuration générale (`js/config.js`)

| Bloc | Ce qu'il règle |
|---|---|
| `server` | nom, sous-titre, slogan, logo, taille du logo, affichage du nom |
| `slides` | liste des photos |
| `slideshow` | durée d'affichage, durée des transitions, ordre aléatoire, effets autorisés |
| `music` | musique(s), volume, autoplay, boucle |
| `loading` | titre de la barre, vitesse de l'animation, textes des étapes |
| `tips` | astuces affichées en haut à gauche |
| `links` | liens affichés en haut à droite (Discord, site…) |
| `effects` | intro, particules, grain, vignette, lignes lumineuses, bandes cinéma, fondu de sortie |

---

## 8. Personnalisation

### Couleurs

En haut de `css/style.css` :

```css
:root {
    --ink:       #03050b;  /* fond */
    --gold:      #e9d3a1;  /* or clair */
    --gold-deep: #b98f4e;  /* or foncé */
    --blue:      #4f8cff;  /* côté légal */
    --red:       #ff2d43;  /* côté illégal */
}
```

Pour assombrir ou éclaircir les photos, ajoute dans `:root` : `--dim: .5;` (défaut `.38`, plus élevé = plus sombre).

### Textes

`js/config.js` → `server.name`, `server.subtitle`, `server.slogan`, `loading.title`, `loading.stages`, `tips.list`, `links`.

### Vitesse du slideshow et durée des transitions

```js
const slideshow = {
    interval: 7000,     // temps d'affichage d'une photo (ms)
    transition: 1800,   // durée du passage d'une photo à l'autre (ms)
    ...
};
```

### Animations

- Vitesse de l'intro : `effects.introSpeed` (`0.5` = 2× plus rapide, `1.5` = plus lent). `effects.intro: false` supprime la séquence.
- Flottement du logo : `effects.logoFloat`.
- Mouvements des photos : listes `slideshow.effects` et `slideshow.transitions`.
- Animations CSS détaillées : `css/style.css` (keyframes `logo-in`, `shine`, `beam`, `sweep`, `line-run`…).

### Effets

```js
const effects = {
    particles: true, particleCount: 40,
    grain: true, grainOpacity: 0.07,
    vignette: true,
    lightLines: true,
    letterbox: true
};
```

Sur une machine modeste, désactive d'abord `blurTransitions` (dans `slideshow`) puis `particles`.

### Polices

Les polices sont chargées dans `index.html` (balise `<link>` Google Fonts) et déclarées dans `css/style.css` (`--font-display`, `--font-ui`). Pour fonctionner 100 % hors ligne, supprime la balise `<link>` : les polices de secours seront utilisées.

---

## 9. Tester sans lancer FiveM

Ouvre `index.html` dans Chrome ou Edge. Hors de FiveM, une **simulation de chargement** se lance automatiquement (durée réglable avec `loading.demoDuration`), ce qui permet de vérifier le design, les photos et la musique.

> Certains navigateurs bloquent l'autoplay : clique une fois sur la page pour lancer la musique.

---

## 10. Dépannage

| Problème | Solution |
|---|---|
| Le loading screen ne s'affiche pas | Vérifie `ensure loading-screen` et qu'aucun autre loading screen n'est actif. Redémarre complètement le serveur. |
| Écran bloqué à la fin | Vérifie que `client.lua` est bien présent et déclaré. Diminue `sessionFallbackDelay`. |
| Pas de musique | Vérifie le nom exact : `assets/music/loading.mp3` (attention aux majuscules et aux extensions cachées comme `loading.mp3.mp3`). |
| Une photo ne s'affiche pas | Vérifie le chemin dans `slides` et l'extension du fichier. Ouvre la console F8 pour voir l'avertissement. |
| Pas de souris | `loadscreen_cursor 'yes'` doit être présent dans `fxmanifest.lua`. |
| Saccades | Réduis la taille des images, mets `blurTransitions: false`, puis `particles: false`. |
