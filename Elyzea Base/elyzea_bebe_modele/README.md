# elyzea_bebe_modele — bébé 3D, portage, porte-bébés, poussette (V4)

> **Non testé en jeu** (pas de client GTA V / FiveM dans l'environnement de développement). Vérifié hors du jeu :
> fichiers du jeu produits et relus par la bibliothèque de CodeWalker, rendus faits à partir de ces fichiers relus,
> contrôles du modèle et des équipements (`Outils_3D/bebe/build/validation.json`), code serveur exécuté avec FiveM simulé
> (`python3 tests/test_portage.py`), syntaxe Lua. Les tests à deux joueurs ci-dessous restent à faire sur ton serveur.

Sources et fabrication des modèles : `Outils_3D/bebe/README_BEBE.md` · rapport complet : `docs/famille/LIVRAISON_V4.md`.

## Installation
1. Dossier `elyzea_bebe_modele` dans `Elyzea Base` (remplacer l'ancien dossier **en entier**, `stream/` compris) ; `server.cfg` : `ensure elyzea_bebe_modele`.
2. **OneSync obligatoire** (standard avec txAdmin) : bébés, porte-bébés et poussettes sont des objets réseau créés par le serveur.
3. Objets d'inventaire (dans `elyzea_inventory/shared/items.lua`, avec image) : `porte_bebe_ventral`, `porte_bebe_dorsal`, `poussette`.
   Vendus par le nouveau préréglage de PNJ **« Puériculture »** de l'éditeur (F10 › Éditeur › PNJ), ou `/giveitem`.
4. Console au démarrage : `[elyzea_bebe_modele] Prêt : N fichiers de modèle présents.`

## Utilisation (interactions normales : menu ALT, aucun droit d'administration)
| Action | Comment |
|---|---|
| Prendre un bébé (posé ou dans une poussette garée) | **ALT** sur le bébé › *Prendre · Dans les bras / Face à moi / Porte-bébé ventral / Porte-bébé dorsal* |
| Changer de prise | **ALT** sur le bébé porté › *Prise : …* (`/bebe_mode bras\|face\|ventral\|dorsal`) |
| Poser | **ALT** › *Poser allongé / assis* (`/bebe_poser allonge\|assis`) |
| Endormir / réveiller (paupières fermées, visible par tous) | **ALT** › *Endormir / réveiller* (`/bebe_dormir`) |
| Équiper / retirer un porte-bébé | **utiliser l'objet** dans l'inventaire (un seul porte-bébé à la fois ; impossible de le retirer avec le bébé dedans) |
| Sortir la poussette | **utiliser l'objet** `poussette` : elle apparaît au sol devant soi (une poussette par personnage) |
| Pousser / garer | **ALT** sur la poussette › *Pousser* / *Garer* (`/poussette`) |
| Installer le bébé dans la poussette | **ALT** sur le bébé porté › *Installer dans la poussette*, ou ALT sur la poussette |
| Sortir le bébé de la poussette | **ALT** sur la poussette › *Sortir le bébé · …* (ou ALT sur le bébé) |
| Ranger la poussette | **ALT** › *Ranger* (garée, vide, et seulement par son propriétaire ou le staff) |
| Coloris | `/coloris_porte_bebe gris\|marine\|sauge` · `/coloris_poussette graphite\|sable` (mémorisés par personnage) |

## États du bébé (un seul à la fois)
`pose` (au sol) · `porte` (prise `bras`, `face`, `ventral`, `dorsal`) · `poussette` (garée : figé dans la nacelle ; poussée : attaché au pousseur).
Chaque changement est décidé par le serveur, sous verrou : état actuel vérifié, conditions vérifiées (distance, équipement,
mains libres, joueur debout, hors véhicule, poussette libre…), anciennes pièces supprimées, nouvelles créées, état mis à jour,
attache demandée au bon joueur puis vérifiée toutes les 2 s (3 essais, sinon repli sûr). Les doubles clics et les demandes
simultanées de deux joueurs sont refusés pendant un changement : jamais deux bébés, jamais de bébé perdu.

| Événement | Ce qui se passe |
|---|---|
| Mort / coma du porteur | bébé reposé allongé au sol à sa place |
| Mort / coma du pousseur | poussette garée sur place (le bébé reste dedans) |
| Déconnexion ou changement de personnage | idem, et le porte-bébé est retiré |
| Poussette **vide** abandonnée (propriétaire parti ou à plus de 60 m) | rangée après 20 min (réglable) ; une poussette **avec** un bébé n'est jamais supprimée |
| Arrêt / redémarrage de la ressource | toutes les entités sont supprimées (les bébés ne sont pas encore enregistrés en base : module « enfants » à venir) |

## Combat
- Le porteur (toutes prises) et le pousseur **ne peuvent pas frapper** : contrôles bloqués chez eux **et** dégâts de mêlée annulés par le serveur.
- Ils **restent vulnérables** : aucune invincibilité, aucune réduction de dégâts. Les règles de combat du serveur ne sont pas modifiées.
- Prises « mains occupées » (bras, face) et poussette : l'arme en main est rangée. Porte-bébés : mains libres.

## Poussette (choix techniques)
- C'est un **objet**, pas un véhicule. Poussée : attachée devant le personnage, qui joue l'animation native du chariot
  (`amb@prop_human_bum_shopping_cart@male@base`). Garée : figée au sol, à l'endroit et dans l'angle choisis.
- **Pas de course** en poussant (réglable), **arrêt devant un obstacle** (rayon devant la poussette : on ne peut plus avancer),
  **hauteur réajustée** au relief (pentes, trottoirs, jusqu'à 45 cm) pour que les roues ne s'enfoncent pas.
- Garée, la poussette n'a pas de collision (comme le bébé) : on peut la traverser à pied.

## Réglages
- `config.lua` : positions des prises (`Config.Portage.modes`), des porte-bébés (`Config.Equipements`), de la poussette
  (`Config.Poussette`), décalage pour les personnages féminins (`Config.Portage.morphologies`). Les valeurs par défaut viennent de
  `shared/modeles.lua` (positions calculées par la chaîne 3D).
- **Menu admin existant** (F10 › Autres › **Famille** › section « Bébés et équipements », permission `famille_manage`) :
  activer / désactiver le porte-bébé ventral, le dorsal, la poussette ; course interdite ; délai d'abandon ; journal de diagnostic.
  Valeurs vérifiées par le serveur, enregistrées en base (table existante `rp_famille_reglages`), réappliquées au démarrage.

## Commandes staff (ACE `command.<nom>`)
`/bebe_creer [teinte] [yeux] [coiffure|chauve] [pyjama|couche]` · `/bebe_supprimer [tous]` (bébé ou poussette vide le plus proche) ·
`/bebe_ajuster x y z rx ry rz` (bébé porté) · `/bebe_ajuster equipement …` · `/bebe_ajuster poussette …` (valeurs à recopier, affichées en F8) ·
`/bebe_diag` (état de tous les bébés, poussettes et porte-bébés) · aperçus locaux `/bebe_test`, `/bebe_galerie`, `/bebe_retirer`.

## Exports
Serveur : `CreerBebe(apparence, coords, cap, { responsables, bucket, pose })` → id (`apparence` = `{ teinte, tenue, yeux, coiffure }`) ·
`SupprimerBebe(id)` · `EtatBebe(id)` · `BebePortePar(src)` · `AppliquerReglages(valeurs)` (appelé par elyzea_famille).
Client : menu ALT `AltTarget`, `AltNearby`, `AltOptions`, `AltSelect` ; aperçus `Creer`, `Supprimer`, `Poses`.

## Tests à faire en jeu (deux joueurs, A et B)
1. `/bebe_creer` : A et B voient le même bébé. A le prend dans les bras : B le voit, A marche et court, le bébé suit.
2. A utilise `porte_bebe_ventral` : B voit le porte-bébé. A › *Prise : Porte-bébé ventral* : le bébé est contre la poitrine de A, dans le panneau.
3. Idem avec `porte_bebe_dorsal` : bébé dans le dos. Vérifier personnage homme **et** femme ; régler avec `/bebe_ajuster` si besoin.
4. A utilise `poussette`, y installe le bébé, la pousse, la gare, reprend le bébé, le remet : B voit tout au même endroit ; jamais deux bébés.
5. A et B cliquent en même temps sur *Pousser* / *Prendre* : un seul réussit.
6. A pousse puis se déconnecte : la poussette reste garée avec le bébé. Poussette vide abandonnée : rangée après le délai.
7. B frappe A pendant le portage : dégâts normaux. A ne peut pas frapper.
8. Menu F10 › Famille : désactiver la poussette, enregistrer, redémarrer le serveur : toujours désactivée.

## Limites connues
- Aucune animation de bercement n'existe dans GTA ; la V4 utilise l'animation native « porter à deux bras » et un bébé posé pour
  épouser cette posture. Une animation sur mesure demande les fichiers du squelette des personnages GTA (voir `docs/famille/AUDIT_V4.md`).
- Porte-bébés ajustés sur un mannequin adulte (approximation d'un personnage GTA) : un léger flottement ou contact est possible
  selon la tenue et la morphologie ; positions réglables en jeu.
- Poussette : objet attaché (pas de physique de roues) ; dans les escaliers raides, elle peut traverser une marche.
- Rendu réel dans GTA (éclairage, transparence des cheveux) non vérifié.
