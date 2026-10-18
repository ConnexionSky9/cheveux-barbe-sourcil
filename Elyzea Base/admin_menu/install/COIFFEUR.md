# Coiffeur / barbier / maquillage

## 1. Installation
Le salon fait partie de `admin_menu` : rien à ajouter dans server.cfg.
Remplace les fichiers du menu, **garde ton dossier `data/`**, puis `restart admin_menu`.

## 2. Poser un salon
1. F10 › Éditeur › PNJ › rôle tout prêt **💈 Coiffeur / barbier** ou **✂️ Salon de luxe**.
2. Place le PNJ, puis « Modifier son rôle » :
   - nom du salon, services proposés (coupes, couleur, barbe, sourcils, yeux, maquillage, peau, corps) ;
   - prix de chaque prestation (0 = gratuit) ;
   - liquide ou banque au choix, lentilles fantaisie, icône sur la carte ;
   - comme les autres PNJ : horaires, métiers autorisés, monnaie.
3. Les joueurs appuient sur **E** devant lui.

Un salon déjà posé garde ses réglages. Les nouvelles prestations (maquillage, peau…) y prennent
les prix de `Config.Barber.defaultPrices` tant que tu ne les changes pas dans l'éditeur.

## 3. Ce que contient le salon
| Onglet | Contenu |
|---|---|
| ✂️ Coupes | toutes les coupes du jeu + tes coupes addon, avec recherche |
| 🎨 Couleurs | couleur des cheveux et reflets (64 teintes) |
| 🧔 Barbe | taille, couleur, reflets, densité (masqué pour les femmes par défaut) |
| 〰️ Sourcils | forme, couleur, densité |
| 👁️ Yeux | 9 couleurs naturelles + 23 lentilles fantaisie |
| 💄 Maquillage | maquillage des yeux, couleur, 2e couleur |
| 🌸 Blush | style et couleur |
| 👄 Lèvres | rouge à lèvres et couleur |
| 🧴 Peau | imperfections, rides, teint, dommages solaires, grains de beauté |
| 💪 Corps | pilosité du torse et sa couleur, imperfections du corps |

---

## 4. Tout le contenu est dans UN fichier : `barber_data.lua`
Il est à la racine de `admin_menu`. Après chaque modification : `restart admin_menu`.

### 4.1 Donner un nom à une coupe (ou la renommer)
Le salon **compte tout seul** les coupes du jeu. `barber_data.lua` sert seulement à leur donner un nom.

1. En jeu, ouvre le salon et repère le **numéro** affiché sur la carte de la coupe (ex : `76`).
2. Dans `barber_data.lua`, partie `BarberData.hair`, va dans `male` ou `female` et ajoute une ligne :
   ```lua
   male = {
       ...
       [38] = 'Coupe militaire',
       [76] = 'Dégradé américain',      -- ← ta ligne
   },
   ```
3. `restart admin_menu`. La carte affiche « Dégradé américain » au lieu de « Coupe n°76 ».

Règles :
- le texte est entre apostrophes `'...'` ; pour une apostrophe dedans, écris `\'` (ex : `'L\'iroquoise'`) ;
- chaque ligne finit par une **virgule** ;
- un même numéro n'apparaît qu'une fois par sexe.

### 4.2 Cacher une coupe
```lua
[23] = false,
```
La coupe disparaît du salon (coupes buguées, réservées au staff…).

### 4.3 Ajouter une VRAIE nouvelle coupe (fichiers .ydd / .ytd)
Les coupes se mettent **dans `admin_menu/stream/`** : pas de ressource à part.
Tout ce qui est dans ce dossier est envoyé aux joueurs à la connexion.

**Coupes déjà installées**
| Sexe | N° | Coupe | Fichiers dans `stream/` |
|---|---|---|---|
| Femme | 23 | Royal Amber (remplace « Mulet ») | `mp_f_freemode_01_mp_f_bikerdlc_01^hair_000_u.ydd` + `…^hair_diff_000_a_uni.ytd` |
| Femme | 24 | Natt (remplace la coiffure de vision nocturne) | `mp_f_freemode_01_female_heist^hair_000_u.ydd` + `…^hair_diff_000_a_uni.ytd` |

