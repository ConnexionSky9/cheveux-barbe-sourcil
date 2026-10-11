# elyzea_police — Métier Police (LSPD)

Dépendance unique : `elyzea_core`. Aucune autre ressource n'est nécessaire.

## Installation
1. Dossier `elyzea_police` dans `resources` (déjà fait dans `Elyzea Base`).
2. `server.cfg` : `ensure elyzea_police` **après** `elyzea_core` et `admin_menu` (déjà ajouté, sous `elyzea_illegal`).
3. Base de données : les tables sont créées **automatiquement** au démarrage. `sql/install.sql` contient les mêmes requêtes si tu préfères les lancer à la main.
4. Premier démarrage : les grades de `Config.DefaultGrades` sont créés (Cadet → Commissaire) et le métier `police` est déclaré dans le core.
5. Nommer le premier chef : menu admin (F10) › **Métier staff** › choisir le joueur › grade 👑 › *Recruter*.

Tables : `police_grades`, `police_employees`, `police_admin_log`, `police_reports`, `police_report_history`, `police_fines`, `police_alerts`.

## Touches et commandes
| Touche / commande | Action |
|---|---|
| **F6** | Menu rapide : service, statut, alerte agent (vert / orange / rouge), alertes en cours, tablette |
| **ALT** (maintenu) | Viser un joueur ou un véhicule : menotter, escorter, mettre / sortir du véhicule, amende |
| **G** / **I** | Valider / décliner l'alerte affichée |
| `/police [message]` | Citoyen : appeler la police (alerte « détresse » à sa position) |
| `/amendes` | Citoyen : voir et payer ses amendes |
| `/police_debloquer` | Débloque l'interface (focus souris) en cas de souci |

Toutes les touches se changent dans Échap › Paramètres › Raccourcis › FiveM.

## Fonctionnement
- **Service** : on est toujours hors service à la connexion. Hors service = pas d'alerte, pas d'interaction, invisible sur la carte.
- **Alerte agent** : envoyée avec la position calculée par le serveur à tous les policiers en service. L'alerte rouge demande une confirmation. Anti-spam : `Config.AgentAlerts.cooldown`. Fermeture par l'auteur ou un grade avec `alert_close`, synchronisée chez tout le monde.
- **Alertes générales** (`Config.Alerts.types`) : tirs et vol de véhicule détectés automatiquement, détresse via `/police`, braquage / agression / autre via les exports. *Valider* = GPS + « pris par X » visible des collègues (plusieurs agents peuvent rejoindre). *Décliner* = masquée pour soi seul.
- **Tablette** : tableau de bord, rapports (créer, chercher, filtrer, modifier, archiver, historique), carte (agents + alertes, rafraîchie toutes les 3 s), agents, et Direction : recrutement (joueur le plus proche → Accepter / Refuser), employés (fiche, promouvoir, rétrograder, changer de grade, modifier, renvoyer), grades (créer, modifier, supprimer avec réaffectation), permissions par grade, historique.
- **Sécurité** : chaque action passe par le serveur (permission du grade, service, distance, hiérarchie : impossible d'agir sur soi ou sur un grade égal ou supérieur, ni de donner une permission qu'on n'a pas). Limite de 12 requêtes / seconde.
- **Déconnexion** : l'agent sort du service, ses menottes / escortes sont libérées, les alertes qu'il a prises sont mises à jour. Contrôle de sécurité toutes les 30 s (pas d'agent fantôme).

## Pour les autres scripts (exports serveur)
```lua
exports.elyzea_police:IsPolice(src)              -- true / false
exports.elyzea_police:IsOnDuty(src)
exports.elyzea_police:HasPermission(src, 'fine')
exports.elyzea_police:GetOnDutyCount()
exports.elyzea_police:SendAlert('robbery', vector3(x, y, z), 'Braquage', 'Supérette', 'Grove Street')
exports.elyzea_police:SendDispatch({ ... })      -- compatibilité elyzea_illegal
```

## Configuration utile (`config.lua`)
Touches, distances, préfixe de matricule, montant max et liste des amendes, niveaux d'alerte agent, types d'alertes générales, statuts, types de rapports, grades par défaut.
Carte : par défaut une carte tactique dessinée. Pour une vraie carte, mets une image dans `html/img/map.jpg` et règle ses bornes dans `Config.MapImage`.

## Limites connues
- Non testé en jeu : le code est vérifié (syntaxe Lua / JS) et l'interface a été prévisualisée dans un navigateur, mais pas sur un serveur FiveM.
- La carte tactique est schématique (pas d'image GTA fournie).
- Pièces jointes des rapports : liens d'images (URL), pas d'envoi de fichiers.
- Alertes automatiques : tirs et vols de véhicule seulement ; le reste passe par `/police` et les exports.
- Dans le menu ALT, les joueurs non policiers apparaissent comme « Personne · ID x » (pas de nom, pour le RP).
