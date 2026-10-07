# Elyzea : création de personnage et documents

Ce pack contient deux ressources qui fonctionnent ensemble :

| Ressource | Rôle |
|---|---|
| `ely_creator` | Création du personnage : identité, hérédité, visage, pilosité, maquillage, tenue. |
| `ely_documents` | Carte d'identité, permis de conduire et permis de port d'arme (PPA), avec photo du personnage. |

Les deux ressources sont prévues pour **Qbox**. `ely_documents` lit les informations créées par `ely_creator` (nom, date de naissance, nationalité...). Il faut donc installer les deux.

---

## 1. Prérequis

- Un serveur FiveM à jour (artifacts récents, OneSync activé).
- **qbx_core** (Qbox) et **oxmysql**.
- **ox_inventory** pour les objets (carte, permis, PPA) et les objets de départ.
- **illenium-appearance** conseillé : vos magasins de vêtements, barbiers et chirurgiens continuent de fonctionner, l'apparence créée y est enregistrée automatiquement.

Les deux ressources fonctionnent aussi en ESX ou sans framework (voir la section 8).

---

## 2. Installation (Qbox)

### Étape 1 : copier les dossiers

Décompressez les deux archives et placez les dossiers dans `resources/` :

```
resources/
├── [elyzea]/
│   ├── ely_creator/
│   └── ely_documents/
```

Le nom des dossiers doit rester exactement `ely_creator` et `ely_documents`.

### Étape 2 : désactiver le multipersonnage de Qbox

`ely_creator` remplace le multipersonnage intégré de Qbox (création, sélection, connexion).
Ouvrez `qbx_core/config/client.lua` et passez ce réglage à `true` :

```lua
useExternalCharacters = true,
```

Sans ça, la fenêtre de création de Qbox et le créateur Elyzea s'ouvriront en même temps.

### Étape 3 : server.cfg

Les deux ressources doivent démarrer **après** qbx_core, ox_inventory et illenium-appearance :

```cfg
ensure oxmysql
ensure ox_lib
ensure qbx_core
ensure ox_inventory
ensure illenium-appearance

ensure ely_creator
ensure ely_documents
```

### Étape 4 : base de données

Rien à importer. Au premier démarrage, les tables sont créées automatiquement :

- `ely_characters` : identité et apparence de chaque personnage (liée au `citizenid`).
- `ely_licenses` : dates de délivrance des permis.

Les personnages Qbox restent dans la table `players` habituelle, et l'apparence est aussi écrite dans `playerskins` pour illenium-appearance.

### Étape 5 : permissions staff

```cfg
add_ace group.admin command.creator allow
add_ace group.admin command.givelicense allow
add_ace group.admin command.removelicense allow
```

### Étape 6 : créer les objets dans ox_inventory

Ajoutez dans `ox_inventory/data/items.lua` :

```lua
['carte_identite'] = { label = "Carte d'identité", weight = 10, stack = false, close = true },
['permis_conduire'] = { label = 'Permis de conduire', weight = 10, stack = false, close = true },
['ppa'] = { label = "Permis de port d'arme", weight = 10, stack = false, close = true },
```

La carte d'identité est donnée automatiquement à la création du personnage (voir `Config.Qbox.starterItems`).
Si vous ne voulez pas d'objets, mettez `Config.UseItems = false` dans `ely_documents/config.lua` : les commandes `/carte`, `/permis` et `/ppa` suffisent.

### Étape 7 : redémarrer et tester

Redémarrez entièrement le serveur, puis connectez-vous avec un compte sans personnage : le créateur doit s'ouvrir directement après l'écran de chargement.

---

## 3. Configuration

### ely_creator/config.lua

