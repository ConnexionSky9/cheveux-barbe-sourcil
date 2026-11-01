# Elyzea : menu des animations

Menu d'animations pour le serveur Elyzea RP. Il s'ouvre avec **K**, l'animation s'arrête avec **X**, et les favoris peuvent recevoir leur propre touche de raccourci.

**Moteur intégré (nouveau).** Le menu joue lui-même les animations avec les fonctions du jeu (`client_engine.lua`) : il n'envoie plus aucune commande à rpemotes (`/e`, `/walk`, `/mood`, `/emotecancel`). Avant, le menu dépendait des commandes et des événements de rpemotes : quand rpemotes a changé (rpemotes-reborn a renommé ses événements d'animations à deux), les animations du menu ont cessé de marcher.

## Contenu du dossier

```
elyzea_animations/
├── fxmanifest.lua           Déclaration de la ressource
├── client_engine.lua        Moteur : animations, objets, effets, scénarios, démarches, humeurs, sorties, animations à deux
├── client.lua               Menu, touches, raccourcis, aperçu 3D, placement, demandes d'animations à deux
├── client_interactions.lua  Menu ALT : copier une animation, proposer une animation, arrêt des animations à deux
├── server.lua               Demandes d'animations à deux, animations à deux en cours, copie (tout est vérifié ici)
├── interactions.lua         Réglages et catégories de « Proposer une animation » (client + serveur)
├── anim_data.lua            Données de TOUTES les animations (généré, voir plus bas)
├── shared_emotes.lua        Animations à deux : rôle de l'autre joueur (généré)
├── html/
│   ├── index.html           L'interface
│   ├── style.css            Thème du menu
│   ├── app.js               Fonctionnement du menu (liste virtualisée)
│   ├── emotes.js            Liste du menu par catégorie (généré)
│   └── logo.webp            Logo
├── tools/
│   ├── gen_anim_data.py     Générateur des 3 fichiers « générés »
│   └── rpemotes_source/     Liste d'animations de rpemotes-reborn utilisée par le générateur (licence GPL-3 incluse)
└── tests/                   Tests hors jeu (voir la fin de ce fichier)
```

## Prérequis

- **rpemotes** (ou rpemotes-reborn) reste installé et démarré **avant** le menu : il fournit les **fichiers** des animations personnalisées et des objets (son dossier `stream/`). Le menu n'utilise plus ses commandes.
- Sans rpemotes, les animations de base de GTA marchent quand même ; celles dont le fichier manque sont masquées automatiquement.
- Pour les animations récentes, une version du jeu suffisante dans `server.cfg` (par exemple `sv_enforceGameBuild 3095`).

## Installation

1. Remplace le dossier `elyzea_animations` par celui du zip (les réglages et favoris des joueurs sont gardés : ils sont enregistrés chez chaque joueur).
2. Dans `server.cfg`, l'ordre ne change pas :

   ```
   ensure rpemotes
   ensure elyzea_animations
   ```

3. Redémarre le serveur, ou dans la console : `refresh` puis `ensure elyzea_animations`.
4. En jeu, appuie sur **K** : le menu s'ouvre.

## Réglages

En haut de `client.lua`, la partie `Config` :

```lua
local Config = {
    Command        = 'anim',  -- /anim wave (lancer), /anim seul (arrêter)
    DefaultOpenKey = 'K',
    DefaultStopKey = 'X',
    AcceptKey      = 'Y',     -- accepter une demande d'animation à deux
    RefuseKey      = 'L',     -- refuser une demande (N = parler avec pma-voice)
    NearbyRadius   = 3.0,     -- distance max (mètres) pour les animations à deux
    PreviewCam = { side = 0.0, dist = 3.3, height = 0.15, fov = 50.0 },   -- caméra de l'aperçu 3D
    Placement = { ... },      -- voir « Placer son animation »
}
```

En haut de `client_engine.lua`, `ElyEngine.Config` : `FxKey = 'G'` (touche des effets), vitesses de transition, délai max de chargement.

**Menu de rpemotes.** rpemotes ouvre aussi son propre menu et garde `/e`. Si tu veux que les joueurs n'utilisent que le menu Elyzea, désactive le menu de rpemotes dans son `config.lua` (`MenuKeybindEnabled = false`).

## Utilisation en jeu

