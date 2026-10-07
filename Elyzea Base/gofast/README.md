# Go Fast — missions dynamiques pour FiveM

Missions de convoyage générées dynamiquement, 4 paliers de difficulté débloqués par niveau, police et événements aléatoires, HUD NUI. Fonctionne avec la **base Elyzea** (elyzea_core), en **ESX**, **QBCore** ou **standalone** (`Config.Framework = 'auto'` détecte tout seul).

**Version 1.1** : les contacts (PNJ) se créent et se gèrent **en jeu** depuis le menu staff `admin_menu`
(onglet **Événements › GoFast**) : emplacements multiples, déplacements automatiques, dialogues, contrats,
destinations et réglages. Un **encadré d'objectifs** guide le joueur du lancement à la fin du Go Fast.

## 1. Arborescence

```
gofast/
├── fxmanifest.lua        manifeste (OneSync obligatoire)
├── config.lua            toute la configuration (partagée client + serveur)
├── README.md             ce guide
├── client/
│   ├── utils.lua         helpers : notifications, sons, blips, markers, modèles
│   ├── vehicle.lua       véhicule de mission : déverrouillage, préparation, état, perte
│   ├── missions.lua      déroulement : HUD, livraisons, checkpoints, événements, alertes police
│   ├── objectives.lua    encadré d'objectifs (quoi faire maintenant, étapes, alertes)
│   └── main.lua          contacts PNJ (reçus du serveur), interactions, menu NUI, commandes, export
├── server/
│   ├── security.lua      logs, rate limit, jetons, flags anti-exploit
│   ├── rewards.lua       bridge framework, XP / niveaux, calcul et paiement
│   ├── storage.lua       sauvegarde data/gofast.json + réglages modifiés en jeu
│   ├── contacts.lua      contacts : emplacements, rotation, dialogues, synchro clients
│   ├── main.lua          génération, spawn, cycle de vie, surveillance, police, commandes
│   └── admin.lua         interface pour le menu staff (exports AdminGetData / AdminAction)
├── data/
│   └── LISEZMOI.txt      la sauvegarde gofast.json est créée ici (ne pas écraser en mise à jour)
├── shared/
│   └── utils.lua         fonctions communes (textes, plaques, niveaux…)
└── web/
    ├── index.html        HUD, menu du contact, bilan, notifications
    ├── style.css         thème « autoroute de nuit »
    └── app.js            logique NUI
```

## 2. Fichiers

Ordre de chargement (fxmanifest) : `config.lua` et `shared/utils.lua` partout, puis côté client `utils → vehicle → missions → objectives → main`, côté serveur `security → rewards → storage → contacts → main → admin`. Chaque fichier commence par un en-tête qui décrit son rôle.

## 3. Dépendances

| Élément | Obligatoire | Rôle |
|---|---|---|
| OneSync (Legacy ou Infinity) | **oui** | le véhicule est créé côté serveur |
| elyzea_core (ou es_extended / qb-core) | non | sinon mode standalone |
| elyzea_core | non | uniquement si `Config.XP.Storage = 'database'` (sinon KVP intégré) |
| ox_target **ou** qb-target | non | si `Config.Interaction.Mode` les utilise |
| ox_lib | non | si `Config.Notify.Type = 'ox_lib'` |
| ox_inventory | non | récompenses objets (détecté automatiquement) |
| LegacyFuel / cdn-fuel / ox_fuel | non | carburant (détecté automatiquement) |
| qb-vehiclekeys / wasabi_carlock / MrNewbVehicleKeys | non | clés (fonction `Config.Vehicle.GiveKeys`) |
| admin_menu (MenuStaff Elyzea FA) 1.7+ | conseillé | gestion en jeu (contacts, dialogues, réglages). Sans lui, active `Config.Manage.SeedDefaultContacts` |

## 4. Installation

1. Copier le dossier `gofast` dans `resources/` (ou un sous-dossier `[jobs]`, etc.). Le nom du dossier peut changer, la NUI s'adapte.
2. Ouvrir `config.lua`, choisir le framework, le mode d'interaction et le compte de paiement.
3. **Créer les contacts en jeu** : menu staff (F10) › **Événements › GoFast › Contacts** (voir section « Gestion en jeu »).
   Sans admin_menu : mets `Config.Manage.SeedDefaultContacts = true` pour créer les deux contacts d'exemple au premier démarrage.
4. Le dossier `data/` doit exister (il est fourni) : c'est là qu'est écrit `gofast.json`.
5. Ajouter les lignes `server.cfg` ci-dessous et redémarrer le serveur (pas seulement la ressource la première fois si tu ajoutes des convars).
6. Si `Config.XP.Storage = 'database'`, la table `gofast_players` est créée automatiquement au démarrage.

## 5. server.cfg

