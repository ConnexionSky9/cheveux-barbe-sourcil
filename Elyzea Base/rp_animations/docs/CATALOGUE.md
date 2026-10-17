# Catalogue technique rp_animations

Généré automatiquement depuis `shared/catalog.lua` (`python3 tests/gen_catalogue.py`). Ne pas modifier à la main.

**Bilan : À valider en jeu : 41 · À créer : 29** (sur 70 fiches).

Statuts :
- **À valider en jeu** : le dictionnaire et le clip sont référencés (noms repris de rpemotes ou du jeu de base) et la ressource
  vérifie au chargement qu'ils existent chez le joueur. Le rendu visuel, l'offset et l'orientation n'ont **pas** encore été
  regardés en jeu. Une fois validée, le staff tape `/rpanim_valider <id>` et la fiche passe en « Native validée ».
- **À créer** : aucun clip existant ne correspond ; il faut produire une animation personnalisée (docs/ANIMATIONS_PERSONNALISEES.md).
  La fiche apparaît grisée dans le menu avec un message clair.
- **Native validée** / **Personnalisée produite et testée** : aucune pour l'instant (aucun test en jeu n'a pu être fait).

## Tableau

| N° | Identifiant | Nom | Catégorie | Type | Source | Statut |
|---|---|---|---|---|---|---|
| 1 | `slow_classique` | Slow classique | Slow et danses de mariage | duo | rpemotes (fichiers tiers streamés) | À valider en jeu |
| 2 | `slow_rapproche` | Slow rapproché | Slow et danses de mariage | duo | rpemotes (fichiers tiers streamés) | À valider en jeu |
| 3 | `slow_elegant` | Slow élégant | Slow et danses de mariage | duo | rpemotes (fichiers tiers streamés) | À valider en jeu |
| 4 | `slow_balancement` | Slow avec balancement | Slow et danses de mariage | duo | rpemotes (fichiers tiers streamés) | À valider en jeu |
| 5 | `slow_rotations` | Slow avec rotations | Slow et danses de mariage | duo | Création rp_animations | À créer |
| 6 | `slow_rapprochement` | Slow avec rapprochement progressif | Slow et danses de mariage | duo | rpemotes (fichiers tiers streamés) | À valider en jeu |
| 7 | `romantique_mains` | Danse romantique avec les mains | Danses romantiques | duo | Création rp_animations | À créer |
| 8 | `couple_enlace` | Danse de couple enlacé | Danses romantiques | duo | GTA V (jeu de base) | À valider en jeu |
| 9 | `romantique_positions` | Danse romantique avec changement de position | Danses romantiques | duo | rpemotes (fichiers tiers streamés) | À valider en jeu |
| 10 | `danse_mariage` | Danse de mariage | Slow et danses de mariage | duo | rpemotes (fichiers tiers streamés) | À valider en jeu |
| 11 | `valse_classique` | Valse classique | Slow et danses de mariage | duo | Création rp_animations | À créer |
| 12 | `valse_mariage` | Valse de mariage | Slow et danses de mariage | duo | Création rp_animations | À créer |
| 13 | `tango_elegant` | Tango élégant | Bachata et tango | duo | Création rp_animations | À créer |
| 14 | `tango_romantique` | Tango romantique | Bachata et tango | duo | Création rp_animations | À créer |
| 15 | `salsa_debutant` | Salsa débutant | Salsa et danses latines | duo | Création rp_animations | À créer |
| 16 | `salsa_dynamique` | Salsa dynamique | Salsa et danses latines | duo | Création rp_animations | À créer |
| 17 | `salsa_rotations` | Salsa avec rotations | Salsa et danses latines | duo | Création rp_animations | À créer |
| 18 | `salsa_guidage` | Salsa avec guidage du partenaire | Salsa et danses latines | duo | Création rp_animations | À créer |
| 19 | `salsa_solo` | Salsa solo | Salsa et danses latines | solo | GTA V (jeu de base) | À valider en jeu |
| 20 | `bachata_classique` | Bachata classique | Bachata et tango | duo | Création rp_animations | À créer |
| 21 | `bachata_romantique` | Bachata romantique | Bachata et tango | duo | Création rp_animations | À créer |
| 22 | `bachata_sensuelle` | Bachata sensuelle | Bachata et tango | duo | Création rp_animations | À créer |
| 23 | `bachata_solo` | Bachata solo | Bachata et tango | solo | Création rp_animations | À créer |
| 24 | `merengue` | Merengue | Salsa et danses latines | duo | Création rp_animations | À créer |
| 25 | `kizomba` | Kizomba | Salsa et danses latines | duo | Création rp_animations | À créer |
| 26 | `latine_festive` | Danse latine festive | Salsa et danses latines | duo | Création rp_animations | À créer |
| 27 | `colle_lent` | Collé-serré lent | Collé-serré | duo | rpemotes (fichiers tiers streamés) | À valider en jeu |
| 28 | `colle_rythme` | Collé-serré rythmé | Collé-serré | duo | Création rp_animations | À créer |
| 29 | `rapprochee_boite` | Danse rapprochée de boîte de nuit | Danses de soirée | duo | GTA V (jeu de base) | À valider en jeu |
| 30 | `couple_sensuelle` | Danse de couple sensuelle | Collé-serré | duo | Création rp_animations | À créer |
| 31 | `rotations_rapprochees` | Danse avec rotations rapprochées | Collé-serré | duo | Création rp_animations | À créer |
| 32 | `fin_de_soiree` | Danse romantique de fin de soirée | Danses de soirée | duo | GTA V (jeu de base) | À valider en jeu |
| 33 | `seduction_duo` | Danse de séduction en duo | Séduction | duo | Création rp_animations | À créer |
| 34 | `club_duo` | Danse de club en duo | Danses de soirée | duo | GTA V (jeu de base) | À valider en jeu |
| 35 | `lente_sensuelle` | Danse lente et sensuelle | Collé-serré | duo | Création rp_animations | À créer |
| 36 | `rapprochement_progressif` | Danse avec rapprochement progressif | Collé-serré | duo | rpemotes (fichiers tiers streamés) | À valider en jeu |
| 37 | `etreinte_consentie` | Danse avec étreinte consentie | Collé-serré | duo | rpemotes (fichiers tiers streamés) | À valider en jeu |
| 38 | `solo_elegante_f` | Danse féminine élégante | Danses solo | solo | GTA V (jeu de base) | À valider en jeu |
| 39 | `solo_elegante_m` | Danse masculine élégante | Danses solo | solo | GTA V (jeu de base) | À valider en jeu |
| 40 | `solo_latine` | Danse latine solo | Danses solo | solo | GTA V (jeu de base) | À valider en jeu |
| 41 | `solo_salsa` | Danse salsa solo | Danses solo | solo | GTA V (jeu de base) | À valider en jeu |
| 42 | `solo_bachata` | Danse bachata solo | Danses solo | solo | Création rp_animations | À créer |
| 43 | `solo_festive` | Danse festive | Danses de soirée | solo | GTA V (jeu de base) | À valider en jeu |
| 44 | `solo_energique` | Danse énergique de boîte de nuit | Danses de soirée | solo | GTA V (jeu de base) | À valider en jeu |
| 45 | `solo_jambes` | Danse avec jeu de jambes | Danses de soirée | solo | GTA V (jeu de base) | À valider en jeu |
| 46 | `solo_rotations` | Danse avec rotations | Danses de soirée | solo | Création rp_animations | À créer |
| 47 | `solo_lente` | Danse lente solo | Danses solo | solo | GTA V (jeu de base) | À valider en jeu |
| 48 | `solo_seduction` | Danse de séduction solo | Séduction | solo | GTA V (jeu de base) | À valider en jeu |
| 49 | `solo_sensuelle` | Danse sensuelle solo | Séduction | solo | GTA V (jeu de base) | À valider en jeu |
| 50 | `solo_celebration` | Danse de célébration | Danses de soirée | solo | GTA V (jeu de base) | À valider en jeu |
| 51 | `inviter_danser` | Inviter à danser | Animations complémentaires | solo | GTA V (jeu de base) | À valider en jeu |
| 52 | `prendre_mains` | Prendre les mains | Animations complémentaires | duo | rpemotes (fichiers tiers streamés) | À valider en jeu |
| 53 | `faire_tourner` | Faire tourner son partenaire | Animations complémentaires | duo | Création rp_animations | À créer |
| 54 | `fin_etreinte` | Terminer une danse par une étreinte | Animations complémentaires | duo | GTA V (jeu de base) | À valider en jeu |
| 55 | `calin_apres` | Câlin après la danse | Animations complémentaires | duo | GTA V (jeu de base) | À valider en jeu |
| 56 | `baiser_romantique` | Baiser romantique en duo | Animations complémentaires | duo | rpemotes (fichiers tiers streamés) | À valider en jeu |
| 57 | `pose_photo` | Pose romantique pour une photo | Animations complémentaires | duo | rpemotes (fichiers tiers streamés) | À valider en jeu |
| 58 | `fin_elegante` | Fin de danse élégante | Animations complémentaires | duo | Création rp_animations | À créer |
| 59 | `etreinte_prolongee` | Étreinte prolongée | Animations complémentaires | duo | rpemotes (fichiers tiers streamés) | À valider en jeu |
| 60 | `rapprochement_visage` | Rapprochement du visage | Animations complémentaires | duo | rpemotes (fichiers tiers streamés) | À valider en jeu |
| 61 | `adulte_tres_rapprochee` | Danse très rapprochée | Animations adultes suggestives | duo | Création rp_animations | À créer |
| 62 | `adulte_seduction_lente` | Danse de séduction lente | Animations adultes suggestives | solo | GTA V (jeu de base) | À valider en jeu |
| 63 | `adulte_etreinte` | Étreinte sensuelle | Animations adultes suggestives | duo | rpemotes (fichiers tiers streamés) | À valider en jeu |
| 64 | `adulte_couple_intime` | Danse de couple intime | Animations adultes suggestives | duo | Création rp_animations | À créer |
| 65 | `adulte_rapprochement` | Rapprochement romantique | Animations adultes suggestives | duo | rpemotes (fichiers tiers streamés) | À valider en jeu |
| 66 | `adulte_pose_duo` | Pose sensuelle en duo | Animations adultes suggestives | duo | rpemotes (fichiers tiers streamés) | À valider en jeu |
| 67 | `adulte_interaction` | Interaction de couple suggestive | Animations adultes suggestives | duo | Création rp_animations | À créer |
| 68 | `adulte_scene_privee` | Transition vers une scène privée | Animations adultes suggestives | duo | rpemotes (fichiers tiers streamés) | À valider en jeu |
| 69 | `adulte_seduction_poses` | Séduction avec changement de pose | Animations adultes suggestives | solo | rpemotes (fichiers tiers streamés) | À valider en jeu |
| 70 | `adulte_boite` | Danse suggestive de boîte de nuit | Animations adultes suggestives | solo | GTA V (jeu de base) | À valider en jeu |

