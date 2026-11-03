# PROJECT_STATUS — elyzea_lasergame

Fichier de reprise : état réel du projet. Dernière mise à jour : livraison v1.0.0.

## État global : v1.0.0 livrée, tous les tests hors jeu passent, validation en jeu à faire
| Phase | Contenu | État |
|---|---|---|
| 1 | Analyse technique et architecture | ✅ base Elyzea (elyzea_core), contrat `pvpArena` réutilisé |
| 2 | Outils | ✅ Python 3, Node 22, Chromium/Playwright, lupa (Lua 5.4), numpy, Pillow, ffmpeg · ❌ CodeWalker, Blender/Sollumz, GTA V Map Agent (Windows / fichiers GTA requis) → générateur de cartes Python |
| 3 | Interface NUI | ✅ 16 écrans testés dans Chromium |
| 4 | PNJ, interactions, instances | ✅ config + en jeu + éditeur admin_menu (rôle « LaserGame ») |
| 5 | 4 cartes PVP | ✅ construites, validées (0 erreur), aperçus |
| 6 | PVP, armes laser, spectateur | ✅ simulé (serveur) · client vérifié statiquement |
| 7 | Rangs et classements | ✅ 8 emblèmes SVG + PNG, Elo + anti-farm, 10 classements |
| 8 | Carte Zombie | ✅ 8 secteurs, 9 portes, 13 armes murales, 8 atouts, validée |
| 9 | Mode Zombie | ✅ simulé (serveur) · client vérifié statiquement |
| 10 | Interface staff | ✅ 9 onglets, toutes actions simulées côté serveur |
| 11 | Sécurité, restauration RP | ✅ simulé (crash, déconnexion, reconnexion, redémarrage) |
| 12 | Tests, corrections, optimisation | ✅ hors jeu · ⏳ validation en jeu (docs/limitations.md §1) |

## Tests (dernière exécution : `bash tests/run_all.sh`)
- Syntaxe Lua : 38 fichiers, 0 erreur · JS : OK
- Cartes : 5/5 valides, 0 avertissement
- Contrats serveur/client/interface : 10/10
- Simulation serveur : 157/157 (420 requêtes SQL)
- Interface : 16/16 écrans sans erreur
- admin_menu (tests existants) : 0 échec après intégration

## Bogues trouvés et corrigés grâce aux tests
- Paramètres SQL `nil` (journaux sans citizenid, égalité sans gagnant) : la requête aurait échoué en production → `NULLIF(?, '')`.
- `brand.js` et logos non déclarés dans le fxmanifest → ajoutés.
- Spectateur resté sur écran noir → fondu ajouté.
- Mot réservé Lua `until` utilisé comme champ → renommé.
- Fentes de 0,4 à 0,7 m entre objets (risque de se coincer) et 2 apparitions de zombies dans des caisses → corrigées.
- Glitch du titre resté affiché → n'apparaît plus que pendant l'animation.

## Fichiers modifiés hors de la ressource
- `admin_menu/` : rôle de PNJ « LaserGame » (html/script.js, server/editor.lua, client/editor.lua), export `GetLaserGameNpcs`,
  permission `lasergame_manage` (config.lua).
- `Serveur cfg/server.cfg` : `ensure elyzea_lasergame`.

## Prochaines tâches (après retour en jeu)
1. Validation en jeu (docs/limitations.md §1) et ajustement des emplacements de cartes (`/lgadmin › Cartes › Placer ici`).
2. Ajuster `Config.Outfits` selon les packs de vêtements du serveur.
3. Corriger ce que la validation en jeu révélera (journaux : `/lgadmin › Journaux › Erreurs`, console F8).

## Reprise
- Régénérer les cartes : `python3 tools/mapgen/build_all.py` · emblèmes : `python3 tools/assets/make_ranks.py` · sons : `python3 tools/assets/make_sounds.py`
- Tous les tests : `bash tests/run_all.sh`
- Archive : `elyzea_lasergame.zip` à la racine du dépôt (régénérer après modification).
