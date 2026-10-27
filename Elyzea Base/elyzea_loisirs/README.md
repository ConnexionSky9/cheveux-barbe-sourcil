# elyzea_loisirs : bowling, billard, golf

Loisirs multijoueurs pour la base Elyzea :

- **Bowling** : 10 frames, règles officielles, 1 à 6 joueurs.
- **Billard** : 8-ball, 2 joueurs.
- **Golf** : stroke play, 1 à 4 joueurs, 1 à 18 trous.

Le **serveur** calcule chaque coup (physique et règles). Les joueurs proches rejouent exactement la même trajectoire, avec la même graine aléatoire. Un client ne peut donc ni inventer un score ni déplacer une boule.

Les pistes, les tables et les parcours se posent **en jeu**, depuis le **menu admin**, onglet **Économie et services › Loisirs**.

## Installation

1. Copier le dossier `elyzea_loisirs` dans `Elyzea Base/`.
2. Remplacer ou ajouter ces fichiers d'`admin_menu` (ils sont dans le zip) :
   - `server/loisirs.lua` (nouveau) ;
   - `html/loisirs.js` (nouveau) ;
   - `fxmanifest.lua` : 2 lignes ajoutées ;
   - `html/index.html` : 1 ligne ;
   - `html/script.js` : onglet ajouté à la catégorie Économie ;
   - `permissions_extra.lua` : permission `loisirs_manage` ;
   - `server/main.lua` : la permission est donnée au SuperAdmin une seule fois.

   **`admin_menu/config.lua` n'est pas touché** : la permission y est ajoutée automatiquement par `permissions_extra.lua`.
3. Dans `server.cfg`, ajouter la ligne **après** `elyzea_core` et `admin_menu` :
   ```
   ensure elyzea_core
   ...
   ensure admin_menu
   ensure elyzea_loisirs
   ```
4. Redémarrer le serveur, ou faire `refresh` puis `ensure admin_menu` puis `ensure elyzea_loisirs`.
5. La table SQL `loisirs_installations` est créée toute seule au démarrage. Aucun fichier SQL n'est à importer.
6. Le Fondateur a l'onglet d'office et le SuperAdmin le reçoit automatiquement. Pour un autre grade, cocher **Loisirs** (`loisirs_manage`) dans l'éditeur de grades.

## Placer les installations (menu admin › Loisirs)

Le jeu de base n'a **ni bowling, ni parcours de golf jouable, ni animation de billard**. Toutes les positions sont donc à poser en jeu : il n'y a aucune coordonnée à écrire dans la config.

### Bowling

Tiens-toi **sur la ligne de faute**, au milieu de la piste, **tourné vers les quilles**, puis clique **Poser la piste ici**.

- Les quilles sont posées 18,29 m devant toi : c'est la distance réglementaire de 60 pieds.
- Il faut un sol plat d'environ 23 m : un MLO de bowling, un hangar ou un parking.
- Une piste par installation. Pose-en plusieurs côte à côte, à 1,9 m d'écart, pour une salle.

**Ton MLO a déjà des quilles ?** Tiens-toi derrière la ligne de faute, regarde vers elles et clique **Aligner sur les quilles du décor**.
La piste est calée exactement sur la quille de tête du décor (même axe, ligne de faute 18,29 m avant elle).
Pendant le jeu, les quilles du décor au fond de la piste sont **cachées** pour laisser place aux vraies quilles qui tombent.

- Cela marche si les quilles du MLO sont des objets séparés. Par défaut, le modèle cherché est `prop_bowling_pin` (`hideModels` dans `config.lua`).
- Si ton MLO utilise un autre modèle : place-toi près des quilles, tape `/loisirs_objets`, puis ouvre la console F8.
  Elle liste les objets proches avec leur numéro (hash) ; ajoute ce numéro dans `hideModels`.
- Si les quilles sont dessinées dans le décor lui-même (pas des objets), elles ne peuvent pas être cachées.

### Billard

Deux façons de poser une table :

- **Table neuve** : elle est posée 1,6 m devant toi, dans l'axe de ton regard. Modèle `prop_pooltable_02` ou `prop_pooltable_3b`.
- **Table du jeu la plus proche** : approche-toi à moins de 4 m d'une table déjà sur la carte (bars, villas). Elle est reprise telle quelle.

Si les billes ne sont pas posées sur le tapis, corrige la longueur, la largeur ou la hauteur du tapis dans la fiche de la table. Laisse vide pour garder les valeurs de `config.lua`.

### Golf

1. Clique **Créer le parcours**. Le golf de Los Santos, près de Richman, convient très bien.
2. Pour chaque trou, tiens-toi au **départ**, tourné vers le drapeau, puis clique **Nouveau trou (départ ici)**.
3. Marche jusqu'au **trou** et clique **Drapeau ici**. Il doit être à plus de 20 m du départ.
4. Règle le **par** (3 à 6), le **rayon du green** et la **largeur du fairway**.
5. Ajoute des **zones** en te tenant à leur centre, avec un rayon :

   | Zone | Effet |
   |---|---|
   | Eau | +1 coup, la balle est reposée près du point d'entrée |
   | Bunker | Le coup suivant est plus court |
   | Hors limites | +1 coup, rejouer du point précédent |
   | Balle perdue | +1 coup, rejouer du point précédent |

   Tout ce qui n'est ni green, ni fairway, ni zone compte comme du **rough**.
   Au-delà du fairway + 45 m de chaque côté, 25 m derrière le départ ou 45 m après le drapeau, la balle est **hors limites** automatiquement
   (`roughWidth`, `behindTee`, `beyondFlag` dans `config.lua`).

