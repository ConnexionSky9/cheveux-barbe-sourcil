# Formats, outils externes et limites

## Les états d'un fichier

L'application distingue toujours :

| État | Signification |
|---|---|
| **Lisible** | Le fichier est reconnu et son contenu (ou son en-tête) a pu être lu sans erreur. |
| **Affichable** | Il peut être montré dans l'application (texture à plat ou aperçu 3D). |
| **Modifiable** | L'application peut le modifier (calques, couleurs, transformations…). |
| **Convertible** | L'application sait le réécrire dans un autre format (par exemple PNG → DDS). |
| **Exportable** | Il peut être placé tel quel dans une ressource FiveM. |
| **Ressource générée** | L'export a produit le dossier et passé les contrôles automatiques. |
| **Testé en jeu** | Vérifié sur un serveur FiveM. **L'application ne le fait jamais** : c'est à vous de le faire. |

Le format réel est détecté par la **signature** du fichier, pas par son extension. Une extension trompeuse est signalée.

## Images et textures

| Format | Lisible | Modifiable | Écriture | Remarques |
|---|---|---|---|---|
| PNG | ✅ | ✅ | ✅ | Sans perte, transparence conservée |
| JPEG | ✅ | ✅ | ✅ | Avec perte, sans transparence (avertissement à l'export) |
| TGA | ✅ types 2, 3, 10, 11 (24 / 32 bits, gris 8 bits, RLE) | ✅ | ✅ 32 bits | TGA à palette (types 1 et 9) refusés avec un message |
| DDS | ✅ DXT1, DXT3, DXT5, RGB 24/32 bits, RGBA/BGRA 8 bits (en-tête DX10 compris), luminance 8 bits | ✅ (niveau 0) | ✅ DXT1, DXT5, BGRA8 + mipmaps | BC4, BC5, BC6H, BC7, cubemaps et volumes refusés avec un message |

Contrôles à l'import : dimensions, puissance de 2, taille excessive (avertissement au-delà de 2048, alerte au-delà de 4096 — réglable), présence d'alpha.

## Modèles 3D intermédiaires

| Format | Aperçu 3D | Remarques |
|---|---|---|
| OBJ (+ MTL) | ✅ | Le `.mtl` et ses textures sont lus dans le dossier d'origine du fichier |
| glTF 2.0 (.gltf) | ✅ | Les `.bin` et images externes sont lus dans le dossier d'origine |
| GLB | ✅ | Format conseillé (tout est dans un seul fichier) |
| FBX | ⚠️ partiel | FBX 7.x via Three.js ; textures externes non chargées |

**Un modèle 3D générique n'est pas un vêtement GTA V.** Il lui manque le squelette du personnage, les poids de skinning, les shaders et les conventions de nommage du jeu. Il sert dans l'application à l'aperçu, au patron UV et à la préparation ; il n'est jamais exporté dans la ressource.

## Fichiers GTA V / FiveM

| Fichier | Rôle | Ce que fait l'application |
|---|---|---|
| `.ydd` (drawable dictionary) | Modèle du vêtement | Contrôle (signature RSC7, version, décompression complète), renommage selon le slot, copie exacte dans `stream/` |
| `.ytd` (texture dictionary) | Textures d'une variante | Contrôle + **lecture des textures** (DXT1, DXT3, DXT5, A8R8G8B8, A8, L8) et **réécriture d'une texture** dans le même format, la même taille et le même nombre de mipmaps (DXT1, DXT5, A8R8G8B8, A8, L8). Expérimental. |
| `.ymt` (métadonnées du personnage) | Collection additionnelle | Contrôle (RSC7 ou PSO), copie dans `stream/` |
| `.meta` (ShopPedApparel, XML) | Collection additionnelle | Vérification de la structure, du personnage, déclaration `data_file 'SHOP_PED_APPAREL_META_FILE'` |

Versions de ressource habituelles relevées sur les fichiers du jeu : `.ytd` = 13, `.ydd` = 165, `.ymt` = 2. Une autre version donne un **avertissement**, pas une erreur.

### Ce qui n'est PAS pris en charge (et pourquoi)

- **Afficher ou modifier le contenu d'un `.ydd` / `.ytd`** : ces formats binaires demandent un décodeur complet des structures du moteur du jeu. L'application ne l'inclut pas pour ne pas produire de fichiers invalides. Utilisez CodeWalker ou Blender + Sollumz.
- **Créer un `.ytd` de toutes pièces** : non pris en charge. En partant d'un vêtement du jeu, son `.ytd` est réécrit (sa structure n'est jamais modifiée, seules les données de pixels sont remplacées). Sans `.ytd` de départ, le DDS est fourni pour CodeWalker.
- **Textures BC7 / BC4 / BC5** dans un `.ytd` : ni lues ni réécrites (message clair).
- **Aperçu 3D des `.ydd`** : non pris en charge (contenu non décodé).

