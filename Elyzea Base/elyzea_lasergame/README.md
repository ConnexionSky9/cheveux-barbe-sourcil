# elyzea_lasergame — LaserGame ElyzeaFA

Complexe LaserGame intégré au RP d'ElyzeaFA : **PVP ARENA** (1v1 à 6v6, mises, 8 rangs, spectateurs) et **MODE ZOMBIE**
(1 à 4 joueurs, 8 secteurs, portes, armes murales, atouts, réanimation), armes **laser**, **5 cartes** construites avec des objets
GTA V, classements, interface premium et administration complète. Le RP est totalement isolé : instance dédiée, inventaire RP jamais
touché, état RP sauvegardé en base et restauré même après un crash.

| | |
|---|---|
| Installation | [docs/installation.md](docs/installation.md) |
| Configuration | [docs/configuration.md](docs/configuration.md) |
| Guide staff | [docs/administration.md](docs/administration.md) |
| Architecture | [docs/architecture.md](docs/architecture.md) |
| Rapport de tests | [docs/tests.md](docs/tests.md) |
| Limitations / validation en jeu | [docs/limitations.md](docs/limitations.md) |
| État du projet | [PROJECT_STATUS.md](PROJECT_STATUS.md) |

## Démarrage rapide
1. Copier `elyzea_lasergame` (et la version à jour d'`admin_menu`) dans `resources`. `ensure elyzea_lasergame` est déjà dans `server.cfg`.
2. Redémarrer : les tables se créent seules.
3. Staff : cocher la permission « LaserGame » dans admin_menu, puis `/lgadmin` › **Cartes** › « Aperçu » pour vérifier les cartes
   (« Placer ici » pour les déplacer) et › **PNJ** › « Poser ici » pour le PNJ d'accueil.
4. Joueurs : aller voir le PNJ LaserGame, touche **E**.

## Contenu
- **PVP** : création (nom, format, carte, manches, durée, catégorie d'arme, mise, public / privé, mot de passe), matchmaking, invitations,
  lobby (équipes rouge / bleue, prêt, armes), équilibrage obligatoire, manches, HUD (scores, temps, vivants, coéquipiers), bouclier,
  élimination → spectateur des coéquipiers, abandon, égalité, écran de victoire, paiement du pot, points et rangs.
- **Armes laser** : 15 armes en 5 catégories (mêlée, pistolet, mitraillette, fusil d'assaut, sniper), faisceaux aux couleurs des équipes,
  impacts lumineux, étincelles, sons ; tirs validés par le serveur (dégâts, portée, cadence, chargeur, trajectoire).
- **Zombie** : 5 types (classique, rapide, résistant, spécial, cracheur d'acide), difficulté progressive, argent Zombie séparé du RP,
  9 portes payantes, 13 armes murales, 8 atouts (Mastodonte, Rapidité, Rechargement rapide, Double dégâts, Résistance acide,
  Réanimation rapide, Régénération, Protection), mise à terre, réanimation, mort et retour à la manche suivante.
- **Cartes** : 5 **complexes souterrains** construits 45 m sous le désert de Grand Senora, chacun à son emplacement :
  ELYSIUM COMBAT (S), NEON DISTRICT (M), BLACKSITE (L), LAST STAND (XL), COMPLEXE ELYZEA-7 (Zombie).
  - Chaque complexe a une dalle de sol, un plafond, des murs jusqu'au plafond, des piliers porteurs et un éclairage sur toute la surface.
  - Aucun élément du décor GTA ne peut gêner, et personne en RP ne les voit.
  - Validées automatiquement : accessibilité, apparitions protégées, équilibre, aucune fente où se coincer, secteurs étanches, rien à travers le plafond.
- **Rangs** : ELYZEA BRONZE, SILVER, GOLD, PLATINUM, DIAMOND, MASTER, GRANDMASTER, LEGEND, chacun avec son emblème (`html/ranks/`).
- **Classements** : PVP (points, ratio, victoires, rangs, séries), Zombie (manches, zombies tués, solo, équipes, performances),
  pagination, actualisation automatique ; profil ; historique.
- **Staff** : parties (arrêt, expulsion), PVP, armes, Zombie, prix, cartes (déplacement, aperçu), PNJ, joueurs (points, rang,
  réinitialisation, exclusion), journaux (Discord facultatif).

## Arborescence
```
elyzea_lasergame/
  fxmanifest.lua  config.lua  README.md  PROJECT_STATUS.md
  shared/   constants · config · utils · rpc
  server/   bridge · logs · security · database · players · settings · maps · economy · restoration
            games · lobby · combat · ranking · pvp · zombie · admin · main
  client/   main · interface · npc · maps · laser · weapons · restoration · pvp · spectator · zombie · doors · perks · admin
  html/     index.html · style.css · script.js · brand.css/js · ranks/ (8 emblèmes) · sounds/ (41 sons) · images/maps/ · assets/
  maps/     pvp_small · pvp_medium · pvp_large · pvp_xlarge · zombie_map  (map.json, preview.png, .ymap.xml) · validation_report.json
  sql/      install.sql
  docs/     installation · configuration · administration · architecture · tests · limitations
  tools/    mapgen/ (construction + validation des cartes) · assets/ (emblèmes, sons)
  tests/    simulation serveur · contrats · interface · syntaxe · run_all.sh
```
