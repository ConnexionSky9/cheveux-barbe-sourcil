# elyzea_ems — Métier EMS / SAMS

> **Important : rien de cette ressource n'a été testé en jeu.** Le code a été relu, sa syntaxe vérifiée (Lua et JavaScript)
> et l'interface affichée hors du jeu avec des données fictives. Les tests en jeu ci-dessous restent à faire.

Dépendance obligatoire : `elyzea_core` (joueurs, métiers, argent, compte société, clés).
Intégrations facultatives (détectées au démarrage, rien ne casse si elles manquent) :

| Ressource | Utilisée pour |
|---|---|
| `elyzea_police` | Menu **ALT** (il appartient à la police et sert à tout le monde) : les options EMS y sont ajoutées par les exports `AltOptions` / `AltSelect`. Sans elyzea_police, les mêmes actions restent dans **F6 › Actions médicales**. |
| `elyzea_papiers` | Remise des PPA (nouvel export `GivePpa`, même papier, même numéro, même licence que la remise après test). |
| `elyzea_inventory` | Pharmacie (coffre), matériel médical facultatif (`Config.Equipment`). |
| `admin_menu` | Journal staff, **Métier staff** (choix Police / EMS), lits de réapparition, réanimation staff. |

## Installation
1. Dossier `elyzea_ems` dans `resources` (déjà dans `Elyzea Base`).
2. `server.cfg` : `ensure elyzea_ems` (déjà ajouté, juste après `elyzea_police`).
3. Base de données : tables créées **automatiquement** au démarrage. `sql/install.sql` contient les mêmes requêtes.
   Si une ancienne table `ems_ppa` (ancien EMS, autre structure) existe, elle est **renommée** `ems_ppa_ancien` : rien n'est supprimé.
4. Premier démarrage : grades de `Config.DefaultGrades` créés (Stagiaire → Directeur ; un ancien grade « Direction » est renommé « Directeur »), métier `ambulance` déclaré dans le core
   (un grade du core par niveau, **salaire du core = 0** : la paie passe par la tablette › Finance).
5. Nommer la première direction : menu admin (F10) › **Métier staff** › onglet **EMS** › joueur › grade 👑 Directeur › *Recruter*.
6. Placer le garage : tablette › Direction › **Garage** › *Placer ici* (garage, place de sortie, pharmacie). Modèles de véhicules
   modifiables au même endroit (par défaut `ambulance` ; ajoutez les noms de modèles de vos packs, ex. gayaems, une fois installés).

## Touches et commandes
| Touche / commande | Action |
|---|---|
| **F6** | Menu rapide EMS : service (+ temps de session / non payé / total), statut, actions médicales sur la personne la plus proche, appels, soutien (vert / orange / rouge, confirmation pour le rouge), tablette, Direction (visible seulement avec la permission) |
| **ALT** (maintenu) | Viser un patient : examiner, soigner, stabiliser, réanimer, porter / accompagner, installer / sortir du véhicule, dossier, compte rendu, facture, PPA civil / FDO |
| **G** / **I** | Accepter / refuser l'appel affiché (ou GPS / masquer pour un soutien) |
| **X** | Annuler un acte en cours |
| `/ems <message>` | Tout le monde : appeler les secours |
| **Coma** : **G** | Signaler sa position aux secours |
| **Coma** : **E** maintenu | Réapparaître à l'hôpital, quand le délai est écoulé |
| `/ems_debloquer` | Rend le curseur si une fenêtre reste bloquée |

## Fonctionnement
- **Coma (tous les joueurs)** : à la mort, le joueur est relevé sur place, allongé et invincible (state bag `emsDown`, métadonnée `isdead`).
  Délai `Config.Death.bleedout` avant de pouvoir réapparaître, +`stabilizeBonus` si un EMS le stabilise. Appel EMS automatique.
  Déconnexion à terre = toujours à terre à la reconnexion. Réapparition : frais `respawnFee` (banque puis liquide, versés à la société),
  réveil au point `Config.Death.hospital` ; si des lits existent dans **admin_menu › Réapparition**, admin_menu détecte la réapparition
  et place le joueur sur un lit. La réanimation staff (admin_menu) termine aussi le coma.
- **Actes** (soins, stabilisation, réanimation) : vérifiés par le serveur en deux temps (début / fin), durée minimale imposée,
  distance revérifiée. Chaque acte est enregistré (`ems_treatments`) : il sert à la facture et au compte rendu.