## Fiches détaillées

### 1. Slow classique  (`slow_classique`)

- Catégorie : Slow et danses de mariage · Type : duo · Source : rpemotes (fichiers tiers streamés)
- Statut : **À valider en jeu**
- Description : Le couple se tient et se balance doucement.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Lecture : boucle
  - Étape 1 (boucle) : A `mx_couple5_1_a` / `mx_couple5_1_a_clip` · B `mx_couple5_1_b` / `mx_couple5_1_b_clip` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Dépendances : rpemotes
- Origine des noms de clips : rpemotes (via elyzea_animations/anim_data.lua) : holdme / holdmeb

### 2. Slow rapproché  (`slow_rapproche`)

- Catégorie : Slow et danses de mariage · Type : duo · Source : rpemotes (fichiers tiers streamés)
- Statut : **À valider en jeu**
- Description : Variante plus serrée du slow.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Lecture : boucle
  - Étape 1 (boucle) : A `mx_couple5_2_a` / `mx_couple5_2_a_clip` · B `mx_couple5_2_b` / `mx_couple5_2_b_clip` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Dépendances : rpemotes
- Origine des noms de clips : rpemotes (via elyzea_animations/anim_data.lua) : holdmec / holdmed

### 3. Slow élégant  (`slow_elegant`)

