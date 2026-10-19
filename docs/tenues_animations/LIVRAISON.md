# Tenues enregistrées et interactions d'animations (menu ALT) — audit et livraison

> **Rien n'a pu être testé dans le jeu** : l'environnement de développement n'a ni GTA V ni client FiveM.
> Ce document sépare **le code écrit**, **les tests automatisés réellement exécutés hors du jeu** (§6) et **les tests en jeu, à faire à deux joueurs** (§7).
> Aucune fonction n'est déclarée validée en jeu.

## 1. Audit des ressources existantes

| Besoin | Ressource réellement utilisée | Constat |
|---|---|---|
| Vêtements | `elyzea_clothing` (boutique, panneau « Ma tenue » **F3**) + `@elyzea_core/lib/clothing.lua` | 15 rayons : 10 composants (1, 3, 4, 5, 6, 7, 8, 9, 10, 11) et 5 accessoires (0, 1, 2, 6, 7). Une pièce de pack est gardée par **collection + n° dans le pack** (elle reste juste quand on ajoute ou retire un pack). |
| Possession des vêtements | `elyzea_inventory` | **Chaque vêtement est un objet.** Le porter retire l'objet, ce qu'on portait revient en objet. Une tenue ne doit donc ni créer ni faire disparaître de vêtements. |
| Apparence sauvegardée | `ely_creator` (`ely_characters.skin`, par `citizenid`), export `SaveOutfit` | Seule la tenue portée est gardée. Aucune tenue enregistrée n'existait (`player_outfits` n'est cité que dans le wipe admin : ancienne table Qbox, non utilisée). |
| Multipersonnage | `elyzea_multichar` / `elyzea_core` (`citizenid`) | Les tenues sont rattachées au `citizenid`. |
| Tenues de service | `admin_menu` (export `IsWearingUniform`) | L'uniforme n'est pas un objet : enregistrer ou charger une tenue pendant le service est bloqué, sinon l'uniforme deviendrait des objets. |
| Grossesse | `elyzea_famille` (`elyTenueMasquee`) | Le ventre temporaire n'est jamais enregistré (lecture `ElyCloth.readReal`). |
| Menu ALT | `elyzea_police/client/alt.lua` (ALT maintenu + clic) | Système de **fournisseurs** (`ALT_PROVIDERS`, exports `AltOptions` / `AltSelect`) déjà utilisé par EMS, mécano, famille, animaux, braquages. Pas d'ox_target ni de qb-target. |
| Animations | `elyzea_animations` (menu **K**) + **rpemotes** (externe, absent du dépôt) | Le menu K a déjà un onglet « Partagées » : choix d'un joueur, invitation **Y / L**, lancement synchronisé par rpemotes (`SyncPlayEmote` / `SyncPlayEmoteSource`, clip de chaque rôle via `shared_emotes.lua`). `anim_data.lua` (généré depuis rpemotes) donne dictionnaire + clip de **toutes** les animations, y compris les 92 rôles d'animations à deux (`nearby_…`). |
| Danses à deux | — | **Aucune danse de couple ni slow à deux dans rpemotes** (les 92 animations à deux : poignées de main, câlins, bisous, porter, etc.). Les « Dance Slow » sont des danses solo. |

