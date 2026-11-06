# Configuration — LaserGame ElyzeaFA

Deux fichiers : **`config.lua`** (général, PNJ, argent, PVP, spectateur, sécurité, journaux) et **`shared/config.lua`**
(armes laser, rangs). Les **arènes** ne sont pas dans les fichiers : elles se créent en jeu (docs/administration.md). Presque tout se règle aussi **en jeu** avec `/lgadmin` : ces réglages sont
enregistrés en base et remplacent les valeurs des fichiers (bouton « réinitialiser » pour revenir aux fichiers).

## config.lua
| Réglage | Rôle |
|---|---|
| `Config.Framework` | `'auto'` (elyzea_core → ESX → QBCore), ou forcé |
| `Config.Permission` / `Config.AcePermission` | permission admin_menu (`lasergame_manage`) / ACE (`elyzea_lasergame.admin`) |
| `Config.BucketBase`, `Config.MaxParallelGames` | instances 63001… ; nombre de parties simultanées |
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
Chaque arme : `model` (arme GTA tenue en main, visuel seulement), `damage`, `range`, `rpm` (cadence),
`spread`, `mag` (0 = sans recharge), `reload` (ms), `beam` (`pulse`, `beam`, `rail`, `scatter`, `blade`), `width`, `life`, `sound`, `tier`.
5 catégories : mêlée, pistolet, mitraillette, fusil d'assaut, sniper.

### Rangs (`LG.Ranks`, `LG.Ranking`)
8 rangs (BRONZE → LEGEND) avec seuils de points modifiables. Calcul des points :
- base Elo par équipe : `k × (résultat − probabilité de victoire)` (battre plus fort rapporte plus) ;
- `kNewPlayer` pendant les `placementMatches` premiers matchs ;
- performance individuelle (éliminations − morts) plafonnée à ±`perfBonusMax` ; bonus de série ;
- une victoire rapporte toujours au moins 1 point, une défaite en coûte au moins 1 ;
- **anti-farm** : contre les mêmes adversaires dans `repeatWindowHours`, points × `repeatFactors` (1 ; 0,75 ; 0,5 ; 0,25 ; 0) ;
  pénalité `leaverPenalty` pour un abandon ; parties privées et parties trop courtes non classées.

## Arènes (créées en jeu, table `lg_arenas`)
Limites (dans `server/maps.lua › Maps.LIMITS`) : 50 arènes, 60 coins par zone, 20 apparitions par équipe, 450 m de côté maximum,
zone d'au moins 16 m² et 3 m de haut. Chaque arène : nom, description, zone (coins, sol, plafond), apparitions ROUGE / BLEUE
(position + direction), joueurs max. par équipe (1 à 6), heure et météo facultatives.
