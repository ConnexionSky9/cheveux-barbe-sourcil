# Audit avant la V6 (bébé, portage, porte-bébés, poussette) — problèmes identifiés et plan

Sauvegarde : V5 = commit `0278dfb`, étiquette `sauvegarde-v5` (branche `claude/dreamy-ritchie-7vdqzv`), paquet `elyzea_famille_v5.zip`.
Fichiers examinés : `elyzea_bebe_modele` (serveur `server/bebes.lua` 1 060 lignes, `server/main.lua`, `client/portage.lua`,
`client/main.lua`, `config.lua`, `shared/modeles.lua`, `stream/` 144 fichiers, tests), chaîne 3D `Outils_3D/bebe/scripts`
(`sdf_baby.py`, `generate_baby.py`, `equipements.py`, `export_gta.py`…), `elyzea_famille` (naissance V5, réglages),
liste des 20 179 dictionnaires d'animations de GTA V.

## 1. Inventaire
| Élément | Contenu | État |
|---|---|---|
| Modèle du bébé | maillage généré (champs de distance + Blender), 4 poses (allongé, assis, porté, ventral), 6 teintes × 2 tenues, 5 yeux, 10 coiffures, paupières fermées (endormi) ; 3 objets réseau par bébé (corps, yeux, cheveux) | fichiers relus par CodeWalker ; **jamais vu en jeu** |
| Portage | bras, face (anim `anim@heists@box_carry@`), ventral, dorsal (porte-bébés équipés) ; attache au repère du personnage ; états sous verrou | testé hors jeu (83 contrôles) |
| Porte-bébés | 2 modèles 3D distincts (ventral, dorsal), 3 coloris ; objets d'inventaire | testé hors jeu |
| Poussette | modèle 3D (châssis, 4 roues, nacelle, capote, panier), 2 coloris ; garée = figée, poussée = attachée devant le joueur | testé hors jeu |
| Sommeil | paupières fermées à la place des yeux, synchronisé | testé hors jeu |
| Menu admin | 6 réglages bébé dans l'onglet Famille existant | testé hors jeu |
| Naissance (V5) | `elyzea_famille` appelle `CreerBebe` à l'accouchement | testé hors jeu |

## 2. Problèmes identifiés
| # | Gravité | Problème | Conséquence |
|---|---|---|---|
| **A1** | **bloquant** | **Aucune persistance** : bébés et poussettes n'existent qu'en mémoire ; l'arrêt de la ressource supprime tout | un redémarrage (serveur ou ressource) **fait disparaître les bébés**, y compris ceux nés d'une grossesse |
| **A2** | **bloquant** | Bébé non rattaché à une identité durable : identifiant `BB-<heure>-<n°>` recalculé à chaque démarrage, pas de lien avec la grossesse ni avec les parents en base | doublons possibles le jour où l'on enregistre ; impossible de retrouver « son » enfant |
| A3 | majeur | Déconnexion / changement de personnage du porteur : bébé posé au sol là où il était, seul | bébé abandonné dans la rue ; avec la persistance, il y resterait |
| A4 | majeur | `reserveAuxResponsables = false` par défaut : n'importe quel joueur peut prendre n'importe quel bébé | contraire à « joueurs autorisés à interagir » |
| **A5** | **majeur** | Poussette : **aucune physique**. Garée = objet figé sans collision ; poussée = objet attaché ; roues **fusionnées** au châssis (ne tournent pas) ; seule la hauteur suit le sol | ne roule pas, ne suit pas les pentes, ne peut pas dévaler une pente |
| A6 | majeur | Bébé dans une poussette garée = objets figés posés à part, **non attachés à la poussette** | si la poussette bougeait (physique), le bébé resterait en l'air |
| A7 | majeur | Portage dans les bras : animation « porter une caisse » (bras tendus), bébé tenu devant ; aucune animation pour prendre / déposer | aspect « objet rigide » demandé à corriger |
| A8 | majeur | Visage : yeux enfoncés avec un bord sombre, joues basses (bajoues), bouche en simple fente, nez fort, cheveux en « casque », jambes longues et tendues (proportions d'un enfant de 1 an), cou absent | visage « poupée », pas un nouveau-né |
| A9 | moyen | Sommeil non conservé (mémoire) | perdu au redémarrage |
| A10 | moyen | Menu admin : pas de choix de prise, de décalages, de réglages de poussette, ni de diagnostic consultable | réglages demandés absents |
| A11 | info | Animations : **aucune animation de bercement ou de port de bébé n'existe dans GTA V** (vérifié dans les 20 179 dictionnaires) ; existent : `pickup_object` (`pickup_low`, `putdown_low`), bras croisés `amb@world_human_hang_out_street@female_arms_crossed@base` | une vraie animation sur mesure demande le squelette des personnages (fichiers du jeu) |
| A12 | info | Rien n'a jamais été vu ni testé en jeu | positions, rendu et synchronisation à valider sur le serveur |

## 3. Choix techniques (et limites annoncées)
- **Physique de la poussette** : un vrai corps rigide GTA pour un objet ajouté demande des collisions intégrées, des drapeaux
  d'archétype et un réglage de masse/frottement **impossibles à ajuster sans le jeu** ; un corps rigide « boîte » glisse au lieu de rouler,
  et un vrai roulement à quatre roues demande un modèle de **véhicule** complet. Choix retenu : **physique simulée par script**
  (pesanteur le long de la pente, résistance au roulement, frein, obstacles, renversement), calculée par le client qui contrôle
  l'objet (comme les véhicules dans FiveM) et vue par tous ; **roues séparées** qui tournent selon le déplacement ; châssis
  incliné selon le terrain sous les quatre roues. Les calculs sont testables hors du jeu.
- **Portage** : pose « bercée » du bébé refaite (couché sur le côté, tête dans le creux du coude), deux prises au choix (bras
  croisés / bras tendus), animations de prise et de dépose natives, décalages réglables dans le menu admin.
- **Persistance** : tables `rp_bebes` et `rp_poussettes` (création automatique), un enregistrement par bébé avec ses parents et
  sa grossesse (pas de doublon : clé unique grossesse + rang), état de transport, position, sommeil.

## 4. Plan (ordre imposé)
1. Étape 2 — persistance + A1-A4, A9 ; tests MariaDB.
2. Étape 3 — modèle 3D (A8), rendus avant / après, contrôles automatiques.
3. Étapes 4-5 — portage (A7), porte-bébés (vérification des positions, aucune régression).
4. Étape 6 — poussette (A5, A6) : roues séparées, physique simulée, frein, renversement, bébé attaché.
5. Étape 7 — menu admin (A10). Étape 8 — tests, documentation, paquet.
