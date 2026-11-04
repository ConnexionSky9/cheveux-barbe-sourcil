# elyzea_manutention : intérim « MANUTENTIONNAIRE »

Métier d'intérim **en complément du métier principal** (il n'est jamais modifié) : on récupère des cartons, on remplit une palette
de **20 cartons exactement** (réglable), on la soulève avec **son Fenwick** (fourches sous la palette, pas de téléportation) et on la
livre dans la zone de livraison. **Payé uniquement à la livraison** (par défaut). Recommençable à l'infini.

**Tout se règle en jeu** : admin_menu › Économie et services › **Manutentionnaire**. Rien à modifier dans les fichiers.

## 1. Diagnostic de l'existant et intégrations

| Système | Ce qui existe sur le serveur | Comment le métier l'utilise |
|---|---|---|
| Framework | **elyzea_core** (remplace qbx_core, oxmysql, ox_lib) | identité (`GetPlayerData`), argent (`AddMoney`), notifications (`Notify`), aide à l'écran (`ShowTextUI`), clés de véhicule (`GiveKeys` / `RemoveKeys`), base de données (`@elyzea_core/lib/MySQL.lua`) |
| Métiers | un seul métier principal par personnage (elyzea_core) | **non touché** : l'intérim est une mission à part, gardée par la ressource |
| Bûcheron (`elyzea_farm`) | **retiré du serveur le 11/10** (commit « Métiers retirés »), il reste un onglet « farm » orphelin dans admin_menu | même principe repris (métier en complément, tenue sauvegardée sur le PC du joueur), en beaucoup plus complet. L'onglet orphelin n'est pas modifié. |
| Vêtements | les vêtements sont des objets (elyzea_clothing) ; apparence via ely_creator ; bibliothèque **ElyCloth** d'elyzea_core (vêtements par collection) | la tenue portée est lue avec **ElyCloth** (collection + n° local) et sauvegardée, puis **rendue à l'identique** (même si des packs de vêtements changent). Aucune tenue civile générique. |
| Menu admin | `admin_menu` : onglets JS (`TABS`, `VIEWS`), actions serveur (`AM.Actions`), données (`AM.DataHooks`), permissions (`permissions_extra.lua`) | 1 module serveur, 1 onglet, 1 permission. **Aucun autre fichier de l'admin modifié** (hors 3 lignes d'inscription : fxmanifest, index.html, catégorie « Économie et services »). |
| Sauvegarde | tables SQL par ressource (comme `lg_settings`) | table `manut_settings` (créée automatiquement) |
| Inventaire | elyzea_inventory | pas utilisé : les cartons ne sont pas des objets d'inventaire (rien à dupliquer ni à revendre) |

## 2. Installation
1. Copier `elyzea_manutention` dans `resources`.
2. Remplacer dans `admin_menu` : `server/manutention.lua` (nouveau), `html/manutention.js` (nouveau), `fxmanifest.lua`, `html/index.html`, `html/script.js`, `permissions_extra.lua`.
3. `server.cfg` (déjà fait dans le dépôt), **après** `elyzea_core` et `admin_menu` :
   ```cfg
   ensure elyzea_manutention
   ```
4. Redémarrer. Console : `[Manutention] prêt : 0 point(s) de cartons…`
5. Staff › Rangs : cocher **« Intérim manutentionnaire »** pour les rangs voulus (le Fondateur l'a d'office).
6. Placer les emplacements en jeu (§3). Tant qu'il en manque, l'onglet affiche ce qu'il reste à placer.

OneSync est obligatoire (Fenwick créé par le serveur). Sans admin_menu : ACE `elyzea_manutention.admin` + `/manutpoints`.

## 3. Mise en place (menu admin › Manutentionnaire)
Va sur place, ouvre le menu, clique **« 📍 Enregistrer ma position actuelle »** : position ET orientation sont lues par le serveur sur ton personnage.