### Lecture des `.ytd` : comment c'est fait

Structure lue (PC, version 13) : ressource RSC7 décompressée, segments système et graphique (tailles déduites des drapeaux de l'en-tête), dictionnaire de textures (liste de pointeurs à +0x30), textures de 0x90 octets (nom +0x28, largeur +0x50, hauteur +0x52, format +0x58, niveaux +0x5D, pixels +0x70). Chaque valeur est contrôlée (nom lisible, dimensions, niveaux, pointeurs dans le fichier) : au moindre écart, le fichier est refusé avec un message plutôt que de produire un fichier abîmé. La réécriture est relue avant d'être placée dans la ressource.
Cette lecture a été vérifiée sur des fichiers construits selon cette structure, **pas encore sur des fichiers du jeu** : testez un premier vêtement en jeu.
- **Créer un `.ydd`** à partir d'un modèle 3D : Blender + Sollumz (squelette, poids, matériaux).
- **Générer `.ymt` / `.meta`** d'une collection : outil spécialisé (par exemple un générateur de packs de vêtements). L'application les vérifie et les intègre.

## Conventions de nommage générées

Remplacement d'un vêtement du jeu (préfixe = modèle du personnage) :

```
mp_m_freemode_01^jbib_005_u.ydd
mp_m_freemode_01^jbib_diff_005_a_uni.ytd     (variante a)
mp_f_freemode_01_p^p_head_002.ydd             (accessoire : dossier « _p »)
mp_f_freemode_01_p^p_head_diff_002_a.ytd
```

Vêtements venant du catalogue : le nom d'origine est conservé (`<dossier du jeu>^<fichier>`), y compris les variantes de peau `_r` / `_whi`, `_bla`…

Collection additionnelle (préfixe = nom du `.ymt` fourni, sans extension) :

```
mp_m_freemode_01_<collection>.ymt
mp_m_freemode_01_<collection>^jbib_000_u.ydd
mp_m_freemode_01_<collection>^jbib_diff_000_a_uni.ytd
```

Slots des composants : `head` (0), `berd` (1), `hair` (2), `uppr` (3), `lowr` (4), `hand` (5), `feet` (6), `teef` (7), `accs` (8), `task` (9), `decl` (10), `jbib` (11).
Accessoires : `p_head` (0), `p_eyes` (1), `p_ears` (2), `p_lwrist` (6), `p_rwrist` (7).
Seule la variante « universelle » (`_u` / `_uni`) est générée dans cette version.

## Outils externes

| Outil | Rôle | Obtention |
|---|---|---|
| Blender (GPL) | Modélisation, préparation des vêtements | https://www.blender.org/download/ |
| Sollumz (extension Blender, GPL) | Import / export des formats GTA V dans Blender | https://github.com/Sollumz/Sollumz |
| CodeWalker | `.ytd` (textures), `.ymt`, conversions XML ↔ binaire | https://github.com/dexyfex/CodeWalker |

L'application **détecte** ces outils (page « Outils et dépendances ») mais ne les télécharge ni ne les exécute à votre place. Leur présence ne garantit pas qu'une conversion réussira : chaque conversion doit être vérifiée dans l'outil.
