# Guide utilisateur

Le parcours : **Créer → Modifier → Prévisualiser → Vérifier → Exporter → Installer.**

L'écran est organisé en trois zones : la **bibliothèque** à gauche (vêtements, textures, fichiers), la **zone de travail** au centre (aperçu 3D ou éditeur de texture), les **propriétés** à droite. Les panneaux se masquent avec Ctrl+1 et Ctrl+2. La barre du bas indique les opérations en cours et l'heure du dernier enregistrement.

## 1. Créer un projet

1. Accueil › **Nouveau projet** (Ctrl+N).
2. Donnez un nom (accents et espaces acceptés), choisissez le dossier, cochez le ou les personnages : homme (`mp_m_freemode_01`) et / ou femme (`mp_f_freemode_01`).
3. Facultatif : partez d'un **modèle de projet** (Propriétés du projet › « Enregistrer comme modèle »).

Le projet est un dossier `<nom>.fcsproj`. Il est **enregistré automatiquement** toutes les 60 secondes ; Ctrl+S enregistre tout de suite. Si l'application se ferme mal, elle propose de récupérer le travail à la réouverture.

## 2. Importer une texture

- **Importer** (Ctrl+I) ou **glissez-déposez** des fichiers depuis l'explorateur Windows sur la zone centrale.
- Chaque fichier est analysé : format réel, dimensions, transparence, états *lisible / affichable / modifiable / convertible / exportable*, problèmes détectés.
- Les fichiers sont **copiés** dans le projet : vos originaux ne sont jamais modifiés.

Formats d'image : PNG, JPEG, TGA, DDS (voir `FORMATS.md`).

## 3. Modifier une texture et placer un logo

1. Cliquez sur l'image importée (Images et logos) › **Ouvrir dans l'éditeur**. Une *texture de travail* en calques est créée ; l'image d'origine devient le calque « Original ».
2. Outils à gauche de la zone : **Déplacer** (glisser le calque), **Pinceau**, **Gomme**, **Effacer une zone**, **Recadrer**. Molette = zoom ; clic droit ou Espace + glisser = faire défiler la vue.
3. **Logo** : bouton « Importer un logo ou une image » dans Calques. Il est centré et réduit ; ajustez **X, Y, Échelle, Rotation** ou glissez-le avec l'outil Déplacer.
4. **Texte** : bouton « Ajouter du texte » (police, taille, couleur, contour, gras). « Modifier le texte » pour le changer ensuite.
5. **Couleurs** : Luminosité, Contraste, Teinte, Saturation, **Colorer** (change la couleur en gardant les ombres du tissu). L'aperçu est immédiat ; cliquez **Appliquer** pour valider.
6. **Dimensions…** : 256 à 4096 px (les calques suivent sans perte jusqu'à l'export).
7. **Enregistrer** la texture, ou **Exporter…** en PNG, TGA, JPEG ou **DDS** (DXT1, DXT5 ou BGRA8, mipmaps).

Annuler / rétablir : Ctrl+Z / Ctrl+Y (40 étapes par défaut, réglable).

## 4. Gérer les calques

Dans le panneau de droite : ajouter un calque vide, dupliquer, supprimer, monter, descendre, masquer (œil), opacité, renommer (double-clic). Le calque sélectionné reçoit les outils et les réglages de couleur.

**Repères** :
- « Afficher le patron UV du modèle 3D » dessine les UV **réels** du modèle chargé dans l'aperçu. Sans modèle, la texture est affichée à plat.
- « Image de référence » superpose une image semi-transparente (non exportée).

## 5. Importer un modèle 3D

- Formats : OBJ (+ MTL), glTF, GLB, FBX (partiel). Gardez le `.mtl`, les textures et les `.bin` à côté du modèle d'origine.
- Double-cliquez sur le modèle (Modèles 3D) ou « Afficher en 3D ».
- Barre de l'aperçu : vues Face / Dos / Gauche / Droite / Dessus, réinitialiser, fil de fer, normales, grille, lumière. Souris : clic gauche = tourner, molette = zoom, clic droit = déplacer.
- Cliquez sur une pièce pour la sélectionner, puis **Déplacer / Tourner / Échelle** (panneau de droite). « Enregistrer une copie de travail (GLB) » conserve ces réglages dans le projet.
- Les problèmes détectés (UV manquants, triangles dégénérés…) et les dimensions s'affichent à droite.

Le personnage freemode du jeu n'est pas fourni. Pour un repère visuel, importez un modèle que vous avez le droit d'utiliser puis « Personnage de référence… » : il s'affiche en transparence. Ce n'est pas le corps exact du jeu.

## 6. Associer des matériaux

Avec un modèle affiché et un vêtement sélectionné : panneau de droite › **Matériaux et textures** › choisissez une texture de travail pour chaque matériau. L'aperçu se met à jour en direct pendant que vous modifiez la texture.

## 7. Préparer un vêtement

Bibliothèque › Vêtements › **+**, puis dans Propriétés :

1. **Nom, description, catégorie** (la catégorie sert seulement à ranger).
2. **Personnage cible** : un vêtement correspond à un seul personnage.
3. **Emplacement GTA V** : type (composant ou accessoire), **slot**, **numéro du modèle**.
   - *Remplacement* : numéro du vêtement du jeu à remplacer.
   - *Collection additionnelle* : numéro dans votre collection (à partir de 0).
