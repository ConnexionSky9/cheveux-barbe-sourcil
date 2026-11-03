# Installation — LaserGame ElyzeaFA

## 1. Ce qu'il faut
| Élément | Obligatoire | Remarque |
|---|---|---|
| Serveur FiveM avec **OneSync** | oui | Instances (routing buckets) et zombies créés par le serveur. Dans txAdmin : *OneSync = On*. |
| MySQL / MariaDB | oui | Celle de ton serveur. Les tables se créent toutes seules. |
| `elyzea_core` | oui (base Elyzea) | Identité RP, argent, accès MySQL. Pour ESX / QBCore, voir §5. |
| `elyzea_inventory` | conseillé | L'inventaire RP est verrouillé pendant une partie (rien n'est retiré ni ajouté). |
| `admin_menu` | conseillé | Permission staff « LaserGame » et PNJ posés avec l'éditeur de map. Sans lui : ACE (§4). |

Aucune autre ressource, aucun stream, aucun MLO : les cartes utilisent uniquement des objets du jeu de base.

## 2. Installer
1. Copie le dossier **`elyzea_lasergame`** dans ton dossier `resources` (à côté des autres ressources Elyzea).
2. Remplace aussi **`admin_menu`** par la version de ce dépôt (ajout du rôle de PNJ « LaserGame » et de la permission staff).
3. Dans `server.cfg`, la ligne est déjà ajoutée (après `pvp_arena`) :
   ```cfg
   ensure elyzea_lasergame
   ```
4. Redémarre le serveur (ou `refresh` puis `ensure admin_menu` et `ensure elyzea_lasergame`).
5. La console affiche : `[LaserGame:admin] ressource démarrée (v1.0.0, framework elyzea, 5 carte(s))`.

Les 9 tables (`lg_players`, `lg_matches`, `lg_match_players`, `lg_zombie_runs`, `lg_ledger`, `lg_pending`, `lg_restore`, `lg_logs`, `lg_settings`)
sont créées au démarrage. `sql/install.sql` contient les mêmes requêtes si tu préfères les importer toi-même.

## 3. Le PNJ d'accès
Un PNJ d'exemple est posé à Vespucci (`config.lua › Config.Npcs`). Pour le placer où tu veux, **trois méthodes** :
- **Éditeur de map** (conseillé) : admin_menu › Éditeur de map › PNJ › pose un PNJ › coche **🔫 LaserGame** › Enregistrer.
- **En jeu** : `/lgadmin` › onglet **PNJ** › « Poser ici » (à ta position et dans ton orientation). « Retirer » pour supprimer celui de l'exemple.
- **Fichier** : `config.lua › Config.Npcs` (modèle, position, animation, distance, texte, blip).

Les joueurs s'approchent et appuient sur **E**.

## 4. Donner l'accès staff
- **admin_menu** : Staff › Rangs › coche **« LaserGame : /lgadmin … »** pour les rangs voulus (déjà inclus dans le rang SuperAdmin par défaut,
  mais si tes rangs sont déjà enregistrés, coche-la à la main).
- **Sans admin_menu** : dans `permissions.cfg` → `add_ace group.admin elyzea_lasergame.admin allow`.

Puis en jeu : **`/lgadmin`**.

## 5. ESX ou QBCore (autres serveurs)
La ressource détecte seule le framework (`Config.Framework = 'auto'`). Adaptateurs fournis : `server/bridge.lua` (identité, argent)
et `client/main.lua` (armes rendues après la partie).
1. Dans `fxmanifest.lua`, remplace `'@elyzea_core/lib/MySQL.lua'` par `'@oxmysql/lib/MySQL.lua'`.
2. ESX : le compte « liquide » s'appelle `money` (géré automatiquement). Les armes du loadout sont rendues par `esx:restoreLoadout`.
3. QBCore / Qbox : les armes sont des objets d'inventaire, rien n'est retiré de l'inventaire.
4. Permissions : ACE `elyzea_lasergame.admin` (§4).

## 6. Placer les cartes (à faire une fois, 2 minutes)
Les cartes sont construites à des emplacements par défaut (tarmac de l'aéroport pour les arènes PVP, aérodrome de Sandy Shores pour le Zombie).
Comme personne ne les a encore vues en jeu, **vérifie-les une fois** :
1. `/lgadmin` › **Cartes** › « Aperçu en jeu » : la carte apparaît autour de son emplacement, **pour toi seul**, pendant 3 minutes
   (contour violet = limites, flèches = apparitions).
2. Si l'endroit ne convient pas (relief, bâtiment), va sur une zone plate et dégagée, oriente-toi, puis **« Placer ici »**.
   La carte entière suit ta position et ton orientation.
3. Si la console F8 indique « modèle(s) absent(s) », note-les : ces objets sont ignorés (ta version du jeu ne les a pas).

Chaque partie se joue dans sa propre instance : plusieurs parties peuvent utiliser la même carte en même temps,
et les joueurs RP autour ne voient jamais l'arène.

## 7. Webhook Discord (facultatif)
Dans `secrets.cfg` (jamais publié) :
```cfg
set elyzea_lasergame_webhook "https://discord.com/api/webhooks/…"
```
Les journaux (staff, argent, PVP, Zombie, sécurité, erreurs) y sont envoyés en plus de la table `lg_logs`.

## 8. Mise à jour
Remplace les fichiers. Les réglages faits en jeu (`/lgadmin`) sont en base (`lg_settings`) et sont conservés.
