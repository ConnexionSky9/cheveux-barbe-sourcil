# Compte rendu de tests

Date : 17 octobre 2026. **Aucun test n'a été fait dans GTA V / FiveM** : l'environnement de développement n'a ni le jeu
ni de serveur FiveM. Ce qui a été réellement exécuté :

1. **Compilation Lua 5.4** de tous les fichiers (`tests/run_tests.py`).
2. **Logique serveur** exécutée dans un vrai Lua 5.4 avec les natives FiveM **simulées** (`tests/fivem_mock.lua`) :
   35 scénarios (invitations, consentement, abus, déconnexions, étapes, charge).
3. **Logique client** dans le même environnement simulé (`tests/client_mock.lua`) : 23 scénarios (lancer, placer,
   attacher, arrêter, nettoyer, invitations, menu).
4. **Interface NUI** ouverte dans Chromium (Playwright) avec les vraies données produites par `client/menu.lua` :
   23 vérifications (souris, clavier, recherche, favoris, invitation, confirmation adulte, petit écran, erreurs JS).

Les simulations vérifient l'enchaînement des appels et les décisions du code, **pas** le rendu des animations, la
physique, la réplication réseau réelle ni la latence. Ces points restent à tester en jeu (dernière partie).

Pour relancer : `python3 tests/run_tests.py` (prérequis : `pip install lupa`) et `tests/run_ui_test.sh` (Playwright).
Un test de mutation a été fait : en retirant volontairement le contrôle « seul le destinataire peut répondre » et la
confirmation adulte, les tests correspondants échouent bien (puis le code a été restauré).

Défaut trouvé et corrigé par ces tests : pour les clips à origine commune (offset nul), la détection d'obstacle
comparait A à lui-même et ne testait rien ; elle teste maintenant le trajet de B vers sa place et la ligne A → place.

## Résultats exécutés (59 réussis, 0 échec, 0 erreur de syntaxe)

### Serveur (natives simulées)

| Scénario | Résultat |
|---|---|
| Invitation acceptée : session créée avec rôles A/B, démarrage après « prêt » des deux | Réussi |
| Rôle B choisi par l'auteur : rôles inversés | Réussi |
| Invitation refusée : aucune session, aucune pénalité, auteur prévenu | Réussi |
| Invitation expirée : fermée après le délai, réponse tardive sans effet | Réussi |
| Réponse falsifiée par un tiers ou par l'auteur : ignorée | Réussi |
| Invitation à usage unique : seconde acceptation sans effet | Réussi |
| Anti-spam : délai entre invitations et limite par minute | Réussi |
| Une seule invitation en attente par auteur et par destinataire | Réussi |
| Distance : trop loin à l'envoi, ou éloigné au moment d'accepter | Réussi |
| Instance différente (routing bucket) : refusé | Réussi |
| Mort, à terre, menotté, porté, escorté, en véhicule : refusé | Réussi |
| Participant mis à terre entre l'invitation et l'acceptation : refusé | Réussi |
| Adulte : option non activée chez la cible, ou chez l'auteur : refusé | Réussi |
| Adulte : acceptation sans confirmation explicite refusée, avec confirmation acceptée | Réussi |
| Adulte : désactiver l'option arrête la session adulte en cours | Réussi |
| Adulte désactivé sur le serveur : refusé | Réussi |
| « Ne pas recevoir d'invitations » : refusé | Réussi |
| Animation inexistante, à créer, solo, paramètres de mauvais type : refusé sans erreur | Réussi |
| Arrêt par B : les deux prévenus, session nettoyée | Réussi |
| Arrêt par A pendant la mise en place : immédiat | Réussi |
| « Prêt » d'un non-participant ou répété : ignoré | Réussi |
| Fichiers absents chez un participant : session annulée proprement | Réussi |
| Déconnexion pendant la session : l'autre est libéré | Réussi |
| Déconnexion avec invitation en attente : invitation fermée | Réussi |
| Surveillance : trop d'écart pendant la danse → arrêt automatique | Réussi |
| Surveillance : participant à terre pendant la danse → arrêt automatique | Réussi |
| Mise en place trop longue → annulée | Réussi |
| Enchaînement d'étapes piloté par le serveur | Réussi |
| Enchaînement cyclique : retour à la première étape | Réussi |
| Occupé : pas d'invitation vers/depuis un joueur en session | Réussi |
| Calibrage : refusé sans permission, valeurs hors limites rejetées, enregistré et diffusé avec permission | Réussi |
| `/rpanim_valider` réservé au staff | Réussi |
| `ShowUnvalidated = false` : seules les animations validées en jeu sont invitables | Réussi |
| Arrêt de la ressource : sessions terminées | Réussi |
| Charge : 24 couples (48 joueurs) simultanés, surveillance, puis déconnexion de tous, état vide | Réussi |

