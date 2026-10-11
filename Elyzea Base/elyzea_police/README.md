# elyzea_police — Métier Police (LSPD)

Dépendance unique : `elyzea_core`. Aucune autre ressource n'est nécessaire.

## Installation
1. Dossier `elyzea_police` dans `resources` (déjà fait dans `Elyzea Base`).
2. `server.cfg` : `ensure elyzea_police` **après** `elyzea_core` et `admin_menu` (déjà ajouté, sous `elyzea_illegal`).
3. Base de données : les tables sont créées **automatiquement** au démarrage. `sql/install.sql` contient les mêmes requêtes si tu préfères les lancer à la main.
4. Premier démarrage : les grades de `Config.DefaultGrades` sont créés (Cadet → Commissaire) et le métier `police` est déclaré dans le core.
5. Nommer le premier chef : menu admin (F10) › **Métier staff** › choisir le joueur › grade 👑 › *Recruter*.

Tables : `police_wanted`, `police_grades`, `police_employees`, `police_admin_log`, `police_reports`, `police_report_history`, `police_fines`, `police_alerts`.

## Touches et commandes
| Touche / commande | Action |
|---|---|
| **F6** | Menu rapide : service, statut, alerte agent (vert / orange / rouge), alertes en cours, tablette |
| **ALT** (maintenu, **tout le monde**) | Viser un joueur ou un véhicule. Tous : porter / poser une personne, ouvrir le coffre (objets), se cacher dans le coffre (E pour sortir), sortir quelqu'un du coffre. Police en service : menotter, escorter, mettre / sortir du véhicule, amende, **fourrière** |
| **G** / **I** | Valider / décliner l'alerte affichée |
| `/police [message]` | Citoyen : appeler la police (alerte « détresse » à sa position) |
| `/amendes` | Citoyen : voir et payer ses amendes |
| `/police_debloquer` | Débloque l'interface (focus souris) en cas de souci |

Toutes les touches se changent dans Échap › Paramètres › Raccourcis › FiveM.

## Fonctionnement
- **Service** : on est toujours hors service à la connexion. Hors service = pas d'alerte, pas d'interaction, invisible sur la carte.
- **Alerte agent** : envoyée avec la position calculée par le serveur à tous les policiers en service. L'alerte rouge demande une confirmation. Anti-spam : `Config.AgentAlerts.cooldown`. Fermeture par l'auteur ou un grade avec `alert_close`, synchronisée chez tout le monde.
- **Alertes générales** (`Config.Alerts.types`) : tirs et vol de véhicule détectés automatiquement, détresse via `/police`, braquage / agression / autre via les exports. *Valider* = GPS + « pris par X » visible des collègues (plusieurs agents peuvent rejoindre). *Décliner* = masquée pour soi seul.
- **Tablette** : tableau de bord, rapports (créer, chercher, filtrer, modifier, archiver, historique), carte (agents en service avec position, rue, vie, armure et état En vie / Blessé / À terre / Mort ; agents connectés hors service listés à part, sans position ; alertes ; rafraîchie toutes les 3 s), agents, et Direction : recrutement (joueur le plus proche → Accepter / Refuser), employés (fiche, promouvoir, rétrograder, changer de grade, modifier, renvoyer), grades (créer, modifier, supprimer avec réaffectation), permissions par grade, **Finance**, historique.
- **Recherche** (permission `search`) : chercher un citoyen par nom et/ou prénom (tous les personnages de la base, connectés ou non). Fiche : identité, téléphone, métier, permis, amendes (payées / dues), rapports où il apparaît, avis de recherche. Bouton « Déclarer recherché ».
- **Recherchés** (permissions `wanted_view` / `wanted_manage`) : avis de recherche avec nom, motif, signalement, dangerosité (faible / moyen / élevé) et photo facultative (lien). Lié à la fiche d'un citoyen ou nom libre (personne inconnue). Les agents en service sont prévenus à chaque nouvel avis. Lever un avis (avec raison) le garde dans l'historique (filtre « Avis levés »).
- **Fourrière** (permission `impound`, en service) : ALT sur un véhicule vide › « Mettre en fourrière » : l'agent se met à genoux (8 s, `Config.Impound.duration`, annulable), le véhicule disparaît puis l'agent se relève. Véhicule d'un joueur : il passe « À la fourrière » ; son propriétaire le récupère dans n'importe quel garage public en payant (`elyzea_garage/config.lua` › `Config.Impound`, 500 $ versés à la police). Véhicule sans propriétaire : simplement enlevé.
- **Porter** : sans demande d'accord. La personne est posée si le porteur s'éloigne, monte en voiture, meurt ou se déconnecte. Impossible sur une personne escortée par la police.
- **Finance** (permission `finance`, donnée au plus haut grade) : argent de l'entreprise (compte société `police` d'elyzea_core, alimenté par les amendes), mouvements récents, salaire **par heure de service** de chaque grade, liste des employés avec leur temps de service non payé et la somme due (temps × salaire horaire du grade actuel, calculé par le serveur). « Payer » verse la somme depuis l'argent de l'entreprise sur le compte en banque de l'employé (même hors ligne) et remet son temps à zéro. Refusé si l'entreprise n'a pas assez d'argent. Le temps de service est compté de la prise à la fin de service (et enregistré toutes les 30 s). Il n'y a plus de paie automatique du core pour la police.
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
Carte : image satellite `html/img/map.jpg`, calibrée dans `Config.MapImage` (sans image, une carte tactique dessinée est utilisée).

## Limites connues
- Non testé en jeu : le code est vérifié (syntaxe Lua / JS) et l'interface a été prévisualisée dans un navigateur, mais pas sur un serveur FiveM.
- Pièces jointes des rapports : liens d'images (URL), pas d'envoi de fichiers.
- Alertes automatiques : tirs et vols de véhicule seulement ; le reste passe par `/police` et les exports.
- Dans le menu ALT, les joueurs non policiers apparaissent comme « Personne · ID x » (pas de nom, pour le RP).
