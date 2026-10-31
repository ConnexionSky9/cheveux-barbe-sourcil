# Builder Studio — éditeur de construction et de mapping 3D en jeu

Ressource sans base de données. Ouverture : **admin_menu › Builder Studio** ou **`/mapping`**.
Droits : **permissions staff d'admin_menu** (cases « Builder Studio ») ; les ACE `builder.*` restent acceptées en plus. Interface NUI en français, inspirée des logiciels 3D (menus, barre d'outils,
hiérarchie, inspecteur, palettes, barre d'état).

> **État : version 1.0, prototype fonctionnel.** Tout ce qui est décrit comme « implémenté » ci-dessous
> existe dans le code et passe les tests hors jeu (`tests/`). **Rien n'a encore été testé dans un vrai
> client GTA V / FiveM** : le comportement des natives en jeu (caméra, sélection, gizmos, placement par
> matrice, lumières, portes) doit être validé sur ton serveur. Voir « Ce qui reste à valider en jeu ».

---

## 1. Ce que permet réellement FiveM / GTA V (analyse)

| Besoin | Possible en jeu ? | Solution retenue |
|---|---|---|
| Créer de la géométrie (mur de 7,3 m, sol troué…) | **Non** : le moteur n'affiche que des modèles existants | Murs, sols, toits… **assemblés en modules** (kit) répétés ; les ouvertures sont de **vrais trous** (les modules ne sont pas posés à cet endroit) |
| Redimensionner un objet | Échelle **visuelle** seulement (`SetEntityMatrix`), la collision ne suit pas | Props : échelle visuelle (signalée). Éléments architecturaux : dimensions changées **par modules** → collision exacte |
| Rotation complète | Oui | Matrice complète (`SetEntityMatrix`), ordre des axes **calibré** au démarrage |
| Matériaux (béton, brique…) | Pas de changement de texture par objet | Un **modèle par matériau** (kit `ubk_*`), teintes de palette pour les props compatibles, transparence (`SetEntityAlpha`) pour le verre |
| Répétition / échelle / orientation de texture, réflexion | **Non** en jeu (UV et shader figés dans le modèle) | Réglées **à la génération** du kit (`tools/kit_generator.js --scale/--rotate`) et dans Sollumz (shader) |
| Textures personnalisées | Oui : `CreateRuntimeTxd` + `AddReplaceTexture` (global à la texture) | Remplacements par projet (PNG dans `textures/custom/`) |
| Lumières | Oui : lumières dynamiques par image (`DrawLightWithRange`, `DrawSpotLight`) | Plafonniers, spots, néons, LED, lampes ; dessinées près de la caméra, nombre limité |
| Portes animées | Oui (entités locales déplacées) | Battantes, doubles, coulissantes, automatiques ; état synchronisé entre joueurs |
| Ascenseurs | Une plate-forme mobile fait tomber les joueurs | Cage + paliers ; **téléportation** entre niveaux (E / G) avec fondu |
| Modifier le relief de GTA | **Non** | Terrains = dalles + talus posés par-dessus (collisions réelles). Vraie île lisse : pipeline heightmap → OBJ → Sollumz |
| Eau (lacs, rivières, cascades) | Seulement via un `water.xml` complet chargé au démarrage | **Non implémenté** en v1 |
| Intérieurs « MLO » (pièces, portails, occlusion) | Uniquement via des fichiers `.ytyp` compilés | Intérieurs = objets posés dans le monde ; MLO à faire dans CodeWalker |
| Fichiers YMAP / YDR / YTD / YBN | Formats binaires de Rockstar | Export du **XML CodeWalker** (`.ymap.xml`, `.ytyp.xml`) + sources OBJ/PNG ; conversion dans CodeWalker / Blender+Sollumz. **Aucun fichier texte n'est présenté comme un binaire.** |

## 2. Fonctionnalités

Légende : ✅ implémenté et testé hors jeu · 🟡 partiel · ❌ non implémenté