```cfg
# OneSync obligatoire
set onesync on

# Ordre de démarrage : framework -> base de données -> cibles -> gofast
ensure elyzea_core
# (ou es_extended / qb-core sur un autre serveur)
ensure ox_lib             # si utilisé
ensure ox_target          # ou qb-target, si utilisé
ensure admin_menu
ensure gofast

# Logs Discord (le webhook reste côté serveur, jamais envoyé aux clients)
set gofast_webhook "https://discord.com/api/webhooks/XXXX/YYYY"

# Commande d'administration
add_ace group.admin command.gofastadmin allow

# Mode standalone uniquement : qui est considéré comme policier
add_ace group.police gofast.police allow
add_principal identifier.license:XXXXXXXX group.police
```

Les rivaux (événement aléatoire) sont créés par le client du joueur : si tu utilises `sv_entityLockdown strict`, cet événement ne pourra pas apparaître (le reste du script fonctionne). Utilise `relaxed` ou retire `rivals` des `events.pool`.

## Gestion en jeu (menu staff › Événements › GoFast)

Permissions (onglet Grades) : `gofast_manage` (contacts, contrats, destinations, réglages — SuperAdmin par défaut)
et `gofast_missions` (missions en cours, XP et attente des joueurs — Administrateur et SuperAdmin).

**Créer un contact** : place-toi exactement là où le PNJ doit se tenir, tourné dans la direction de son regard,
donne-lui un nom, une apparence et une animation, puis « Créer à ma position ». Un point d'apparition du véhicule
est ajouté automatiquement sur la route la plus proche. Tu peux aussi convertir un PNJ « Décor » déjà posé avec
l'éditeur de map (bouton « 🏎️ Contact GoFast » sur sa fiche).

**Emplacements** : un contact peut avoir jusqu'à 20 emplacements. Chacun a ses **points véhicule** : monte dans une
voiture garée au bon endroit et clique « Ajouter un point véhicule » (sa position exacte est reprise). Sans point
véhicule, aucune mission ne peut démarrer depuis cet emplacement (signalé en rouge dans le menu).

**Déplacements** : « Ne bouge pas », « Tour à tour » ou « Au hasard », toutes les X à Y minutes (tirage entre les deux).
Option « Seulement quand personne n'est autour » : il attend qu'aucun joueur ne soit à moins de
`Config.Manage.MoveCheckRadius` mètres. Boutons « Faire venir ici » et « Le déplacer maintenant » pour forcer.

**Dialogues** : 5 moments (accueil, refus/attente, contrat accepté, réussite, échec). Une réplique est tirée au hasard.
Variables : `{joueur}` `{contact}` `{niveau}` `{palier}` `{temps}`. Liste vide = répliques de `Config.DefaultDialogues`.

**Contrats, destinations, réglages** : toutes les valeurs de config.lua sont les valeurs par défaut ; ce qui est modifié
dans le menu est enregistré dans `data/gofast.json` et peut être remis par défaut. **Fermer le réseau** fait disparaître
tous les contacts (les missions en cours continuent).

## Encadré d'objectifs

Pendant un Go Fast, un petit panneau (milieu gauche de l'écran, entre le chat et la minimap) indique :
l'objectif actuel et la consigne (« Va chercher la Kuruma · plaque GF12AB34 · 350 m », « Arrête-toi pour livrer »,
« Remonte dans le véhicule »…), les étapes cochées au fur et à mesure, et les alertes (police prévenue, balise GPS,
rivaux, moins de 30 s). Il disparaît à la fin du Go Fast, avec `/gofasthud` et dans le menu pause.
Réglages : `Config.Objectives` (`Enabled`, `Position` = `left` / `right` / `bottom`, `KeyLabel`, `Refresh`).

## 6. Guide de `config.lua`

**Général** — `Framework` (`auto`, `esx`, `qbcore`, `standalone`), `Debug`, `CurrencySymbol`, `SpeedUnit` (`kmh`/`mph`).

**Interaction** — `Mode` : `key` (touche + marker), `ox_target` ou `qb-target` pour le contact. `Key` (38 = E) sert aussi au véhicule et à la livraison. `SpawnDistance` : le PNJ contact n'est créé qu'à proximité.

**Notify / Sounds** — `Notify.Type` : `nui` (toasts du script), `esx`, `qbcore`, `ox_lib`, `gta`. Chaque son est `{ name, set }` ; `Sounds.Enabled = false` coupe tout.

**Logs** — catégories activables une par une, couleurs Discord. Le webhook se règle dans `server.cfg`.

**Cooldown** — en secondes, par licence Rockstar : `Success`, `Fail`, `Abandon`, `Disconnect`, et `Global` (délai entre deux lancements sur tout le serveur).

