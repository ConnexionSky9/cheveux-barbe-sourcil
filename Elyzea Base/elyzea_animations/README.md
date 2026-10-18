# Elyzea : menu des animations

Menu d'animations pour le serveur Elyzea RP. Il s'ouvre avec **K**, l'animation s'arrête avec **X**, et les favoris peuvent recevoir leur propre touche de raccourci.

Les danses sont dans ce même menu, quatre catégories en tête : **Danses lentes**, **Danses en duo**, **Danses en groupe** et **Danses solo** (voir la section « Danses » plus bas et `docs/DANSES.md`).

## Contenu du dossier

```
elyzea_animations/
├── fxmanifest.lua      Déclaration de la ressource
├── client.lua          Touches, raccourcis, animations partagées, lien avec ton script d'emotes
├── server.lua          Envoi des demandes d'animations partagées entre joueurs
├── shared_emotes.lua   Liste des animations partagées de rpemotes et de leur partenaire
├── anim_data.lua       Données des animations (aperçu 3D et vérification)
├── README.md           Ce fichier
├── html/
│   └── index.html      L'interface (menu, logo, liste des animations)
├── danses/             Danses à deux et en groupe
│   ├── config.lua      Réglages (invitations, groupes, distances)
│   ├── catalog.lua     Liste des danses lentes, duo et groupe, avec leurs positions
│   ├── client/         Lecture, positionnement, danse en cours, calibrage
│   └── server/         Invitations, consentement, sessions, sécurité
├── docs/               DANSES.md (catalogue, vidéos, limites), TESTS.md (résultats, test à deux)
└── tests/              Tests hors jeu (pas chargés par FiveM)
```

## Prérequis

Le menu utilise **rpemotes** (version nox-rpemotes) pour jouer les animations. Toutes ses animations sont déjà listées dans le menu : environ 1 500, réparties en 14 catégories.

rpemotes doit être installé et fonctionnel. Vérifie en jeu que `/e wave` marche avant d'installer le menu.

**Sécurité de lancement.** Le menu utilise d'abord la commande de rpemotes. Après chaque animation classique, il vérifie que l'animation a réellement démarré. Si rpemotes n'a pas lancé l'animation (cas fréquent après un placement ou un déplacement), Elyzea la lance directement avec ses données et gère aussi les objets attachés. L'arrêt supprime également ces objets de secours.

## Installation

1. Décompresse le zip et place le dossier `elyzea_animations` dans le dossier `resources` de ton serveur. Tu peux le mettre dans un sous-dossier, par exemple `resources/[elyzea]/elyzea_animations`.

2. Ouvre ton `server.cfg` et ajoute la ligne suivante **après** ton script d'emotes :

   ```
   ensure rpemotes
   ensure elyzea_animations
   ```

   Remplace `rpemotes` par le nom exact du dossier de ton script d'emotes. Le zip s'appelle `nox-rpemotes-master` : renomme le dossier en `rpemotes`, c'est le plus simple.

3. Redémarre le serveur, ou tape dans la console :

   ```
   refresh
   ensure elyzea_animations
   ```

4. En jeu, appuie sur **K** : le menu s'ouvre.

## Réglages

En haut de `client.lua`, la partie `Config` :

```lua
local Config = {
    EmoteCommand   = 'e',           -- animations : /e wave
    WalkCommand    = 'walk',        -- démarches : /walk Casual
    MoodCommand    = 'mood',        -- humeurs : /mood Happy
    CancelCommand  = 'emotecancel', -- arrêter l'animation
    DefaultOpenKey = 'K',
    DefaultStopKey = 'X',
    AcceptKey      = 'Y',           -- accepter une demande d'animation partagée
    RefuseKey      = 'N',           -- refuser une demande
    NearbyRadius   = 3.0,           -- distance max (mètres) pour les animations partagées
    PreviewCam = {                  -- caméra de l'aperçu 3D
        side   = 1.1,               -- décalage sur le côté
        dist   = 3.3,               -- distance (plus grand = perso plus petit)
        height = 0.15,              -- hauteur
        fov    = 50.0,              -- angle de vue
    },
}
```

