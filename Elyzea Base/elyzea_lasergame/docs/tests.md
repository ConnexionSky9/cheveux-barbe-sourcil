# Rapport de tests — LaserGame ElyzeaFA (v2.0.0)

Tous les tests ci-dessous ont été **réellement exécutés** (environnement Linux, sans GTA V).
Relancer : `bash tests/run_all.sh` (Python 3 + `lupa` ; Node + Playwright / Chromium).

## Résultat de la dernière exécution
| Suite | Résultat |
|---|---|
| Syntaxe Lua 5.4 (35 fichiers : serveur, client, partagé, configuration, tests) | ✅ 0 erreur |
| Syntaxe JavaScript de l'interface | ✅ |
| Contrats serveur ↔ client ↔ interface ↔ admin_menu | ✅ 19 / 19 |
| Simulation du vrai code serveur (1 200 requêtes SQL) | ✅ 187 / 187 vérifications, 0 erreur de fil |
| Interface dans Chromium (13 écrans, interactions) | ✅ 13 / 13 sans erreur JavaScript |
| admin_menu : liaison LaserGame (`tests/run_lasergame_link_sim.py`) | ✅ 27 / 27 |
| admin_menu : onglet LaserGame dans Chromium (`tests/lasergame_ui.cjs`) | ✅ 20 / 20 |
| admin_menu : autres tests existants (requins, caméra libre, portes) | ✅ 0 échec |

## 1. Simulation du serveur (`tests/run_server_sim.py`)
Le vrai code serveur (ordre du fxmanifest) tourne dans Lua 5.4 avec des natives FiveM simulées, une horloge virtuelle
et une vraie base SQLite (requêtes MySQL traduites). Scénarios :
- **Démarrage** : 9 tables, aucune arène, réglages publiés, **plus de mode Zombie** (configuration, constantes, serveur).
- **Arènes (staff)** : refus à un joueur ; création à la position du staff (nom nettoyé) ; arène incomplète invisible et non ouvrable ;
  apparitions refusées avant la zone ; zone de 2 coins, trop grande, coin invalide refusés ; zone de 4 coins (sol, plafond, surface, taille) ;
  apparition hors zone et équipe inconnue refusées ; apparitions avec direction ; ouverture, joueurs max., heure, météo (inconnue ignorée) ;
  liste des joueurs avec silhouette **sans coordonnées du monde** ; enregistrement en base et relecture après redémarrage.
- **Outils « à ma position »** : 2e arène posée coin par coin, plafond, apparitions orientées comme le staff, refus hors zone.
- **Exports pour admin_menu** : permission revérifiée, ouverture d'une arène, liste (zone + apparitions pour les outils de dessin), résumé.
- **PVP** sur ces arènes : création, validations (arène trop petite pour le format), mises, lancement **dans l'instance 63001**,
  tirs laser vérifiés, éliminations, manches, fin de partie, paiement, points, historique, anti-farm, déconnexion, reconnexion,
  redémarrage pendant une partie, spectateur.
- **Staff** : suppression refusée pendant un lobby / une partie ; la partie garde une **copie figée** quand le staff modifie l'arène ;
  arrêt par le staff ; fermer une arène ferme les lobbies et **rembourse** les mises ; apparitions effacées → arène de nouveau incomplète ;
  suppression ; réglages, PNJ, exclusion, rang, recherche, journaux ; aucune mise bloquée.
- **Téléphone** : arènes ouvertes seulement, classements Zombie retirés, annonces PVP (mode Zombie demandé ignoré), rappels, messages.

## 2. Contrats (`tests/contract_check.py`)
Événements serveur → client, messages vers l'interface, rappels NUI, appels serveur autorisés et existants, sons, emblèmes, images ;
arène côté client exécutée (chargement progressif sans blocage, mur invisible dedans / dehors / sol / plafond, heure et météo
appliquées puis rendues, arène invalide refusée) ; **admin_menu** : les 9 actions d'arène du pont existent dans `Maps.Action`,
les boutons de l'onglet y sont reliés, les outils `lg_zone_draw` / `lg_spawns_draw` existent dans l'éditeur et la fin du dessin
envoie à l'action « lasergame » (pvp_arena inchangé) ; fichiers déclarés dans le fxmanifest ; **aucune trace du Zombie** dans le code.

## 3. Interface (`tests/ui_screens.cjs`)
Accueil, PVP (liste, création avec choix d'arène, lobby), classements, profil, historique, paramètres, staff (7 onglets parcourus),
**Arènes** (fiche, action simulée), HUD PVP, résultats, chargement : sans erreur JavaScript, captures enregistrées.

## 4. Ce qui reste à valider en jeu
Ces tests demandent un serveur FiveM et un client GTA V, absents de cet environnement : rendu des lasers, de la paroi de zone,
dessin à l'écran des zones et apparitions, apparition du décor de l'éditeur dans l'instance, caméras, animations, sons,
synchronisation réseau réelle. Voir docs/limitations.md §1.