- Catégorie : Slow et danses de mariage · Type : duo · Source : rpemotes (fichiers tiers streamés)
- Statut : **À valider en jeu**
- Description : Tenue de danse de cérémonie.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Lecture : boucle
  - Étape 1 (boucle) : A `EnchantedBrwny@wedding1a` / `wedding1a` · B `EnchantedBrwny@wedding1b` / `wedding1b` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Dépendances : rpemotes
- Origine des noms de clips : rpemotes (via elyzea_animations/anim_data.lua) : couplewed1a / couplewed1b

### 4. Slow avec balancement  (`slow_balancement`)

- Catégorie : Slow et danses de mariage · Type : duo · Source : rpemotes (fichiers tiers streamés)
- Statut : **À valider en jeu**
- Description : Le couple enlacé se balance.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Lecture : boucle
  - Étape 1 (boucle) : A `mx_couple5_3_a` / `mx_couple5_3_a_clip` · B `mx_couple5_3_b` / `mx_couple5_3_b_clip` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Dépendances : rpemotes
- Origine des noms de clips : rpemotes (via elyzea_animations/anim_data.lua) : holdmee / holdmef

### 5. Slow avec rotations  (`slow_rotations`)

- Catégorie : Slow et danses de mariage · Type : duo · Source : Création rp_animations
- Statut : **À créer**
- Description : Slow avec tours lents du couple.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 6. Slow avec rapprochement progressif  (`slow_rapprochement`)

- Catégorie : Slow et danses de mariage · Type : duo · Source : rpemotes (fichiers tiers streamés)
- Statut : **À valider en jeu**
- Description : Mains dans les mains, puis enlacés, puis slow.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Lecture : boucle
  - Étape 1 (8 s) : A `amnilka@photopose@couple@couplefirst` / `amnilka_couple_mal_005` · B `amnilka@photopose@couple@couplefirst` / `amnilka_couple_fem_005` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
  - Étape 2 (8 s) : A `amnilka@photopose@couple@couplefirst` / `amnilka_couple_mal_001` · B `amnilka@photopose@couple@couplefirst` / `amnilka_couple_fem_001` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
  - Étape 3 (boucle) : A `mx_couple5_1_a` / `mx_couple5_1_a_clip` · B `mx_couple5_1_b` / `mx_couple5_1_b_clip` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Dépendances : rpemotes
- Origine des noms de clips : rpemotes (via elyzea_animations/anim_data.lua)
- Remarque : Enchaînement de trois clips existants (fondu de 0,5 s entre chaque) : ce n'est pas un mouvement continu.

### 7. Danse romantique avec les mains  (`romantique_mains`)

- Catégorie : Danses romantiques · Type : duo · Source : Création rp_animations
- Statut : **À créer**
- Description : Danse en se tenant les mains, bras tendus.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 8. Danse de couple enlacé  (`couple_enlace`)

- Catégorie : Danses romantiques · Type : duo · Source : GTA V (jeu de base)
- Statut : **À valider en jeu**
- Description : Les bras autour de l'autre, longuement.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Lecture : boucle
  - Étape 1 (boucle) : A `misscarsteal2chad_goodbye` / `chad_armsaround_chad` · B `misscarsteal2chad_goodbye` / `chad_armsaround_girl` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Origine des noms de clips : GTA V (mission Chad) : hugr / hugr2 de rpemotes

### 9. Danse romantique avec changement de position  (`romantique_positions`)

- Catégorie : Danses romantiques · Type : duo · Source : rpemotes (fichiers tiers streamés)
- Statut : **À valider en jeu**
- Description : Trois tenues de slow qui s'enchaînent en boucle.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Lecture : cycle (les étapes recommencent)
  - Étape 1 (10 s) : A `mx_couple5_1_a` / `mx_couple5_1_a_clip` · B `mx_couple5_1_b` / `mx_couple5_1_b_clip` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
  - Étape 2 (10 s) : A `mx_couple5_2_a` / `mx_couple5_2_a_clip` · B `mx_couple5_2_b` / `mx_couple5_2_b_clip` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
  - Étape 3 (10 s) : A `mx_couple5_3_a` / `mx_couple5_3_a_clip` · B `mx_couple5_3_b` / `mx_couple5_3_b_clip` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Dépendances : rpemotes
