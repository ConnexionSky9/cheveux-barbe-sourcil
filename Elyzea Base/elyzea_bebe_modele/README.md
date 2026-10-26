# elyzea_bebe_modele — bébé 3D, portage, porte-bébés, poussette, soins (V8)

> **Non testé en jeu** (pas de client GTA V / FiveM dans l'environnement de développement). Vérifié hors du jeu :
> fichiers du jeu produits et relus par la bibliothèque de CodeWalker, rendus faits à partir de ces fichiers relus,
> contrôles du modèle et des équipements (`Outils_3D/bebe/build/validation.json`), code serveur réel exécuté avec FiveM simulé
> (`tests/test_portage.py`, `tests/test_poussette.py`), persistance contre une vraie base MariaDB (`tests/test_persistance.py`),
> physique sur terrains simulés (`tests/test_physique.lua`), logique client (`tests/test_client.lua`).
> Rapport complet et tests à faire en jeu : `docs/famille/LIVRAISON_BEBE_V6.md`.
> **V8** (« Prendre contre soi » unique et ouvert à tous, bébé attaché au pousseur, frein sans envol, besoins, biberon, couche,
> vêtements portés) : `docs/famille/LIVRAISON_V8.md` (`tests/test_soins.py` 25/25).

Sources et fabrication des modèles : `Outils_3D/bebe/README_BEBE.md` (chaîne complète : `Outils_3D/bebe/construire.sh`).

## Installation
1. Dossier `elyzea_bebe_modele` dans `Elyzea Base` (remplacer l'ancien dossier **en entier**, `stream/` compris) ; `server.cfg` : `ensure elyzea_bebe_modele`
   (après `elyzea_core`).
2. **OneSync obligatoire** : bébés, porte-bébés et poussettes sont des objets réseau créés par le serveur.
3. Tables `rp_bebes` et `rp_poussettes` créées automatiquement au démarrage (aucune table existante modifiée).
4. Objets d'inventaire : `porte_bebe_ventral`, `porte_bebe_dorsal`, `poussette` (préréglage de PNJ « Puériculture », ou `/giveitem`).
5. Console au démarrage : `Prêt : N fichiers de modèle présents.` puis `Persistance : x poussette(s), y bébé(s) restauré(s).`

## Utilisation (menu ALT, aucun droit d'administration)
| Action | Comment |
|---|---|
| Prendre un bébé (posé ou dans une poussette garée) | **ALT** sur le bébé › *Prendre · Dans les bras / Contre moi / Porte-bébé ventral / Porte-bébé dorsal* (geste natif pour se pencher) |
| Changer de prise | **ALT** sur le bébé porté › *Prise : …* (`/bebe_mode bras\|face\|ventral\|dorsal`) |
| Poser | **ALT** › *Poser allongé / assis* (`/bebe_poser allonge\|assis`) |
| Endormir / réveiller (paupières fermées, visible par tous, enregistré) | **ALT** › *Endormir / réveiller* (`/bebe_dormir`) |
| Confier le bébé à quelqu'un (parents seulement) | `/bebe_confier [id joueur]` (jusqu'au redémarrage) |
| Équiper / retirer un porte-bébé | **utiliser l'objet** (un seul à la fois ; impossible de le retirer avec le bébé dedans) |
| Sortir la poussette | **utiliser l'objet** `poussette` : elle apparaît devant soi, **frein serré** |
| Pousser | **ALT** sur la poussette › *Pousser* (aussi pour **rattraper** une poussette qui roule) |
| Garer / lâcher | **ALT** › *Garer (frein serré)* ou *Lâcher (sans frein)* (`/poussette garer\|lacher`) |
| Frein | **ALT** sur une poussette garée › *Serrer / Desserrer le frein* (desserré dans une pente : elle part) |
| Relever une poussette renversée | **ALT** › *Relever la poussette* |
| Installer / sortir le bébé | **ALT** sur le bébé porté › *Installer dans la poussette* ; **ALT** sur la poussette › *Sortir le bébé · …* |
| Ranger la poussette | **ALT** › *Ranger* (garée ou renversée, vide ; propriétaire ou staff) |
| Coloris | `/coloris_porte_bebe gris\|marine\|sauge` · `/coloris_poussette graphite\|sable` |

## États
Bébé (un seul à la fois, décidé par le serveur sous verrou) : `pose` · `porte` (`bras`, `face`, `ventral`, `dorsal`) · `poussette` ·
`garde` (« avec » un personnage déconnecté : aucune entité, revient à ses pieds à sa connexion).
Poussette : `garee` (frein serré ou non) · `poussee` · `libre` (roule, calculée par un client proche) · `renversee`.

| Événement | Ce qui se passe |
|---|---|
| Mort / coma du porteur | bébé reposé allongé au sol |
| Déconnexion / changement de personnage du porteur | bébé **enregistré** : gardé avec ce personnage ; bébé de test : posé au sol |
| Mort / déconnexion du pousseur | poussette garée sur place, bébé dedans |
| Poussette qui roule et choc rapide, dévers trop fort, chute d'un trottoir | renversée ; **le bébé est posé au sol à côté**, jamais perdu |
| Joueur qui calcule le roulement déconnecté / silencieux 90 s | poussette garée à la dernière position connue du serveur |
| Redémarrage (serveur ou ressource) | poussettes remises garées (frein serré) ; bébés remis posés, dans leur poussette, ou « avec » leur porteur |
| Poussette **vide** abandonnée | rangée après 20 min (réglable) |

## Poussette : physique (choix technique)
Physique **simulée par script** (`shared/physique.lua`), pas le moteur physique de GTA : un objet ajouté n'a pas de réglage de
masse / frottement ajustable sans le jeu, et un objet rigide glisse au lieu de rouler. La poussette roule dans l'axe de ses roues,
accélère dans les pentes, freine par résistance au roulement, reste immobile frein serré (jusqu'à ≈ 23 %), tourne vers le bas de
la pente (roues avant pivotantes), s'arrête aux obstacles (murs, véhicules, personnages, objets), se renverse sur un choc rapide.
Le calcul est fait par le joueur le plus proche (comme les véhicules dans FiveM) ; tout le monde voit le mouvement ; le serveur
vérifie la position finale. Pendant la poussée, la poussette s'incline selon le sol sous ses essieux. Roues : objets **locaux**
qui tournent selon le déplacement (aucun coût réseau).

## Réglages
- `config.lua` : prises (`Config.Portage.modes`), gestes, porte-bébés, poussette et `physique`, persistance.
- **Menu admin existant** (F10 › Autres › **Famille**, permission `famille_manage`) : porte-bébés, poussette, course, abandon, journal,
  réservation aux parents, garde à la déconnexion, physique et ses paramètres, roues, coloris par défaut, **décalages de chaque prise**
  (cm, degrés), **diagnostic** des bébés / poussettes. Enregistrés en base (`rp_famille_reglages`), réappliqués au démarrage.

## Commandes staff (ACE `command.<nom>`)
`/bebe_creer …` (bébé de test, non enregistré) · `/bebe_supprimer [tous] [definitif]` (un bébé né en jeu n'est supprimé qu'avec
`definitif`) · `/bebe_ajuster …` · `/bebe_diag` · aperçus `/bebe_test`, `/bebe_galerie`, `/bebe_retirer`.

## Exports
Serveur : `CreerBebe(apparence, coords, cap, { responsables, bucket, pose, persistant, grossesse, rang, nom })` → id (une naissance
grossesse + rang déjà enregistrée renvoie le même bébé) · `SupprimerBebe(id)` · `EtatBebe(id)` · `BebePortePar(src)` ·
`AppliquerReglages(valeurs)` · `Diagnostic()`.

## Limites connues
- Aucune animation de bercement n'existe dans GTA ; prises avec animations natives (porter à deux bras, bras croisés).
  Une animation sur mesure demande les fichiers du squelette des personnages (`mp_f_freemode_01.yft`, `mp_m_freemode_01.yft`).
- Positions (bébé, porte-bébés, poussette, roues, sens de rotation des roues et du roulis) calculées sur un mannequin : à vérifier en jeu,
  réglables dans le menu admin (décalages) et `/bebe_ajuster`.
- Physique simulée : la poussette qui roule s'arrête devant les joueurs, elle ne les pousse pas.
- Collision (V7) : le modèle de la poussette contient une collision en 4 boîtes ; solide garée, renversée ou en roulement.
  Pendant la poussée (attachée au personnage), sa collision est coupée. V8 : collision aussi coupée pendant le roulement libre,
  poussette garée figée chez chaque joueur (correction de l'envol). Non vérifié en jeu : `docs/famille/LIVRAISON_V8.md`.

## Portage dans les bras (audit V9)
- Avant, le bébé était attaché au repère du personnage, pas au buste. Quand le buste bougeait (marche, animation), il ne suivait pas, d'où l'effet « flotte » ou « traverse ».
- `client/suivi.lua` l'attache à l'os du buste (SKEL_Spine3), à la même place que la position validée :
  - la conversion est mesurée une fois en jeu avec un objet invisible ;
  - le résultat est mémorisé (KVP) ;
  - si la mesure échoue, l'ancienne attache est gardée.
- Nouvelle prise **« Bercé dans les bras »** (`/bebe_prendre berce` ou, bébé déjà porté, `/bebe_mode berce`), avec l'émote « teddy » déjà présente sur le serveur.
- Désactivable : `Config.Portage.suiviBuste.actif = false`.
- Poids réalistes des objets de puériculture : `elyzea_inventory/shared/items.lua`.
  - Porte-bébé : 750 g / 950 g.
  - Poussette pliée : 6 kg.
  - Biberon : 280 g.
  - Couche : 30 g.
  - Pyjama : 90 g.