| Action | Comment |
|---|---|
| Ouvrir ou fermer le menu | **K** (ou Échap pour fermer) |
| Arrêter l'animation | **X**, même menu fermé, ou le bouton Arrêter |
| Chercher une animation | Barre de recherche, par nom ou par commande |
| Mettre en favori | L'étoile en haut à droite d'une animation |
| Assigner une touche | Onglet Favoris, bouton « + Touche », puis appuie sur la touche voulue |
| Retirer une touche | Clique sur la touche assignée, puis « Retirer la touche » |
| Choisir au clavier | **Flèches** puis **Entrée** (aussi depuis la recherche) |
| Effet de l'animation (fumée, flash, billets…) | **G** : maintenir (fumée) ou appuyer (effet court). « G effet » s'affiche dans le menu |
| Animation à deux | Onglet À deux : choisis un joueur proche, il reçoit une demande |
| Accepter une demande | **Y** (ou le bouton Accepter si ton menu est ouvert) |
| Refuser une demande | **L** (ou le bouton Refuser) |
| Dans le chat | `/anim wave` pour lancer, `/anim` pour arrêter |
| Placer une animation où je veux | Clic droit sur une animation, ou l'icône flèches en bas à droite de la case |
| Déplacer l'animation en cours | **J** (menu fermé), ou `/placer` |
| Paramètres | L'icône engrenage en haut du menu |

Touches acceptées pour les raccourcis : chiffres, F1 à F12, pavé numérique et lettres libres. Les touches du jeu (ZQSD, WASD, E, F, G, R, T, C, V, Espace, Tab) et celles du menu (Y, L, J, G) sont bloquées pour éviter les conflits.

**F7 est réservée à « Mes animaux » (`elyzea_animaux`).** Le menu des animations ne peut plus s'ouvrir, s'arrêter ni lancer un raccourci avec F7. Un joueur qui avait choisi F7 repasse automatiquement sur **K** (son raccourci sur F7 est retiré). Liste des touches réservées : `ReservedKeys` en haut de `client.lua`.

Les réglages et raccourcis sont sauvegardés pour chaque joueur et restent après une déconnexion. Ils apparaissent aussi dans **Paramètres GTA > Raccourcis > FiveM**, sous le nom « Elyzea animations ».

## Aperçu 3D

Quand tu ouvres le menu, la caméra se place devant ton personnage. Quand tu survoles une animation, il la fait en boucle, en entier, avec ses objets. Tu vois donc exactement le résultat avant de cliquer.

Comment ça marche : une copie de ton personnage, visible seulement par toi, prend ta place pendant que le menu est ouvert. Les autres joueurs te voient normalement, debout, tant que tu n'as pas lancé d'animation. Quand tu fermes le menu, la caméra revient derrière toi et la copie disparaît.

