# Architecture — LaserGame ElyzeaFA

## Principe
Le **serveur est la seule autorité** : équipes, armes attribuées, dégâts, éliminations, scores, argent, rangs, zombies, portes, atouts.
Le client affiche, anime et envoie des *intentions* (tirs, achats) que le serveur vérifie.

```
             ┌──────────────── client (par joueur) ────────────────┐
  NUI html/  │ interface.lua ── RPC ──┐   laser.lua   (rendu lasers) │
  script.js ◄┤ npc.lua (PNJ, touche E)│   weapons.lua (tirs, boucle) │
             │ maps.lua (construction locale des cartes, mur)        │
             │ pvp.lua · spectator.lua · zombie.lua · doors · perks  │
             └───────────────────────┬──────────────────────────────┘
                     lots de tirs (100 ms) · RPC · confirmations
             ┌───────────────────────▼──────────────────────────────┐
             │ serveur : rpc → security → players (PNJ requis)       │
             │ lobby · games (instances) · combat (validation tirs)  │
             │ pvp · zombie · ranking · economy · restoration        │
             │ settings (réglages en jeu) · maps · admin · logs      │
             │ bridge (elyzea_core / ESX / QBCore) · database        │
             └──────────────────────────────────────────────────────┘
```

## Fichiers
| Dossier | Fichier | Rôle |
|---|---|---|
| shared | `constants.lua` | phases, modes, états, nom des state bags |
| | `config.lua` | armes, rangs, mode Zombie |
| | `utils.lua` | fonctions **pures** testées hors jeu : points Elo, partage du pot, manches, géométrie, formules Zombie |
| | `rpc.lua` | appels client → serveur avec réponse, limite de fréquence, erreurs rattrapées |
| server | `bridge.lua` | identité et argent selon le framework ; permission staff |
| | `logs.lua` · `security.lua` | journaux (console, base, Discord) · limite de fréquence, verrous, événements suspects |
| | `database.lua` | création des 9 tables, profils, réglages |
| | `players.lua` | exclusions ; obligation d'être près d'un PNJ pour entrer dans une partie |
| | `settings.lua` | réglages staff en base, appliqués sans redémarrage, publiés aux clients (`GlobalState.lgPublic`) |
| | `maps.lua` | cartes (JSON), ancre déplaçable, repère local ↔ monde, limites, secteurs |
| | `economy.lua` | mises (journal `lg_ledger`, règlement unique), paiements, remboursements, versements différés |
| | `restoration.lua` | sauvegarde de l'état RP en base, restauration confirmée par le client |
| | `games.lua` · `lobby.lua` | registre des parties, instances, entrée / sortie, déconnexions · lobbies, invitations, liste en direct |
| | `combat.lua` | validation des tirs laser (arme, cadence, chargeur, origine, portée, trajectoire), relais des effets |
| | `pvp.lua` | mode PVP complet (lobby → manches → fin), spectateurs |
| | `zombie.lua` | mode Zombie complet (zombies serveur, IA de combat serveur, acide, portes, armes, atouts, réanimation) |
| | `ranking.lua` | points, rangs, classements (cache 30 s, pagination), historique, profil |
| | `admin.lua` · `main.lua` | interface staff · démarrage, interface, reprise après crash |
| client | `main.lua` | état, utilitaires, apparence (sauvegarde / restauration), adaptateur de framework, réglages publics |
| | `interface.lua` | pont NUI ↔ serveur (liste blanche des appels) |
| | `npc.lua` | PNJ chargés à proximité, blips, touche d'interaction unique |
| | `maps.lua` | construction des cartes (objets locaux, murs ajustés aux dimensions réelles), lumières, tremplins, mur invisible |
| | `laser.lua` · `weapons.lua` | rendu des lasers et effets · tir, recharge, mêlée, envoi groupé, boucle de partie |
| | `restoration.lua` | entrée / sortie de partie, application de l'état RP |
| | `pvp.lua` · `spectator.lua` | HUD et événements PVP · caméra spectateur |
| | `zombie.lua` · `doors.lua` · `perks.lua` | IA locale des zombies contrôlés, à terre / réanimation · portes · atouts et armes murales |
| html | `index.html` · `style.css` · `script.js` | interface complète (menu, lobbies, HUD, résultats, staff) ; mode démo hors jeu |
| maps | `<id>/map.json` | cartes générées (+ `preview.png`, `<id>.ymap.xml`) |
| tools | `mapgen/` · `assets/` | génération et validation des cartes · emblèmes et sons |
| tests | | voir `docs/tests.md` |

## Isolation du RP
- Partie = **routing bucket** dédié (63001+), sans population, verrouillage strict des entités.
- State bag **`pvpArena`** (même contrat que `pvp_arena`) : `elyzea_inventory` refuse toute action d'inventaire, `elyzea_ems` ne met pas
  en coma, `admin_menu` ne fait pas réapparaître à l'hôpital, `elyzea_drogues` et `elyzea_clothing` se mettent en pause.
- L'inventaire RP n'est **jamais** modifié : l'arme RP tenue est rangée (`disarm`), les armes laser sont des armes GTA temporaires,
  retirées à la sortie. Rien ne peut donc être perdu ni dupliqué.
- Sauvegarde RP (instance, position, cap, vie, gilet, vêtements) écrite **en base avant** l'entrée, supprimée seulement quand le client a
  confirmé la restauration. Rejouée à la reconnexion, au redémarrage, ou avec `/lgrestore`.

## Tirs laser
1. Le client tire un rayon depuis la caméra (dispersion de l'arme), la couverture l'arrête, et il affiche le faisceau immédiatement.
2. Les tirs sont envoyés par lots toutes les 100 ms : origine, direction, point d'impact, cible.
3. Le serveur vérifie : partie et phase, joueur vivant, arme attribuée, cadence (seau à jetons), chargeur et recharge,
   origine à moins de 6 m de sa position serveur, cible dans la partie (pas un coéquipier), cible proche de la trajectoire et à portée.
4. Dégâts = table serveur. Effets relayés **seulement** aux membres de la partie, regroupés toutes les 100 ms.

## Zombies
Créés **par le serveur** (`CreatePed`) dans l'instance. Le client propriétaire réseau anime la poursuite ; le serveur calcule les attaques
(distance serveur, délai), les crachats d'acide (flaque, dégâts par intervalle) et les points de vie. Limites : `maxAlive` par partie,
70 sur tout le serveur. Un zombie coincé ou sorti de la carte est replacé.

## Cartes
Construites localement chez chaque joueur de l'instance : aucun coût pour le reste du serveur, invisibles en RP, plusieurs parties
possibles sur la même carte. Les murs sont découpés avec les **dimensions réelles** des modèles mesurées en jeu (même algorithme que
l'outil Python, vérifié par `tests/contract_check.py`).
