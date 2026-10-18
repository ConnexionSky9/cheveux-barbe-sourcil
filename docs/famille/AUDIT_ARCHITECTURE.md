# Écosystème famille, animaux et télévision — audit du serveur et architecture

Document de l'étape 1 (audit) et de l'étape 2 (architecture) du cahier des charges.
Il sert de référence pour tous les modules suivants. Le premier livrable (modèle 3D du bébé) est décrit dans
`Outils_3D/bebe/README_BEBE.md`.

---

## 1. Framework et ressources détectés

**Framework : base maison `elyzea_core`** (ni ESX, ni QBCore, ni Qbox — Qbox et ox ont été retirés, voir `README.md` du dépôt).
L'API reprend la forme de QBCore (`Player.PlayerData`, `Player.Functions.AddMoney`, `citizenid`…), ce qui facilite l'intégration.

| Domaine | Ressource | Ce qui est utilisable |
|---|---|---|
| Base, personnages | `elyzea_core` | `GetPlayer`, `GetPlayerByCitizenId`, `GetOfflinePlayer`, `citizenid`, `charinfo` (prénom, nom, date de naissance, sexe), métadonnées, événements `elyzea:server:playerLoaded / playerUnloaded / characterDeleted` |
| Base de données | `elyzea_core` (pilote Node, remplace oxmysql) | `@elyzea_core/lib/MySQL.lua` : `query/single/scalar/insert/update/transaction` (`.await`), requêtes préparées |
| Bibliothèque commune | `@elyzea_core/lib/ely.lua` | notifications, barre de progression, rappels client↔serveur (`Ely.callback`), touches |
| Argent | `elyzea_core` | `cash`, `bank`, `crypto` ; `AddMoney/RemoveMoney` (refus si solde insuffisant en liquide), comptes de société `AddSocietyMoney/RemoveSocietyMoney` |
| Métiers, grades | `elyzea_core` + `elyzea_agences` | `CreateJobs`, grades, service ; plusieurs agences par métier (police, EMS, mécano, Dynasty 8) |
| Permissions staff | `admin_menu` + ACE | grades support → fondateur, `exports.admin_menu:HasPermission(src, cle)`, liste `Config.Permissions` ; ACE `group.admin/mod/support` dans `permissions.cfg` |
| Identité, apparence | `ely_creator` (+ `elyzea_multichar`) | table `ely_characters.skin` : parents GTA `heritage.mom/dad` (0-45), `shapeMix`, `skinMix`, 20 traits du visage, `eyeColor` (0-31), cheveux (style, couleur 0-63). Âge minimum **18 ans** imposé à la création. Taille visible réglable (`client/height.lua`, mise à l'échelle du personnage) |
| Inventaire | `elyzea_inventory` | objets déclarés dans `shared/items.lua` (un objet inconnu est refusé), `RegisterUsableItem`, métadonnées par objet, `AddItem/RemoveItem/GetItemCount/CanCarryItem`, coffres |
| Médical | `elyzea_ems` | `IsEms`, `IsOnDuty`, `HasPermission`, actes tracés (`ems_treatments`), factures (`ems_invoices`), dossiers patients, menu ALT |
| Interactions | menu **ALT** de `elyzea_police` | fournisseurs externes : `AltOptions(ctx)` / `AltSelect(id, ctx)` (déjà utilisé par EMS, mécano, braquages) |
| Animations | `rpemotes` (externe, non fourni) + `elyzea_animations` | ≈ 1 500 animations, animations en duo par demande / acceptation (`shared_emotes.lua`) |
| Logement | `elyzea_dynasty` | biens immobiliers, accès, décoration, coffres (`d8_properties`, `d8_contracts`…) |
| Placement d'objets / PNJ | `admin_menu` (éditeur) | props et PNJ posés en jeu, `GetPropsByRole`, points de spawn |
| Téléphone | `elyzea_aura` (+ `blackphone`, `noirx`) | notifications et applications (possible support du suivi de grossesse plus tard) |
| Version du jeu | `server.cfg` | `sv_enforceGameBuild 3258` ; FXServer artefact **35245** (canal stable, confirmé) |

**Absents du serveur** (aucun conflit direct) : grossesse, enfants, animaux de compagnie, vétérinaire, crèche, refuge, télévision / DUI.

## 2. Systèmes existants réutilisés (aucun système parallèle)

- **Identité** : `citizenid` d'elyzea_core pour les parents, responsables, propriétaires. Aucun second système d'identité.
- **Argent** : `RemoveMoney` d'elyzea_core (banque puis liquide, comme les factures EMS) ; recettes vers les comptes de société.
- **Objets** : préservatif, pilule, test de grossesse, biberon, croquettes… déclarés dans `elyzea_inventory/shared/items.lua`, utilisés via `RegisterUsableItem` (consommation vérifiée côté serveur).
- **Permissions** : `admin_menu` (staff) + métiers d'elyzea_core (médecin, puéricultrice, travailleur social, vétérinaire, agent de refuge) — les agences d'`elyzea_agences` permettent plusieurs établissements.
- **Médical** : grossesse suivie par les EMS en service (`exports.elyzea_ems:IsOnDuty`), actes facturés par leur système de factures.
- **Interactions** : options ajoutées au menu ALT (demande d'interaction, prendre / reposer le bébé, soins animaux).
- **Apparence** : héritage calculé depuis `ely_characters.skin` des deux parents.
- **Animations** : animations natives GTA et celles de rpemotes ; duo synchronisé côté serveur.

## 3. Conflits, dépendances et limites découvertes

| Sujet | Constat | Conséquence |
|---|---|---|
| Objets d'inventaire | elyzea_inventory refuse les objets non déclarés | **modification de `elyzea_inventory/shared/items.lua`** (ajout de lignes, rien de supprimé) |
| Menu ALT | la liste des fournisseurs est codée dans `elyzea_police/client/alt.lua` | **ajout d'une ligne** `{ res = 'elyzea_famille', prefix = 'fam:' }` |
| Permissions staff | `admin_menu/config.lua` liste les permissions | ajout de clés (`famille_staff`, `animaux_staff`, `tv_staff`) aux grades SuperAdmin+ |
| Suppression d'un personnage | `Config.Characters.deleteTables` efface ses lignes | les enfants **ne sont pas** supprimés : le parent supprimé est marqué, l'enfant passe en dossier social (événement `characterDeleted`) |
| Ventre de grossesse | GTA n'a **aucune déformation de ventre** pour les personnages ; ely_creator non plus | solution proposée : tenues de grossesse (vêtements à ventre arrondi, 3 tailles) **à créer** avec la même chaîne 3D, appliquées automatiquement selon le stade. À valider avec toi |
| Enfants qui grandissent | GTA n'a **aucun PNJ enfant** | nouveau-né / nourrisson = modèles objets (livrés) ; « jeune enfant » et « enfant » = personnage freemode réduit (technique déjà utilisée par `ely_creator/client/height.lua`), proportions d'adulte : limite assumée |
| Animaux | GTA a chiens (8 races), chat, lapin, poules, oiseaux ; **pas de cheval** ni de petits (chiots, chatons) | petits = animal adulte réduit (même technique de mise à l'échelle) ; **chevaux = modèle animal sur mesure**, très lourd (squelette + animations de marche) : à décider |
| Animation intime | une animation duo personnalisée demande le squelette des personnages GTA dans Blender (fichiers du jeu, que je n'ai pas) | version 1 : animations natives + fondu au noir (prévu par le cahier des charges), aucune représentation explicite |
| Télévision | pas de DUI sur le serveur | ressource nouvelle ; certaines vidéos YouTube refusent l'intégration (erreurs 101/150) : message explicite, pas de contournement |
| rpemotes | ressource externe, non fournie | je n'utiliserai que des animations natives vérifiées par nom ; rpemotes reste optionnel |
| VIP | aucun système VIP sur le serveur | proposition : ACE `group.vip` (dans `permissions.cfg`) ; à confirmer |

## 4. Architecture proposée

### 4.1 Ressources

```
Elyzea Base/
├── elyzea_bebe_modele/     (LIVRÉ) modèle 3D du bébé, exports d'affichage, commandes de test
├── elyzea_famille/         intimité + consentement, contraception, grossesse, accouchement, enfants,
│                           héritage, croissance, transport, crèche, protection de l'enfance
├── elyzea_animaux/         animaux, reproduction, portées, héritage, vétérinaire, pensions, refuges
└── elyzea_tv/              télévisions YouTube (DUI), sessions, permissions
```

Pourquoi `elyzea_famille` regroupe autant de modules : l'enfant a **un seul emplacement logique** (parent, crèche, famille d'accueil…),
et toutes ces fonctions le modifient. Un seul propriétaire de cet état = pas de course entre ressources, une seule source de vérité.
Chaque module reste un fichier séparé et **désactivable** dans `config.lua`.

Organisation interne (même modèle que `jewelry_heist`, déjà sur le serveur) :

```
elyzea_famille/
├── fxmanifest.lua · config.lua · README.md · sql/install.sql
├── adapters/        core.lua, inventory.lua, money.lua, permissions.lua, ems.lua, notify.lua
├── server/          main.lua, ids.lua, locks.lua, ratelimit.lua, audit.lua,
│                    intimite.lua, contraception.lua, grossesse.lua, accouchement.lua,
│                    enfants.lua, heritage.lua, croissance.lua, transport.lua, creche.lua, protection.lua
├── client/          main.lua, intimite.lua, grossesse.lua, enfants.lua, transport.lua, creche.lua
└── html/            interfaces NUI (consentement, suivi privé, dossier médical, enfants, crèche, dossiers sociaux)
```

### 4.2 Règles communes (tous les modules)

1. **Le serveur décide de tout** : le client n'envoie que des intentions (« je demande », « j'accepte ») ; résultats, probabilités, paiements et naissances sont calculés et écrits par le serveur.
2. **Temps calculé, jamais décompté** : on enregistre des dates (conception, prise de pilule, dépôt en crèche) ; l'avancement est calculé à la lecture (`maintenant − date`). La progression hors ligne et après redémarrage est donc exacte, sans boucle coûteuse. Un seul planificateur (1 tick / minute) traite les échéances indexées (`due_at`).
3. **Pas de doublon par construction** : contraintes d'unicité SQL (une tentative de conception par interaction, un enfant par `(grossesse, rang)`, un paiement par séjour et période) + transactions SQL. Un double clic ou un crash au mauvais moment ne crée rien en double.
4. **Emplacement unique** : chaque enfant / animal a `location_type` + `location_ref` + `version` ; tout déplacement est un `UPDATE … WHERE version = ?` (verrou optimiste). Porté par un seul joueur à la fois.
5. **Déconnexion ≠ abandon** : une déconnexion remet l'enfant / l'animal à son dernier emplacement sûr (domicile, crèche) ; aucun dossier social automatique.
6. **Limites d'appels** sur chaque événement réseau, validation de tous les paramètres, journaux d'audit par domaine.
7. **Confidentialité** : contraception, grossesse et dossiers médicaux visibles par le personnage concerné, puis par ceux qu'il autorise ou les rôles médicaux en service.

### 4.3 Base de données (tables à créer, créées automatiquement au démarrage + `sql/install.sql`)

Famille : `rp_contraception`, `rp_intimacy_sessions`, `rp_conception_attempts`, `rp_pregnancies`, `rp_pregnancy_events`,
`rp_pregnancy_medical_records`, `rp_children`, `rp_child_caregivers`, `rp_child_location_log`, `rp_nursery_stays`, `rp_nursery_payments`,
`rp_child_cases`, `rp_child_case_notes`, `rp_child_placements`, `rp_adoption_applications`, `rp_child_case_logs`.
Animaux : `rp_animals`, `rp_animal_breeding`, `rp_animal_litters`, `rp_animal_health_records`, `rp_animal_care_stays`,
`rp_animal_payments`, `rp_animal_ownership_history`, `rp_animal_cases`, `rp_animal_case_notes`, `rp_animal_placements`,
`rp_animal_adoption_applications`, `rp_animal_case_logs`.
Télévision : `rp_tv_screens` (télévisions posées), `rp_tv_sessions`, `rp_tv_logs`.
(Les schémas détaillés, index et contraintes seront livrés avec chaque module.)

### 4.4 Données déjà fixées par le modèle 3D livré

Apparence d'un bébé = `{ teinte = peau1..6, yeux = ardoise|bleu|vert|noisette|marron, coiffure = duvet_*|touffe_*|chauve }`,
enregistrée à la naissance dans `rp_children.appearance` (JSON). L'héritage (module 6) produira ces valeurs à partir de l'apparence des parents
(`skinMix`, parents GTA, `eyeColor`, couleur de cheveux), avec option « ressemblance marquée à un parent » (40 % par défaut).
Ce sera un choix parmi des variantes visuelles, pas une génétique biologique.

## 5. Fichiers créés ou modifiés

| Étape | Créés | Modifiés |
|---|---|---|
| Livré : modèle bébé | `Outils_3D/bebe/**`, `Elyzea Base/elyzea_bebe_modele/**`, ce document | `Serveur cfg/server.cfg` (+1 `ensure`) |
| Socle + intimité + contraception | `Elyzea Base/elyzea_famille/**` | `elyzea_inventory/shared/items.lua` (+objets), `elyzea_police/client/alt.lua` (+1 fournisseur), `admin_menu/config.lua` (+permissions), `server.cfg` |
| Grossesse → crèche → protection | dans `elyzea_famille` | — |
| Animaux | `Elyzea Base/elyzea_animaux/**` | `items.lua`, `alt.lua`, `admin_menu/config.lua`, `server.cfg` |
| Télévision | `Elyzea Base/elyzea_tv/**` | `permissions.cfg` (rôles), `server.cfg` |

## 6. Outils de création 3D (tous gratuits, installés et utilisés dans mon environnement)

| Outil | Rôle | Licence |
|---|---|---|
| Blender 5.2 (module Python `bpy`) | maillage, UV, cuissons, squelette, poids, poses, rendus | GPL |
| numpy, scikit-image, Pillow | forme procédurale (SDF + marching cubes), textures, DDS | BSD / HPND |
| Sollumz 2.9.0 + szio | conversion vers les formats GTA (CodeWalker XML) | GPL-3 (outil seulement, rien d'inclus dans les fichiers du jeu) |
| CodeWalker.Core (via .NET 8) | XML → binaires `.ydr/.ytd/.ytyp` + relecture de contrôle | MIT |

## 7. Limites de mon environnement

- **Pas de GTA V ni de client FiveM** : je ne peux pas lancer le jeu. Tout ce qui est « en jeu » (affichage, positions, animations, NUI dans le jeu) reste à tester par toi avec les procédures fournies.
- **Pas de base MySQL réelle** : les requêtes seront vérifiées par relecture et, quand c'est possible, sur une base MariaDB locale de test.
- **Pas de fichiers du jeu** : pas de squelette des personnages GTA → pas d'animation duo personnalisée en version 1 (animations natives + fondu au noir).
- **Lua** : syntaxe vérifiée avec Lua 5.4 ; les fonctions natives de FiveM ne peuvent pas être exécutées ici.

## 8. Premier livrable complet et vérifiable : le modèle 3D du bébé

Voir `Outils_3D/bebe/README_BEBE.md` (ce qui a été exécuté, converti, contrôlé, et ce qui reste à tester)
et `Elyzea Base/elyzea_bebe_modele/README.md` (installation et procédure de test en jeu : `/bebe_test`, `/bebe_galerie`, `/bebe_ajuster`).

## 9. Décisions prises (réponses du propriétaire du serveur)

| Sujet | Décision | Conséquence technique |
|---|---|---|
| Artefact FXServer | **35245** (stable) | fonctions natives récentes disponibles (state bags, OneSync) |
| Ventre de grossesse | **tenues de grossesse** à créer | 3 tailles de ventre en vêtements (chaîne 3D d'`Outils_3D`), appliquées selon le stade |
| Animaux | **pas de chevaux** ; animaux existants du jeu **légèrement modifiés** (pelages de chats, nouvelles races de chiens…) | nouvelles textures (`.ytd`) sur les modèles d'animaux existants, pas de nouveau squelette |
| Crèche | **un PNJ**, payé directement selon le **nombre d'enfants** et la **durée** | pas de métier : PNJ posé dans l'éditeur, tarif calculé par le serveur |
| Abandon / protection de l'enfance | **un PNJ** | dépôt et suivi auprès d'un PNJ, sans travailleur social joueur |
| Animaleries (ferme, domestiques, exotiques) | **des PNJ** | un PNJ par animalerie, catalogue par type d'animal |
| VIP (télévision) | **créer un rôle VIP** | groupe ACE `group.vip` dans `permissions.cfg` (module télévision) |

Non précisé, choisi par défaut (modifiable) : le **vétérinaire** et la **pension animale** seront aussi des PNJ, dans la logique ci-dessus.

## 10. Avancement

| Étape | État |
|---|---|
| 1. Audit · 2. Architecture | fait (ce document) |
| 5. Modèle 3D du bébé | V2 (normales corrigées, cheveux, visage), non testé en jeu (`elyzea_bebe_modele` 1.1) |
| 6 (partiel). Portage visible par tous, poser, prises, combat bloqué pendant le portage | fait, non testé en jeu — voir `LIVRAISON_V2.md` |
| 3. Moment intime, contraception + tirage de conception, création de la grossesse | fait, non testé en jeu (`elyzea_famille` 0.2) |
| 4 (partiel). Test de grossesse, examen EMS, suivi `/grossesse`, progression hors ligne | fait (0.2) ; symptômes, tenues de grossesse, accouchement : à faire |
| Contraceptifs achetables (supérette, PNJ « Pharmacie ») | fait |
| 6 à 11 | à faire |
