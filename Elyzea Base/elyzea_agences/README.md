# elyzea_agences — plusieurs polices, EMS, mécanos et agences Dynasty 8

> **État : écrit et testé hors jeu** (syntaxe Lua/JS, et les vrais fichiers serveur exécutés dans un banc d'essai
> avec une base MariaDB : migration d'une base existante, création d'agence, nomination, zones, routage des alertes,
> isolation entre agences, mutation, téléphone de service, suppression). **Rien n'a été testé sur un serveur FiveM.**

Comme les concessions : on crée en jeu autant d'agences que l'on veut pour chaque métier.
Chaque agence a **son métier elyzea_core** (ex. `bcso`), **ses grades**, **ses employés**, **son compte de société**,
**son préfixe de matricule**, **son téléphone de service** (préfixe et couleur) et **sa zone d'alerte**.

| Métier | Ressource | Agence de départ (reprise telle quelle) |
|---|---|---|
| Police | `elyzea_police` | `police` · LSPD |
| EMS | `elyzea_ems` | `ambulance` · SAMS |
| Mécano | `elyzea_meca` | `mechanic` · Mécano |
| Dynasty 8 | `elyzea_dynasty` | `realestate` · Dynasty 8 |
| Presse | `elyzea_presse` | `journaliste` · Weazel News |

La concession (`elyzea_concess`) était déjà multi-concessions et n'est pas concernée.

## Installation

1. `server.cfg` : `ensure elyzea_agences` **avant** `elyzea_police` (déjà ajouté), et `ensure elyzea_jobphone` après les métiers (déjà ajouté).
2. Base de données : table `ely_agencies` créée automatiquement (`sql/install.sql` pour une installation manuelle).
   Au premier démarrage, chaque métier ajoute une colonne `job` à ses tables : **tout ce qui existe est rattaché à la première agence**
   (employés, grades, salaires dus, historique, transactions). Rien n'est supprimé.
3. admin_menu : permission **`agencies_manage`** (donnée au SuperAdmin ; le Fondateur a tout), onglet **Agences des métiers** ou `/agences`.
   Sans admin_menu : `add_ace group.admin elyzea.agences allow`.

## Créer une deuxième police (exemple : sheriff à Paleto)

1. `/agences` › onglet **Police** › **+ Nouvelle agence** : nom (*Blaine County Sheriff*), nom court (*BCSO*), métier (*bcso*),
   préfixe de matricule (*BCSO-*), préfixe du téléphone (*921* → numéros 921-XXXX), couleur.
   Les grades par défaut (Cadet → Commissaire), le métier `bcso` et le compte de société `bcso` sont créés tout seuls.
2. **Zone d'alerte** :
   - **Sur la carte** (recommandé pour une grande zone) : clic gauche = un coin, clic droit = retirer le dernier,
     double-clic ou clic sur le premier coin = fermer la forme, glisser = déplacer, molette = zoom.
     Plusieurs formes possibles, gomme pour en retirer une, puis **Enregistrer la zone**.
   - **En jeu** (« 🧭 En jeu ») : l'outil de dessin de l'éditeur de map d'admin_menu (coins posés un par un en visant le sol, noclip possible).
     La forme dessinée est ajoutée à la zone de l'agence.
   - Hors dessin, un clic sur la carte indique **quelle agence recevrait une alerte à cet endroit**.
3. **Nommer le directeur** : ID serveur du joueur → plus haut grade de l'agence. Il recrute ensuite lui-même (tablette / F6).

## Règles des alertes

Une alerte du public (police : coups de feu, braquages, vols, `/police`, alertes des autres scripts ; EMS : appels, comas, `/ems` ;
mécano : demandes de dépannage) va :

1. aux agences dont la **zone contient le lieu** ;
2. sinon aux agences **sans zone** (elles couvrent « le reste de la carte ») ;
3. sinon (toutes les agences ont une zone) à l'agence **la plus proche** (`Config.Outside = 'all'` : à toutes).

Les alertes internes (alerte agent police, soutien EMS, alertes du téléphone de service) restent **dans l'agence de leur auteur**.

## Ce qui est séparé / partagé

