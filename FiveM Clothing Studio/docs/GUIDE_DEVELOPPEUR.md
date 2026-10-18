# Guide développeur

## Choix techniques

| Besoin | Choix | Pourquoi |
|---|---|---|
| Application de bureau Windows | **Electron 33** | Un seul langage (JavaScript) pour le cœur et l'interface ; WebGL pour la 3D ; empaquetage Windows possible depuis n'importe quel système ; aucun service en ligne. |
| Aperçu 3D | **Three.js 0.170** | Chargeurs OBJ / MTL / glTF / FBX et export GLB éprouvés, licence MIT. |
| Images | Code du projet + **pngjs** + **jpeg-js** | TGA et DDS (DXT, mipmaps) écrits ici : le format DDS des textures du jeu est maîtrisé et testé sans dépendance native. |
| Tests | `node:test` + **Playwright** | Le cœur est testé sans interface ; l'application complète est pilotée de bout en bout. |

Alternatives écartées : WPF / .NET (pas de compilation ni de test possibles hors Windows, aperçu 3D à construire), Tauri (chaîne Rust + WebView2 plus lourde pour un gain faible ici).

## Architecture

```
src/
├── core/                 Cœur métier (Node.js, sans Electron) — testé par npm test
│   ├── paths.js          Noms et chemins sûrs (accents, Windows, refus des sorties de dossier)
│   ├── logger.js         Journal JSON par jour
│   ├── config.js         Configuration centralisée (app.config.json + copie utilisateur)
│   ├── detect.js         Détection du format réel (signatures)          [PUR]
│   ├── importer.js       Analyse avant import : états, problèmes, opérations
│   ├── tools.js          Détection des outils externes (execFile, jamais de shell)
│   ├── image/
│   │   ├── rgba.js       Image RGBA                                    [PUR]
│   │   ├── ops.js        Retouches (renvoient une nouvelle image)      [PUR]
│   │   ├── layers.js     Document en calques + annuler / rétablir      [PUR]
│   │   ├── dds.js        DDS : lecture DXT1/3/5/RGBA, écriture DXT1/DXT5/BGRA8 + mipmaps [PUR]
│   │   ├── tga.js        TGA : lecture types 2/3/10/11, écriture 32 bits [PUR]
│   │   └── codecs.js     PNG / JPEG / TGA / DDS depuis le disque
│   ├── model/inspect.js  Analyse OBJ / glTF / GLB / FBX                [PUR]
│   ├── gta/
│   │   ├── rsc7.js       En-tête et intégrité des ressources RSC7
│   │   └── naming.js     Slots et noms de fichiers freemode           [PUR]
│   ├── project/
│   │   ├── schema.js     Format de projet versionné + migrations
│   │   ├── store.js      Création, ouverture, sauvegarde atomique, auto-sauvegarde, verrou, import
│   │   └── textures.js   Textures de travail (doc.json + calques PNG)
│   └── export/
│       ├── validate.js   Validation + plan d'export (erreur / avertissement / information)
│       ├── manifest.js   Génération et contrôle de fxmanifest.lua
│       └── exporter.js   Export atomique, rapport, README d'installation
├── main/                 Processus principal Electron
│   ├── main.js           Fenêtre, menu, journaux, configuration
│   ├── ipc.js            Fonctions exposées à l'interface ({ ok, … } ou { ok: false, error })
│   └── preload.cjs       Pont sécurisé (contextIsolation, sandbox)
└── renderer/             Interface (modules ES, sans framework)
    ├── app.js            État, navigation, enregistrement, annuler / rétablir du projet
    ├── ui.js             Éléments, icônes, notifications, fenêtres modales
    └── views/            Accueil, espace de travail, éditeur de textures, aperçu 3D, export, outils, aide
```

Les modules marqués **[PUR]** n'utilisent aucune API Node : l'éditeur de textures les importe directement, si bien que l'aperçu et l'export final passent par le **même code testé**.

### Sécurité