| Domaine | Fonctionnalité | État |
|---|---|---|
| Interface | `/mapping`, menus, barre d'outils, hiérarchie, inspecteur, palettes par mode (Construction, Décoration, Intérieur, Terrain & îles, Urbanisme), barre d'état, notifications | ✅ (testée dans Chromium) |
| Projets | Créer, renommer, dupliquer, supprimer, charger, fermer, publier / retirer du jeu | ✅ |
| Projets | Sauvegarde automatique (30 s), copie `.bak`, points de restauration manuels / automatiques, restauration | ✅ |
| Projets | Historique des modifications (qui, quand, quoi) | ✅ |
| Construction | Fondations, sols / étages (avec trémies), murs (2 clics, enchaînés), cloisons, façades à fenêtres répétitives, murs rideaux, plafonds, toits plats / 1 pente / 2 pans, escaliers, colonnes, piliers, balcons, terrasses, ascenseurs | ✅ |
| Ouvertures | Fenêtres (verre clair / teinté / opaque, cadre, volets), vitrines, portes simples / doubles / coulissantes / automatiques, ouvertures vides — découpe réelle du mur | ✅ |
| Ouvertures | Formes non rectangulaires (arcs, œils-de-bœuf) | ❌ |
| Gratte-ciel | Générateur d'immeubles (étages, façades, RDC commercial, ascenseur, sous-sols / parking, toiture), duplication d'étage, chaque étage modifiable | ✅ |
| Intérieurs | Pièces meublées (chambre, salon, cuisine, salle de bain, bureau, couloir, garage, réunion, commerce, entrepôt, sous-sol), éclairage | ✅ |
| Matériaux | 16 matériaux demandés + sable / herbe / terre / roche, teinte des props, transparence du verre | ✅ (kit à installer, voir §5) |
| Textures | Bibliothèque **importée en jeu** : image du PC (redimensionnée en PNG 128 à 2048 px) ou lien https ; remplacements par projet ; aucun fichier à copier, aucun redémarrage | ✅ (logique testée ; rendu en jeu à valider) |
| Permissions | Cases staff d'admin_menu (`builder_manage` = tout, ou `builder_access`, `_build`, `_edit`, `_delete`, `_import`, `_export`) + ACE | ✅ |
| Éditeur 3D | Caméra libre, zoom, rotation, sélection au clic (raycast), gizmos déplacement / rotation / échelle (axes X/Y/Z, repère monde / local), sélection multiple, copier-coller, duplication, suppression, verrouillage, masquage, groupes, hiérarchie par glisser-déposer, alignement, répartition, poser au sol, grille, magnétisme, annuler / rétablir | ✅ (logique testée ; rendu en jeu à valider) |
| Catalogue | ~100 modèles vanilla par catégorie, recherche, catégories, favoris, récents, aperçu en jeu (vraie entité), véhicules décoratifs, objets personnalisés, vérification de présence des modèles | ✅ |
| Terrain & îles | Grille de relief (île, colline, montagne, vallée, falaise, plage), sculpture, aplanissement, matériau auto (sable / herbe / terre / roche), végétation dispersée posée sur le sol | ✅ |
| Terrain & îles | Export heightmap → OBJ lissé (pipeline vers YDR/YBN) | ✅ |
| Terrain & îles | Lacs, rivières, cascades | ❌ |
| Urbanisme | Routes, ponts (garde-corps + piliers), tunnels, quais / docks | ✅ |
| Urbanisme | Zones résidentielles / industrielles automatiques | 🟡 (préréglages d'immeubles et d'entrepôts à combiner) |
| Export | Ressource FiveM autonome : `fxmanifest.lua`, client, serveur (portes), `config.lua`, `data.json`, moteur de rendu, `LISEZMOI.txt` | ✅ |
| Export | `.ymap.xml` (XML CodeWalker) + mode « ymap » dans la ressource exportée | ✅ (conversion par CodeWalker) |
| Export | `.ydr` / `.ytd` / `.ybn` binaires | ❌ par le jeu ; ✅ sources OBJ/PNG + `.ytyp.xml` via `tools/` |
| Sécurité | Permissions ACE (accès, construction, modification, suppression, importation, exportation, admin), validation serveur de chaque opération, anti-spam | ✅ |
| Optimisation | Chargement progressif par distance, N entités par image, entités locales non réseau, limites configurables, lumières limitées, nettoyage à l'arrêt | ✅ |

