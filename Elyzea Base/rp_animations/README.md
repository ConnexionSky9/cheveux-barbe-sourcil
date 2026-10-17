# rp_animations : danses et animations romantiques (Elyzea)

Menu de danses en solo et en duo, avec invitations, consentement vérifié par le serveur, positionnement des deux
partenaires, arrêt immédiat et nettoyage fiable. Toutes les animations sont accessibles à tous, sans VIP.

- Menu : **F7** ou `/danses`
- Arrêter : **X**, `/stopanim`, le bouton « Arrêter », ou simplement avancer / sauter
- Invitation reçue : **Y** accepter, **L** refuser (adulte : **Y** ouvre la fenêtre de confirmation)

## Ce qui est livré, et ce qui ne l'est pas

| | État |
|---|---|
| Ressource complète (client, serveur, NUI, config, catalogue) | Écrite, chargée et testée hors jeu (voir `docs/TESTS.md`) |
| 70 fiches au catalogue | 41 jouables (21 jeu de base, 20 rpemotes), 29 « à créer » affichées en grisé |
| Animations natives **validées en jeu** | **Aucune pour l'instant** : je n'ai pas accès au jeu. Les 41 jouables sont « À valider en jeu » |
| Animations personnalisées produites | **Aucune** : pas d'outil 3D ni de squelette GTA disponible ici (voir `docs/ANIMATIONS_PERSONNALISEES.md`) |
| Offsets des duos | Estimations, à calibrer en jeu avec `/rpanim_calib` (sans toucher au code) |

Le menu ne propose que ce qui peut vraiment être joué : chaque clip est vérifié chez le joueur (dictionnaire présent et
clip de durée non nulle). Une animation dont les fichiers manquent est marquée « Fichiers absents » et ne se lance pas.

## Avec elyzea_animations (menu K)

Les deux menus sont reliés : bouton **Slows & duos** dans le menu K pour venir ici, bouton **‹ Animations** pour y
retourner. La touche X d'elyzea_animations arrête aussi une danse (le partenaire est prévenu), et lancer une danse arrête
d'abord l'emote ou le placement Elyzea en cours. Il faut la version d'`elyzea_animations` fournie dans ce dépôt (elle ajoute
le bouton et deux exports) ; sans elle, rp_animations fonctionne seul avec F7.

Exports : `exports.rp_animations:Open()`, `exports.rp_animations:Stop()`, `exports.rp_animations:IsBusy()`.

## Prérequis

