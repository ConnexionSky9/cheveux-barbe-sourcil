# PROJECT_STATUS — elyzea_lasergame

Fichier de reprise : état réel du projet. Dernière mise à jour : v2.0.0 (arènes créées en jeu, mode Zombie retiré).

## État global : v2.0.0, tous les tests hors jeu passent, validation en jeu à faire
| Sujet | État |
|---|---|
| Mode Zombie | ❌ retiré (serveur, client, interface, configuration, classements, téléphone, admin) |
| Cartes générées (5 complexes) | ❌ retirées (`maps/`, `tools/mapgen`, aperçus) |
| Arènes créées en jeu (table `lg_arenas`) | ✅ création à la position du staff, zone, apparitions, réglages, ouverture, suppression — simulé |
| Dessin en visant (admin_menu) | ✅ outils de zone / apparitions d'admin_menu branchés sur « lasergame » — liaison testée, rendu à valider en jeu |
| Décor | ✅ éditeur de map d'admin_menu (objets locaux, visibles dans l'instance) — à valider en jeu |
| Parties en instance séparée | ✅ bucket 63001+ par partie, copie figée de l'arène — simulé |
| PVP, armes laser, spectateur, rangs, classements | ✅ inchangés, simulés |
| Interface NUI | ✅ 13 écrans testés dans Chromium |
| Appli téléphone (elyzea_aura) | ✅ Zombie retiré, arènes |

## Tests (dernière exécution : `bash tests/run_all.sh`)
- Syntaxe Lua : 35 fichiers, 0 erreur · JS : OK
- Contrats serveur / client / interface / admin_menu : 19/19
- Simulation serveur : 187/187 (1 200 requêtes SQL)
- Interface : 13/13 écrans sans erreur
- admin_menu : liaison 27/27, onglet LaserGame 20/20, autres tests existants 0 échec

## Fichiers modifiés hors de la ressource
- `admin_menu/` : `server/lasergame.lua` (actions d'arène), `html/lasergame.js` (onglet Arènes), `client/editor.lua`
  (`lg_zone_draw`, `lg_spawns_draw`), `client/zones.lua` (fin du dessin envoyée à `tg.action`, couleurs d'équipe facultatives),
  tests `lasergame_ui.cjs` et `lasergame_link_sim.lua`.
- `elyzea_aura/` : appli LaserGame du téléphone (Zombie retiré, arènes sans image).

## Prochaines tâches (après retour en jeu)
1. Créer la première arène et jouer un 1v1 (docs/limitations.md §1).
2. Ajuster `Config.Outfits` selon les packs de vêtements du serveur.
3. Corriger ce que la validation en jeu révélera (journaux : `/lgadmin › Journaux › Erreurs`, console F8).

## Reprise
- Emblèmes : `python3 tools/assets/make_ranks.py` · sons : `python3 tools/assets/make_sounds.py`
- Tous les tests : `bash tests/run_all.sh`
- Archive : `elyzea_lasergame.zip` à la racine du dépôt (régénérer après modification).
