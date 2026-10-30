# elyzea_club : boîtes de nuit (plusieurs établissements)

Chaque boîte de nuit a **son propre métier**, avec :

- son compte de société ;
- ses grades et ses permissions ;
- son personnel ;
- sa carte du bar ;
- ses enceintes et sa playlist.

On peut en créer autant que l'on veut (Galaxy, Bahama Mamas, Tequi-la-la…).

> **État : écrit et vérifié hors jeu uniquement.**
> Une simulation serveur (2 boîtes, 7 joueurs imités, 120 vérifications) et des tests de l'interface dans un navigateur (31 vérifications) passent.
> **Rien n'a été testé sur un vrai serveur FiveM.** Suivez la liste « Tests à faire en jeu ».

## Ressources réutilisées

| Besoin | Utilisé |
|---|---|
| Métier, grades, argent, comptes de société | `elyzea_core` (même socle que les concessions, Dynasty 8, mécano) |
| Boissons | objets **déjà déclarés** dans `elyzea_inventory` : `nc_mojito`, `nc_whiskycoca`, `nc_vodkaenergy`, `nc_shot`, `nc_coupe`, bouteilles `nc_champagne` / `nc_whisky` / `nc_vodka` / `nc_rhum`, `nc_soda`, `nc_energy` |
| Coffre | `elyzea_inventory` (coffre `club:<id>`, accès revérifié à chaque ouverture) |
| Staff | `admin_menu` : permission `club_manage`, onglet **Boîtes de nuit** (ou `/clubadmin`) ; **Mes outils › Métier staff** (permission `staff_job`) : une entrée 🪩 par boîte |
| Téléphone de service | `elyzea_jobphone` : unité « Boîte de nuit », numéros en 917 |
| Liens YouTube | même lecture des liens que `elyzea_tv` (YouTube seulement) |

## Installation

1. Copier `elyzea_club` dans `Elyzea Base/`.
2. Remplacer ou ajouter ces fichiers (ils sont dans le zip) :
   - `admin_menu/client/club.lua` et `admin_menu/html/club.js` (nouveaux) ;
   - `admin_menu/fxmanifest.lua` (2 lignes) et `admin_menu/html/index.html` (1 ligne) ;
   - `admin_menu/permissions_extra.lua` (permission `club_manage`) ;
   - `admin_menu/server/main.lua` (la permission est donnée au SuperAdmin une seule fois) ;
   - `elyzea_jobphone/config.lua` (1 ligne : la boîte de nuit dans le téléphone de service).

   **`admin_menu/config.lua` n'est pas touché.**
3. Dans `server.cfg`, **après** `elyzea_inventory` et `admin_menu`, **avant** `elyzea_jobphone` :
   ```
   ensure elyzea_club
   ```
4. Redémarrer. Les tables `cl_*` sont créées toutes seules (`sql/install.sql` pour une installation manuelle).

## Créer une boîte (staff)

Menu admin › **Boîtes de nuit** › Ouvrir (ou `/clubadmin`) :

1. **+ Nouvelle boîte** : nom, adresse.
   - Le métier et le compte sont créés automatiquement, ou vous choisissez leurs noms.
   - La boîte reçoit 5 grades : Serveur, Videur, DJ, Gérant, Patron.
   - Sa carte du bar est créée avec 20 unités de chaque boisson en stock.
2. **Points** : placez-vous au bon endroit, puis « Placer ici ».

   | Point | Rôle | Obligatoire |
   |---|---|---|
   | Entrée | Les clients y entrent | Oui |
   | Bar | Les serveurs y encaissent, les clients y voient la carte | Oui |
   | Intérieur | Payer l'entrée téléporte dedans ; E dedans ressort | Non |
   | Coffre | Coffre de la boîte | Non |
   | Bureau | Ouvrir la tablette | Non |
3. **👑 Nommer le patron** (ID du joueur), puis **Activer**.

Le staff peut aussi :

- **désactiver** une boîte : bar, entrée et musique sont suspendus, rien n'est effacé ;
- **supprimer** une boîte : les employés sont retirés du métier, les ventes et les finances sont gardées ;
- retirer une enceinte ;
- couper la musique.

## Métier staff (admin_menu)

Menu admin › Mes outils › **Métier staff** : chaque boîte a son bouton (🪩 Galaxy, 🪩 Bahama Mamas…).