## 3. Architecture

```
builder_studio/
├── fxmanifest.lua
├── config.lua                 commandes, ACE, limites, chargement, éditeur, export
├── shared/                    (client + serveur + export)
│   ├── mathx.lua              vecteurs, matrices, euler <-> matrice, quaternions, aléatoire déterministe
│   ├── kits.lua               kits de modules et matériaux (copié dans chaque export)
│   ├── geometry.lua           générateurs : élément -> pièces (murs + ouvertures, sols, toits, terrain, routes…)
│   ├── compose.lua            pièces meublées, immeubles, duplication d'étage, clonage (copier-coller)
│   ├── catalog.lua            catalogue 3D et préréglages de pièces
│   └── schema.lua             validation / nettoyage des données reçues des clients
├── server/
│   ├── storage.lua            fichiers JSON (index, projets, .bak, versions, catalogue perso, dimensions)
│   ├── projects.lua           projets, opérations atomiques, permissions ACE, verrous, limites, historique
│   ├── export.lua             génération de la ressource exportée + .ymap.xml
│   └── main.lua               événements réseau, sauvegarde automatique, synchronisation des portes
├── client/
│   ├── runtime.lua            moteur de rendu (copié dans chaque export) : streaming, matrices, lumières, portes, ascenseurs
│   ├── editor.lua             caméra, sélection, gizmos, outils de placement, annuler / rétablir
│   └── main.lua               commandes, événements serveur, rappels NUI
├── html/                      interface (index.html, style.css, app.js, panels.js)
├── export_template/           client.lua / server.lua des ressources exportées
├── tools/                     pipeline d'assets hors jeu (Node.js, Blender)
├── tests/                     tests hors jeu (Lua via lupa, Chromium via Playwright)
├── data/                      projets du serveur (créés automatiquement)
├── exports/                   ressources exportées
└── textures/custom/           PNG des textures personnalisées
```

**Flux d'une modification** : l'interface envoie une action → `client/editor.lua` calcule l'opération
**et son inverse** (annuler) → `builder:op` → le serveur vérifie ACE, verrous, limites et données
(`BSchema`), applique **tout ou rien** → diffuse `builder:applied` aux éditeurs du projet (ou à tous si le
projet est publié) → chaque client met à jour ses entités (déplacement sur place sans clignotement quand
seule la position change).

**Modèle de données** (un projet = un fichier JSON) :
`{ id, name, owner, created, updated, active, origin, elements = { [id] = élément }, textures, history, meta }`
et un élément : `{ id, type, name, parent, pos, rot, level, kit, mat, model, scale, tint, alpha, locked, hidden, params }`.
Les **paramètres** (longueur, ouvertures, hauteurs du terrain…) sont enregistrés, pas les entités : la
géométrie est recalculée à l'identique partout (éditeur, serveur, export).

## 4. Installation

1. Copie `builder_studio` dans `resources/` (déjà dans `Elyzea Base`).
2. `server.cfg` : `ensure builder_studio` (déjà ajouté dans `Serveur cfg/server.cfg`).
3. **Droits** : admin_menu › éditeur de grades › catégorie **Gestion** › cases « Builder Studio »
   (le rang SuperAdmin reçoit « TOUT » au premier démarrage ; le Fondateur a toujours tout).
   Optionnel, en plus : `permissions.cfg` :
   ```cfg
   add_ace group.admin builder.access allow
   add_ace group.admin builder.build allow
   add_ace group.admin builder.edit allow
   add_ace group.admin builder.delete allow
   add_ace group.admin builder.import allow
   add_ace group.admin builder.export allow
   add_ace group.admin builder.admin allow
   ```
   Pour un mappeur sans suppression ni export : donne-lui seulement `access`, `build`, `edit`.