- Origine des noms de clips : rpemotes (via elyzea_animations/anim_data.lua)

### 10. Danse de mariage  (`danse_mariage`)

- Catégorie : Slow et danses de mariage · Type : duo · Source : rpemotes (fichiers tiers streamés)
- Statut : **À valider en jeu**
- Description : La première danse des mariés.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Lecture : boucle
  - Étape 1 (boucle) : A `EnchantedBrwny@wedding2b` / `wedding2b` · B `EnchantedBrwny@wedding2a` / `wedding2a` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Dépendances : rpemotes
- Origine des noms de clips : rpemotes (via elyzea_animations/anim_data.lua) : couplewed2a / couplewed2b

### 11. Valse classique  (`valse_classique`)

- Catégorie : Slow et danses de mariage · Type : duo · Source : Création rp_animations
- Statut : **À créer**
- Description : Pas de valse à trois temps en tournant.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 12. Valse de mariage  (`valse_mariage`)

- Catégorie : Slow et danses de mariage · Type : duo · Source : Création rp_animations
- Statut : **À créer**
- Description : Valse lente de cérémonie.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 13. Tango élégant  (`tango_elegant`)

- Catégorie : Bachata et tango · Type : duo · Source : Création rp_animations
- Statut : **À créer**
- Description : Marche de tango, tenue fermée.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 14. Tango romantique  (`tango_romantique`)

- Catégorie : Bachata et tango · Type : duo · Source : Création rp_animations
- Statut : **À créer**
- Description : Tango lent avec arrêts et regards.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 15. Salsa débutant  (`salsa_debutant`)

- Catégorie : Salsa et danses latines · Type : duo · Source : Création rp_animations
- Statut : **À créer**
- Description : Pas de base de salsa face à face.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 16. Salsa dynamique  (`salsa_dynamique`)

- Catégorie : Salsa et danses latines · Type : duo · Source : Création rp_animations
- Statut : **À créer**
- Description : Salsa rapide.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 17. Salsa avec rotations  (`salsa_rotations`)

- Catégorie : Salsa et danses latines · Type : duo · Source : Création rp_animations
- Statut : **À créer**
- Description : Salsa avec passes et tours.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 18. Salsa avec guidage du partenaire  (`salsa_guidage`)

- Catégorie : Salsa et danses latines · Type : duo · Source : Création rp_animations
- Statut : **À créer**
- Description : Le guide fait tourner sa ou son partenaire.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 19. Salsa solo  (`salsa_solo`)

- Catégorie : Salsa et danses latines · Type : solo · Source : GTA V (jeu de base)
- Statut : **À valider en jeu**
- Description : Mouvement de bras salsa.
- Lecture : boucle · le joueur peut marcher (haut du corps)
  - Étape 1 (boucle) : A `anim@mp_player_intuppersalsa_roll` / `idle_a`
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule
- Origine des noms de clips : GTA V : emote salsa de rpemotes
- Remarque : Approximation : animation du haut du corps seulement (on peut marcher en même temps).

### 20. Bachata classique  (`bachata_classique`)

- Catégorie : Bachata et tango · Type : duo · Source : Création rp_animations
- Statut : **À créer**
- Description : Pas de bachata, tenue fermée.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 21. Bachata romantique  (`bachata_romantique`)

- Catégorie : Bachata et tango · Type : duo · Source : Création rp_animations
- Statut : **À créer**
- Description : Bachata lente et proche.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 22. Bachata sensuelle  (`bachata_sensuelle`)

- Catégorie : Bachata et tango · Type : duo · Source : Création rp_animations
- Statut : **À créer**
- Description : Bachata sensuelle avec ondulations.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 23. Bachata solo  (`bachata_solo`)

- Catégorie : Bachata et tango · Type : solo · Source : Création rp_animations
- Statut : **À créer**
- Description : Pas de bachata seul.
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 24. Merengue  (`merengue`)

- Catégorie : Salsa et danses latines · Type : duo · Source : Création rp_animations
- Statut : **À créer**
- Description : Pas de merengue sur place.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 25. Kizomba  (`kizomba`)

- Catégorie : Salsa et danses latines · Type : duo · Source : Création rp_animations
- Statut : **À créer**
- Description : Kizomba lente et collée.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 26. Danse latine festive  (`latine_festive`)

- Catégorie : Salsa et danses latines · Type : duo · Source : Création rp_animations
- Statut : **À créer**
- Description : Danse latine joyeuse face à face.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 27. Collé-serré lent  (`colle_lent`)

- Catégorie : Collé-serré · Type : duo · Source : rpemotes (fichiers tiers streamés)
- Statut : **À valider en jeu**
- Description : Le couple serré l'un contre l'autre.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Lecture : boucle
  - Étape 1 (boucle) : A `anim@male_couple_03_b` / `m_couple_03_b_clip` · B `anim@female_couple_03_b` / `f_couple_03_b_clip` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Dépendances : rpemotes
- Origine des noms de clips : rpemotes (via elyzea_animations/anim_data.lua) : bff / bffb
- Remarque : Rendu exact du clip non vu : à valider en jeu.

### 28. Collé-serré rythmé  (`colle_rythme`)

- Catégorie : Collé-serré · Type : duo · Source : Création rp_animations
- Statut : **À créer**
- Description : Collé-serré sur un rythme plus marqué.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 29. Danse rapprochée de boîte de nuit  (`rapprochee_boite`)

