# elyzea_drogues — système de drogues (v2.1)

Filières de fabrication en plusieurs étapes, culture du cannabis par les joueurs, vente, consommation avec
animations et fumée colorée, effets propres à chaque drogue (dont les hallucinations des champignons).
Tout passe par le **ALT existant** (Alt + clic sur un objet ou un PNJ) et par **admin_menu › Illégal › 💊 Gestion des drogues**.

> État : **rien n'a été testé en jeu.** Le code serveur est vérifié par des simulations hors jeu
> (`tests/run_server_sim.py`, 95/95 ; `tests/run_client_sim.py`, 16/16) et des contrôles statiques (`tests/static_check.py`, 41/41) ;
> les 14 mini-jeux ont été joués de bout en bout dans un navigateur par un script automatique ;
> l'onglet admin a été affiché dans un navigateur de test. Voir `docs/TESTS.md` pour la procédure en jeu.

## Nouveau en v2.1 : étapes immersives
Chaque étape de fabrication est un **vrai mini-jeu** avec une scène en jeu (position, animation, objets en main, accessoires sur la table) :
effeuillage assis d'une vraie fleur de cannabis, séchage, moulin, roulage, pesée, dosage, chauffe, découpe, cristaux, presse, tri…
Quantités, prix et durées inchangés ; un mini-jeu raté ne fait rien perdre. Nouvelle étape « séchage » du cannabis (désactivable).
La récolte (champs placés par le staff, pots) garde la barre de progression avec des animations adaptées.
Tout est détaillé dans **`docs/IMMERSIF.md`** (commandes `/drogues_verif` et `/drogues_assise`).

## Installation
1. Copier `elyzea_drogues` dans le dossier des ressources (à côté des autres ressources Elyzea).
2. Remplacer aussi les fichiers modifiés de `admin_menu`, `elyzea_police` et `elyzea_inventory/shared/items.lua`
   (liste dans `docs/FICHIERS.md`).
3. `server.cfg` : `ensure elyzea_drogues` **après** `elyzea_inventory`, `elyzea_ems`, `admin_menu` et `elyzea_police`
   (déjà fait dans `Serveur cfg/server.cfg`, section « Illégal »).
4. Base de données : rien à faire, les tables sont créées au démarrage. Le fichier `sql/drogues.sql` permet de les créer à la main.
5. Redémarrer le serveur (ou `refresh` puis `ensure elyzea_drogues`, `ensure admin_menu`, `ensure elyzea_police`, `ensure elyzea_inventory`).
6. Donner la permission `drugs_manage` (gestion complète) ou `drugs_effects` (effets seulement) aux grades voulus
   dans admin_menu (le SuperAdmin les a déjà).
7. Placer les installations en jeu (`docs/ADMINISTRATION.md`).

## Contenu
| Filière | Étapes | Produits finis |
|---|---|---|
| 🌿 Cannabis (4 variétés : Weed verte, White Widow violette, Purple Haze violet foncé, Variété maison orange) | culture en pot ou plant sauvage → effeuillage assis (têtes fraîches) → séchage (désactivable) → préparer (désactivable) → rouler / ensacher | joints et pochons par variété |
| ❄️ Cocaïne | récolte coca → broyage → pâte → ensachage (basique) → raffinage → finition | `cokebaggy`, `coke_premium` (pure) |
| 💎 Crack | mélange → cuisson → séchage → découpe → ensachage | `crack_baggy` |
| ⚗️ Méth | produits chimiques → mélange → cuisson → cristallisation → ensachage | `meth` |
| 💊 Ecstasy | base → synthèse → presse (rose / bleu / jaune) → conditionnement | `xtc_pink`, `xtc_blue`, `xtc_yellow` |
| 💉 Opiacés | macération → filtration → finition → conditionnement | `oxy`, `opi_syringe` |
| 🐴 Kétamine | évaporation → séchage → broyage → ensachage | `ketamine` |
| 🍄 Champignons | ramassage → tri → séchage → ensachage | `dried_mushroom`, `shroom_bag` |

Les ingrédients achetés (graines, pots, lampe, solvant, réactifs, colorants…) se trouvent chez les **PNJ fournisseurs** ;
les produits se vendent aux **PNJ acheteurs** contre de l'argent sale (`black_money`, modifiable).

## Consommation
Inventaire › Utiliser. Animation et prop selon le produit (joint, pipe, sniff, comprimé, nourriture, seringue),
fumée de la couleur de la variété visible des joueurs proches, effets différents par drogue (voir `config.lua`).
Chaque prise est envoyée au **laboratoire EMS** (`exports.elyzea_ems:RecordConsumption`).

## Sécurité (tout est décidé par le serveur)
- Distance au poste, recette active, ingrédients réellement présents, place dans l'inventaire, durée minimale de fabrication
  (un client trop rapide est refusé et journalisé), un seul poste utilisé à la fois par joueur et par poste.
- Ingrédients retirés seulement à la fin ; pertes tirées au sort côté serveur.
- Vente : prix des réglages serveur (jamais celui du client), quantité réelle, délai, limite horaire, place pour le paiement vérifiée **avant** de retirer les produits.
- Culture : propriétaire, distance, nombre de pots, zones interdites, croissance calculée par le serveur.
- Toutes les actions du menu admin revérifient la permission côté serveur.

## Documentation
- `docs/ADMINISTRATION.md` — placer les installations, régler recettes, prix, culture, effets.
- `docs/AJOUTER_UNE_DROGUE.md` — ajouter une drogue, une étape ou une variété.
- `docs/TESTS.md` — procédure de test en jeu et tests hors jeu.
- `docs/FICHIERS.md` — fichiers créés et modifiés.
- `docs/ANALYSE.md` — analyse de l'existant faite avant d'écrire le code, et limites.

## Exports
- Serveur : `IsHigh(src)`, `ClearEffects(src)`, `GetPrice(item)`.
- Client : `IsHigh()`, plus les exports ALT (`AltTarget`, `AltNearby`, `AltOptions`, `AltSelect`) utilisés par `elyzea_police`.

## Limites connues
- Pas de modèles 3D personnalisés : les variétés utilisent les plantes de GTA, différenciées par une lueur et une fumée colorées.
- Les animations « pipe », « sniff » et « seringue » et la particule de fumée colorée n'ont pas pu être vérifiées en jeu ;
  si une animation manque, une animation de repli est jouée (rien ne bloque).
- La hauteur de la plante dans le pot est calculée à partir de la taille du pot : à vérifier visuellement.
