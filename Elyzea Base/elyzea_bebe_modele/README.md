# elyzea_bebe_modele — modèle 3D du bébé

> **Non testé en jeu.** Les fichiers du jeu ont été produits et relus par la bibliothèque de CodeWalker, la syntaxe Lua est vérifiée,
> mais aucun client GTA V / FiveM n'était disponible pour un essai réel. La procédure ci-dessous sert à ce premier essai.

Ressource « socle » : elle ne contient **que** le modèle et de quoi l'afficher. L'identité des enfants, la grossesse, la crèche, etc.
seront dans la ressource famille, qui appellera les exports ci-dessous. Aucune dépendance (pas même elyzea_core, utilisé seulement pour les notifications s'il est là).

Sources et fabrication du modèle : `Outils_3D/bebe/README_BEBE.md`.

## Installation
1. Le dossier `elyzea_bebe_modele` est dans `Elyzea Base`.
2. `server.cfg`, section SCRIPTS : `ensure elyzea_bebe_modele` (ajouté, avant les futures ressources famille).
3. Console au démarrage : `[elyzea_bebe_modele] Prêt : 86 fichiers de modèle présents.`

## Procédure de test (staff, permission ACE `command.bebe_test`… déjà incluse dans `group.admin`)
| Commande | Résultat attendu |
|---|---|
| `/bebe_test` | bébé « porté dans les bras » attaché devant toi, animation bras tendus |
| `/bebe_test allonge peau5 marron touffe_noir` | bébé allongé au sol devant toi, peau foncée, yeux marron, cheveux noirs |
| `/bebe_test assis peau1 bleu chauve` | bébé assis, sans cheveux |
| `/bebe_test ventral` | bébé contre ta poitrine (porte-bébé) |
| `/bebe_galerie allonge` | les 6 teintes côte à côte |
| `/bebe_ajuster 0.1 0.35 0.2 0 0 90` | déplace le bébé porté ; les valeurs à recopier dans `config.lua` s'affichent dans la console F8 |
| `/bebe_retirer` | supprime les bébés de test |

Points à regarder : taille (≈ 50 cm), yeux et cheveux bien en place sur la tête, cheveux non opaques (tramés),
reliefs du visage dans le bon sens, pas de face invisible, couleurs cohérentes de jour et de nuit.

Poses : `allonge`, `porte`, `assis`, `ventral` · teintes : `peau1` (claire) … `peau6` (foncée) ·
yeux : `ardoise`, `bleu`, `vert`, `noisette`, `marron` · coiffures : `duvet_` ou `touffe_` + `blond|chatain|brun|noir|roux`, ou `chauve`.

## Exports client
```lua
local b = exports.elyzea_bebe_modele:Creer('allonge', { teinte = 'peau3', yeux = 'bleu', coiffure = 'duvet_brun' }, coords, cap, false)
exports.elyzea_bebe_modele:Porter(b, PlayerPedId(), 'porte')      -- ou 'ventral'
exports.elyzea_bebe_modele:Attacher(b, entite, os, vector3(...), vector3(...))
exports.elyzea_bebe_modele:Supprimer(b)
exports.elyzea_bebe_modele:Poses()
```
`reseau = false` (dernier argument de `Creer`) : objets visibles par ce joueur seulement. La ressource famille gérera la synchronisation
(c'est le serveur qui décidera où se trouve l'enfant, pour qu'il ne puisse jamais être à deux endroits).

## Fichiers
`stream/` (générés) : `ely_bebe.ytyp`, `ely_bebe_txd.ytd`, 84 × `ely_bebe_<pose>_<variante>.ydr`. `shared/modeles.lua` est généré : ne pas le modifier à la main.
