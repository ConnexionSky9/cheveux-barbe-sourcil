# Boutique Elyzea — site web + boutique en jeu

Boutique officielle du serveur GTA RP **Elyzea** (FiveM). Elle a deux portes d'entrée :

1. **Le site web** : React. On y trouve le catalogue, le panier, le compte joueur, l'historique, les pages légales et le **panel d'administration**.
2. **La boutique en jeu** (ressource `server_shop`, `/boutique` ou F9). C'est une NUI au même design.

Les deux lisent **le même catalogue**, dans la base de la boutique. Les paiements en argent réel passent par **Tebex**, le revendeur officiel FiveM. Les achats sont **livrés automatiquement en jeu**, et seulement après la confirmation officielle de Tebex.

```
boutique/
├── backend/          API Node.js + TypeScript (Express, MySQL) : catalogue, Tebex, livraisons, admin
├── web/              Site + panel (React + TypeScript, Vite) — servi par l'API en production
├── fivem/server_shop Ressource FiveM (Lua + NUI) : boutique en jeu, livraison, adaptateurs ESX / elyzea_core
├── database/         Migrations SQL (schéma + catalogue de départ)
├── shared/theme.css  Thème commun (site + NUI)
├── tools/            sync-theme.mjs (copie du thème vers la NUI)
├── docs/             Architecture, Tebex, API, déploiement
└── .env.example      Configuration (sans secret)
```

## Ce qu'il faut savoir avant tout

- **Votre serveur n'utilise pas ESX** : il tourne sur `elyzea_core`, de type QBCore. La ressource `server_shop` détecte automatiquement **elyzea_core** ou **ESX** (`Config.Framework = 'auto'`). Elle reste donc utilisable si vous passez un jour sur ESX.
- **Rien n'est livré sans Tebex.** Un retour du navigateur (« merci pour votre achat ») ne prouve rien. Seule une notification Tebex **signée** fait passer une commande à « payée ».
- **Identification** : chaque achat est rattaché au **compte Cfx.re** du joueur (identifiant `fivem:`). Ce n'est jamais un pseudonyme. Voir « Lier son compte » plus bas.
- **Ce qui a été testé** (hors jeu, voir « Tests »), et ce qui ne l'a pas été :
  - **pas en jeu** : aucun serveur FiveM réel n'a été lancé ;
  - **pas contre Tebex en vrai** : le réseau de l'environnement de développement bloquait Tebex. Les chemins de l'API Headless viennent du client `tebex_headless` (npm). Le format des notifications vient de la documentation Tebex. **Faites un achat test** (mode test Tebex) avant l'ouverture, voir docs/TEBEX.md.

## Installation rapide (production)