- Catégorie : Danses de soirée · Type : duo · Source : GTA V (jeu de base)
- Statut : **À valider en jeu**
- Description : Danse de club face à face, proches.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Lecture : boucle
  - Étape 1 (boucle) : A `anim@amb@nightclub@mini@dance@dance_paired@dance_a@` / `ped_a_dance_idle` · B `anim@amb@nightclub@mini@dance@dance_paired@dance_a@` / `ped_b_dance_idle` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Origine des noms de clips : Dictionnaire GTA (rpemotes utilise ped_a_dance_idle) ; clip ped_b_dance_idle supposé, vérifié au chargement

### 30. Danse de couple sensuelle  (`couple_sensuelle`)

- Catégorie : Collé-serré · Type : duo · Source : Création rp_animations
- Statut : **À créer**
- Description : Danse lente avec ondulations.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 31. Danse avec rotations rapprochées  (`rotations_rapprochees`)

- Catégorie : Collé-serré · Type : duo · Source : Création rp_animations
- Statut : **À créer**
- Description : Tours lents en restant serrés.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 32. Danse romantique de fin de soirée  (`fin_de_soiree`)

- Catégorie : Danses de soirée · Type : duo · Source : GTA V (jeu de base)
- Statut : **À valider en jeu**
- Description : Une dernière danse puis on s'enlace.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Lecture : boucle
  - Étape 1 (12 s) : A `anim@amb@nightclub@mini@dance@dance_paired@dance_b@` / `ped_a_dance_idle` · B `anim@amb@nightclub@mini@dance@dance_paired@dance_b@` / `ped_b_dance_idle` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
  - Étape 2 (boucle) : A `misscarsteal2chad_goodbye` / `chad_armsaround_chad` · B `misscarsteal2chad_goodbye` / `chad_armsaround_girl` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Origine des noms de clips : Dictionnaire GTA (rpemotes utilise ped_a_dance_idle) ; clip ped_b_dance_idle supposé, vérifié au chargement

### 33. Danse de séduction en duo  (`seduction_duo`)

- Catégorie : Séduction · Type : duo · Source : Création rp_animations
- Statut : **À créer**
- Description : Jeu de séduction dansé à deux.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 34. Danse de club en duo  (`club_duo`)

- Catégorie : Danses de soirée · Type : duo · Source : GTA V (jeu de base)
- Statut : **À valider en jeu**
- Description : Danse de boîte de nuit à deux.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Lecture : boucle
  - Étape 1 (boucle) : A `anim@amb@nightclub@mini@dance@dance_paired@dance_d@` / `ped_a_dance_idle` · B `anim@amb@nightclub@mini@dance@dance_paired@dance_d@` / `ped_b_dance_idle` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Origine des noms de clips : Dictionnaire GTA (rpemotes utilise ped_a_dance_idle) ; clip ped_b_dance_idle supposé, vérifié au chargement

### 35. Danse lente et sensuelle  (`lente_sensuelle`)

- Catégorie : Collé-serré · Type : duo · Source : Création rp_animations
- Statut : **À créer**
- Description : Danse très lente, corps proches.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 36. Danse avec rapprochement progressif  (`rapprochement_progressif`)

- Catégorie : Collé-serré · Type : duo · Source : rpemotes (fichiers tiers streamés)
- Statut : **À valider en jeu**
- Description : On danse face à face, puis on se rapproche.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Lecture : boucle
  - Étape 1 (10 s) : A `anim@amb@nightclub@mini@dance@dance_paired@dance_a@` / `ped_a_dance_idle` · B `anim@amb@nightclub@mini@dance@dance_paired@dance_a@` / `ped_b_dance_idle` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
  - Étape 2 (boucle) : A `mx_couple5_2_a` / `mx_couple5_2_a_clip` · B `mx_couple5_2_b` / `mx_couple5_2_b_clip` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Dépendances : rpemotes
- Origine des noms de clips : Dictionnaire GTA (rpemotes utilise ped_a_dance_idle) ; clip ped_b_dance_idle supposé, vérifié au chargement + rpemotes (via elyzea_animations/anim_data.lua)
- Remarque : Enchaînement de deux clips existants.

### 37. Danse avec étreinte consentie  (`etreinte_consentie`)

- Catégorie : Collé-serré · Type : duo · Source : rpemotes (fichiers tiers streamés)
- Statut : **À valider en jeu**
- Description : Une étreinte affectueuse.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Lecture : boucle
  - Étape 1 (boucle) : A `littlespoon@friendship007` / `friendship007` · B `littlespoon@friendship008` / `friendship008` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Dépendances : rpemotes
- Origine des noms de clips : rpemotes (via elyzea_animations/anim_data.lua) : hugtip / hugtip2

### 38. Danse féminine élégante  (`solo_elegante_f`)

- Catégorie : Danses solo · Type : solo · Source : GTA V (jeu de base)
- Statut : **À valider en jeu**
- Description : Style féminin, fonctionne sur tous les personnages.
- Lecture : boucle
  - Étape 1 (boucle) : A `anim@amb@nightclub@dancers@solomun_entourage@` / `mi_dance_facedj_17_v1_female^1`
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule
- Origine des noms de clips : GTA V : dancef de rpemotes

### 39. Danse masculine élégante  (`solo_elegante_m`)

- Catégorie : Danses solo · Type : solo · Source : GTA V (jeu de base)
- Statut : **À valider en jeu**
- Description : Style masculin sobre, fonctionne sur tous les personnages.
- Lecture : boucle
  - Étape 1 (boucle) : A `anim@amb@nightclub@mini@dance@dance_solo@male@var_a@` / `low_center`
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule
- Origine des noms de clips : GTA V : danceshy de rpemotes

