# PROJECT_STATUS — elyzea_lasergame

Fichier de reprise : état réel du projet, mis à jour à chaque étape.

## État
| Phase | Contenu | État |
|---|---|---|
| 1 | Analyse technique et architecture | ✅ |
| 2 | Outils (Python, Node, Chromium/Playwright, lupa, ffmpeg) | ✅ (CodeWalker / Blender / GTA V Map Agent indisponibles sous Linux sans GTA : voir Limites) |
| 3 | Interface NUI | ⏳ |
| 4 | PNJ, interactions, instances | ✅ code écrit |
| 5 | 4 cartes PVP | ⏳ |
| 6 | PVP, armes laser, spectateur | ✅ code écrit |
| 7 | Rangs et classements | ✅ code écrit (emblèmes ⏳) |
| 8 | Carte Zombie | ⏳ |
| 9 | Mode Zombie | ✅ code écrit |
| 10 | Interface staff | ✅ serveur · ⏳ NUI |
| 11 | Sécurité, restauration RP | ✅ code écrit |
| 12 | Tests, corrections, optimisation | ⏳ |

## Fichiers
- `server/` : bridge, logs, security, database, players, settings, maps, economy, restoration, games, lobby, combat, ranking, pvp, zombie, admin, main
- `client/` : main, interface, npc, maps, laser, weapons, restoration, pvp, spectator, zombie, doors, perks, admin
- `shared/` : constants, config (armes, rangs, Zombie), utils (fonctions pures), rpc

## Prochaines tâches
1. Générateur de cartes (tools/mapgen) + 5 cartes + validation + aperçus
2. Emblèmes des rangs (SVG → PNG), sons (synthèse → OGG)
3. NUI complète
4. Tests (lupa : simulation serveur ; Playwright : NUI ; Python : cartes)
5. Docs, intégration admin_menu, server.cfg, ZIP