4. **Fichiers** : le `.ydd` (modèle GTA V) si vous en avez un ; sans `.ydd` en mode remplacement, seules les textures sont remplacées.
5. **Variantes** (a, b, c…) : pour chacune, un `.ytd` **ou** une texture de travail. Une texture de travail est exportée en DDS à convertir (pack incomplet tant que ce n'est pas fait).

Le point de couleur dans la bibliothèque : vert = complet, orange = conversion externe nécessaire, rouge = information manquante.

### Partir d'un vêtement existant (variante)

1. Importez le `.ydd` et le `.ytd` d'un vêtement que vous avez le droit de modifier (les noms au format du jeu sont reconnus automatiquement).
2. Pour modifier sa texture : ouvrez le `.ytd` dans CodeWalker, exportez la texture en DDS ou PNG, importez-la ici, modifiez-la.
3. Créez le vêtement avec le même slot et le même numéro, associez le `.ydd`, ajoutez une variante avec votre texture de travail.
4. Exportez : le DDS est produit avec le nom de texture conseillé ; remettez-le dans un `.ytd` avec CodeWalker, réimportez ce `.ytd` dans la variante, exportez de nouveau → pack complet.

### Créer un nouveau modèle 3D

La modélisation se fait dans Blender : partez d'un vêtement existant importé avec Sollumz, gardez le squelette du personnage et les poids, modifiez la forme, puis exportez en `.ydd` avec Sollumz. Importez ensuite le `.ydd` ici. Un modèle OBJ / GLB peut servir d'aperçu et de patron UV, mais il ne remplace pas le `.ydd`.

## 8. Vérifier les fichiers

- Dans un vêtement : **Vérifier** affiche les problèmes de ce vêtement.
- L'assistant d'export (étape 2) vérifie tout le projet : **erreur bloquante**, **avertissement** (conséquence expliquée), **information**.
- Fichiers manquants : barrés en rouge dans la bibliothèque, listés dans les propriétés du projet.

## 9. Exporter un pack

**Exporter pour FiveM** (Ctrl+E) :

1. **Configuration** : nom du pack (le nom technique est proposé automatiquement : minuscules, sans accent ni espace), dossier de destination, mode (*remplacer des vêtements du jeu* ou *collection additionnelle* avec son `.ymt` et son `.meta`).
2. **Vérification** : rapport. Les erreurs bloquantes empêchent l'export.
3. **Génération** : barre de progression, bouton Annuler. Rien n'apparaît dans la destination tant que tout n'est pas terminé et vérifié. Une ressource du même nom n'est remplacée qu'après confirmation, et seulement si le nouvel export réussit.
4. **Résultat** : chemin, nombre de fichiers, contrôles réussis, ce qu'il reste à faire, boutons pour ouvrir le dossier et le README.

Contenu : `fxmanifest.lua`, `stream/` (fichiers du jeu renommés), `data/` (collection additionnelle), `README.txt`, `export_report.json`. Si des textures restent à convertir : dossier `<ressource>_a_convertir/` à côté, avec les DDS et `A_LIRE.txt`.

## 10. Installer le pack sur FiveM

Voir `INSTALLATION_FIVEM.md`. En bref : copiez le dossier dans `resources`, ajoutez `ensure <nom_technique>` dans `server.cfg`, redémarrez, vérifiez la console, testez en jeu.

## 11. Erreurs courantes

| Message | Solution |
|---|---|
| « Nom technique de ressource invalide » | Minuscules, chiffres, `_` ou `-` uniquement. |
| « slot GTA V non choisi » / « numéro du modèle non défini » | Propriétés du vêtement › Emplacement GTA V. |
| « … utilisent le même emplacement » | Deux vêtements ont le même personnage + slot + numéro. |
| « n'est pas une ressource GTA V (signature RSC7 absente) » | Le fichier n'est pas un vrai `.ydd` / `.ytd` (extension renommée ou fichier endommagé). |
| « Données de la ressource illisibles ou tronquées » | Fichier incomplet ou corrompu : réexportez-le depuis l'outil d'origine. |
| « Version de ressource inhabituelle » | Avertissement : fichier d'une autre plateforme ou d'un autre outil, à vérifier en jeu. |
| « … pèse plus de 16 Mo » | FiveM signale les fichiers trop lourds : réduisez la taille des textures. |
| « Les formats compressés DXT exigent des dimensions multiples de 4 » | Dimensions… › choisissez 512, 1024, 2048… |
| « Format DDS non pris en charge : bc7 » | Convertissez la texture en DXT1 / DXT5 / RGBA dans un autre outil. |
| « Fichiers non trouvés à côté du modèle » | Gardez le `.mtl`, les textures et les `.bin` dans le dossier d'origine du modèle. |
| « Le dossier … existe déjà » | Confirmez le remplacement ou changez le nom technique. |
| Aperçu 3D impossible | Préférez GLB ; vérifiez le fichier dans Blender. Les autres opérations restent disponibles. |

Journaux techniques : Aide › « Ouvrir le dossier des journaux » (un fichier par jour).