Prérequis : **Node.js 20+**, **MySQL 8 ou MariaDB 10.6+**, un nom de domaine en **HTTPS** (Nginx ou Caddy devant l'API), un compte **Tebex** relié à votre serveur FiveM.

```bash
# 1. Base de données dédiée
mysql -u root -p -e "CREATE DATABASE elyzea_boutique CHARACTER SET utf8mb4;
  CREATE USER 'boutique'@'localhost' IDENTIFIED BY 'UN_MOT_DE_PASSE_FORT';
  GRANT ALL ON elyzea_boutique.* TO 'boutique'@'localhost';"

# 2. Configuration
cp .env.example backend/.env        # puis remplissez backend/.env (voir ci-dessous)

# 3. API
cd backend && npm ci && npm run build && npm run migrate:prod
npm run admin:create:prod -- patron owner      # mot de passe demandé au clavier

# 4. Site
cd ../web && npm ci && npm run build            # produit web/dist, servi par l'API

# 5. Démarrage (à mettre sous pm2 / systemd, voir docs/DEPLOIEMENT.md)
cd ../backend && npm start
```

### Les variables à remplir (`backend/.env`)

| Variable | Où la trouver |
|---|---|
| `PUBLIC_URL` | L'adresse https de votre site, par ex. `https://boutique.elyzea.fr` |
| `DATABASE_URL` | `mysql://boutique:MOT_DE_PASSE@127.0.0.1:3306/elyzea_boutique` |
| `TEBEX_PUBLIC_TOKEN` | Panneau Tebex › Integrations › Headless API : identifiant public de la boutique |
| `TEBEX_PRIVATE_KEY` | Même page (facultatif). Il reste côté serveur. |
| `TEBEX_WEBHOOK_SECRET` | Panneau Tebex › Webhooks : secret de votre adresse de webhook |
| `GAME_SERVER_TOKEN` | À générer : `openssl rand -hex 32`. C'est le même jeton que dans server.cfg. |
| `GAME_SERVER_IPS` | IP publique de votre serveur FiveM (recommandé) |
| `TRUST_PROXY` | `1` derrière Nginx ou Caddy |

### Webhook Tebex

Dans le panneau Tebex › Webhooks, ajoutez l'adresse `https://VOTRE-SITE/api/webhooks/tebex`. Cochez au minimum :

- `payment.completed`
- `payment.declined`
- `payment.refunded`
- `payment.dispute.opened`
- `payment.dispute.lost`

Tebex envoie d'abord une notification de **validation**. L'API y répond automatiquement.

### Ressource FiveM

1. Copiez `fivem/server_shop` dans le dossier `resources` de votre serveur, par exemple à côté des autres ressources Elyzea.
2. Dans `server.cfg` (ou `secrets.cfg`), avec **`set`**. N'utilisez jamais `sets` ni `setr` : les joueurs pourraient lire ces valeurs.
   ```
   set shop_api_url   "https://boutique.elyzea.fr"
   set shop_api_token "LE_MEME_JETON_QUE_GAME_SERVER_TOKEN"
   ensure server_shop
   ```
   Placez `ensure server_shop` **après** `elyzea_core` et `elyzea_inventory`.
3. Dans `fivem/server_shop/config.lua`, réglez `Config.SiteUrl` (l'adresse publique du site, pour les images), la commande, la touche et les tables de véhicules si vous utilisez ESX.
4. Redémarrez le serveur, ou faites `refresh` puis `ensure server_shop`. La console doit afficher `[server_shop] prêt (framework : elyzea)`.

## Mettre un produit en vente

1. Dans **Tebex**, créez le paquet, au même prix que sur votre site. Tebex n'a pas besoin de « commandes de jeu » : la livraison passe par notre ressource.
2. Dans le **panel** (`/admin` › Produits) :
   - créez ou modifiez le produit ;
   - cliquez sur « Lister mes paquets Tebex » puis **Choisir** ;
   - ajoutez ses **récompenses** : grade, véhicule, objet, argent, ou une commande prédéfinie dans `config.lua`.
3. Le produit devient « en vente » : il est actif **et** relié à un paquet Tebex. Sinon il s'affiche « Indisponible » et ne peut pas être acheté.

Types de récompenses :

| Type | Effet en jeu | Retirable (fin de durée, remboursement) |
|---|---|---|
| `group` | Groupe ACE `group.<nom>` tant que l'achat est actif. Lisible par `IsPlayerAceAllowed` ou `exports.server_shop:HasPerk(src, nom)`. | oui |
| `perk` | Avantage nommé lisible par vos scripts : `exports.server_shop:HasPerk(src, nom)` | oui |
| `vehicle` | Véhicule ajouté au garage du personnage actif (`player_vehicles` ou `owned_vehicles`), avec les clés | oui (supprimé par sa plaque) |
| `item` | Objet d'inventaire (elyzea_inventory, ox_inventory ou ESX) | non : signalé dans les journaux |
| `money` | Argent en jeu | non : signalé dans les journaux |
| `command` | Commande définie dans `Config.Commands` (jamais du texte libre venant du panel) | si `revoke` est défini |

> Avant de vendre de la monnaie ou des avantages de jeu, vérifiez les règles de monétisation **Cfx.re** en vigueur.

## Lier son compte (comment le joueur s'identifie)

1. En jeu, le joueur tape **`/boutique_lier`** (ou boutique › « Mon compte web »).
2. Le **serveur de jeu** lit lui-même l'identifiant Cfx.re du joueur et demande un code à l'API avec le jeton secret. Le code fait 8 caractères, est valable 10 minutes et ne sert qu'une fois.
3. Sur le site, page **Connexion**, le joueur saisit le code : son compte web est créé et rattaché à ce compte Cfx.re.
4. Au paiement, Tebex demande de se connecter avec **Cfx.re**. L'API vérifie que c'est **le même compte**, sinon elle bloque et explique pourquoi.

Le navigateur et la NUI n'envoient **jamais** d'identifiant de compte : seul le serveur de jeu, authentifié par son jeton, en fournit.

Un achat fait **directement sur la boutique Tebex**, sans passer par le site, est aussi pris en compte. Il est livré au compte Cfx.re qui a payé.

## Livraison

- La ressource interroge l'API toutes les 20 s **pour les joueurs connectés dont le personnage est chargé**. Hors ligne, la récompense attend la prochaine connexion.
- Chaque tâche est **réservée**, exécutée, puis confirmée. Une tâche réservée sans réponse redevient disponible au bout de 5 minutes.
- Le serveur de jeu garde la liste des tâches déjà exécutées (table `server_shop_deliveries`, créée automatiquement). Une même tâche n'est **jamais exécutée deux fois**.
- En cas d'échec (inventaire plein, personnage non chargé…), un nouvel essai est fait plus tard. Après 8 essais, la tâche passe en « échouée ». Elle est alors visible dans le panel (Livraisons), avec les boutons **Relancer** et **Annuler**.
- Produits à durée :
  - retrait automatique à l'expiration ;
  - un nouvel achat prolonge la période en l'ajoutant à la suite.
- Remboursement ou litige perdu :
  - les grades et véhicules sont retirés ;
  - l'argent et les objets déjà livrés sont signalés dans les journaux, pour un traitement à la main.

## Développement local

```bash
# Base locale + API
cp .env.example backend/.env    # PUBLIC_URL=http://localhost:3000, COOKIE_SECURE=false
cd backend && npm install && npm run migrate && npm run admin:create -- patron owner && npm run dev
# Site (rechargement à chaud, appels /api relayés vers le port 3000)
cd web && npm install && npm run dev          # http://localhost:5173
```

## Tests

| Commande | Ce qui est vérifié |
|---|---|
| `cd backend && npm test` | **31 tests**, sur une vraie base MySQL ou MariaDB (`TEST_DATABASE_URL`). Tebex est simulé. Voir le détail ci-dessous. |
| `python3 fivem/server_shop/tests/run_sim.py elyzea` (puis `esx`) | **30 vérifications** (elyzea), 28 (esx) : les vrais fichiers Lua, branchés sur l'API qui tourne et sur une vraie base « serveur de jeu ». Voir le détail ci-dessous. |
| `node tools/sync-theme.mjs --check` | Le thème de la NUI est identique à celui du site |

Ce que couvrent les tests de l'API :

- signature des webhooks ;
- liaison des comptes ;
- parcours complet de paiement ;
- notification reçue plusieurs fois ;
- joueur hors ligne ;
- nouveaux essais et échec définitif ;
- remboursement ;
- expiration et prolongation ;
- cadeau ;
- paquet inconnu ;
- rôles admin, CSRF, verrouillage, limite de tentatives.

Ce que couvre la simulation de la ressource :

- ouverture et catalogue ;
- liaison ;
- achat refusé ;
- livraison d'un grade, d'un véhicule, d'objets et d'argent ;
- pas de double livraison après une réponse perdue ;
- inventaire plein ;
- remboursement ;
- déconnexion.

Le site et la NUI ont aussi été vérifiés dans Chromium (Playwright), sur une base de **développement** :

- `tests/e2e/site.e2e.cjs` (22 vérifications) : parcours d'achat, erreurs, panel, mobile ;
- `tests/e2e/nui.e2e.cjs` (17 vérifications) : 1280×720, texte de l'API jamais interprété comme du HTML.

Le test du site relie VIP Diamant à un paquet Tebex : remettez `tebex_package_id` à NULL avant de le relancer.

## Limites connues

- **Abonnements Tebex** (paquets « subscription ») : non pris en charge. Vendez des durées fixes (30 ou 90 jours) en paiement unique ; un rachat prolonge.
- **Panier multiple en jeu** : la NUI achète un produit à la fois. Le site gère un panier complet.
- **Images produits** : à déposer dans `web/public/images/produits/`, ou à indiquer par une URL https. Les trois images fournies sont des visuels de départ.
- **Pages légales** : ce sont des **modèles** à compléter, avec votre statut, votre adresse et vos délais, puis à faire relire.
- **Monnaie, objets, argent** : ils ne sont pas retirés automatiquement après un remboursement. Ils sont signalés dans les journaux.

Documentation détaillée : [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) · [docs/TEBEX.md](docs/TEBEX.md) · [docs/API.md](docs/API.md) · [docs/DEPLOIEMENT.md](docs/DEPLOIEMENT.md)