4. Redémarre. admin_menu › **Builder Studio** › « Ouvrir le studio » (ou `/mapping`).
5. **Mise à jour** : ne remplace jamais le dossier `data/` du serveur (tes projets). Les fichiers de
   `data/` sont ignorés par Git pour cette raison.

### Kits de construction

- **Blocs vanilla** : fonctionne immédiatement (blocs du DLC Stunt, teintes 0-15). Les dimensions sont
  mesurées en jeu au démarrage et partagées avec le serveur. Pas de vrais matériaux.
- **Kit architectural `ubk_*`** (vrais matériaux texturés, 379 modèles) : à produire une fois avec le
  pipeline `tools/` (voir `tools/README.md`) puis `ensure builder_studio_kit` **avant** `builder_studio`.
  Tant qu'il n'est pas installé, l'interface l'indique (« 0 / 379 modèles présents ») et rien n'apparaît.
- Diagnostic : `/mapping_kit` (console F8) liste les modèles absents et les dimensions mesurées.

## 5. Utilisation

- **Caméra** : ZQSD / flèches, A / E (descendre / monter), clic droit maintenu pour regarder, molette, Maj (rapide), Ctrl (lent).
- **Sélection** : clic (sélectionne le groupe racine) ; Alt+clic : l'élément seul ; Maj/Ctrl+clic : ajouter.
- **Gizmo** : 2 déplacer, 3 rotation, 4 échelle, T monde / local, X magnétisme. Glisser une flèche = axe, le point central = plan horizontal.
- **Édition** : Ctrl+Z / Ctrl+Y, Ctrl+C / Ctrl+V, Ctrl+D, Suppr, Ctrl+G / Ctrl+Maj+G, L verrouiller, H masquer, Fin poser au sol, F centrer.
- **Murs** : outil Mur, clic début, clic fin ; Maj+clic pour enchaîner. Ouvertures : sélectionne le mur → palette « Ouvertures » ou inspecteur.
- **Immeubles** : Urbanisme → préréglage → clic. Puis sélectionne un étage → « Dupliquer l'étage ».
- **Terrain** : Terrain & îles → relief → clic ; inspecteur → Sculpter (clic élève, Maj+clic abaisse).
- **Routes / ponts / tunnels / quais** : clics successifs, Entrée pour terminer.
- **Tester** : bouton « Tester » (tu marches sous la caméra), `/mapping` pour revenir.
- **Publier** : Fichier → Publier : le projet devient visible par tous les joueurs (chargement progressif).

### Textures (tout en jeu)

Panneau de droite › **Matériaux** :
1. **Bibliothèque de textures** : nom, résolution (128 à 2048, puissances de 2), puis **Image du PC** ou **lien https**.
   L'image du PC est redimensionnée en PNG dans l'interface et gardée sur le serveur (`data/textures/`).
