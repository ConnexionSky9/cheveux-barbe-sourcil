# pvp_arena : arène PvP compétitive

Parties en équipes (1 contre 1 à 5 contre 5) lancées depuis un PNJ. Le mode comprend un lobby, des mises de participation, des paris, des manches avec choix de l'arme et une instance isolée. À la fin, chacun revient au RP exactement comme avant.

Le serveur est la seule autorité : équipes, armes, dégâts, éliminations, scores, argent.

## 1. Installation
1. Copie le dossier `pvp_arena` dans tes ressources.
2. Dans `server.cfg`, ajoute `ensure pvp_arena` après `elyzea_casino`. C'est déjà fait dans le `server.cfg` du dépôt.
3. Les dépendances sont `elyzea_core`, `elyzea_inventory` et `admin_menu`. Les tables SQL sont créées toutes seules : `pvp_ledger`, `pvp_pending`, `pvp_restore` et `pvp_matches`.
4. Remplace aussi les ressources modifiées : `admin_menu`, `elyzea_ems`, `elyzea_inventory` (voir la section « Intégrations »).
5. Redémarre le serveur, ou fais `refresh` puis `ensure` sur `admin_menu`, `elyzea_ems`, `elyzea_inventory` et `pvp_arena`.

> ⚠️ Les arènes posées en jeu sont enregistrées dans `pvp_arena/data/arenas.json`. **Garde ce fichier** quand tu mets la ressource à jour.

## 2. Le PNJ
**Méthode conseillée (éditeur de map)**
1. Ouvre admin_menu › Éditeur de map › PNJ.
2. Pose un PNJ et active le rôle **⚔️ Arène PvP**. Tu peux changer son nom affiché.
3. Enregistre. Le PNJ est statique et invulnérable, et il est géré par l'éditeur : il n'y a pas de doublon après un redémarrage.

Les joueurs s'approchent et appuient sur **E**. On peut aussi dupliquer le PNJ avec « ⧉ Dupliquer ».

