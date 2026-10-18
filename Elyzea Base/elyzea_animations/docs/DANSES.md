# Danses du menu K : catalogue, vidéos de référence, limites

## Où sont les danses

Tout est dans le menu habituel (**K**), quatre catégories en tête :

| Catégorie | Contenu | Comment ça se lance |
|---|---|---|
| **Danses lentes** | 8 danses à deux | Choisir la personne (et son rôle) → invitation → acceptation |
| **Danses en duo** | 4 danses à deux | Idem |
| **Danses en groupe** | 6 danses collectives | Cocher les participants, choisir ligne ou cercle → invitations → départ commun |
| **Danses solo** | 111 danses (rpemotes, doublons retirés) | Clic, comme les autres animations (aperçu 3D, placement, favoris, raccourcis) |

Aucun autre menu n'existe : l'ancienne ressource `rp_animations` (menu F7) est supprimée.

## Danses lentes et en duo : positions

Les danses à deux utilisent des animations qui existent réellement : celles du jeu de base et celles que **rpemotes**
diffuse déjà sur ton serveur. Le moteur reprend **exactement** la position et la rotation que rpemotes utilise pour chacune
(fichier `client/AnimationList.lua` de rpemotes-reborn, options `Attachto` / `SyncOffset`), avec les mêmes paramètres
d'attache. C'est ce qui corrige le défaut de la version précédente (personnages côte à côte, même direction).

Ce que ces positions révèlent :
- « Hold Me » 1 et 3 de rpemotes sont des étreintes **par derrière** (rotation 0°) : elles sont dans « Enlacés par derrière ».
- « Hold Me 2 » est **face à face** (rotation −180°, 36 cm) : c'est la base des slows face à face.

| Danse | Catégorie | Animations (meneur / partenaire) | Position du partenaire | Source |
|---|---|---|---|---|
| Slow face à face | Lentes | `mx_couple5_2_a` / `mx_couple5_2_b` | x −0,12 · y 0,36 · z −0,01 · rot −180 | rpemotes (holdmec/holdmed) |
| Slow tournant | Lentes | idem + rotation lente du couple (7°/s) | idem | rpemotes + script |
| Étreinte romantique | Lentes | `misscarsteal2chad_goodbye` girl / chad | côté −0,05 · devant 0,52 · face à face | GTA V (hugr) |
| Danse des mariés | Lentes | `EnchantedBrwny@wedding2b` / `wedding2a` | x 0,01 · y 0,25 · rot −88,9 | rpemotes (couplewed2) |
| Pose des mariés | Lentes | `EnchantedBrwny@wedding1a` / `wedding1b` | x 0,03 · y 1,0 · z 0,02 · rot 130 | rpemotes (couplewed1) |
| Enlacés par derrière | Lentes | `mx_couple5_1_a` / `mx_couple5_1_b` | x −0,02 · y 0,24 · z −0,01 · rot 0 | rpemotes (holdme) |
| Baiser | Lentes | `chocoholic@couple14` / `couple13` | x 0,16 · y 0,27 · rot 130 | rpemotes (kisslips) |
| Slow puis baiser | Lentes | slow face à face 20 s, puis baiser | les deux ci-dessus | rpemotes |
| Danse de club face à face | Duo | clubs `male@var_a` / `female@var_a` `high_center` | 1 m devant, face à face | GTA V |
| Danse en paire (boîte de nuit) | Duo | `dance_paired@dance_a@` `ped_a` / `ped_b_dance_idle` | origine commune | GTA V (clip B à confirmer) |
| Le porté | Duo | `couplepose1pack1anim2` / `anim1` | x 0,002 · y 0,287 · z 0,25 · rot 180 | rpemotes (liftme) |
| Le grand porté | Duo | `couplepose2pack1anim2` / `anim1` | x 0,01 · y 0,48 · z 0,53 · rot 180 | rpemotes (liftme3) |

Groupe (tout le monde joue le même clip, départ commun, phase recalée sur le meneur) :

