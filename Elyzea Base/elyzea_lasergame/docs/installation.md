# Installation — LaserGame ElyzeaFA

## 1. Ce qu'il faut
| Élément | Obligatoire | Remarque |
|---|---|---|
| Serveur FiveM avec **OneSync** | oui | Instances (routing buckets) : chaque partie a la sienne. Dans txAdmin : *OneSync = On*. |
| MySQL / MariaDB | oui | Celle de ton serveur. Les tables se créent toutes seules. |
| `elyzea_core` | oui (base Elyzea) | Identité RP, argent, accès MySQL. Pour ESX / QBCore, voir §5. |
| `elyzea_inventory` | conseillé | L'inventaire RP est verrouillé pendant une partie (rien n'est retiré ni ajouté). |
| `admin_menu` | conseillé | Permission staff « LaserGame », dessin des arènes en visant, décor avec l'éditeur de map, PNJ. Sans lui : ACE (§4) et outils « à ma position » de `/lgadmin`. |

Aucune autre ressource, aucun stream, aucun MLO : les arènes sont des lieux du monde GTA choisis par le staff, décorés avec des objets du jeu de base.

## 2. Installer
1. Copie le dossier **`elyzea_lasergame`** dans ton dossier `resources` (à côté des autres ressources Elyzea).
2. Remplace aussi **`admin_menu`** par la version de ce dépôt (onglet LaserGame › Arènes, outils de dessin, rôle de PNJ « LaserGame », permission staff).
3. Dans `server.cfg`, la ligne est déjà ajoutée (après `pvp_arena`) :
   ```cfg
   ensure elyzea_lasergame
   ```
4. Redémarre le serveur (ou `refresh` puis `ensure admin_menu` et `ensure elyzea_lasergame`).
5. La console affiche : `[LaserGame:admin] ressource démarrée (v2.0.0, framework elyzea, 0 arène(s))`.

Les 9 tables (`lg_players`, `lg_matches`, `lg_match_players`, `lg_ledger`, `lg_pending`, `lg_restore`, `lg_logs`, `lg_arenas`, `lg_settings`)
sont créées au démarrage. `sql/install.sql` contient les mêmes requêtes si tu préfères les importer toi-même.

## 3. Le PNJ d'accès
Un PNJ d'exemple est posé à Vespucci (`config.lua › Config.Npcs`). Pour le placer où tu veux, **trois méthodes** :
- **Éditeur de map** (conseillé) : admin_menu › Éditeur de map › PNJ › pose un PNJ › coche **🔫 LaserGame** › Enregistrer.
- **En jeu** : `/lgadmin` › onglet **PNJ** › « Poser ici » (à ta position et dans ton orientation). « Retirer » pour supprimer celui de l'exemple.
- **Fichier** : `config.lua › Config.Npcs` (modèle, position, animation, distance, texte, blip).

Les joueurs s'approchent et appuient sur **E**.

## 4. Donner l'accès staff
- **admin_menu** (c'est lui qui décide dès qu'il est démarré) : Staff › Rangs › coche **« LaserGame »** pour les rangs voulus.
  Le SuperAdmin la reçoit automatiquement au premier démarrage, même si tes rangs sont déjà enregistrés.
  Une ACE seule ne donne plus l'accès quand admin_menu tourne : tout se règle dans les rangs du menu.
- **Sans admin_menu** seulement : dans `permissions.cfg` → `add_ace group.admin elyzea_lasergame.admin allow`.

Puis en jeu : menu staff › Économie et services › **LaserGame** (arènes, parties en cours, arrêter une partie, « Panneau LaserGame complet »),
ou directement **`/lgadmin`**.

## 5. ESX ou QBCore (autres serveurs)
La ressource détecte seule le framework (`Config.Framework = 'auto'`). Adaptateurs fournis : `server/bridge.lua` (identité, argent)
et `client/main.lua` (armes rendues après la partie).
1. Dans `fxmanifest.lua`, remplace `'@elyzea_core/lib/MySQL.lua'` par `'@oxmysql/lib/MySQL.lua'`.
2. ESX : le compte « liquide » s'appelle `money` (géré automatiquement). Les armes du loadout sont rendues par `esx:restoreLoadout`.
3. QBCore / Qbox : les armes sont des objets d'inventaire, rien n'est retiré de l'inventaire.
4. Permissions : ACE `elyzea_lasergame.admin` (§4).

## 6. Les arènes : à créer en jeu
Au premier démarrage il n'y a **aucune arène** : les joueurs voient « Aucune arène ouverte ». Crée la première en suivant
[docs/administration.md › Créer une arène](administration.md) (5 minutes) :
**Créer ici** → **Dessiner la zone** → **Apparitions** des deux équipes → décor avec l'**Éditeur de map** → **Ouvrir aux joueurs**.

Chaque partie se joue dans sa propre instance : plusieurs parties peuvent utiliser la même arène en même temps,
et les joueurs RP autour ne voient jamais les joueurs de la partie.

**Mise à jour depuis la v1** : les 5 cartes générées et le mode Zombie n'existent plus. Les anciennes tables / colonnes Zombie
(`lg_zombie_runs`, colonnes `zb_*` de `lg_players`) restent en base sans être utilisées : tu peux les supprimer si tu veux.
Les annonces Zombie encore ouvertes dans l'appli du téléphone sont closes au démarrage.

## 7. Webhook Discord (facultatif)
Dans `secrets.cfg` (jamais publié) :
```cfg
set elyzea_lasergame_webhook "https://discord.com/api/webhooks/…"
```
Les journaux (staff, argent, PVP, sécurité, erreurs) y sont envoyés en plus de la table `lg_logs`.

## 8. Mise à jour
Remplace les fichiers. Les réglages faits en jeu (`/lgadmin`) sont en base (`lg_settings`) et sont conservés.

## 9. Appli « LaserGame » du téléphone (elyzea_aura)
1. Remplace `elyzea_aura` et `elyzea_lasergame` par les versions de ce dépôt (les deux sont nécessaires), puis redémarre.
2. En jeu : téléphone › **Appli** › LaserGame › Obtenir.
3. Profil (points, rang), Classement, Matchs (demandes PVP), Annonces (tournois programmés), Messages.
4. **Rejoindre** pose un point GPS sur le PNJ LaserGame le plus proche : aucun joueur n'est téléporté. Pour que le GPS
   fonctionne, au moins un PNJ LaserGame doit être placé (§3).
5. Réglages : `config.lua › Config.Phone` (limites, rappel avant l'heure, durée d'une demande « dès que possible »).