**Méthode de secours (sans l'éditeur)**
1. Dans `config.lua`, mets `Config.Npc.enabled = true`.
2. Renseigne `Config.Npc.coords` (x, y, z, cap), `model` et `scenario`.

## 3. Les arènes
Les coordonnées présentes dans `config.lua` sont des **exemples à remplacer**. Le plus simple est de configurer en jeu, avec la permission `pvp_manage` :

| Commande | Effet |
|---|---|
| `/pvp_arena_new docks Docks du port` | crée l'arène `docks`, à l'endroit où tu te trouves |
| `/pvp_arena_add docks A` | ajoute un point d'apparition de l'équipe A (ta position et ton orientation) ; refais-le pour chaque joueur |
| `/pvp_arena_add docks B` | pareil pour l'équipe B |
| `/pvp_arena_add docks corner` | ajoute un coin de la zone de combat (au moins 3, dans l'ordre du contour) |
| `/pvp_arena_add docks safe` | point sûr où renvoyer un joueur sorti de la zone (facultatif) |
| `/pvp_arena_height docks 25 60` | hauteur autorisée (z minimum, z maximum) |
| `/pvp_arena_reset docks A` / `B` / `corner` / `safe` | efface ces points |
| `/pvp_arena_show docks` | affiche la zone, les points d'apparition et les points sûrs pendant 60 s |
| `/pvp_arena_tp docks B 2` | te téléporte sur le point B n°2 pour le tester |
| `/pvp_arenas` | liste les arènes et ce qui leur manque |
| `/pvp_arena_delete docks` | supprime l'arène |

- Une arène est utilisable dès qu'elle a au moins 1 point A, 1 point B et 3 coins.
- Mets autant de points d'apparition que de joueurs par équipe. Sinon, les joueurs sont décalés autour des points existants.
- La première arène créée en jeu remplace les exemples de la config.
- Tu peux aussi écrire les arènes directement dans `Config.Arenas`. Ce sont des tableaux `spawns`, `zone.points`, `zone.minZ` / `maxZ` et `safe`.
- `time` et `weather` forcent l'heure et la météo pour les joueurs de l'arène.

## 4. Armes
Les armes se règlent dans `Config.WeaponCategories` (pistolets, mitraillettes, fusils d'assaut).
- Chaque arme a un `name` (le nom GTA), un `label` et des `stats` de 0 à 100, affichées dans l'interface.
- Pour ajouter une arme, ajoute une ligne dans la bonne catégorie.
- `Config.DefaultWeapon` est l'arme donnée si un joueur ne choisit pas à temps.
- `Config.Ammo`, `Config.Health` et `Config.Armor` règlent les munitions, la vie et le gilet de chaque manche.

**L'arme est prêtée, comme pour l'essai au stand de tir de l'armurerie :**
- elle ne vient jamais de l'inventaire RP et n'y entre jamais ;
- les munitions sont illimitées seulement pour cette arme et seulement dans l'arène, et le chargeur se recharge normalement ;
- tout est retiré à la sortie.

## 5. Manches, formats, délais
- `Config.Modes` : formats proposés à l'hôte (1v1, 2v2, 3v3, 5v5).
- `Config.WinsOptions` : nombre de manches à gagner (première équipe à N).
- `Config.RoundTimes` : durées de manche proposées à l'hôte.
- `Config.Timers` : choix de l'arme, chargement, décompte de 3 s, fin de manche, écran de fin, tolérance après téléportation.
- `Config.TimeoutRule` : règle quand le temps est écoulé.
  - `most_alive` : gagne l'équipe qui a le plus de joueurs vivants, puis le plus de vie restante, sinon la manche est nulle.
  - `draw` : la manche est nulle.
- Si les deux équipes meurent presque en même temps, la manche est nulle.
- `Config.MaxRounds` : sécurité contre les parties sans fin.
- `Config.RequireFullTeams` : avec `true`, les équipes doivent être complètes pour lancer.

## 6. Argent : mises et paris (deux mécanismes séparés)
L'argent vient du compte `Config.Account` (`bank` par défaut). Le serveur vérifie toujours le solde réel, débite lui-même, et écrit chaque somme dans `pvp_ledger`. La somme reste dans le **pot logique** de la partie jusqu'à son règlement. Une ligne passe de « en jeu » à « payée / perdue / remboursée » **une seule fois** : rejouer un paiement ne verse jamais deux fois.

**Mise de participation**
- L'hôte fixe le montant, identique pour tous, entre `Config.Stake.min` et `Config.Stake.max`.
- Chaque joueur la paie avant de pouvoir se mettre « prêt ».
- Si l'hôte change le montant, les mises déjà payées sont rendues.
- À la fin, le pot (moins `Config.HouseFeePct.stake` %) est **partagé à parts égales** entre les joueurs de l'équipe gagnante. Les quelques dollars restants de la division vont aux premiers joueurs de la liste.
- Quitter le lobby avant le lancement : la mise est rendue.
- Quitter une partie en cours ou se déconnecter : la mise reste dans le pot. Avec `Config.LeaverForfeitsShare = true`, le joueur parti ne touche aucune part.

**Paris** (joueurs et spectateurs, avant le lancement seulement)
- Un pari par personne et par partie, sur une équipe, entre `Config.Bet.min` et `Config.Bet.max`. Il peut être annulé et remboursé tant que la partie n'est pas lancée.
- Le calcul est un pari mutuel : le pot de tous les paris, moins `Config.HouseFeePct.bet` %, est réparti entre les paris gagnants **au prorata** de leur montant.
- Si personne n'a parié sur l'équipe gagnante, tous les paris sont remboursés.
- `Config.ParticipantBets` : `own` (un participant ne parie que sur sa propre équipe, par défaut), `none` ou `any`.

**Annulation, erreur, redémarrage :** tout ce qui est encore en jeu est remboursé. Cela couvre une annulation par le staff, une égalité impossible à départager et un redémarrage du serveur ou de la ressource.

**Abandon d'une équipe entière** (`Config.AbandonPolicy`) :
- `forfeit` (par défaut) : l'autre équipe gagne et les mises restent jouées. Personne ne peut se faire rembourser en se déconnectant.
- `cancel` : la partie est annulée et tout est remboursé.

Un gagnant déconnecté au moment du paiement est crédité à sa prochaine connexion (table `pvp_pending`).

## 7. Instances, zone, sécurité
- **Instance :** chaque partie a son propre routing bucket (`Config.BucketBase` + n°), sans population et avec un verrouillage strict des entités. Seuls les participants y sont, et deux parties n'utilisent jamais le même bucket.
- **Dégâts :**
  - Le serveur bloque les dégâts hors manche, entre coéquipiers (sauf si l'hôte active les dégâts alliés), par un joueur éliminé, et avec une arme différente de celle qu'il a attribuée (journalisé).
  - Les dégâts valides désignent le tueur.
- **Morts :** la victime signale sa mort. Le serveur constate aussi lui-même une vie à 0. Une mort n'est comptée qu'une fois.
- **Zone :** le serveur contrôle les positions toutes les 0,5 s, avec un vrai polygone et la hauteur. Un joueur sorti de la zone est replacé sur un point sûr ou d'apparition. Au-delà de `Config.Zone.maxExitsPerRound` sorties, il est éliminé de la manche.
- **Requêtes :** une action à la fois par joueur, au plus 8 par seconde (doubles clics, requêtes simultanées). Les identifiants de partie et de transaction sont uniques.

## 8. Retour au RP
- Avant l'entrée, le serveur sauvegarde l'instance, la position, l'orientation, la vie et le gilet, en mémoire et dans la table `pvp_restore`.
- À la sortie (fin, abandon, annulation ou sortie forcée), le joueur est remis dans son instance et à sa position, avec sa vie et son gilet. Arme prêtée, munitions illimitées et état d'arène sont retirés.
- **L'inventaire RP n'est jamais vidé ni modifié.** L'arme d'inventaire éventuellement en main est simplement rangée à l'entrée. Le joueur garde donc tout ce qu'il possédait légitimement.
- Après une déconnexion en partie, le joueur est renvoyé à sa position RP dès sa reconnexion.
- Après un redémarrage, les joueurs connectés sont renvoyés immédiatement.

## 9. Intégrations (petites modifications d'autres ressources)
- **admin_menu :**
  - rôle de PNJ « ⚔️ Arène PvP » ;
  - permission `pvp_manage`, donnée au SuperAdmin ;
  - le respawn d'admin_menu ignore les morts dans l'arène (pas de lit d'hôpital) ;
  - bouton « ⧉ Dupliquer » pour les PNJ.
- **elyzea_ems :** une élimination dans l'arène ne déclenche pas le coma RP.
- **elyzea_inventory :** l'inventaire, les coffres et l'utilisation d'objets sont bloqués côté serveur pendant une partie.
- Ces trois règles s'appuient sur l'état `pvpArena` du joueur, posé et retiré par pvp_arena. L'état est retiré 4 s après le retour au RP.

## 10. Administration
Toutes ces commandes demandent la permission `pvp_manage` ou la console serveur.
- `/pvp_list` : parties en cours.
- `/pvp_info <partie | id joueur>` : détails.
- `/pvp_cancel <partie | id joueur>` : annule, rembourse et renvoie les joueurs au RP.
- `/pvp_kick <id>` : sort un joueur de l'arène, même s'il est bloqué.
- `/pvp_stats [n]` : dernières parties.
- Commandes d'arène : voir la section 3.

## 11. Design
- `html/style.css` : couleurs dans `:root`.
- `Config.UI.accent` / `accent2` : couleurs principales.
- `Config.Teams` : noms et couleurs des équipes.
- `html/lang.js` : tous les textes de l'interface, à traduire ou changer ici.
- `locales/fr.lua` : textes du serveur.
- Pas de flou d'arrière-plan : FiveM le dessine en carré noir.

## 12. Diagnostic
- **« Arène invalide »** : `/pvp_arenas` indique ce qui manque (points A / B, coins).
- **Un joueur bloqué dans l'arène :** `/pvp_kick <id>`.
- **Une partie bloquée :** `/pvp_cancel <partie>`, qui rembourse tout.
- **Argent :** chaque mise et chaque pari se trouve dans la table `pvp_ledger`, avec son statut et le montant versé.
- **Console serveur :** les lignes `[pvp_arena]` journalisent la création, le lancement, la fin, les annulations, les dégâts refusés et les sorties forcées.

## 13. Tests
`python3 tests/run_pvp_sim.py` (il faut `pip install lupa`). Cette commande fait tourner **le vrai code serveur**, avec une base de données, l'argent et les natives simulés et une horloge virtuelle. Elle couvre :
- lobby ;
- réglages réservés à l'hôte ;
- mises et double paiement ;
- solde insuffisant ;
- paris et verrou anti double clic ;
- lancement refusé ou accepté ;
- instance dédiée ;
- choix d'arme et arme par défaut ;
- décompte ;
- dégâts entre coéquipiers, arme non attribuée et joueur extérieur ;
- élimination et mort comptée une fois ;
- sortie de zone ;
- morts simultanées ;
- victoire finale et répartition exacte des gains ;
- règlement rejoué sans double paiement ;
- fin, retour au RP et suppression de la sauvegarde temporaire ;
- transfert d'hôte ;
- déconnexion en partie (forfait, retour à la reconnexion) ;
- annulation par le staff et remboursement ;
- deux parties en même temps ;
- redémarrage de la ressource ;
- règles de répartition.

**Non testable hors jeu :** tout ce qui se passe côté client.
- Animations, téléportations visuelles, caméra spectateur, interface dans FiveM.
- Retrait effectif des armes et des munitions illimitées.
- Focus de l'interface.

L'interface a été vérifiée seulement dans un navigateur, avec des données d'exemple.
