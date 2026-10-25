# API REST

Toutes les réponses sont en JSON. Erreurs : `{ "error": "message lisible", "code": "identifiant" }`.

## Public (site)

| Méthode | Route | Accès | Description |
|---|---|---|---|
| GET | `/api/health` | public | État |
| GET | `/api/config` | public | Nom du serveur, devise, liens Discord et support |
| GET | `/api/catalog` | public | Catégories et produits actifs (sans récompenses ni ids Tebex) |
| GET | `/api/products?category=slug` | public | Produits |
| GET | `/api/products/:slug` | public | Fiche produit |
| GET | `/api/session` | public | Joueur connecté et jeton CSRF |
| POST | `/api/auth/link` `{code}` | public, limité (10 / 15 min) | Connexion par code de liaison |
| POST | `/api/auth/logout` | joueur + CSRF | Déconnexion |
| GET | `/api/account/orders` | joueur | Historique, avec état de livraison |
| GET | `/api/account/entitlements` | joueur | Avantages actifs |
| POST | `/api/checkout` `{items:[{productId,quantity}]}` | joueur + CSRF, limité | Crée la commande et le panier Tebex. Renvoie `{ref, redirectUrl}`. |
| GET | `/api/checkout/:ref/continue` | lien de retour Tebex | Vérifie le compte Cfx.re, ajoute les paquets, redirige vers le paiement |
| GET | `/api/orders/:ref/status` | référence (UUID) | Statut de commande, sans donnée personnelle |
| POST | `/api/webhooks/tebex` | signature Tebex | Notifications de paiement |

## Serveur de jeu (`Authorization: Bearer GAME_SERVER_TOKEN`)

| Méthode | Route | Description |
|---|---|---|
| GET | `/api/game/catalog` | Catalogue |
| POST | `/api/game/link-code` `{cfxId,name,identifiers}` | Code de liaison (8 caractères, 10 min) |
| POST | `/api/game/checkout` `{cfxId,name,items}` | Achat depuis le jeu, avec le compte imposé par le serveur |
| POST | `/api/game/deliveries/claim` `{cfxIds:[…]}` | Réserve les tâches des joueurs connectés |
| POST | `/api/game/deliveries/:id/result` `{ok,error?,meta?}` | Compte rendu (idempotent) |
| GET | `/api/game/players/:cfxId/summary` | Historique, avantages actifs, compte web lié ou non |

## Administration (cookie admin + `X-CSRF-Token` pour les modifications)

| Route | Rôle minimum |
|---|---|
| `POST /api/admin/login`, `POST /logout`, `GET /me` | — / support |
| `GET /api/admin/stats` | support |
| `GET/POST /categories`, `PATCH/DELETE /categories/:id` | lecture : support · écriture : admin |
| `GET/POST /products`, `GET/PATCH /products/:id`, `PUT /products/:id/rewards` | lecture : support · écriture : admin |
| `GET /tebex/packages`, `POST /tebex/sync-prices` | admin |
| `GET /orders?status&q&page`, `GET /orders/:id` | support |
| `GET /deliveries?status`, `POST /deliveries/:id/retry`, `POST /deliveries/:id/cancel` | lecture : support · actions : admin |
| `GET /webhooks?status`, `GET /logs?level` | support |
| `GET/POST /admins`, `PATCH /admins/:id` | owner |
