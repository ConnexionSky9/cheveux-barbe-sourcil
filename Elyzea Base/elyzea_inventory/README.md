# Migration ox_inventory → elyzea_inventory

Ce guide permet de retirer complètement ox_inventory du serveur. Après la migration :

- **elyzea_inventory** est l'inventaire principal (objets, emplacements, poids, sauvegarde, objets au sol, objets utilisables) ;
- **elyzea_clothing** est le système de vêtements (boutique, port, retrait, renommage) ;
- **ox_inventory** peut être arrêté puis supprimé.

Lisez la section 0 avant toute chose : certaines ressources ne peuvent pas fonctionner sans ox_inventory.

---

## 0. Avant de commencer : ce qui peut bloquer la suppression

| Situation sur votre serveur | Conséquence | Que faire |
|---|---|---|
| **Qbox (`qbx_core`)** | qbx_core exige ox_inventory pour fonctionner. | La suppression complète est impossible sans changer de framework. Ne supprimez pas ox_inventory. |
| **Armes gérées par ox_inventory** (les armes sont des objets ox) | Plus aucun système d'armes une fois ox supprimé. | Installez un système d'armes séparé avant de supprimer ox, ou gardez ox. |
| **Argent en objet** (`money`, `black_money` dans ox) | L'argent liquide en objet disparaît de l'inventaire. | Laissez l'argent au framework (ESX : comptes, QBCore : `PlayerData.money`). |
| **Shops, coffres, stashs, fouille, coffres de véhicules d'ox** | Ces fonctions d'ox disparaissent. elyzea_inventory gère l'inventaire du joueur et les objets au sol, pas les coffres partagés. | Gardez-les désactivés ou remplacez-les par vos scripts. |
| **Scripts qui appellent `xPlayer.addInventoryItem` (ESX) ou `Player.Functions.AddItem` (QBCore)** | Ces fonctions écrivent dans l'inventaire du framework, pas dans elyzea_inventory : le joueur ne verrait pas l'objet. | Remplacez-les par `exports.elyzea_inventory:AddItem` (section 6). |

Si aucune de ces situations ne vous concerne, ou si vous les avez traitées, continuez.

---

## 1. Sauvegarder

1. Arrêtez le serveur.
2. Exportez la base de données complète (HeidiSQL, phpMyAdmin ou `mysqldump`).
3. Copiez le dossier `resources/` entier (en particulier `ox_inventory/data/items.lua` et `ox_inventory/web/images/`).
4. Copiez `server.cfg`.

---

## 2. Installer les deux ressources

1. Placez `elyzea_inventory/` et `elyzea_clothing/` dans `resources/` (remplacez l'ancien `elyzea_clothing`).
2. Supprimez, s'il existe encore, l'ancien fichier `elyzea_clothing/install/ox_inventory_items.lua` : il n'est plus utilisé.
3. Les 15 images des vêtements sont déjà dans `elyzea_inventory/html/img/`.

Les 15 vêtements sont déclarés dans `elyzea_inventory/shared/items.lua`, chacun à **10 grammes** :

```
vet_haut, vet_tshirt, vet_pantalon, vet_chaussures, vet_sac, vet_gilet, vet_gants,
vet_collier, vet_masque, vet_logo, vet_chapeau, vet_lunettes, vet_boucles,
vet_montre, vet_bracelet
```

Ce poids est défini une seule fois (`CLOTHING_WEIGHT = 10`). Le serveur le lit à chaque calcul de poids, pour chaque ajout et chaque vérification de place. La valeur `weight` de `elyzea_clothing/config.lua` est seulement indicative.

---

## 3. Déclarer vos autres objets

elyzea_inventory ne connaît que les objets déclarés dans `shared/items.lua`. Un objet inconnu est refusé à l'ajout et ignoré au chargement (un avertissement s'affiche dans la console).

**Option A, import automatique depuis ox :**

1. Ouvrez `ox_inventory/data/items.lua`.
2. Copiez tout le contenu entre `return {` et la dernière `}`.
3. Collez-le dans `elyzea_inventory/shared/ox_items_import.lua`, à l'intérieur de `OxItems = { ... }`.
4. Copiez `ox_inventory/web/images/*.png` dans `elyzea_inventory/html/img/`.