- **Appels** : `pending → accepted → enroute → onsite → care → transport → done` (ou `cancelled`). Plusieurs EMS peuvent rejoindre un appel.
  Les soins font avancer le statut tout seuls (sans jamais reculer). Historique complet (`ems_call_log`). Appel non pris : annulé après `Config.Calls.lifetime`.
- **Soutien** : 3 niveaux, envoyé à tous les EMS en service, point GPS de la couleur du niveau ; la clôture (auteur ou permission) le retire chez tout le monde.
- **Temps de service et paie** : compté par le serveur. Chaque morceau de service est converti en argent dû **au taux du grade du moment** ;
  avant un changement de taux ou de grade, le temps en cours est compté à l'ancien taux → **jamais rétroactif** (historique `ems_rates`, sessions `ems_sessions`).
  Sauvegarde chaque minute + à chaque fin de service / déconnexion (un crash fait perdre au plus une minute).
- **Payer** (Finance) : confirmation → verrou par employé → recalcul serveur → débit du compte société (refusé si le solde manque) →
  crédit de la banque de l'employé (connecté ou hors ligne) → si le crédit échoue, la société est remboursée et rien ne change →
  sinon seul le temps payé est retiré, transaction `PAY-…` unique journalisée.
- **Facture** : montant recalculé par le serveur à partir des actes non facturés (mode par prestation / forfait / mixte, tarifs en base).
  Paiement immédiat (banque puis liquide). Un acte facturé reçoit le numéro de facture : il ne peut plus être facturé. Fonds insuffisants :
  facture « refusée », les actes restent à facturer. Remboursement / annulation par la direction, avec motif, tracés.
