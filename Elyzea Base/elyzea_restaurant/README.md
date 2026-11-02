# elyzea_restaurant — métier Restaurant (plusieurs établissements)

Même architecture que les autres métiers Elyzea (copie adaptée d'`elyzea_club`) : métier `elyzea_core` par restaurant, grades et permissions réglables, service et paie, commissions, compte de société, direction, finances, F6, tablette, téléphone de service, administration staff.

## Installation

1. Copier `elyzea_restaurant` dans les ressources.
2. Dans `server.cfg`, après `elyzea_inventory` et `admin_menu`, **avant** `elyzea_jobphone` :
   ```
   ensure elyzea_restaurant
   ```
3. Remplacer aussi les fichiers modifiés de `elyzea_inventory` (objet `restaurant_bag`), `elyzea_jobphone` (appli « Commande ») et `admin_menu` (onglet « Restaurants », permissions, Métier staff).
   Pour vendre les 80 recettes : `elyzea_cuisine` doit être présent (déjà avant `elyzea_inventory` dans `server.cfg`). Pour les pesos : `elyzea_change` (objet `pesos`).
4. Les tables `rs_*` se créent seules au démarrage (`sql/install.sql` : même chose à la main).
5. En jeu (staff avec « Restaurants : TOUT », donné au rang SuperAdmin au premier démarrage) : `admin_menu › Restaurants` ou `/restoadmin`.

## Mise en place d'un restaurant

1. **+ Nouveau restaurant** : nom, logo (emoji ou lien d'image), couleur, métier et compte (créés tout seuls), 5 grades.
2. **Point de commande** (obligatoire) : se placer au comptoir, « Placer ici ». Coffre et Bureau (tablette) : facultatifs.
3. **Stations de cuisine** (au moins une) : cocher les types (grill, four, friteuse, fontaine, pâtisserie, piano de cuisson, plan de travail), « Poser ici ». Une station peut avoir plusieurs types.
4. **Produits vendus** : cocher ce que ce restaurant a le droit de vendre (catégories repliables, « Tout » / « Rien » par catégorie, recherche). « Tout le catalogue » = le patron choisit lui-même. Chaque produit montre sa station ; s'il en manque une, un avertissement l'indique.
5. **Paiements acceptés** : banque, espèces et/ou pesos.
6. **Nommer le patron**, puis **Activer**.

Permission staff de ces deux réglages : « Restaurants : choisir les produits vendus… » (`resto_menu`), ou « Restaurants : TOUT ».

Autre possibilité : `Config.Restaurants` dans `config.lua` (créés une seule fois au démarrage, jamais écrasés ensuite).

## Déroulement d'une commande

| Étape | Qui | Où |
|---|---|---|
| Carte, panier, paiement (banque, espèces ou pesos, selon le restaurant) | Client | **E** au point de commande |
| « Nouvelle commande reçue ! Commande #001 – 3 produits… » | Employés concernés en service | Notification |
| Prendre en charge (un seul employé, jamais deux) | Employé | Appli **Commande** du téléphone de service (ou tablette › Commandes) |
| Préparer chaque produit (mini-jeu) | L'employé qui a la commande | **E** à la station du produit |
| Sac `restaurant_bag` (numéro, contenu) | Donné automatiquement | Inventaire de l'employé |
| Remettre le sac | Employé avec le sac, client à moins de 3 m | Appli Commande › « Remettre au client » |
| Ouvrir le sac, prendre les produits | Client | Utiliser l'objet dans l'inventaire |

Statuts : En attente → En préparation → Terminée → Livrée (ou Annulée + remboursée).

## Recettes de elyzea_cuisine

`shared/cuisine.lua` lit `elyzea_cuisine/data/recipes.lua` (le même fichier que l'inventaire) et ajoute les **80 recettes** au catalogue : 4 catégories (Restaurant italien, Fast-Food, Restaurant japonais, Restaurant mexicain), objet donné = la recette (`it_lasagnes`, `jp_sushi_saumon`…), donc les gestes et objets en main de `elyzea_cuisine` quand le client mange.

- Prix de départ : `Config.Cuisine.prices` selon le type (plat, dessert, boisson) + un peu selon la faim / soif rendue. Le patron les change ensuite.
- Préparation : `Config.Cuisine.rules` (première règle qui correspond) : boissons → fontaine, desserts → pâtisserie, pizzas → four, burgers → grill, fritures (frites, nuggets, tempura…) → friteuse, sushis / wraps / sandwichs → plan de travail (dressage sans cuisson), lasagnes / gratins → four, grillades / tacos → grill, le reste (pâtes, ramen, woks, currys…) → piano de cuisson.
- Aucune recette n'est mise à la carte d'un restaurant tant que le staff (ou le patron) ne l'a pas choisie.

## Paiement en pesos

- Le staff coche « Pesos » pour un restaurant. Prix en pesos = prix × `Config.Pesos.rate` (1 par défaut), arrondi au-dessus.
- Les pesos payés vont dans le **coffre du restaurant** (objet `pesos`), pas sur le compte de société en $. Pas de commission sur ces commandes (rien n'entre sur le compte).
- Annulation : pesos repris dans le coffre et rendus au client. Coffre vidé entre-temps : annulation refusée (rien n'est inventé). Client absent ou inventaire plein : remis à sa prochaine connexion (table `rs_refunds`, jamais deux fois).
- Coffre plein ou pas assez de pesos : commande refusée, rien n'est retiré.
- Tablette › Finances : ventes en pesos comptées à part. Les statistiques « chiffre du jour » comptent la valeur en $ de toutes les commandes.

## Configuration (`config.lua`)

- `Config.Products` : catalogue (objet donné, catégorie, prix de départ, image, description, **mini-jeu, difficulté 1-3, durée, étapes, station**). Le staff choisit les produits autorisés par restaurant ; le patron choisit sa carte et ses prix parmi eux dans la tablette (Carte et prix).
- `Config.Cuisine` (recettes de elyzea_cuisine), `Config.Pesos` (objet, taux).
- `Config.Orders.methods` (moyens possibles) et `defaultMethods` (ceux d'un restaurant que le staff n'a pas encore réglé).
- `Config.Categories`, `Config.StationTypes`, `Config.MiniGames` (durée minimale crédible).
- `Config.Orders` : limites du panier, commandes en cours par client (2) et par employé (3), distance, annulation automatique + remboursement des commandes jamais prises (60 min).
- `Config.Kitchen.unitsPerGame` : unités préparées par mini-jeu réussi (2).
- `Config.Delivery.distance`, `Config.Bag.item`, `Config.DefaultGrades`.

Les produits utilisent les objets déjà présents dans `elyzea_inventory` (burgers, boissons, desserts, frites, pizza) et leurs images.

## Mini-jeux

`burger` (cuisson à la jauge + montage dans l'ordre), `pizza` (garniture sur les repères + cuisson), `drink` (remplir jusqu'au trait), `dessert` (bons ingrédients), `fries` (sortir au bon moment), `plat` (recettes : cuisson à la jauge, sauf plats froids, puis dressage avec les ingrédients de la cuisine du plat — `Config.Cuisine.ingredients`).

**Ajouter un mini-jeu** : une entrée dans `shared/games.lua` (`gen` = défi, `check` = vérification), un module `Kitchen.register('nom', …)` dans `html/kitchen.js`, une ligne dans `Config.MiniGames`, puis `game = 'nom'` sur un produit.

## Sécurité (vérifié par le serveur)

- Prix, total et carte relus côté serveur ; le client n'envoie que des identifiants et des quantités. Prix changés entre-temps : refusé.
- Paiement d'abord ; numéro de commande donné seulement après paiement ; remboursement si l'enregistrement échoue.
- Prise en charge sans attente entre la vérification et l'attribution : deux employés ne peuvent pas avoir la même commande.
- Mini-jeux : défi généré et gardé par le serveur, jeton à usage unique, durée minimale et maximale, distance à la station, propriétaire de la commande, réponses vérifiées. Raté = rien de préparé.
- Sac : un seul par commande ; ne s'ouvre qu'une fois la commande livrée ; contenu restant gardé en base (`bag_left`, écriture conditionnelle) : une copie du sac ne redonne rien.
- Remise : sac de CETTE commande sur l'employé, bon client, proche, place dans l'inventaire ; une seule remise.
- Restaurants séparés : commandes, carte, stations, personnel, compte et numérotation propres à chacun.

**Limite** : un mini-jeu se joue dans le navigateur du joueur ; le serveur vérifie tout ce qu'il peut (structure, temps, distance, jeton), mais un tricheur qui lit les paramètres pourrait envoyer de bonnes réponses. Il doit tout de même attendre la durée minimale et rester à la station.

## Tests hors jeu

- `python3 tests/run_tests.py <socket MariaDB>` : scripts serveur réels + vraie base MariaDB, parcours complet à plusieurs joueurs, recettes, produits vendus, pesos (187 vérifications).
- `NODE_PATH=$(npm root -g) node tests/ui.cjs` : carte, panier, sac, 5 mini-jeux joués, tablette (35 vérifications).
- `NODE_PATH=$(npm root -g) node tests/ui_catalog.cjs` : carte en pesos, mini-jeu « plat » joué, panneau staff produits vendus + paiements (32 vérifications).
- `NODE_PATH=$(npm root -g) node tests/ui_phone.cjs` : appli « Commande » du téléphone (7 vérifications).

Exports : `IsRestoEmployee(src)`, `GetRestaurants()`, `GetActiveOrders(src)`, et ceux du Métier staff d'admin_menu.
