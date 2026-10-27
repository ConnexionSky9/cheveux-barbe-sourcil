# Audit multipersonnage et tatouages

## Architecture vérifiée

- **Framework :** base Elyzea (`elyzea_core`). Ce n'est ni ESX, ni QBCore, ni Qbox, mais le joueur a la même forme que QBCore (`PlayerData`, `citizenid`).
- **Sélection :** `elyzea_multichar` (écran et aperçu).
- **Création, connexion, apparence :** `ely_creator`.
- **Identifiant d'un personnage :** `players.citizenid`. La licence (`players.license`) identifie le **compte** : elle est commune à tous les personnages.
- **Connexion :** `elyzea_core › Login` → `elyzea:server:playerLogin` → apparition (`ely_creator:spawn`) → `elyzea:server:playerLoaded` / `elyzea:client:playerLoaded`.
- **Changement de personnage (`/logout`) :** `Logout` → `Save` → `elyzea:server:playerUnloaded` (avec le citizenid) → `elyzea:client:playerUnloaded` → écran de sélection.
- **Point clé :** si les deux personnages ont le même sexe, **le ped reste le même** (même modèle). Tout ce qui est posé sur le ped et que personne n'enlève passe donc d'un personnage à l'autre.

## Cause exacte des tatouages partagés

Les tatouages sont gérés par **admin_menu** : `client/tattoo.lua` et `server/tattoo.lua`. Ils sont rangés dans `admin_menu/data/tattoo_looks.json`.

1. **Le ped n'était jamais nettoyé.** GTA garde les tatouages (« décorations ») sur le ped. Ni `ely_creator` (ApplySkin) ni `elyzea_multichar` (aperçu) n'appelaient `ClearPedDecorations`. Au passage de A à B (même sexe), les tatouages de A restaient donc sur B.
2. **La liste de A restait en mémoire.** `SavedTattoos` était réappliquée à B à l'événement `ely_creator:loaded`, avant que la liste de B n'arrive. Et la réapplication ne faisait qu'**ajouter**, jamais retirer.
3. **Les tatouages de A étaient ensuite enregistrés sur B.** À l'ouverture du salon, le point de départ était « ce que porte le ped » (`GetPedDecorations`). Au paiement de B, la liste envoyée contenait donc les tatouages de A, enregistrés définitivement sur B.
4. **Repli sur la licence.** Sans personnage chargé, la clé de sauvegarde retombait sur la licence (`Bridge.GetCharId` → `license:`), commune à tous les personnages du compte.
5. **Sauvegarde différée de 3 s** (`saveLater`). Un redémarrage brutal juste après l'achat pouvait la perdre.

Le **barbier** d'admin_menu (coupe, barbe, couleurs, `client/barber.lua` et `server/barber.lua`) avait exactement les mêmes défauts 2 et 4 : la coupe de A était remise sur B.

## Corrections

| Fichier | Correction |
|---|---|
| `admin_menu/server/tattoo.lua` | Clé = citizenid uniquement (jamais la licence). La liste est envoyée **avec son citizenid**. Liste finale **calculée par le serveur** = tatouages enregistrés du personnage, moins les retraits, plus les ajouts (on ne fait plus confiance au ped). Enregistrement immédiat (`Storage.save`). Paiement refusé (sans débit) si aucun personnage n'est chargé. Nouvel export `GetTattoosByCid`. |
| `admin_menu/client/tattoo.lua` | Liste rattachée au citizenid. Au chargement d'un personnage : `ClearPedDecorations`, puis **exactement** ses tatouages. À la déconnexion du personnage : tout est vidé. Réponse en retard pour un autre personnage : ignorée. Salon : point de départ = tatouages enregistrés. Application immédiate de la liste renvoyée par le serveur. |
| `admin_menu/server/barber.lua` | Clé = citizenid uniquement, citizenid envoyé avec la tête, enregistrement immédiat, paiement refusé sans personnage. |
| `admin_menu/client/barber.lua` | Tête rattachée au citizenid, oubliée à la déconnexion, jamais réappliquée à un autre personnage. |
| `elyzea_multichar/server.lua`, `client.lua` | Aperçu : tatouages du personnage affiché (export `GetTattoosByCid`), ped nettoyé entre deux aperçus. |
| `ely_creator/client/main.lua` | L'apparence en mémoire (`loadedSkin`) est toujours celle du personnage chargé, et vidée à la déconnexion. Avant, sans apparence enregistrée, celle du personnage précédent pouvait être réenregistrée par `SaveOutfit`. |
| `elyzea_inventory/client/use.lua` | À la déconnexion du personnage, l'arme sortie est retirée du ped (avant, B apparaissait avec l'arme de A en main). |
| `elyzea_aura/server/main.lua` | Téléphone libéré à la déconnexion du personnage (numéro, appel en cours). |
| `gofast/server/main.lua`, `jewelry_heist/server/heist.lua`, `bank_heist/server/hack.lua`, `bank_heist/server/loot.lua` | Mission ou braquage en cours annulé au changement de personnage, comme une déconnexion : la récompense ne peut pas aller au personnage suivant. |
| `elyzea_clothing/server/items.lua` | Noms des pièces portées : plus de repli sur la licence. |

## Vérifié et correct (aucune modification)

Ces systèmes chargent et sauvegardent par **citizenid** :

