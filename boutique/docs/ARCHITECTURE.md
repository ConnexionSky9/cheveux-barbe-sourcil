# Architecture

## Choix

| Partie | Technologie | Pourquoi |
|---|---|---|
| API | Node.js 20+, TypeScript strict, Express 5, mysql2, zod | Une seule application pour le site, le panel, les webhooks Tebex et le serveur de jeu. Les requêtes SQL sont préparées et toutes les entrées sont validées. |
| Site + panel | React 18 + TypeScript, Vite | Servi par l'API sur la **même origine** : cookies HttpOnly, CSRF simple, aucune configuration CORS. Le panel est chargé à part (code séparé). |
| Base | MySQL 8 / MariaDB 10.6+ | C'est ce qu'utilise déjà votre serveur. Transactions et `SKIP LOCKED` pour la file de livraison. |
| Boutique en jeu | Lua 5.4 + NUI en HTML/CSS/JS sans compilation | Elle n'a pas besoin de React. La NUI pèse moins de 30 Ko et n'a rien à compiler pour l'installer. Le **thème CSS est commun** avec le site (`shared/theme.css`). |
| Paiement | Tebex Headless API + webhooks | C'est l'intégration autorisée pour monétiser un serveur FiveM. Le paiement, les cartes bancaires et la TVA restent chez Tebex. |

## Flux d'un achat

```
Joueur (site ou jeu)          API boutique                   Tebex                     Serveur FiveM (server_shop)
        │  panier ──────────────► commande « en attente »
        │                        panier Tebex (custom.order_ref)──► basket
        │ ◄──── redirection ──── lien de connexion Cfx.re ◄──────── auth links
        │  connexion Cfx.re ───────────────────────────────────────►
        │ ◄─────────────────────────── retour /api/checkout/:ref/continue
        │                        vérifie le compte, ajoute les paquets ─► basket
        │ ◄──── redirection ──── page de paiement Tebex
        │  paie ───────────────────────────────────────────────────►
        │                        ◄──── webhook signé payment.completed
        │                        commande « payée », récompenses, tâches de livraison
        │                                                             ◄── toutes les 20 s : tâches des joueurs connectés
        │                                                                 exécute (adaptateur), mémorise, rend compte ──►
        │  en jeu : « VIP Or vous a été livré »
```

## Garanties

- **Prix et droits côté serveur** : la NUI et le navigateur n'envoient qu'un identifiant de produit et une quantité. Le prix payé est celui de Tebex. Les récompenses viennent de la base.
- **Idempotence** :
  - `webhook_events.tebex_id` est unique : un événement n'est traité qu'une fois ;
  - `orders.tebex_transaction_id` est unique : une même transaction reçue sous un autre id d'événement ne crée rien de plus ;
  - `rewards (order_item_id, unit_index, reward_def_id)` et `delivery_jobs (reward_id, action)` sont uniques ;
  - côté jeu, la table `server_shop_deliveries` garde les tâches déjà exécutées.
- **Concurrence** : le traitement d'un webhook et la réservation des tâches se font en transaction, avec verrou de ligne (`FOR UPDATE`, `SKIP LOCKED`).
- **Échecs** :
  - nouvel essai avec attente croissante (2, 4, 8… jusqu'à 60 minutes) ;
  - « échouée » au bout de `DELIVERY_MAX_ATTEMPTS` essais ;
  - une exécution interrompue (arrêt du serveur en pleine livraison) n'est **pas** refaite automatiquement : elle remonte en erreur pour vérification.
- **Retrait** :
  - fin de durée : tâche planifiée chaque minute (`sweepExpired`) ;
  - remboursement ou litige perdu : traité par le webhook.

## Tables

`users`, `linked_accounts`, `link_codes`, `admins`, `sessions`, `categories`, `products`, `product_rewards`, `orders`, `order_items`, `transactions`, `webhook_events`, `rewards` (récompenses accordées), `delivery_jobs` (récompenses en attente de livraison ou de retrait), `audit_logs` (journal des actions sensibles et des erreurs). Le détail des colonnes est dans `database/migrations/001_schema.sql`.

## Sécurité

| Risque | Protection |
|---|---|
| Faux paiement | Signature `X-Signature` (HMAC-SHA256 du SHA-256 du corps brut), liste d'IP facultative. Le retour du navigateur n'est jamais pris comme une preuve. |
| Rejeu d'une notification | Id d'événement unique, transaction unique, verrou de ligne |
| Usurpation de compte | Identifiant Cfx.re lu **par le serveur FiveM** et transmis avec un jeton secret. Code de liaison à usage unique (10 min, haché en base, limite de tentatives). Le compte Cfx.re Tebex doit correspondre. |
| Injection SQL | Requêtes préparées uniquement. Noms de tables ESX vérifiés (`^[%w_]+$`). |
| XSS | React échappe le texte. La NUI insère le texte avec `textContent`. En-tête CSP strict (helmet). |
| CSRF | Cookies `SameSite` + jeton CSRF par session dans l'en-tête `X-CSRF-Token` pour toute modification |
| Force brute | Limites de débit (connexion admin, liaison, commandes). Compte admin verrouillé 15 min après 5 échecs. |
| Sessions | Jeton aléatoire de 256 bits, seul son hachage est stocké. HttpOnly, Secure. Durée : 7 jours (joueur), 8 h (admin). |
| Panel | Rôles vérifiés **sur chaque route** (support < admin < owner). Il reste toujours un propriétaire actif. |
| Commandes en jeu | La récompense `command` ne peut appeler qu'une commande déclarée dans `config.lua`. Les variables sont filtrées. |
| Secrets | Fichier `.env` (non versionné), `set` dans server.cfg. Aucune clé dans le site, la NUI ou les journaux. |