Ces commandes sont celles de rpemotes, tu n'as normalement rien à changer.

**Touche du menu rpemotes.** rpemotes ouvre aussi son propre menu (F3 par défaut). Si tu veux que les joueurs n'utilisent que le menu Elyzea, mets `MenuKeybindEnabled = false` dans le `config.lua` de rpemotes.

## Utilisation en jeu

| Action | Comment |
|---|---|
| Ouvrir ou fermer le menu | **K** (ou Échap pour fermer) |
| Arrêter l'animation | **X**, même menu fermé, ou le bouton Arrêter |
| Chercher une animation | Barre de recherche, par nom ou par commande |
| Mettre en favori | L'étoile en haut à droite d'une animation |
| Assigner une touche | Onglet Favoris, bouton « + Touche », puis appuie sur la touche voulue |
| Retirer une touche | Clique sur la touche assignée, puis « Retirer la touche » |
| Animation à deux | Onglet Partagées : choisis un joueur proche, il reçoit une demande |
| Accepter une demande | **Y** (ou le bouton Accepter si ton menu est ouvert) |
| Refuser une demande | **N** (ou le bouton Refuser) |
| Placer une animation où je veux | Clic droit sur une animation, ou l'icône flèches en bas à droite de la case |
| Déplacer l'animation en cours | **J** (menu fermé), ou `/placer` |
| Paramètres | L'icône engrenage en haut du menu |

Touches acceptées pour les raccourcis : chiffres, F1 à F12, pavé numérique et lettres libres. Les touches du jeu (ZQSD, WASD, E, F, G, R, T, C, V, Espace, Tab) sont bloquées pour éviter les conflits.

Les réglages et raccourcis sont sauvegardés pour chaque joueur et restent après une déconnexion. Ils apparaissent aussi dans **Paramètres GTA > Raccourcis > FiveM**, sous le nom « Elyzea animations ».

## Aperçu 3D

Quand tu ouvres le menu, la caméra se place devant ton personnage. Quand tu survoles une animation, il la fait en boucle, en entier, avec ses objets. Tu vois donc exactement le résultat avant de cliquer.

Comment ça marche : une copie de ton personnage, visible seulement par toi, prend ta place pendant que le menu est ouvert. Les autres joueurs te voient normalement, debout, tant que tu n'as pas lancé d'animation. Quand tu fermes le menu, la caméra revient derrière toi et la copie disparaît.

- Le personnage s'affiche du côté opposé au menu (menu à gauche par défaut, perso à droite).
- L'aperçu est désactivé dans un véhicule.
- Tu peux le couper dans les paramètres du menu (« Aperçu 3D »).
- Pour régler le cadrage, change `PreviewCam` dans `client.lua` (par exemple `dist = 4.0` pour voir le perso plus petit).

Dans l'aperçu web (hors jeu), un mannequin doré remplace ton personnage, juste pour montrer l'emplacement.

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

Ça ne marche que pour les animations classiques (`/e`) : pas pour les démarches, les humeurs, les animations partagées (rpemotes place déjà les deux joueurs) ni en véhicule.

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

**Note.** `/placer` et **J** ne connaissent que les animations lancées par le menu, un raccourci ou `/placer`. Une animation tapée directement avec `/e` ne peut pas être déplacée avec **J** : utilise `/placer nomdelanimation` à la place.

## Animations masquées automatiquement

Le menu ne montre que les animations que tu peux vraiment faire :

- **Fichiers manquants** : au démarrage, le menu vérifie chaque animation et chaque objet. Si un fichier n'existe pas (fichier absent de rpemotes, version du jeu trop ancienne), l'animation est masquée. Tape `elyzea_anim_check` dans la console F8 pour voir la liste.
- **Véhicule** : les animations « seulement en véhicule » n'apparaissent que quand tu es dans un véhicule, et celles interdites en véhicule disparaissent quand tu y montes.
- **Sexe du personnage** : les animations prévues pour l'autre sexe (« Female », « Male » dans leur nom) sont masquées. Désactivable dans les paramètres (« Masquer l'autre sexe »).

