# Bébé, portage, porte-bébés, poussette — livraison V6

> **Rien n'a pu être testé dans le jeu** (pas de client GTA V / FiveM dans l'environnement de développement).
> Ce document distingue : **code écrit**, **tests automatisés réellement exécutés** (hors du jeu, §6), et **tests en jeu à faire** (§7).
> Aucune fonction n'est déclarée validée en jeu ni avec plusieurs joueurs.
> Audit préalable : `docs/famille/AUDIT_BEBE_V6.md` (problèmes A1-A12).

## 1. Sauvegarde et retour arrière
V5 = commit `0278dfb` (étiquette `sauvegarde-v5`) et paquet `elyzea_famille_v5.zip`. Retour arrière : §8.

## 2. Ce qui a été fait, par étape
| Étape | Réalisé | Statut |
|---|---|---|
| 1 Audit | inventaire, 12 problèmes (dont 2 bloquants : aucune persistance, bébé sans identité durable), plan | fait |
| 2 Persistance, bugs | tables `rp_bebes` / `rp_poussettes` ; identifiants durables ; naissance = un enregistrement (grossesse + rang : jamais deux bébés) ; porteur déconnecté → bébé gardé avec son personnage puis rendu à ses pieds ; redémarrage → poussettes et bébés restaurés (dans la poussette, endormis…) ; bébés réservés aux parents + `/bebe_confier` ; suppression définitive explicite | code + tests auto |
| 3 Modèle 3D | **vraie modification du maillage** (générateur `sdf_baby.py`) : visage ramené aux proportions d'un nouveau-né (joues ≈ 11 cm → ≈ 8 cm de large, plus de bajoues, joues hautes et rondes), crâne plus rond, yeux plus ouverts, nez « bouton », bouche plus large aux lèvres pleines, commissures et narines sans « trous » ; duvet clairsemé (plus d'effet casque) ; textures : dépliage moins morcelé et **remplissage des bords d'îles** (supprime les traits sombres du pyjama vus de loin) ; pose « porté » bercée (bras repliés vers la poitrine, jambes en grenouille) | voir §5 |
| 4 Portage | prise « Contre moi » aux **bras croisés** (animation native vérifiée) ; « Dans les bras » plus près du corps ; **gestes natifs pour prendre et déposer** (`pickup_object`) ; décalages de chaque prise réglables dans le menu admin | code ; positions à vérifier en jeu |
| 5 Porte-bébés | modèles V4 conservés (contrôles : 0 cm dans le corps du mannequin) ; décalages réglables | code ; à vérifier en jeu |
| 6 Poussette | **roues séparées** qui tournent ; **frein**, « lâcher sans frein », **physique simulée** (pente, roulement, frein, obstacles, renversement, pivot vers le bas de la pente) calculée par un joueur proche et vérifiée par le serveur ; inclinaison selon le terrain pendant la poussée ; bébé **attaché à la poussette** ; renversée → bébé posé à côté ; relever ; rattraper une poussette qui roule | code + tests auto |
| 7 Menu admin | même onglet Famille, même permission, même table : +9 réglages bébé, 16 décalages de prise, liste de choix (coloris), bloc **diagnostic** | code + tests auto + rendu |
| 8 Tests | §6 (automatiques) ; §7 (en jeu, à faire) | partiel |