**Deux agences d'un même métier sont totalement séparées** : chacune ne voit, ne modifie et ne facture que ce qui lui appartient.
Le serveur le vérifie à chaque action (pas seulement l'interface).

| Séparé par agence | Détail |
|---|---|
| Grades, permissions, salaires, commissions, employés, recrutement, direction, historique | (déjà le cas) |
| Compte de société, chiffre d'affaires, paie, transactions, factures, **statistiques** | tableaux de bord, CA du jour / 7 jours, statistiques : seulement l'agence |
| Alertes, appels, carte des collègues, téléphone de service | (déjà le cas) |
| Garage de service, coffre d'atelier / pharmacie | (déjà le cas) |
| **Mécano** | **points d'atelier** (chaque point appartient à l'agence qui l'a posé ; les autres ne le voient pas et ne peuvent pas l'ouvrir), **catalogue et prix**, devis, historique des véhicules, ponts roulants de ses points |
| **EMS** | **tarifs des soins et des PPA**, **dossiers médicaux** (un dossier par patient ET par agence : notes, groupe sanguin, allergies), actes, comptes rendus, PPA délivrés, analyses du laboratoire, **postes des dossiers**, rendez-vous (attribués à l'agence qui couvre l'endroit de la demande) |
| **Police** | amendes vues par les agents, **avis de recherche**, **rapports**, casier (`Config.SharedRecords = true` dans `elyzea_police/config.lua` pour partager ce fichier entre polices) |
| **Dynasty 8** | **biens** (chaque bien est géré par une agence, choisie par le staff dans la fiche du bien), contrats, visites, tarifs |
| **Presse** | articles, flashs, interviews, médias (déjà le cas) |

Restent communs, volontairement :
- l'**état de santé du personnage** (maladies en cours, blessures, sang, vaccins) : c'est son corps, pas un dossier d'agence ;
- les **règles du jeu** réglées par le staff (maladies, actes médicaux) ;
- ce qui appartient au **joueur** : ses amendes à payer (`/amendes`), son bien acheté, son véhicule.

Mise à jour d'une base existante : tout ce qui existe est rattaché à la **première agence** de chaque métier (rien n'est perdu ;
les tarifs, points et catalogue actuels deviennent ceux de la première agence). Une nouvelle agence reçoit le catalogue mécano de départ.
Test sur une vraie base MariaDB : `tests/separation_db_test.py`.

L'argent encaissé va sur le compte de l'agence de l'employé qui encaisse (amendes, factures, PPA, devis, ventes et locations).
Les frais d'hôpital vont à l'agence EMS dont la zone couvre le lieu du coma.

## Mutation et suppression

- Donner à quelqu'un le métier d'une autre agence (`/setjob`, menu admin, Métier staff, « Nommer ») le **mute** : nouveau matricule,
  grade de la nouvelle agence au même niveau, service terminé, salaire dû conservé.
- **Supprimer** une agence (taper son métier pour confirmer) : ses employés sont retirés du métier, ses grades supprimés,
  le métier retiré d'elyzea_core. Rapports, dossiers, transactions et argent du compte restent. La dernière agence d'un métier ne peut pas être supprimée.
- Le nom du métier d'une agence ne peut plus être changé après la création (nom, nom court, préfixes et couleur oui).

## Autres scripts

Les scripts qui passent par les exports d'`elyzea_police` (braquages, drogue, NOIR X…) comptent automatiquement **toutes** les polices
et leurs alertes sont routées par zone. Ceux qui ont une **liste de métiers** dans leur configuration doivent recevoir le nouveau métier
(ex. `bcso`) : `gofast/config.lua` (`Config.Police.Jobs`), `admin_menu/config.lua` (`Config.PoliceJobs`, exception des safe zones),
`elyzea_papiers/config.lua`, portes et coffres réservés à un métier.

## Exports (serveur)

```lua
exports.elyzea_agences:GetAgencies('police')            -- liste des agences d'un métier
exports.elyzea_agences:GetAgency('bcso')                -- une agence
exports.elyzea_agences:Route('police', vector3(x, y, z)) -- métiers qui reçoivent une alerte à cet endroit
-- Dans chaque métier : exports.elyzea_police:GetAgencies(), :GetAgencyOf(src), :AgencyStats(job)
```

## Tests à faire en jeu

1. Démarrage : aucune erreur, `ely_agencies` créée avec une agence par métier, anciens employés toujours dans leur métier.
2. Création d'une police BCSO, d'un EMS et d'un garage à Paleto ; nomination d'un directeur ; recrutement depuis sa tablette.
3. Zones : alerte de tirs à Paleto → seulement le BCSO ; à Los Santos → seulement le LSPD ; à Sandy Shores → agence sans zone ou la plus proche.
4. Tablettes : employés, grades, finance, historique, carte et alertes de sa seule agence.
5. Téléphone de service : numéro avec le préfixe de l'agence, couleur, annuaire et messages limités à l'agence.
6. Mutation par `/setjob`, puis suppression d'une agence de test.
