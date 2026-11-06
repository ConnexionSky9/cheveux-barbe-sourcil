# elyzea_lasergame — LaserGame ElyzeaFA

Complexe LaserGame intégré au RP d'ElyzeaFA : **PVP ARENA** (1v1 à 6v6, mises, 8 rangs, spectateurs), armes **laser**,
**arènes créées en jeu par le staff** (autant qu'il en veut, là où il veut), classements, interface premium et administration
complète. Chaque partie se joue dans **sa propre instance** : le RP ne voit pas les joueurs, l'inventaire RP n'est jamais touché,
l'état RP est sauvegardé en base et restauré même après un crash.

| | |
|---|---|
| Installation | [docs/installation.md](docs/installation.md) |
| Configuration | [docs/configuration.md](docs/configuration.md) |
| Guide staff (créer une arène) | [docs/administration.md](docs/administration.md) |
| Architecture | [docs/architecture.md](docs/architecture.md) |
| Rapport de tests | [docs/tests.md](docs/tests.md) |
| Limitations / validation en jeu | [docs/limitations.md](docs/limitations.md) |
| État du projet | [PROJECT_STATUS.md](PROJECT_STATUS.md) |

## Démarrage rapide
1. Copier `elyzea_lasergame` (et les versions à jour d'`admin_menu` et d'`elyzea_aura`) dans `resources`. `ensure elyzea_lasergame` est déjà dans `server.cfg`.
2. Redémarrer : les tables se créent seules.
3. Staff : cocher la permission « LaserGame » dans admin_menu, puis **créer une arène** (docs/administration.md) :
   menu staff › LaserGame › Arènes › **Créer ici** → **Dessiner la zone** → **Apparitions** ROUGE et BLEUE →
   décor avec l'**Éditeur de map** → **Ouvrir aux joueurs**.
4. Poser le PNJ d'accueil (éditeur de map, rôle « 🔫 LaserGame », ou `/lgadmin` › PNJ › « Poser ici »).
5. Joueurs : aller voir le PNJ LaserGame, touche **E**.

## Contenu
- **Arènes** : créées à la position du staff, zone de combat dessinée en visant le sol (coins, sol, plafond), apparitions de chaque
  équipe posées une par une (la caméra donne la direction), heure et météo facultatives, nombre max. de joueurs par équipe.
  Le décor se fait avec l'éditeur de map d'admin_menu : ses objets sont visibles dans l'instance de la partie.
  Une arène incomplète n'est jamais proposée aux joueurs ; une partie en cours garde une copie figée de son arène.
  Plusieurs parties peuvent utiliser la même arène en même temps (chacune dans son instance).
- **PVP** : création (nom, format, arène, manches, durée, catégorie d'arme, mise, public / privé, mot de passe), matchmaking, invitations,
  lobby (équipes rouge / bleue, prêt, armes), équilibrage obligatoire, manches, HUD (scores, temps, vivants, coéquipiers), bouclier,
  mur invisible et paroi laser au bord de la zone, élimination → spectateur des coéquipiers, abandon, égalité, écran de victoire,
  paiement du pot, points et rangs.
- **Armes laser** : 13 armes en 5 catégories (mêlée, pistolet, mitraillette, fusil d'assaut, sniper), faisceaux aux couleurs des équipes,
  impacts lumineux, étincelles, sons ; tirs validés par le serveur (dégâts, portée, cadence, chargeur, trajectoire).
- **Rangs** : ELYZEA BRONZE, SILVER, GOLD, PLATINUM, DIAMOND, MASTER, GRANDMASTER, LEGEND, chacun avec son emblème (`html/ranks/`).
- **Classements** : points, ratio, victoires, rangs, séries ; pagination, actualisation automatique ; profil ; historique.
- **Staff** : parties (arrêt, expulsion), arènes, PVP, armes, PNJ, joueurs (points, rang, réinitialisation, exclusion),
  journaux (Discord facultatif). Dans `/lgadmin` et dans l'onglet LaserGame d'admin_menu.
- **Appli du téléphone** (elyzea_aura › « LaserGame ») : points, rang, classements, demandes de match PVP, annonces
  programmées avec bouton Rejoindre (point GPS vers le LaserGame, jamais de téléportation), messages entre joueurs.

Le mode Zombie et les cartes générées de la version 1 ont été retirés (version 2.0.0).

## Arborescence
```
elyzea_lasergame/
  fxmanifest.lua  config.lua  README.md  PROJECT_STATUS.md
  shared/   constants · config · utils · rpc
  server/   bridge · logs · security · database · players · settings · maps (arènes) · economy · restoration
            games · lobby · combat · ranking · pvp · admin · phone · main
  client/   main · interface · npc · maps (zone, mur invisible) · laser · weapons · restoration · pvp · spectator · admin
  html/     index.html · style.css · script.js · brand.css/js · ranks/ (8 emblèmes) · sounds/ · assets/
  sql/      install.sql
  docs/     installation · configuration · administration · architecture · tests · limitations
  tools/    assets/ (emblèmes, sons)
  tests/    simulation serveur · contrats · interface · syntaxe · run_all.sh
```