### Client (natives simulées)

| Scénario | Résultat |
|---|---|
| Solo : lancer depuis le menu puis `/stopanim` (clip retiré, menu informé) | Réussi |
| Solo : la touche d'arrêt arrête | Réussi |
| Solo : avancer arrête l'animation | Réussi |
| Solo : fichiers absents → message clair, rien n'est joué | Réussi |
| Animation « à créer » : message clair | Réussi |
| Personnage mort ou en véhicule : refusé | Réussi |
| Mort pendant une animation : arrêt automatique | Réussi |
| Adulte solo : refusé sans l'option, joué avec, arrêté si l'option est retirée | Réussi |
| Enchaînement solo cyclique | Réussi |
| Duo rôle B : marche vers sa place (pas de téléportation), attache, recalage de phase, fin propre (détaché, sans clip) | Réussi |
| Duo rôle A : prêt sans bouger, immobile pendant la mise en place, arrêt local immédiat, plus aucun contrôle bloqué ensuite | Réussi |
| Duo : obstacle → annulé avant de démarrer | Réussi |
| Duo : fichiers absents chez moi → serveur prévenu | Réussi |
| Duo : partenaire hors de portée → arrêt automatique | Réussi |
| Duo : animation coupée par une autre ressource → session arrêtée | Réussi |
| Duo : offset calibré utilisé pour attacher B | Réussi |
| Fondu au noir : seulement si choisi, retiré à l'arrêt | Réussi |
| Invitation simple : Y accepte, L refuse | Réussi |
| Invitation adulte : Y ouvre la confirmation, n'accepte jamais directement ; mauvais identifiant ignoré | Réussi |
| Inviter : rôle et cible transmis, joueurs proches listés | Réussi |
| Menu : ouverture, favoris persistants, fermeture avec focus rendu au jeu | Réussi |
| Vérification des fichiers : fiches avec clip manquant marquées | Réussi |
| Arrêt de la ressource pendant un duo : personnage libéré | Réussi |

### Interface (Chromium)

Toutes réussies : 12 catégories affichées ; « à créer » grisées en fin de liste avec message clair au clic ; recherche ;
flèches + Entrée ; F favori ; favoris ; fenêtre d'invitation (joueur trop loin désactivé, rôle B, envoi correct) ;
catégorie adulte verrouillée puis visible après activation ; bouton Accepter adulte désactivé tant que la case n'est pas
cochée ; barre « en cours » et bouton Arrêter ; Échap ferme ; invitation visible menu fermé ; pas de défilement
horizontal sur petit écran ; aucune erreur JavaScript.

## Non exécutés (nécessitent le jeu)

| Test demandé | Statut |
|---|---|
| Rendu visuel de chacune des 41 animations jouables | **Non exécuté** |
| Existence réelle des clips dans GTA / rpemotes (`rpanim_check`) | **Non exécuté** (vérifié automatiquement au chargement en jeu) |
| Orientations et offsets des 25 duos | **Non exécuté** (estimations, `/rpanim_calib`) |
| Synchronisation réelle entre deux clients (latence, phase) | **Non exécuté** |
| Attache et absence de collision entre deux joueurs réels | **Non exécuté** |
| Arrêt par chacun des participants, en jeu | **Non exécuté** (logique testée en simulation) |
| Déconnexion réelle d'un participant | **Non exécuté** (logique testée en simulation) |
| Contrôles du joueur après interruption, en jeu | **Non exécuté** (logique testée en simulation) |
| Tentatives d'abus réseau depuis un vrai client modifié | **Non exécuté** (événements forgés testés en simulation) |
| Performances avec plusieurs joueurs réels (resmon) | **Non exécuté** (24 sessions simulées) |
| Démarrage / arrêt de la ressource sur le serveur | **Non exécuté** |
| Cohabitation avec rpemotes / elyzea_animations (touches X, Y, L) | **Non exécuté** |

## Recette conseillée en jeu (2 joueurs, 30 minutes)

1. `ensure rp_animations` : message de catalogue sans problème dans la console.
2. F8 `rpanim_check` : noter les animations « fichiers absents ».
3. Menu F7 : navigation, recherche, favoris, fermeture (la souris disparaît, le personnage bouge).
4. Solo : 3 danses, arrêt par X, par `/stopanim`, en avançant.
5. Duo : inviter / refuser / laisser expirer / accepter ; essayer les deux rôles ; X par A puis par B ; s'éloigner ;
   déconnecter un joueur pendant une danse.
6. Adulte : invitation sans option (refus), avec option (fenêtre et case obligatoire), fondu choisi par un seul.
7. `/rpanim_calib` sur les duos mal placés, `/rpanim_valider` sur ceux qui conviennent.
8. `resmon` : rp_animations doit être à ~0,00 ms au repos.
