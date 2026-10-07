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
**`p_bridge`, `rcore_spray`, `rpemotes`, `mm_radio`, `tstudio_mrpd`**.
`p_bridge` et `rcore_spray` sont désactivés dans le server.cfg. `mm_radio` est remplacée par **`elyzea_radio`** (voir 3.5).
Si l'une affiche une erreur au démarrage (`Could not find dependency ox_lib`, `qbx_core`…), mets sa ligne en commentaire (`#ensure …`) ou cherche sa version « standalone ».

### 3.5 Problèmes vus dans les logs du serveur et leur solution
| Message dans la console | Solution |
|---|---|
| `No such config file: secrets.cfg` puis `does not have a license key` / `mysql_connection_string est vide` | Mets **`secrets.cfg` dans le même dossier que `server.cfg`** (ex. `D:\txData\Qbox_BE5BF8.base\secrets.cfg`). Sans lui : pas de clé de licence et **pas de base de données** (personnages, inventaires non sauvegardés). |
| `Argument count mismatch (passed 1, wanted 2)` | Une tabulation dans `voice.cfg` (`voice_enableSubmix`). Corrigé : remplace ton `voice.cfg`. |
| `The file myLogo.png must be a 96x96 PNG image` | Remplace `myLogo.png` à côté du server.cfg par celui de `Serveur cfg/` (96 × 96). |
| `Could not find dependency ox_lib for resource mm_radio` | **Supprime le dossier `mm_radio`** (dans `[voice]`) : `elyzea_radio` le remplace. |
| `p_bridge … attempt to index a nil value (global 'lib')` | `p_bridge` est désactivé dans le server.cfg ; tu peux supprimer son dossier. |
| `Couldn't find resource rcore_spray` | Ligne désactivée dans le server.cfg. |
| `tstudio_mrpd : Failed to load script @ox_lib/init.lua` / `could not find server_script scripts/*.lua` | Dans `tstudio_mrpd/fxmanifest.lua`, supprime la ligne `'@ox_lib/init.lua'` et la ligne `server_script 'scripts/*.lua'` (ou `server_scripts { 'scripts/*.lua' }`). La map marche sans. |
| `permis_item does not have a resource manifest` | Supprime le dossier `permis_item` : le permis est déjà dans `elyzea_inventory`. |
| `elyzea_aura exists in more than one place` | Supprime l'ancienne copie `resources\[telephone]\elyzea_aura`. |
| `Asset … uses XX MiB of physical memory` / `Oversized assets` | Avertissements sur des véhicules / maps trop lourds (textures). Rien de cassé ; si des textures ne chargent pas, réduis les `.ytd` (OpenIV / Texture Toolkit). |
| `could not find file handling.meta / carcols.meta / vehicle_names.lua` (gayaems, 21x90, umbuf4bb, elusnon, m3g80, onx-evp-b-audio) | Fichiers déclarés dans leur manifeste mais absents : sans gravité. Pour supprimer l'avertissement, retire la ligne correspondante dans leur `fxmanifest.lua` / `__resource.lua`. |

### 3.6 Radio (`elyzea_radio`)
Remplace `mm_radio`, sans ox_lib.
- **Utiliser** l'objet `radio` → talkie-walkie Elyzea : allumer, fréquence (1.00 à 999.99), rejoindre / quitter, volume.
- **★ Mes favoris** : saisis une fréquence, donne-lui un nom (facultatif), **★ Ajouter**. Clic pour la rejoindre, ✕ pour la retirer (10 maximum, `Config.MaxFavorites`).
- **🔒 Canaux du métier** : policiers (police, sheriff, gendarmerie) et EMS ont d'office les canaux réservés de leur métier dans la radio, sans pouvoir les supprimer.
  Noms et fréquences dans `Config.JobChannels` (`elyzea_radio/config.lua`) ; ils changent tout seuls si le joueur change de métier.
- Parler : **Verr. Maj** (touche radio de pma-voice, `voice.cfg` › `voice_defaultRadio`).
- **Fréquences réservées** (`elyzea_radio/config.lua`) : 1 à 10.99 police, 11 à 20.99 EMS, 21 à 25.99 services. Le serveur bloque aussi l'accès direct par pma-voice.
- **Batterie** : se vide radio allumée ; l'objet `radiocell` (piles AAA) la recharge.
- **Brouilleur** (`jammer`) : posé au sol, coupe les radios dans un rayon de 35 m pendant 10 min.
- Sans l'objet `radio` dans l'inventaire, la radio s'éteint toute seule.

