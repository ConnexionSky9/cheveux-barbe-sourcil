# elyzea_police

Métier Police complet pour **Qbox** (oxmysql, ox_inventory conseillé), relié au menu admin (`admin_menu`)
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

**Menu d'interaction (F7)** : menotter / démenotter, escorter, mettre dans / sortir d'un véhicule, fouiller (ox_inventory),
vérifier l'identité, amende (catalogue + montant libre), prison.

**Points** : prise de service (E), armurerie (E, boutique ox_inventory filtrée par grade).

## Pour les citoyens
- `/112 <message>` : appeler la police (position envoyée).
- `/amendes` : voir et payer ses amendes impayées.
- Coups de feu sans silencieux : alerte automatique (réglable).

## Pour le staff (tablette `/police_staff`)
Vue d'ensemble, métier et grades (créé dans Qbox), métiers considérés comme police, permissions par grade,
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
