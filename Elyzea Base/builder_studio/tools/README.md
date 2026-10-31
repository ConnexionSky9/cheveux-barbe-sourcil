# Pipeline d'assets (hors jeu)

GTA V ne lit que des fichiers binaires (`.ydr` modèles, `.ytd` textures, `.ybn` collisions, `.ytyp`
archétypes, `.ymap` placements). Builder Studio produit leurs **sources** ; la conversion binaire se fait
avec les outils de la communauté : **Blender + Sollumz** (modèles, textures, collisions) et **CodeWalker**
(`.ytyp`, `.ymap`). Prérequis : Node.js 18+, Blender 3.3+ avec l'extension Sollumz, CodeWalker.

## 1. Kit architectural `ubk_*` (vrais matériaux)

```bash
node tools/kit_generator.js C:\kit                        # tout (379 modèles, 20 textures)
node tools/kit_generator.js C:\kit --materials beton,brique,verre_clair,bois   # seulement certains
node tools/kit_generator.js C:\kit --scale brique=1.5 --rotate bois=90 --size 1024
```

- `--scale mat=m` : une répétition de texture couvre `m` mètres (répétition / échelle de texture).
- `--rotate mat=deg` : orientation de la texture.
- Dimensions et noms lus dans `shared/kits.lua` : identiques à ceux que le jeu demande (vérifié par `tests/tools_test.py`).

Produit :
- `source/obj/*.obj|.mtl` : un modèle par module et matériau, origine au centre de la face du bas, axe Y vers le haut (import Blender par défaut → Z vers le haut comme GTA).
- `source/textures/ubk_*.png` : textures procédurales raccordables (le verre a une transparence dans l'alpha).
- `source/ubk_kit.ytyp.xml` : archétypes (XML CodeWalker), dictionnaire de textures `ubk_textures`.
- `builder_studio_kit/fxmanifest.lua` : la ressource à remplir.

Conversion :
1. Blender → Scripting → `tools/blender_import_kit.py` (règle `KIT_DIR`) : importe les OBJ et nomme les objets.
2. Avec Sollumz : convertis les objets en Drawable, crée la collision (boîte) de chacun, regroupe les textures dans `ubk_textures` ; pour le verre, choisis un shader de verre (la réflexion se règle ici). Exporte les `.ydr` (et `.ybn` si séparées) et le `.ytd`.
3. CodeWalker : importe `ubk_kit.ytyp.xml` et enregistre `ubk_kit.ytyp`.
4. Mets `.ydr`, `.ybn`, `ubk_textures.ytd`, `ubk_kit.ytyp` dans `builder_studio_kit/stream/`, copie la ressource dans `resources/`, puis dans `server.cfg` : `ensure builder_studio_kit` **avant** `ensure builder_studio`.
5. En jeu : `/mapping_kit` doit afficher `ubk : 379 / 379` (ou le nombre de modèles convertis).

Les menus exacts de Sollumz / CodeWalker évoluent : réfère-toi à leur documentation.

## 2. Terrains et îles

Dans le studio : sélectionne un terrain → Propriétés → « Exporter la heightmap (JSON) », enregistre le texte.

```bash
node tools/heightmap_to_obj.js terrain.json terrain.obj --subdiv 2 --uv 8
node tools/heightmap_to_obj.js ile.pgm ile.obj --cell 4 --height 40 --base 0     # image PGM 8 bits
```

Le maillage est lissé (hauteurs aux coins), avec un bord qui descend au niveau de base. Dans Blender :
Sollumz → Drawable + collision → `.ydr` / `.ybn` ; dans CodeWalker : place-le avec un `.ymap`
(position et cap fournis dans le JSON : `origin`, `heading`).

## 3. Placements (YMAP)

Chaque export contient `map_<nom>.ymap.xml` (CodeWalker). Importe-le dans CodeWalker, enregistre le
`.ymap`, mets-le dans `stream/` de la ressource exportée et `Mode = 'ymap'` dans son `config.lua`.
Les rotations sont écrites en quaternion conjugué (convention des YMAP) : vérifie l'orientation de
quelques objets dans CodeWalker lors de la première conversion.
