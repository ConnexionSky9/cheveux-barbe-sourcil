# Intégration Tebex

## Ce qui est utilisé

1. **Headless API** (`https://headless.tebex.io`), appelée **uniquement par l'API**, jamais par le navigateur :
   - `POST /api/accounts/{token}/baskets` : création du panier, avec `custom.order_ref` (référence de notre commande), `complete_url` et `cancel_url` ;
   - `GET /api/accounts/{token}/baskets/{ident}/auth?returnUrl=…` : lien de connexion **Cfx.re** (obligatoire pour FiveM) ;
   - `POST /api/baskets/{ident}/packages` : ajout des paquets, une fois le joueur connecté ;
   - `GET /api/accounts/{token}/baskets/{ident}` : état du panier et lien `links.checkout` ;
   - `GET /api/accounts/{token}/categories?includePackages=1` : liste des paquets pour le panel (relier un produit, synchroniser les prix).

   Ces chemins ont été vérifiés sur le client npm `tebex_headless`, et non contre Tebex en direct : le réseau de développement était fermé.
2. **Webhooks** : `POST https://VOTRE-SITE/api/webhooks/tebex`
   - Signature : `X-Signature = HMAC_SHA256(clé = secret du webhook, données = SHA256_hex(corps brut))`.
   - `validation.webhook` : l'API répond `{ "id": "<id reçu>" }`.
   - Traités :
     - `payment.completed` : commande payée et récompenses créées ;
     - `payment.declined` : commande échouée ;
     - `payment.refunded` : remboursement ;
     - `payment.dispute.lost` : litige perdu, retrait ;
     - `payment.dispute.opened` / `won` / `closed` : journalisés.
   - Les autres événements sont enregistrés puis ignorés.
   - En cas d'erreur, l'API renvoie 500 : Tebex renvoie la notification plus tard, sans risque de doublon.

## Champs lus dans `payment.completed`

`subject.transaction_id`, `subject.custom.order_ref`, `subject.price_paid` (ou `price`), `subject.customer.username.id` (identifiant Cfx.re du payeur), et pour chaque élément de `subject.products` : `id` (paquet Tebex), `quantity`, `paid_price`, `username.id` (destinataire si c'est un cadeau).

> **À vérifier avec un achat test** (Tebex › mode test) : que `customer.username.id` est bien l'identifiant numérique Cfx.re, le même que `fivem:XXXX` en jeu. Si un champ diffère, la commande est payée mais la récompense n'est pas créée : une erreur `payment.no_recipient` ou `payment.unknown_package` apparaît dans **Panel › Journaux**. Corrigez la lecture dans `backend/src/services/payments.ts` (fonction `onCompleted`).

## Configuration dans Tebex

1. **Integrations › Headless API** : récupérez l'identifiant public de la boutique (`TEBEX_PUBLIC_TOKEN`) et, si besoin, la clé privée.
2. **Webhooks** : ajoutez l'adresse et cochez les événements ci-dessus, puis copiez le secret dans `TEBEX_WEBHOOK_SECRET`.
3. **Paquets** : un paquet par produit, au même prix. **Pas besoin de commandes de jeu Tebex** : la livraison est assurée par `server_shop`. Si vous laissez aussi le plugin Tebex du serveur exécuter des commandes, la livraison serait doublée : n'ajoutez pas de commandes de jeu aux paquets vendus par ce système.
4. **Abonnements** : non pris en charge. Utilisez des produits à durée fixe en paiement unique.
5. **IP des webhooks** : pour activer le filtrage, renseignez `TEBEX_WEBHOOK_IPS` avec les adresses publiées par Tebex. Vérifiez-les sur la documentation officielle au moment de l'installation : elles peuvent changer.

## Achat test conseillé avant l'ouverture

1. Activez le mode test de Tebex. Reliez un produit à un paquet à 0,01 € ou en test.
2. En jeu : `/boutique_lier`, puis connexion sur le site.
3. Achetez depuis le site, puis vérifiez :
   - **Panel › Notifications Tebex** : `payment.completed` est « traitée » ;
   - **Panel › Commandes** : la commande est « Payée » ;
   - **Panel › Livraisons** : la tâche est « done » en moins d'une minute si vous êtes connecté.
4. Remboursez depuis Tebex : le grade ou le véhicule doit être retiré en jeu.
