# Étapes immersives : mini-jeux, scènes et animations (v2.1)

> **État : rien n'a été testé en jeu.**
>
> Ce qui a été vérifié :
> - les 23 parties de mini-jeux ont été jouées de bout en bout dans Chromium par un script, sur la vraie interface ;
> - la simulation serveur passe à 95/95, celle des laboratoires à 91/91 ;
> - la simulation client (nettoyage dans tous les cas) passe à 16/16 ;
> - le contrôle statique des objets passe à 41/41.
>
> Ce qui reste à vérifier en jeu :
> - la position de la chaise et du personnage assis ;
> - la position des objets ;
> - l'existence des modèles et animations, avec la commande `/drogues_verif`.

## Principe

À chaque étape de fabrication, la **barre de progression est remplacée par un vrai mini-jeu**, avec une **scène** en jeu :
- le personnage se place devant le poste (ou s'assoit sur la chaise) ;
- il joue une animation adaptée ;
- il tient un objet et des accessoires sont posés sur la table.

**Ce qui ne change pas** :
- les quantités, recettes, prix et l'expérience des labos ;
- la **durée de la recette**, qui reste le minimum exigé par le serveur. Si le mini-jeu est fini plus tôt, une courte « Finition… » complète le temps.

**Réussite et échec** :
- **Mini-jeu raté** (trop d'erreurs ou temps écoulé) : **rien n'est retiré**. Les ingrédients restent, le poste est libéré et le joueur recommence.
- **Le serveur valide le résultat** et refuse un résultat incomplet, falsifié, trop rapide ou venant d'un autre mini-jeu. Il vérifie aussi, comme avant, le jeton, la durée, la distance, les ingrédients et la place dans l'inventaire.
- **Limite honnête** : un tricheur équipé d'un exécuteur peut toujours imiter un mini-jeu réussi. Il reste quand même bloqué par la durée, la distance et les ingrédients, comme avec l'ancienne barre.

**Récolte** (champs placés avec l'admin_menu, pots de culture) : **pas de mini-jeu**, à ta demande. La barre de progression reste, avec une animation adaptée et un objet tenu :

| Plante | Animation | Objet tenu |
|---|---|---|
| Cannabis | debout, on inspecte et coupe les têtes | ciseaux |
| Pot | accroupi | ciseaux |
| Coca | jardinage | — |
| Champignons | se baisser pour ramasser | — |
| Fûts chimiques | à genoux | — |

## Les étapes, drogue par drogue

| Drogue | Étape | Mini-jeu | Scène |
|---|---|---|---|
| 🌿 Cannabis | Effeuiller (table de manucure) | **Fleur de cannabis réaliste** (calices, pistils, trichomes, violette pour la Purple Haze) : attraper chaque petite feuille et la **tirer pour la décrocher**. Pincer la fleur ou tirer de travers = erreur. | **Assis sur la chaise** devant la table, tête de weed dans la main, tas de têtes, feuilles, ciseaux et seau sur la table |
| | **Sécher** (nouveau séchoir) | Suspendre chaque tête à un crochet, puis régler la ventilation | Debout, ventilateur et seau |
| | Préparer | Moulin : tourner sans aller trop vite | Debout à la table |
| | Rouler | Répartir, rouler sous tension, coller | Joint en main |
| | Ensacher | Pesée au gramme près (3,5 g) | Balance, sachets, brique |
| ❄️ Cocaïne | Broyer | Manivelle | Machine |
| | Pâte | Dosage : feuilles broyées puis solvant, jusqu'au trait | Versement, flacon en main |
| | Ensacher | Pesée (1 g) | Cuillère en main |
| | Raffiner | Chauffe dans la zone | Bouteilles et gaz |
| | Finition | Tracer les lignes à la carte | Bloc de coupe |
| 💎 Crack | Mélanger | Dosage : pâte puis bicarbonate | Versement |
| | Chauffer | Réchaud | Cuisson |
| | Sécher | Étaler sur un plateau, régler la lampe | Plateau |
| | Découper | Couteau le long des traits | Couteau en main |
| | Ensacher | Trier les bons cailloux | Emballage |
| ⚗️ Méth | Mélange | Dosage : produits chimiques puis acide | Ammoniaque, acide |
| | Cuire | Réacteur (bouillonnements) | Versement |
| | Cristalliser | Frapper les fissures au marteau | Marteau en main, plateau |
| | Ensacher | Pesée des cristaux | Balance |
| 💊 Ecstasy | Base | Dosage : huile puis solvant | Flacons |
| | Synthèse | Chauffe du réacteur | Gaz |
| | Presse | Taper au bon moment, à la couleur du comprimé | Presse |
| | Blister | Comprimés intacts en cases, cassés au rebut | Emballage |
| 💉 Opiacés | Macérer | Dosage : eau puis résine | Seau |
| | Filtrer | Secouer le filtre sans renverser | Mouvement de shaker |
| | Poudre | Mortier | Table |
| | Injectable | Tirer le piston, chasser les bulles | Seringue en main |
| | Comprimés / seringues | Blister / étui | Emballage |
| 🐴 Kétamine | Évaporer | Évaporateur | Gaz |
| | Sécher | Plateau + lampe | Plateau |
| | Écraser | Carte le long des traits | Carte en main |
| | Ensacher | Pesée (0,5 g) | Balance |
| 🍄 Champignons | Trier | Tapis roulant : bons au panier, pourris au rebut | Assiette, seau |
| | Sécher | Suspendre puis ventiler | Plateau |
| | Ensacher | Pesée (2 g) | Balance |

Les **laboratoires** (`elyzea_labs`) utilisent exactement les mêmes mini-jeux, scènes et décors pour leurs équipements.

## Étape « séchage » du cannabis

- La manucure donne des **têtes fraîches**. Le séchoir les transforme **1 pour 1** en têtes séchées, les têtes habituelles. Les quantités ne changent donc pas.
- Les têtes déjà en inventaire restent valables.
- **Désactivable par variété** : admin_menu › Gestion des drogues › Culture › « Étape séchage active ». Désactivée, la manucure redonne directement les têtes, comme avant.
- **Nouveau poste** à placer : « Séchoir à cannabis » (`weed_dry`).
- **4 nouveaux objets** : `weed_bud_wet`, `weed_bud_wet_ww`, `weed_bud_wet_ph`, `weed_bud_wet_custom`. Ils sont déjà ajoutés dans `elyzea_inventory/shared/items.lua`.

## Assise (v2.1.1)

- Le personnage s'assoit avec le **scénario d'assise de GTA** (« assis à une table », mains sur le plateau), placé sur l'assise de la chaise. Il a les **pieds au sol**, le fessier sur la chaise et fait face à la table.
- L'ancienne méthode jouait une animation assise sans chaise sous le personnage, et le corps flottait.
- **Directement assis** : pas de marche jusqu'à la chaise ni de geste pour s'asseoir. Le personnage est placé sur l'assise dès le début de l'étape.
- **Se relever** : directement debout devant la chaise. Il n'est jamais coincé.
- **Garde-fou** : si une animation soulève le personnage (pieds à plus de 20 cm du sol), elle est arrêtée et une animation de secours prend le relais. C'était le cas au séchoir et au conditionnement, qui utilisent maintenant des animations vérifiées.
- **Postes avec chaise** :
  - postes de drogue : table de manucure et table de roulage ;
  - laboratoires : table de manucure.
  On y travaille assis (effeuiller, rouler, préparer).
- **Réglage** : si la hauteur ou la position n'est pas parfaite avec tes modèles de chaise, utilise `/drogues_assise`. Le réglage est enregistré pour toutes les tables de ce type.

## Décor permanent et chaise

Chaque poste reçoit ses accessoires, visibles de tous :
- leur hauteur est calculée avec les dimensions réelles des modèles, donc ils ne flottent pas ;
- la table de manucure reçoit en plus une **chaise**, et ALT sur la chaise ouvre le poste.

## Commandes

| Commande | Pour qui | Effet |
|---|---|---|
| `/drogues_verif` | Tout le monde | Liste en F8 les modèles et animations absents chez toi. Un modèle absent est remplacé par le suivant de la liste ; une animation absente est remplacée par son repli. |
| `/drogues_assise` | Staff `drugs_manage` | Près d'une table avec chaise : le personnage s'assoit (scénario d'assise du jeu). Les flèches le déplacent, Page ↑/↓ règle la hauteur, Q/E la rotation, **Entrée enregistre** pour toutes les tables de ce type, Retour annule. À faire une fois si le personnage n'est pas parfaitement assis. |

## Réglages (`config/minigames.lua`)

| Réglage | Effet |
|---|---|
| `Config.Minigames.enabled = false` | Retour à l'ancienne barre de progression partout |
| `walkToStation` | Le personnage se place devant le poste |
| `limitFactor` | Temps maximum des mini-jeux |
| `networkProps` | Objets temporaires visibles des autres. Le serveur les supprime si le joueur se déconnecte, et n'accepte que les objets du joueur, de modèles de scène connus. |
| `Config.Steps` | Mini-jeu, difficulté (objectifs, erreurs tolérées), pose, animation et objets de chaque étape |
| `Config.Decor` | Accessoires de chaque poste |
| `Config.HarvestScenes` | Animations de récolte |

## Sécurité et nettoyage

Quoi qu'il arrive, le curseur est rendu, le personnage est débloqué et relevé, et les objets temporaires sont supprimés. Cela couvre :
- Échap ;
- un échec ;
- la mort ou une chute ;
- l'entrée dans un véhicule ;
- un délai dépassé ;
- une erreur de script ;
- l'arrêt de la ressource ;
- la sortie du laboratoire.

**Un joueur par poste** (verrou du serveur, comme avant). Les autres joueurs voient :
- l'animation du joueur ;
- le décor du poste ;
- les objets temporaires.

## Tests

```
python3 tests/run_server_sim.py   # 95/95 (dont 22 sur les mini-jeux, le séchage, l'assise, les objets de scène)
python3 tests/run_client_sim.py   # 16/16 (nettoyage dans tous les cas, replis, refus d'une 2e étape)
python3 tests/static_check.py     # 41/41
../elyzea_labs/tests/run_lab_sim.py  # 91/91
```

**À tester en jeu** :
1. Lancer `/drogues_verif`.
2. Faire chaque étape une fois.
3. Régler l'assise avec `/drogues_assise` si besoin.
4. Vérifier qu'un 2e joueur voit la scène.
5. Se déconnecter en pleine étape et vérifier que les objets disparaissent.
