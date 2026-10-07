# Elyzea FA — passer à la base Elyzea et supprimer Qbox / ox

Ce dépôt contient le serveur Elyzea **entièrement migré** sur sa propre base :

| Ancienne ressource | Remplacée par |
|---|---|
| `qbx_core` | `elyzea_core` (personnages, argent, métiers, gangs, faim / soif, salaires) |
| `oxmysql` | `elyzea_core` (accès MySQL : `@elyzea_core/lib/MySQL.lua`) |
| `ox_lib` | `elyzea_core` (notifications, barre de progression, aide à l'écran, rappels : `@elyzea_core/lib/ely.lua`) |
| `qbx_vehiclekeys` | `elyzea_core` (clés, touche **U**) |
| `ox_inventory` | `elyzea_inventory` |
| `Renewed-Banking` (comptes d'entreprise) | `elyzea_core` (comptes de société, soldes repris automatiquement) |

Plus aucune ressource du dossier `Elyzea Base` n'a besoin de qbx ou d'ox.

---

## 1. Avant de commencer : sauvegarde

1. **Arrête le serveur.**
2. **Sauvegarde ta base de données** (phpMyAdmin › Exporter, ou `mysqldump`). Ne saute pas cette étape.
3. **Copie ton dossier `resources`** ailleurs (par exemple `resources_ancien`).

---

## 2. Installer les nouveaux fichiers

1. Remplace le contenu de `Elyzea Base` dans ton dossier `resources` par celui de ce dépôt.
2. Remplace `server.cfg` et `permissions.cfg` par ceux du dossier `Serveur cfg`.
3. **Crée le fichier `secrets.cfg`** à côté de `server.cfg` (modèle : `Serveur cfg/secrets.cfg.example`) :

   ```cfg
   sv_licenseKey "cfxk_TA_CLE_DE_LICENCE"
   set mysql_connection_string "mysql://utilisateur:motdepasse@127.0.0.1/nom_de_la_base?charset=utf8mb4"
   ```

   Mets **la même base qu'avant** : tes personnages, métiers et véhicules sont conservés.
   Ce fichier n'est jamais envoyé sur GitHub (il est dans `.gitignore`).

---

## 3. Supprimer Qbox et ox

### 3.1 Dossiers à supprimer dans `resources`

Supprime (ou déplace dans `resources_ancien`) **tous** ces dossiers s'ils existent :

**Qbox**
- `[qbx]` (le dossier entier), ou séparément : `qbx_core`, `qbx_vehiclekeys`, `qbx_garages`, `qbx_management`,
  `qbx_vehicleshop`, `qbx_police`, `qbx_ambulancejob`, `qbx_hud`, `qbx_spawn`, `qbx_multicharacter`,
  `qbx_smallresources`, `qbx_radialmenu`, `qbx_idcard`, `qbx_houses`, `qbx_apartments`… (tout ce qui commence par `qbx_`)
- `qb-core` (le pont de compatibilité de Qbox), et toute ressource `qb-…` qui venait avec Qbox

**ox**
- `[ox]` (le dossier entier), ou séparément : `ox_lib`, `oxmysql`, `ox_inventory`, `ox_target`, `ox_fuel`, `ox_doorlock`

**Autres**
- `Renewed-Banking`

⚠️ **À garder** :
- `[assets]/pillbox` : c'est la **carte** de l'hôpital, pas une base. Garde-le si ta map EMS en dépend.
- `screenshot-basic` : seulement si tu utilises `elyzea_clothing_photos` (studio photo des vêtements, non lancé par le `server.cfg`).
- `pma-voice` / `[voice]` : la voix n'a rien à voir avec Qbox.

### 3.2 Fichiers de configuration

1. Supprime **`ox.cfg`** et la ligne `exec ox.cfg` si elle est encore dans un de tes `.cfg`.
2. Dans **tous** tes `.cfg` (`server.cfg`, `permissions.cfg`, `misc.cfg`…), supprime les lignes qui contiennent :
   - `ensure qbx_…`, `ensure [qbx]`, `ensure qb-…`
   - `ensure ox_…`, `ensure oxmysql`, `ensure [ox]`, `ensure Renewed-Banking`
   - `setr ox:…`, `set inventory:…`, `setr qbx:…`, `set qbx:…`
   - `add_ace resource.qbx_core …`, `add_ace resource.ox_lib …`
3. Vérifie que ces lignes sont **en haut** des `ensure`, dans cet ordre :

   ```cfg
   ensure elyzea_core
   ensure elyzea_inventory
   ```

   Et dans `permissions.cfg` : `add_ace resource.elyzea_core command allow`.

### 3.3 Vérifier qu'il ne reste rien

Dans ton dossier `resources`, cherche ces mots dans tous les fichiers (VS Code : Ctrl+Maj+F) :

```
qbx_core   qb-core   ox_lib   oxmysql   ox_inventory   @ox_lib   @oxmysql   Renewed-Banking
```

- Un `fxmanifest.lua` qui contient `@ox_lib/init.lua` ou `@oxmysql/lib/MySQL.lua` ne démarrera pas.
  Remplace par `@elyzea_core/lib/ely.lua` et `@elyzea_core/lib/MySQL.lua`.
- Une ligne `dependencies { 'qbx_core', 'ox_lib', 'oxmysql' }` empêche le démarrage : remplace par `dependencies { 'elyzea_core' }`.
- Les ressources de ce dépôt (`elyzea_aura`, `gofast`) gardent des mentions de `qb-core` / `ESX` : ce sont des **modes de secours facultatifs**, ils ne se lancent pas quand `elyzea_core` est là. Tu n'as rien à faire.

### 3.4 Ressources externes à vérifier

Ces ressources ne sont pas dans ce dépôt et peuvent encore demander qbx ou ox :
**`p_bridge`, `rcore_spray`, `rpemotes`**.
Si l'une affiche une erreur au démarrage (`Could not find dependency ox_lib`, `qbx_core`…), mets sa ligne en commentaire (`#ensure …`) ou cherche sa version « standalone ».

---

## 4. La base de données

### Tables conservées (ne touche à rien)
`players`, `player_groups`, `player_vehicles` : les mêmes qu'avec Qbox. `elyzea_core` les lit directement.
La colonne `players.inventory` est relue par `elyzea_inventory` : les inventaires des joueurs sont repris à la connexion.

### Tables créées automatiquement
`elyzea_society`, `elyzea_society_logs`, `elyzea_bank_logs`, `elyzea_stashes` (+ celles des métiers : `police_*`, `concess_*`, `elyzea_permis`…).

### Anciennes tables : NE PAS les supprimer tout de suite
- **`ox_inventory`** : le contenu de chaque ancien coffre (police, EMS, gangs…) est repris **à sa première ouverture**.
  Attends que tous les coffres aient été ouverts au moins une fois (quelques semaines), puis tu pourras supprimer la table.
- **`bank_accounts_new`** (Renewed-Banking) : le solde de chaque entreprise est repris la première fois que son compte est utilisé.
  Même conseil : garde-la quelques semaines.

Ensuite (après une nouvelle sauvegarde !), tu peux supprimer les tables des anciennes ressources Qbox/ox que tu n'utilises plus
(`ox_inventory`, `bank_accounts_new`, `bank_statements`, `player_transactions`, `management_outfits`…).

### Vérifier les objets inconnus
Dans la console du serveur : `elyzea_inventory_check`.
Elle liste les objets présents dans les inventaires mais absents du catalogue (à ajouter dans `elyzea_inventory/data/items.lua`).

---

## 5. Premier démarrage : checklist

Démarre le serveur et regarde la console :

- [ ] `[elyzea_core] Connexion à la base de données établie.`
- [ ] `[elyzea_core] Base Elyzea démarrée.`
- [ ] `[elyzea_inventory] Catalogue : … objets …`
- [ ] Aucune ligne rouge `Could not find dependency` ni `Couldn't find resource`

En jeu :

- [ ] Choisir un personnage existant : argent, métier, position et inventaire sont bons
- [ ] Créer un nouveau personnage
- [ ] Touche **U** sur son propre véhicule (verrouiller / déverrouiller)
- [ ] Manger / boire : la faim et la soif remontent dans le HUD
- [ ] Police : prise de service, armurerie, fouille, amende
- [ ] Ouvrir un coffre existant : son ancien contenu est là
- [ ] Concession : achat d'un véhicule, clé reçue, garage
- [ ] Téléphone (F1) et tablette illégale (F5)

En cas d'erreur, note la ligne rouge exacte de la console : elle donne la ressource et le fichier.

---

## 6. Ajouter un objet (item)

Les objets sont dans **`elyzea_inventory`** :

| Fichier | Rôle |
|---|---|
| `shared/items.lua` | Objets Elyzea (prioritaires). **C'est ici qu'on ajoute un objet.** |
| `data/items.lua` | Catalogue repris de l'ancien ox_inventory (même format qu'ox). |
| `data/weapons.lua` | Armes, munitions, accessoires d'armes. |
| `html/img/` | Images des objets (`<nom>.png` ou `.webp`, idéalement 100×100 à 256×256, fond transparent). |

### Étape par étape

1. Ouvre `elyzea_inventory/shared/items.lua` et ajoute une ligne **dans `Items = { … }`** :

   ```lua
   -- Objet simple
   lockpick = { label = 'Crochet', weight = 50, stack = true, max = 10, description = 'Pour ouvrir les serrures.' },

   -- Nourriture / boisson : food('Nom', poids en grammes, faim rendue, soif rendue)
   sandwich = food('Sandwich', 200, 20, 0, { notification = 'Vous avez mangé un sandwich.' }),
   ```

   - `weight` : poids en **grammes** par unité.
   - `stack` : `true` si les objets s'empilent ; `max` : taille maximum d'une pile.
   - `image` : facultatif. Par défaut, l'image est `html/img/<nom>.png`.

2. Ajoute l'image : `elyzea_inventory/html/img/lockpick.png` (le **même nom** que l'objet).
   Sans image, l'objet s'affiche avec une icône emoji (champ `icon = '🔧'`).
   Pour réutiliser une image existante, ajoute une ligne dans `ImageAlias`, en bas de `shared/items.lua` :
   `lockpick = 'repairkit.png',`