### 3.7 Touches du serveur (aucune ne se chevauche)
Chaque joueur peut changer ses touches : Échap › Paramètres › Raccourcis › FiveM.

| Touche | Action | Qui |
|---|---|---|
| **E** | Interagir avec le point le plus proche (PNJ, zones, récolte, borne…) | Tous |
| **TAB** · **1 à 5** · **R** | Inventaire · raccourcis rapides · recharger l'arme | Tous |
| **U** | Verrouiller / déverrouiller le véhicule | Tous |
| **F1** | Téléphone | Tous |
| **F3** | Ma tenue (vêtements) | Tous |
| **F4** | Tablette CarPlay | Tous, en véhicule |
| **F5** | Menu du groupe illégal | Membres d'un groupe |
| **F6** | Tablette du métier (police, EMS, mécano, concessions, taxi, Burger Shot, boîte de nuit) | Une seule s'ouvre : celle de ton métier |
| **F7** | Menu d'interaction police | Police |
| **G** · **I** | Accepter · ignorer un appel ou une alerte | Police et EMS |
| **ALT** (maintenir en visant) | Menu de soins | EMS |
| **ALT** | Couper du bois | Bûcheron, dans une zone de coupe |
| **K** · **X** · **J** | Animations : menu · arrêter · déplacer | Tous |
| **Y** · **L** | Accepter · refuser une demande (animation à deux, facture EMS) | Tous |
| **N** | Parler (pma-voice) · **²** changer la portée de la voix | Tous |
| **Verr. Maj** | Parler à la radio | Avec une radio |
| **F2** · **F9** · **F10** | Noclip · menu rapide · menu admin | Staff |
| **Suppr** · **Début** · **Fin** · **Inser** · **M** | Noclip : supprimer le véhicule · éditeur : hauteur à zéro · coller au sol · côté de l'aimant · aimant | Staff, dans ces modes |

- **Changements :**
  - Police : accepter **Y → G**, ignorer **U → I** (Y servait aux animations, U au verrou).
  - EMS : ignorer **X → I** (X arrête une animation).
  - Animations : refuser **N → L** (N sert à parler).
  - Tenue : **F7 → F3** ; CarPlay : **F7 → F4** (F7 = menu police).
  - Radio : **ALT → Verr. Maj** (ALT sert aux soins EMS et au bûcheron).
  - Facture EMS : refuser **X → L**.
- Le menu des animations refuse maintenant qu'on mette une animation sur une touche déjà prise.
- Les nouvelles touches s'appliquent même aux joueurs déjà venus : les commandes ont été renommées pour que FiveM reprenne les nouveaux défauts.
  **Seules exceptions :**
  - la radio (pma-voice) : ceux qui avaient déjà joué gardent ALT ; à changer dans Raccourcis › FiveM › « Radio » ;
  - les touches du staff (noclip / éditeur) : à refaire dans le même menu.
- `rpemotes` (ressource externe) a ses propres touches dans son `config.lua` : vérifie qu'elles ne reprennent pas une touche du tableau.
  Elle fait doublon avec `elyzea_animations` : tu peux la retirer du server.cfg.

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

## 8. Papiers : permis, carte d'identité, PPA

Tous les papiers ont le même design Elyzea (carte holographique avec la photo du titulaire).
Clic droit › **Utiliser** pour regarder son papier, puis **Montrer à la personne la plus proche** (3 m).
Réglages : `elyzea_papiers/config.lua` (prix, paiement banque / liquide / au choix, règles) et `elyzea_papiers/questions.lua` (questions du test PPA).

### Permis de conduire (`elyzea_permis`)
Trois cases sur le permis : **Voiture (B)**, **Moto (A)**, **Poids lourd (C)**, cochées avec la date d'obtention.
Le permis est remis dès qu'une catégorie est réussie, puis mis à jour à chaque nouvelle catégorie.

### Carte d'identité et changement d'identité : PNJ « Gouvernement »
1. Menu admin › **Éditeur de map › PNJ** : crée ou choisis un PNJ, coche le rôle **🏛️ Gouvernement**, donne un nom au guichet, enregistre.
2. Les joueurs parlent au PNJ (E) et ouvrent le guichet :
   - **Carte d'identité** : prix réglable (`Config.Government.idCard`), première carte gratuite, une seule carte à la fois (réglable) ;
   - **Changement d'identité** : prénom, nom, date de naissance, nationalité (et sexe si activé), prix, délai entre deux changements,
     âge minimum / maximum, liste des nationalités ; une nouvelle carte est remise et les anciennes sont retirées (réglable).