- `contextIsolation: true`, `sandbox: true`, `nodeIntegration: false`, CSP stricte (script-src limité au fichier et au hash de l'importmap, vérifié par un test).
- Navigation interdite ; liens externes limités à `https://`.
- Tous les chemins issus de fichiers ou de l'utilisateur passent par `safeJoin` / `safeFileName` (refus de `..`, chemins absolus, lecteurs, UNC, noms réservés Windows).
- Les fichiers voisins d'un modèle (MTL, textures, .bin) ne sont lus que dans le dossier d'origine du modèle, 64 Mo maximum chacun.
- Les archives ZIP ne sont pas décompressées (pas de risque « zip slip ») : l'utilisateur les décompresse lui-même.
- Décompression RSC7 limitée (`maxOutputLength`) contre les fichiers piégés.
- Outils externes appelés avec `execFile` et un tableau d'arguments, jamais avec une chaîne de commande.

## Format de projet (version 2)

Dossier `<nom>.fcsproj/` :

```
project.json            Description du projet (ci-dessous)
project.json.bak        Version précédente (à chaque enregistrement)
autosave.json           Sauvegarde automatique (supprimée à l'enregistrement ou à la fermeture normale)
.lock                   Verrou { pid, host, at } : détecte une double ouverture et une fermeture anormale
assets/originals/       Copies des fichiers importés (« <id8>_<nom> »)
models/                 Copies de travail GLB
textures/<id>/          Textures de travail : doc.json, layers/<calque>.png, preview.png
reports/                Rapports d'export
```

`project.json` :

```json
{
  "format": "fivem-clothing-studio-project", "formatVersion": 2, "appVersion": "0.1.0",
  "id": "uuid", "name": "…", "description": "…", "createdAt": "…", "updatedAt": "…",
  "targetPeds": ["mp_m_freemode_01"],
  "categories": ["T-shirts", "…"],
  "assets": [{ "id", "kind": "texture|model|gta|material", "format", "name", "file": "assets/originals/…",
               "originalPath", "size", "sha256", "importedAt", "info": { "role", "status", "summary", "issues", "garment" } }],
  "textureDocs": [{ "id", "name", "dir": "textures/<id>", "sourceAssetId", "width", "height", "layers", "updatedAt" }],
  "garments": [{ "id", "name", "description", "category", "ped", "kind": "component|prop", "slot", "drawableIndex",
                 "yddAssetId", "modelAssetId", "materials": [{ "name", "textureDocId" }],
                 "variants": [{ "id", "name", "letter", "ytdAssetId", "textureDocId" }] }],
  "exportSettings": { "packName", "resourceName", "mode": "replace|addon", "destination",
                      "collections": { "<ped>": { "ymtAssetId", "metaAssetId" } } },
  "referenceModels": { "<ped>": "<assetId>" },
  "reports": [{ "t", "file", "status", "resource" }],
  "history": [{ "t", "action" }]
}
```

**Migrations** : `schema.js › MIGRATIONS[v]` transforme la version `v` en `v + 1`. À l'ouverture d'un ancien projet, une copie `project.v-old.<date>.json` est conservée. Un projet d'une version plus récente est refusé avec un message clair. Pour une nouvelle version du format : incrémenter `PROJECT_VERSION`, ajouter `MIGRATIONS[ancienne]`, ajouter un test.

Toutes les écritures sont **atomiques** (fichier temporaire puis renommage).

## Pipeline d'import

1. `detect.sniff` : format réel par signature, incohérence d'extension signalée.
2. `importer.inspectFile` : taille (limite configurable), lecture, analyse spécialisée (image, modèle, GTA), états, problèmes, opérations possibles.
3. `store.importAsset` : copie dans le projet (sans écraser, `COPYFILE_EXCL`), empreinte SHA-256, doublons détectés.

## Pipeline de conversion

| Source | Cible | Où |
|---|---|---|
| PNG / JPEG / TGA / DDS | Calques (RGBA) | `codecs.decodeImage` |
| Calques | PNG / TGA / JPEG / DDS (DXT1, DXT5, BGRA8, mipmaps) | `layers.composite` + `codecs.encodeImage` |
| OBJ / glTF / GLB / FBX | Scène 3D | Three.js (interface) |
| Scène 3D | GLB de travail | `GLTFExporter` |
| Texture de travail | DDS à insérer dans un `.ytd` | `exporter.js` (dossier `_a_convertir`) |
| Modèle 3D → `.ydd`, DDS → `.ytd`, `.ymt` | — | **Non réalisé** : Blender + Sollumz, CodeWalker |

## Système d'export

`validate.js` produit `{ status, issues, plan }` :
- `blocked` (erreur), `incomplete` (textures à convertir), `ready` (contrôles réussis — jamais « testé en jeu ») ;
- `plan.stream` (copies vers `stream/`), `plan.dataFiles` (métadonnées), `plan.pending` (DDS à convertir).

`exporter.js` : dossier temporaire à côté de la destination → copies binaires (empreintes vérifiées) → DDS à convertir → manifeste → contrôle de structure (`checkManifest`, fichiers présents, copies identiques) → `README.txt` + `export_report.json` → renommage final (l'ancienne ressource n'est supprimée qu'après réussite) → nettoyage du temporaire dans tous les cas. Annulation possible entre chaque étape.

## Tests

- `npm test` : `test/*.test.js` (node:test). Fichiers de test créés à la volée (images, OBJ, GLB). Les fichiers RSC7 sont **synthétiques** : ils vérifient la logique (en-tête, intégrité, nommage, export), pas un vrai vêtement du jeu.
- `npm run test:e2e` : `test/e2e/app.e2e.mjs`, pilote l'application (fenêtres natives simulées dans le processus principal). Avec `FCS_EXE=<exécutable>`, teste l'application empaquetée.
- Le manifeste généré est exécuté par un vrai interpréteur Lua 5.4 (via `lupa`, si Python + lupa sont installés).

## Étendre l'application

- **Nouveau format d'image** : décodeur dans `src/core/image/`, cas dans `detect.sniff` et `codecs.decodeImage`, test d'aller-retour.
- **Nouveau format 3D** : chargeur Three.js dans `viewer3d.js › load`, analyse dans `model/inspect.js`, cas dans `importer.js`.
- **Nouveau mode d'export / profil d'intégration** (ESX, QBCore…) : entrée dans `EXPORT_MODES` (validate.js), plan dans `validateExport`, fichiers générés dans `exporter.js` — uniquement si le format cible est documenté et vérifiable.
- **Traduction** : les textes de l'interface sont dans `src/renderer/` ; les regrouper dans un fichier de langue avant d'ajouter l'anglais.
- **Opération de retouche** : fonction pure dans `ops.js` (nouvelle image en sortie), bouton dans `textureEditor.js`, test.

## Limites techniques

Voir `FORMATS.md` et le README (section « Limites connues »).
