# Slows : analyse des animations réelles (19 octobre 2026)

## Méthode

Au lieu de se fier aux noms, les fichiers d'animation eux-mêmes (`.ycd` de rpemotes-reborn, version du 24 septembre 2026)
ont été décodés avec `tests/ycd_reader.py`, un lecteur porté du code source de CodeWalker. Pour chaque slow :
1. lecture des pistes de position et de rotation des 128 os de chaque personnage ;
2. reconstruction du squelette (`tests/pose.py`) : bassin, colonne, tête, bras, mains, jambes, pieds ;
3. application de la position du partenaire **exactement comme en jeu** : attache à l'os racine du meneur
   (`GetPedBoneIndex(meneur, 0)`), puis décalage et rotation de rpemotes ;
4. mesures (`tests/slow_check.py`) : angle entre les deux torses (déduit des épaules), distance entre poitrines et têtes,
   contact le plus proche, mains de chacun sur l'autre, mouvement sur toute la boucle.

Le modèle a été vérifié de deux façons : le squelette reconstruit a des proportions humaines (tête 64 cm au-dessus du
bassin, pieds 89 cm en dessous, épaules gauche / droite du bon côté), et le décodeur lit bien le mouvement d'une danse
connue (« wave » : déplacements d'environ 1,5 m).

**Limite** : c'est une reconstruction du squelette, pas le rendu du jeu (ni vêtements, ni peau). Elle ne remplace pas
le contrôle visuel à deux en jeu, qui n'a pas pu être fait ici.

## Résultats

| Animation (rpemotes) | Utilisée par | Angle entre torses | Poitrines | Mouvement dans le fichier | Verdict |
|---|---|---|---|---|---|
| Hold Me 2 (`mx_couple5_2_a/b`) | Slow enlacé face à face, Slow tournant, Slow puis baiser | 167° | 0,36 m | **aucun** (pose tenue) | Face à face, enlacés |
| Baiser (`chocoholic@couple13/14`) | Baiser, Slow puis baiser | 165° | 0,40 m | **aucun** (pose tenue) | Face à face, enlacés |
| Hold Me 1 (`mx_couple5_1_a/b`) | *Enlacés par derrière* | −5° | 0,20 m | aucun | **Même direction** → retirée des danses lentes |
| Hold Me 3 (`mx_couple5_3_a/b`) | — | 10° | 0,19 m | aucun | Même direction |
| Mariés 2 (`EnchantedBrwny@wedding2a/b`) | *Danse des mariés* | −167° | 0,62 m, têtes 1,16 m | pose de 3 images | Pose éloignée → retirée |
| Mariés 1 (`EnchantedBrwny@wedding1a/b`) | *Pose des mariés* | −122° | 1,05 m | pose de 3 images | De biais → retirée |
| Étreinte (`misscarsteal2chad_goodbye`) | Étreinte romantique | non mesurée | | | Fichier du jeu de base, non accessible ici |

Schémas reconstruits (bleu = meneur, rouge = partenaire) : `images/slow_hold_me_2.png` (face à face),
`images/slow_hold_me_1.png` (même direction), `images/slow_baiser.png`, `images/slow_maries_2.png`.

Les trois animations retirées restent disponibles comme poses dans « Partagées ».

## Ce que cela veut dire

- Le positionnement du moteur était déjà identique à celui de rpemotes (même os, même décalage, même rotation). Avec les
  fichiers de rpemotes-reborn, « Slow enlacé face à face » place bien les deux personnages face à face et enlacés.
- **Aucune** animation de couple de rpemotes ne bouge : les 486 animations des 388 fichiers ont été analysées ; les
  couples sont tous des poses figées. Il n'existe donc, sur ton serveur, **aucun vrai slow** (balancement, transfert de
  poids, pas coordonnés). Le jeu de base n'en contient pas non plus.
- « Slow tournant » ajoute une rotation lente du couple par le script ; c'est le seul mouvement disponible sans nouvelles
  animations.

## Si en jeu ce n'est pas face à face

Deux causes possibles, à départager avec `/danse_mesure` (pendant la danse, chacun de son côté) :
1. **Ancienne version installée** (par exemple `rp_animations`, qui plaçait les partenaires côte à côte). La commande
   n'existe que dans la version actuelle : si elle est inconnue, la ressource n'est pas à jour.
2. **Fichiers rpemotes différents** sur ton serveur (nox-rpemotes est plus ancien que rpemotes-reborn) : la mesure donnera
   alors un angle loin de 180°. Il faudra me transmettre `mx_couple5_2_a.ycd` et `mx_couple5_2_b.ycd` de ton dossier
   rpemotes (`stream/`), que j'analyserai de la même façon.

## Pour un vrai slow en couple

Il faut des animations de couple **qui bougent**, enregistrées ensemble pour deux personnages. Aucun pack libre de ce type
n'a été trouvé (les « Couple Pose Packs » de gta5-mods sont des poses figées ; les packs payants consultés ne précisent
pas de slow). Dès que tu disposes d'un pack (fichiers `.ycd` et noms des clips), il s'intègre ainsi :
1. analyse des fichiers avec `tests/slow_check.py` (orientation, distance, mouvement) avant toute installation ;
2. copie des `.ycd` dans `elyzea_animations/stream/` ;
3. une fiche dans `danses/catalog.lua` avec la position calculée ;
4. contrôle à deux en jeu avec `/danse_mesure`, puis `/danse_valider`.
