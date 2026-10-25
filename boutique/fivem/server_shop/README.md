# server_shop

Boutique Elyzea en jeu (`/boutique`, touche F9) et livraison automatique des achats Tebex.
Elle a besoin de l'API de la boutique (dossier `boutique/backend`). Installation complète : `boutique/README.md`.

```
# server.cfg — « set » et pas « sets »/« setr » (valeurs secrètes, invisibles des joueurs)
set shop_api_url   "https://boutique.exemple.fr"
set shop_api_token "même valeur que GAME_SERVER_TOKEN"
ensure server_shop      # après elyzea_core / elyzea_inventory (ou es_extended / oxmysql)
```

- Framework détecté tout seul : `elyzea_core` ou ESX (`Config.Framework`).
- `/boutique_lier` : code pour lier son compte sur le site.
- Pour vos scripts : `exports.server_shop:HasPerk(source, 'vip_or')` et `exports.server_shop:GetPerks(source)`. Les grades donnent aussi le groupe ACE `group.<nom>`.
- Table créée automatiquement dans la base du jeu : `server_shop_deliveries` (livraisons déjà exécutées).
- Test hors jeu : `python3 tests/run_sim.py elyzea` (API démarrée, voir l'en-tête du fichier).
