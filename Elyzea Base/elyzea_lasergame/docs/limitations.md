# Limitations connues et validation en jeu

Cette page dit honnêtement ce qui n'a pas pu être fait ou vérifié, et comment le valider sur ton serveur.

## 1. Aucun test dans un vrai client GTA V / FiveM
L'environnement de développement est un serveur Linux sans GTA V. Le **code serveur** a été exécuté et vérifié (157 vérifications),
le **code client** a été vérifié (syntaxe, contrats avec le serveur et l'interface, relecture des natives) mais **pas exécuté en jeu**.
**À valider en jeu (≈ 20 minutes à deux joueurs)** :
1. PNJ visible, touche E, ouverture de l'interface, son.
2. Créer une arène (docs/administration.md), la vérifier avec « Voir la zone », jouer une partie 1v1 dessus.
3. Un 1v1 sans mise : lasers visibles des deux côtés, impacts, bouclier, élimination, spectateur, manche suivante, écran de fin,
   retour exact à la position, à la tenue et à l'arme RP.
4. Un 1v1 avec une petite mise : débit, gain, journal.
Si un point ne fonctionne pas, les journaux (`/lgadmin › Journaux › Erreurs` et la console F8) indiquent l'endroit.

## 2. Arènes : ce qui n'a pas pu être vérifié sans le jeu
- Le **dessin** (visée du sol, flèches, ↑ ↓ ← →) réutilise les outils d'admin_menu déjà utilisés pour les arènes pvp_arena ;
  le branchement vers elyzea_lasergame est testé hors jeu (actions, permissions, validation), pas le rendu à l'écran.
- Le **décor** de l'éditeur de map apparaît selon la distance d'affichage de l'éditeur : au début d'une partie, le chargement attend ~3 s.
  Sur un décor très chargé, quelques objets peuvent apparaître juste après le décompte.
- Les objets de l'éditeur sont visibles aussi en RP à l'endroit de l'arène (c'est un décor du monde, pas un objet d'instance).
- Aucun contrôle de « ligne de vue » côté serveur entre les apparitions : place-les derrière des couvertures.

## 3. Pas de fichiers .ymap / MLO
Les arènes n'ont besoin d'aucun fichier streamé : la zone et les apparitions sont en base, le décor vient de l'éditeur de map.
Aucun MLO, YTYP ou YDR n'a été créé (aucun modèle personnalisé).

## 4. Limites techniques de FiveM / GTA
- **Murs et tirs** : le serveur ne connaît pas la géométrie du monde. Il vérifie distance, trajectoire, cadence, chargeur et portée,
  mais un client modifié pourrait tirer à travers un mur. Les impacts impossibles sont journalisés (sécurité).
- **Animations** : les noms de dictionnaires d'animation (mêlée) sont ceux du jeu de base ; s'ils manquaient,
  l'action fonctionne quand même, sans animation.
- **Voix** : selon ta configuration de pma-voice, un spectateur peut entendre les joueurs proches. Les spectateurs extérieurs ne peuvent de
  toute façon rien faire dans la partie, et les joueurs éliminés n'observent que leurs coéquipiers.
- **Tenue LaserGame** : `Config.Outfits` utilise le composant 9 (gilet) avec des numéros génériques ; selon tes packs de vêtements,
  ajuste les numéros ou mets `enabled = false` (les vêtements RP sont toujours restaurés).
- **Polices** : Exo 2 et Manrope sont chargées depuis Google Fonts (comme les autres interfaces Elyzea) ; sans internet, police de secours.

## 5. Autres frameworks
Les adaptateurs ESX et QBCore sont écrits mais seule la base Elyzea a été simulée. Pour ESX / QBCore, changer la bibliothèque MySQL dans
le fxmanifest (voir `installation.md` §5) et faire la validation en jeu du §1.
