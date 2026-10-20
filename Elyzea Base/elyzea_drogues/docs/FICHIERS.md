# Fichiers créés et modifiés

## Créés (elyzea_drogues)
- `config/varieties.lua`, `config/culture.lua`, `config/stations.lua`, `config/recipes.lua`, `config/harvest.lua`,
  `config/products.lua`, `config/economy.lua`
- `shared/growth.lua`
- `server/core.lua`, `server/crafting.lua`, `server/culture.lua`, `server/sale.lua`, `server/admin.lua`
- `client/consume.lua`, `client/world.lua`, `client/placement.lua`, `client/alt.lua`
- `html/index.html` (fiche de suivi de la plante)
- `sql/drogues.sql`
- `docs/ANALYSE.md`, `docs/ADMINISTRATION.md`, `docs/AJOUTER_UNE_DROGUE.md`, `docs/TESTS.md`, `docs/FICHIERS.md`
- `tests/static_check.py`, `tests/server_mocks.lua`, `tests/server_sim.lua`, `tests/run_server_sim.py`

## Modifiés (elyzea_drogues, version 1 étendue)
- `fxmanifest.lua` (2.0.0), `config.lua`, `shared/rules.lua`, `server/main.lua`, `client/effects.lua`, `README.md`
- supprimés : `tests/drogues_sim.lua`, `tests/run_drogues_sim.py` (remplacés par la nouvelle simulation)

## Modifiés (autres ressources, ajouts seulement)
- `admin_menu/html/drogues.js` : onglet « Gestion des drogues » (Installations, Recettes, Prix et vente, Culture, Récolte, Effets, Journal)
- `admin_menu/server/drogues.lua` : permissions `drugs_manage` / `drugs_effects`
- `admin_menu/client/editor.lua` : placement `drugsite`, rappels `drug_place` et `drug_tp`
- `admin_menu/config.lua` : permissions `drugs_manage`, `drugs_effects`
- `elyzea_police/client/alt.lua` : fournisseur ALT `elyzea_drogues` + second rayon « objets »
- `elyzea_inventory/shared/items.lua` : bloc « Drogues » (environ 70 objets)
- `Serveur cfg/server.cfg` : commentaire d'ordre de démarrage de `elyzea_drogues`
