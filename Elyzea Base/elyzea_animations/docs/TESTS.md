# Tests

## Ce qui a été réellement exécuté (sans le jeu)

Je n'ai pas accès à GTA V ni à ton serveur. Tout ce qui suit a tourné hors jeu, dans un vrai Lua 5.4, avec les
fonctions de FiveM **simulées** (`tests/fivem_mock.lua`, `tests/client_mock.lua`). Ces tests vérifient le code et ses
décisions, **pas** le rendu des animations, la physique ni le réseau réel.

| Vérification | Résultat |
|---|---|
| Syntaxe Lua de tous les fichiers de la ressource | 15 fichiers, 0 erreur |
| Analyse statique (variables globales créées par erreur) | 1 défaut trouvé et corrigé (`placing`) |
| Tests serveur : duo, groupe, sécurité, partagées | 40 réussis sur 40 |
| Tests client : **ton vrai `client.lua`** (touche K, X, Y / L, menu) + moteur de danse | 33 réussis sur 33 |
| Touche K quand les réglages sont abîmés ou le dossier danses/ absent | 2 réussis sur 2 |
| Menu K ouvert dans Chromium avec les données du jeu simulé | 14 réussis sur 14 |
| Tests de mutation (protections retirées volontairement) | les 3 mutations ont été détectées |

Relancer : `python3 tests/run_tests.py` (prérequis `pip install lupa`) et `tests/run_ui_test.sh` (Playwright).

Principaux scénarios couverts : invitation acceptée / refusée / expirée / annulée ; réponse falsifiée par un tiers ;
invitation à usage unique ; anti-spam ; invitations en double et croisées ; distance, instance, mort, menottes, portage,
véhicule ; arrêt par chaque participant ; déconnexions ; mise en place trop longue ; fichiers absents ; obstacle ;
enchaînement d'étapes ; rotation du slow tournant ; attache identique à rpemotes ; recalage de phase ; groupe
(acceptations, refus, expiration, lancement anticipé, annulation par le meneur, départ d'un membre avant et pendant,
meneur parti, membre trop loin ou en retard, limite de participants) ; 48 joueurs simulés (4 groupes + 8 duos) ;
redémarrage de la ressource ; animations partagées vers les deux versions de rpemotes ; touche K, X, `/stopanim`,
raccourcis, `/animdiag`.

## Ce qui n'a PAS été testé en jeu

Aucun test à deux joueurs n'a été fait : il est à faire par vous deux (procédure ci-dessous). En particulier :
le rendu de chaque danse sur les deux écrans, le face à face, la synchronisation réelle, les contrôles après
interruption, et l'existence réelle du clip `ped_b_dance_idle`. Les danses de groupe à 3 joueurs ou plus n'ont été
vérifiées qu'en simulation : elles restent à valider avec plus de joueurs.

## Procédure de test à deux (environ 40 minutes)

Notez pour chaque ligne : OK / problème (et ce que voit chacun des deux écrans).

**Avant**
1. `ensure elyzea_animations` : la console serveur affiche `[Elyzea danses] 18 danses à plusieurs au catalogue, 0 problème(s)`.
2. En jeu, F8 : `animdiag` (version de rpemotes, touches, animations masquées) puis `elyzea_anim_check`.

**Réparation (chacun)**
3. K ouvre le menu, Échap le ferme, le personnage bouge normalement.
4. Trois animations classiques (Gestes, Danses solo, Objets) : elles se lancent ; X les arrête ; `/stopanim` aussi.
5. Une animation partagée (Partagées › Hug) : l'autre reçoit la demande, Y accepte, l'animation se joue chez les deux.
6. Placement (clic droit sur une animation) puis X : le personnage n'est plus figé.

**Danses lentes (joueur A invite, joueur B accepte, puis inverser les rôles)**
7. Slow face à face : B marche jusqu'à A, ils sont **face à face**, à distance naturelle, sans se traverser.
8. Slow tournant : le couple tourne lentement ; les deux écrans voient la même chose.
9. Étreinte romantique, Danse des mariés, Pose des mariés, Enlacés par derrière, Baiser, Slow puis baiser.
10. Pour chaque danse : arrêt par A (X), puis par B (avancer) → l'autre est libéré et prévenu, contrôles normaux.
11. Si un partenaire est mal placé : dans son rôle, `/danse_calib`, ajuster, Entrée (staff). Si c'est bon : `/danse_valider <id>`.

**Duo**
12. Danse de club face à face, Danse en paire (masquée si le clip n'existe pas), Le porté, Le grand porté.

**Invitations**
13. Refuser (L), laisser expirer (20 s), inviter deux fois de suite (message d'attente), s'inviter mutuellement
    (message « réponds à son invitation »), inviter quelqu'un dans un véhicule (refus).

**Groupe à deux (fonctions de base)**
14. A invite B à « Thriller » en ligne : départ quand B accepte ; même mouvement chez les deux.
15. Recommencer en cercle ; B quitte avec X → A est prévenu et la danse s'arrête (moins de 2 danseurs).
16. A invite B puis tape `/danse_lancer` avant la réponse → départ seul impossible, message.
17. A lance un groupe puis X avant la réponse de B → l'invitation de B disparaît.

**Interruptions**
18. Pendant une danse : un des deux monte dans un véhicule, se fait menotter, meurt, se déconnecte, s'éloigne :
    la danse s'arrête chez l'autre, personne ne reste attaché ni bloqué.
19. `restart elyzea_animations` pendant une danse : les deux personnages sont libérés.
