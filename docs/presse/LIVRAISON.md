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


---

# Mise à jour : annonces commandées par les entreprises (applications « Annonce » et « Planning »)

> Même règle : **rien n'a pu être testé dans le jeu**. Les vérifications ci-dessous ont été réellement exécutées hors jeu.

## A. Analyse : ce qui est réutilisé

| Besoin | Système existant réutilisé |
|---|---|
| Entreprises de journalisme multiples | Rédactions `elyzea_agences` (type presse) : chacune son métier, ses employés, ses grades, son compte de société |
| Comptes bancaires professionnels | `elyzea_core` : `RemoveSocietyMoney` (débit atomique, refusé si le solde manque), `AddSocietyMoney`, journal `elyzea_society_logs` ; droit de payer = `job.bankAuth` (grade patron) ; concessions : `elyzea_concess:GetShopOf().society` |
| Téléphone de service | `elyzea_jobphone` : 2 applications ajoutées dans son interface et ses actions serveur (aucun nouveau téléphone) |
| Employés en service, grades, permissions | Socle du métier (`P.CrewOnDuty`, `P.Can`, permissions `ads` / `ads_manage`) |
| Primes | Même circuit que la paie et la commission existantes : compte de la rédaction → `P.PayBank`, ligne `commission` dans `presse_transactions` |
| Menu administratif | `admin_menu` : nouvel onglet sur le modèle des onglets existants (`AM.Actions` + `DataHooks`), permission `presse_manage` |
| Position de la mini-carte | `exports.admin_menu:GetMinimapRect()` (rectangle réel calculé par la mini-carte) |
| Persistance | Tables créées au démarrage dans la base existante (`@elyzea_core/lib/MySQL.lua`), réglages dans `presse_settings` |

**Remplacé** : l'ancien système « annonce payante proposée par ALT à un joueur » (table `presse_ads`) faisait doublon ; il est retiré
(code, interface, ALT). La table n'est plus créée ; `sql/uninstall.sql` la supprime si elle existe.

## B. Fichiers