- Le personnage s'affiche au milieu de l'écran, face à la caméra (`side = 1.1` pour le remettre à l'opposé du menu).
- L'aperçu est désactivé dans un véhicule.
- Tu peux le couper dans les paramètres du menu (« Aperçu 3D »).
- Pour régler le cadrage, change `PreviewCam` dans `client.lua` (par exemple `dist = 4.0` pour voir le perso plus petit).

## Placer son animation

Pour te mettre exactement où tu veux (sur une chaise, un muret, un banc, contre un mur…), sans dépendre de l'endroit où ton perso s'arrête en marchant.

**Lancer le placement**

- Dans le menu : **clic droit** sur une animation, ou l'icône flèches en bas à droite de sa case.
- Pendant une animation, menu fermé : **J** pour la déplacer.
- Dans le chat : `/placer wave` pour placer une animation précise, `/placer` pour déplacer celle en cours.

Un fantôme transparent de ton personnage apparaît et fait l'animation. Lui seul bouge, les autres joueurs ne le voient pas. La souris tourne la caméra comme d'habitude.

| Action | Touche |
|---|---|
| Déplacer le fantôme | **Z Q S D** (dans la direction de la caméra) |
| Tourner | **A** / **E**, ou la molette |
| Monter / descendre | **Flèche haut** / **Flèche bas** |
| Mode précis (lent) | Maintenir **Maj** |
| Poser au sol | **G** |
| Valider | **Entrée**, clic gauche, ou **J** |
| Annuler | **Retour arrière**, clic droit, Échap, ou **X** |

Les touches s'affichent en bas à droite de l'écran pendant le placement (elles suivent la disposition du clavier du joueur).

Le cercle au sol est **doré** quand l'endroit est valide et **rouge** sinon. Le message en bas de l'écran dit pourquoi :

- *Pas de sol à cet endroit* : il n'y a rien sous le fantôme.
- *Trop haut au-dessus du sol* : plus de 1,2 m au-dessus de la surface en dessous.
- *Un mur te sépare de cet endroit* : impossible de traverser un mur.

Le fantôme ne peut pas s'éloigner de plus de 3 m de l'endroit où tu étais.

**Après validation**, ton personnage est déplacé à la place du fantôme et l'animation démarre. Si tu l'as placé en hauteur ou dans un meuble (chaise, lit, muret), il est figé sur place pour ne pas tomber. Il se relève quand l'animation s'arrête (**X**), quand tu bouges (**Z Q S D**, **Espace**), ou quand l'animation se termine d'elle-même. Posé à plat sur le sol, rien ne change : l'animation se comporte comme d'habitude.

Ça ne marche que pour les animations classiques : pas pour les démarches, les humeurs, les animations à deux (le moteur place déjà les deux joueurs) ni en véhicule.

**Réglages**, dans `client.lua`, partie `Config.Placement` :

```lua
Placement = {
    Enabled     = true,     -- false pour désactiver complètement le placement
    Key         = 'J',      -- touche pour déplacer l'animation en cours
    Command     = 'placer', -- commande du chat
    MaxDistance = 3.0,      -- distance max depuis l'endroit où tu es (mètres)
    MaxHeight   = 1.2,      -- hauteur max au-dessus du sol (mètres)
    MoveSpeed   = 1.2,      -- vitesses de déplacement, montée, rotation
    HeightSpeed = 0.5,
    RotateSpeed = 90.0,
    WheelStep   = 10.0,     -- rotation par cran de molette (degrés)
    SlowFactor  = 0.25,     -- vitesse en mode précis
    GhostAlpha  = 170,      -- transparence du fantôme (0 à 255)
},
```

Garde `MaxDistance` et `MaxHeight` petits : ce sont eux qui empêchent de se servir du placement pour monter sur un toit ou entrer quelque part. La touche **J** se change aussi dans Paramètres GTA > Raccourcis > FiveM (« déplacer mon animation »).

**Note.** `/placer` et **J** ne connaissent que les animations lancées par le menu, un raccourci, `/anim` ou `/placer`. Une animation lancée par `/e` de rpemotes ne peut pas être déplacée avec **J** : utilise `/placer nomdelanimation` à la place.

## Animations masquées automatiquement

Le menu ne montre que les animations que tu peux vraiment faire :

- **Fichiers manquants** : au démarrage, le menu vérifie chaque animation et chaque objet. Si un fichier n'existe pas (rpemotes absent ou ancien, version du jeu trop ancienne), l'animation est masquée. Tape `elyzea_anim_check` dans la console F8 pour voir la liste.
- **Véhicule** : les animations « seulement en véhicule » n'apparaissent que quand tu es dans un véhicule, et celles interdites en véhicule disparaissent quand tu y montes.
- **Sexe du personnage** : les animations prévues pour l'autre sexe (« Female », « Male » dans leur nom) sont masquées. Désactivable dans les paramètres (« Masquer l'autre sexe »).

Si beaucoup d'animations sont masquées pour fichiers manquants, vérifie la version du jeu dans `server.cfg` (par exemple `sv_enforceGameBuild 3095`) : certaines animations de rpemotes viennent de mises à jour récentes de GTA.

## Animations à deux

Quand tu choisis une animation à deux et un joueur, celui-ci reçoit une fenêtre en haut de son écran avec ton nom et l'animation proposée. Il a 15 secondes pour appuyer sur **Y** (accepter) ou **L** (refuser).

Tu reçois un message dans tous les cas : accepté, refusé, ou pas de réponse. Une fois acceptée, l'animation démarre pour vous deux. **X** l'arrête pour les deux joueurs.

Celui qui fait la demande est toujours celui qui porte (épaule, dos).

Réglages côté serveur, en haut de `server.lua` :

```lua
local Config = {
    RequestTimeout = 15,   -- secondes pour accepter
    MaxDistance    = 3.0,  -- distance max entre les deux joueurs
    Cooldown       = 3,    -- secondes entre deux demandes d'un même joueur
}
```

Le contrôle de distance côté serveur nécessite **OneSync** (activé par défaut sur les serveurs récents).

**Comment les animations sont jouées.** Une fois la demande acceptée, le serveur envoie l'événement `elyzea_anim:sharedPlay` aux deux joueurs en même temps. Chacun joue son rôle (`shared_emotes.lua` : par exemple `carry` pour celui qui porte, `carry2` pour celui qui est porté), comme rpemotes-reborn :

