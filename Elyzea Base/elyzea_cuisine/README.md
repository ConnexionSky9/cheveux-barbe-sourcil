# elyzea_cuisine — 80 recettes avec objets en main et gestes adaptés

80 recettes réparties en 4 restaurants (italien, fast-food, japonais, mexicain ; 20 chacun) : 80 objets d'inventaire utilisables,
chacun avec **ses objets en main** (assiette + couvert, bol + cuillère, part de pizza, cornet, gobelet à paille…) et **le geste qui va avec**.

## Ce qui a été réutilisé (aucun système en double)

| Besoin | Ressource existante utilisée |
|---|---|
| Framework | **elyzea_core** (maison) |
| Inventaire, objets, images | **elyzea_inventory** : les 80 objets y sont créés automatiquement |
| Consommation sécurisée | circuit déjà présent d'elyzea_inventory : jeton à usage unique, objet revérifié à la fin, retrait d'1 unité, faim / soif ajoutées **par le serveur** (`AddNeeds` d'elyzea_core) |
| Faim / soif | métadonnées `hunger` / `thirst` d'elyzea_core (sur 100, baisse régulière) |
| Barre de progression, annulation, notifications | `ProgressBar` d'elyzea_core |
| Objets et gestes | liste d'emotes de **rpemotes-reborn** (déjà sur ton serveur) : objets et positions repris d'emotes existants |

Seule nouveauté côté jeu : plusieurs objets en main à la fois (assiette **et** couvert), ce que la barre de progression ne sait pas faire seule.

## Installation

1. Copier `elyzea_cuisine` dans les ressources.
2. Dans `server.cfg`, **avant** `elyzea_inventory` (déjà fait dans le `server.cfg` du dépôt) :
   ```
   ensure elyzea_cuisine
   ensure elyzea_inventory
   ```
3. Remplacer les fichiers modifiés d'`elyzea_inventory` : `shared/items.lua`, `server/main.lua`, `client/use.lua` + les 80 images `html/img/it_*.png`, `ff_*.png`, `jp_*.png`, `mx_*.png`.
4. **rpemotes** démarré : il fournit les objets « stream » (pizza, bol de ramen, milkshake, cornet de glace…). Sans lui, chaque recette passe sur son repli du jeu de base.
5. Staff (commandes protégées par ACE) :
   ```
   add_ace group.admin command.cuisine_check allow
   add_ace group.admin command.cuisine_essai allow
   ```
   - `/cuisine_check` : liste dans la console F8 les objets / animations absents **chez toi** et les recettes en repli.
   - `/cuisine_essai it_spaghetti_bolo` : joue le visuel d'une recette (sans objet ni effet) pour régler une position.

## Modifier une recette

Tout est dans **un seul fichier** : `data/recipes.lua`.
- Une ligne `r(...)` par recette : id, catégorie, type, nom, description, faim, soif, poids, durée, emoji de l'icône, façon de consommer, repli.
- `D.Props` : chaque objet (modèle, os, position, rotation) ; `D.Anims` : chaque geste.
- Après modification : redémarrer `elyzea_cuisine` **puis** `elyzea_inventory`.
- Icônes : `python3 tools/make_icons.py` (police Noto Color Emoji + Pillow) régénère les 80 images dans `elyzea_inventory/html/img`.

## Fonctionnement

1. Le joueur utilise l'objet dans l'inventaire.
2. Le serveur de l'inventaire envoie la recette au joueur (avec un jeton) ; rien n'est encore retiré.
3. Le client vérifie que les objets et l'animation existent **chez ce joueur** :
   - oui → les objets de la recette sont attachés aux bons os, le geste se joue ;
   - non → le **repli** de la recette (toujours du jeu de base), sinon un dernier secours (burger / bouteille).
4. Barre de progression (annulable). À la fin, ou à l'annulation, ou en cas d'erreur, ou si la ressource s'arrête : **tous les objets sont retirés** et le geste est arrêté.
5. Si c'est fini, le serveur revérifie l'objet (même case, jeton valide, une seule fois), retire 1 unité et ajoute faim / soif. Annulé : rien n'est retiré.

## Limites (honnêtes)

- **GTA V n'a pas de baguettes, de sushis, de burrito, de churros ni d'épi de maïs.** Les alternatives les plus proches sont documentées dans le tableau : tranche de poisson pour le sushi, sandwich pour le burrito, barre allongée pour les churros, brochette pour l'elote.
- **Aucune fourchette n'existe dans GTA** : les assiettes utilisent la cuillère de l'emote « dinner » de rpemotes.
- Plusieurs plats « à l'assiette » partagent le même modèle d'assiette (il n'existe qu'une assiette fiable dans le jeu) : la différence se fait par le nom, l'icône, la durée et les valeurs.
- **Noms non vérifiés ici** (origine « jeu de base, nom à confirmer en jeu ») : `prop_food_bs_burger2`, `prop_food_cb_burg01`, `prop_food_burg2`, `prop_food_bs_chips`, `prop_food_cb_nugets`. S'ils n'existent pas chez le joueur, le repli s'applique tout seul ; `/cuisine_check` le dit.
- Positions « estimées » (pas reprises d'un emote) : tranche de poisson, cornet / boîte de frites et nuggets, gobelet des onion rings, burgers du Burger Shot / Cluckin' Bell. À ajuster avec `/cuisine_essai`.
- Valeurs de faim / soif entre 0 et 42 par recette : sous la limite de 100 d'elyzea_core (le total est plafonné par le core).

## Tests hors jeu

- `python3 tests/run_client_sim.py` : 80 recettes (4 × 20, noms, valeurs cohérentes, objets et gestes connus, variété) + moteur client : bons objets, os, positions, geste, durée, nettoyage à la fin, annulation, erreur, replis, deux repas en même temps, arrêt de la ressource (22 vérifications, dont 80 consommations).
- `python3 tests/run_server_sim.py` : **vrai serveur d'elyzea_inventory** : 80 objets créés avec leurs icônes, dans « Nourriture », objets existants inchangés, utiliser / annuler / finir, faim et soif ajoutées par le serveur, fin renvoyée deux fois, faux jeton, objet disparu (13 vérifications).

**À tester en jeu** : rendu de chaque objet en main (position exacte), présence des objets rpemotes sur ta version, ressenti des durées.

## Les 80 recettes

### 🇮🇹 Restaurant italien

| Objet | Nom | Faim | Soif | Durée | Geste | Objets en main | Origine | Repli |
|---|---|---|---|---|---|---|---|---|
| `it_spaghetti_bolo` | Spaghetti Bolognaise | 38 | 4 | 9 s | manger à l'assiette / au bol avec un couvert | `prop_cs_plate_01` + `h4_prop_h4_caviar_spoon_01a` | jeu de base, réglage rpemotes | — |
| `it_lasagnes` | Lasagnes à la viande | 42 | 2 | 9 s | manger à l'assiette / au bol avec un couvert | `prop_cs_plate_01` + `h4_prop_h4_caviar_spoon_01a` | jeu de base, réglage rpemotes | — |
| `it_pizza_margherita` | Pizza Margherita | 28 | 0 | 5.5 s | croquer (tenu en main) | `knjgh_pizzaslice4` | objet rpemotes (stream) | croquer : `p_ing_bagel_01` |
| `it_pizza_4fromages` | Pizza 4 Fromages | 30 | 0 | 5.5 s | croquer (tenu en main) | `knjgh_pizzaslice2` | objet rpemotes (stream) | croquer : `p_ing_bagel_01` |
| `it_pizza_pepperoni` | Pizza Pepperoni | 30 | 0 | 5.5 s | croquer (tenu en main) | `knjgh_pizzaslice5` | objet rpemotes (stream) | croquer : `p_ing_bagel_01` |
| `it_carbonara` | Carbonara | 38 | 2 | 9 s | manger à l'assiette / au bol avec un couvert | `prop_cs_plate_01` + `h4_prop_h4_caviar_spoon_01a` | jeu de base, réglage rpemotes | — |
| `it_risotto_champi` | Risotto aux champignons | 34 | 6 | 9 s | manger à l'assiette / au bol avec un couvert | `prop_cs_plate_01` + `h4_prop_h4_caviar_spoon_01a` | jeu de base, réglage rpemotes | — |
| `it_raviolis` | Raviolis ricotta épinards | 34 | 2 | 8.5 s | manger à l'assiette / au bol avec un couvert | `prop_cs_plate_01` + `h4_prop_h4_caviar_spoon_01a` | jeu de base, réglage rpemotes | — |
| `it_gnocchis` | Gnocchis sauce tomate | 32 | 4 | 8.5 s | manger à l'assiette / au bol avec un couvert | `prop_cs_plate_01` + `h4_prop_h4_caviar_spoon_01a` | jeu de base, réglage rpemotes | — |
| `it_tagliatelles_saumon` | Tagliatelles au saumon | 36 | 2 | 9 s | manger à l'assiette / au bol avec un couvert | `prop_cs_plate_01` + `h4_prop_h4_caviar_spoon_01a` | jeu de base, réglage rpemotes | — |
| `it_penne_arrabbiata` | Penne Arrabbiata | 32 | 2 | 8.5 s | manger à l'assiette / au bol avec un couvert | `prop_cs_plate_01` + `h4_prop_h4_caviar_spoon_01a` | jeu de base, réglage rpemotes | — |
| `it_escalope_milanaise` | Escalope Milanaise | 40 | 0 | 9.5 s | manger à l'assiette / au bol avec un couvert | `prop_cs_plate_01` + `h4_prop_h4_caviar_spoon_01a` | jeu de base, réglage rpemotes | — |
| `it_parmigiana` | Parmigiana d'aubergines | 30 | 4 | 8.5 s | manger à l'assiette / au bol avec un couvert | `prop_cs_plate_01` + `h4_prop_h4_caviar_spoon_01a` | jeu de base, réglage rpemotes | — |
| `it_focaccia` | Focaccia italienne | 18 | 0 | 5 s | croquer (tenu en main) | `p_ing_bagel_01` | jeu de base, réglage rpemotes | — |
| `it_tiramisu` | Tiramisu | 16 | 2 | 7 s | manger à l'assiette / au bol avec un couvert | `pata_christmasfood7` + `h4_prop_h4_coke_spoon_01` | jeu de base, réglage rpemotes, objet rpemotes (stream) | manger à l'assiette / au bol avec un couvert : `h4_prop_h4_caviar_tin_01a` + `h4_prop_h4_caviar_spoon_01a` |
| `it_panna_cotta` | Panna Cotta | 14 | 2 | 6.5 s | manger à l'assiette / au bol avec un couvert | `h4_prop_h4_caviar_tin_01a` + `h4_prop_h4_caviar_spoon_01a` | jeu de base, réglage rpemotes | — |
| `it_cannoli` | Cannoli siciliens | 14 | 0 | 5 s | croquer (tenu en main) | `bzzz_foodpack_croissant001` | objet rpemotes (stream) | croquer : `p_ing_bagel_01` |
| `it_gelato` | Gelato italien | 10 | 6 | 6 s | croquer (tenu en main) | `bzzz_icecream_pistachio` | objet rpemotes (stream) | manger à l'assiette / au bol avec un couvert : `h4_prop_h4_caviar_tin_01a` + `h4_prop_h4_caviar_spoon_01a` |
| `it_limonata` | Limonata italienne | 0 | 30 | 4.5 s | boire (tasse, verre, gobelet) | `prop_drink_whisky` | jeu de base, réglage rpemotes | — |
| `it_espresso` | Café Espresso | 0 | 10 | 3.5 s | boire (tasse, verre, gobelet) | `p_ing_coffeecup_01` | jeu de base, réglage rpemotes | — |

### 🍔 Fast-Food

| Objet | Nom | Faim | Soif | Durée | Geste | Objets en main | Origine | Repli |
|---|---|---|---|---|---|---|---|---|
| `ff_cheeseburger` | Cheeseburger | 26 | 0 | 5.5 s | croquer (tenu en main) | `prop_cs_burger_01` | jeu de base, réglage rpemotes | — |
| `ff_double_burger` | Double Burger | 36 | 0 | 6.5 s | croquer (variante) | `prop_food_bs_burger2` | jeu de base, nom à confirmer en jeu | croquer : `prop_cs_burger_01` |
| `ff_chicken_burger` | Chicken Burger | 28 | 0 | 5.5 s | croquer (tenu en main) | `prop_food_cb_burg01` | jeu de base, nom à confirmer en jeu | croquer : `prop_cs_burger_01` |
| `ff_fish_burger` | Fish Burger | 26 | 0 | 5.5 s | croquer (tenu en main) | `prop_food_burg2` | jeu de base, nom à confirmer en jeu | croquer : `prop_cs_burger_01` |
| `ff_hotdog` | Hot-Dog | 22 | 0 | 5 s | croquer (tenu en main) | `prop_cs_hotdog_02` | jeu de base, réglage rpemotes | — |
| `ff_tacos_us` | Tacos américain | 22 | 0 | 5 s | croquer (variante) | `prop_taco_01` | jeu de base, réglage rpemotes | — |
| `ff_nuggets` | Nuggets de poulet | 22 | 0 | 6 s | piocher dans un cornet / une boîte | `prop_food_cb_nugets` | jeu de base, nom à confirmer en jeu | piocher dans un cornet / une boîte : `prop_candy_pqs` |
| `ff_frites` | Frites classiques | 16 | 0 | 6 s | piocher dans un cornet / une boîte | `prop_food_bs_chips` | jeu de base, nom à confirmer en jeu | piocher dans un cornet / une boîte : `prop_candy_pqs` |
| `ff_onion_rings` | Onion Rings | 14 | 0 | 6 s | piocher dans un cornet / une boîte | `xs_prop_trinket_cup_01a` | jeu de base, réglage rpemotes | piocher dans un cornet / une boîte : `prop_candy_pqs` |
| `ff_wrap_poulet` | Wrap au poulet | 24 | 0 | 5.5 s | croquer (variante) | `prop_sandwich_01` | jeu de base, réglage rpemotes | — |
| `ff_club_sandwich` | Club Sandwich | 26 | 0 | 5.5 s | croquer (tenu en main) | `prop_sandwich_01` | jeu de base, réglage rpemotes | — |
| `ff_panini` | Panini poulet | 24 | 0 | 5 s | croquer (variante) | `p_ing_bagel_01` | jeu de base, réglage rpemotes | — |
| `ff_pizza_slice` | Pizza Slice Fast-Food | 24 | 0 | 5.5 s | croquer (variante) | `knjgh_pizzaslice1` | objet rpemotes (stream) | croquer : `p_ing_bagel_01` |
| `ff_chicken_wings` | Chicken Wings | 24 | 0 | 6 s | piocher dans un cornet / une boîte | `prop_food_cb_nugets` | jeu de base, nom à confirmer en jeu | piocher dans un cornet / une boîte : `prop_candy_pqs` |
| `ff_tenders` | Tenders de poulet | 24 | 0 | 5.5 s | croquer (variante) | `prop_food_cb_nugets` | jeu de base, nom à confirmer en jeu | croquer : `prop_cs_burger_01` |
| `ff_donut` | Donut | 12 | 0 | 4.5 s | croquer (tenu en main) | `prop_amb_donut` | jeu de base, réglage rpemotes | — |
| `ff_brownie` | Brownie au chocolat | 14 | 0 | 4.5 s | croquer (tenu en main) | `bzzz_food_dessert_a` | objet rpemotes (stream) | croquer : `prop_choc_ego` |
| `ff_muffin` | Muffin aux myrtilles | 14 | 0 | 4.5 s | croquer (tenu en main) | `pata_christmasfood6` | objet rpemotes (stream) | croquer : `prop_amb_donut` |
| `ff_milkshake_fraise` | Milkshake à la fraise | 8 | 26 | 5.5 s | siroter à la paille | `brum_cherryshake_strawberry` | objet rpemotes (stream) | boire : `prop_cs_bs_cup` |
| `ff_soda` | Soda en gobelet | 0 | 30 | 4.5 s | siroter à la paille | `rpemotesreborn_soda02` | objet rpemotes (stream) | boire : `prop_cs_bs_cup` |

### 🇯🇵 Restaurant japonais

| Objet | Nom | Faim | Soif | Durée | Geste | Objets en main | Origine | Repli |
|---|---|---|---|---|---|---|---|---|
| `jp_sushi_saumon` | Sushi Saumon | 10 | 0 | 4 s | croquer (tenu en main) | `prop_fish_slice_01` | jeu de base, réglage rpemotes | — |
| `jp_sushi_thon` | Sushi Thon | 10 | 0 | 4 s | croquer (variante) | `prop_fish_slice_01` | jeu de base, réglage rpemotes | — |
| `jp_makis_saumon` | Makis Saumon | 20 | 0 | 8 s | manger à l'assiette / au bol avec un couvert | `prop_cs_plate_01` + `h4_prop_h4_caviar_spoon_01a` | jeu de base, réglage rpemotes | — |
| `jp_california` | California Rolls | 20 | 0 | 8 s | manger à l'assiette / au bol avec un couvert | `prop_cs_plate_01` + `h4_prop_h4_caviar_spoon_01a` | jeu de base, réglage rpemotes | — |
| `jp_sashimi` | Sashimi Saumon | 18 | 0 | 7.5 s | manger à l'assiette / au bol avec un couvert | `prop_cs_plate_01` + `h4_prop_h4_caviar_spoon_01a` | jeu de base, réglage rpemotes | — |
| `jp_ramen_porc` | Ramen au porc | 36 | 14 | 10 s | manger à l'assiette / au bol avec un couvert | `scully_pho` + `scully_spoon_pho` | objet rpemotes (stream) | manger à l'assiette / au bol avec un couvert : `prop_cs_plate_01` + `h4_prop_h4_caviar_spoon_01a` |
| `jp_ramen_poulet` | Ramen au poulet | 34 | 14 | 10 s | manger à l'assiette / au bol avec un couvert | `scully_pho` + `scully_spoon_pho` | objet rpemotes (stream) | manger à l'assiette / au bol avec un couvert : `prop_cs_plate_01` + `h4_prop_h4_caviar_spoon_01a` |
| `jp_udon` | Udon | 32 | 14 | 10 s | manger à l'assiette / au bol avec un couvert | `scully_pho` + `scully_spoon_pho` | objet rpemotes (stream) | manger à l'assiette / au bol avec un couvert : `prop_cs_plate_01` + `h4_prop_h4_caviar_spoon_01a` |
| `jp_yakitori` | Yakitori poulet | 14 | 0 | 5 s | croquer (tenu en main) | `bzzz_camp_food_kebab` | objet rpemotes (stream) | croquer : `prop_choc_ego` |
| `jp_gyoza` | Gyoza | 18 | 0 | 7.5 s | manger à l'assiette / au bol avec un couvert | `prop_cs_plate_01` + `h4_prop_h4_caviar_spoon_01a` | jeu de base, réglage rpemotes | — |
| `jp_tempura` | Tempura de crevettes | 20 | 0 | 8 s | manger à l'assiette / au bol avec un couvert | `prop_cs_plate_01` + `h4_prop_h4_caviar_spoon_01a` | jeu de base, réglage rpemotes | — |
| `jp_donburi` | Donburi au bœuf | 36 | 4 | 9.5 s | manger à l'assiette / au bol avec un couvert | `scully_pho` + `scully_spoon_pho` | objet rpemotes (stream) | manger à l'assiette / au bol avec un couvert : `prop_cs_plate_01` + `h4_prop_h4_caviar_spoon_01a` |
| `jp_katsudon` | Katsudon | 38 | 4 | 9.5 s | manger à l'assiette / au bol avec un couvert | `scully_pho` + `scully_spoon_pho` | objet rpemotes (stream) | manger à l'assiette / au bol avec un couvert : `prop_cs_plate_01` + `h4_prop_h4_caviar_spoon_01a` |
| `jp_bento` | Bento japonais | 34 | 2 | 9 s | manger à l'assiette / au bol avec un couvert | `h4_prop_h4_caviar_tin_01a` + `h4_prop_h4_caviar_spoon_01a` | jeu de base, réglage rpemotes | — |
| `jp_onigiri` | Onigiri | 14 | 0 | 4.5 s | croquer (variante) | `prop_sandwich_01` | jeu de base, réglage rpemotes | — |
| `jp_mochi` | Mochi | 10 | 0 | 4 s | croquer (tenu en main) | `bzzz_food_xmas_macaroon_a` | objet rpemotes (stream) | croquer : `prop_amb_donut` |
| `jp_dorayaki` | Dorayaki | 12 | 0 | 4.5 s | croquer (variante) | `p_ing_bagel_01` | jeu de base, réglage rpemotes | — |
| `jp_taiyaki` | Taiyaki | 12 | 0 | 4.5 s | croquer (variante) | `bzzz_foodpack_croissant001` | objet rpemotes (stream) | croquer : `p_ing_bagel_01` |
| `jp_matcha` | Thé Matcha | 0 | 24 | 5 s | boire à la bouteille / au mug | `bzzz_food_xmas_mug_a` | objet rpemotes (stream) | boire : `p_amb_coffeecup_01` |
| `jp_ramune` | Ramune japonais | 0 | 28 | 4 s | boire à la bouteille / au mug | `prop_energy_drink` | jeu de base, réglage rpemotes | — |

### 🇲🇽 Restaurant mexicain

| Objet | Nom | Faim | Soif | Durée | Geste | Objets en main | Origine | Repli |
|---|---|---|---|---|---|---|---|---|
| `mx_tacos_pastor` | Tacos Al Pastor | 20 | 0 | 5 s | croquer (tenu en main) | `prop_taco_01` | jeu de base, réglage rpemotes | — |
| `mx_tacos_carnitas` | Tacos Carnitas | 20 | 0 | 5 s | croquer (variante) | `prop_taco_01` | jeu de base, réglage rpemotes | — |
| `mx_burrito_boeuf` | Burrito au bœuf | 34 | 0 | 6.5 s | croquer (tenu en main) | `prop_sandwich_01` | jeu de base, réglage rpemotes | — |
| `mx_burrito_poulet` | Burrito au poulet | 32 | 0 | 6.5 s | croquer (variante) | `prop_sandwich_01` | jeu de base, réglage rpemotes | — |
| `mx_quesadilla` | Quesadilla au fromage | 22 | 0 | 5 s | croquer (variante) | `knjgh_pizzaslice3` | objet rpemotes (stream) | croquer : `p_ing_bagel_01` |
| `mx_nachos` | Nachos au fromage | 20 | 0 | 7 s | piocher dans un cornet / une boîte | `prop_cs_plate_01` | jeu de base, réglage rpemotes | — |
| `mx_enchiladas` | Enchiladas | 34 | 2 | 9 s | manger à l'assiette / au bol avec un couvert | `prop_cs_plate_01` + `h4_prop_h4_caviar_spoon_01a` | jeu de base, réglage rpemotes | — |
| `mx_fajitas` | Fajitas au poulet | 34 | 2 | 9 s | manger à l'assiette / au bol avec un couvert | `prop_cs_plate_01` + `h4_prop_h4_caviar_spoon_01a` | jeu de base, réglage rpemotes | — |
| `mx_chimichanga` | Chimichanga | 32 | 0 | 6 s | croquer (tenu en main) | `prop_sandwich_01` | jeu de base, réglage rpemotes | — |
| `mx_tamales` | Tamales | 24 | 0 | 5.5 s | croquer (tenu en main) | `p_ing_bagel_01` | jeu de base, réglage rpemotes | — |
| `mx_tostadas` | Tostadas | 24 | 0 | 8 s | manger à l'assiette / au bol avec un couvert | `prop_cs_plate_01` + `h4_prop_h4_caviar_spoon_01a` | jeu de base, réglage rpemotes | — |
| `mx_chilaquiles` | Chilaquiles | 30 | 2 | 8.5 s | manger à l'assiette / au bol avec un couvert | `prop_cs_plate_01` + `h4_prop_h4_caviar_spoon_01a` | jeu de base, réglage rpemotes | — |
| `mx_elote` | Elote (maïs grillé) | 14 | 0 | 5 s | croquer (variante) | `bzzz_camp_food_kebab` | objet rpemotes (stream) | croquer : `prop_choc_ego` |
| `mx_empanadas` | Empanadas | 20 | 0 | 5 s | croquer (tenu en main) | `bzzz_foodpack_croissant001` | objet rpemotes (stream) | croquer : `p_ing_bagel_01` |
| `mx_pozole` | Pozole | 34 | 16 | 10 s | manger à l'assiette / au bol avec un couvert | `scully_pho` + `scully_spoon_pho` | objet rpemotes (stream) | manger à l'assiette / au bol avec un couvert : `prop_cs_plate_01` + `h4_prop_h4_caviar_spoon_01a` |
| `mx_churros` | Churros | 12 | 0 | 4.5 s | croquer (variante) | `prop_choc_ego` | jeu de base, réglage rpemotes | — |
| `mx_flan` | Flan mexicain | 12 | 2 | 6.5 s | manger à l'assiette / au bol avec un couvert | `pata_christmasfood7` + `h4_prop_h4_coke_spoon_01` | jeu de base, réglage rpemotes, objet rpemotes (stream) | manger à l'assiette / au bol avec un couvert : `h4_prop_h4_caviar_tin_01a` + `h4_prop_h4_caviar_spoon_01a` |
| `mx_tres_leches` | Tres Leches | 16 | 2 | 5 s | croquer (variante) | `bzzz_food_dessert_a` | objet rpemotes (stream) | manger à l'assiette / au bol avec un couvert : `prop_cs_plate_01` + `h4_prop_h4_caviar_spoon_01a` |
| `mx_horchata` | Horchata | 4 | 28 | 4.5 s | boire (tasse, verre, gobelet) | `prop_plastic_cup_02` | jeu de base, réglage rpemotes | — |
| `mx_agua_fresca` | Agua Fresca | 0 | 32 | 4.5 s | boire (tasse, verre, gobelet) | `scully_boba` | objet rpemotes (stream) | boire : `prop_plastic_cup_02` |

## Animations de tous les aliments du serveur (v2)

Chaque aliment se mange avec **ses objets en main** et **son geste**, plus jamais le « burger » générique :

| Aliment | Ce qu'on voit |
|---|---|
| Pâtes (spaghetti, carbonara, tagliatelles, penne…) | assiette creuse de nouilles dans la main gauche + **fourchette** dans la main droite |
| Lasagnes, raviolis, gnocchis, gyozas, tempura, enchiladas… | assiette + **fourchette** |
| Escalope, fajitas, steak… | assiette **avec la viande dessus** + fourchette |
| Makis, california, sashimi | assiette **avec le poisson dessus** + fourchette |
| Sushi (nigiri) | le sushi dans la main, on croque |
| Pizza (recettes + « Part de pizza » de l'inventaire) | **part de pizza** dans la main, on croque |
| Burger Shot | burger, cornet de frites, gobelet à paille (on sirote), milkshake, café, sundae à la cuillère… |
| Boîte de nuit | verre de mojito, verre à cocktail, shot, coupe de champagne, canette, boisson énergisante |
| Supérette | canette eCola / Sprunk, paquet de chips, barres chocolatées, donut, pain, croque-monsieur |

- **Fourchette** : `prop_cs_fork` (objet du jeu de base). Il n'existe **aucun modèle de spaghetti** dans GTA V :
  les pâtes utilisent le bol de nouilles de rpemotes (`scully_pho`) ; sans rpemotes → assiette + fourchette.
- **Pizza sans rpemotes** : part de pizza du jeu de base (`ng_proc_pizza01a`) au lieu du pain d'avant.
- **Aliments ajoutés plus tard** : reconnus **par leur nom** (« Assiette de pâtes », « Sushi saumon », « Steak frites »,
  « Salade César », « Pisswasser », « Café »…) sans rien configurer. Règles : `D.Guess` dans `data/recipes.lua`.
  Un plat inconnu consistant se mange à l'assiette + fourchette, un petit en-cas se croque, une boisson se boit.
- Liste des aliments existants : `D.Items` dans `data/recipes.lua` (modifiable).
- Durée réaliste selon le geste (assiette ≥ 7 s, en-cas ≥ 4,5 s, boisson ≥ 4 s).
- Seuls les objets qui **rendent de la faim ou de la soif** sont concernés : drogues, soins, etc. gardent leur animation.
- `/cuisine_essai pizza`, `/cuisine_essai bs_frites`, `/cuisine_essai "pâtes"`… : aperçu staff (affiche dans F8 le geste et les objets choisis).
- Positions marquées `posSrc = 'estime'` dans `D.Props` (fourchette, viande / poisson sur l'assiette, verres du bar…) :
  réglées à la main, à ajuster en jeu avec `/cuisine_essai` si un objet est mal placé.
