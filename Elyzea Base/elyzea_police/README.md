# elyzea_police

Métier Police complet pour la **base Elyzea** (elyzea_core, elyzea_inventory), relié au menu admin (`admin_menu`)
et configuré en jeu avec la tablette staff (`elyzea_police_staff`).

## Installation
1. **Arrête tout autre script de police** (qbx_police, qb-policejob, ps-mdt, ps-dispatch…) : ils feraient doublon.
2. Place `elyzea_police` et `elyzea_police_staff` dans `resources/`.
3. Dans `server.cfg` :
   ```
   ensure admin_menu
   ensure elyzea_police
   ensure elyzea_police_staff
   ```
4. Les tables SQL (`police_settings`, `police_records`, `police_fines`, `police_warrants`, `police_jail`) sont créées automatiquement.
5. Ouvre la tablette staff (`/police_staff` ou menu admin › Métiers › Police) et pose les points : prise de service,
   armurerie, prison, sortie de prison (des points par défaut à Mission Row et Bolingbroke sont déjà posés).

## Pour les agents
| Action | Touche par défaut |
|---|---|
| Tablette de l'agent | F6 |
| Menu d'interaction (personne la plus proche) | F7 |
| Accepter / ignorer un appel | Y / U |
| Bouton panique | à assigner |

Touches modifiables : Paramètres › Raccourcis clavier › FiveM › « Police : … ».

**Tablette (F6)** : accueil (agents en service, appels, avis, derniers rapports, prise de service, indicatif),
appels du dispatch (accepter, GPS, clôturer), citoyens (recherche, dossier complet, permis, casier, amendes, véhicules),
véhicules (recherche de plaque), rapports, avis de recherche, prison, effectif (recruter, promouvoir, renvoyer).

**Menu d'interaction (F7)** : menotter / démenotter, escorter, mettre dans / sortir d'un véhicule, fouiller (elyzea_inventory),
vérifier l'identité, amende (catalogue + montant libre), prison.

**Points** : prise de service (E), armurerie (E, boutique elyzea_inventory filtrée par grade).

## Pour les citoyens
- `/112 <message>` : appeler la police (position envoyée).
- `/amendes` : voir et payer ses amendes impayées.
- Coups de feu sans silencieux : alerte automatique (réglable).

## Pour le staff (tablette `/police_staff`)
Vue d'ensemble, métier et grades (créé dans elyzea_core), métiers considérés comme police, permissions par grade,
**tenues de service par grade** (enfilées à la prise de service, retirées à la fin ; enregistrées par admin_menu),
catalogue des amendes, armurerie, points, réglages, dossiers (détenus, avis, amendes impayées, rapports).
L'accès est donné dans le menu admin (permission `police_staff`).

## Exports (serveur)
```lua
exports.elyzea_police:SendDispatch({ coords = vector3(...), title = 'Braquage', message = '...', code = '10-90', priority = 3 })
exports.elyzea_police:IsPolice(source)      -- policier (en service ou non)
exports.elyzea_police:IsOnDuty(source)
exports.elyzea_police:GetCopsOnDuty()       -- liste des sources
exports.elyzea_police:IsCuffed(source)
```
L'état menotté est aussi dans `Player(source).state.cuffed`.

## Mise à jour : ALT, tablette, Patron

- **Interactions : ALT + clic.** En service, maintenir **ALT** : un curseur apparaît et la personne visée s'entoure.
  Clic gauche sur la personne : menu (menotter, escorter, véhicule, fouille, identité, amende, prison).
  Clic sur un véhicule : sortir les personnes menottées. La touche F7 n'est plus utilisée.
- **Tablette (F6)** : F6 ou Échap la referme. Si elle reste bloquée en main : `/police_debloquer`.
  Elle se range aussi toute seule si l'interface perd la main (autre menu, chute, mort).
- **Patron (F6 › Patron)** remplace le menu patron F11 pour la police :
  - **Argent** : solde du compte de l'entreprise, dépôt / retrait (liquide ou banque), dernières opérations ;
  - **Employés** : recruter, changer de grade, renvoyer ;
  - **Grades** : créer, renommer, salaire (max `settings.maxSalary`), accès de chaque grade (cases à cocher),
    supprimer un grade vide. On ne gère que les grades en dessous du sien et on ne donne que des accès qu'on a soi-même.
- Les accès par grade partent des niveaux de `permGrades` (tablette staff). Enregistrer les permissions dans la
  tablette staff remet les accès de tous les grades à partir de ces niveaux.