**Mission** — `MaxActive` (Go Fast simultanés), `PickupTimeout`, `AwayDistance` + `AwayTimeout` (éloignement du véhicule), `DestroyedEngineHealth`, `DeliveryRadius`, `DeliveryMaxSpeed`, `RequireKeyToDeliver`, `TickInterval` (boucle serveur), `RecentDestinationsMemory`, `ClearWantedOnEnd` (efface la recherche à la réussite), `LeaveVehicleOnEnd`.

**Security** — toutes ces valeurs sont contrôlées côté serveur : distances maximales (contact, véhicule, checkpoint, livraison), `MaxAverageSpeed` (anti-téléportation), `MinMissionDuration`, `RateLimitMs`, `KickOnExploit` + `MaxFlags`.

**Vehicle** — `PlatePattern` (`#` chiffre, `@` lettre, `*` l'un ou l'autre, 8 caractères max), `ClearRadius` (zone qui doit être libre), `UnlockDistance`, `AutoUnlock`, `FuelLevel`, `DeleteDelay` / `DeleteTimeout`, marker au-dessus du véhicule, fonctions `SetFuel` et `GiveKeys` à adapter à tes scripts.

**Delivery / Checkpoints / Blips** — marker et PNJ de livraison, rayon des checkpoints, `CorridorRatio` (détour maximum autorisé), réglages des blips (sprite, couleur, échelle, itinéraire GPS).

**Police** — `Enabled`, `Jobs`, `RequireOnDuty`, `AcePermission` (standalone), `BlockPoliceFromMissions`, `Mode` (`builtin` = blips + notifications intégrés, `custom` = ta fonction `CustomDispatch`, exemple cd_dispatch fourni), `NotifyDriver`, `ShowPlate`, `ShowVehicleModel`, `Blip` (zone, durée).

**RandomEvents** — `wanted` (niveau de recherche), `rivals` (véhicules, PNJ, armes, nombre, précision, distances, durée), `tracker` (balise GPS : la police reçoit la position régulièrement).

**Rare / Rewards / XP / Levels** — multiplicateurs des missions rares ; compte de paiement par framework (`black_money` par défaut en ESX) ; bonus par niveau, bonus rapidité, pénalité de dégâts, bonus par checkpoint ; stockage XP (`kvp` ou `database`), pénalités d'XP ; seuils d'XP par niveau ; libellés de risque.

**Manage** — fichier de sauvegarde, `SeedDefaultContacts`, valeurs d'un nouveau contact (modèle, animation, icône), blip et cercle au sol des contacts, rayon « personne autour », limites (contacts, emplacements, points véhicule, répliques).

**DialogueCategories / DefaultDialogues** — les 5 moments de dialogue et leurs répliques par défaut.

**MissionGivers** — uniquement les exemples créés si `SeedDefaultContacts = true`.

**Objectives** — encadré d'objectifs (voir plus haut).

**Destinations** — `label`, `zone` (`city`, `county`, `north` ou tes propres zones), `coords` au niveau du sol. Les destinations non choisies servent de checkpoints.

**Tiers** — un palier = `minLevel`, `risk` (1 à 5), `zones`, `drops` (min, max), distances des étapes, `time` (base + par km), `reward` (min, max, par km), `xp`, nombre de `checkpoints`, `vehicleUpgrade` (0 à 1), `vehicles` / `rareVehicles`, `rareChance`, `police` (chance, délai, balise, policiers minimum), `events` (chance, maximum, pool, fenêtre), `items` (récompenses objets avec chance).

**Lang** — tous les textes. Les `%s` doivent être conservés.

## 7. Commandes, events et exports

**Commandes**

| Commande | Côté | Description |
|---|---|---|
| `/gofastabandon` | serveur | abandonne la mission en cours |
| `/gofasthud` | client | masque / affiche le HUD |
| `/gofastadmin list` | serveur (ace) | missions actives |
| `/gofastadmin stop <id>` | serveur (ace) | annule la mission d'un joueur (sans cooldown) |
| `/gofastadmin resetcd <id>` | serveur (ace) | réinitialise le cooldown |
| `/gofastadmin info <id>` | serveur (ace) | niveau, XP, missions, cooldown |
| `/gofastadmin setxp <id> <xp>` / `addxp <id> <xp>` | serveur (ace) | modifie l'XP |
| `/gofastcoords` | client | relève la position (uniquement si `Config.Debug`) |

**Events client → serveur** (tous vérifiés : rate limit, jeton de mission, distances, phase)
`gofast:server:requestMenu (giverId)`, `gofast:server:startMission (giverId, tierId)`, `gofast:server:requestUnlock (token)`, `gofast:server:checkpointReached (token, index)`, `gofast:server:deliver (token, dropIndex)`, `gofast:server:abandon ()`, `gofast:server:vehicleLost (token, reason)`, `gofast:server:registerEventEntities (token, netIds)`.