Les poids ox sont déjà en grammes et sont repris tels quels. Les objets déjà définis dans `shared/items.lua`, dont les vêtements à 10 g, ne sont jamais écrasés.

Attention : les blocs `client = { ... }`, `server = { export = ... }` et `buttons` d'ox ne sont pas repris. Les objets qui « faisaient quelque chose » doivent être réenregistrés (étape suivante).

**Option B, à la main :** ajoutez vos objets dans `Items` (poids en grammes).

**Objets utilisables :** pour chaque objet qui avait un effet dans ox, ajoutez côté serveur :

```lua
exports.elyzea_inventory:RegisterUsableItem('sandwich', function(source, item)
    -- item = { name, slot, count, metadata, label }
    TriggerClientEvent('mon_script:manger', source)
    return true   -- true = consomme 1 unité ; false ou rien = ne consomme pas
end)
```

Les objets de `elyzea_inventory/server/usables.lua` (burger, eau, bandage) sont des exemples.

---

## 4. Migrer les inventaires existants des joueurs

Les inventaires ox sont stockés en base, dans la colonne `inventory` de la table `players` (QBCore) ou `users` (ESX). La commande de migration les lit directement : ox_inventory n'a pas besoin d'être démarré. Elle a besoin d'oxmysql.

1. Démarrez le serveur avec `elyzea_inventory`, **sans joueur connecté**.
2. Dans la console serveur, lancez un aperçu (rien n'est écrit) :
   ```
   elyzea_migrate_ox
   ```
3. Lisez la liste des « objets inconnus ignorés ». Déclarez-les (section 3), redémarrez `elyzea_inventory`, puis relancez l'aperçu.
4. Quand la liste vous convient, écrivez les inventaires :
   ```
   elyzea_migrate_ox confirm
   ```

La migration écrase l'inventaire elyzea des personnages concernés. Lancez-la une seule fois, avant l'ouverture aux joueurs.

Les coffres, stashs et coffres de véhicules d'ox ne sont pas migrés : elyzea_inventory n'a pas d'équivalent.

---

## 5. Trouver tous les scripts qui dépendent encore d'ox_inventory

Depuis le dossier du serveur.

**Linux :**

```bash
grep -rn --include=*.lua --include=*.js --include=*.html --include=*.cfg "ox_inventory" resources/ server.cfg
```

**Windows (PowerShell) :**

```powershell
Get-ChildItem -Recurse resources -Include *.lua,*.js,*.html | Select-String "ox_inventory"
Select-String "ox_inventory" server.cfg
```

Chaque ligne trouvée appartient à l'un des cas suivants :

| Motif trouvé | Où | Quoi faire |
|---|---|---|
| `dependency 'ox_inventory'` | fxmanifest.lua | Supprimer la ligne (section 7). |
| `'ox_inventory'` dans `dependencies { ... }` | fxmanifest.lua | Retirer l'entrée de la liste. |
| `'@ox_inventory/...'` dans `shared_script(s)` / `client_script(s)` / `server_script(s)` | fxmanifest.lua | Supprimer la ligne ; remplacer ce qu'elle apportait. |
| `exports.ox_inventory:Fonction(...)` ou `exports['ox_inventory']:Fonction(...)` | .lua | Remplacer par `exports.elyzea_inventory:Fonction(...)` si la fonction existe (section 6), sinon réécrire. |
| `GetResourceState('ox_inventory')` | .lua | Remplacer par `'elyzea_inventory'`, ou retirer la condition. |
| Événements `ox_inventory:...` (`ox_inventory:updateInventory`, `ox_inventory:setPlayerInventory`, `ox_inventory:openInventory`…) | .lua | Remplacer par `elyzea_inv:sync` (client) ou retirer. |
| `ensure ox_inventory`, `setr inventory:...`, `set inventory:...` | server.cfg | Supprimer (section 8). |

Recommencez la recherche jusqu'à ce qu'elle ne renvoie plus rien (en dehors des commentaires et de `elyzea_inventory/shared/ox_items_import.lua`, qui ne contient le mot qu'en commentaire).

---

## 6. Correspondance des fonctions ox_inventory → elyzea_inventory

Toutes ces fonctions vérifient réellement le poids, la place et les metadata. Aucune ne renvoie `true` sans contrôle. Les poids sont en **grammes**, comme dans ox.

### Serveur

| ox_inventory | elyzea_inventory | Notes |
|---|---|---|
| `AddItem(src, name, count, metadata, slot)` | **identique** | Renvoie `true, slot` ou `false, raison` (`too_heavy`, `no_space`, `unknown_item`…). |
| `RemoveItem(src, name, count, metadata, slot)` | **identique** | Avec `slot`, vérifie que l'objet et les metadata correspondent. |
| `CanCarryItem(src, name, count, metadata)` | **identique** | Poids **et** place libre. |
| — | `CanCarryItems(src, { {name, count, metadata}, ... })` | Plusieurs objets d'un coup (utilisé pour l'achat de vêtements). |
| `CanCarryWeight(src, grammes)` | **identique** | |
| `GetSlot(src, slot)` | **identique** | `{ name, label, count, slot, metadata, weight }` |
| `SetMetadata(src, slot, metadata)` | **identique** | |
| `GetItem(src, name, metadata, returnsCount)` | **identique** | |
| `GetItemCount(src, name, metadata)` | **identique** | |
| `Search(src, 'count' / 'slots', name, metadata)` | **identique** | |
| `GetInventoryItems(src)` | **identique** | |
| `GetInventory(src)` | **identique** | `{ id, owner, slots, weight, maxWeight, items }` |
| `GetEmptySlot(src)` | **identique** | |
| `Items(name)` | **identique** | Définition de l'objet. |
| `RegisterUsableItem(name, cb)` (ESX/QB) | `RegisterUsableItem(name, cb)` | Export **et** fonction globale dans elyzea_inventory. |
| — | `UseSlot(src, slot)`, `GetWeight(src)`, `SetBagEquipped(src, bool)`, `IsBagEquipped(src)`, `Refresh(src)` | |
| `SetMaxWeight`, `RegisterStash`, `forceOpenInventory`, `CustomDrop`, `ClearInventory`, `ConfiscateInventory`, `registerHook`, armes | **non fournies** | Pas d'équivalent : réécrire ou retirer la fonctionnalité. |

### Client

| ox_inventory | elyzea_inventory |
|---|---|
| `GetPlayerItems()` | **identique** (avec `metadata`) |
| `Search('count' / 'slots', name)` | **identique** |
| `closeInventory()` | **identique** |
| `useSlot(slot)` | Événement serveur `elyzea_inv:action` (`'use'`), ou les touches 1 à 5 |
| `openInventory(...)` | Pas d'équivalent (la touche TAB ouvre l'inventaire du joueur) |