Si beaucoup d'animations sont masquées pour fichiers manquants, vérifie la version du jeu dans `server.cfg` (par exemple `sv_enforceGameBuild 3095`) : certaines animations de rpemotes viennent de mises à jour récentes de GTA.

## Animations partagées

Quand tu choisis une animation à deux et un joueur, celui-ci reçoit une fenêtre en haut de son écran avec ton nom et l'animation proposée. Il a 15 secondes pour appuyer sur **Y** (accepter) ou **N** (refuser).

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

**Comment les animations sont jouées.** Une fois la demande acceptée dans le menu Elyzea, c'est rpemotes qui place les deux joueurs et lance les deux animations synchronisées (porter, câlin, poignée de main, etc.). Le fichier `shared_emotes.lua` indique, pour chaque animation, celle que joue l'autre joueur (par exemple `carry` pour celui qui porte, `carry2` pour celui qui est porté).

La distance maximale est de 3 mètres, comme dans rpemotes.

## Personnaliser

**Ajouter ou modifier des animations.** Ajoute d'abord l'animation dans rpemotes (fichier `client/AnimationListCustom.lua`) et vérifie qu'elle marche avec `/e`. Ensuite, dans `html/index.html`, cherche `const EMOTES`. Chaque catégorie est une liste au format :

```
["Nom affiché","commande"]
```

Ajoute ta ligne dans la catégorie voulue, par exemple dans `"objets":[...]` : `["Ma pancarte","mapancarte"]`. Respecte les virgules entre les entrées.

Préfixes à utiliser selon le type :

| Type | Préfixe | Exemple |
|---|---|---|
| Animation classique | aucun | `["Saluer","wave"]` |
| Animation partagée | `nearby_` | `["Câlin","nearby_hug"]` |
| Démarche | `walk_` | `["Gangster","walk_Gangster"]` |
| Humeur | `mood_` | `["Heureux","mood_Happy"]` |

Pour une nouvelle animation partagée, ajoute aussi une ligne dans `shared_emotes.lua` : `["moncalin"] = "moncalin2",` (l'animation de l'autre joueur, ou la même).

Les catégories (nom, icône, description) se règlent juste en dessous, dans `const META`. Les icônes viennent de lucide.dev.

**Animations exclues.** Les 35 animations marquées « adulte » dans rpemotes et les animations d'animaux (désactivées par défaut dans rpemotes) ne sont pas dans le menu. Les animations adultes restent utilisables avec `/e` si rpemotes les autorise (`AdultEmotesDisabled` dans son `config.lua`).

**Noms en anglais.** Les noms des animations sont ceux de rpemotes, en anglais. Tu peux les traduire directement dans `const EMOTES` : seul le premier texte est affiché, la commande ne change pas.

**Changer le logo.** Le logo est intégré dans `index.html` (ligne `<img src="data:image/webp;base64,...">`). Pour le remplacer, place une image `logo.png` dans le dossier `html`, ajoute-la dans `fxmanifest.lua` :

```lua
files { 'html/index.html', 'html/logo.png' }
```

puis remplace la source de l'image par `src="logo.png"`.

**Changer les couleurs.** En haut du `<style>` de `index.html`, les variables `--gold`, `--blue` et `--red` définissent l'ambiance du menu.

## Problèmes fréquents

**Le menu ne s'ouvre pas avec K.**
Vérifie que la ressource démarre bien (`ensure elyzea_animations` dans la console, aucune erreur en F8). Si K est déjà utilisée par un autre script, change la touche dans les paramètres du menu ou dans Paramètres GTA > Raccourcis > FiveM.