- **PPA** : deux catégories (civil / force de l'ordre), prix et activation en base, grades par permission. Récapitulatif → paiement immédiat →
  remise du papier (`elyzea_papiers:GivePpa`) → si la remise échoue, remboursement automatique. Un identifiant `PPA-…` relie délivrance, facture et transaction.

## Tablette
Tableau de bord · Dispatch · Patients (dossier médical, actes, factures, PPA, appels) · Comptes rendus (pré-remplis depuis un appel ou les actes récents) ·
Carte · Statistiques · **Direction** : Recrutement (personne la plus proche, Accepter / Refuser), Employés (temps total / non payé, sessions, historique,
promotion / rétrogradation / renvoi), Grades (création, nom, niveau, suppression avec réaffectation, pas de salaire), Permissions, Historique, Garage ·
**Finance** : Vue d'ensemble (solde réel, entrées / sorties, salaires, taux horaires + historique, recettes PPA), Factures, Tarifs des soins, PPA, Transactions.

Règles de hiérarchie (serveur) : on n'agit que sur un grade inférieur au sien, jamais sur soi ; on ne donne qu'un grade inférieur au sien
(la direction peut nommer jusqu'au grade juste sous elle ; le plus haut grade se donne par le staff) ; on ne donne que des permissions que l'on possède.

## Tables
`ems_settings`, `ems_grades`, `ems_employees`, `ems_admin_log`, `ems_sessions`, `ems_rates`, `ems_transactions`, `ems_calls`, `ems_call_log`,
`ems_support`, `ems_treatments`, `ems_invoices`, `ems_ppa`, `ems_patients`, `ems_reports`, `ems_report_history`.

## Exports
Serveur : `IsEms(src)`, `IsOnDuty(src)`, `HasPermission(src, perm)`, `GetOnDutyCount()`, `IsDown(src)`, `Revive(src, health)`,
`SendCall({ reason, coords, street, urgency, info })`, `GetActiveCalls()`, `AdminGrades/AdminSetGrade/AdminRemove/AdminInfo/AdminDuty` (admin_menu).
Client : `AltOptions(ctx)`, `AltSelect(id, ctx)` (menu ALT), `IsDown()`.

## Modifications faites dans d'autres ressources (dépendances vérifiées)
- `elyzea_police/client/alt.lua` : ajoute les options EMS au menu ALT quand elyzea_ems est démarré ; ALT bloqué pendant le coma.
  `elyzea_police/html/app.js` : icônes des actions EMS.
- `elyzea_papiers/server.lua` : la remise du PPA est sortie dans une fonction `Deliver` (même comportement pour la remise après test),
  nouveaux exports `GivePpa(src, target, kind)` et `HasPpa(target, kind)`. `PpaRequest`, `PpaIssue`, `PpaState` inchangés.
- `admin_menu` › Métier staff : choix **Police / EMS** (mêmes exports des deux côtés).

## Tests à faire en jeu (non faits)
1. Démarrage : console « [EMS] Prêt », tables créées, métier `ambulance` visible dans le core.
2. Mort d'un joueur : coma, écran, appel automatique reçu par un EMS en service, G (signal), E après le délai, frais prélevés, réveil à l'hôpital / sur un lit.
3. Déconnexion pendant le coma puis reconnexion : toujours à terre.
4. ALT sur un patient : examen, soins, stabilisation (délai allongé), réanimation (animation, patient relevé), port, installation dans l'ambulance, sortie.
5. Facture : aperçu, ajout d'une prestation, paiement banque puis liquide, refus si pas d'argent, actes non refacturables, remboursement par la direction.
6. PPA : récapitulatif, paiement, papier reçu, licence `weapon` (+ `weapon_fdo`), refus pour un non-policier en FDO, doublon refusé, inventaire plein → remboursement.
7. Service : prise / fin, sessions dans la fiche, temps qui continue après un redémarrage du serveur, changement de taux puis paie (ancien temps à l'ancien taux).
8. Paie : solde insuffisant (refus), employé hors ligne (banque créditée), double clic (un seul paiement), « Payer tout le monde ».
9. Direction : recrutement (accepter / refuser / expiration), promotion jusqu'au grade sous le sien, rétrogradation, renvoi avec salaire dû (demande de confirmation), grades, permissions.
10. Garage : placer les points, sortir un véhicule (clés), le ranger, pharmacie.
11. Appels : /ems, statuts, plusieurs EMS sur un appel, annulation, historique ; soutien vert / orange / rouge et clôture chez tous.

## Limites connues
- **Aucun test en jeu** : des ajustements (positions d'animation, sièges de l'ambulance, réglages de délais) seront probablement nécessaires.
- Le coma relève le joueur sur place (`NetworkResurrectLocalPlayer`) : un autre script de mort actif en même temps entrerait en conflit (il n'y en a pas dans le dépôt actuellement).
- Les véhicules des packs gayaems / thunder_medicalcenter ne sont pas dans le dépôt : ajoutez leurs noms de modèles dans Direction › Garage une fois installés.
- Le compte société et le journal `elyzea_society_logs` sont ceux d'elyzea_core ; les transactions EMS détaillées sont dans `ems_transactions`.
- Une session de service compte au plus une minute de moins en cas de crash du serveur.
- `Config.Equipment` (matériel requis) est désactivé par défaut.

## Laboratoire : analyse sanguine « Alcool et substances »

Résultats **simulés pour le jeu de rôle** (pas des mesures médicales réelles), calculés uniquement à partir des
consommations enregistrées par le serveur. Aucun hasard, aucun positif sans consommation enregistrée.

1. **Prélèvement** : ALT sur le patient › « Prélèvement sanguin » (permission `lab_sample`, en service, 3 m max).
2. **Analyse** : tablette › 🧪 Laboratoire › le prélèvement › « Lancer l'analyse » (permission `lab_analyze`, en service).
   Le serveur calcule le résultat avec les consommations faites **avant** le prélèvement, puis le fige dans le rapport.
3. **Rapport** (permission `lab_view`) : patient, préleveur, médecin responsable, dates, alcoolémie (présence, taux g/L,
   niveau nul / faible / modéré / élevé, consommation récente), dépistage par substance (vert négatif, rouge positif,
   gris indéterminé), historique de l'analyse et analyses précédentes du patient.

**D'où viennent les données** (`Config.Lab` dans config.lua) :
- objets consommés dans l'inventaire (`elyzea_inventory:usedItem`) : grammes d'alcool par boisson (`alcohol.items`),
  objets par substance (`substances[].items`) ;
- autres scripts serveur : `exports.elyzea_ems:RecordConsumption(source, 'cocaine' [, quantité])`
  (alcool : `'alcohol'` et la quantité en grammes, 10 g ≈ un verre).

**Indéterminé** quand on ne peut pas savoir : suivi démarré trop récemment pour couvrir la durée de détection,
ou substance reliée à aucune source de données. Durées de détection et seuils réglables par substance.

Permissions données une fois aux grades existants : Directeur / direction / `reports_manage` → les trois,
`records_write` → prélèvement et consultation. Tables : `ems_lab_consumptions`, `ems_lab_samples`, `ems_lab_meta` (créées toutes seules).
Tests hors jeu : `python3 tests/run_lab_sim.py`.
