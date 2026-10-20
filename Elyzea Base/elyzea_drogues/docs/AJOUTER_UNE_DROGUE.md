# Ajouter une drogue, une étape ou une variété

Le moteur est le même pour toutes les filières : on ajoute des lignes de configuration, pas de code.

## 1. Les objets
Dans `elyzea_inventory/shared/items.lua`, bloc « Drogues » : un objet par ingrédient, produit intermédiaire et produit fini
(nom, libellé français, poids, image). Les produits consommables ont `close = true`.

## 2. L'effet (`config.lua` › `Config.Drugs`)
```lua
lsd = { label = 'LSD', enabled = true, duration = 240, cooldown = 300, intensity = 1.0 },
```
Les effets visuels et physiques sont dans `client/effects.lua` (une fonction par drogue) ; une nouvelle drogue sans
fonction dédiée doit y recevoir la sienne (copier celle de l'ecstasy par exemple). Ajouter la substance au labo EMS
(`elyzea_ems/config.lua` › `Config.Lab`) si elle doit être détectée.

## 3. Le produit consommable (`config/products.lua`)
```lua
P.lsd_tab = { drug = 'lsd', use = 'pill', mult = 1.0 }               -- use : joint, pipe, snort, pill, eat, syringe
P.lsd_joint = { drug = 'lsd', use = 'joint', smoke = { 255, 0, 255 } } -- fumée de couleur fixe
```
L'objet devient utilisable automatiquement au démarrage.

## 4. Les postes (`config/stations.lua`)
```lua
lsd_lab = { label = 'Laboratoire (LSD)', drug = 'lsd', icon = '🧪', models = { 'prop_table_08' }, anim = A.bench },
```
Le premier modèle est celui par défaut ; un modèle absent du jeu est ignoré.

## 5. Les étapes (`config/recipes.lua`)
```lua
R.lsd_synth = { label = 'Synthèse', drug = 'lsd', step = 2, station = 'lsd_lab',
    inputs = { { 'drg_reagent', 1 } }, outputs = { { 'lsd_liquid', 1 } }, duration = 12, loss = 5 }
```
Une étape de récolte se déclare dans `config/harvest.lua` (objet obtenu, min/max, repousse).

## 6. Le prix (`config/economy.lua`)
`Config.Prices.lsd_tab = { price = 80, max = 10 }`, et les ingrédients à vendre dans `Config.Shop`.

## 7. Nouvelle variété de cannabis (`config/varieties.lua`)
Ajouter une entrée avec ses 6 objets (`seed`, `leaf`, `bud`, `ground`, `joint`, `pouch`) et sa couleur : recettes,
plant sauvage, produits, prix et culture sont générés automatiquement. Créer les 6 objets dans l'inventaire et ajouter
la graine à `Config.Shop`.

## 8. Vérifier
`python3 tests/static_check.py` (objets manquants, postes inconnus, recettes cassées) et `python3 tests/run_server_sim.py`,
puis redémarrer la ressource. L'onglet admin affiche automatiquement la nouvelle drogue.