- **elyzea_core :** argent liquide et banque, métier, grade, gang, position, faim, soif, vie, armure (`players.metadata`). Sauvegarde **avant** `playerUnloaded`.
- **elyzea_inventory :** `players.inventory`. L'identifiant est figé au chargement, donc la sauvegarde ne peut pas aller au mauvais personnage.
- **ely_creator :** apparence (`ely_characters.identifier` = citizenid).
- **elyzea_garage :** `player_vehicles.citizenid`.
- **elyzea_dynasty :** biens (`owner_cid`).
- **elyzea_permis**, **elyzea_papiers**, **elyzea_famille**, **elyzea_jobphone**, **elyzea_clothing** (tenues).
- **elyzea_ems :** blessures (`citizenid`, données vidées au changement de personnage).
- **elyzea_aura** (téléphone) : citizenid via l'adaptateur Elyzea.

La licence reste utilisée volontairement pour des données du **compte** : staff, bans, avertissements, roue du casino, délais anti-abus de gofast, boutique Elyzea Coins.

## Base de données

- **Aucune modification SQL.** Les tatouages et les têtes du barbier restent dans `admin_menu/data/*.json` (architecture existante), rangés par citizenid.
- **Aucune donnée supprimée.** D'anciennes entrées rangées par `license:…` restent dans le fichier mais ne sont plus lues.
- **Limite :** un personnage B qui a déjà acheté un tatouage pendant le bug peut avoir les tatouages de A **enregistrés dans sa liste**. Impossible de les distinguer automatiquement : il suffit de les retirer une fois au salon (le retrait fonctionne et ne touche que B). Ou, avec le serveur arrêté, de corriger à la main l'entrée du citizenid concerné dans `admin_menu/data/tattoo_looks.json`, après en avoir fait une copie.

## Tests

| Test | Comment | Résultat |
|---|---|---|
| 1. Tatouages de A (application, sauvegarde, reconnexion) | Simulation hors jeu, vrais fichiers | OK |
| 2. Isolation A / B | Simulation hors jeu | OK |
| 3. Retrait volontaire | Simulation hors jeu | OK |
| 4. Redémarrage admin_menu / serveur | Simulation hors jeu (disque conservé, ressources relancées) | OK |
| 8. Allers-retours A ↔ B (×5) | Simulation hors jeu | OK |
| Coupe / barbe A / B | Simulation hors jeu (`tests/barber_sim.lua` [13]) | OK |
| 5. Inventaires indépendants | Analyse du code (citizenid, identifiant figé) | non exécuté en jeu |
| 6. Argent indépendant | Analyse du code (`players.money` par citizenid) | non exécuté en jeu |
| 7. Apparence | Analyse du code + correction `loadedSkin` | non exécuté en jeu |
| 9. Métiers, véhicules, biens, licences, téléphone | Analyse du code | non exécuté en jeu |
| Base SQL | Pas d'accès à ta base | non vérifié |

- Avec les **anciens** fichiers, la simulation des tatouages échoue bien sur « retour à la sélection : plus aucun tatouage sur le ped ». La correction répond donc au bug observé.
- Lancement : `python3 tests/run_tattoo_multichar_sim.py` et `python3 tests/run_barber_sim.py` (depuis `admin_menu/`, `pip install lupa`).

## Procédure de test en jeu (deux personnages du même sexe)

1. **Test 1.** Connecte-toi avec A et achète 2 tatouages. Ils apparaissent tout de suite. Fais `/logout`, reprends A : ils sont là.
2. **Test 2.** `/logout`, prends B : aucun tatouage. Achète-en un autre à B. Reviens sur A (uniquement les siens), puis sur B (uniquement le sien).
3. **Test 3.** Sur A, retire un tatouage : il disparaît, l'autre reste. `/logout`, reprends A : il ne revient pas. B est inchangé.
4. **Test 4.** `restart admin_menu`, puis redémarre le serveur. Vérifie A et B.
5. **Test 5.** Donne un objet à A (`/giveitem` ou équivalent staff) : il n'est pas chez B. Puis l'inverse.
6. **Test 6.** Change le liquide et la banque de A : B ne bouge pas.
7. **Test 7.** Change la coupe de A au barbier : B garde la sienne. Puis l'inverse.
8. **Test 8.** Sors une arme avec A, fais `/logout` et prends B : B n'a rien en main.
9. **Test 9.** Vérifie véhicules (garage), biens (Dynasty 8), permis, numéro de téléphone et métier de chaque personnage.

## Installation et retour arrière

- **Redémarrage :** à faire dans cet ordre, ou un redémarrage complet du serveur :
  1. `restart admin_menu`
  2. `restart ely_creator`
  3. `restart elyzea_multichar`
  4. `restart elyzea_inventory`
  5. `restart elyzea_aura`
  6. `restart gofast`
  7. `restart jewelry_heist`
  8. `restart bank_heist`
  9. `restart elyzea_clothing`
- **SQL :** aucune commande à exécuter.
- **Retour arrière :** garde une copie de tes fichiers actuels avant d'installer. Pour revenir en arrière, remets cette copie, ou les fichiers du commit `84517f2` (état juste avant cet audit). Aucune donnée n'a été convertie, donc rien d'autre à défaire.
- **Ne remplace jamais** ton dossier `admin_menu/data/` : il contient les tatouages et les têtes enregistrés.
