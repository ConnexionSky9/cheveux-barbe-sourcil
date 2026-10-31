# Builder Studio — Guide simple

## Installer (5 minutes)

1. Décompresse **builder_studio.zip** dans le dossier `resources/` de ton serveur.
   Tu dois avoir : `resources/builder_studio/fxmanifest.lua`.
2. Dans **server.cfg**, ajoute :
   ```
   ensure builder_studio
   ```
3. Les droits se donnent dans **admin_menu › grades › Gestion › « Builder Studio »** (cases à cocher).
   Optionnel : tu peux aussi utiliser les ACE dans **permissions.cfg** :
   ```
   add_ace group.admin builder.access allow
   add_ace group.admin builder.build allow
   add_ace group.admin builder.edit allow
   add_ace group.admin builder.delete allow
   add_ace group.admin builder.import allow
   add_ace group.admin builder.export allow
   add_ace group.admin builder.admin allow
   ```
4. Redémarre le serveur. En jeu : **admin_menu › Builder Studio** (ou tape **/mapping**).

Rien d'autre n'est obligatoire : pas de base de données, pas d'ESX / QBCore / Qbox.

## Ta première construction (2 minutes)

1. `/mapping` → **Créer ici** (le projet se crée là où regarde la caméra).
2. Onglet **Urbanisme** → clique **Maison** → clique au sol. La maison apparaît.
3. Clique sur un mur → modifie-le à droite (longueur, fenêtres, portes…).
4. **Ctrl+Z** pour annuler. Tout est sauvegardé automatiquement.
5. **Fichier → Publier** : tous les joueurs voient la construction.

## Les commandes à retenir

| Action | Touche |
|---|---|
| Bouger la caméra | Z Q S D (ou flèches) |
| Monter / descendre | E / A |
| Regarder | clic droit maintenu |
| Aller vite | Maj |
| Sélectionner | clic gauche |
| Déplacer / tourner / taille | 2 / 3 / 4 puis glisser une flèche |
| Annuler / rétablir | Ctrl+Z / Ctrl+Y |
| Copier / coller / dupliquer | Ctrl+C / Ctrl+V / Ctrl+D |
| Supprimer | Suppr |
| Poser au sol | Fin |
| Quitter | Échap |
| Marcher dans ta construction | bouton **Tester**, puis `/mapping` pour revenir |

## Les 5 onglets

- **Construction** : murs (2 clics), sols, toits, escaliers, balcons… et portes / fenêtres sur le mur sélectionné.
- **Décoration** : catalogue d'objets (meubles, arbres, véhicules…). Clic = poser, molette = tourner.
- **Intérieur** : pièces toutes prêtes (chambre, salon, cuisine…) et lumières.
- **Terrain & îles** : île, colline, montagne, plage, forêt. Clic au sol.
- **Urbanisme** : maison, immeubles, gratte-ciel, routes, ponts, tunnels, quais.

## Tes propres textures (directement en jeu)

Onglet de droite **Matériaux** :
1. **Bibliothèque** : donne un nom, choisis la résolution, puis **Image du PC** (ou colle un lien https).
2. **Remplacements** : choisis la texture du jeu à remplacer (ou un matériau du kit dans la liste) et ton image → **Appliquer**.
Rien à copier, rien à redémarrer.

## Donner ta map à un autre serveur

**Fichier → Exporter** → une ressource toute prête est créée dans `builder_studio/exports/map_<nom>/`.
Copie ce dossier dans `resources/` et ajoute `ensure map_<nom>`. Elle marche sans le studio.

## Les vrais matériaux (béton, brique, bois, verre…) — optionnel

Sans rien installer, tu construis avec des **blocs colorés** du jeu (16 couleurs).
Pour les vrais matériaux texturés, il faut convertir le **kit architectural** une seule fois :
le zip **builder_studio_kit_sources.zip** contient déjà tous les modèles et textures.
Suis `tools/README.md` (Blender + Sollumz, puis CodeWalker), puis ajoute **avant** builder_studio :
```
ensure builder_studio_kit
```
Vérifie avec **/mapping_kit** (console F8).

## Si ça ne marche pas

- « Tu n'as pas accès au studio » → coche les cases « Builder Studio » de ton grade dans admin_menu (ou ajoute les ACE).
- Rien n'apparaît → tu as choisi le kit architectural sans l'avoir installé : prends « Blocs vanilla » (à gauche dans Construction).
- Un objet est grisé dans le catalogue → il n'existe pas dans ton jeu.
- Mise à jour du studio : **ne remplace jamais le dossier `data/`** (ce sont tes projets).

Ce qui n'est pas possible dans GTA : l'eau (lacs, rivières), modifier le vrai sol de la carte, et les intérieurs « MLO » (à faire dans CodeWalker).
