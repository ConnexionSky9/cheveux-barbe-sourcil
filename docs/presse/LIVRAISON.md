# Métier de journaliste (`elyzea_presse`) — audit et livraison

> **Rien n'a pu être testé dans le jeu** : l'environnement de développement n'a ni GTA V ni client FiveM.
> Ce document distingue **le code écrit**, **les vérifications automatiques réellement exécutées hors du jeu** (§6)
> et **les tests en jeu à faire à plusieurs joueurs** (§7). Aucune fonction n'est déclarée validée en jeu.

## 1. Audit des ressources existantes

| Besoin | Ce qui existe réellement sur le serveur | Décision |
|---|---|---|
| Framework | `elyzea_core` (remplace qbx_core / ox) : métiers déclarés par les ressources (`CreateJob`), `player_groups`, `players.job`, comptes de société `elyzea_society`, salaires automatiques (désactivés de fait pour les métiers à agences : `payment = 0`) | Réutilisé tel quel |
| Modèle de métier | `elyzea_dynasty` (Dynasty 8) et `elyzea_meca` : même socle copié d'un métier à l'autre (`main`, `agencies`, `service`, `finance`, `commission`, `direction`, `phone`, `api`) | **Modèle retenu : Dynasty 8** (métier civil, tablette, direction, finance) + garage de service du mécano |
| Grades, salaires, permissions | Grades et permissions en base (`<métier>_grades`), taux horaire par grade, paie depuis le compte société (Finance), hiérarchie vérifiée par le serveur | Repris à l'identique |
| Plusieurs entreprises d'un métier | `elyzea_agences` (types police, EMS, mécano, Dynasty 8) | Type **« presse »** ajouté : plusieurs rédactions |
| Attribution du métier par le staff | admin_menu › **Métier staff** (`staffjob.lua`, exports `AdminSetGrade` / `AdminRemove`…) | Presse ajoutée à la liste |
| Gestion de métiers génériques | `admin_menu/server/jobsmgr.lua`, `jobtools.lua`, `client/uniforms.lua` : **présents mais non chargés** par le `fxmanifest` (anciens) | Non utilisés (ils ne tournent pas) |
| Vestiaire / tenues | Aucun vestiaire actif. Vêtements = **objets** (`elyzea_clothing` + `elyzea_inventory`) ; apparence gardée par `ely_creator` ; lib `@elyzea_core/lib/clothing.lua` (packs) | Vestiaire dans la ressource ; tenue hors objets protégée par un state bag lu par `elyzea_clothing` |
| Menu ALT / target | Menu ALT d'`elyzea_police` (fournisseurs `AltOptions` / `AltSelect`), pas d'ox_target | Fournisseur `elyzea_presse` ajouté |
| Facturation | Par métier (EMS : facture immédiate ; Dynasty 8 : offre signée par le client) | Annonce payante sur le modèle « offre signée » de Dynasty 8 |
| Coffres | `elyzea_inventory:RegisterStash` (accès par métier et grade) | Coffre de la rédaction |
| Garage de service | Copié dans chaque métier (EMS, mécano) ; `elyzea_garage` = garage personnel | Même module que le mécano (pas de second système de garage) |
| Téléphone de service | `elyzea_jobphone` (annuaire, messages, appels, carte, alertes) via `PhoneBridge` | Presse raccordée (préfixe 916) |
| Annonces / journal / médias | **Aucun** (ni application de journal, ni annonces) ; animations rpemotes `newsmic`, `newscam`, `camera` disponibles | Journal créé dans la ressource : **une seule interface** (`/journal` et présentoirs) |
| Notifications, journaux d'activité | `elyzea_core:Notify`, `admin_menu:AddLog`, historiques par métier | Réutilisés |
| SQL | `@elyzea_core/lib/MySQL.lua`, tables créées au démarrage (`CREATE TABLE IF NOT EXISTS`) | Même pratique + `sql/install.sql`, `sql/uninstall.sql` |

Fichier `admin_menu.zip` fourni : comparé au dépôt avant tout changement — il est identique au dossier du dépôt sauf la
permission `clothing_manage` (dernier commit) que seul le dépôt contient. Les modifications ont donc été faites **sur la version du dépôt**,
qui contient tout le zip ; rien n'a été écrasé.

## 2. Nom technique et identité