- le rôle « accroché » (porté, sur le dos, otage…) s'attache à l'os prévu du partenaire ;
- sinon, celui qui a demandé se place devant l'autre (distance et angle propres à chaque animation) ;
- l'arrêt (X, mort, éloignement, déconnexion) détache et libère les deux.

La distance maximale est de 3 mètres.

## Menu ALT : copier une animation, proposer une animation

Maintenir **ALT** et cliquer sur une personne (menu ALT d'`elyzea_police`, le même que pour porter ou le coffre) ajoute deux actions :

**Copier l'animation**
- Le jeu de la personne visée regarde ce que son personnage joue **vraiment** (dictionnaire + clip, ou scénario) et le compare
  au catalogue (`anim_data.lua`). Si plusieurs animations ont le même clip, celle dont l'objet en main correspond est choisie.
  Rien n'est modifié chez la personne copiée.
- Ton personnage lance la même animation, au même moment de l'animation, **sans être déplacé**. **X** l'arrête.
- Refus expliqué, sans rien lancer : aucune animation reconnue, animation hors catalogue (« non reconnue »), **animation à deux**
  (porté, câlin avec un partenaire, animation lancée par le menu…) → utilise « Proposer une animation », fichier absent chez toi
  (« fichier manquant »), animation de véhicule à pied (ou l'inverse), menotté / à terre.
- Distance max 6 m (`ElyzeaInteractions.Copy` dans `interactions.lua`).

**Proposer une animation**
- Le menu **K** s'ouvre en mode « Proposer une animation à … », avec seulement les animations à deux, classées :
  Salutations, Poignées de main, Accolades et câlins, Interactions amicales, En couple, **Danser ensemble**, **Slow**, Porter, Autres interactions.
  Ce sont les 94 rôles d'animations à deux de rpemotes-reborn (`shared_emotes.lua`) ; ceux dont le fichier manque sont masqués.
- La personne reçoit l'invitation : **Y** accepter, **L** refuser. Tu vois un bandeau « Invitation envoyée » : **L** (ou `/annuleranim`,
  ou ALT › « Annuler l'invitation ») pour l'annuler. Sans réponse en 15 s : expirée, les deux sont prévenus.
- Une seule invitation à la fois : on ne peut pas inviter quelqu'un qui a déjà une invitation, ni en envoyer deux.
- À l'acceptation, le serveur revérifie : connectés, à moins de 4 m, ni menotté, ni porté, ni à terre, ni en véhicule, ni déjà en animation à deux.
- Les animations à deux sont jouées par le moteur avec le clip de **chaque rôle** (ex. `hug` / `hug2`) : il place les deux personnages.
- **Danser ensemble / Slow** : la liste n'a **aucune danse de couple** ni slow à deux. Ces catégories proposent donc une danse **solo** que
  vous faites tous les deux, tournés l'un vers l'autre, lancée au même moment (c'est écrit dans le menu et dans l'invitation).
  Les danses « Hip Hop » de rpemotes sont le rôle A d'une danse GTA à deux : elles ne sont pas proposées (jouer deux fois le même rôle ne donne pas une danse de couple).
- **Arrêt** : **X** chez l'un arrête les deux ; ALT › « Arrêter l'animation à deux » aussi. Arrêt automatique des deux si l'un meurt,
  est menotté, s'éloigne de plus de 8 m, se déconnecte, ou si la ressource redémarre.

Réglages : `interactions.lua` (catégories, distances, durées) et `Config` en haut de `server.lua` (délai de réponse, distance, anti-spam).

## Personnaliser

**Mettre à jour ou ajouter des animations.** Les fichiers `anim_data.lua`, `shared_emotes.lua` et `html/emotes.js` sont **générés** depuis la liste de rpemotes-reborn :

1. Remplace `tools/rpemotes_source/AnimationList.lua` (et `types.lua`) par ceux de ta version de rpemotes, ou ajoute tes animations dedans au même format.
2. Lance `python3 tools/gen_anim_data.py` (paquet Python `lupa`).
3. Les catégories et noms déjà choisis sont gardés ; les nouvelles animations sont classées automatiquement (par mots-clés). Tu peux ensuite les déplacer à la main dans `html/emotes.js` : le générateur gardera ton choix la fois suivante.

Ce qui est repris de rpemotes pour chaque animation : dictionnaire et clip, drapeau de mouvement (marcher pendant l'animation, boucle, figé), durée, délai, 1 ou 2 objets (modèle, os, position, rotation), effet (asset, nom, placement, os, couleurs, maintenir ou appuyer), animation de sortie (se relever, ranger le téléphone…), règles véhicule, et pour les animations à deux : accroche (os + position) ou placement devant le partenaire.

Pour une nouvelle animation à deux, range-la aussi dans une catégorie de `interactions.lua` pour qu'elle apparaisse dans « Proposer une animation » (menu ALT).

**Animations exclues.** Les animations marquées « adulte » dans rpemotes (comme avant ; `INCLUDE_ADULT = True` en haut du générateur pour les ajouter) et les animations d'animaux (il faut un personnage animal).

**Noms en anglais.** Les noms sont ceux de rpemotes. Tu peux les traduire dans `html/emotes.js` : seul le premier texte est affiché, la commande ne change pas (le générateur garde ta traduction).

**Changer le logo.** Remplace `html/logo.webp` par ton image (même nom).

**Changer les couleurs.** En haut de `html/style.css` : `--cy` (couleur principale), `--a1` / `--a2` (reflets bleu / rouge). L'ambiance se choisit aussi dans les paramètres du menu.

## Problèmes fréquents

**Le menu ne s'ouvre pas avec K.**
Vérifie que la ressource démarre bien (`ensure elyzea_animations` dans la console, aucune erreur en F8). Si K est déjà utilisée par un autre script, change la touche dans les paramètres du menu ou dans Paramètres GTA > Raccourcis > FiveM.

**Le menu s'ouvre mais l'animation ne se lance pas.**
Un message explique pourquoi (en véhicule, menotté, fichier absent…). « Fichier absent » : rpemotes n'est pas démarré, ou ta version n'a pas ce fichier ; tape `elyzea_anim_check` dans F8 pour la liste des animations masquées.

**Rien ne s'affiche quand j'appuie sur G.**
Seules les animations marquées d'une flamme dans le menu ont un effet. Si un autre script utilise G, change la touche dans Paramètres GTA > Raccourcis > FiveM (« effet de l'animation »).

**Je ne peux plus bouger, la souris reste affichée.**
Appuie sur Échap. Si ça persiste, tape `restart elyzea_animations` dans la console F8.

**La demande partagée n'arrive pas à l'autre joueur.**
Vérifie que `server.lua` est bien chargé (il est déclaré dans `fxmanifest.lua`) et que vous êtes à moins de 3 mètres. Regarde la console serveur pour une éventuelle erreur.

**Y ou L ne font rien.**
Un autre script utilise peut-être ces touches. Change-les dans Paramètres GTA > Raccourcis > FiveM (« accepter une demande » et « refuser une demande »), ou dans `Config.AcceptKey` et `Config.RefuseKey`.

**Je reste bloqué sur place après un placement.**
Appuie sur **X** ou avance avec **Z**. Si ça persiste, tape `restart elyzea_animations` dans la console F8 : le personnage est libéré.

**J ne fait rien.**
Un autre script utilise peut-être cette touche. Change-la dans Paramètres GTA > Raccourcis > FiveM, ou utilise `/placer`.

**Une touche changée ne prend pas effet.**
FiveM garde en mémoire les raccourcis déjà créés. Va dans Paramètres GTA > Raccourcis > FiveM et vérifie la touche liée à « Elyzea animations ».

## Tests hors jeu

Depuis `elyzea_animations/` (paquets `lupa` pour Python, `playwright` pour Node) :

| Commande | Ce qui est vérifié |
|---|---|
| `python3 tests/run_engine_sim.py` | Moteur avec natives simulées : **toutes** les animations lancées puis arrêtées (animation, drapeau, durée, objets, effets, sortie), toutes les démarches et humeurs, les 94 rôles à deux (placement / accroche), cas particuliers |
| `python3 tests/run_client_sim.py` | Copier l'animation, menu ALT, arrêt des animations à deux, danser ensemble |
| `python3 tests/run_interactions_sim.py` | Serveur : invitations, acceptation, refus, expiration, déconnexions, copie |
| `python3 tests/run_f7_sim.py` | F7 réservée à « Mes animaux » |
| `NODE_PATH=$(npm root -g) node tests/ui_menu.js` | Interface dans Chromium, sans internet : catégories, liste virtualisée, recherche, clavier, favoris, raccourcis, à deux, proposer, paramètres, petit écran |

Ces tests vérifient ce qui est **demandé au jeu**, pas le rendu : un essai en jeu reste nécessaire (rendu des animations, positions des objets, synchronisation entre deux joueurs).