---

## 7. Lignes de fxmanifest à vérifier

Dans **chaque** ressource trouvée à la section 5, ouvrez `fxmanifest.lua` (ou `__resource.lua`) et retirez :

```lua
dependency 'ox_inventory'
dependencies { 'ox_inventory' }                  -- ou l'entrée 'ox_inventory' dans une liste plus longue
shared_script '@ox_inventory/...'
client_script '@ox_inventory/...'
server_script '@ox_inventory/...'
```

Si le script utilise maintenant elyzea_inventory, ajoutez à la place :

```lua
dependency 'elyzea_inventory'
```

État des deux ressources livrées :

- `elyzea_inventory/fxmanifest.lua` : aucune dépendance.
- `elyzea_clothing/fxmanifest.lua` : `dependency 'elyzea_inventory'` (ox_inventory n'y figure plus).

---

## 8. server.cfg

**À supprimer :**

```cfg
ensure ox_inventory
start ox_inventory
setr inventory:keys ...
setr inventory:weight ...
setr inventory:slots ...
set inventory:framework ...
set inventory:...              # toute autre convar inventory:* d'ox
```

**Ordre de démarrage conseillé :**

```cfg
ensure oxmysql                 # seulement si d'autres scripts l'utilisent (et pour la migration)
ensure ox_lib                  # seulement si d'autres scripts l'utilisent (elyzea n'en a pas besoin)
ensure es_extended             # ou qb-core : votre framework
ensure illenium-appearance     # ou fivem-appearance
ensure elyzea_inventory
ensure admin_menu
ensure elyzea_clothing
# … vos autres scripts
```

`elyzea_inventory` doit démarrer **avant** `elyzea_clothing` et avant tout script qui appelle ses exports.

---

## 9. Ordre d'arrêt et de suppression

À faire **serveur démarré, sans joueur**, dans la console (txAdmin ou console serveur) :

1. `stop elyzea_clothing`
2. `stop` chaque script trouvé à la section 5 qui n'a pas encore été corrigé
3. `stop ox_inventory`
4. `ensure elyzea_inventory`
5. `ensure elyzea_clothing`
6. Faites les tests de la section 10.
7. Si tout fonctionne : arrêtez le serveur, appliquez les modifications de `server.cfg` (section 8), puis **déplacez** le dossier `resources/[ox]/ox_inventory` hors de `resources/` (gardez-le quelques jours comme archive).
8. Redémarrez complètement le serveur et relisez la console.
9. Après quelques jours sans problème, supprimez définitivement l'archive. La table SQL `ox_inventory` (stashs, coffres) peut être exportée puis supprimée ; les colonnes `inventory` des tables `players` / `users` peuvent rester (elles ne sont plus lues).

---

## 10. Tester après la suppression

Faites ces tests avec un joueur, dans l'ordre. Donnez des objets avec `/egive [id] [objet] [quantité]` (permission : `add_ace group.admin command.egive allow`). N'utilisez pas `/giveitem` : sur Qbox, cette commande appartient à qbx_core et donne l'objet à ox_inventory.

**Inventaire :**

1. Appuyez sur **TAB** : l'inventaire ELYZEA FA s'ouvre, avec votre personnage au centre.
2. Le poids affiché commence à `0.00 / 18 KG` pour un personnage vide.
3. `/egive [id] burger 5` : le poids passe à 2.50 KG.
4. Glissez un objet d'un emplacement à un autre, puis dans « Au sol », puis ramassez-le : le poids suit.
5. Mettez un objet dans l'emplacement 1, fermez l'inventaire et appuyez sur **1** : l'objet est utilisé.
6. Remplissez l'inventaire jusqu'à 18 KG, puis essayez d'ajouter 500 g : refus « Poids maximum atteint ».
7. Déconnectez-vous puis reconnectez-vous : l'inventaire est identique.

**Vêtements :**

8. Achetez un haut dans une boutique (sans « Porter tout de suite ») : un objet « Haut n°X » arrive dans l'inventaire et le poids augmente d'exactement **10 g**.
9. Glissez-le sur le personnage : il est porté, l'ancien haut revient dans l'inventaire (10 g), le poids reste le même.
10. Glissez le haut porté depuis le personnage vers la grille : il est rangé, le personnage repasse sur « rien ».
11. Clic droit sur un vêtement > Renommer : le nouveau nom s'affiche, et il est conservé quand vous le portez puis le rangez.
12. Achetez un sac et portez-le : la capacité passe à **28 KG**, le badge « SAC ÉQUIPÉ » apparaît.
13. Chargez plus de 18 KG, puis essayez de retirer le sac : refus avec le poids que vous atteindriez.
14. Repassez sous 17.99 KG : le sac se retire, la capacité revient à 18 KG.
15. Remplissez l'inventaire au maximum puis achetez un vêtement : refus **avant** le paiement.
16. Essayez un vêtement femme sur un personnage homme : refus.
17. **F3** (Ma tenue) : la liste correspond à ce que vous portez ; « Ranger » met la pièce dans l'inventaire.

**Console :** aucune ligne rouge mentionnant `ox_inventory`, `elyzea_inventory` ou `elyzea_clothing`.

---

## 11. Erreurs à surveiller

| Message | Cause | Solution |
|---|---|---|
| `Could not find dependency ox_inventory for resource X` | Le fxmanifest de X déclare encore ox. | Retirer la ligne (section 7). |
| `No such export AddItem in resource ox_inventory` | Un script appelle encore `exports.ox_inventory`. | Remplacer par `exports.elyzea_inventory` (section 6). |
| `attempt to call a nil value (global 'RegisterUsableItem')` | Un fichier hors d'elyzea_inventory appelle la fonction globale. | Utiliser `exports.elyzea_inventory:RegisterUsableItem(...)`, et démarrer elyzea_inventory avant ce script. |
| `No such export ... in resource elyzea_inventory` | Fonction ox non fournie (`RegisterStash`, `CustomDrop`…). | Voir la dernière ligne du tableau de la section 6. |
| `objet inconnu ignoré au chargement : X` | Objet absent de `shared/items.lua`. | Le déclarer (section 3), puis redémarrer. |
| Achat de vêtement refusé « inventaire plein ou trop lourd » alors qu'il reste de la place | Toutes les cases sont occupées. | Libérer un emplacement : chaque vêtement en prend un (non empilable). |
| Le sac porté ne donne pas 28 KG | Sac porté via la tenue enregistrée avant la migration, sans passer par l'objet. | Le ranger (F3) puis le porter depuis l'inventaire. |
| Images d'objets manquantes (emoji à la place) | PNG absent de `elyzea_inventory/html/img/`. | Copier l'image (`nom_objet.png`). |
| TAB n'ouvre rien | Ancienne touche enregistrée côté joueur, ou ressource non démarrée. | Paramètres > Raccourcis > FiveM > « Ouvrir l'inventaire » ; vérifier `ensure elyzea_inventory`. |

---

## 12. Fichiers modifiés par cette migration

**elyzea_inventory (version 3.0.0, autonome)**

- `fxmanifest.lua` : plus aucune dépendance ; nouveaux fichiers chargés.
- `config.lua` : poids en grammes (18 000 g), sac `vet_sac`, 15 emplacements = rayons d'elyzea_clothing, raccourcis 1 à 5.
- `shared/items.lua` : 15 vêtements `vet_*` à 10 g, `vet_sac` avec bonus de 10 000 g, boutons Porter / Renommer.
- `shared/ox_items_import.lua` (nouveau) : import optionnel des objets d'ox.
- `shared/utils.lua` : poids entiers en grammes, comparaison de metadata façon ox.
- `server/main.lua` : réécrit, stockage autonome par personnage, API compatible ox, gestion du sac côté serveur, `RegisterUsableItem` en export et en globale.
- `server/usables.lua` (rétabli) : exemples d'objets utilisables.
- `server/migrate.lua` (nouveau) : commande `elyzea_migrate_ox`.
- `client/main.lua` : réécrit, exports client, raccourcis 1 à 5, vêtements délégués à elyzea_clothing.
- `client/drops.lua` (rétabli) : objets au sol.
- `client/clothing.lua` : supprimé (remplacé par elyzea_clothing).
- `html/` : panneau « Au sol », menu clic droit, poids en grammes pour les petits objets, 15 images de vêtements.

**elyzea_clothing (version 2.0.0)**

- `server.lua` : tous les appels ox remplacés ; vérification du poids et de la place avant paiement (`CanCarryItems`) ; gestion du sac (`SetBagEquipped`) à l'achat, au port et au retrait ; enregistrement des objets utilisables.
- `client.lua` : appels ox remplacés ; nouvel export `GetWorn` pour l'affichage autour du personnage.
- `config.lua` : poids indicatif à 10 g, commentaires mis à jour.
- `fxmanifest.lua` : `dependency 'elyzea_inventory'`.
- `html/index.html` : texte de « Ma tenue » mis à jour.
- `LISEZ-MOI.txt` : section objets réécrite.
- `install/` : supprimé (objets et images désormais dans elyzea_inventory).

---

## 13. Ajouter des objets et leurs icônes facilement

### Tant qu'ox_inventory est encore dans `resources/`

Rien à faire : au démarrage, elyzea_inventory lit `ox_inventory/data/items.lua` et `ox_inventory/data/weapons.lua`, et reprend tous les objets, munitions (`ammo-9`, `ammo-rifle2`…), armes et accessoires, avec leurs poids. La console affiche par exemple :

```
[elyzea_inventory] Import ox_inventory : 120 objets, 18 munitions, 90 armes, 60 accessoires.
```

Les icônes sont prises dans `ox_inventory/web/images/` : ce sont les mêmes que dans ox. ox_inventory peut être **arrêté** (`stop ox_inventory`, ligne retirée du server.cfg) : le dossier doit seulement rester présent.

Attention : les armes apparaissent comme objets, mais elyzea_inventory ne les équipe pas en main (voir section 0).

### Avant de supprimer le dossier ox_inventory (à faire une seule fois)

1. Copiez toutes les images de `ox_inventory/web/images/` dans `elyzea_inventory/html/img/`.
2. Copiez le contenu de `ox_inventory/data/items.lua` dans `elyzea_inventory/shared/ox_items_import.lua` (section 3, option A).
3. Pour les munitions et accessoires, déclarez-les dans `shared/items.lua` (exemple ci-dessous), ou gardez une copie de `data/weapons.lua` dans un dossier `ox_inventory/data/` vide.
4. Supprimez le dossier ox_inventory, puis redémarrez.

### Ajouter un nouvel objet

1. Dans `elyzea_inventory/shared/items.lua`, ajoutez une ligne dans `Items` :
   ```lua
   ['ammo-9'] = { label = '9mm', weight = 7, stack = true, max = 1000 },
   kit_reparation = { label = 'Kit de réparation', weight = 1500, stack = true, max = 5, description = 'Répare un véhicule.' },
   ```
   - `weight` en **grammes** ;
   - `stack = true` pour empiler ;
   - `image = 'fichier.png'` seulement si le fichier ne porte pas le nom de l'objet.
2. Déposez l'icône dans `elyzea_inventory/html/img/` sous le **nom exact de l'objet** : `ammo-9.png`, `kit_reparation.png`. Format PNG ou WEBP, fond transparent, 100 à 256 px.
3. `restart elyzea_inventory`, puis `/egive [votre id] kit_reparation 1`.

Ordre de recherche d'une icône : `elyzea_inventory/html/img/<nom>.png`, puis `ox_inventory/web/images/<nom>.png`, puis l'emoji de l'objet.

Où trouver des icônes dans ce style : le dossier `web/images` d'ox_inventory (celles de votre capture), ou les packs d'icônes d'objets FiveM gratuits. Gardez le même style pour tout l'inventaire.

### Rendre un objet utilisable

Voir section 3 : `exports.elyzea_inventory:RegisterUsableItem('kit_reparation', function(source, item) ... end)`.

---

## 14. Serveur Qbox / ox_inventory conservé : mode ox (automatique)

Quand ox_inventory est démarré, elyzea_inventory passe tout seul en **mode ox**. La console affiche alors :

```
[elyzea_inventory] Mode ox_inventory : l'interface ELYZEA affiche l'inventaire ox (armes comprises).
```

Dans ce mode, **il n'y a qu'un seul inventaire : celui d'ox**. L'interface ELYZEA (touche TAB) l'affiche et le modifie.

- **Tout ce qui est donné apparaît** : armes, munitions, objets de Qbox, de `/giveitem`, des shops et des métiers.
- **Utiliser un objet** passe par ox_inventory : clic droit > Utiliser, double-clic, ou touches 1 à 5. Les armes s'équipent en main et la nourriture fait son effet, comme avant.
- **Le poids est celui d'ox**. La capacité passe à 18 KG, ou 28 KG avec un sac porté (appliquée par `SetMaxWeight`).
- **`/egive` n'est pas actif** dans ce mode : utilisez `/giveitem` de Qbox.

**À installer une fois** pour les vêtements :

1. Collez `elyzea_inventory/install/ox_items_vetements.lua` dans `ox_inventory/data/items.lua`. Ce sont les 15 vêtements, à 10 g chacun.
2. Copiez `elyzea_inventory/html/img/vet_*.png` dans `ox_inventory/web/images/`.
3. Dans `server.cfg`, avant `ensure ox_inventory`, libérez TAB : `setr inventory:keys ["F2","K","F11"]`.
4. L'ordre de démarrage doit être : `ox_inventory`, puis `elyzea_inventory`, puis `elyzea_clothing`.

Pour forcer un mode : `Config.Backend = 'ox'` ou `'standalone'` dans `elyzea_inventory/config.lua`.