## 2. Sauvegarde et retour arrière
- État avant travaux : commit `8e63b36` (branche `claude/affectionate-mayer-65nnxp`). Revenir en arrière : `git revert` des commits de cette livraison, ou remettre les dossiers `elyzea_clothing`, `elyzea_animations`, `elyzea_police` et `admin_menu/server/wipe.lua` de ce commit.
- **Avant la mise à jour du serveur : sauvegarder la base de données** (les nouvelles tables sont créées automatiquement ; aucune table existante n'est modifiée).

## 3. Ce qui a été fait

### Partie 1 — Tenues enregistrées (`elyzea_clothing`, F3 › onglet « Mes tenues »)
| Fonction | Statut |
|---|---|
| Enregistrer la tenue portée sous un nom (15 rayons, coloris, packs) | code + tests auto |
| Porter une tenue en une seule action | code + tests auto (logique serveur), **à vérifier en jeu** (rendu sur le personnage) |
| Renommer, changer de catégorie (« Modifier »), remplacer par la tenue actuelle, supprimer avec confirmation | code + tests auto |
| Catégories par défaut (Quotidien, Travail, Soirée, Sport, Cérémonie) ; créer, renommer, supprimer ses catégories (les tenues sont gardées) | code + tests auto |
| Par personnage (`citizenid`), tenue homme refusée sur un personnage femme, limite configurable (40), noms uniques | code + tests auto |
| Porter = via l'inventaire : pièce non possédée laissée de côté, ce qu'on portait revient en objet, sac (capacité) géré, inventaire plein géré, rien n'est créé ni perdu | code + tests auto |
| Pièce d'un pack retiré du serveur : laissée de côté avec un message, le reste est mis, l'objet reste dans l'inventaire | code + tests auto (logique), **à vérifier en jeu** |
| La liste prévient d'avance des pièces manquantes ou de pack absent | code + tests auto |
| Bloqué en boutique, menotté, porté, à terre, en tenue de service | code (non testé en jeu) |

### Partie 2 — Menu ALT (`elyzea_animations`, branché au menu ALT d'`elyzea_police`)
| Fonction | Statut |
|---|---|
| Deux options sur une personne visée : « Copier l'animation », « Proposer une animation » (+ « Annuler l'invitation », « Arrêter l'animation à deux » selon l'état) | code + tests auto |
| Copier : le jeu de la personne visée reconnaît ce que son personnage joue **vraiment** (dictionnaire + clip ou scénario, objets en main pour départager), en lecture seule | code + tests auto (natives simulées), **à vérifier en jeu** |
| Copier : même animation via rpemotes, au même moment de l'animation, sans déplacement ; **X** l'arrête ; arrêt si mort ou menotté | code + tests auto, **à vérifier en jeu** |
| Copier : refus expliqué (rien de reconnu, hors catalogue, animation à deux, fichier manquant, véhicule) | code + tests auto |
| Proposer : menu K en mode « Proposer à … », 9 catégories, les 92 animations à deux réelles (fichiers absents masqués) | code + tests auto + rendu navigateur |
| Invitation : accepter (Y), refuser (L), annuler (L, `/annuleranim`, ALT), expiration (15 s), messages des deux côtés, une seule invitation à la fois | code + tests auto, **à vérifier en jeu** |
| Vérifications serveur : participants, invitation (jeton), expiration, distance, disponibilité (menotté, porté, à terre, véhicule, déjà occupé), animation valide | code + tests auto |
| Lancement : rpemotes avec le clip de chaque rôle (placement par rpemotes) | réutilise le système existant, **à vérifier en jeu** |
| « Danser ensemble » et « Slow » : même danse solo, face à face, lancée en même temps (dit clairement dans le menu et l'invitation) | code + tests auto, **à vérifier en jeu** |
| Arrêt des deux : X chez l'un, ALT, mort, menottes, éloignement > 8 m, déconnexion, redémarrage de la ressource, durée max | code + tests auto, **à vérifier en jeu** |

## 4. Fichiers
| Fichier | Rôle |
|---|---|
| `elyzea_clothing/server/outfits.lua` (nouveau) | tables, enregistrer / modifier / supprimer, catégories, porter via l'inventaire |
| `elyzea_clothing/client/outfits.lua` (nouveau) | onglet « Mes tenues », pièces portées, packs absents, application |
| `elyzea_clothing/html/index.html`, `app.js`, `style.css` | onglets « Portée » / « Mes tenues », fenêtres de saisie et de confirmation |
| `elyzea_clothing/server/items.lua` | partage du verrou anti double-clic et des noms de pièces avec les tenues (2 lignes) |
| `elyzea_clothing/config.lua` (`Config.Outfits`), `fxmanifest.lua` (3.1.0), `README.md` | |
| `elyzea_clothing/sql/outfits.sql` (nouveau) | création manuelle facultative des tables |
| `elyzea_clothing/tests/` (nouveau) | `run_outfits_sim.py` + `outfits_sim.lua`, `ui_outfits.js` |
| `elyzea_animations/client_interactions.lua` (nouveau) | options ALT, reconnaissance de l'animation jouée, copie, invitations, arrêt des animations à deux |
| `elyzea_animations/interactions.lua` (nouveau) | réglages et catégories de « Proposer une animation » (client + serveur) |
| `elyzea_animations/server.lua` | invitations (modes, annulation, disponibilité, messages), animations à deux en cours, copie, déconnexions |
| `elyzea_animations/client.lua` | points d'accroche (arrêt, refus automatique, touche L, ouverture en mode « proposer ») ; comportement existant inchangé |
| `elyzea_animations/html/index.html` | mode « Proposer à … », bandeau « Invitation envoyée » ; correction de la grille du panneau (la liste prend la hauteur libre) |
| `elyzea_animations/fxmanifest.lua`, `README.md` | données chargées aussi côté serveur (vérification) |
| `elyzea_animations/tests/` (nouveau) | `run_interactions_sim.py`, `run_client_sim.py`, `ui_menu.js` |
| `elyzea_police/client/alt.lua` | fournisseur `elyzea_animations` ajouté au menu ALT (1 ligne) |
| `elyzea_police/html/app.js` | 4 icônes du menu ALT |
| `admin_menu/server/wipe.lua` | le wipe d'un personnage vide aussi ses tenues |
| `README.md` | tableau des touches (F3, ALT) |

## 5. Base de données, installation, dépendances
- **Migration** : tables `elyzea_outfits` et `elyzea_outfit_categories` (utf8mb4), créées au démarrage d'`elyzea_clothing`. À la main si besoin : `elyzea_clothing/sql/outfits.sql`. Aucune table existante n'est modifiée. Enregistrer ou supprimer une tenue ne touche jamais aux vêtements possédés ; la porter les échange seulement avec ce qu'on portait, via l'inventaire.
- **Mise à jour** : sauvegarder la base, remplacer les dossiers `elyzea_clothing`, `elyzea_animations`, `elyzea_police`, `admin_menu` par ceux du dépôt, redémarrer le serveur. Rien à changer dans `server.cfg` : l'ordre actuel convient (`elyzea_clothing` après `[vetements]`, `rpemotes` avant `elyzea_animations`, `elyzea_police` après).
- **Dépendances** : `elyzea_core` (base de données, personnage), `elyzea_inventory` (vêtements en objets), `rpemotes` (version du serveur, avec `SyncPlayEmote` / `SyncPlayEmoteSource`), `elyzea_police` (menu ALT). Facultatives : `admin_menu` (tenue de service, wipe), `elyzea_famille`, `ely_creator`.
- **Réglages** : `Config.Outfits` (`elyzea_clothing/config.lua`) ; `elyzea_animations/interactions.lua` ; `Config` en haut de `elyzea_animations/server.lua`.

## 6. Tests automatisés réellement exécutés (hors du jeu)
| Test | Commande | Résultat |
|---|---|---|
| Tenues, serveur (vrais `items.lua` + `outfits.lua`, base et inventaire simulés) | `python3 tests/run_outfits_sim.py` (dans `elyzea_clothing/`, paquet `lupa`) | **50 / 50** |
| Tenues, interface (Chromium) : onglets, enregistrer, filtrer, modifier, catégories, confirmations, Échap, largeur téléphone | `node tests/ui_outfits.js` (paquet npm `playwright`) | **15 / 15**, aucune erreur JS |
| Animations, serveur (vrai `server.lua` + vraies données rpemotes, 6 joueurs simulés, horloge virtuelle) | `python3 tests/run_interactions_sim.py` (dans `elyzea_animations/`) | **55 / 55** |
| Animations, client (vrais `client.lua` + `client_interactions.lua`, natives simulées) : reconnaissance, copie, options ALT, arrêts | `python3 tests/run_client_sim.py` | **35 / 35** |
| Menu K, interface : mode proposer, masquage (fichier manquant, autre sexe), bandeau, annulation, retour au mode normal | `node tests/ui_menu.js` | **12 / 12**, aucune erreur JS |
| Syntaxe Lua 5.4 de tous les fichiers touchés, syntaxe JS | — | OK |
| Mode normal du menu K inchangé (capture avant / après) | — | identique (seul le mannequin animé de l'aperçu diffère) |

Captures (navigateur, icônes en ligne non chargées) : `captures/mes_tenues.png`, `captures/proposer_animation.png`, `captures/invitation_envoyee.png`.

Points vérifiés par ces tests, entre autres : les 15 rayons enregistrés avec coloris et pack ; aucun objet créé ni perdu en portant une tenue ; un autre personnage ne voit, ne porte ni ne supprime les tenues d'un personnage ; les 92 animations à deux de rpemotes sont classées et aucune n'est inventée ; un rôle d'animation à deux n'est jamais copié comme animation solo ; une réponse de copie venant d'un autre joueur, ou rejouée, est ignorée ; rien ne démarre sans acceptation, après annulation ou après expiration.

## 7. Tests en jeu à faire (au moins deux joueurs connectés)
**Tenues**
1. Enregistrer une tenue complète (haut, t-shirt, pantalon, chaussures, sac, gants, collier, masque, chapeau, lunettes, boucles, montre, bracelet, coloris variés, une pièce de pack).
2. Changer de vêtements depuis l'inventaire, puis « Porter » : chaque pièce et chaque coloris revient ; l'ancienne tenue est dans l'inventaire.
3. Retirer une pièce de l'inventaire (la jeter) et « Porter » : message « Non mis : … (pas dans ton inventaire) », le reste est mis.
4. Renommer, changer de catégorie, remplacer, supprimer ; créer, renommer, supprimer une catégorie.
5. Se déconnecter / reconnecter, puis redémarrer le serveur : tenues et catégories présentes.
6. Deuxième personnage du même compte : il ne voit pas les tenues du premier.
7. Tenue de service (admin_menu) : enregistrer et porter sont refusés.

**Menu ALT**
1. ALT sur un joueur : « Copier l'animation » et « Proposer une animation » présents, avec les options existantes (porter, police, EMS…) qui marchent toujours.
2. Copier une danse lancée par le menu, puis une lancée par `/e` : même animation, même rythme, personne copiée non dérangée, copieur non déplacé ; X l'arrête.
3. Copier une animation à deux (porter, câlin) et une personne sans animation : messages clairs, rien ne se lance.
4. Proposer un câlin : invitation, accepter (Y) ; refuser (L) ; annuler (L côté demandeur) ; laisser expirer (15 s).
5. Vérifier le placement par rpemotes (personnages face à face, pas l'un dans l'autre) sur plusieurs animations (poignée de main, câlin, bisou, porter).
6. « Slow » et « Danser ensemble » : les deux se tournent l'un vers l'autre et dansent en même temps.
7. Arrêter depuis chaque participant (X, ALT) ; mourir, être menotté, s'éloigner, se déconnecter pendant une animation à deux : l'autre est libéré.
8. `restart elyzea_animations` pendant une animation à deux : personne ne reste bloqué.

## 8. Limites techniques (honnêtes)
- **Pas de danse de couple ni de slow à deux** : rpemotes n'en a aucune. Les catégories « Danser ensemble » et « Slow » font faire la **même danse solo** aux deux, face à face, lancée au même moment. Ce n'est pas une danse de couple et c'est écrit dans le menu. Les clips GTA de danse à deux (boîte de nuit, rôles A / B) existent dans le jeu, mais leur placement relatif n'a pas pu être réglé sans le jeu : ils ne sont pas proposés. Une vraie danse de couple ajoutée à rpemotes (et à `shared_emotes.lua` / `anim_data.lua` / `interactions.lua`) apparaît automatiquement dans « Proposer une animation ».
- **Copier** ne reconnaît que les animations du catalogue rpemotes (`anim_data.lua`) : une animation lancée par une autre ressource (assise du casino, etc.) est en général « non reconnue » et rien n'est lancé ; si elle utilise par hasard un clip ou un scénario du catalogue, c'est cette animation du catalogue qui est copiée. Si deux animations ont exactement le même clip et les mêmes objets, c'est la première par ordre alphabétique qui est copiée (même mouvement à l'écran).
- **Animation à deux finie toute seule** (durée fixe dans rpemotes) : les deux sont libérés sans rien couper ; une animation en boucle continue jusqu'à X.
- **Sécurité, point existant non modifié** : comme le bouton « Porter » existant, le serveur se fie à ce que le client dit porter au moment d'échanger une pièce. Les tenues ne l'aggravent pas (mêmes règles), mais une vérification par les natives serveur des composants du personnage renforcerait les deux ; à envisager après des essais en jeu.
- Les animations à deux sont placées et synchronisées par **rpemotes** (aucun deuxième système de synchronisation) : leur qualité dépend de rpemotes.
