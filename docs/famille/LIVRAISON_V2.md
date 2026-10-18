# Système familial — livraison V2 (bébés 3D, portage multijoueur, combat, conception, grossesse, contraception)

> Rien n'a pu être testé **dans le jeu** (pas de client GTA V / FiveM dans l'environnement de développement).
> Tous les tests listés au §5 ont réellement été exécutés, hors du jeu, avec leurs résultats.

## 1. Fichiers ajoutés et modifiés

### Ajoutés
| Fichier | Rôle |
|---|---|
| `Elyzea Base/elyzea_bebe_modele/server/bebes.lua` | bébés en réseau : création, prise, prises, pose, vérifications, mort / déconnexion, blocage serveur de la mêlée |
| `Elyzea Base/elyzea_bebe_modele/client/portage.lua` | attache, animation, blocage des coups, menu ALT, commandes |
| `Elyzea Base/elyzea_bebe_modele/tests/test_portage.py` | test du portage (code serveur réel, FiveM simulé) |
| `Elyzea Base/elyzea_famille/server/grossesse.lua` | test de grossesse, examen EMS, suivi `/grossesse` |
| `Elyzea Base/elyzea_inventory/html/img/{preservatif,pilule_contraceptive,implant_contraceptif,test_grossesse}.png` | images des objets (rendues dans Blender) |
| `Outils_3D/icones/icones_famille.py` | script de rendu de ces images |
| `Outils_3D/bebe/build/rendus/comparaison_v1_v2.png` | comparaison du visage V1 / V2 |
| `docs/famille/LIVRAISON_V2.md` | ce document |

### Modifiés
| Fichier | Modification |
|---|---|
| `elyzea_bebe_modele/stream/*` (86 fichiers) | modèles et textures **régénérés** (V2, voir §4) |
| `elyzea_bebe_modele/config.lua`, `fxmanifest.lua`, `client/main.lua`, `server/main.lua`, `README.md` | portage, prises, commandes ; l'ancien portage local (visible par soi seul) est retiré, les aperçus locaux restent pour le staff |
| `elyzea_famille/config.lua`, `shared/regles.lua`, `server/base.lua`, `server/conception.lua`, `server/intimite.lua`, `client/main.lua`, `html/*`, `sql/install.sql`, `fxmanifest.lua`, `README.md`, `tests/*` | règle d'interruption, délai, blocage pendant le portage, grossesse |
| `elyzea_inventory/shared/items.lua` | images des 3 objets existants + objet `test_grossesse` |
| `admin_menu/config.lua` | rayon « Santé » de la supérette + préréglage de PNJ « Pharmacie » |
| `elyzea_police/client/alt.lua` | fournisseur ALT `elyzea_bebe_modele` (1 ligne) |
| `Outils_3D/bebe/scripts/{sdf_baby,generate_baby,export_gta}.py`, `README_BEBE.md` | modèle V2, correction des normales, cheveux |

## 2. Dépendances et justification
| Dépendance | Pourquoi |
|---|---|
| `elyzea_core` | joueurs, citizenid, fiche d'identité (âge, sexe), notifications, base de données |
| `elyzea_inventory` | objets (seul inventaire du serveur, aucun second inventaire créé) |
| `admin_menu` (supérette) | vente des objets par le commerce existant, sans commerce parallèle |
| `elyzea_police` (menu ALT) | interactions (prendre le bébé, proposer un moment, actes EMS) dans le menu existant |
| `elyzea_ems` (facultatif) | coma = lâcher le bébé ; EMS en service pour implant et examen |
| **OneSync** | objets réseau créés par le serveur (bébé visible par tous) et vérification des distances |

## 3. Fonctionnalités existantes réutilisées
- Moment intime avec consentement, fondu au noir, X pour arrêter (déjà présent dans `elyzea_famille` 0.1) : **c'est l'animation de conception** ; elle n'a pas été recréée.
- Calcul de conception côté serveur, une tentative par moment (contrainte SQL), grossesse enregistrée en transaction (0.1).
- Contraception : préservatif, pilule, implant, `/contraception` (0.1).
- Supérette et éditeur de PNJ d'`admin_menu`, menu ALT d'`elyzea_police`, inventaire Elyzea, coma EMS.

