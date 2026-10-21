# elyzea_labs — laboratoires illégaux des groupes

Les groupes d'**elyzea_illegal** achètent et possèdent de grands laboratoires. Ils y transforment les matières premières
récoltées **dehors** grâce à des équipements achetés et posés, font monter le laboratoire en niveau, et peuvent se le faire
prendre lors d'une attaque.

> **État : rien n'a été testé en jeu.** Le serveur est vérifié par une simulation hors jeu (`tests/run_lab_sim.py` :
> **87/87**, les 22 scénarios demandés), les interfaces ont été affichées dans un navigateur de test. Voir « À tester en jeu ».

## Analyse de l'existant (ce qui est réutilisé)
| Besoin | Système existant utilisé |
|---|---|
| Framework | `elyzea_core` (maison) : joueurs, notifications, barre de progression, `Ely.callback`, SQL (`@elyzea_core/lib/MySQL.lua`, transactions) |
| Groupes / grades / argent des groupes | `elyzea_illegal` : groupes, grades (chef = `boss`), comptes propre / sale du groupe (avec historique) |
| Appartements / instances | même principe que `elyzea_dynasty` : un *routing bucket* par bien (Dynasty 40000+, PvP 61000+, **labos 52000+id**) |
| Rond bleu | même principe que le **cercle bleu de Dynasty 8** (gestion + éditeur : flèches, Pg.Préc/Suiv, Q/E, G, Entrée, Retour) |
| Coffre | `elyzea_inventory` : `RegisterStash` (500 emplacements maximum gérés, poids en grammes) + `RegisterStashAccess` |
| Objets des drogues | ceux d'`elyzea_drogues` (feuilles, têtes, pâte de coca, produits chimiques…) : vérifiés au démarrage |
| Mort / à terre | `elyzea_ems:IsDown` |
| Menu admin | `admin_menu` : onglet, permission `labs_manage`, actions serveur revérifiées |
| F5 | le F5 d'`elyzea_illegal` ouvre la tablette du laboratoire quand on est dedans (`/laboratoire` aussi) |

Le code des équipements de Dynasty 8 (décoration) n'est pas réutilisable tel quel (lié aux biens et contrats) : l'éditeur
des laboratoires reprend **les mêmes touches et le même principe** dans cette ressource.

