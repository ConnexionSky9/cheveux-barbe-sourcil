> **Base Elyzea : intégration déjà faite** (rien à refaire) :
> objet `noirphone` + image dans elyzea_inventory · `ensure noirx` dans server.cfg (après bank_heist) ·
> permission `noirx_staff` dans admin_menu (donnée au SuperAdmin) + onglet **Illégal › NOIR X** (`admin_menu/html/noirx.js`,
> `admin_menu/server/noirx.lua`, via les exports `AdminDataAsync` / `AdminActionAsync`) ·
> messages d'elyzea_illegal sur le téléphone (`Config.PhoneNotify`). Donner le téléphone : `/egive [id] noirphone 1`.

# NOIR X — Installation sur la base Elyzea

NOIR X est **déjà relié** à tes ressources. Les appels ont été écrits d'après leur code source :

| Ressource | Utilisée pour | Fichier NOIR X |
|---|---|---|
| `elyzea_core` | base de données (`db_query`, `db_insert`, `db_update`), personnage (`GetCitizenId`), argent propre (`GetPlayer(src).Functions.AddMoney/RemoveMoney`), notifications | `bridge/server/database.lua`, `identity.lua`, `custom_economy.lua` |
| `elyzea_inventory` | objet `noirphone` utilisable (`RegisterUsableItem`), argent sale `black_money` (`GetItemCount`, `AddItem`, `RemoveItem`) | `bridge/server/custom_inventory.lua` |
| `admin_menu` | permission staff (`HasPermission(src, 'noirx_staff')`), comme `elyzea_illegal` | `bridge/server/admin.lua`, `server/admin_menu.lua` |
| `elyzea_illegal` | facultatif : ses messages « numéro inconnu » arrivent sur NOIR X | `client/phone.lua` |

Rien de tout cela n'a encore été testé en jeu : la checklist est en bas de page.

## 1. Installer la ressource

1. Copie le dossier `noirx` dans `resources/`.
2. Dans `server.cfg`, **après** `elyzea_core`, `elyzea_inventory` et `admin_menu` :
   ```cfg
   ensure noirx
   ```
3. Les tables sont créées automatiquement au démarrage (`sql/001` et `sql/002`, rejouables).
   Pour avoir deux informateurs d'exemple, importe une seule fois `sql/003_noirx_ratline_exemples.sql`.

## 2. Déclarer l'objet `noirphone` dans elyzea_inventory

1. Ouvre `elyzea_inventory/shared/items.lua`. Dans `Items = { … }`, sous la ligne `phone = { … }`, ajoute :
   ```lua
   noirphone = { label = 'NOIR X', weight = 180, stack = false, description = 'Terminal clandestin sécurisé. Accès au réseau privé NOIR X.' },
   ```
2. Copie `noirx/install/elyzea_inventory/html/img/noirphone.png` dans `elyzea_inventory/html/img/`.
3. `restart elyzea_inventory` puis `ensure noirx`.
4. Donne-le : `/egive [id] noirphone 1`.

NOIR X enregistre lui-même l'objet comme utilisable. Il n'est jamais consommé.
Tu peux aussi ouvrir le téléphone avec `/noirx` (la possession est toujours vérifiée par le serveur).

## 3. Argent

| Argent | Où NOIR X le lit | Réglage |
|---|---|---|
| Sale | objet `black_money` d'elyzea_inventory (même objet qu'elyzea_illegal) | `Config.Money.dirtyItem` |
| Propre | compte `cash` d'elyzea_core | `Config.Money.cleanAccount` : `'cash'` ou `'bank'` |

L'argent blanchi est versé sur ce compte propre. Tous les versements passent par une file (`noirx_payouts`) : un gain n'est versé qu'une seule fois, même après un redémarrage. Si le versement échoue, il est retenté plus tard.

## 4. Permission staff (admin_menu)

1. Dans `admin_menu/config.lua`, ajoute la permission `noirx_staff` à la liste des permissions, de la même façon que `illegal_staff`.
2. Donne-la aux grades staff voulus dans l'onglet **Grades** du menu.

Tant qu'admin_menu n'est pas démarré, l'ACE `noirx.admin` sert de secours :
```cfg
add_ace group.admin noirx.admin allow
```

**Onglet NOIR X dans admin_menu** : les exports sont prêts, au même format que l'onglet ILLEGAL :
```lua
exports.noirx:AdminData(src)               -- informateurs, infos, blanchiments en cours, réglages, journaux
exports.noirx:AdminAction(src, name, data) -- ok, message
```
L'interface de l'onglet (`admin_menu/html/noirx.js`) sera écrite quand tu m'enverras `admin_menu`. En attendant, les commandes staff ci-dessous font tout.

## 5. Messages d'elyzea_illegal sur NOIR X (facultatif)

Dans `elyzea_illegal/config.lua`, remplace `Config.PhoneNotify = nil` par :
```lua
Config.PhoneNotify = function(title, message) exports.noirx:PhoneNotify(title, message) end
```
Si le joueur a le NOIR X sur lui, le message s'affiche sur le téléphone. Sinon, il s'affiche en notification normale d'elyzea_core.

## 6. Commandes staff (en attendant l'onglet admin_menu)

| Commande | Effet |
|---|---|
| `/nx_informant_add Nom \| accroche \| message d'accueil` | crée un informateur PNJ |
| `/nx_informant_list` | liste les informateurs |
| `/nx_intel_here <idInformateur> <catégorie> <prix> <dirty\|clean> <fiabilité> \| Question \| Réponse \| mots, clés` | crée une info avec **ta position** comme point GPS |
| `/nx_intel_add …` | pareil, sans GPS |
| `/nx_intel_list [idInformateur]` · `/nx_intel_toggle <id> on\|off` · `/nx_intel_del <id>` | gérer les infos |
| `/nx_launders` · `/nx_launder_cancel <id> [refund]` | blanchiments en cours, annulation |
| `/nx_set Chemin valeur` · `/nx_get Chemin` | régler en jeu (ex. `/nx_set Laundering.feePercent 25`) |
| `/nx_revoke <pseudo>` | révoquer un pseudo |

Catégories d'infos : `weed` (champs), `dealer` (revendeurs), `opportunity`, `rival`, `rumor`, `other`.

Exemple, placé sur le champ de weed :
```
/nx_intel_here 1 weed 1500 dirty 90 | Où pousse la weed ? | Derrière les serres de Grapeseed, côté est. | weed, champ, beuh, plantation
```

## 7. Checklist en jeu

- [ ] Console au démarrage : pas de ligne rouge `[noirx]` ; les tables `noirx_*` existent.
- [ ] `/egive [id] noirphone 1`, puis utilisation dans l'inventaire : le téléphone s'ouvre et l'objet reste.
- [ ] Sans l'objet, `/noirx` ne fait rien.
- [ ] Le portefeuille affiche ton `black_money` et ton `cash` ; `/egive [id] black_money 1000` met le montant à jour en 5 s maximum.
- [ ] Ratline : poser une question payante retire l'argent sale ; « Placer le GPS » met le point sur la carte.
- [ ] Blanchiment : l'argent sale part au lancement, l'argent propre arrive à la fin (moins la commission).
- [ ] Changer de personnage : le téléphone se ferme ; le second personnage a ses propres données.
- [ ] Un joueur sans `noirx_staff` ne peut pas utiliser les commandes `/nx_*`.