## 4. Problèmes identifiés et corrections
| Problème (vérifié dans les fichiers) | Correction |
|---|---|
| Bébé visible **uniquement** par celui qui le crée : `/bebe_test` crée des objets locaux (`isNetwork = false`) ; aucun système de portage réseau | bébé = objets réseau créés par le serveur, un seul exemplaire, attache synchronisée et vérifiée |
| Aucune règle de combat pendant le portage | coups bloqués chez le porteur + dégâts de mêlée annulés par le serveur ; aucune protection pour lui |
| Moment interrompu à plus de 60 % : une tentative était encore calculée | par défaut **aucune** tentative si le moment n'est pas terminé (`Config.Conception.siInterrompu`) |
| Pas de délai entre deux moments | `Config.Intimite.delaiEntreMoments` (30 min par défaut) |
| Grossesse enregistrée mais invisible en jeu | test de grossesse, examen EMS, suivi `/grossesse` |
| Contraceptifs définis mais **impossibles à obtenir** (aucun commerce ne les vend) et sans image | rayon « Santé » de la supérette, préréglage « Pharmacie », images |
| Modèle : **carte de normales en convention OpenGL** alors que GTA V attend DirectX → reliefs inversés en jeu | canal vert inversé à l'export |
| Modèle : cheveux découpés (aspect moucheté), regard fixe, narines marquées, peau grise | cheveux à transparence douce, paupières, narines, peau (régénéré et reconverti) |

## 5. Tests réellement effectués (hors du jeu)
| Test | Résultat |
|---|---|
| Règles de calcul (`lua5.4 elyzea_famille/tests/test_regles.lua`) : âge, porteur, contraception combinée, pilule, implant, interruption, test de grossesse, étapes, statistiques sur 200 000 tirages | **51/51** |
| Code serveur famille + **vraie base MariaDB** (`python3 elyzea_famille/tests/integration_test.py`) : consentement, refus, réponse falsifiée, préservatif consommé une fois, une seule tentative, interruption = aucune tentative, délai, portage bloquant, grossesse unique, test (trop tôt / positif / sans objet), examen EMS, progression sur 13 jours, redémarrage, mise à jour 0.1 → 0.2 | **52/52** (3 exécutions) |
| Portage (`python3 elyzea_bebe_modele/tests/test_portage.py`) : création, distance, prise, un seul porteur, mêlée annulée pour le porteur seulement, prises, pose, attache échouée, mort, déconnexion, 10 demandes répétées, arrêt de la ressource | **31/31** |
| Modèle 3D (`python3 Outils_3D/bebe/scripts/validate.py`) : maillage fermé, normales, poids, squelette, poses, textures, fichiers du jeu | **20/20** |
| Fichiers du jeu relus par CodeWalker (`ElyConvert`) | **86/86** |
| Syntaxe Lua (`luac5.4 -p`) et JavaScript de tous les fichiers modifiés | OK |
| **Tests en jeu à deux joueurs** (visibilité, suivi des mouvements, combat réel, rendu) | **non faits** : procédure dans `elyzea_bebe_modele/README.md` |

## 6. Installation et configuration
Voir `INSTALLATION.txt` du paquet. Réglages : `elyzea_bebe_modele/config.lua` (`Config.Portage`), `elyzea_famille/config.lua`
(`Config.Conception` : probabilités, `siInterrompu`, multiples ; `Config.Contraception` : fiabilités et durées ;
`Config.Intimite.delaiEntreMoments` ; `Config.Grossesse.test`).

## 7. Limites techniques
- Pas d'essai dans le jeu : positions des prises à ajuster (`/bebe_ajuster`), rendu de la transparence des cheveux à vérifier.
- Animation de portage et animation du moment intime : animations natives de GTA (pas d'animation sur mesure, qui demanderait les fichiers de squelette du jeu).
- Les bébés sont créés par le staff ou par l'export `CreerBebe` ; la naissance automatique et la sauvegarde des enfants sont le module suivant.
- Grossesse : pas encore de symptômes, de tenues de grossesse ni d'accouchement.