3. L'argent va sur le compte d'entreprise `gouvernement` (réglable).
4. Staff : `/refairecarte [id]` donne une carte gratuite.

### Permis de port d'arme (PPA) : test et remise par les EMS
| PPA | Objet | Catégories sur la carte | Qui peut le passer |
|---|---|---|---|
| Civil | `ppa` | Pistolet | Tout le monde |
| Forces de l'ordre | `ppa_fdo` | Arme légère, arme lourde | Métiers `police`, `sheriff`, `gendarmerie` (réglable) |

1. L'EMS en service vise le joueur, **Alt** › **Test PPA civil** (ou **forces de l'ordre**).
2. Le joueur reçoit une **demande avec le prix** : il accepte, il paie tout de suite (banque ou liquide), le test démarre.
   L'argent va au compte des EMS.
3. Le test s'affiche sur son écran : **questions** et **mises en situation**, réponses mélangées, corrigées par le serveur
   (les bonnes réponses ne sont jamais envoyées aux joueurs). L'EMS reçoit le résultat.
4. Réussi : l'EMS fait **Alt › Donner le PPA** (dans les 30 minutes, réglable). **Échoué : impossible de donner le PPA**, il faut repasser le test.
5. Le PPA enregistre aussi le permis `weapon` dans le personnage (tablette de la police, armureries qui exigent un PPA).

---

## 9. Armes portées sur le personnage

Dans l'inventaire, **clic droit sur une arme** :
- **Mettre dans le dos / Retirer du dos** : fusils, mitraillettes, fusils à pompe, fusils de précision, armes lourdes ;
- **Mettre à la ceinture / Retirer de la ceinture** : pistolet, glissé à l'arrière du pantalon.

