# elyzea_dynasty — Dynasty 8 (agence immobilière)

> **État : écrit et vérifié hors jeu uniquement** (syntaxe Lua/JS, cohérence des appels
> interface ↔ client ↔ serveur, aperçus de l'interface avec des données fictives).
> **Rien n'a été testé sur un serveur FiveM.** Suivez la liste « Tests à faire en jeu » avant l'ouverture.

## Installation

1. Dépendances : `elyzea_core`, `elyzea_inventory`, `admin_menu` (pour la gestion immobilière staff), `elyzea_garage` (version fournie, qui connaît l'état « rangé dans un bien »).
2. `server.cfg` : `ensure elyzea_dynasty` **après** `elyzea_core`, `elyzea_inventory`, `admin_menu` et `elyzea_garage` (déjà ajouté).
3. Base de données : les tables `d8_*` sont créées automatiquement au démarrage. `sql/install.sql` contient les mêmes requêtes pour une installation manuelle.
4. Métier du framework : `realestate` (« Dynasty 8 ») est créé/synchronisé par la ressource ; le compte société utilisé est `realestate`.
5. Premier démarrage : grades de départ (Stagiaire → Directeur) et 20 intérieurs GTA de départ sont ajoutés.
6. Donnez le métier : admin_menu › Métier staff › **Dynasty 8** (directeur compris), ou recrutement depuis la tablette.

## Rôles

| Qui | Accès |
|---|---|
| Staff (permission admin_menu `property_manage`, donnée au SuperAdmin ; le Fondateur a tout) | Gestion immobilière : biens, intérieurs, points, garages, contrats, coffres archivés |
| Agents Dynasty 8 (selon les permissions de leur grade) | F6, tablette, visites, vente, location, résiliation, prix, direction, finance |
| Titulaire d'un contrat | Entrée sans code, coffre, zone de gestion (code, locataires, prolongation, décoration), garage |
| Locataire ajouté | Entrée sans code ; coffre / gestion / garage seulement si le titulaire les coche |
| Visiteur avec le code | Entrée seulement (pas de coffre, pas de gestion) |

## Mettre en place un bien (staff)

admin_menu › **Gestion immobilière** › « Ouvrir » (ou `/d8admin`).

1. **+ Nouveau** : nom, adresse, catégorie (appartement / maison / villa / garage), intérieur, prix, durées, coffre, limite de décoration. Le bien est créé **désactivé**.
2. Placez-vous devant la porte, rouvrez le panneau : **Entrée › Placer ici** (et Sonnette si voulu). La sélection du bien est gardée entre deux ouvertures.
3. **Aller à l'intérieur** (mode staff) puis placez **Sortie (rouge)**, **Zone de gestion (bleue)**, **Coffre (orange)**.
4. Garage : cochez « Ce bien a un garage », taille (petit 2 / moyen 6 / grand 10 places), capacité, intérieur de garage → Enregistrer. Placez **Entrée du garage**, **Sortie des véhicules** (au volant, orienté vers la sortie), puis dans le garage **Arrivée à pied**, **Sortie du garage** et les **places** (une par véhicule).
5. **Activer** : le bien apparaît dans la tablette (refusé tant que l'entrée, l'intérieur ou la sortie manquent).
6. `/d8sortir` ramène le staff dehors. « Aperçu en jeu » affiche les points des biens proches avec leur nom.

Intérieurs : onglet **Intérieurs** → « + Nouveau à ma position » (MLO ou intérieur GTA), IPL facultatives, « Tester » (instance privée). Changer l'intérieur d'un bien occupé est possible : propriétaire, contrat, paiements, coffre et historique sont conservés ; les points intérieurs sont à replacer et la décoration passe en réserve (le résident la replace).

## Fonctionnement

- **Instances** : chaque bien a son routing bucket (`40000 + id`). Un joueur qui se déconnecte à l'intérieur est remis devant l'entrée à la reconnexion ; au redémarrage de la ressource, tout le monde est sorti.
- **Porte** (E sur le cercle vert) : résidents → entrée directe ; sinon code, sonnette (le résident accepte/refuse, accès 30 min), entrée de visite, entrée staff.
- **Visites** : depuis un bien disponible (tablette › Faire visiter), l'agent invite les clients proches (F6 › Visite commerciale). Aucun droit permanent ; fin manuelle, après 30 min, ou quand le bien est attribué.
- **Vente / location** : l'agent prépare l'offre (client à moins de 6 m, durée, banque/espèces) ; le client voit le récapitulatif et signe. Le serveur recalcule le prix, débite le client, crédite le compte société `realestate`, crée le contrat ; en cas d'échec après débit, remboursement automatique tracé (`d8_payments`, `d8_transactions`).
- **Zone bleue** : contrat, prolongation (paiement banque/espèces, période de grâce 48 h), code de la porte, locataires et leurs droits, décoration.
- **Coffre orange** : vrai stash `elyzea_inventory`, propre au bien **et** au contrat (`d8:<bien>:<contrat>`) : un nouvel occupant ne récupère jamais les objets de l'ancien. Les coffres archivés restent ouvrables par le staff.
- **Garage** : rangement au volant sur l'entrée bleue (le véhicule doit appartenir au joueur), places limitées, véhicules visibles dans le garage (objets locaux), sortie sans doublon. Un véhicule rangé est `player_vehicles.state = 3` : le garage public le montre « dans un bien » et refuse de le sortir.
- **Fin de contrat** (expiration après la grâce, résiliation, staff) : occupants sortis, coffre archivé, décoration en réserve, véhicules renvoyés au garage public (`OnContractEnd` dans config.lua).
- **Tablette** : tableau de bord, biens disponibles / indisponibles (filtres), fiche, carte (vert disponible, orange loué, rouge vendu, violet réservé), contrats, visites, direction (recrutement, employés, grades, permissions, historique), finance (salaires horaires, taux, transactions).

## Commandes

`F6` / `/d8_menu` menu métier · `/d8admin` gestion immobilière (staff) · `/d8sortir` sortie staff · `/d8_debloquer` rend le curseur · `/d8_pos` affiche votre position.

## Tests à faire en jeu (rien n'a été testé)

1. Démarrage : aucune erreur console, tables `d8_*` créées, 20 intérieurs présents.
2. Pour **chaque intérieur** de départ : « Tester » — les coordonnées viennent d'intérieurs GTA connus et **doivent être vérifiées** (certaines demandent des IPL ou un DLC).
3. Créer un appartement, placer tous les points, activer ; vérifier marqueurs, couleurs et E.
4. Garage : rangement, affichage des véhicules, sortie, capacité pleine, véhicule non possédé refusé, garage public qui refuse un véhicule rangé.
5. Vente banque puis espèces ; fonds insuffisants ; client qui refuse ; client qui s'éloigne ; compte société crédité.
6. Location : expiration (accélérer en modifiant `ends_at` en base), période de grâce, prolongation, renvoi des véhicules, archivage du coffre.
7. Code, sonnette accepter/refuser, locataire avec/sans droits, retrait d'un locataire.
8. Coffre : ouverture, contenu conservé après redémarrage, coffre vide pour un nouvel occupant.
9. Décoration : poser, déplacer, retirer, limite, réserve après changement d'intérieur.
10. Visite : invitation, entrée du client, fin de visite, sortie des visiteurs.
11. Déconnexion à l'intérieur puis reconnexion ; `restart elyzea_dynasty` avec des joueurs à l'intérieur.
12. Direction et finance : recrutement, grades, paie, permissions.
13. admin_menu : onglet « Gestion immobilière » visible pour SuperAdmin/Fondateur seulement ; Métier staff › Dynasty 8.

## Limites connues

- **Non testé en jeu** (voir ci-dessus).
- Coordonnées des intérieurs de départ à vérifier ; un MLO doit être streamé par sa propre ressource.
- Les véhicules affichés dans le garage et la décoration sont des **objets locaux** (non synchronisés) : chaque joueur de l'instance les voit, mais on ne peut pas conduire un véhicule affiché ; « Sortir » crée le vrai véhicule dehors.
- Placement des points : il faut fermer le panneau, se déplacer puis rouvrir (`/d8admin`) ; pas de mode « viser et poser ».
- Pas de remboursement automatique lors d'une résiliation (choix volontaire, à faire manuellement).
- Les prix d'un contrat en cours ne changent pas quand on modifie les tarifs.
- La carte de la tablette utilise l'image `html/img/map.jpg` existante (calibrage repris du métier Mécano).