| Danse | Animation | Formations |
|---|---|---|
| Thriller | `mj_thriller` / `mj_thriller_dance` (rpemotes) | ligne, cercle |
| Soirée club | `crowddance_facedj@hi_intensity` `hi_dance_facedj_09_v2_female^1` (GTA) | cercle, ligne |
| Shuffle | `dance_solo@shuffle@` `high_center` (GTA) | ligne, cercle |
| Robot | `dancing_wave_part_one@anim` `robot_dance` (rpemotes) | ligne, cercle |
| Pas balancés (ligne) | `casino … dance_solo@female@var_a@` `med_center` (GTA) | ligne, cercle |
| Woogie | `the_woogie` (GTA) | cercle, ligne |

Les danses de groupe sont des **mouvements identiques synchronisés**, pas des chorégraphies avec interactions entre
danseurs : aucune animation de ce type n'existe dans GTA V ni dans rpemotes.

Chaque clip est vérifié au démarrage chez le joueur (dictionnaire présent, clip de durée non nulle, pour le meneur **et**
le partenaire). Une danse dont un fichier manque est masquée du menu ; `elyzea_anim_check` en F8 les liste.

## Les quatre vidéos de référence

Les quatre fichiers joints ont été ouverts et analysés image par image. Ce sont des extraits TikTok d'autres serveurs RP.

| Vidéo | Ce qu'on y voit | Type | Le plus proche disponible | Pour l'obtenir vraiment |
|---|---|---|---|---|
| `ScreenRecording_10-18-2026` (3 s, « Le porté de Dirty Dancing ») | Sur la plage, un couple face à face ; l'un soulève et fait tourner l'autre, collé contre lui | Duo, porté dynamique | **Le porté** / **Le grand porté** (poses tenues, sans le mouvement) | Animation personnalisée |
| `v24044gl0000d0orj6nog65o1tq57sv0` (65 s) | Couple sur une jetée la nuit : pas latins (salsa / bachata), mains tenues, tours sous le bras, puis slow enlacé qui se balance | Duo latin + slow | **Slow face à face**, **Slow tournant** | Animation personnalisée pour la partie latine |
| `v26300gc0001d9vbrnvog65g2otpb7mg` (25 s, « SALSA ») | Soirée RP : un menu d'interaction propose « Suivre la chorégraphie » ; plusieurs joueurs dansent les mêmes pas, des couples font la salsa face à face | Groupe synchronisé + duo | **Danses en groupe** (même principe : tout le monde suit, départ commun) ; aucun pas de salsa natif | Animation personnalisée pour les pas de salsa |
| `v24044gl0000d3v2icfog65uf77hthag` (7,5 s) | Appartement : slow face à face, ses bras à elle autour de son cou, ses mains à lui à la taille, balancement doux | Danse lente | **Slow face à face** (posture exacte à vérifier en jeu) | Animation personnalisée pour cette posture précise |

Les serveurs de ces vidéos utilisent des **animations personnalisées** (packs de couple, souvent payants). Ni GTA V ni
rpemotes ne contiennent de salsa à deux, de porté dynamique, ni de slow avec bras au cou et balancement.

Je n'ai pas pu vérifier le rendu en jeu : je n'ai pas accès à GTA V.

## Ce qu'il faut pour de vraies danses de couple personnalisées

Aucune animation personnalisée n'a été créée ici. Un fichier d'animation GTA (`.ycd`) se fabrique avec :
1. Les mouvements : capture (combinaison, ou vidéo traitée par IA type Move.ai / Rokoko Vision), un animateur, ou un
   **pack acheté avec une licence qui autorise son usage sur ton serveur**.
2. Blender + le module **Sollumz** (squelettes `mp_m_freemode_01` / `mp_f_freemode_01`), les deux danseurs animés
   ensemble depuis la même origine.
3. Export en `.ycd`, à placer dans `elyzea_animations/stream/` (dossier diffusé automatiquement par FiveM).
4. Une fiche dans `danses/catalog.lua` (copier une fiche existante, mettre `off = attach(0, 0, 0, 0)` pour deux danseurs
   enregistrés ensemble), puis essai à deux, `/danse_calib` si besoin, `/danse_valider`.

Si tu achètes un pack, envoie-moi ses fichiers et sa notice (noms des dictionnaires, clips, positions) : je l'intègre
dans les catégories existantes sans rien recommencer.

## Ajouter une nouvelle vidéo de référence

Joins-la à la conversation : j'indique le style, ce qui existe de plus proche, et ce qui nécessite une animation
personnalisée. Le catalogue est prévu pour être complété fiche par fiche.