3. **Objet utilisable** (clic droit › Utiliser), depuis le serveur de n'importe quelle ressource :

   ```lua
   exports.elyzea_inventory:RegisterUsableItem('lockpick', function(source, item)
       -- ton code…
       return true   -- true = consomme 1 objet ; false ou rien = ne consomme pas
   end)
   ```

4. Redémarre : `restart elyzea_inventory` dans la console (ou redémarre le serveur).
5. Teste : `/giveitem [id] lockpick 5` (droit `command.giveitem`, déjà donné au groupe admin).

### État actuel des images
- 367 objets au catalogue, 409 images.
- 55 objets n'ont pas encore d'image et s'affichent avec un emoji : 37 skins d'armes (`at_skin_…`),
  `WEAPON_BATTLERIFLE`, `WEAPON_SNOWLAUNCHER`, `WEAPON_TACTICALRIFLE`, `WEAPON_TEARGAS`, et quelques objets
  (`diamond`, `small_tv`, `toaster`, `jammer`, `gatecrack`, `magic_mushroom`, `gun_parts_…`…).
  Pour leur en donner une, dépose simplement `<nom>.png` dans `html/img/`.
- Pour vérifier les objets des joueurs absents du catalogue : `elyzea_inventory_check` dans la console.

---

## 7. Ajouter une coiffure