2. **Remplacements du projet** : texture du jeu visée (`dictionnaire|texture`, ou un matériau du kit
   architectural proposé dans la liste : `ubk_textures|ubk_brique`…) + image de la bibliothèque → **Appliquer**.
   Tous les joueurs qui ont le projet chargé (ou tout le monde s'il est publié) voient le changement.
3. À l'export, les images deviennent de vrais PNG de la ressource exportée (les liens restent des liens).

Limite du moteur : GTA remplace une texture **pour tous les objets qui l'utilisent** (pas objet par objet).
Les noms `dictionnaire|texture` des objets vanilla se lisent dans CodeWalker.

## 6. Export

Fichier → Exporter : crée `builder_studio/exports/map_<nom>/` (fichiers listés dans l'interface). Copie le
dossier dans `resources/`, `ensure map_<nom>` : la map tourne **sans** `builder_studio`.
Le `.ymap.xml` est le format texte de CodeWalker : importe-le dans CodeWalker pour obtenir le `.ymap`,
mets-le dans `stream/` de la ressource exportée et passe `Mode = 'ymap'` dans son `config.lua`
(le script ne gère alors plus que portes, lumières, ascenseurs et véhicules décoratifs).

## 7. Sécurité et performances

- Chaque événement serveur vérifie l'ACE correspondante ; la console a tous les droits.
- Données client nettoyées : champs connus, nombres finis et bornés (±20 000 m), textes courts, noms de modèles `[A-Za-z0-9_-]`, taille des paramètres limitée, hiérarchie sans boucle.
- Opérations **atomiques** (un lot invalide n'applique rien), verrous respectés, 25 actions / s max par joueur.
- Limites (`Config.Limits`) : 5 000 éléments et 12 000 modules par projet, **1 500 objets par élément**, **2 500 objets ajoutés par action**, 600 éléments par action, 200 projets. Un élément trop lourd est refusé avec un conseil (réduire la grille, les étages…) ; un élément déjà trop gros reste déplaçable.
- **Anti-plantage** : GTA plante quand sa réserve d'objets est pleine (« Pool full »). Le studio compte les objets de tout le monde du joueur chaque seconde et n'en crée jamais au-delà de `Config.Stream.maxWorldObjects` (1 800), ni plus de `maxEntities` (1 500) pour lui-même. Les éléments les plus proches de la caméra passent en premier ; au-delà, la barre d'état l'indique.
- **Fluidité** : modifier un élément (sculpture, longueur d'un mur…) réutilise les objets déjà posés et ne crée / supprime que la différence ; le déplacement d'un gros élément est rafraîchi ~16 fois par seconde ; 8 créations par image.
- Estimation avant de poser : chaque carte de relief et d'immeuble affiche le nombre d'objets, et les cartes trop lourdes sont grisées.
- Client : entités **locales** (aucune charge réseau / OneSync), chargement par distance (250 m) avec marge de déchargement, 48 lumières max près de la caméra, attente de modèle limitée à 6 s, suppression de tout à l'arrêt de la ressource.

## 8. Tests

```bash
pip install lupa
python3 tests/run_admin_textures.py   # permissions admin_menu, bibliothèque de textures, export, moteur de textures
python3 tests/make_init.py > /tmp/init.json && NODE_PATH=$(npm root -g) node tests/ui_textures.cjs /tmp/init.json
# Les 3 tests ci-dessous font partie de la version d'origine mais n'étaient pas dans le zip reçu :
python3 tests/run_tests.py      # géométrie, serveur (projets, ACE, verrous, limites, export), annuler/rétablir, syntaxe
python3 tests/tools_test.py     # pipeline : noms et dimensions identiques jeu / générateur, PNG, heightmap
python3 tests/ui_test.py        # interface dans Chromium (Playwright) avec les vraies données Lua
```

### Ce qui reste à valider en jeu

Ces points dépendent du comportement réel des natives et n'ont **pas** pu être testés ici :
caméra libre et focus de streaming, sélection par raycast sur des entités locales, gizmos (projection
écran), calibrage de `SetEntityMatrix`, rendu des blocs vanilla (formes réelles des modèles Stunt),
lumières, animation des portes, ascenseurs, remplacement de textures, débit des gros projets publiés
(`TriggerLatentClientEvent`), écriture des exports (`io` / `os.execute` côté serveur).

## 9. Feuille de route

1. Validation en jeu et corrections (priorité).
2. Eau : génération d'un `water.xml` complet (lacs, rivières) chargé au démarrage.
3. Ouvertures non rectangulaires, escaliers tournants, pignons de toiture.
4. Génération automatique de quartiers (lotissements, zones industrielles).
5. Conversion binaire directe (YMAP) sans CodeWalker, si le format peut être validé.