**Créés** : `elyzea_presse/server/annonces.lua` (cœur : texte, calendrier, commande et paiement, planificateur, file, primes, reprise, API du téléphone et d'admin_menu),
`elyzea_presse/client/annonce.lua` (affichage au-dessus de la mini-carte), `admin_menu/server/presse.lua`, `admin_menu/html/presse.js`,
`elyzea_presse/tests/ui_phone.js`, `elyzea_presse/tests/ui_admin.js`.

**Modifiés** : `elyzea_jobphone/server/main.lua` (actions `annonce` et `planning`, transmises à `elyzea_presse`), `elyzea_jobphone/html/app.js` et `style.css`
(applications Annonce et Planning) ; `admin_menu/fxmanifest.lua`, `html/index.html`, `config.lua` (libellé de `presse_manage`) ;
`elyzea_presse` : `config.lua` (`Config.Annonces`), `shared/perms.lua`, `fxmanifest.lua`, `server/main.lua`, `server/articles.lua`, `html/*`, `client/alt.lua`, `client/interview.lua`,
`sql/install.sql`, `sql/uninstall.sql`, `tests/server_bench.lua`, `tests/ui_nui.js`, `README.md`. **Supprimé** : `elyzea_presse/server/ads.lua`.

## C. Base de données

Deux tables, créées automatiquement (ou `sql/install.sql`) : `presse_ad_orders` (commande : rédaction, entreprise et compte clients, texte, fréquence, dates,
prix unitaire contractuel, nombre, total, remboursé, état, clé de demande **unique**) et `presse_ad_slots` (une ligne par diffusion : heure, état
`scheduled → offered → queued → broadcasting → sent` ou `missed` / `cancelled` / `failed`, mode auto / manuel, journaliste, prime et son état, essais, erreur,
remboursement ; **unique** (commande, heure)). Aucune table existante modifiée. Réglages globaux : clé `annonces` de `presse_settings` ;
par rédaction : clé `adcfg:<métier>`.

## D. Vérifications réellement exécutées

| Test | Résultat |
|---|---|
| Banc serveur (vrais fichiers, **MariaDB 10.11**) — 64 nouvelles vérifications pour les annonces | **203 / 203** |
| Téléphone de service dans Chromium (vrai `elyzea_jobphone/html`) : Annonce, compteur 150/151, emojis, dates, récapitulatif, refus, paiement, commandes, Planning | **16 / 16**, aucune erreur JS |
| Onglet admin_menu « Annonces presse » (vrai `admin_menu/html`) | **5 / 5**, aucune erreur JS |
| Interface du métier (bandeau au-dessus de la mini-carte, page Annonces de la tablette) | **34 / 34**, aucune erreur JS |
| Installation / désinstallation SQL sur MariaDB | OK (16 tables ; la désinstallation ne touche pas aux autres métiers) |

Les 20 scénarios demandés sont couverts par le banc serveur : rédactions indépendantes (2), changement de tarif, 150 caractères accepté,
151 refusé, emojis, paiement par le compte de l'entreprise, fonds insuffisants, nombre de diffusions (30 min, 1 h, quotidien, aujourd'hui,
dates invalides), envoi automatique sans journaliste, envoi manuel, prime seulement après une diffusion manuelle réelle, aucune prime en automatique,
3 annonces à la même heure affichées l'une après l'autre (écart mesuré = durée d'affichage + pause), durée réglée à 5 s depuis admin_menu,
aucune double diffusion ni double prime (deux journalistes, envoi rejoué, même demande envoyée deux fois, prix modifié par le client), reprise après
redémarrage (affichage coupé, paiement coupé), refus pour les non-autorisés (sans entreprise, employé sans accès au compte, non-journaliste, stagiaire,
hors service), isolation entre rédactions, journaliste qui quitte son service, erreurs d'affichage (nouvel essai, échec, relance), file en pause,
diffusion trop en retard remboursée, annulation contrôlée d'une commande.

Défaut trouvé par les tests et corrigé : après un paiement **refusé**, le téléphone réutilisait la même clé de demande, et le serveur refusait
(à raison) le nouvel essai. Désormais : même clé seulement sans réponse (réseau / double clic), nouvelle clé après un refus.

## E. À vérifier en jeu (au moins 3 joueurs : patron d'une entreprise, journaliste, spectateur)

1. Commander depuis le téléphone d'un patron (et refus pour un employé), voir le débit du compte de l'entreprise et le crédit de la rédaction (tablettes Finance).
2. Journaliste en service : notification, Planning, « Envoyer l'annonce », bandeau chez tous les joueurs, prime en banque.
3. Sans journaliste en service : envoi automatique à l'heure ; plusieurs annonces à la même heure : l'une après l'autre.
4. Position du bandeau au-dessus de la mini-carte sur plusieurs résolutions (16:9, 21:9) et avec d'autres éléments du HUD.
5. Durée d'affichage changée dans admin_menu ; pause / relance de la file ; `restart elyzea_presse` pendant un affichage.

## F. Limites

- « Tous les joueurs concernés » = tous les joueurs connectés (pas de ciblage par zone : le serveur n'en a pas pour les annonces).
- Le serveur ne peut pas savoir si un client a réellement vu l'annonce : une diffusion est « envoyée » quand la durée d'affichage est écoulée pour tous.
  Une diffusion coupée par un arrêt du serveur est rejouée (au pire vue deux fois, jamais perdue ni payée deux fois).
- La longueur suit les règles Unicode des emojis courants (séquences ZWJ, teintes, drapeaux, accents combinés) ; le même calcul est fait dans le téléphone
  et sur le serveur, donc le compteur et le contrôle serveur sont toujours d'accord.
- Une entreprise sans téléphone de service (métier non raccordé à `elyzea_jobphone`) ne peut pas commander : le téléphone de service est le seul point d'entrée prévu.