Il y a deux cas.

### A. Donner un nom à une coupe du jeu (ou la cacher)

Le salon de coiffure (PNJ « Coiffeur » de l'éditeur de map) lit tout seul les coupes du jeu.
Pour les nommer, ouvre **`admin_menu/barber_data.lua`**, partie `BarberData.hair`, rubrique `male` ou `female` :

```lua
[41] = 'Ma nouvelle coupe',   -- donne un nom à la coupe n°41
[23] = false,                 -- cache la coupe n°23 dans le salon
```

Le numéro est affiché sur chaque carte du salon. Puis `restart admin_menu`.

### B. Ajouter une vraie nouvelle coupe (fichiers `.ydd` / `.ytd`)

Une coupe téléchargée contient en général `hair_XXX_u.ydd` et `hair_diff_XXX_a_uni.ytd`.
Elle **remplace** un numéro de coupe existant (pour tout le monde).

1. Choisis le **sexe** et le **numéro à remplacer** N (3 chiffres : `024`, `047`…).
   - Homme : `mp_m_freemode_01`
   - Femme : `mp_f_freemode_01`
   Prends de préférence une coupe buguée ou inutile (ex. femme n°24, l'ancienne coupe « vision nocturne »).
2. Renomme les fichiers (même N partout) :

   ```
   hair_XXX_u.ydd           →  mp_f_freemode_01^hair_N_u.ydd
   hair_diff_XXX_a_uni.ytd  →  mp_f_freemode_01^hair_diff_N_a_uni.ytd
   ```

   S'il y a d'autres textures (`_b_`, `_c_`…), renomme-les de la même façon.
3. Place-les dans **`elyzea_coupes/stream/`** (la ressource est déjà lancée par le `server.cfg` : `ensure elyzea_coupes`).
4. Donne-lui un nom dans `admin_menu/barber_data.lua` : `[24] = 'Ma coupe',`
5. Redémarre le serveur, puis reconnecte-toi (les fichiers du dossier `stream` sont envoyés à la connexion).

Les coupes déjà installées sont dans `elyzea_coupes/stream` (femme n°24) et `admin_menu/stream`.
Plus de détails : `elyzea_coupes/LISEZMOI.txt` et `admin_menu/install/COIFFEUR.md`.

---

## 8. Pour les développeurs

**Serveur**
```lua
local p = exports.elyzea_core:GetPlayer(source)       -- p.PlayerData, p.Functions (AddMoney, SetJob…)
exports.elyzea_core:AddSocietyMoney('police', 500, 'Amende')
exports.elyzea_core:GiveKeys(source, vehicle)
exports.elyzea_inventory:AddItem(source, 'water', 2)
```

**Client**
```lua
local data = exports.elyzea_core:GetPlayerData()
Ely.notify({ description = 'Bonjour', type = 'success' })   -- avec shared_script '@elyzea_core/lib/ely.lua'
```

**Événements** : `elyzea:client:playerLoaded`, `elyzea:client:playerUnloaded`, `elyzea:client:onJobUpdate`,
`elyzea:client:onMoneyChange` (client) ; `elyzea:server:playerLoaded`, `elyzea:server:playerUnloaded` (serveur).
