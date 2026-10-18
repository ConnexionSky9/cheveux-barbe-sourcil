# FiveM Clothing Studio

Application de bureau Windows pour **préparer, retoucher, vérifier et exporter des packs de vêtements FiveM** sans écrire de code.

> Nom provisoire : il se change dans `app.config.json` (`appName`) ou dans **Paramètres**.
> Version : 0.2.1. Lisez la section « Limites connues » avant de l'utiliser.

---

## Ce que fait l'application (et ce qu'elle ne fait pas)

| Fonction | État | Détail |
|---|---|---|
| **Vêtements du jeu** : catalogue de tous les vêtements extraits de votre GTA V (hauts, bras et gants, pantalons, chaussures, chapeaux, lunettes, masques, montres…), vignettes, homme / femme, jeu de base et DLC | ✅ Nouveau (0.2) | Fichiers extraits une fois avec CodeWalker depuis VOTRE jeu : l'application n'en contient aucun. **0.2.1** : glisser-déposer du dossier, nom de dossier libre (question homme / femme si besoin), ajout de plusieurs dossiers, explication précise quand rien n'est trouvé (dossier de GTA V, archives .rpf, Export XML, mauvais mode d'extraction…) |
| **Créer à partir d'un vêtement du jeu** puis modifier sa texture : la texture est **réécrite dans le .ytd du jeu** à l'export | ✅ Nouveau (0.2) ⚠️ expérimental | Même format, taille et mipmaps que l'original. Testé sur des fichiers construits selon la structure documentée du format, **pas encore sur de vrais fichiers du jeu** |
| Formes sur la texture : boutons, fermeture éclair, coutures, poche, rayures, écusson, étoile, cœur, chevron, flèche, croix… + pot de peinture | ✅ Nouveau (0.2) | Chaque forme est un calque modifiable |
| Formes 3D (cube, sphère, cylindre, cône, anneau, plaque, bouton, capsule), suppression de pièces, effacement d'une zone du maillage | ✅ Nouveau (0.2) | Dans l'aperçu 3D et la copie GLB ; **pour aller en jeu, le GLB doit être converti en .ydd** (Blender + Sollumz) |
| Projets (création, ouverture, récents, sauvegarde auto, récupération après plantage, duplication, renommage, suppression, modèles de projet, migration de format) | ✅ Disponible, testé | Un projet = un dossier `<nom>.fcsproj`, jamais confondu avec la ressource exportée |
| Import de fichiers (bouton ou glisser-déposer) avec analyse du format réel | ✅ Disponible, testé | Les originaux sont copiés, jamais modifiés |
| Éditeur de textures en calques | ✅ Disponible, testé | Luminosité, contraste, teinte, saturation, colorer, texte, logos, déplacement / échelle / rotation, recadrage, gomme, pinceau, effacement de zone, opacité, ordre, duplication, annuler / rétablir |
| Lecture d'images | ✅ | PNG, JPEG, TGA (24/32 bits, RLE), DDS (DXT1, DXT3, DXT5, RGBA/BGRA 8 bits) |
| Écriture d'images | ✅ | PNG, JPEG, TGA 32 bits, **DDS DXT1 / DXT5 / BGRA8 avec mipmaps** |
| Aperçu 3D interactif | ✅ OBJ (+MTL), glTF, GLB · ⚠️ FBX partiel | Rotation, zoom, déplacement, vues, éclairage, fil de fer, normales, matériaux, textures appliquées en direct, sélection et transformation des pièces, copie de travail GLB |
| Patron UV sur la texture | ✅ | Calculé à partir des UV réels du modèle chargé (aucun UV inventé) |
| Contrôles géométriques | ✅ | Dimensions, UV manquants, normales manquantes, triangles dégénérés, coordonnées invalides |
| Vêtements, variantes, catégories, bibliothèque (recherche, filtres personnage / catégorie) | ✅ | Slot GTA V choisi par l'utilisateur, jamais déduit d'une catégorie |
| Fichiers GTA V `.ydd`, `.ymt` | ⚠️ Contrôle seulement | Signature RSC7, version, intégrité ; contenu ni affiché ni modifié |
| Fichiers GTA V `.ytd` | ⚠️ Lecture et réécriture des textures (expérimental) | DXT1, DXT3, DXT5, A8R8G8B8, A8, L8 lus ; DXT1, DXT5, A8R8G8B8, A8, L8 réécrits ; BC7 et autres refusés avec un message |
| Export de ressource FiveM | ✅ Disponible, testé | Validation (erreurs / avertissements / informations), génération atomique, `fxmanifest.lua`, `README.txt`, `export_report.json`, annulation sans fichier partiel |
| Création d'un `.ytd` à partir de rien | ❌ Non pris en charge | Partez d'un vêtement du jeu (son `.ytd` est réécrit) ; sinon le DDS est fourni pour CodeWalker |
| Conversion d'un modèle 3D en `.ydd` | ❌ Non pris en charge | Se fait dans Blender + Sollumz (parcours guidé dans l'aide) |
| Génération des `.ymt` / `.meta` d'une collection additionnelle | ❌ Non pris en charge | Fichiers fournis par l'utilisateur (outil spécialisé), vérifiés par l'application |
| Modèles 3D des personnages freemode | ❌ Non fournis | Fichiers du jeu : importez un modèle que vous avez le droit d'utiliser comme « personnage de référence » |

**Statut d'une ressource exportée** : *prête à installer* signifie que **tous les contrôles automatiques** sont réussis. **Aucune ressource n'est testée en jeu par l'application** : ce test reste à faire sur votre serveur.

---

## Prérequis

