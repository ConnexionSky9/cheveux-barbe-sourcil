# elyzea_change — Pesos de Cayo Perico et bureau de change

Nouvelle monnaie : les **pesos**, un objet d'inventaire (`pesos`, pièce dorée « CAYO PERICO »).
On les obtient au **bureau de change** : un PNJ placé avec l'éditeur de map d'admin_menu.
Les boutiques de vêtements peuvent être réglées pour n'accepter **que les pesos**.

## Installation

1. Copier `elyzea_change` dans les ressources.
2. Dans `server.cfg`, après `elyzea_inventory` et `admin_menu` :
   ```
   ensure elyzea_change
   ```
3. Remplacer aussi les fichiers modifiés :
   - `elyzea_inventory` : objet `pesos` (`shared/items.lua`) et son image (`html/img/pesos.png`) ;
   - `admin_menu` : rôle « 🪙 Bureau de change » et option « Pesos uniquement » des boutiques de vêtements ;
   - `elyzea_clothing` : paiement en pesos.

## Poser un bureau de change

admin_menu › Éditeur de map › PNJ › « Ce qu'il fait » › **🪙 Bureau de change** :

| Réglage | Exemple | Effet |
|---|---|---|
| Nom affiché | Change du port | Titre de la fenêtre et de l'invite « E » |
| Pesos donnés pour 100 $ | 100 | 1 000 $ → 1 000 pesos |
| $ rendus pour 100 pesos | 90 | 1 000 pesos → 900 $ (le bureau garde 10 %) |

Les réglages « Qui peut lui parler » et les horaires du PNJ s'appliquent aussi.

## Utilisation en jeu

**E** près du PNJ : fenêtre du bureau de change.
- Choisir le sens (**$ → Pesos** ou **Pesos → $**), le montant (boutons +100, +1 000, +10 000, Tout), puis **Échanger**.
- Seul l'**argent liquide** est échangé (pas la banque).
- Le montant reçu est arrondi vers le bas : jamais d'argent créé par un arrondi.

## Boutique de vêtements « pesos uniquement »

admin_menu › PNJ avec le rôle 👕 Boutique de vêtements › **Moyen de paiement accepté** › **🪙 Pesos uniquement**.
Les prix (même pourcentage) sont alors affichés et payés en pesos ; le liquide et la banque sont refusés, côté serveur aussi.

## Sécurité (vérifié par le serveur)

- Taux et position du guichet pris sur le PNJ côté serveur, jamais envoyés par le joueur.
- Distance au guichet (5 m), montant entier entre 1 et 1 000 000, solde suffisant.
- Place dans l'inventaire vérifiée **avant** de payer ; si les pesos ne peuvent pas être donnés, le liquide est rendu (et inversement).
- Une même demande renvoyée deux fois (double clic, lag) n'est exécutée qu'une fois.

## Réglages (`config.lua`)

`Config.Item` (objet des pesos), `Config.Default` (taux par défaut), `Config.MinAmount`, `Config.MaxAmount`, `Config.MaxDistance`.

Exports : `exports.elyzea_change:OpenFor(src, { name, toPesos, toCash, coords })`, `exports.elyzea_change:GetPesos(src)`.

Image de la pièce : `tools/make_coin.py` (Python + Pillow) la redessine si besoin.

## Tests hors jeu

- `python3 tests/run_change_sim.py` : vrai `server.lua`, argent et inventaire imités (21 vérifications).
- `NODE_PATH=$(npm root -g) node tests/ui_change.cjs` : fenêtre dans Chromium, sans internet (14 vérifications).
- Dans `elyzea_clothing` : `python3 tests/run_pesos_sim.py` (13) et `node tests/ui_pesos.cjs` (3).

Non testé en jeu.

## Monnaie de chaque commerce (dollars / pesos) : `Config.Payment`
Un seul endroit décide quelle monnaie accepte un commerce.

Commerces concernés : fourrières, tatoueur, coiffeur, supérette, armurerie, boutique PNJ, garage PNJ et boutiques de vêtements.

```lua
Tatoueur = { Currency = 'pesos', ForceCurrency = true },   -- pesos uniquement, pas de choix
Superette = { Currency = 'money', ForceCurrency = false },  -- dollars d'abord, pesos acceptés
```

Règles :
- `ForceCurrency = true` : seule cette monnaie est proposée et acceptée par le serveur.
- Sinon, la monnaie réglée sur le PNJ s'applique (admin_menu › PNJ › « Dollars ou pesos ») ; à défaut, celle du commerce, l'autre monnaie restant acceptée.
- `PesosRate` : nombre de pesos pour 1 $ de prix (arrondi au-dessus).
- `Enabled = false` : retour aux dollars partout.
- Pesos insuffisants : refus, rien n'est retiré ni donné, et le joueur est envoyé au bureau de change.

Exports serveur (`server_payment.lua`) :
- `PaymentPlan(src, commerce, opts)` ;
- `PaymentCharge(src, commerce, montant, méthode, raison, opts)` → `{ ok, error, receipt }` ;
- `PaymentRefund(src, reçu)` ;
- `PaymentMethods(commerce, opts)` ;
- `PaymentPrice(méthode, montant)`.

Ils sont testés dans `elyzea_fourriere/tests/run_sim.py`.