- **Cliquer un grade** : le staff entre dans cette boîte à ce grade et passe en service. Son vrai métier est gardé.
- **Prendre / quitter le service**.
- **Recruter / changer le grade** d'un joueur connecté, ou le **retirer** de la boîte.
- **Revenir à mon métier d'origine** : le staff est retiré de la boîte.
- Une personne ne peut être que dans **une** boîte : la mettre dans une autre boîte la retire de la première (c'est indiqué dans le message).
- Tout est inscrit dans l'historique du personnel de la boîte (« Staff (menu admin) »).

## Ce que fait le patron

Tout se fait dans la **tablette** (F6 › Tablette, ou le point Bureau) et le **menu F6**.

### Entrée

- **Ouvrir / fermer au public**, et régler le **prix d'entrée** (0 = gratuit).
- **Bracelets** : payer l'entrée donne un bracelet valable 4 h. On peut sortir et revenir sans repayer.
- **Liste VIP** : entrée gratuite.
- **Liste noire** : interdit d'entrée, pour une durée en jours ou définitivement.
- **Contrôle du videur** (F6 › Contrôler la personne proche) : le videur voit le bracelet, si la personne est VIP ou sur la liste noire. Il peut la raccompagner à la sortie, l'ajouter à la liste VIP ou l'interdire.

### Bar

- La **carte** : prix de chaque boisson, retirer ou remettre une boisson.
- Le **stock** : commandé avec l'argent de la boîte, au prix d'achat de `Config.Drinks`.
- **Servir** (point Bar, en service) :
  1. le serveur choisit le client proche et les boissons ;
  2. le client voit la commande et paie par carte ou en espèces ;
  3. les boissons arrivent dans son inventaire.

  Le serveur revérifie tout : prix, stock, place dans l'inventaire, argent.
- Les clients peuvent consulter **la carte** (E au bar).

### Musique

Voir la partie « Enceintes et musique » plus bas.

### Le reste

- **Annonce à toute la ville** : un bandeau en haut de l'écran de tous les joueurs, une annonce toutes les 10 minutes au plus.
- **Coffre** de la boîte.
- **Personnel** :
  - recruter (la personne la plus proche accepte ou refuse) ;
  - promouvoir, rétrograder, renvoyer ;
  - modifier les fiches ;
  - consulter l'historique.
- **Grades et permissions** : le patron coche, grade par grade, ce que chacun peut faire.
- **Finances** :
  - compte de la boîte ;
  - recettes du bar et des entrées, achats de stock ;
  - salaires horaires payés au temps de service ;
  - **commission** en % sur les commandes servies au bar.
- **Tableau de bord** : chiffre du jour et de la semaine, équipe en service, stock bas, musique en cours.

## Enceintes et musique

- **Poser une enceinte** (F6 › Poser une enceinte, ou la tablette › Musique) :
  1. choisissez le modèle : grande, moyenne ou petite enceinte de club, enceinte sur pied, enceinte de sono, ou « invisible » si la carte a déjà des enceintes ;
  2. l'enceinte suit votre regard : clic gauche (ou Entrée) pour la poser, A / E pour la tourner, Retour pour annuler.

  10 enceintes au plus par boîte.
- **Les enceintes appartiennent à la boîte qui les a posées.**
  - Seuls les employés de **cette** boîte peuvent les utiliser ou les retirer.
  - Une autre boîte ne peut ni les retirer ni toucher à leur musique, même tout à côté.
- **Le patron choisit quels grades ont le droit de mettre de la musique** : tablette › Direction › **Permissions** › « Utiliser les enceintes ».
  - Par défaut : DJ, Gérant et Patron.
  - Une deuxième permission, « Poser et retirer les enceintes », est réglée de la même façon.
- **Platine DJ** (E près d'une enceinte, F6 › Platine DJ, ou tablette › Musique) :
  - **playlist** de liens YouTube : collez-en un ou plusieurs (un par ligne) ;
  - réordonner la playlist, retirer un titre, la vider ;
  - lecture, pause, titre précédent ou suivant, couper ;
  - aléatoire, lecture en boucle ;
  - **volume** des enceintes et **portée** du son (8 à 120 m).

  La playlist **défile toute seule** : à la fin d'un titre, le suivant démarre. Une vidéo que YouTube interdit de lire hors de son site est **sautée** et marquée dans la liste.
- Pour piloter la lecture, il faut être à moins de 60 m d'une enceinte de la boîte. La playlist se modifie de partout.
- **Ce qu'entendent les joueurs** :
  - tous les joueurs proches entendent **la même musique au même moment** (heure commune du serveur) ;
  - le son baisse avec la distance à l'enceinte la plus proche ;
  - au-delà de la portée, la musique s'arrête pour ce joueur ;
  - `/musique 0-100` règle son volume personnel des boîtes de nuit.

## Commandes

| Commande | Effet |
|---|---|
| `F6` / `/club_menu` | Menu rapide des employés (ou le téléphone de service s'il remplace F6) |
| `/clubadmin` | Panneau staff |
| `/musique 0-100` | Volume personnel des boîtes de nuit |
| `/club_debloquer` | Rend le curseur |
| `/club_pos` | Position et cap dans la console F8 |

## Tests hors jeu

Depuis `elyzea_club/` :

```
pip install lupa
python3 tests/run_tests.py          # serveur : 2 boîtes, bar, entrée, listes, enceintes, permissions, playlist (120 vérifications)
node tests/ui.cjs <dossier>         # interface : F6, bar, commande, carte, entrée, annonce, platine, tablette, staff (31 vérifications)
```

## Tests à faire en jeu (aucun n'a été fait)

1. **Démarrage** : aucune erreur, tables `cl_*` créées, onglet « Boîtes de nuit » visible au SuperAdmin.
2. **Mise en place** : créer 2 boîtes, placer leurs points, nommer un patron dans chacune, les activer. Les blips apparaissent.
3. **Bar** :
   - un serveur en service, au bar, sert 2 mojitos à un client ;
   - le client paie en espèces : l'argent arrive sur le compte de la boîte, les boissons dans l'inventaire, le stock baisse ;
   - le client refuse : le serveur est prévenu ;
   - l'inventaire du client est plein : rien n'est payé.
4. **Entrée** :
   - la boîte est fermée au public : l'entrée est refusée ;
   - le patron l'ouvre avec une entrée à 50 $ : le client paie, il est téléporté à l'intérieur (si le point Intérieur est placé), puis il sort et revient sans repayer ;
   - un client sur la liste VIP entre gratuitement ;
   - un client sur la liste noire est refusé.
5. **Enceintes** :
   - le patron pose 2 enceintes (essayer chaque modèle) ;
   - le DJ colle 3 liens YouTube et lance la lecture : deux joueurs entendent la même musique au même moment ;
   - le son baisse en s'éloignant et se coupe au-delà de la portée ;
   - à la fin du titre, le suivant démarre.
6. **Permissions** :
   - un serveur ne peut pas toucher à la musique ;
   - le patron coche « Utiliser les enceintes » pour le grade Serveur : le serveur peut alors mettre en pause ;
   - le patron de l'autre boîte ne peut ni retirer ni piloter les enceintes de la première.
7. **Vidéo refusée** : une vidéo interdite d'intégration est sautée.
8. **Annonce** : le bandeau apparaît chez tous les joueurs.
9. **Métier staff** : entrer dans une boîte au grade DJ, prendre le service, mettre de la musique ; passer dans une autre boîte ; revenir à son métier d'origine.
10. **Finances** : commission versée au serveur, paie des heures de service, transactions (bar, entrées, stock).

## Limites connues

- **Non testé en jeu.**
- **Modèles d'enceintes** :
  - les noms des modèles `ba_prop_battle_club_speaker_*` et `prop_speaker_05` / `06` n'ont pas pu être vérifiés en jeu ;
  - un modèle absent du jeu est remplacé par `prop_speaker_06` (une enceinte « invisible » reste un point de son) ;
  - les enceintes sont des objets affichés par chaque joueur : personne ne peut les déplacer ni les casser.
- **Son** :
  - il suit la distance, pas les murs : on l'entend dehors si on est assez près ;
  - avec plusieurs boîtes proches, un joueur entend au plus les 2 plus proches.
- **YouTube** :
  - certaines vidéos refusent d'être lues hors de YouTube : elles sont sautées ;
  - le lecteur intégré peut jouer les publicités prévues par YouTube ;
  - la durée d'un titre est donnée par les joueurs qui l'écoutent ; si personne n'est près des enceintes, le titre passe au bout de 10 minutes.
- **Entrée** :
  - le bracelet est gardé en mémoire : un redémarrage du serveur l'efface, les clients repaient ;
  - sans point Intérieur, l'entrée vend seulement un bracelet. Rien n'empêche physiquement d'entrer : c'est au videur de contrôler.