**Le menu s'ouvre mais l'animation ne se lance pas.**
Vérifie que rpemotes est démarré avant le menu dans `server.cfg`, et teste la commande affichée sous l'animation directement dans le chat (par exemple `/e wave`). Si elle ne marche pas non plus, le problème vient de rpemotes.

**Les icônes du menu n'apparaissent pas.**
Elles sont chargées depuis internet (jsdelivr). Le menu fonctionne quand même, seules les icônes manquent.

**Je ne peux plus bouger, la souris reste affichée.**
Appuie sur Échap. Si ça persiste, tape `restart elyzea_animations` dans la console F8.

**La demande partagée n'arrive pas à l'autre joueur.**
Vérifie que `server.lua` est bien chargé (il est déclaré dans `fxmanifest.lua`) et que vous êtes à moins de 3 mètres. Regarde la console serveur pour une éventuelle erreur.

**Y ou N ne font rien.**
Un autre script utilise peut-être ces touches. Change-les dans Paramètres GTA > Raccourcis > FiveM (« accepter une demande » et « refuser une demande »), ou dans `Config.AcceptKey` et `Config.RefuseKey`.

**Je reste bloqué sur place après un placement.**
Appuie sur **X** ou avance avec **Z**. Si ça persiste, tape `restart elyzea_animations` dans la console F8 : le personnage est libéré.

**J ne fait rien.**
Un autre script utilise peut-être cette touche. Change-la dans Paramètres GTA > Raccourcis > FiveM, ou utilise `/placer`.

**Une touche changée ne prend pas effet.**
FiveM garde en mémoire les raccourcis déjà créés. Va dans Paramètres GTA > Raccourcis > FiveM et vérifie la touche liée à « Elyzea animations ».

## Danses

Tout se passe dans ce menu (pas d'autre menu à ouvrir).

| Catégorie | Utilisation |
|---|---|
| Danses lentes / Danses en duo | Clic sur la danse, choix de son rôle (« je reste sur place » ou « je viens me placer ») puis de la personne (moins de 3 m). Elle reçoit la demande en haut de l'écran : **Y** accepter, **L** refuser. Si elle accepte, le serveur revérifie tout, la personne marche jusqu'à sa place, puis la danse démarre chez les deux en même temps. |
| Danses en groupe | Clic sur la danse, cocher les participants (moins de 8 m, 8 danseurs maximum), choisir **en ligne** ou **en cercle**, « Inviter et danser ». La danse démarre quand tout le monde a répondu (ou tout de suite avec `/danse_lancer`). |
| Danses solo | Comme toutes les animations du menu. |

Arrêter ou quitter : **X**, `/stopanim`, ou avancer. En groupe, un participant qui part laisse les autres continuer ;
si le meneur part, la danse s'arrête pour tous. Une déconnexion, un véhicule, des menottes, un état « à terre » ou un
éloignement arrêtent aussi la danse proprement : personne ne reste attaché ni bloqué.

Une danse dont un fichier d'animation manque est masquée automatiquement (`elyzea_anim_check` en F8).

**Staff** (permission `admin` de `group.admin`, ou `add_ace group.mod elyzea_animations.admin allow`) :
- `/danse_calib` pendant une danse à deux, dans le rôle de celui qui vient se placer : corriger la position (flèches,
  Page ↑/↓, molette, Maj = fin, Entrée enregistre pour tout le monde).
- `/danse_valider <id>` après un essai réussi, `/danse_reset <id>` pour revenir aux positions d'origine.

**Diagnostic** : `animdiag` en F8 écrit la version de rpemotes trouvée, les touches, le nombre d'animations masquées
et l'état en cours. Envoie-moi ce texte si quelque chose ne marche pas.

Réglages : `danses/config.lua`. Ajouter une danse : copier une fiche de `danses/catalog.lua`.

**Animations partagées et rpemotes récent.** Le menu prévient maintenant les deux versions de rpemotes (anciens
événements `SyncPlayEmote` et `rpemotes:client:syncEmote` de rpemotes-reborn) : les animations partagées fonctionnent
avec l'une comme avec l'autre.
