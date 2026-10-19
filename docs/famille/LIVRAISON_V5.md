# Système famille — livraison V5 (étapes 1 à 4 : audit, bugs, grossesse et contraception, ventre)

> **Rien n'a pu être testé dans le jeu** (pas de client GTA V / FiveM dans l'environnement de développement).
> Tous les tests du §6 ont réellement été exécutés, hors du jeu, avec les résultats indiqués.
> Conformément à la consigne (« vérifie chaque étape en jeu avant de déclarer le travail terminé »), les étapes 2 à 4
> sont **livrées pour essai en jeu**, pas déclarées terminées. Les étapes 5 et 6 (bébé, portage, porte-bébés, poussette
> avec physique) **ne sont pas faites dans cette livraison** (§8).
> Audit et liste des bugs : `docs/famille/AUDIT_V5.md`.

## 1. Sauvegarde
V4 = commit `d9daf3f` (branche `claude/dreamy-ritchie-7vdqzv`) et paquet `elyzea_famille_v4.zip`. Retour arrière : §7.

## 2. Bug prioritaire « test toujours négatif » — causes et corrections
| # | Cause | Correction | Vérifié par |
|---|---|---|---|
| B1 | Part « réalisée » d'un moment **terminé** calculée à la seconde près (pouvait valoir 93 %) ; seuil appliqué à tous les moments | moment terminé = 100 % ; seuil seulement pour un moment arrêté (si l'option est activée) | règles + intégration (test 29) |
| B2 | Test positif seulement **24 h réelles** après la conception, délai absent du menu, même message qu'un vrai négatif | délai **en minutes, réglable** (60 min par défaut) ; message : « Un test fait trop tôt peut être négatif : refaites-en un dans 1 h » | intégration (tests 16, 30-32) |
| B3 | 1 test sur 100 négatif après le délai | fiabilité **100 %** par défaut, réglable | règles + intégration (31) |
| B4 | Deux risques (« les deux souhaitent un enfant » / « accidentel ») : régler l'un à 100 % ne change rien dans l'autre cas | libellés explicites dans le menu ; le diagnostic dit quel risque a été appliqué | intégration (33) |
| B5 | `/famille_etat` ne montrait pas les tentatives refusées | lecture par moment (personne A ou B) : statut, raison, risque, probabilité, tirage | intégration (33) |
| B6 | Étapes en jours fixes, fausses si la durée change | étapes en **pourcentage** de la durée, réglables, ordre vérifié | règles + intégration (34) |
| B7 | Aucune fin de grossesse | accouchement EMS, naissance automatique, fin staff (§3) | intégration (39-42) |

**Pour vérifier en jeu que la grossesse fonctionne à 100 %** : menu admin › Famille › Risque de grossesse : régler les **deux**
risques à 100 % (ou cocher « souhaiter un enfant » des deux côtés), délai du test à 0 ou attendre 60 min, moment **mené à son terme**
(pas arrêté avec X), sans préservatif, entre un personnage féminin et un personnage masculin de 18 à 55 ans. En cas d'échec,
`/famille_etat [id]` affiche la raison exacte de la dernière tentative.

