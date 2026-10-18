# Rapport des tests — version 0.1.0

Environnement : Linux x64 (conteneur), Node.js 22.22.0, Electron 33.2.1, Chromium avec affichage virtuel (Xvfb), Python 3 + lupa (Lua 5.4) pour l'exécution du manifeste.

## 1. Tests unitaires et d'intégration (`npm test`) — 41 / 41 réussis

| Domaine | Tests |
|---|---|
| Projets | création / sauvegarde / réouverture dans un chemin avec accents et espaces ; sauvegarde automatique et récupération après fermeture anormale ; duplication ; renommage ; suppression refusée hors projet ; import par copie (original intact), doublons, fichiers manquants, limite de taille ; migration depuis le format v1 et refus d'un format plus récent ; textures de travail (calques enregistrés puis rechargés à l'identique) |
| Chemins | refus de `..`, chemins absolus, lecteurs Windows ; noms réservés Windows ; nom technique de ressource |
| Images | PNG et TGA sans perte (transparence conservée) ; JPEG avec avertissements ; DDS BGRA8 sans perte avec 7 niveaux de mipmaps ; DDS DXT5 (alpha conservé, erreur bornée) ; DXT1 couleur exacte ; refus des dimensions non multiples de 4 ; fichiers tronqués / corrompus ; détection par signature et extension trompeuse |
| Retouches et calques | luminosité, contraste, teinte, saturation, colorer, recadrer, effacer, rotation, miroir ; original inchangé ; opacité, visibilité, ordre, duplication, suppression ; logo avec position / échelle / rotation ; annuler / rétablir ; historique limité ; recadrage non destructif ; pinceau et gomme ; sérialisation |
| Modèles 3D | OBJ valide / invalide (faces hors limites, sans géométrie, sans UV) ; GLB valide, sans UV, tronqué, mauvaise version ; FBX (version, prise en charge partielle annoncée) |
| Import | états distincts pour texture / modèle / fichier GTA ; modèle générique jamais déclaré exportable ; refus des fichiers vides, trop gros, archives, formats inconnus ; shop meta reconnu |
| GTA V | noms de fichiers freemode (composants, accessoires, collections) ; analyse d'un nom existant ; RSC7 : en-tête, version inhabituelle (avertissement), données tronquées (erreur) |
| Export | erreurs bloquantes (nom technique, slot, variantes, doublon d'emplacement, mauvais type de fichier) ; export complet : structure, noms, copies binaires identiques, manifeste sans chemin absolu, rapport en chemins relatifs, README avec `ensure` ; pas d'écrasement sans confirmation puis remplacement atomique ; annulation sans fichier laissé ; export bloqué sans écriture ; export incomplet (DDS DXT5 redimensionné en puissance de 2 avec mipmaps, statut « incomplet ») ; collection additionnelle (`.ymt`, `.meta`, `data_file`), erreurs de nommage du `.ymt`, `.ydd` obligatoire |
| Manifeste | contrôle structurel ; **exécution par un vrai interpréteur Lua 5.4** (8 directives reconnues) |
| Interface | empreinte CSP de la carte d'import vérifiée |

Les fichiers `.ydd` / `.ytd` / `.ymt` utilisés sont **synthétiques** (en-tête RSC7 + flux compressé valide, contenu factice) : ils valident la logique de l'application, **pas** un vrai vêtement du jeu.

## 2. Test de bout en bout de l'application (`npm run test:e2e`) — réussi

Exécuté deux fois : depuis les sources, puis sur **l'application empaquetée** (asar, même empaquetage que la version Windows, construite pour Linux).

1. Accueil affiché, aucune erreur dans la console.
2. Nouveau projet « Collection Été » dans un dossier « fcs e2e é … » (accents, espaces).
3. Import de 5 fichiers (PNG, PNG, GLB, YDD, YTD) par la fenêtre d'import.
4. Aperçu 3D du GLB (triangles, matériaux, dimensions).
5. Import d'un OBJ + MTL + texture voisine, affichage sans fichier manquant.
6. Éditeur : réglage de teinte appliqué, texte « ÉLYZÉA », logo importé (3 calques).
7. Ctrl+Z / Ctrl+Y sur les calques.
8. Enregistrement : `project.json` contient la texture et ses 3 calques.
9. Vêtement : slot `jbib`, numéro 15, `.ydd` et `.ytd` associés.
10. Texture de travail appliquée au matériau « Tissu » du modèle : pixel coloré lu dans le rendu WebGL.
11. Patron UV du modèle superposé dans l'éditeur (pixels du tracé vérifiés).
12. Assistant d'export : vérification « prêt », génération, résultat ; fichiers `stream/mp_m_freemode_01^jbib_015_u.ydd` et `…^jbib_diff_015_a_uni.ytd` présents, README avec `ensure collection_ete`.
13. Pages Aide et Outils.

Captures d'écran : `test/.tmp/shots/` (générées à chaque exécution).

## 3. Construction Windows (`npm run build:win`) — réussie, non lancée

- Produit `dist/FiveM Clothing Studio-win32-x64/FiveM Clothing Studio.exe` (PE32+ x86-64, interface graphique) et l'archive zip.
- **L'exécutable Windows n'a pas été lancé** : aucun Windows n'était disponible pendant le développement. Le même code empaqueté a été testé sous Linux (point 2).

## 4. Ce qui n'a PAS été testé

- Lancement et utilisation sur Windows 10 / 11 réels (dialogues natifs, chemins `C:\…`, SmartScreen, mise à l'échelle d'écran).
- Fichiers GTA V réels (`.ydd`, `.ytd`, `.ymt` du jeu ou de packs existants).
- **Installation d'une ressource exportée sur un serveur FiveM et test en jeu.**
- Détection de Blender / Sollumz / CodeWalker installés (absents de l'environnement de test ; le cas « absent » est vérifié).
- FBX réels (seul l'en-tête est testé automatiquement).
- Glisser-déposer depuis l'explorateur Windows (le code utilise l'API officielle `webUtils.getPathForFile`).
- Très gros fichiers (textures 4K, modèles de plusieurs millions de triangles) : pas de mesure de performance.

Les tests automatiques prouvent que le logiciel fait ce qu'il annonce sur les fichiers de test ; ils ne valident pas un vêtement en jeu.
