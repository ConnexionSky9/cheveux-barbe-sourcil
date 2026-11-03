# Limitations connues et validation en jeu

Cette page dit honnêtement ce qui n'a pas pu être fait ou vérifié, et comment le valider sur ton serveur.

## 1. Aucun test dans un vrai client GTA V / FiveM
L'environnement de développement est un serveur Linux sans GTA V. Le **code serveur** a été exécuté et vérifié (157 vérifications),
le **code client** a été vérifié (syntaxe, contrats avec le serveur et l'interface, relecture des natives) mais **pas exécuté en jeu**.
**À valider en jeu (≈ 20 minutes à deux joueurs)** :
1. PNJ visible, touche E, ouverture de l'interface, son.
2. `/lgadmin › Cartes › Aperçu` sur chaque carte (voir §2).
3. Un 1v1 sans mise : lasers visibles des deux côtés, impacts, bouclier, élimination, spectateur, manche suivante, écran de fin,
   retour exact à la position, à la tenue et à l'arme RP.
4. Un 1v1 avec une petite mise : débit, gain, journal.
5. Une partie Zombie solo : zombies qui avancent et frappent, porte, arme murale, atout, à terre, fin.
Si un point ne fonctionne pas, les journaux (`/lgadmin › Journaux › Erreurs` et la console F8) indiquent l'endroit.

## 2. Cartes : emplacement et objets
- Les 5 cartes sont **réellement construites** (1 489 objets GTA V du jeu de base, validées automatiquement) mais **personne ne les a vues
  en jeu**. Les dimensions des objets utilisées pour la validation sont des estimations. En jeu, les murs utilisent les vraies dimensions
  mesurées, donc ni trou ni chevauchement dans les murs. Un objet isolé peut toutefois être un peu plus grand ou plus petit que prévu.
- **Complexes souterrains** : le sol et le plafond sont pavés **en jeu** avec le premier modèle disponible, avec ses vraies dimensions.
  - Ordre : `stt_prop_stunt_bblock_xl3`, `xl1`, `lrg3`, `lrg1`, puis `prop_container_01a`.
  - La couverture sans trou est vérifiée hors jeu pour un grand bloc et pour les conteneurs.
  - Avec des conteneurs, une carte XL compte environ 3 500 pièces de sol et de plafond, ce qui est plus lourd mais fonctionne.
- L'emplacement (45 m sous le désert de Grand Senora, loin de l'eau) n'a pas pu être vu en jeu. S'il ne convient pas : `/lgadmin › Cartes › Placer ici`
  (le complexe est recréé à la même profondeur sous toi).
- Sous la map, on est « dehors » pour GTA : l'heure de la carte est forcée (nuit) et l'éclairage vient des lumières du plafond.
- Un modèle absent de ta version du jeu est ignoré (la console F8 le liste) ; tous les modèles utilisés font partie du jeu de base
  ou du DLC Cunning Stunts (`stt_prop_stunt_bblock_*`), inclus dans les versions de jeu habituelles de FiveM.

## 3. Pas de fichiers binaires .ymap / .ytyp / .ydr
CodeWalker, Blender + Sollumz et « GTA V Map Agent » demandent Windows et/ou les fichiers de GTA V : impossible à installer ici.
- **Ce n'est pas nécessaire au fonctionnement** : les cartes sont construites dans l'instance de la partie (c'est même préférable :
  un .ymap serait visible par tous les joueurs RP, partout, tout le temps).
- Un export **XML CodeWalker** est fourni (`maps/<id>/<id>.ymap.xml`, sol supposé plat à la hauteur de l'ancre) si tu veux un jour une
  version « streamée » : CodeWalker › Importer XML › Enregistrer en .ymap. Il n'a pas pu être ouvert dans CodeWalker ici.
- Aucun MLO, YTYP ou YDR n'a été créé : les cartes n'utilisent que des objets existants (aucun modèle personnalisé).

## 4. Limites techniques de FiveM / GTA
- **Murs et tirs** : le serveur ne connaît pas la géométrie du monde. Il vérifie distance, trajectoire, cadence, chargeur et portée,
  mais un client modifié pourrait tirer à travers un mur. Les impacts impossibles sont journalisés (sécurité).
- **IA des zombies** : déplacement par la navigation de GTA. Les objets de la carte sont locaux : le client qui contrôle un zombie les
  connaît, mais un zombie peut parfois buter contre un mur. Un zombie coincé 25 s est automatiquement replacé.
- **Animations** : les noms de dictionnaires d'animation (mêlée, attaque de zombie, boisson) sont ceux du jeu de base ; s'ils manquaient,
  l'action fonctionne quand même, sans animation.
- **Voix** : selon ta configuration de pma-voice, un spectateur peut entendre les joueurs proches. Les spectateurs extérieurs ne peuvent de
  toute façon rien faire dans la partie, et les joueurs éliminés n'observent que leurs coéquipiers.
- **Tenue LaserGame** : `Config.Outfits` utilise le composant 9 (gilet) avec des numéros génériques ; selon tes packs de vêtements,
  ajuste les numéros ou mets `enabled = false` (les vêtements RP sont toujours restaurés).
- **Polices** : Exo 2 et Manrope sont chargées depuis Google Fonts (comme les autres interfaces Elyzea) ; sans internet, police de secours.

## 5. Autres frameworks
Les adaptateurs ESX et QBCore sont écrits mais seule la base Elyzea a été simulée. Pour ESX / QBCore, changer la bibliothèque MySQL dans
le fxmanifest (voir `installation.md` §5) et faire la validation en jeu du §1.