## 3. Ce qui a été fait (étapes 2 à 4)
| Étape | Réalisé |
|---|---|
| 2 Bugs | B1 à B6 ci-dessus ; module conception activable dans le menu |
| 3 Grossesse | suivi serveur toutes les 60 s **à partir de la base** (continue hors ligne, après déconnexion et redémarrage) ; **symptômes réglables un par un** : faim plus rapide (×2 par défaut, via `elyzea_core:AddNeeds`, respecte le gel des besoins), nausées (flou + tangage), vomissements (animation native vérifiée `anim@scripted@nightclub@vomit@`, secours `missfam5_blackout` ; jamais en véhicule, dans l'eau, à terre, pendant un moment intime ou avec un bébé porté), démarche lourde native `move_f@fat@a` (course interdite en option) — étape de début / fin, fréquence, durée, intensité ; **fin de grossesse** : accouchement par un EMS (menu ALT, consentement, à partir de 90 %, écran noir de 20 s, EMS à genoux, distance vérifiée à la fin), naissance automatique 24 h après le terme, `/famille_fin [id] [naissance]` ; grossesse close **une seule fois** ; bébé(s) créé(s) à côté de la patiente (ressource `elyzea_bebe_modele`, responsables = les deux parents) ; tous les effets s'arrêtent |
| 4 Ventre | mécanisme générique : la pièce du pack réglée pour l'étape est posée par-dessus la tenue, la pièce d'origine est gardée et remise à la fin ; nouvelle tenue (objet vêtement, boutique, uniforme, rechargement) = nouvelle pièce d'origine puis ventre remis ; boutique ouverte = rien n'est touché ; identification **par collection + n° local** (indépendante de l'ordre de chargement des packs) ; compatibilité réglable (`toujours`, `sansHaut`, `liste` de hauts) ; la tenue enregistrée (ely_creator), les objets vêtements et « Ma tenue » (elyzea_clothing) **ne contiennent jamais le ventre** ; outils `/ventre_info`, `/ventre_scan`, `/ventre_essai` |
| 7 Menu admin (partiel) | même onglet Famille, même permission `famille_manage`, même table : **5 nouvelles sections** (Étapes, Symptômes, Fin de grossesse, Ventre, + test et module dans « Risque de grossesse ») — 69 réglages au total, tous revalidés par le serveur (bornes, ordre des étapes, début ≤ fin, texte de collection filtré), enregistrés en base, appliqués immédiatement, rechargés au redémarrage |

### Configurer le ventre VeloxFv1 (numéros à relever, le pack n'est pas dans le dépôt)
1. En jeu, mettre le ventre du pack sur un personnage féminin (boutique ou `/ventre_scan 3` puis `/ventre_essai 3 <n°> 0 <collection>`).
2. `/ventre_info` : la ligne du composant qui a changé donne **composant, `col` (collection) et `li` (n° local)**.
   La catégorie boutique « Gants et bras » = composant 3 ; si le ventre est ailleurs (8, 11…), `/ventre_info` le montre.
3. Menu admin › Famille › **Ventre de grossesse** : composant, collection, n° et texture par étape (−1 = pas de ventre), activer, Enregistrer.
4. Si des hauts deviennent transparents avec le ventre : mode `sansHaut` ou `liste` dans `config.lua` (`Config.Ventre.compatibilite`).

## 4. Fichiers produits ou modifiés
| Fichier | Rôle |
|---|---|
| `elyzea_famille/` (0.5) | `shared/regles.lua` (B1, B2, B3, B6, symptômes), `shared/ventre.lua` (nouveau), `server/suivi.lua` (nouveau : effets, accouchement, fin), `server/grossesse.lua` (message du test), `server/staff.lua` (diagnostic), `server/reglages.lua` (sections + type texte + publication du ventre), `server/base.lua` (colonne), `client/grossesse.lua` (nouveau), `client/ventre.lua` (nouveau), `client/main.lua` (option ALT Accouchement), `config.lua`, `sql/install.sql`, `fxmanifest.lua`, `README.md`, `tests/` |
| `elyzea_core/lib/clothing.lua` | `ElyCloth.readReal` (pièce réelle quand une pièce temporaire est posée) |
| `ely_creator/client/main.lua` | `SaveOutfit` : enregistre la pièce réelle (une ligne) |
| `elyzea_clothing/client/items.lua` | objet vêtement et « Ma tenue » : pièce réelle (deux lignes) |
| `admin_menu/html/famille.js` | champ texte (collection du pack), sous-titre |
| `docs/famille/AUDIT_V5.md`, `LIVRAISON_V5.md`, `captures/menu_admin_symptomes.png`, `captures/menu_admin_ventre.png` | documentation |

## 5. Base de données
Une seule modification de structure, **ajoutée automatiquement** au démarrage (données conservées) :
`ALTER TABLE rp_pregnancies ADD COLUMN end_reason VARCHAR(32) NULL AFTER ended_at` (raison de fin : `accouchement`,
`naissance_auto`, `naissance_staff`, `fin_staff`). Nouvelles lignes possibles dans `rp_famille_reglages` (réglages enregistrés).
Ancien réglage du test `delai` (heures) toujours accepté si présent dans un `config.lua` personnalisé.

## 6. Tests réellement exécutés (hors du jeu)
| Test | Résultat |
|---|---|
| Règles (`lua5.4 tests/test_regles.lua`) : B1, délai et fiabilité du test, étapes en %, symptômes (étapes, faim, fréquence moyenne mesurée sur 20 000 tirages), seuil d'accouchement | **68/68** |
| Serveur réel + **vraie base MariaDB** (`python3 tests/integration_test.py`) : régression complète V1-V4 + B1, B2/B3 (trop tôt / après le délai / délai 0), diagnostic staff, étapes refusées dans le désordre, état envoyé à la seule joueuse, faim ×2 et ×3, besoins gelés, nausées à la fréquence réglée, symptômes désactivés, démarche à l'étape 3, accouchement trop tôt refusé, accouchement (grossesse close, bébé créé, effets arrêtés, journal), second accouchement refusé, fin staff, naissance automatique, reprise après redémarrage, réglages du ventre publiés / refusés / rechargés | **113/113** |
| Ventre, logique client avec fonctions du jeu simulées (`lua5.4 tests/test_ventre.lua`) : désactivé par défaut, pose par collection, pièce d'origine gardée et lue par la sauvegarde, changement de tenue, boutique, `sansHaut`, personnage recréé, pack absent, fin de grossesse | **17/17** |
| Bébé (`elyzea_bebe_modele` : `test_portage.py`, `test_client.lua`) — non modifié, régression | **83/83**, **10/10** |
| Onglet admin affiché dans Chromium avec les vraies données (11 sections, 69 réglages, aucune erreur JavaScript) | fait (`captures/`) |
| Syntaxe Lua (`luac5.4 -p`) et JavaScript (`node --check`) de tous les fichiers modifiés | OK |

## 7. Tests à faire en jeu (non faits) — plan par phases
- **A. Conception** : risques à 100 %, moment terminé → `/famille_etat` montre « conception » ; moment arrêté avec X → « aucune tentative » ; préservatif → « protege » / risque réduit.
- **B. Test** : test juste après → négatif + rappel « trop tôt » ; après 60 min → positif ; `/grossesse` affiche l'étape.
- **C. Symptômes** : faim qui baisse plus vite (HUD), nausée (flou), vomissement (animation, pas en voiture, pas avec un bébé), démarche lourde à l'étape 3 (accélérer le temps : `UPDATE rp_pregnancies SET conceived_at = conceived_at - 86400*8, due_at = due_at - 86400*8 WHERE active_key = '<citizenid>'`).
- **D. Ventre** : relever les numéros (§3), activer, vérifier chaque étape, changer de haut / gants, boutique, se reconnecter (la tenue enregistrée ne doit pas contenir le ventre), fin de grossesse (pièce d'origine remise).
- **E. Fin** : accouchement par un EMS (deux joueurs), bébé visible des deux, `/famille_fin`, redémarrage pendant une grossesse.

Retour arrière : remettre les fichiers V4 (`git checkout d9daf3f -- "Elyzea Base/elyzea_famille" "Elyzea Base/admin_menu/html/famille.js" "Elyzea Base/elyzea_core/lib/clothing.lua" "Elyzea Base/ely_creator/client/main.lua" "Elyzea Base/elyzea_clothing/client/items.lua"`). La colonne `end_reason` peut rester (ignorée par la V4).

## 8. Non fait dans cette livraison, et pourquoi
1. **Étape 5 (bébé plus beau, portage naturel)** et **étape 6 (porte-bébés, poussette avec vraie physique)** : non commencées.
   L'ordre imposé met les bugs et la grossesse d'abord, et ces étapes dépendent des positions V4 jamais vues en jeu.
   La **physique de poussette** (roule, suit le terrain, descend une pente une fois lâchée) demande un objet dynamique avec
   collisions intégrées au modèle (nouveau modèle exporté avec ses collisions + nouveau code de poussée) : travail à part entière.
2. **Animations sur mesure** (bercement, accouchement) : impossibles sans le squelette des personnages GTA
   (`mp_f_freemode_01.yft`, `mp_m_freemode_01.yft` extraits de ton jeu avec CodeWalker). Animations natives utilisées à la place.
3. **Ventre VeloxFv1** : numéros non fournis (pack absent du dépôt) ; mécanisme prêt, désactivé tant qu'ils ne sont pas saisis.
4. Bébés **non enregistrés en base** (module « enfants ») : le bébé né existe dans le jeu jusqu'au redémarrage ; la naissance est journalisée (`rp_pregnancy_events`).
5. La démarche lourde remplace la démarche choisie par un autre script (ex. rpemotes) pendant l'effet ; elle est retirée à la fin.