Un parcours dont un trou n'a pas de drapeau ne peut pas être joué : l'onglet le signale en rouge.

### Autres actions de l'onglet

Pour chaque installation : renommer, **Y aller**, supprimer. Supprimer annule et rembourse une partie en cours.

La page **Parties en cours** liste toutes les parties et permet de les annuler.

## Jouer

Approche-toi d'une piste, d'une table ou du départ du trou 1, puis appuie sur **E**.

- Le salon permet de créer une partie : nom, privée, mot de passe, nombre de joueurs.
- On peut aussi rejoindre une partie existante, inviter un joueur par son ID ou en exclure un (pour l'hôte).
- L'onglet **Règles** du salon explique les règles appliquées.

Les touches ci-dessous sont en QWERTY ; en AZERTY, A/W/Q deviennent Q/Z/A.

| Jeu | Touches |
|---|---|
| Bowling | A / D : pas de côté · Q / E : angle · W / S : effet · ESPACE maintenu puis relâché : puissance |
| Billard | Souris ou A / D : viser · Q / E : réglage fin · ESPACE : puissance · C : vue de dessus |
| Billard, blanche en main | W / S / A / D : déplacer la blanche · E : valider |
| Golf | A / D : direction · molette : club · W / S : effet · ESPACE : swing · C : caméra · G : balle injouable (+1) |

Au bowling :

- **A / D** fait faire au personnage de **vrais pas de côté** (animation du jeu `move_strafe@reposition`) : il reste face à la piste. Maintenir la touche enchaîne les pas.
- Une **flèche bleue** posée sur la piste montre la direction visée. Elle se courbe selon l'effet (W / S).
- Après le lâcher, la **caméra suit la boule**, puis s'arrête devant les quilles pour les voir tomber, avant de rendre la main.
  Les joueurs de la partie la voient aussi ; les simples spectateurs non.
- Chaque quille touchée **bascule dans le sens où elle a été poussée** et se couche au sol.

`/loisirs_quitter` quitte la partie en cours.

## Règles appliquées

**Bowling**

- Strike : 10 + les 2 lancers suivants.
- Spare : 10 + le lancer suivant.
- 10e frame : jusqu'à 3 lancers.
- Score maximum : 300.

**Billard 8-ball**

- Casse : 4 bandes minimum, sinon c'est une faute.
- Noire rentrée sur la casse : la table est remise en place.
- Les groupes (pleines ou rayées) sont attribués à la première bille rentrée après la casse.
- Fautes, avec blanche en main n'importe où pour l'adversaire :
  - blanche rentrée ;
  - mauvaise bille touchée en premier ;
  - aucune bande après le contact.
- Noire rentrée trop tôt ou avec une faute : partie perdue.

**Golf (stroke play)**

- Chaque coup compte.
- Ordre de jeu : honneur au départ, puis le joueur le plus loin du trou joue.
- Pénalités : eau, hors limites et balle perdue (+1), balle injouable (+1).
- Un trou est arrêté à **par + 6** pour ne pas bloquer les autres (réglable).

## Sécurité et robustesse

- Le serveur valide tout : il faut être à son tour, à moins de quelques mètres, et le numéro de coup (`seq`) doit être le bon.
- Les coups trop rapprochés sont limités et les valeurs sont bornées (angle, puissance, effet).
- Les positions des installations viennent du serveur (`GetEntityCoords`), jamais du client.
- Les droits d'entrée (`price` dans `Config.Games`, 0 par défaut) sont débités à l'inscription. Ils sont remboursés si la partie est annulée avant le départ, si le joueur se déconnecte avant le départ ou si la ressource est arrêtée.
- Un joueur trop loin, à terre ou déconnecté est retiré après un délai de grâce.
- Un joueur inactif perd son tour, puis est retiré après 2 tours manqués.
- Une partie trop longue est arrêtée.
- Un joueur ne peut être que dans **une** partie à la fois.
- Une installation n'accueille qu'**une** partie à la fois.

## Réglages (`config.lua`)

- Jeux : activé, joueurs min et max, prix, compte (`cash` ou `bank`).
- Délais : salon, démarrage, temps par coup, inactivité, distance d'abandon, durée maximale.
- Physique du bowling : rebonds, frottements, chute des quilles.
- Billard :
  - dimensions des tables ;
  - frottements ;
  - règles : bandes à la casse, noire sur la casse, blanche en main.
- Golf :
  - clubs : vitesse, loft, courbe ;
  - lies : départ, fairway, rough, bunker, green ;
  - traînée et portance ;
  - imprécision ;
  - plafond de coups ;
  - pénalités.
- Animations, modèles et touches.

Toutes les animations et tous les modèles de la config ont été vérifiés dans les listes du jeu (dumps DurtyFree) :

- `mini@golf` ;
- `weapons@projectile@` ;
- `move_strafe@reposition` (`step_short_90_face_0`, `step_short_-90_face_0`) ;
- `anim@heists@box_carry@` ;
- `anim@amb@business@coc@coc_unpack_cut_left@` ;
- `prop_bowling_*`, `prop_poolball_*`, `prop_pool_cue`, `prop_golf_*`.

## Tests hors jeu

Depuis `elyzea_loisirs/` :

```
pip install lupa
python3 tests/run_tests.py           # règles, physique, serveur, pont admin, bout en bout (Lua 5.4)
node tests/ui.cjs <dossier>          # interface joueurs (Playwright)
node tests/admin_ui.cjs <dossier>    # onglet Loisirs du menu admin (Playwright)
```

Ces tests tournent **hors du jeu** :

- les fonctions FiveM, MySQL et elyzea_core sont imitées ;
- les vrais fichiers de la ressource et d'`admin_menu/server/loisirs.lua` sont chargés.

Ils ne remplacent pas un essai en jeu.

## Procédure de test en jeu (à faire)

1. **Démarrage.** `ensure elyzea_loisirs`. La console ne doit afficher aucune erreur et la table `loisirs_installations` doit exister.
2. **Bowling.**
   - Poser une piste dans le menu admin.
   - Vérifier que 10 quilles apparaissent à 18 m, dans l'axe, posées sur le sol.
   - Dans un MLO avec ses propres quilles : utiliser « Aligner sur les quilles du décor » et vérifier qu'il n'y a pas de quilles en double.
   - A / D : le personnage fait des pas de côté en restant face à la piste, sans glisser. Note si un pas part du mauvais côté :
     le client le corrige tout seul dès le premier pas.
   - La flèche bleue est visible sur la piste et bouge avec Q / E et W / S.
   - Après le lancer, la caméra suit la boule puis montre les quilles tomber.
   - Faire **E**, créer une partie, la démarrer seul.
   - Jouer 3 frames : boule en main, lancer animé, quilles qui tombent, score à jour.
   - Faire un strike ou un spare pour voir le message.
3. **Bowling à 2.**
   - Un 2e joueur rejoint la partie.
   - Il voit les mêmes quilles tomber au même moment.
   - Le tour passe bien d'un joueur à l'autre.
4. **Billard.**
   - Poser une table neuve, puis reprendre une table existante d'un bar.
   - Vérifier que les billes sont **sur le tapis**. Sinon, calibrer la hauteur.
   - Partie à 2 :
     - casse ;
     - attribution des groupes ;
     - faute sur la blanche, puis replacement avec W/A/S/D ;
     - fin sur la noire.
5. **Golf.**
   - Créer un parcours de 2 trous avec une zone d'eau.
   - Jouer :
     - choix du club à la molette ;
     - swing ;
     - balle qui suit le relief ;
     - pénalité dans l'eau ;
     - putt et balle dans le trou ;
     - carte de score finale.
6. **Abandons.**
   - S'éloigner de plus de 30 m pendant une partie : retrait après le délai.
   - Se déconnecter : la partie continue pour les autres.
   - Ne pas jouer : tour perdu.
7. **Admin.**
   - Annuler une partie depuis l'onglet.
   - Supprimer une installation pendant une partie : elle est annulée et remboursée.
   - Vérifier qu'un grade sans `loisirs_manage` ne voit pas l'onglet.

## Limites connues

- **Pas de lieu prêt dans le jeu de base** pour le bowling ni pour le golf. Les pistes et les trous se posent à la main, et l'enveloppe du bowling (murs, salle) dépend de ton MLO.
- **Bowling, chute des quilles** : le sens de bascule (vers l'avant de leur mouvement) n'a pas pu être vérifié en jeu.
  Si les quilles tombent vers le lanceur au lieu du fond, il faut inverser le signe de `-88.0` dans `client/bowling.lua` (fonction `pinPose`).
- **Bowling, pas de côté** : si l'animation du jeu ne déplace pas le personnage, le client le fait glisser pendant le pas (détecté au premier pas).
- **Golf** :
  - le serveur simule le terrain comme un plan entre départ et drapeau, et le green comme plat ;
  - chez le joueur, la balle est recollée au vrai sol ;
  - les pentes très fortes peuvent donc donner un rebond un peu différent de ce que l'œil attend.
- **Billard** :
  - pas d'effet latéral (english) ;
  - pas d'annonce de poche (« bille 8 dans le coin ») ;
  - la blanche en main n'est visible que par celui qui la place, jusqu'à validation ;
  - la pose penchée sur la table est une animation existante détournée : il n'existe aucune animation de billard dans GTA ;
  - la hauteur du tapis peut demander un calibrage selon la table.
- **Golf, position du joueur** : le décalage du joueur à côté de la balle peut demander un ajustement (`stanceOffset` et `stanceHeight` dans `config.lua`) selon le rendu en jeu.