## Installation
1. Copier `elyzea_labs` dans les ressources ; remplacer les fichiers modifiés de `admin_menu` et `elyzea_illegal` (liste plus bas).
2. `server.cfg` : `ensure elyzea_labs` **après** `elyzea_core`, `elyzea_inventory`, `elyzea_illegal`, `elyzea_drogues`, `elyzea_ems`, `admin_menu` (déjà fait).
3. Base de données : rien à faire (tables créées au démarrage). `sql/install.sql` pour le faire à la main. Aucune donnée n'est supprimée lors d'une mise à jour.
4. Redémarrer le serveur (ou `refresh` puis `ensure elyzea_illegal`, `ensure admin_menu`, `ensure elyzea_labs`).
5. Donner `labs_manage` aux grades du staff concernés (le SuperAdmin l'a déjà).

**Dépendances réelles** : `elyzea_core`, `elyzea_inventory`, `elyzea_illegal` (obligatoires) ; `elyzea_drogues` (objets des recettes ; sans lui, les
recettes aux objets inconnus sont désactivées au démarrage) ; `elyzea_ems` (joueurs à terre, facultatif) ; `admin_menu` (administration).
**Aucun MLO requis** : intérieurs du jeu de base (bunker, laboratoires biker).

## Créer un laboratoire
admin_menu › Illégal › 🧪 **Laboratoires** › se placer devant la porte (dehors) › nom, intérieur, prix › **Créer ici**.
Ensuite le **chef** d'un groupe l'achète à l'entrée (E) avec le compte du groupe (argent sale par défaut) et reçoit un code à 4 chiffres.

## Fonctionnement en jeu
- **Entrée** (E) : membres autorisés sans code ; les autres saisissent le code (pavé). 3 erreurs = blocage 2 min, le chef est prévenu.
  Le code est gardé en empreinte SHA-256 salée, jamais en clair, jamais envoyé aux joueurs.
- **Intérieur** : ROUGE sortie · BLEU gestion des équipements (acheter et poser, poser depuis la réserve, déplacer, ranger, revendre 50 %) · ORANGE coffre.
  E près d'un équipement posé : ses recettes (ingrédients, ce que tu as, quantité ×1 à ×5) → barre de progression.
- **Aucune récolte à l'intérieur** : feuilles de cannabis, coca, produits chimiques se récoltent dehors (elyzea_drogues) ; les ingrédients
  s'achètent aux fournisseurs. Le laboratoire ne fait que transformer.
- **Tablette (F5 dedans, ou /laboratoire)** : Informations (propriétaire, niveau, XP, progression, améliorations, équipements),
  Sécurité et accès (code ; autorisations par grade : entrer sans code, fabriquer, coffre, équipements, tablette, code, améliorations, attaques),
  Équipements (achetés, posés, débloqués, verrouillés, prix, niveaux, recettes), Améliorations, Coffre, Attaques (en cours, horaires, historique).
- **Niveau et expérience** : appartiennent au laboratoire (identifiant), jamais au groupe. L'XP n'est donnée qu'après une fabrication terminée et revalidée.
- **Coffre** : 500 emplacements, 1 000 kg (`Config.Stash`), identifiant `lab_<id>` : il reste au laboratoire après une capture.

## Niveaux (par défaut)
| Niveau | XP requise | Prix | Débloque | Équipements max |
|---|---|---|---|---|
| 1 | — | achat du labo | 🌿 Cannabis (séchoir, manucure, roulage, conditionnement) | 8 |
| 2 | 1 500 | 150 000 $ | ❄️ Cocaïne (broyeur, extraction, table de coupe, raffinerie : basique + pure) | 14 |
| 3 | 5 000 | 400 000 $ | 💎 Crack, ⚗️ Méth | 20 |
| 4 | 12 000 | 900 000 $ | 💊 Ecstasy, 🐴 Kétamine, 💉 Opiacés | 28 |

## Attaques
- Lancées à l'entrée par le **chef** d'un autre groupe (réglable), dans un **créneau autorisé**, avec au moins `minAttackers` attaquants
  **vivants** dans la zone et `minDefendersOnline` défenseurs connectés, hors délais de repos (laboratoire et groupe).
- États : préparation (60 s, défenseurs prévenus) → en cours (**10 min**) → réussie / échouée / annulée. Une seule attaque à la fois par laboratoire.
- Chaque seconde, le serveur compte les attaquants vivants (ni morts, ni à terre, ni déconnectés) dans la zone (rayon 60 m autour de l'entrée).
  Zone vide d'attaquants pendant 30 s = échec. À la fin : victoire si au moins un attaquant vivant dans la zone (ou majorité, réglable).
- Victoire : **transfert atomique** (une transaction SQL) : même identifiant, niveau, XP, améliorations, équipements, coffre ; nouveau code
  envoyé au nouveau chef, autorisations remises à zéro, joueurs qui perdent l'accès sortis du laboratoire. Échec ou annulation : rien ne change.
- Laboratoire verrouillé pendant l'attaque (réglable). Membres des deux groupes : zone sur la carte et au sol, compte à rebours, effectifs.
- Attaques interrompues par un redémarrage : annulées (le propriétaire ne change jamais sans victoire validée).

## Horaires d'attaque (admin_menu › Laboratoires › Attaques)
Activer / désactiver, fuseau (heures par rapport à UTC), **créneaux** (jours + début + fin, plusieurs créneaux, un créneau peut passer minuit),
préparation, durée, rayon, conditions de victoire, minimums, repos, verrouillage. Enregistré en base (table `labs_settings`), appliqué tout de suite.
Le même onglet liste les attaques en cours (bouton **Annuler**) et l'historique des captures.

## Configuration (`config.lua`)
- `Config.Account` : compte du groupe débité (`'dirty'` / `'clean'`) · `Config.DefaultLabPrice` · `Config.MaxLabsPerGroup` (2, dans `server/ownership.lua`)
- `Config.Interiors` : intérieurs (points, zone des équipements, *entity sets*) · `Config.DefaultInterior`
- `Config.Levels` : seuils d'XP, prix, catégories débloquées, équipements max
- `Config.Equipment` : équipements (catégorie, prix, modèles, animation) · `Config.SellRefund` · `Config.MinSpacing` · `Config.KeepClear`
- `Config.Recipes` : recettes (`equipment`, `inputs`, `outputs`, `duration`, `xp`) · `Config.MaxBatch`
- `Config.Perms` / `Config.DefaultGradePerms` : droits par grade · `Config.Code` · `Config.Stash` · `Config.Raids` (valeurs par défaut)

### Ajouter un équipement et ses recettes
```lua
Config.Equipment.lsd_lab = { label = 'Paillasse (LSD)', category = 'lsd', price = 80000, models = { 'prop_table_08' }, anim = A.table }
Config.Categories.lsd = { label = 'LSD', icon = '🌈' }
table.insert(Config.Levels[4].unlocks, 'lsd')      -- ou un niveau 5
R.lsd_synth = { label = 'Synthèse', equipment = 'lsd_lab', inputs = { { 'drg_reagent', 1 } }, outputs = { { 'lsd_tab', 5 } }, duration = 12, xp = 15 }
```
Les objets doivent exister dans `elyzea_inventory/shared/items.lua` (sinon la recette est désactivée au démarrage, avec un message en console).
Ajouter un niveau : une ligne de plus dans `Config.Levels`.

## Fichiers
**Créés** : `elyzea_labs/` (fxmanifest, config, `shared/sha256.lua`, `shared/rules.lua`, `server/{main,permissions,ownership,access,equipment,production,storage,upgrades,raids,tablet,admin}.lua`,
`client/{main,entrance,editor,production,tablet,raids}.lua`, `web/{index.html,style.css,app.js}`, `sql/install.sql`, `tests/{mocks.lua,lab_sim.lua,run_lab_sim.py}`, README) ;
`admin_menu/server/labs.lua`, `admin_menu/html/labs.js`.
**Modifiés** (ajouts seulement) : `elyzea_illegal/server/main.lua` (exports `GetPlayerGroupFull`, `GetGroupInfo`, `GetGroupOnline`, `GroupPay`, `GroupCredit`, `GetGroupIds`),
`elyzea_illegal/client/f5.lua` (F5 dans un laboratoire → tablette), `admin_menu/config.lua` (permission `labs_manage`), `admin_menu/fxmanifest.lua`,
`admin_menu/html/index.html`, `admin_menu/html/script.js` (onglet dans « Illégal »), `Serveur cfg/server.cfg`.

## Tests
`python3 tests/run_lab_sim.py` → **87/87** : achat, entrée avec / sans code, code faux et blocage, changement de code, droits des grades, achat et
pose (collisions, zones interdites), équipement verrouillé, fabrication (ingrédients, produits, XP, fin trop rapide, jeton falsifié ou réutilisé,
double lancement), niveau suivant (XP, verrou, pas de double paiement), déblocage, coffre (taille, accès), **redémarrage** (rechargement depuis
la base simulée), horaires (créneaux, minuit), déclenchement et notification, victoire des défenseurs, victoire des attaquants, transfert complet,
permissions admin, plusieurs joueurs en même temps, annulation par le staff.
La base de données, l'inventaire et les groupes sont **simulés** : la simulation vérifie la logique du serveur, pas le comportement réel en jeu.

## À tester en jeu (non vérifié)
- **Coordonnées des intérieurs** (arrivée, cercles, zone des équipements) et leurs *entity sets* : coordonnées d'usage courant, à vérifier puis corriger
  en jeu (admin › Laboratoires › Intérieurs › Tester / Définir ici). Le bunker est le grand intérieur industriel par défaut.
- Modèles des équipements : le premier modèle présent dans le jeu est utilisé (`bkr_prop_weed_dry_02b` non vérifié, repli sur d'autres modèles).
- Animations de fabrication, éditeur de placement, affichage du coffre à 500 emplacements dans l'inventaire.
- Attaque complète à plusieurs joueurs (zone, comptage, notifications, transfert).
- Aucun asset externe n'est nécessaire ; un MLO dédié peut être ajouté plus tard (nouvelle entrée dans `Config.Interiors`).
