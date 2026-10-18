# Système familial — livraison V4 (bébé, portage, porte-bébés ventral et dorsal, poussette)

> **Rien n'a pu être testé dans le jeu** (pas de client GTA V / FiveM dans l'environnement de développement).
> Tous les tests du §6 ont réellement été exécutés, hors du jeu, avec les résultats indiqués. Les tests en jeu (§7) restent à faire.
> Audit préalable (fichiers, inventaire du système familial, dépendances, formats, blocages) : `docs/famille/AUDIT_V4.md`.

## 1. Sauvegarde et retour arrière
V3 = commit `a8d61c0` (étiquette locale `sauvegarde-v3`) et paquet `elyzea_famille_v3.zip`. La V4 ne crée, ne supprime ni ne
modifie aucune table : retour arrière = remettre les fichiers V3 (procédure : `RETOUR_ARRIERE.txt` du paquet).

## 2. Ce qui a été fait, par phase
| Phase | Réalisé |
|---|---|
| 1-2 Audit, conservation | audit écrit avant toute modification ; système familial conservé (aucune fonction remplacée) ; fonctions absentes signalées (familles, relations, bébés en base : module « enfants » à venir) |
| 3 Modèle du bébé | **vraies paupières** (coussin de paupière ouvert en amande, bords qui épousent l'œil), globe aux proportions d'un nouveau-né, **bouche fermée et détendue**, narines discrètes, double menton allégé, rebord d'oreille (hélix), **cheveux sur deux couches**, peau **mate** dans le jeu (reflet faible et large au lieu du reflet serré « plastique »), micro-relief de peau très léger, pyjama : **poignets, chevilles et col côtelés** et **plis souples** aux coudes et genoux, **variante endormie** (paupières fermées) ; toutes les variantes conservées et réellement produites : 6 teintes × 2 tenues, 5 yeux, 10 coiffures, 4 poses, + 6 paupières fermées par pose |
| 4 Portage dans les bras | pose « porté » refaite (bébé couché sur le dos, jambes légèrement repliées, tête légèrement tournée) ; animation native vérifiée (`anim@heists@box_carry@`) : **aucune animation de bercement n'existe dans GTA** (vérifié dans la liste des 20 179 dictionnaires) ; animation sur mesure impossible sans le squelette des personnages (fichiers du jeu) |
| 5 Porte-bébé ventral 3D | **créé** : panneau rembourré qui épouse le dos du bébé, appui-tête roulé, assise, ceinture, bretelles croisées dans le dos, épaulières, boucle ; 3 coloris ; équipable depuis l'inventaire, bébé installé / retiré, attaché au personnage (visible par tous) |
| 6 Porte-bébé dorsal 3D | **modèle distinct** : bébé au centre du dos, panneau, bretelles parallèles, sangle de poitrine et sa boucle ; 3 coloris ; transitions avec les autres prises |
| 7 Poussette 3D | **créée** : châssis, 4 roues à rayons, poignée en mousse, nacelle à fond plat, matelas, capote plissée, panier ; 2 coloris ; sortir / pousser / garer / installer / reprendre / remettre / ranger ; pas de course, arrêt devant un obstacle, hauteur réajustée au relief ; nettoyage des poussettes vides abandonnées |
| 8 États et transitions | un seul état par bébé (`pose`, `porte` bras/face/ventral/dorsal, `poussette`), changements sous verrou, attaches vérifiées, replis sûrs (mort, déconnexion, **changement de personnage**) |
| 9 Menu admin unique | section « Bébés et équipements » ajoutée à l'onglet **Famille existant** : activer ventral / dorsal / poussette, course interdite, délai d'abandon, journal de diagnostic ; même permission `famille_manage`, même table, mêmes vérifications serveur |
| 10 Multijoueur, sécurité | objets réseau créés par le serveur, attaches confirmées par le client et vérifiées par le serveur, anti double clic, demandes simultanées refusées, distances et équipements vérifiés côté serveur ; aucune invincibilité |
| 11 Intégration | inventaire existant (3 objets), menu ALT existant, éditeur de PNJ existant (préréglage « Puériculture »), menu admin existant ; aucun système parallèle |

## 3. Fichiers produits ou modifiés
| Fichier | Rôle |
|---|---|
| `Elyzea Base/elyzea_bebe_modele/` (2.0.0) | ressource complète : `server/bebes.lua` (états, équipements, poussette), `client/portage.lua`, `config.lua`, `server/main.lua`, `shared/modeles.lua` (généré), `stream/` (**144 fichiers** : 140 modèles, 3 dictionnaires de textures, 1 `.ytyp`, 36,6 Mo), `tests/test_portage.py`, `tests/test_client.lua`, `README.md` |
| `Elyzea Base/elyzea_famille/` (0.3) | `server/reglages.lua` (section bébés + export `ReglagesBebe`), `config.lua` (`Config.Bebe`), `tests/integration_test.py`, `README.md` |
| `Elyzea Base/admin_menu/config.lua`, `html/famille.js` | préréglage de PNJ « Puériculture » ; sous-titre de l'onglet |
| `Elyzea Base/elyzea_inventory/shared/items.lua`, `html/img/{porte_bebe_ventral,porte_bebe_dorsal,poussette}.png` | 3 objets et leurs images (rendues à partir des vrais modèles 3D) |
| `Outils_3D/bebe/scripts/` | `sdf_baby.py`, `generate_baby.py` (bébé V4), **`equipements.py`** (porte-bébés, poussette, mannequin, contrôles), `export_gta.py`, `make_resource.py`, `validate.py`, `rendu_jeu.py`, `apercu_visage.py`, `icones_equipements.py`, `construire.sh` (chaîne complète en une commande) |
| `Outils_3D/bebe/build/` | sources `.blend` / `.glb` / `.fbx`, `equipements/equipements.blend`, textures, rendus, rapports |
| `docs/famille/AUDIT_V4.md`, `LIVRAISON_V4.md`, `captures/menu_admin_bebes.png` | documentation |

## 4. Base de données
Aucune migration de structure. Six nouvelles **lignes** possibles dans la table existante `rp_famille_reglages` (clés `bebe.*`),
écrites seulement si un administrateur enregistre ces réglages. Les bébés ne sont toujours pas enregistrés en base (module « enfants »).

## 5. Dépendances (versions)
FXServer artefact 35245 avec **OneSync** ; `elyzea_core`, `elyzea_inventory`, `elyzea_police` (menu ALT), `admin_menu`, `elyzea_famille` 0.3
(facultatif pour la ressource bébé : sans elyzea_famille, les valeurs de `config.lua` s'appliquent) ; `elyzea_ems` facultatif.
Outils de fabrication (pas nécessaires au serveur) : Blender 5.2 (module bpy), Sollumz 2.9.0, szio 1.3.0.dev9, .NET 8 + CodeWalker.Core, Python 3 (numpy, scikit-image, Pillow, scipy).

## 6. Tests réellement exécutés (hors du jeu)
| Test | Résultat |
|---|---|
| Contrôles du modèle et des équipements (`validate.py`) : maillage fermé, normales, poids, squelette, poses, **UV sans superposition** (bébé, porte-bébés, poussette), **peau peu étirée par pose**, **porte-bébés : 0 cm dans le corps du mannequin**, **bébé ventral / dorsal : tronc et tête à ≥ 1 cm du parent, bras et jambes au contact sans le traverser**, **poussette : roues au sol, bébé sur le matelas dans la nacelle**, 144 fichiers présents, chacun < 16 Mo | **37/37** |
| Conversion en fichiers du jeu et relecture par CodeWalker | **144/144** |
| Rendu à partir des fichiers du jeu relus (bébé, porte-bébés avec bébé, poussette avec bébé endormi) : toutes les textures retrouvées | fait (`build/rendus/fichiers_du_jeu.png`) |
| Serveur du bébé, FiveM simulé (`tests/test_portage.py`) : V3 (création, distance, prises, combat, pose, attache, mort, déconnexion, requêtes répétées) **et V4** : porte-bébés (objet requis, non consommé, modèle 3D, attache, retrait refusé avec le bébé dedans, dorsal distinct), réglages admin appliqués, poussette (sortie, une par personnage, installer, pousser, garer avec rotation, reprendre, remettre le même bébé, nacelle occupée), demandes simultanées et doubles clics, endormir / réveiller, déconnexion du pousseur, changement de personnage, abandon (avant / après le délai), ranger (propriétaire seulement), mort du pousseur, **aucune entité orpheline ni dupliquée** | **83/83** |
| Logique client (`tests/test_client.lua`) : options du menu ALT selon l'état (équipement, réglages admin, mains occupées, nacelle occupée), position dans la nacelle, décalages féminins par prise | **10/10** |
| Famille + vraie base MariaDB (`elyzea_famille/tests/integration_test.py`) : **régression** de tout l'existant (71) + section bébés du menu admin (enregistrement, transmission, valeurs invalides, refus sans permission, redémarrage, valeurs par défaut) | **79/79** |
| Règles de calcul famille (`test_regles.lua`) | **51/51** |
| Onglet admin affiché dans Chromium avec les vraies données | fait (`captures/menu_admin_bebes.png`) |
| Syntaxe Lua (`luac5.4 -p`) et JavaScript (`node --check`) de tous les fichiers modifiés | OK |

## 7. Tests à faire sur le serveur (non faits)
Voir `elyzea_bebe_modele/README.md` › « Tests à faire en jeu » : rendu réel, positions sur un vrai personnage (homme et femme),
deux joueurs (visibilité, positions identiques, actions simultanées), déconnexion, abandon, menu F10, redémarrage.

## 8. Points non terminés ou nécessitant une intervention
1. **Réglage fin en jeu des positions** (bébé dans les bras, porte-bébés, poussette) : valeurs calculées sur un mannequin, à vérifier
   et éventuellement corriger avec `/bebe_ajuster` (les valeurs s'affichent en F8, à recopier dans `config.lua`).
2. **Animation de bercement sur mesure** : impossible sans le squelette des personnages GTA. Si tu veux la faire, extrais avec CodeWalker
   `mp_m_freemode_01.yft` et `mp_f_freemode_01.yft` de TON jeu et envoie-les : la chaîne pourra produire un `.ycd`.
3. **Visage** : nettement plus doux que la V3, mais ce n'est pas un bébé photographique (modèle de jeu généré par programme,
   16 000 triangles). Les paupières fermées montrent un contour visible de très près.
4. **Poussette** : objet attaché (pas de physique de roues) ; garée, elle n'a pas de collision ; escaliers raides non gérés.
5. **Bébés en base, familles, naissance** : non faits (module « enfants »), comme indiqué dans l'audit.
6. Préréglage « Puériculture » : à poser une fois dans l'éditeur de PNJ (F10 › Éditeur › PNJ).
