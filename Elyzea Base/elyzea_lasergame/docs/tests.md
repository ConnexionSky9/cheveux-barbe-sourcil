# Rapport de tests — LaserGame ElyzeaFA

Tous les tests ci-dessous ont été **réellement exécutés** (environnement Linux, sans GTA V).
Relancer : `bash tests/run_all.sh` (Python 3 + `lupa`, `numpy`, `pillow` ; Node + Playwright / Chromium).

## Résultat de la dernière exécution
| Suite | Résultat |
|---|---|
| Syntaxe Lua 5.4 (38 fichiers : serveur, client, partagé, configuration, tests) | ✅ 0 erreur |
| Syntaxe JavaScript de l'interface | ✅ |
| Cartes : génération + validation (5 cartes, 1 489 objets GTA V) | ✅ 5 / 5, 0 erreur, 0 avertissement |
| Contrats serveur ↔ client ↔ interface | ✅ 10 / 10 |
| Simulation du vrai code serveur (420 requêtes SQL réelles) | ✅ 157 / 157 vérifications, 0 erreur |
| Interface dans Chromium (16 écrans, interactions) | ✅ 16 / 16 sans erreur JavaScript |
| Tests existants d'admin_menu après intégration (portes, coiffeur, boutiques) | ✅ 0 échec |

## 1. Cartes (`tools/mapgen/build_all.py`)
| Carte | Objets | Surface | Couverture | Apparitions exposées | Accessibilité | Équilibre A/B | Fentes |
|---|---|---|---|---|---|---|---|
| ELYSIUM COMBAT (S) | 143 | 44 × 44 m | 25 % | 0 | 100 % | 1,00 | 0 |
| NEON DISTRICT (M) | 157 | 72 × 56 m | 20 % | 0 | 100 % | 1,00 | 0 |
| BLACKSITE (L) | 275 | 110 × 90 m | 17 % | 0 | 100 % | 1,00 | 0 |
| LAST STAND (XL) | 329 | 160 × 130 m | 13 % | 0 | 100 % | 1,00 | 0 |
| COMPLEXE ELYZEA-7 (Zombie) | 585 | 98 × 128 m | 24 % | — | 8 secteurs, 9 portes, 13 armes, 8 atouts | — | 0 |

Vérifié pour chaque carte : objets dans les limites ; grille de navigation 0,5 m (rayon d'un joueur) ; tous les points d'apparition
accessibles ; aucune poche inaccessible ; aucune ligne de vue directe entre apparitions adverses ; couverture haute à moins de 7 m de
chaque apparition ; distance de marche au centre identique pour les deux camps ; aucune fente de 0,5 m où se coincer.
Zombie : **portes fermées, aucun autre secteur n'est accessible** depuis la salle de départ ; portes ouvertes, tous les secteurs,
portes, armes murales et atouts sont accessibles ; 38 points d'apparition de zombies hors obstacles.

## 2. Simulation du serveur (`tests/run_server_sim.py`)
Le **vrai** code serveur est exécuté par un interpréteur Lua 5.4, avec natives FiveM simulées, horloge virtuelle, argent simulé
(elyzea_core) et une vraie base SQL (SQLite, dialecte MySQL traduit). Scénarios couverts :
- **Fonctions pures** : points Elo (gain à niveau égal = 20, battre plus fort rapporte plus, défaite toujours négative, anti-farm à 0),
  partage du pot sans perte ni création d'argent, manches, formules Zombie (3 coups sans atout, 5–6 avec Mastodonte), repères.
- **Démarrage** : 9 tables, 5 cartes, réglages publiés, framework détecté.
- **Lobby PVP** : refus loin d'un PNJ, format / mise / carte invalides, nom nettoyé, équilibrage auto, partie complète, choix d'arme.
- **Mises** : fonds insuffisants, débit à « prêt », remboursement à « pas prêt », aucun double remboursement.
- **Partie PVP 2v2** : instance 63001, state bags, sauvegarde RP en base ; tirs refusés (arme non attribuée, origine éloignée,
  trajectoire fausse, tir allié, cadence, éliminé qui tire) ; dégâts serveur ; éliminations ; 2 manches ; fin ; **paiement exact**
  (gagnants 105 000 $, perdants 95 000 $, total conservé 400 000 $) ; points (gagnant 1 033, perdant 967) et statistiques ; restauration (position, vie, gilet,
  instance) confirmée puis sauvegarde supprimée ; historique ; classement (identifiant RP non divulgué).
- **Anti-farm** : 5 victoires de suite contre le même adversaire → gains réels mesurés : +32, +20, +12, +6, puis 0 point.
- **Déconnexion** : abandon → l'autre gagne le pot ; sauvegarde conservée ; **restauration automatique à la reconnexion**.
- **Crash / redémarrage pendant une partie** : mises remboursées, partie « interrompue », joueurs remis au RP.
- **Spectateur** : entrée dans l'instance, impossible de tirer, reçoit le score, retour au RP.
- **Zombie en duo** : zombies créés par le serveur dans l'instance ; argent Zombie gagné, **jamais** ajouté à l'argent RP ;
  fin de manche, pause, manche 2 plus fournie ; porte refusée à distance / sans argent, achetée une fois ; arme murale ; atout ;
  atout d'une salle fermée refusé ; joueur renvoyé d'une salle fermée ; Mastodonte (200 PV) ; attaque au corps à corps calculée
  par le serveur ; mise à terre ; réanimation (2 s avec Réanimation rapide) ; flaque d'acide ; fin de partie, classement des équipes,
  profil Zombie ; zombies supprimés.
- **Zombie solo** puis abandon → retour RP.
- **Staff** : refus sans permission ; armes, mises, prix, difficulté, formats modifiés et publiés ; valeurs bornées ; réinitialisation ;
  carte déplacée puis remise ; PNJ ajouté ; exclusion / levée ; rang fixé ; recherche ; journaux ; aucune mise bloquée.
- **Sécurité** : limite de fréquence active, événements suspects journalisés.

## 3. Contrats (`tests/contract_check.py`)
43 événements serveur → client tous gérés · 44 messages vers l'interface tous traités · 5 rappels NUI déclarés ·
30 appels de l'interface autorisés · 42 appels RPC tous définis côté serveur · 33 sons présents · 8 emblèmes (SVG + PNG) ·
5 cartes · découpage des murs **identique** entre le client Lua et l'outil Python (1 042 pièces) · fichiers servis déclarés.

## 4. Interface (`tests/ui_screens.cjs`)
Ouverture dans Chromium, sans erreur JavaScript : accueil, PVP (liste, création, lobby), Zombie (accueil, lobby), classements (PVP et
Zombie), profil, historique, paramètres, staff (9 onglets parcourus), HUD PVP, HUD Zombie, résultats PVP et Zombie, chargement.

## 5. Ce qui n'a PAS pu être testé ici
Ces tests demandent un serveur FiveM et un client GTA V, absents de cet environnement : rendu réel des lasers et des cartes,
natives côté client, IA de déplacement des zombies, caméras, animations, sons dans le jeu, synchronisation réseau réelle,
performances en jeu. Voir `docs/limitations.md` pour la liste et la procédure de validation en jeu.
