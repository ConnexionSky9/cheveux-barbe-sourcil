# Configuration — LaserGame ElyzeaFA

Deux fichiers : **`config.lua`** (général, PNJ, argent, PVP, spectateur, sécurité, journaux) et **`shared/config.lua`**
(armes laser, rangs, mode Zombie). Presque tout se règle aussi **en jeu** avec `/lgadmin` : ces réglages sont
enregistrés en base et remplacent les valeurs des fichiers (bouton « réinitialiser » pour revenir aux fichiers).

## config.lua
| Réglage | Rôle |
|---|---|
| `Config.Framework` | `'auto'` (elyzea_core → ESX → QBCore), ou forcé |
| `Config.Permission` / `Config.AcePermission` | permission admin_menu (`lasergame_manage`) / ACE (`elyzea_lasergame.admin`) |
| `Config.BucketBase`, `Config.MaxParallelGames` | instances 63001… ; nombre de parties simultanées (PVP + Zombie) |
| `Config.Npcs` | PNJ : `model`, `coords` (vector4), `scenario` ou `anim`, `distance`, `label`, `text`, `blip` |
| `Config.Account` | compte des mises : `'bank'` ou `'cash'` |
| `Config.Stake` | mises : `enabled`, `min`, `max`, `step`, `houseFeePct` (commission, 0 = aucune) |
| `Config.LeaverForfeitsShare` | un joueur parti en cours de partie ne touche pas de part du pot |
| `Config.PvP.formats` | 1v1 à 6v6 (désactivables en jeu) |
| `Config.PvP.roundsOptions`, `roundTimeOptions` | choix proposés au créateur |
| `Config.PvP.requireEqualTeams`, `requireFullTeams` | équilibrage obligatoire avant le lancement |
| `Config.PvP.shield`, `oneHitElimination` | bouclier laser (100) ; ou élimination en un tir (laser game classique) |
| `Config.PvP.timeoutRule` | temps écoulé : `most_alive` (plus de vivants, puis plus de bouclier) ou `draw` |
| `Config.PvP.ranked`, `minRankedDuration` | parties classées (publiques oui, privées non) ; durée minimale de jeu |
| `Config.PvP.timers` | chargement, décompte, fin de manche, écran de fin |
| `Config.Teams` | noms et couleurs (RVB + hex) des équipes : lasers, HUD |
| `Config.Outfits` | gilet coloré par équipe (composant 9). Mets `enabled = false` si tes packs de vêtements ne correspondent pas |
| `Config.Spectator` | activation, nombre max, éliminé = coéquipiers seulement, bouclier adverse masqué |
| `Config.Security` | limite d'événements / s, tolérance d'origine des tirs, exclusion auto après N événements suspects (0 = jamais) |
| `Config.Logs` | console, base, Discord ; conservation (jours) |

## shared/config.lua
### Armes laser (`LG.Weapons`)
Chaque arme : `model` (arme GTA tenue en main, visuel seulement), `damage` (PVP), `zDamage` (Zombie), `range`, `rpm` (cadence),
`spread`, `mag` (0 = sans recharge), `reload` (ms), `beam` (`pulse`, `beam`, `rail`, `scatter`, `blade`), `width`, `life`, `sound`, `tier`.
`zombieOnly = true` : arme réservée aux murs de la carte Zombie. 5 catégories : mêlée, pistolet, mitraillette, fusil d'assaut, sniper.

### Rangs (`LG.Ranks`, `LG.Ranking`)
8 rangs (BRONZE → LEGEND) avec seuils de points modifiables. Calcul des points :
- base Elo par équipe : `k × (résultat − probabilité de victoire)` (battre plus fort rapporte plus) ;
- `kNewPlayer` pendant les `placementMatches` premiers matchs ;
- performance individuelle (éliminations − morts) plafonnée à ±`perfBonusMax` ; bonus de série ;
- une victoire rapporte toujours au moins 1 point, une défaite en coûte au moins 1 ;
- **anti-farm** : contre les mêmes adversaires dans `repeatWindowHours`, points × `repeatFactors` (1 ; 0,75 ; 0,5 ; 0,25 ; 0) ;
  pénalité `leaverPenalty` pour un abandon ; parties privées et parties trop courtes non classées.

### Mode Zombie (`LG.Zombie`)
- `player` : vie (100 = 3 coups), régénération, temps à terre, durée de réanimation ;
- `rounds` : nombre de zombies (base + par manche, × nombre de joueurs), présents en même temps (`maxAlive`),
  résistance (linéaire puis exponentielle), dégâts (plafonnés), vitesse (proportion de coureurs / sprinteurs) ;
- `types` : classique, rapide, résistant, spécial, cracheur d'acide (modèles, multiplicateurs, récompense, poids, manche d'apparition,
  `acid` : portée, délai, rayon et durée de la flaque, dégâts par intervalle) ;
- `money` : par impact, bonus corps à corps, bonus de réanimation, bonus de manche, argent de départ ;
- `perks` : 8 atouts (Mastodonte, Rapidité, Rechargement rapide, Double dégâts, Résistance acide, Réanimation rapide, Régénération,
  Protection) avec prix et effets ; `maxPerks` par joueur.
- Prix des **portes** et des **armes murales** : dans la carte (`maps/zombie_map/map.json`) et modifiables en jeu.

## Cartes
Les cartes sont **générées** par `tools/mapgen` (Python) : ne modifie pas `map.json` à la main, modifie `tools/mapgen/maps_pvp.py`
ou `map_zombie.py`, puis :
```bash
python3 tools/mapgen/build_all.py
```
Le script valide chaque carte (accessibilité, apparitions non exposées, équilibre, fentes, secteurs Zombie) et refuse une carte invalide.
L'emplacement dans le monde (ancre) se change en jeu (`/lgadmin › Cartes › Placer ici`), sans régénérer.