| Option | Utilité |
|---|---|
| `Config.Framework` | `'qbox'` (par défaut), `'esx'` ou `'standalone'`. |
| `Config.Qbox.maxCharacters` | `1` = connexion directe sur son personnage. Plus de 1 = écran de sélection des personnages. |
| `Config.Qbox.illenium` | Enregistre l'apparence dans illenium-appearance (`playerskins`). |
| `Config.Qbox.starterItems` | Objets donnés à la création du personnage. |
| `Config.ServerName` | Nom affiché dans l'interface et sur la carte d'identité. |
| `Config.CreatorCoords` | Salle de création (par défaut la pièce du créateur GTA Online). |
| `Config.SpawnCoords` | Où le joueur apparaît après la création (ensuite, il réapparaît là où il s'est déconnecté). |
| `Config.Identity` | Longueur des noms, âge min/max, taille min/max, noms interdits. |
| `Config.Nationalities` | Liste des nationalités proposées. |
| `Config.DefaultOutfit` | Tenue de départ homme / femme (numéros de vêtements). |
| `Config.Camera` | Angles et distances de la caméra. |

### ely_documents/config.lua

| Option | Utilité |
|---|---|
| `Config.Framework` | Doit être identique à celle du créateur. |
| `Config.LicenseSource` | `'qbox'` : lit les licences du joueur Qbox (metadata `licences`). `'esx'` : table `user_licenses`. `'internal'` : uniquement `ely_licenses`. |
| `Config.StateName` | Texte en haut des cartes (« État de San Andreas »). |
| `Config.ShowDistance` | Distance maximale pour montrer un document (mètres). |
| `Config.ViewDuration` | Temps d'affichage chez la personne qui reçoit le document. |
| `Config.Commands` | Noms des commandes (`false` pour en désactiver une). |
| `Config.Items` | Noms des objets. |
| `Config.DriveCategories` | Catégories A / B / C et le type de licence associé. |
| `Config.CodeType` | Licence du code de la route, ou `false` pour ne pas l'afficher (par défaut en Qbox). |
| `Config.PPA` | Type de licence, catégorie d'arme et autorité affichées. |
| `Config.Validity` | Années de validité affichées sur chaque document. |

Types de licence par défaut en Qbox :

| Licence | Type |
|---|---|
| Permis A (moto) | `driver_bike` |
| Permis B (voiture) | `driver` |
| Permis C (poids lourd) | `driver_truck` |
| PPA | `weapon` |

`driver` et `weapon` sont les licences de base de Qbox : vos scripts d'auto-école et d'armurerie qui les donnent fonctionnent directement. `driver_bike` et `driver_truck` n'existent pas par défaut dans Qbox : donnez-les avec `/givelicense` ou depuis vos scripts.

---|---|
| Code de la route | `dmv` |
| Permis A (moto) | `drive_bike` |
| Permis B (voiture) | `drive` |
| Permis C (poids lourd) | `drive_truck` |
| PPA | `weapon` |

---

## 4. Utilisation en jeu

### Création de personnage

- S'ouvre automatiquement quand le joueur n'a pas encore de personnage.
- Avec `Config.Qbox.maxCharacters` supérieur à 1, un écran « Vos personnages » s'affiche à la connexion : clic sur un personnage pour le prévisualiser, **Jouer** (ou double-clic) pour se connecter, **Nouveau personnage** pour en créer un autre.
- La commande `/logout` de Qbox ramène à cet écran.
- 9 étapes : identité, hérédité, visage, yeux et sourcils, cheveux et pilosité, peau, maquillage, tenue, accessoires.
- Le personnage change en direct à chaque réglage.
- Caméra : boutons Visage / Buste / Jambes / Entier, glisser la souris sur la scène pour tourner, molette pour zoomer, touches Q et D pour pivoter.
- Double-clic sur un curseur pour le remettre au centre.
- L'apparence est réappliquée automatiquement à chaque connexion.

### Documents

1. Sortir un document : `/carte`, `/permis`, `/ppa` ou utiliser l'objet.
2. Clic droit sur la carte : **Montrer** ou **Ranger**.
3. Après **Montrer** : maintenir **Alt**, viser la personne (contour doré), **clic gauche**.
4. Échap, Retour ou clic droit pour annuler.

La personne qui reçoit le document le voit à droite de son écran. Elle le ferme avec Retour, sinon il disparaît tout seul.

### Commandes staff

| Commande | Effet |
|---|---|
| `/creator` | Rouvre le créateur pour soi. |
| `/creator 12` | Rouvre le créateur pour le joueur 12 (modifie son personnage actuel, n'en crée pas un nouveau). |
| `/givelicense 12 weapon` | Donne le PPA au joueur 12. |
| `/givelicense 12 driver` | Donne le permis B au joueur 12. |
| `/removelicense 12 weapon` | Retire le PPA au joueur 12. |

---

## 5. Pour les développeurs

### Exports ely_creator

```lua
-- Client
exports.ely_creator:ApplySkin(skin, ped)   -- applique une apparence
exports.ely_creator:GetSkin()              -- apparence du joueur
exports.ely_creator:IsOpen()               -- créateur ouvert ?

-- Serveur
exports.ely_creator:GetCharacter(source)   -- identité + apparence
exports.ely_creator:OpenCreator(source)    -- ouvre le créateur
```

Événements : `ely_creator:created` (client) et `ely_creator:characterCreated` (serveur).

### Exports ely_documents

```lua
-- Client
exports.ely_documents:ViewDocument('idcard')   -- 'idcard', 'license' ou 'ppa'
exports.ely_documents:StartShow('ppa')         -- lance directement la sélection Alt + clic
exports.ely_documents:Close()

-- Serveur
exports.ely_documents:AddLicense(source, 'weapon')
exports.ely_documents:RemoveLicense(source, 'weapon')
exports.ely_documents:HasLicense(source, 'drive')
exports.ely_documents:ShowDocument(source, 'idcard', targetId)
```

### Objets donnés à la création

Pas de code à écrire : modifiez `Config.Qbox.starterItems` dans `ely_creator/config.lua`. Les objets de départ de `qbx_core` ne sont plus utilisés, puisque c'est `ely_creator` qui crée le personnage.

---

## 6. Personnaliser

- **Logo** : remplacez `html/logo.jpg` dans les deux ressources (image carrée, 320 × 320 conseillé, garder le même nom).
- **Couleurs** : en haut de chaque `html/style.css`, dans `:root` (`--gold`, `--blue`, `--red`...).
- **Aperçu sans le jeu** : ouvrez `html/index.html` de chaque ressource dans Chrome pour voir l'interface avec des données de démonstration.

---

## 7. Dépannage

**Le créateur de Qbox s'ouvre en plus du créateur Elyzea.**
`useExternalCharacters` n'est pas à `true` dans `qbx_core/config/client.lua` (étape 2).

**Écran de chargement bloqué.**
Vérifiez que `ely_creator` démarre bien et qu'aucune erreur n'apparaît dans la console (F8 côté joueur, console serveur). Si besoin, ajoutez `setr loadscreen:externalShutdown false` dans `server.cfg`.

**Le menu de illenium-appearance s'ouvre après la création.**
Un script (souvent un script d'appartement de départ) déclenche encore l'événement `qb-clothes:client:CreateFirstCharacter`. Désactivez l'appartement de départ dans ce script.

**Le personnage revient avec d'anciens vêtements.**
Vérifiez que `Config.Qbox.illenium = true` : l'apparence est alors enregistrée à la fois dans `ely_characters` et dans `playerskins`.

**« Vous n'avez pas encore créé votre personnage » en sortant un document.**
Le personnage a été créé avant l'installation d'Elyzea : il n'a pas de ligne dans `ely_characters`. Faites-lui refaire son apparence avec `/creator [id]`.

**Le permis n'apparaît pas alors que le joueur l'a passé.**
Vérifiez que le type donné par votre auto-école correspond à `Config.DriveCategories` (par défaut `driver` pour le permis B).

**La photo n'apparaît pas sur la carte.**
La personne qui montre le document doit être visible et proche. Sinon une silhouette s'affiche à la place, le reste de la carte fonctionne.

**Les polices sont différentes de l'aperçu.**
Les polices se chargent depuis Google Fonts. Sans accès internet côté joueur, une police de secours est utilisée.

**La taille choisie ne change pas le personnage.**
C'est normal : GTA ne permet pas de modifier la taille réelle d'un ped. La taille est une information RP affichée sur la carte d'identité.

---

## 8. Utilisation avec ESX

Dans les deux `config.lua`, mettez `Config.Framework = 'esx'`, puis dans `ely_documents/config.lua` :
`Config.LicenseSource = 'esx'`, les types `drive_bike`, `drive`, `drive_truck` et `Config.CodeType = 'dmv'`.

Dans `server.cfg`, retirez `esx_identity` et `esx_skin`, et démarrez `es_extended` (et `esx_license`) avant les deux ressources. Les objets se créent dans la table `items` :

```sql
INSERT INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`) VALUES
('carte_identite', "Carte d'identité", 1, 0, 1),
('permis_conduire', 'Permis de conduire', 1, 0, 1),
('ppa', "Permis de port d'arme", 1, 0, 1);
```