**Events serveur → client**
`gofast:client:notify`, `gofast:client:openMenu`, `gofast:client:missionStarted`, `gofast:client:vehicleUnlocked`, `gofast:client:checkpointValidated`, `gofast:client:nextDrop`, `gofast:client:missionEnded`, `gofast:client:awayWarning`, `gofast:client:randomEvent`, `gofast:client:policeAlert`, `gofast:client:policeTrackerUpdate`, `gofast:client:policeTrackerStop`, `gofast:client:contacts` (liste des contacts), `gofast:client:policeAlerted`.

Client → serveur, en plus : `gofast:server:requestContacts` (au chargement, limité).

**Hooks serveur (standalone)** — à écouter dans ta propre ressource :
```lua
AddEventHandler('gofast:standalone:addMoney', function(source, account, amount) end)
AddEventHandler('gofast:standalone:addItem', function(source, itemName, count) end)
```

**Exports**
```lua
-- serveur
exports.gofast:HasActiveMission(source)   -- boolean
exports.gofast:GetActiveMission(source)   -- résumé de la mission ou nil
exports.gofast:GetPlayerLevel(source)     -- { level, xp, currentLevelXp, nextLevelXp, maxLevel }
exports.gofast:AddXP(source, amount)
exports.gofast:CancelMission(source)
exports.gofast:AdminGetData()                       -- utilisé par admin_menu
exports.gofast:AdminAction(source, nom, data)       -- utilisé par admin_menu (réponse : évènement serveur 'gofast:adminReply')
-- client
exports.gofast:IsInGoFast()               -- boolean
```

## 8. Checklist de test

1. Au démarrage, la console affiche `Framework détecté : ...` sans erreur rouge.
2. Le blip du contact apparaît ; le PNJ apparaît en approchant et disparaît au loin.
3. Interaction (touche ou target) : le menu s'ouvre, Échap le ferme et rend la souris.
4. Un palier au-dessus de ton niveau est grisé avec « Niveau X requis » ; un palier sans assez de policiers est bloqué.
5. Accepter un contrat : véhicule au point de spawn, plaque au format choisi, portes verrouillées, blip + itinéraire.
6. Bloquer le point de spawn avec une voiture : un autre point est utilisé, ou le message « zone encombrée » s'affiche.
7. Deux joueurs lancent en même temps : deux véhicules distincts, aucun sur le même point.
8. Déverrouillage par touche au véhicule : destination révélée, timer de transit, carburant plein, clés données.
9. Passer un checkpoint : blip retiré, récompense estimée augmentée dans le HUD.
10. Livrer en roulant : refusé ; à l'arrêt : étape suivante, puis paiement final et bilan.
11. Relancer immédiatement : message de cooldown, menu affichant le temps restant.
12. Abandon (`/gofastabandon` ou bouton du menu) : échec, véhicule supprimé, XP retirée, cooldown d'abandon.
13. Détruire le véhicule ou le jeter à l'eau : échec et suppression.
14. S'éloigner de plus de `AwayDistance` : bandeau rouge avec compte à rebours, puis échec.
15. Se déconnecter pendant une mission : véhicule supprimé, cooldown de déconnexion à la reconnexion.
16. Laisser expirer le temps : échec « temps écoulé ».
17. Avec un policier en service : alerte reçue (blip + zone), balise suivie sur le palier Fantôme.
18. Déclencher l'event `gofast:server:deliver` à la main depuis un exécuteur : refusé (jeton, distance, vitesse) et loggué en `exploit`.
19. `restart gofast` en pleine mission : véhicule, PNJ, blips et HUD nettoyés.
20. `/gofastadmin info <id>` puis `setxp` : le niveau du menu change à la réouverture.
21. Menu staff › Événements › GoFast › Contacts : créer un contact à ta position → le PNJ apparaît, son blip aussi.
22. Ajouter un 2e emplacement, « Faire venir ici » → le PNJ change de place pour tous les joueurs.
23. Mode « Au hasard », 1 à 1 min, option « personne autour » cochée : il ne bouge pas tant que tu es à côté, bouge quand tu t'éloignes.
24. Ajouter une réplique d'accueil avec `{joueur}` → elle s'affiche à l'ouverture du menu avec ton nom.
25. Modifier un contrat (paie, niveau) → le menu du contact affiche les nouvelles valeurs ; « Valeurs par défaut » les remet.
26. Fermer le réseau → les contacts disparaissent ; le rouvrir → ils reviennent.
27. `restart gofast` : contacts, emplacements, dialogues et réglages sont conservés.
28. Pendant un Go Fast : l'encadré d'objectifs change à chaque étape (récupération, livraison, arrêt, remonter dans le véhicule) et disparaît à la fin.