**Une seule arme dans le dos et une seule à la ceinture** (impossible de mettre deux fusils d'assaut dans le dos).
Elles sont visibles par tous les joueurs. L'arme sortie en main n'est pas affichée en double. Cachées en véhicule (réglable).
Réglages : `elyzea_inventory/config.lua` › `Config.BodyWeapons`.

**Ajuster la position** (si l'arme rentre dans le corps ou flotte) : en jeu, tape `/positionarme dos x y z rx ry rz`
ou `/positionarme ceinture x y z rx ry rz`. Le changement est visible tout de suite (pour toi seulement). Quand c'est bien placé,
recopie la ligne affichée dans la console F8 dans `Config.BodyWeapons`, puis `restart elyzea_inventory`.

---

## 10. Métiers : bûcheron, entreprises, concession aérienne

### Bûcheron (`elyzea_farm`) : métier secondaire
Il se cumule avec le métier principal : un policier peut aller couper du bois sans quitter son métier.
1. **Menu admin › Éditeur de map › PNJ** : crée un PNJ, coche le rôle **🪓 Métier de farm** et choisis **Bûcheron**.
2. **Menu admin › Métiers › Métiers de farm › Bûcheron** :
   - **zones de coupe** (centre et rayon, visibles sur la carte) : on ne peut couper que dedans ;
   - **points** d'arbres posés à la main si besoin (les arbres de la map sont aussi détectés) ;
   - **réglages** : temps de coupe, nombre de bûches par coupe (min / max), prix de revente, plafond par heure ;
   - **tenue** : mets la tenue sur toi, puis « Copier ma tenue actuelle » (homme et femme séparés).
3. En jeu : **E** sur le PNJ › « Voulez-vous travailler en tant que bûcheron ? » › Oui : la tenue est mise.
   Devant un arbre, dans une zone : **ALT** pour couper (barre de progression). L'arbre ne disparaît pas.
4. Retour au PNJ : **vendre les bûches** (`buche_bois`) et **arrêter de travailler** : tu récupères tes vêtements
   (gardés même après une déconnexion).

### Taxi, Burger Shot, Boîte de nuit (`elyzea_entreprises`)
Tablette des employés : **F6**.
| Entreprise | Ce que font les employés |
|---|---|
| Taxi | Compteur dans le véhicule, factures, **courses PNJ** (client à prendre puis à déposer, paiement vérifié par le serveur), véhicules de service |
| Burger Shot | Préparation des recettes (cuisine), achat de fournitures payé par l'entreprise, factures, coffre |
| Boîte de nuit | Bar (préparation des boissons), entrée payante, factures, coffre |

Toutes ont : prise de service avec tenue, coffre partagé, factures (banque ou liquide, commission de l'employé),
direction (recrutement, grades, renvoi, dépôt / retrait sur le compte de l'entreprise).

**Staff : Menu admin › Métiers › Taxi / Burger Shot / Boîte de nuit** (permission `entreprises_staff`) :
activer / désactiver, nom, grades et salaires, permissions par grade, zones, carte (prix), recettes, fournitures,
tarifs du taxi, points de course, réglages. Les positions par défaut sont approximatives : vérifie les zones.

### Borne de commande du Burger Shot
**Points à poser** (Menu admin › Métiers › Burger Shot › Zones, « Utiliser ma position actuelle ») :
- **Borne de commande (clients)** : autant que tu veux, devant chaque borne du restaurant ;
- **Plan de travail** : place-toi **derrière le comptoir, face au client**. Le plateau apparaît devant ce point.

**Côté client** : **E** sur la borne → interface Elyzea Burger Shot : **6 burgers, 6 boissons, 6 desserts**, panier, paiement banque ou liquide.
La commande part aux employés en service ; le client la suit en direct (burger assemblé couche par couche).
Elle est remboursée automatiquement si personne ne la prépare à temps, ou si elle est annulée (même s'il s'est déconnecté).

**Côté employé** : une alerte sonne à chaque commande. **F6 › Commandes** (ou **E** au plan de travail) → **Préparer** :
- l'employé prépare devant le client, avec une animation par produit ;
- chaque produit est posé sur le plateau, visible par tous ;
- les ingrédients sont pris dans son inventaire.

Client à moins de 6 m : la commande lui est remise. Sinon, il la récupère au comptoir avec **E**.
L'argent va à l'entreprise à la fin de la préparation, moins la part de l'employé.

**Staff : Menu admin › Métiers › Burger Shot › 🍔 Borne de commande** :
- **commandes en cours**, avec bouton d'annulation et remboursement ;
- **réglages** :
  - borne ouverte, employé obligatoire, ingrédients consommés, alerte ;
  - mode de paiement, articles maximum, commandes par client, délai de remboursement ;
  - part de l'employé, distance de remise directe ;
  - plateau : modèle, distance, hauteur ;
  - catégories et animations ;
- **produits** :
  - nom, objet donné, prix, temps, description, actif, catégorie ;
  - couches du burger (de bas en haut, avec aperçu) ou visuel et couleur de la boisson ;
  - modèle posé sur le plateau ;
  - ingrédients.

Objets ajoutés (avec images) :
- **Burgers** : `bs_burger_classic`, `bs_burger_double`, `bs_burger_bacon`, `bs_burger_chicken`, `bs_burger_veggie`, `bs_burger_monster`.
- **Boissons** : `bs_drink_cola`, `bs_drink_orange`, `bs_drink_lemon`, `bs_drink_icetea`, `bs_drink_shake`, `bs_drink_coffee`.
- **Desserts** : `bs_dessert_sundae`, `bs_dessert_donut`, `bs_dessert_cookie`, `bs_dessert_pie`, `bs_dessert_cheesecake`, `bs_dessert_muffin`.
- **Nouveaux ingrédients**, en vente chez le fournisseur : `bs_bacon`, `bs_poulet`, `bs_cafe`, `bs_patisserie`.

Sur un serveur déjà lancé, au premier démarrage, la mise à jour se fait seule :
- la permission « commandes » est donnée aux grades qui peuvent cuisiner ;
- les nouveaux ingrédients sont ajoutés au fournisseur ;
- 2 bornes et 1 plan de travail sont posés (positions approximatives, à vérifier).

### Concession aérienne (`elyzea_concess_air`)
Même fonctionnement que la concession automobile, avec son propre métier `planedealer` (« Elyzea Aviation ») à LSIA.
Staff : **Menu admin › Métiers › Concession aérienne**. Détails dans `elyzea_concess_air/README.md`.

### PNJ catalogue (consultation seule)
**Menu admin › Éditeur de map › PNJ** : rôle **📚 Catalogue**, puis choisis **Concession automobile** ou **Concession aérienne**.
Les joueurs regardent le catalogue, sans pouvoir acheter (l'achat passe par un vendeur).

---

## 11. Pour les développeurs

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