**Le nom de fichier n'est PAS le numéro du salon**
FiveM ne laisse plus remplacer les coupes du pack de base (`mp_f_freemode_01^hair_…`) :
un fichier nommé ainsi est **ignoré** et le salon montre l'ancienne coupe.
On remplace donc les coupes ajoutées par les mises à jour du jeu (DLC). Chacune vit dans
un dossier du jeu, et le fichier doit porter **le nom de ce dossier + `^` + le nom de la coupe dans ce dossier** :

```
mp_f_freemode_01_mp_f_bikerdlc_01^hair_000_u.ydd
└────────── dossier du DLC ─────────┘ └ coupe ┘
```

Numéros déjà connus :
| Sexe | N° du salon | Coupe d'origine | Nom à donner aux fichiers | Libre ? |
|---|---|---|---|---|
| Femme | 23 | Mulet | `mp_f_freemode_01_mp_f_bikerdlc_01^hair_000_u` | pris (Royal Amber) |
| Femme | 24 | Vision nocturne (cachée) | `mp_f_freemode_01_female_heist^hair_000_u` | pris (Natt) |
| Homme | 23 | Vision nocturne (cachée) | `mp_m_freemode_01_male_heist^hair_000_u` | **libre** |

**Trouver le nom d'une autre coupe** : ouvre le jeu avec *CodeWalker* (RPF Explorer) ou *OpenIV* et cherche
`hair_` dans `update\x64\dlcpacks\…\dlc.rpf\x64\models\cdimages\…_female.rpf` (ou `_male.rpf`).
Le dossier qui contient la coupe donne la première partie du nom. Repère le bon numéro en comparant
avec le salon.

**Ajouter une coupe livrée en « remplacement »** (fichiers `hair_XXX_u.ydd` + `hair_diff_XXX_a_uni.ytd`)
1. Choisis la coupe à remplacer dans le tableau ci-dessus (ou trouve son nom, voir juste au-dessus).
2. Renomme les fichiers avec ce nom (exemple : homme, n°23) :
   ```
   hair_047_u.ydd            →  mp_m_freemode_01_male_heist^hair_000_u.ydd
   hair_diff_047_a_uni.ytd   →  mp_m_freemode_01_male_heist^hair_diff_000_a_uni.ytd
   ```
   - le `^` fait partie du nom ;
   - s'il y a d'autres textures (`_b_`, `_c_`…), renomme-les pareil : `…^hair_diff_000_b_uni.ytd`.
3. Copie-les dans `admin_menu/stream/`.
4. Nomme la coupe dans `barber_data.lua` (voir 4.1) à la ligne du numéro du salon : `[23] = 'Ma coupe',`
5. **Redémarre le serveur**, quitte complètement FiveM puis reconnecte-toi.

⚠️ La coupe d'origine est remplacée pour tout le monde.

**Redémarrer après un ajout de coupe**
Comme les coupes sont dans le menu, un `restart admin_menu` renvoie aussi les fichiers 3D.
Après un ajout, préfère redémarrer **tout le serveur** : les joueurs déjà connectés ne voient la
nouvelle coupe qu'après s'être reconnectés.