- **OneSync** activé (txAdmin l'active par défaut). Sans OneSync, le serveur refuse les duos (il ne peut pas vérifier les distances).
- **rpemotes** démarré : 20 animations utilisent des fichiers que rpemotes diffuse (couples, slows, baisers). Sans rpemotes,
  elles sont automatiquement masquées comme « Fichiers absents » ; les 21 animations du jeu de base restent disponibles.
- Build du jeu : celle du serveur (`sv_enforceGameBuild 3258`) contient tous les dictionnaires du jeu de base utilisés.
- Aucune autre dépendance. `elyzea_core` est utilisé seulement si `Config.Invite.ShowNames = true` (nom du personnage).

## Installation

1. **Sauvegarde** : copie ton `server.cfg` et ton dossier `resources` (la base de données n'est pas touchée).
2. Copie le dossier `rp_animations` dans `resources` (avec le reste de `Elyzea Base`).
3. Dans `server.cfg`, la ligne est déjà ajoutée dans la partie « Animations et expressions », **après** rpemotes :

   ```cfg
   ensure rpemotes
   ensure elyzea_animations
   ensure rp_animations
   ```

4. Redémarre le serveur (ou `refresh` puis `ensure rp_animations` dans la console).
5. Console serveur : tu dois voir `[rp_animations] 70 animations au catalogue, 41 jouables, 0 problème(s)`.
6. En jeu : F8 puis `rpanim_check` → liste des animations jouables trouvées et de celles dont les fichiers manquent.

Le calibrage et la validation utilisent la permission `admin` déjà donnée à `group.admin` dans `permissions.cfg`.
Pour la donner à quelqu'un d'autre : `add_ace group.mod rp_animations.admin allow`.

## Commandes et touches

| Action | Touche par défaut | Commande |
|---|---|---|
| Ouvrir / fermer le menu | F7 | `/danses` |
| Arrêter l'animation (solo ou duo) | X | `/stopanim` |
| Accepter une invitation | Y | — |
| Refuser une invitation | L | — |
| Vérifier les fichiers d'animation (F8) | — | `rpanim_check` |
| Calibrer la position du partenaire (staff, rôle B) | — | `/rpanim_calib` |
| Marquer une animation validée en jeu (staff) | — | `/rpanim_valider <id>` (`/rpanim_valider <id> non` pour annuler) |
| Revenir aux positions du catalogue (staff) | — | `/rpanim_reset <id>` |

Chaque joueur peut changer ses touches : Échap › Paramètres › Raccourcis › FiveM › « Danses : … ».
X est volontairement la même touche d'arrêt qu'`elyzea_animations` : une seule touche arrête tout.
Y / L sont aussi celles d'`elyzea_animations` ; chaque ressource ne réagit que si elle a une invitation en attente.

Dans le menu : souris, ou clavier (`/` recherche, flèches, Entrée lancer, F favori, Page ↑/↓ catégorie, Échap fermer).

## Utilisation

**Solo** : clic sur « Lancer ». **Duo** : clic sur « Inviter », choix de son rôle (A reste sur place, B vient se placer ;
les rôles ne dépendent pas du personnage), choix de la personne à moins de 3 m, envoi.

L'invité voit une fenêtre en haut de l'écran avec le nom de la danse et son rôle, 20 s pour répondre. S'il accepte, le
serveur revérifie tout (distance, état des deux personnages, instance, contenu adulte), B marche jusqu'à sa place, puis les
deux animations démarrent ensemble. Chacun peut arrêter à tout moment ; l'autre est prévenu et libéré.

**Animations adultes** (non graphiques, roleplay entre personnages adultes) : masquées tant que le joueur ne les a pas
activées dans les réglages du menu. Une invitation adulte n'est possible que si **les deux** les ont activées, et elle ne
s'accepte que dans une fenêtre avec une case « Je confirme explicitement » (la touche Y seule ne suffit jamais).
Désactiver l'option arrête aussitôt une animation adulte en cours. Le **fondu au noir** est facultatif, choisi par chacun
pour son propre écran, n'apparaît qu'à l'intérieur d'une session acceptée et disparaît dès l'arrêt.

**Réglages joueur** (roue crantée) : ne plus recevoir d'invitations, contenu adulte, nouvelle vérification des fichiers.
Favoris et récents sont gardés sur le PC du joueur.

## Configuration (`config.lua`)

| Réglage | Défaut | Rôle |
|---|---|---|
| `OpenKey` / `OpenCommand` | F7 / danses | Ouverture du menu |
| `StopKey` / `StopCommand` / `StopOnMove` | X / stopanim / true | Arrêt |
| `AcceptKey` / `RefuseKey` | Y / L | Réponse aux invitations |
| `Invite.Timeout` / `Cooldown` / `MaxPerMinute` | 20 s / 5 s / 6 | Expiration et anti-spam |
| `Invite.MaxDistance` / `StartDistance` | 3 m / 4 m | Distance pour inviter / pour commencer |
| `Invite.ShowNames` | false | false : « Une personne (ID 12) » ; true : nom du personnage |
| `Session.MaxDistance` / `PrepareTimeout` | 6 m / 10 s | Arrêt automatique / délai de mise en place |
| `Positioning.*` | | Marche vers sa place, correction max, détection d'obstacle |
| `Adult.Enabled` / `FadeAllowed` | true / true | Contenu adulte sur le serveur, fondu au noir |
| `ShowUnvalidated` | true | false : ne montrer que les animations validées en jeu |
| `ShowPlanned` | true | Afficher les « à créer » en grisé |
| `BlockingStates` | emsDown, cuffed, carriedBy, escortedBy, emsEscortedBy | États Elyzea qui interdisent un duo |

## Valider les animations en jeu (à faire par le staff)

Pour chaque animation « À valider en jeu » (liste dans `docs/CATALOGUE.md`) :

1. Lancer l'animation (en duo : avec un deuxième joueur, tester chaque rôle).
2. Vérifier le mouvement, l'orientation, la distance entre les deux, la fin et l'arrêt par chacun.
3. Si B est mal placé : dans le rôle B, `/rpanim_calib`, ajuster (flèches, Page ↑/↓, molette, Maj = fin), Entrée.
   La position est enregistrée sur le serveur pour tout le monde et affichée en F8 pour la reporter dans le catalogue.
4. Si l'animation convient : `/rpanim_valider <id>`. Elle s'affiche alors « Native validée ».
5. Si elle ne convient pas : passer son `status` à `'bloquee'` dans `shared/catalog.lua` (elle disparaît du menu).

Points à surveiller en priorité : les clips `ped_b_dance_idle` (danses de club en duo, nom supposé, masqués s'ils
n'existent pas), `gesture_come_here_soft` (« Inviter à danser ») et tous les offsets (estimations).

## Ajouter une animation

Ajoute une fiche dans `Catalog.List` (`shared/catalog.lua`) en suivant les autres, puis relance `python3 tests/run_tests.py`
et `python3 tests/gen_catalogue.py`. Pour un fichier personnalisé : `docs/ANIMATIONS_PERSONNALISEES.md`.

## Mise à jour

1. Sauvegarde le dossier actuel. 2. Remplace les fichiers (garde ton `config.lua` si tu l'as modifié).
3. `restart rp_animations`. Les offsets calibrés et les validations sont gardés (stockage de la ressource, KVP).

## Désinstallation

1. Retire `ensure rp_animations` de `server.cfg`. 2. Supprime le dossier `rp_animations`.
Rien n'est écrit en base de données. Les réglages restent dans le stockage KVP de FiveM sans effet.

## Sécurité et performances (résumé)

- Le serveur est la seule source de vérité : une invitation a un identifiant aléatoire, n'est acceptable que par son
  destinataire, une seule fois, avant expiration ; tout est revérifié à l'acceptation.
- Chaque événement réseau vérifie ses paramètres et a une limite d'appels ; l'arrêt est toujours accepté.
- Les animations « à créer », inexistantes ou solo sont refusées pour une invitation ; le calibrage exige la permission.
- Déconnexion, mort, menottes, portage, véhicule, distance excessive, changement d'instance : arrêt automatique.
- Aucune boucle quand rien ne se passe : les boucles client et la surveillance serveur ne tournent que pendant une animation.

## Limites techniques connues

- **Synchronisation** : les deux clients reçoivent le départ en même temps du serveur ; l'écart restant (différence de
  ping) est rattrapé une fois en recalant la phase de B sur celle de A. Pas de correction permanente (elle saccaderait).
  Une synchronisation à l'image près exigerait des « synchronized scenes » réseau, peu fiables entre deux joueurs.
- **Positionnement** : B est attaché à A pendant la danse (aucune dérive, répliqué par le moteur, collision désactivée
  entre eux). La petite correction finale (moins de 1,2 m, sinon annulation) peut se voir sur les clips à origine commune.
- **Obstacles** : test de ligne de vue et de hauteur du sol avant de commencer, pas de collision fine des membres.
- **Enchaînements** : les « rapprochements progressifs » enchaînent des clips existants avec un fondu, ce n'est pas un
  mouvement continu. Les vraies chorégraphies (valse, salsa, bachata, tango…) sont « à créer ».
- Le fondu au noir est un voile noir de l'interface, pas un fondu du moteur : il ne peut pas rester bloqué.