- Windows 10 ou 11, 64 bits (l'application tourne aussi sous Linux pour le développement).
- Pour lancer depuis les sources ou compiler : **Node.js 20 ou plus récent** (testé avec Node.js 22).
- Outils externes **facultatifs** (seulement pour les étapes qu'ils couvrent) : Blender + Sollumz, CodeWalker. Voir `docs/FORMATS.md`.

## Installation (version empaquetée)

1. Décompressez `FiveM-Clothing-Studio-0.2.1-win-x64.zip` où vous voulez (par exemple `C:\Programmes\FiveM Clothing Studio`).
2. Lancez `FiveM Clothing Studio.exe`.
3. Windows SmartScreen peut avertir (exécutable non signé) : « Informations complémentaires » › « Exécuter quand même ».

Les données utilisateur (configuration, journaux, projets récents, modèles de projet) sont dans `%APPDATA%\FiveM Clothing Studio\`.

## Lancement depuis les sources

```
npm install
npm start
```

## Compilation (Windows 64 bits)

```
npm install
npm run build:win
```

Résultat : `dist/FiveM Clothing Studio-win32-x64/` (dossier portable) et `dist/FiveM-Clothing-Studio-0.2.1-win-x64.zip`.
La compilation fonctionne aussi depuis Linux ou macOS (pas d'icône personnalisée ni de signature dans ce cas).

## Tests

```
npm test                 # 55 tests unitaires et d'intégration (cœur : projets, images, DDS, imports, validation, export)
npm run test:e2e         # parcours complet dans l'application (Windows, ou Linux avec : xvfb-run -a npm run test:e2e)
npm run demo             # régénère le projet et l'export de démonstration (examples/)
```

Le rapport des tests réalisés est dans `docs/RAPPORT_TESTS.md`.

## Formats pris en charge

Voir le tableau complet dans [`docs/FORMATS.md`](docs/FORMATS.md) (lisible, modifiable, convertible, exportable).

## Documentation

- [`docs/GUIDE_UTILISATEUR.md`](docs/GUIDE_UTILISATEUR.md) — pas à pas, de la création du projet à l'installation.
- [`docs/INSTALLATION_FIVEM.md`](docs/INSTALLATION_FIVEM.md) — installer la ressource sur un serveur.
- [`docs/FORMATS.md`](docs/FORMATS.md) — formats, outils externes, limites.
- [`docs/GUIDE_DEVELOPPEUR.md`](docs/GUIDE_DEVELOPPEUR.md) — architecture, format de projet, pipelines, extension.
- [`docs/RAPPORT_TESTS.md`](docs/RAPPORT_TESTS.md) — tests réalisés et non réalisés.

Ces guides sont aussi lisibles dans l'application (**Aide**, touche F1).

## Exemples

- `examples/demo-project/Démo T-shirt rayé.fcsproj` — projet de démonstration créé avec des ressources générées pour l'occasion (motif, logo, modèle 3D simple). Aucun fichier du jeu, aucun contenu de tiers.
- `examples/demo-export/` — export obtenu à partir de ce projet. Il est volontairement **incomplet** : la texture modifiée est fournie en DDS (`demo_tshirt_raye_a_convertir/`) et doit encore être placée dans un `.ytd`. Il sert à vérifier la structure générée.

## Dépendances

| Paquet | Rôle | Licence |
|---|---|---|
| electron 33.2.1 | Application de bureau (développement / empaquetage) | MIT |
| three 0.170.0 | Aperçu 3D (WebGL), chargeurs OBJ / MTL / glTF / FBX, export GLB | MIT |
| pngjs 7.0.0 | Lecture / écriture PNG | MIT |
| jpeg-js 0.4.4 | Lecture / écriture JPEG | BSD-3-Clause |
| @electron/packager 18.3.6 | Construction de l'exécutable Windows (développement) | BSD-2-Clause |
| playwright 1.56.1 | Tests de bout en bout (développement) | Apache-2.0 |

Les lecteurs / écrivains TGA et DDS (compression DXT, mipmaps) sont écrits dans le projet (`src/core/image/`).
Aucun service en ligne n'est utilisé ; l'application fonctionne hors ligne.

## Limites connues

- Pas d'aperçu 3D des vêtements du jeu : le contenu des `.ydd` n'est pas décodé (le catalogue montre leurs textures).
- Les formes et modifications 3D ne vont pas en jeu sans conversion du GLB en `.ydd` (Blender + Sollumz) ; les détails ajoutés sur la TEXTURE (boutons, coutures, logos…) vont, eux, directement en jeu.
- Vêtements du jeu : mode « remplacement » uniquement (le vêtement modifié remplace l'original sur votre serveur). Ajouter de NOUVELLES variantes ou de nouveaux vêtements demande un `.ymt` produit par un outil spécialisé.
- Lecture / réécriture des `.ytd` : expérimentale, à vérifier en jeu sur un premier vêtement avant de produire un gros pack.
- Remplacement de vêtements : seule la variante « universelle » (`_u` / `_uni`) est générée.
- FBX : chargé par Three.js, prise en charge partielle (FBX 7.x) ; les textures externes d'un FBX ne sont pas chargées. Préférez glTF / GLB.
- L'aperçu 3D affiche les modèles en pose de repos (pas d'animation, pas de simulation de tissu, pas de sculpture).
- Compression DXT : encodeur simple (qualité correcte, inférieure aux outils spécialisés).
- La version Windows n'a pas été lancée sur un Windows réel pendant le développement (construction faite sous Linux, application testée sous Linux). Voir `docs/RAPPORT_TESTS.md`.
- Interface en français uniquement (les textes sont regroupés pour une traduction future).

## Licence

MIT.