## 3. Choix techniques et limites (honnêtes)
- **Physique** : simulée par script, pas le moteur physique de GTA (un objet ajouté n'a pas de masse / frottement réglables sans le
  jeu ; un corps rigide glisse au lieu de rouler ; un vrai roulement à 4 roues = un modèle de véhicule complet). Elle ne pousse pas
  les joueurs (elle s'arrête devant eux). Le sens du roulis et de la rotation des roues est calculé, pas vu : à confirmer en jeu.
- **Portage** : GTA n'a **aucune** animation de bercement (vérifié dans les 20 179 dictionnaires). Le résultat « vrai parent qui tient
  un nouveau-né » demande une animation sur mesure, impossible sans le squelette des personnages (fichiers du jeu à fournir).
- **Modèle** : nettement plus proche d'un nouveau-né, mais modèle de jeu généré par programme (~16 000 triangles), pas un scan.

## 4. Fichiers
| Fichier | Rôle |
|---|---|
| `elyzea_bebe_modele/server/bebes.lua` | états, frein / lâcher / simulation / renversement, garde, confier, réglages V6, export `Diagnostic` |
| `elyzea_bebe_modele/server/persistance.lua` (nouveau) | tables, écriture des changements, restauration, retour à la connexion |
| `elyzea_bebe_modele/shared/physique.lua` (nouveau) | physique de la poussette (fonctions pures) |
| `elyzea_bebe_modele/client/poussette.lua` (nouveau) | simulation par le client qui contrôle l'objet, roues locales |
| `elyzea_bebe_modele/client/portage.lua` | bébé attaché à la poussette, inclinaison, gestes, décalages, options ALT |
| `elyzea_bebe_modele/config.lua`, `fxmanifest.lua` (3.0.0), `README.md`, `stream/` (modèles régénérés + roues), `shared/modeles.lua` (généré) | |
| `elyzea_bebe_modele/tests/` | `test_persistance.py`, `test_poussette.py`, `test_physique.lua` (nouveaux) ; `test_portage.py`, `test_client.lua` |
| `elyzea_famille/server/reglages.lua`, `config.lua`, `server/suivi.lua` | réglages V6 ; naissance enregistrée |
| `admin_menu/html/famille.js` | liste de choix, diagnostic |
| `Outils_3D/bebe/scripts/` | `sdf_baby.py` (visage), `generate_baby.py` (pose, duvet, UV), `equipements.py` (roues séparées), `export_gta.py`, `make_resource.py`, `rendu_jeu.py` |

## 5. Modèle 3D : résultat
Chaîne complète relancée (`Outils_3D/bebe/construire.sh`) : **148 fichiers du jeu** produits (bébé : 6 teintes × 2 tenues, 5 yeux,
10 coiffures, paupières fermées, 4 poses ; porte-bébés ventral / dorsal × 3 coloris ; poussette **sans roues** × 2 coloris ;
**roue arrière et roue avant** × 2 coloris), **0 échec de conversion**, relus par CodeWalker, **37/37 contrôles**.
Rendu fait à partir des fichiers du jeu relus : `docs/famille/captures/fichiers_du_jeu_v6.png` (poussette avec ses 4 roues placées
comme dans le jeu). Visage avant / après : joues ramenées sous les yeux, visage plus étroit, bouche plus large, yeux plus ouverts.
Reste visible : quelques petites marques sombres sur le pyjama (genoux, entrejambe), nettement moins qu'en V4 ; aspect encore
« modèle de jeu » de près.

## 6. Tests réellement exécutés (hors du jeu)
| Test | Résultat |
|---|---|
| Contrôles du modèle et des équipements (`validate.py` : maillage fermé, UV sans superposition, porte-bébés hors du corps du mannequin, bébé dans la nacelle, **roues au sol**, fichiers présents) | **37/37** |
| Conversion en fichiers du jeu + relecture CodeWalker | **148/148** |
| Persistance, vraie base MariaDB, redémarrages simulés (`tests/test_persistance.py`) | **19/19** |
| États de la poussette : frein, lâcher, simulateur, arrêt, renversement, relever, rattraper, simulateur déconnecté, position invraisemblable, réglages admin (`tests/test_poussette.py`) | **23/23** |
| Physique sur terrains simulés : plat, élan, pentes 2 / 8 / 55 %, frein, dévers, mur, trottoir, travers, bosses (`tests/test_physique.lua`) | **15/15** |
| Portage V3-V5 (régression) avec bébé attaché à la poussette (`tests/test_portage.py`) | **83/83** |
| Logique client : options ALT (frein, relever…) (`tests/test_client.lua`) | **11/11** |
| `elyzea_famille` complet + réglages V6 transmis (`tests/integration_test.py`) | **117/117** |
| Onglet admin affiché dans Chromium (13 sections, 94 réglages, aucune erreur JavaScript) | fait (`captures/menu_admin_*`) |
| Syntaxe Lua / JavaScript de tous les fichiers modifiés | OK |

## 7. Tests à faire en jeu (deux joueurs A et B)
1. **Naissance** (accouchement EMS) : le bébé apparaît, A et B le voient ; redémarrer le serveur : il est toujours là.
2. **Portage** : A prend le bébé (geste), *Dans les bras* puis *Contre moi* : bébé soutenu, ni flottant ni dans le torse (régler les décalages dans le menu si besoin) ; marcher, courir, B voit la même chose.
3. **Porte-bébés** ventral et dorsal, personnage homme **et** femme.
4. **Déconnexion** de A en portant le bébé : le bébé disparaît du monde ; A se reconnecte : bébé à ses pieds.
5. **Poussette** : sortir (frein serré), installer le bébé, pousser sur du plat puis dans une pente (la poussette s'incline), garer.
6. Dans une rue en pente : *Lâcher (sans frein)* : elle dévale, roues qui tournent, s'arrête en bas ou contre un obstacle ; B voit le même trajet. Vérifier le sens de rotation des roues et l'inclinaison latérale.
7. Pente forte vers un mur : renversement, bébé posé à côté ; *Relever*.
8. B rattrape une poussette qui roule (*Pousser*). A et B cliquent en même temps : une seule action réussit ; jamais deux bébés.
9. Redémarrer la ressource pendant qu'une poussette roule : elle revient garée, bébé dedans.
10. Menu F10 › Famille : modifier un décalage, la physique, un coloris ; redémarrer : réglages conservés ; bloc diagnostic lisible.

## 8. Retour arrière
`git checkout sauvegarde-v5 -- "Elyzea Base/elyzea_bebe_modele" "Elyzea Base/elyzea_famille" "Elyzea Base/admin_menu/html/famille.js"`
(remettre le dossier `elyzea_bebe_modele` **en entier**, `stream/` compris). Les tables `rp_bebes` / `rp_poussettes` peuvent rester
(la V5 les ignore) ou être supprimées : `DROP TABLE rp_bebes, rp_poussettes;` (perd les bébés enregistrés).

## 9. Dépendances
FXServer avec **OneSync** ; `elyzea_core` (base de données, joueurs), `elyzea_inventory`, `elyzea_police` (menu ALT), `admin_menu`,
`elyzea_famille` ; `elyzea_ems` facultatif. Fabrication des modèles (pas nécessaire au serveur) : Blender 5.2 (bpy), Sollumz 2.9.0,
.NET 8 + CodeWalker.Core, Python 3 (numpy, scipy, scikit-image, Pillow).