### 4.3 bis Packs de coupes « addon » (fichiers `.ymt` + `.meta`)
Un pack addon **ajoute** des coupes après celles du jeu (rien n'est remplacé). Le salon les trouve tout seul :
il demande au jeu les coupes qui existent vraiment pour le personnage, avec leur pack (« collection »).

**Ce que doit contenir la ressource du pack** (exemple : collection `mp_f_freemode_01_mp_f_vm_female_hair`)
```
ma_ressource_cheveux/
├── fxmanifest.lua
├── mp_f_freemode_01_mp_f_vm_female_hair.meta                 ← à la RACINE (pas dans stream/)
└── stream/                                                   ← sous-dossiers autorisés
    ├── mp_f_freemode_01_mp_f_vm_female_hair.ymt
    ├── mp_f_freemode_01_mp_f_vm_female_hair^hair_000_u.ydd
    ├── mp_f_freemode_01_mp_f_vm_female_hair^hair_diff_000_a_uni.ytd
    ├── mp_f_freemode_01_mp_f_vm_female_hair^hair_001_u.ydd
    └── …
```
```lua
-- fxmanifest.lua du pack
fx_version 'cerulean'
game 'gta5'
files { 'mp_f_freemode_01_mp_f_vm_female_hair.meta' }
data_file 'SHOP_PED_APPAREL_META_FILE' 'mp_f_freemode_01_mp_f_vm_female_hair.meta'
```
Dans le `.meta` : `<pedName>mp_f_freemode_01</pedName>`, `<dlcName>mp_f_vm_female_hair</dlcName>`,
`<fullDlcName>mp_f_freemode_01_mp_f_vm_female_hair</fullDlcName>`.

**Les 4 règles qui évitent une tête chauve**
1. Le `.ymt` s'appelle exactement `<fullDlcName>.ymt`.
2. Chaque `.ydd` / `.ytd` commence par `<fullDlcName>^` (pas `mp_f_freemode_01^`, pas un autre nom de pack).
3. Les n° des fichiers suivent l'ordre du `.ymt` : `hair_000`, `hair_001`… sans trou.
4. Le suffixe correspond au `.ymt` : `_u` (universel) ou `_r` (selon la couleur de peau) ; textures `_uni` ou `_whi`…

Si le `.ymt` déclare 26 coupes mais que les fichiers ne portent pas ces noms, le jeu **compte** bien
26 coupes de plus (le salon les affiche, par ex. n°126 à 151) mais ne trouve **aucun modèle** :
le personnage est chauve. Le salon garde maintenant la coupe actuelle et marque la carte « ⚠ ».

**Installation** : mets la ressource dans `resources/[vetements]/` (déjà lancé par `ensure [vetements]`)
ou ajoute `ensure ma_ressource_cheveux` dans la partie VÊTEMENTS de `server.cfg`, avant `elyzea_clothing`.
Redémarre le serveur puis reconnecte-toi (un pack relancé à chaud n'est vu qu'après reconnexion).

**Noms des coupes addon** : une carte sans nom affiche « Coupe n°130 · vm_female_hair ».
Le numéro d'une coupe addon **change** si tu ajoutes ou retires un pack avant le sien : un nom donné
dans `barber_data.lua` (`[130] = '…'`) peut alors tomber sur une autre coupe. Les têtes ACHETÉES,
elles, sont enregistrées avec leur pack et leur n° dans le pack : elles restent justes.

### 4.3 ter Diagnostic (`Config.Barber.debug = true`)
Dans `config.lua` › `Config.Barber`, mets `debug = true`, puis `restart admin_menu`.
À l'ouverture du salon, la console **F8** (et la console du serveur) affiche :
- le modèle du personnage, le nombre de coupes déclarées et utilisables, les n° sans texture ;
- chaque collection (jeu de base, DLC, packs) avec ses n° (ex : `mp_f_vm_female_hair n° 126 à 151`) ;
- pour chaque pack addon : la ressource qui le déclare, son `.meta`, la présence du `.ymt`,
  les n° de coupes **sans `.ydd` au bon nom** et les fichiers rangés sous un **autre préfixe** ;
- à chaque coupe essayée : n°, texture, collection, n° dans la collection, ou la raison du refus
  (n'existe pas, modèle non chargé + nom de fichier attendu).

Remets `debug = false` en production.

**Test en jeu conseillé**
1. Personnage femme, salon ouvert : survole une coupe du jeu (ex : n°10), puis une coupe du pack (n°126 et suivantes).
2. Coupe à plusieurs textures : clique dessus, puis « Variante 2 » sous la liste.
3. « ✕ » / Échap : la tête d'origine revient. Paye une coupe : elle reste, et revient après reconnexion.
4. Coupe marquée ⚠ : regarde F8 (debug) pour le nom de fichier attendu, corrige le pack.
5. Même chose avec un personnage homme. Arrête le pack (`stop ma_ressource_cheveux`) puis reconnecte-toi :
   le salon s'ouvre sans ses coupes et la tête enregistrée garde la coupe actuelle.

**Tests hors jeu** (logique du salon, natives imitées) : `pip install lupa` puis, depuis `admin_menu/`,
`python3 tests/run_barber_sim.py`.

### 4.4 Barbes, sourcils, maquillages, blush, rouges à lèvres, peau
Même principe, dans `BarberData.overlays`. Chaque calque a sa liste `styles` :
```lua
lipstick = {
    index = 8, label = 'Rouge à lèvres', palette = 'makeup', none = 'Sans rouge à lèvres', esx = 'lipstick',
    styles = { [0] = 'Mat', 'Brillant', 'Contour mat', ... },
},
```
- `[0] = 'Mat'` est le style n°1 du salon, le nom suivant le n°2, etc. ;
- pour nommer un style précis plus loin : ajoute `[16] = 'Peinture tribale',` dans la liste
  (le n°17 du salon, car le salon compte à partir de 1) ;
- `[16] = false,` le cache ;
- `none` : nom du choix « rien » (ex : « Sans rouge à lèvres ») ;
- `label` : utilisé pour les styles sans nom (« Rouge à lèvres n°11 »).

Le maquillage des yeux contient aussi les peintures de visage du jeu (environ 75 styles).
Les 16 premiers ont un nom, tu peux nommer les autres de la même façon.

### 4.5 Couleurs des yeux
Dans `BarberData.eyes`, chaque ligne est `{ 'Nom', '#couleur de l'aperçu' }`.
`BarberData.naturalEyes = 9` : nombre de couleurs naturelles. Les suivantes sont des lentilles
fantaisie, réservées aux salons où la case « Lentilles fantaisie » est cochée.

### 4.6 Onglets : renommer, retirer, réordonner
Tout est dans `BarberData.tabs` :
- **renommer** : `label` (onglet), `label` d'un mode (sous-onglet), `cart` (texte du panier) ;
- **retirer** : supprime le bloc `{ id = ..., }` de l'onglet ;
- **réordonner** : déplace le bloc ;
- **réserver à un sexe** : `female = false` ou `male = false`, sur l'onglet ou sur un mode ;
- `cam` choisit la caméra : `head`, `face`, `eyes`, `lips` ou `bust`.

Le prix d'un mode se règle dans l'éditeur avec la même clé (`lipstick`, `lipstick_color`…),
et sa valeur par défaut dans `Config.Barber.defaultPrices` (config.lua).

> Ne renomme pas les `key` (ex : `lipstick`) une fois les salons utilisés : leurs prix et les
> têtes enregistrées en mode interne sont rangés sous ces noms.

---

## 5. Enregistrement de la nouvelle tête (`Config.Barber.saveMode`)
| Mode | Utilisé quand |
|---|---|
| `illenium` | illenium-appearance démarré (Qbox / QBCore) : tout est enregistré, maquillage compris |
| `esx` | esx_skin + skinchanger démarrés |
| `internal` | aucun des deux : le menu garde la tête dans `data/barber_looks.json` et la remet à chaque spawn |

## 6. Pour les développeurs
- Événement serveur `adminmenu:barber:paid` (src, total, idPnj, panier) : verser l'argent à une société, logs…
- Événement client `adminmenu:barber:saved` (tête, mode).
- Exports : `exports.admin_menu:IsBarberOpen()` (client), `exports.admin_menu:GetBarberLook(src)` (serveur).