Ressource `elyzea_presse` · métier `journaliste` · première rédaction « Weazel News » (`WZL`, matricules `WZL-001`…,
téléphone 916, couleur rouge) · compte de société `journaliste`. Grades : Stagiaire, Journaliste junior, Journaliste,
Journaliste confirmé, Rédacteur en chef, Directeur de la rédaction.

## 3. Fichiers

**Créés** (`Elyzea Base/elyzea_presse/`) : `fxmanifest.lua`, `config.lua`, `shared/perms.lua`,
`server/` (`main`, `agencies`, `service`, `finance`, `commission`, `direction`, `phone`, `api` repris du socle ;
`public`, `articles`, `interviews`, `media`, `flash`, `ads`, `gear`, `points` nouveaux),
`client/` (`main`, `items`, `interview`, `points`, `wardrobe`, `reader`, `alt`, `f6`, `tablet`, `phone`),
`html/` (`index.html`, `style.css`, `app.js`, `tablet.js`), `sql/install.sql`, `sql/uninstall.sql`,
`tests/run_server_bench.py`, `tests/server_bench.lua`, `tests/ui_nui.js`, `README.md`. Captures : `docs/presse/captures/`.

**Modifiés** (ajouts seulement, rien de retiré) :

| Fichier | Changement |
|---|---|
| `Serveur cfg/server.cfg` | `ensure elyzea_presse` après `elyzea_dynasty`, avant `elyzea_jobphone` |
| `elyzea_agences/config.lua`, `README.md` | type « presse » |
| `elyzea_jobphone/config.lua` | ligne Presse (préfixe 916) |
| `admin_menu/server/staffjob.lua` | Presse dans Métier staff |
| `admin_menu/config.lua` | permission `presse_manage` (donnée au SuperAdmin par défaut ; le Fondateur a tout) |
| `elyzea_police/client/alt.lua`, `html/app.js` | fournisseur ALT `elyzea_presse`, 2 icônes |
| `elyzea_inventory/shared/items.lua` | 5 objets `presse_*` |
| `elyzea_clothing/server/items.lua`, `outfits.lua`, `shop.lua`, `client/outfits.lua` | refus d'échanger des vêtements-objets pendant une tenue de service (`state.elyUniform`) |
| `elyzea_clothing/tests/*` | 4 nouveaux cas + simulation `Player` / `GetSlot` |
| `README.md` | métier et touches |

> ⚠ Rangs admin_menu déjà enregistrés en jeu : la permission `presse_manage` n'est ajoutée qu'aux rangs **par défaut**.
> Sur un serveur existant, cochez-la pour le SuperAdmin dans admin_menu › Grades.

## 4. Fonctionnalités (code écrit)

| Fonction | Où | Vérifié hors jeu |
|---|---|---|
| Métier, grades, permissions, attribution / retrait (staff, recrutement avec accord), mutation entre rédactions | socle | banc serveur |
| Service, temps de service, paie au taux horaire depuis le compte de la rédaction, commission | socle | banc serveur |
| Articles : brouillon, version, soumission, renvoi avec note, validation, publication, archives, retrait, historique, doublons, délai anti-spam | `articles.lua` | banc serveur + interface |
| Journal public (toutes les rédactions, rubriques, recherche, archives, petites annonces), modération staff | `articles.lua`, `public.lua`, `reader.lua` | banc + interface |
| Interviews : demande, refus, expiration, accord, anonymat, notes, fin (personne, journaliste, distance, déconnexion, service, arrêt) | `interviews.lua` | banc + interface |
| Photos / séquences (fiches, durée comptée par le serveur), jointes aux articles | `media.lua`, `items.lua` | banc (serveur) ; viseur : **à vérifier en jeu** |
| Flash info et annonce des publications, réservés à la permission `flash`, délais | `flash.lua` | banc + interface |
| Annonces payantes : offre, refus, fonds insuffisants, paiement banque / liquide, compte société, transaction, commission, remboursement | `ads.lua` | banc + interface |
| Matériel de service (prise / rendu, grade minimum), objets utilisables réservés aux journalistes en service | `gear.lua` | banc |
| Carte de presse nominative, validité vérifiée, révocation (départ, nouvelle carte) | `gear.lua` | banc + interface |
| Vestiaire (3 tenues enregistrées en jeu, packs compris), tenue personnelle, fin de service, reconnexion | `points.lua`, `wardrobe.lua` | banc (serveur) ; rendu : **à vérifier en jeu** |
| Locaux placés en jeu (garage, sortie, coffre, matériel, vestiaire, présentoirs), véhicules par grade | `points.lua` | banc (points, coffre) ; sortie de véhicule : **à vérifier en jeu** |
| Téléphone de service, F6, tablette, ALT | `phone.lua`, `f6.lua`, `tablet.lua`, `alt.lua` | interface ; **à vérifier en jeu** |