### 40. Danse latine solo  (`solo_latine`)

- Catégorie : Danses solo · Type : solo · Source : GTA V (jeu de base)
- Statut : **À valider en jeu**
- Description : Déhanché aux accents orientaux et latins.
- Lecture : boucle
  - Étape 1 (boucle) : A `anim@amb@nightclub@lazlow@hi_railing@` / `ambclub_09_mi_hi_bellydancer_laz`
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule
- Origine des noms de clips : GTA V : danceglowstick3 de rpemotes (sans les bâtons)
- Remarque : Approximation : danse du ventre de club.

### 41. Danse salsa solo  (`solo_salsa`)

- Catégorie : Danses solo · Type : solo · Source : GTA V (jeu de base)
- Statut : **À valider en jeu**
- Description : Petits pas balancés.
- Lecture : boucle
  - Étape 1 (boucle) : A `anim@amb@casino@mini@dance@dance_solo@female@var_a@` / `med_center`
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule
- Origine des noms de clips : GTA V : dance5 de rpemotes
- Remarque : Approximation : pas de vrai pas de salsa dans GTA V.

### 42. Danse bachata solo  (`solo_bachata`)

- Catégorie : Danses solo · Type : solo · Source : Création rp_animations
- Statut : **À créer**
- Description : Pas de bachata seul.
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 43. Danse festive  (`solo_festive`)

- Catégorie : Danses de soirée · Type : solo · Source : GTA V (jeu de base)
- Statut : **À valider en jeu**
- Description : La danse « woogie », joyeuse.
- Lecture : boucle
  - Étape 1 (boucle) : A `anim@mp_player_intcelebrationfemale@the_woogie` / `the_woogie`
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule
- Origine des noms de clips : GTA V : dancesilly9 de rpemotes

### 44. Danse énergique de boîte de nuit  (`solo_energique`)

- Catégorie : Danses de soirée · Type : solo · Source : GTA V (jeu de base)
- Statut : **À valider en jeu**
- Description : Haute intensité, face au DJ.
- Lecture : boucle
  - Étape 1 (boucle) : A `anim@amb@nightclub@dancers@crowddance_facedj@hi_intensity` / `hi_dance_facedj_09_v2_female^1`
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule
- Origine des noms de clips : GTA V : dancef4 de rpemotes

### 45. Danse avec jeu de jambes  (`solo_jambes`)

- Catégorie : Danses de soirée · Type : solo · Source : GTA V (jeu de base)
- Statut : **À valider en jeu**
- Description : Shuffle, les pieds en avant.
- Lecture : boucle
  - Étape 1 (boucle) : A `anim@amb@nightclub@mini@dance@dance_solo@shuffle@` / `high_center`
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule
- Origine des noms de clips : GTA V : danceclubo de rpemotes

### 46. Danse avec rotations  (`solo_rotations`)

- Catégorie : Danses de soirée · Type : solo · Source : Création rp_animations
- Statut : **À créer**
- Description : Danse solo avec pirouettes.
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 47. Danse lente solo  (`solo_lente`)

- Catégorie : Danses solo · Type : solo · Source : GTA V (jeu de base)
- Statut : **À valider en jeu**
- Description : Balancement doux.
- Lecture : boucle
  - Étape 1 (boucle) : A `anim@amb@nightclub@mini@dance@dance_solo@female@var_a@` / `low_center`
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule
- Origine des noms de clips : GTA V : danceslow2 de rpemotes

### 48. Danse de séduction solo  (`solo_seduction`)

- Catégorie : Séduction · Type : solo · Source : GTA V (jeu de base)
- Statut : **À valider en jeu**
- Description : Danse de club lascive.
- Lecture : boucle
  - Étape 1 (boucle) : A `anim@amb@nightclub_island@dancers@club@` / `hi_idle_a_f02`
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule
- Origine des noms de clips : GTA V : danceclube de rpemotes

### 49. Danse sensuelle solo  (`solo_sensuelle`)

- Catégorie : Séduction · Type : solo · Source : GTA V (jeu de base)
- Statut : **À valider en jeu** · Adulte (option + confirmation explicite)
- Description : Danse de club très suggestive.
- Lecture : boucle
  - Étape 1 (boucle) : A `anim@amb@nightclub@lazlow@hi_railing@` / `ambclub_13_mi_hi_sexualgriding_laz`
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule
- Origine des noms de clips : GTA V : danceglowstick de rpemotes (sans les bâtons)

### 50. Danse de célébration  (`solo_celebration`)

- Catégorie : Danses de soirée · Type : solo · Source : GTA V (jeu de base)
- Statut : **À valider en jeu**
- Description : On fête une victoire.
- Lecture : boucle
  - Étape 1 (boucle) : A `anim@mp_celebration@idles@female` / `celebration_idle_f_a`
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule
- Origine des noms de clips : GTA V : idle4 de rpemotes

### 51. Inviter à danser  (`inviter_danser`)