| Sous-catégorie | Contenu |
|---|---|
| ⚙️ Configuration générale | activer / désactiver le métier, cartons par palette (défaut 20, 1 à 40), **autoriser la course avec un carton**, paiement banque / liquide, modèles (Fenwick, carton porté, cartons empilés, palette, PNJ) |
| 🧑‍🔧 PNJ | enregistrer ma position (+ orientation), orientation, modèle, animation (scénario GTA), PNJ affiché / désactivé, y aller |
| 📦 Points de récupération | autant que tu veux : ajouter, nommer, déplacer à ma position, supprimer, y aller |
| 🟫 Palettes | emplacements où apparaît la palette vide de chaque joueur (orientation = la tienne) |
| 🚜 Fenwick | système activé, nombre maximum simultané, retrait après N minutes sans activité, modèle, points de spawn (ajouter / déplacer / supprimer), état **libre / occupé** de chaque point |
| 🏁 Livraisons | zones de dépôt (rayon de validation réglable par zone, orientation) |
| 💰 Rémunérations | **RÉMUNÉRATION PAR PALETTE LIVRÉE** (montant libre) + paiements facultatifs : par carton, palette complète, transport |
| 🦺 Tenue | « Copier ma tenue actuelle » (homme / femme), ou tenue d'origine |
| 💾 Sauvegardes | sauvegarder, charger les paramètres enregistrés, réglages par défaut (en gardant ou non les emplacements) |
| 👷 Au travail | joueurs en mission (étape, cartons, palettes livrées, gains), arrêter le travail d'un joueur |
| 👁️ Voir les emplacements | marqueurs, numéros, flèche d'orientation et rayons en jeu (chez toi seulement) |

## 4. Déroulé pour le joueur
1. **PNJ** › [E] › présentation › **Accepter** : tenue sauvegardée puis tenue de travail, Fenwick créé sur un point libre (clés données), palette vide posée, objectifs + GPS.
2. **Cartons** : [E] au stock → animation, carton dans les bras (un seul à la fois ; course bloquée si interdite, pas d'arme, pas de véhicule) → [E] à la palette → le carton apparaît **empilé sur la palette** (couches). Suivi : « Cartons déposés : 12/20 ».
3. **PALETTE COMPLÈTE !** (20/20) → monter sur le Fenwick, glisser les fourches sous la palette, bien dans l'axe (entrée par les 4 côtés) → [E] : la palette est accrochée **là où elle est**, fourches et palette montent ensemble.
4. **Livraison** : entrer dans la zone → [E] : fourches et palette redescendent, palette posée → le serveur vérifie → **LIVRAISON TERMINÉE ! Vous avez reçu : 250 $** → nouvelle palette. Hors zone : [G] pour reposer la palette et se replacer.
5. **Fin** : PNJ › **Terminer le travail** : tenue rendue à l'identique, Fenwick supprimé, objectifs / blips / palette effacés. Le PNJ propose aussi de remplacer un Fenwick détruit.

## 5. Sécurité (tout est vérifié par le serveur)
- Positions lues par le serveur (joueur, Fenwick, **palette elle-même** à la livraison), distances vérifiées à chaque étape.
- Machine à états : impossible de prendre 2 cartons, de dépasser le nombre requis, de charger une palette incomplète, de livrer sans l'avoir chargée.
- Fenwick : il faut être **au volant de SON Fenwick** (celui créé pour le joueur).
- Paiement : calculé et versé par le serveur, **une seule fois par livraison** (et une seule fois par carton / palette / chargement pour les options).
- Cadence minimale entre deux cartons + anti-flood des demandes.
- Admin : permission revérifiée à chaque action (admin_menu `HasPermission`), valeurs validées et bornées (montants, nombre de cartons, modèles, positions), journal staff.
- Déconnexion / changement de personnage / arrêt de la ressource : Fenwick, palette et cartons supprimés ; tenue rendue à la reconnexion (sauvegarde sur le PC du joueur, même après un crash).
- Optimisation : les boucles ne tournent à chaque image que pendant le travail et près des points ; PNJ créé seulement à moins de 60 m.

## 6. Tests hors jeu
```
python3 tests/run_server_sim.py                 # 87 vérifications (2 démarrages : réglages gardés)
MANUT_MARIADB=<socket> python3 tests/run_server_sim.py   # mêmes requêtes sur une vraie MariaDB
python3 tests/run_client_sim.py                 # 43 vérifications (PNJ, tenue, cartons, course, Fenwick, livraison)
NODE_PATH=$(npm root -g) node tests/ui_job.cjs                     # interface du joueur
NODE_PATH=$(npm root -g) node ../admin_menu/tests/manutention_ui.cjs   # onglet admin
```

## 7. Limites (à vérifier en jeu)
- Positions estimées à la main : carton dans les bras (reprise de l'emote « box » de rpemotes), empilement des cartons, hauteur de levée de la palette. Le Fenwick du jeu de base (`forklift`) lève ses fourches avec `SetForkliftForkHeight`.
- Tenue de départ : n° de vêtements choisis à l'estime → utilise « Copier ma tenue actuelle » pour mettre la tienne.
