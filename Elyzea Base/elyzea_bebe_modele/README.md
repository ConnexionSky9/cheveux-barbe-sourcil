# elyzea_bebe_modele — bébé 3D, portage visible par tous

> **Non testé en jeu.** Vérifié hors du jeu : fichiers du jeu produits et relus par la bibliothèque de CodeWalker (86/86),
> contrôles du modèle (20/20), code serveur du portage exécuté avec FiveM simulé (31/31 contrôles), syntaxe Lua.
> Les tests à deux joueurs ci-dessous restent à faire sur ton serveur.

Sources et fabrication du modèle : `Outils_3D/bebe/README_BEBE.md`.

## Installation
1. Dossier `elyzea_bebe_modele` dans `Elyzea Base` ; `server.cfg` : `ensure elyzea_bebe_modele`.
2. **OneSync obligatoire** (standard avec txAdmin) : le bébé est un objet réseau créé par le serveur.
3. Console : `[elyzea_bebe_modele] Prêt : 86 fichiers de modèle présents.`

## Utilisation
| Action | Comment |
|---|---|
| Prendre un bébé posé | **ALT** près du bébé › *Prendre · Dans les bras / Face à moi / Porte-bébé* (ou `/bebe_prendre [bras\|face\|portebebe]`) |
| Changer de prise | **ALT** (le bébé porté est proposé) › *Prise : …* (ou `/bebe_mode …`) |
| Poser | **ALT** › *Poser allongé* / *Poser assis* (ou `/bebe_poser [allonge\|assis]`), 65 cm devant soi, au sol |
| Staff : créer un bébé (visible par tous) | `/bebe_creer [teinte] [yeux] [coiffure\|chauve]` |
| Staff : supprimer | `/bebe_supprimer` (le plus proche) · `/bebe_supprimer tous` |
| Staff : régler la position portée | `/bebe_ajuster x y z rx ry rz` (valeurs à recopier dans `Config.Portage.modes`, affichées en F8) |
| Staff : aperçus locaux (visibles par soi seul) | `/bebe_test`, `/bebe_galerie [pose]`, `/bebe_retirer` |

Teintes `peau1` (claire) … `peau6` (foncée) · yeux `ardoise`, `bleu`, `vert`, `noisette`, `marron` ·
coiffures `duvet_` / `touffe_` + `blond|chatain|brun|noir|roux`, ou `chauve`.

## Fonctionnement réseau
- Un bébé existe **une seule fois**, sur le serveur. Ses 3 pièces (corps, yeux, cheveux) sont des objets réseau créés par le serveur :
  tous les joueurs proches voient les mêmes objets (pas de copie par joueur).
- **Posé** : les 3 pièces sont figées au même endroit, avec le même angle (elles partagent la même origine) ; aucun joueur n'est nécessaire.
- **Porté** : le porteur prend le contrôle des pièces et les attache à son personnage ; FiveM synchronise l'attache pour tout le monde.
  Le serveur vérifie toutes les 2 s que le bébé est bien attaché au bon personnage ; sinon il redemande l'attache (3 essais), puis repose le bébé.
- **Un seul porteur** : un bébé porté ne peut pas être pris par quelqu'un d'autre ; demandes répétées ignorées.
- **Mort, coma (EMS), déconnexion** : le bébé est reposé allongé à l'endroit où était le porteur (hauteur du sol envoyée régulièrement par le porteur).
- **Arrêt / redémarrage de la ressource** : toutes les pièces sont supprimées.

## Combat pendant le portage
- Le porteur **ne peut pas frapper** : coups de poing, de pied, coups de crosse et armes blanches sont bloqués chez lui,
  **et** le serveur annule les dégâts de mêlée qu'il enverrait (protection contre un client modifié, événement `weaponDamageEvent`).
- Le porteur **reste vulnérable** : aucune invincibilité, aucune réduction de dégâts. Les coups qu'il reçoit ne sont jamais touchés.
- Prises « mains occupées » (bras, face à moi) : l'arme en main est rangée tant que l'on porte (les deux mains tiennent le bébé).
  Porte-bébé : mains libres, seules les attaques de mêlée sont bloquées (pas de restriction ajoutée sur les armes à feu).
- Dès que le bébé est posé (ou lâché à la mort / déconnexion), plus rien n'est bloqué : le blocage est recalculé à chaque image
  à partir de l'état envoyé par le serveur ; rien ne reste coincé.

## Exports
Serveur : `CreerBebe(apparence, coords, cap, { responsables, bucket, pose })` → id · `SupprimerBebe(id)` · `EtatBebe(id)` · `BebePortePar(src)`.
Client (aperçus locaux) : `Creer`, `Supprimer`, `Poses`. Menu ALT : `AltTarget`, `AltNearby`, `AltOptions`, `AltSelect`.

## Tests à faire en jeu (deux joueurs, A et B)
1. `/bebe_creer` : A et B voient le même bébé au sol.
2. A le prend (ALT) : B le voit dans les bras de A ; A marche, court : le bébé suit.
3. A frappe B : aucun coup ne part. B frappe A : dégâts normaux.
4. A pose le bébé : B le voit au bon endroit ; A peut de nouveau frapper.
5. A reprend le bébé puis se déconnecte (ou meurt) : le bébé est au sol, une seule fois ; A n'a plus rien de bloqué.
6. Prises bras / face / porte-bébé : régler les positions avec `/bebe_ajuster` si le bébé traverse le personnage.

## Limites connues
- Positions des prises : valeurs de départ, à ajuster une fois en jeu (`/bebe_ajuster`).
- Animation de portage : animation native GTA (porter un carton), la plus proche disponible sans fichier d'animation sur mesure.
- Les bébés n'existent pas encore « tout seuls » : ils sont créés par le staff (`/bebe_creer`) ou par l'export `CreerBebe`,
  que le futur module de naissance utilisera. Ils ne sont pas sauvegardés en base pour l'instant (ce sera le rôle du module enfants).