## 5. Base de données

15 tables `presse_*` (grades, employés, historique, sessions, taux, transactions, commission, réglages, articles, journal des articles,
interviews, médias, annonces, diffusions, cartes), créées au démarrage (`CREATE TABLE IF NOT EXISTS`, utf8mb4).
Aucune table existante modifiée. Retour arrière : `sql/uninstall.sql` (journalistes remis sans emploi, rédactions retirées
d'`ely_agencies`, coffre et tables du métier supprimés ; le compte société est gardé). Les deux scripts ont été exécutés
sur MariaDB 10.11 : l'installation recrée les 15 tables, la désinstallation ne touche à aucun autre métier.

## 6. Vérifications automatiques réellement exécutées (hors jeu)

| Test | Commande | Résultat |
|---|---|---|
| Banc serveur : les vrais `server/*.lua` (ordre du fxmanifest), Lua 5.4, **vraie base MariaDB 10.11**, 7 joueurs simulés, 2 rédactions, horloge virtuelle | `python3 tests/run_server_bench.py` | **139 / 139** |
| Interface (Chromium) : 19 pages de la tablette, éditeur, fiche article, F6, demande d'interview, annonce, flash, carte, viseur, journal, petit écran | `node tests/ui_nui.js` | **33 / 33**, aucune erreur JS |
| Non-régression `elyzea_clothing` (tenues enregistrées) + 4 cas « tenue de service » | `python3 tests/run_outfits_sim.py` | **54 / 54** |
| Non-régression `elyzea_clothing` (vêtements cachés) | `python3 tests/run_hidden_sim.py` | **0 échec** |
| Syntaxe Lua 5.4 des 29 fichiers de la ressource, syntaxe JS | — | OK |

Le banc serveur couvre les 10 points demandés côté serveur : attribution / retrait, grade gardé (relecture de la base, reconnexion),
accès selon le grade, vestiaire (tenue, blocage, fin de service), objets (matériel, utilisation refusée hors métier), article
(création → publication, journal public), **refus d'interview**, protection des actions de direction (faux événements, grades,
paie, renvoi), redémarrage (interviews et sessions fermées, données intactes), isolation des rédactions.
Il a trouvé et fait corriger 3 défauts avant livraison : identifiant d'une personne **anonyme** enregistré quand même,
photo « Ne pas garder » enregistrée quand même, auteur affiché sur une annonce diffusée (idiome Lua `x and nil or y`).
Le test d'interface a trouvé une fonction manquante (`toast`) corrigée.

**Non couvert hors jeu** : rendu des tenues, animations et objets tenus, caméra du viseur, marqueurs, création réelle de véhicules,
pma-voice / téléphone, comportement à plusieurs vrais clients, performances.

## 7. Tests en jeu à faire (au moins 3 joueurs)

Voir `Elyzea Base/elyzea_presse/README.md` › « Tests à faire en jeu » (10 scénarios, dont la non-régression des autres métiers :
menu ALT police / EMS / mécano / animations, F6 et téléphone de service des autres métiers, boutique et F3 hors tenue de service).

## 8. Reste à configurer en jeu

1. **Emplacement de la rédaction** : aucune coordonnée n'est codée. La direction place garage, sortie, coffre, matériel, vestiaire
   et présentoirs (tablette › Locaux) à l'endroit choisi (MLO ou bâtiment du jeu). `/presse_pos` affiche la position.
2. **Tenues** : enregistrer les 3 tenues en homme et en femme (vêtements de la boutique ou d'un pack caché).
3. **Véhicules** : vérifier `rumpo`, `tailgater`, `burrito3`, `frogger` sur le serveur (ou les remplacer, avec les livrées voulues).
4. **Taux horaires, commissions, tarifs des annonces, permissions des grades** (tablette › Finance / Annonces / Permissions).
5. **Direction** : nommer le directeur (Métier staff › Presse) ; donner `presse_manage` aux modérateurs voulus.
6. Images facultatives : `elyzea_inventory/html/img/presse_appareil.png`, `presse_bloc.png`, `presse_carte.png` (256 × 256).
7. Intégrations externes non faites (absentes du serveur) : capture d'images (`screenshot-basic` + hébergement), application de
   journal dans un téléphone personnel.