- Catégorie : Animations complémentaires · Type : solo · Source : GTA V (jeu de base)
- Statut : **À valider en jeu**
- Description : Un geste doux de la main : « viens ».
- Lecture : une fois (fin automatique) · le joueur peut marcher (haut du corps)
  - Étape 1 (jusqu'à la fin du clip) : A `gestures@m@standing@casual` / `gesture_come_here_soft`
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule
- Origine des noms de clips : GTA V : dictionnaire présent dans rpemotes ; clip gesture_come_here_soft vérifié au chargement

### 52. Prendre les mains  (`prendre_mains`)

- Catégorie : Animations complémentaires · Type : duo · Source : rpemotes (fichiers tiers streamés)
- Statut : **À valider en jeu**
- Description : Se tenir les mains face à face.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Lecture : boucle
  - Étape 1 (boucle) : A `amnilka@photopose@couple@couplefirst` / `amnilka_couple_mal_005` · B `amnilka@photopose@couple@couplefirst` / `amnilka_couple_fem_005` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Dépendances : rpemotes
- Origine des noms de clips : rpemotes (via elyzea_animations/anim_data.lua) : couplehhands

### 53. Faire tourner son partenaire  (`faire_tourner`)

- Catégorie : Animations complémentaires · Type : duo · Source : Création rp_animations
- Statut : **À créer**
- Description : Le guide fait tourner sa ou son partenaire sous son bras.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 54. Terminer une danse par une étreinte  (`fin_etreinte`)

- Catégorie : Animations complémentaires · Type : duo · Source : GTA V (jeu de base)
- Statut : **À valider en jeu**
- Description : Quelques pas puis une étreinte.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Lecture : boucle
  - Étape 1 (10 s) : A `anim@amb@nightclub@mini@dance@dance_paired@dance_a@` / `ped_a_dance_idle` · B `anim@amb@nightclub@mini@dance@dance_paired@dance_a@` / `ped_b_dance_idle` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
  - Étape 2 (boucle) : A `misscarsteal2chad_goodbye` / `chad_armsaround_chad` · B `misscarsteal2chad_goodbye` / `chad_armsaround_girl` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Origine des noms de clips : Dictionnaire GTA (rpemotes utilise ped_a_dance_idle) ; clip ped_b_dance_idle supposé, vérifié au chargement

### 55. Câlin après la danse  (`calin_apres`)

- Catégorie : Animations complémentaires · Type : duo · Source : GTA V (jeu de base)
- Statut : **À valider en jeu**
- Description : Bise et accolade, quelques secondes.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Lecture : une fois (fin automatique)
  - Étape 1 (jusqu'à la fin du clip) : A `mp_ped_interaction` / `kisses_guy_a` · B `mp_ped_interaction` / `kisses_guy_b` · offset B/A : x 0, y 1.05, z 0, h 180 (estimation, à calibrer)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Origine des noms de clips : GTA V : hug / hug2 de rpemotes

### 56. Baiser romantique en duo  (`baiser_romantique`)

- Catégorie : Animations complémentaires · Type : duo · Source : rpemotes (fichiers tiers streamés)
- Statut : **À valider en jeu**
- Description : Un baiser tendre.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Lecture : boucle
  - Étape 1 (boucle) : A `chocoholic@couple13` / `couple13_clip` · B `chocoholic@couple14` / `couple14_clip` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Dépendances : rpemotes
- Origine des noms de clips : rpemotes (via elyzea_animations/anim_data.lua) : kisslips / kisslips2

### 57. Pose romantique pour une photo  (`pose_photo`)

- Catégorie : Animations complémentaires · Type : duo · Source : rpemotes (fichiers tiers streamés)
- Statut : **À valider en jeu**
- Description : Pose de couple pour la photo.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Lecture : boucle
  - Étape 1 (boucle) : A `amnilka@photopose@couple@couplefirst` / `amnilka_couple_mal_004` · B `amnilka@photopose@couple@couplefirst` / `amnilka_couple_fem_004` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Dépendances : rpemotes
- Origine des noms de clips : rpemotes (via elyzea_animations/anim_data.lua) : cutepicpose

### 58. Fin de danse élégante  (`fin_elegante`)

- Catégorie : Animations complémentaires · Type : duo · Source : Création rp_animations
- Statut : **À créer**
- Description : Révérence et salut de fin de danse.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 59. Étreinte prolongée  (`etreinte_prolongee`)

- Catégorie : Animations complémentaires · Type : duo · Source : rpemotes (fichiers tiers streamés)
- Statut : **À valider en jeu**
- Description : Rester enlacés.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Lecture : boucle
  - Étape 1 (boucle) : A `amnilka@photopose@couple@couplefirst` / `amnilka_couple_mal_001` · B `amnilka@photopose@couple@couplefirst` / `amnilka_couple_fem_001` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Dépendances : rpemotes
- Origine des noms de clips : rpemotes (via elyzea_animations/anim_data.lua) : hugpose

### 60. Rapprochement du visage  (`rapprochement_visage`)

- Catégorie : Animations complémentaires · Type : duo · Source : rpemotes (fichiers tiers streamés)
- Statut : **À valider en jeu**
- Description : Front contre front, baiser sur le front.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Lecture : boucle
  - Étape 1 (boucle) : A `genesismods_kissme@kissmale10` / `kissmale10` · B `genesismods_kissme@kissfemale10` / `kissfemale10` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Dépendances : rpemotes
- Origine des noms de clips : rpemotes (via elyzea_animations/anim_data.lua) : kisscutefh

### 61. Danse très rapprochée  (`adulte_tres_rapprochee`)

- Catégorie : Animations adultes suggestives · Type : duo · Source : Création rp_animations
- Statut : **À créer** · Adulte (option + confirmation explicite)
- Description : Danse corps contre corps.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 62. Danse de séduction lente  (`adulte_seduction_lente`)

- Catégorie : Animations adultes suggestives · Type : solo · Source : GTA V (jeu de base)
- Statut : **À valider en jeu** · Adulte (option + confirmation explicite)
- Description : Danse privée lente, debout.
- Lecture : boucle
  - Étape 1 (boucle) : A `mini@strip_club@private_dance@idle` / `priv_dance_idle`
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule
- Origine des noms de clips : GTA V : lapdance2 de rpemotes

### 63. Étreinte sensuelle  (`adulte_etreinte`)

- Catégorie : Animations adultes suggestives · Type : duo · Source : rpemotes (fichiers tiers streamés)
- Statut : **À valider en jeu** · Adulte (option + confirmation explicite)
- Description : Baiser dans le cou.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Lecture : boucle
  - Étape 1 (boucle) : A `genesismods_kissme@kissmale8` / `kissmale8` · B `genesismods_kissme@kissfemale8` / `kissfemale8` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Dépendances : rpemotes
- Origine des noms de clips : rpemotes (via elyzea_animations/anim_data.lua) : kisscuteneck

### 64. Danse de couple intime  (`adulte_couple_intime`)

- Catégorie : Animations adultes suggestives · Type : duo · Source : Création rp_animations
- Statut : **À créer** · Adulte (option + confirmation explicite)
- Description : Danse lente et intime.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 65. Rapprochement romantique  (`adulte_rapprochement`)

- Catégorie : Animations adultes suggestives · Type : duo · Source : rpemotes (fichiers tiers streamés)
- Statut : **À valider en jeu** · Adulte (option + confirmation explicite)
- Description : Bisou sur la joue, puis baiser.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Lecture : boucle
  - Étape 1 (8 s) : A `genesismods_kissme@kissmale9` / `kissmale9` · B `genesismods_kissme@kissfemale9` / `kissfemale9` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
  - Étape 2 (boucle) : A `chocoholic@couple13` / `couple13_clip` · B `chocoholic@couple14` / `couple14_clip` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Dépendances : rpemotes
- Origine des noms de clips : rpemotes (via elyzea_animations/anim_data.lua)

### 66. Pose sensuelle en duo  (`adulte_pose_duo`)

- Catégorie : Animations adultes suggestives · Type : duo · Source : rpemotes (fichiers tiers streamés)
- Statut : **À valider en jeu** · Adulte (option + confirmation explicite)
- Description : L'un soulève l'autre.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Lecture : boucle
  - Étape 1 (boucle) : A `couplepose1pack1anim2@animation` / `couplepose1pack1anim2_clip` · B `couplepose1pack1anim1@animation` / `couplepose1pack1anim1_clip` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Dépendances : rpemotes
- Origine des noms de clips : rpemotes (via elyzea_animations/anim_data.lua) : liftme / liftme2
- Remarque : Rendu exact du clip non vu : à valider en jeu.

### 67. Interaction de couple suggestive  (`adulte_interaction`)

- Catégorie : Animations adultes suggestives · Type : duo · Source : Création rp_animations
- Statut : **À créer** · Adulte (option + confirmation explicite)
- Description : Jeu de couple suggestif, habillé.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Remarque : Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).

### 68. Transition vers une scène privée  (`adulte_scene_privee`)

- Catégorie : Animations adultes suggestives · Type : duo · Source : rpemotes (fichiers tiers streamés)
- Statut : **À valider en jeu** · Adulte (option + confirmation explicite) · Fondu au noir facultatif
- Description : Étreinte puis baiser ; fondu au noir facultatif, choisi par chacun pour soi.
- Rôles : A = Guide (reste sur place, repère) · B = Partenaire (rejoint sa place, attaché à A)
- Lecture : boucle
  - Étape 1 (8 s) : A `misscarsteal2chad_goodbye` / `chad_armsaround_chad` · B `misscarsteal2chad_goodbye` / `chad_armsaround_girl` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
  - Étape 2 (boucle) : A `chocoholic@couple13` / `couple13_clip` · B `chocoholic@couple14` / `couple14_clip` · offset B/A : x 0, y 0, z 0, h 0 (estimation, à calibrer)
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule; les deux participants à moins de 3 m, consentement de B
- Dépendances : rpemotes
- Origine des noms de clips : GTA V + rpemotes (via elyzea_animations/anim_data.lua)

### 69. Séduction avec changement de pose  (`adulte_seduction_poses`)

- Catégorie : Animations adultes suggestives · Type : solo · Source : rpemotes (fichiers tiers streamés)
- Statut : **À valider en jeu** · Adulte (option + confirmation explicite)
- Description : Trois poses qui s'enchaînent.
- Lecture : cycle (les étapes recommencent)
  - Étape 1 (6 s) : A `littlespoon@sexy003` / `sexy003`
  - Étape 2 (6 s) : A `littlespoon@sexy004` / `sexy004`
  - Étape 3 (6 s) : A `littlespoon@sexy005` / `sexy005`
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule
- Dépendances : rpemotes
- Origine des noms de clips : rpemotes (via elyzea_animations/anim_data.lua) : sexypose 1 à 3

### 70. Danse suggestive de boîte de nuit  (`adulte_boite`)

- Catégorie : Animations adultes suggestives · Type : solo · Source : GTA V (jeu de base)
- Statut : **À valider en jeu** · Adulte (option + confirmation explicite)
- Description : Danse de club provocante.
- Lecture : boucle
  - Étape 1 (boucle) : A `anim@amb@nightclub@lazlow@hi_railing@` / `ambclub_12_mi_hi_bootyshake_laz`
- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule
- Origine des noms de clips : GTA V : danceglowstick2 de rpemotes (sans les bâtons)
