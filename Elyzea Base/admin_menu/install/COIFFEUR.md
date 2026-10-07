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

**Coupe « addon » (qui s'ajoute en fin de liste au lieu de remplacer)**
Ces packs contiennent en plus des fichiers `.ymt` et `.meta` : ils se créent avec un outil comme
*Durty Cloth Tool*. Le plus simple est de passer la coupe en « remplacement » comme ci-dessus.

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
