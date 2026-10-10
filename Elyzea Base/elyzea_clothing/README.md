# elyzea_clothing — Boutique de vêtements

Essayage en direct, panier, paiement liquide/banque, vêtements en objets d'inventaire,
panneau « Ma tenue » (F3) et **packs de vêtements détectés automatiquement**.

## Ajouter un pack de vêtements (2 étapes)

1. Dépose le dossier du pack dans `resources/[vetements]/`
   (n'importe quel pack FiveM de vêtements addon : il contient un `fxmanifest.lua`, un dossier `stream/` et un fichier `.meta`).
2. Redémarre le serveur.

C'est tout. La boutique trouve le pack toute seule, le range dans un filtre à son nom
(nom du dossier mis en forme : `ma_marque_luxe` → « Ma marque luxe ») et vend ses vêtements.

> À faire **une seule fois** : `ensure [vetements]` dans `server.cfg`, **avant** `ensure elyzea_clothing`
> (déjà présent dans le `server.cfg` d'Elyzea). Tu peux aussi lancer un pack seul avec `ensure nom_du_pack`.

Vérifier : tape `vetements_packs` dans la console du serveur → liste des packs trouvés et de leurs collections.
Au démarrage, la console affiche aussi `[elyzea_clothing] Packs de vêtements détectés : …`.

### Réglages facultatifs d'un pack (`config.lua` → `Config.Packs.list`)

```lua
list = {
    ['eup_police']     = { hidden = true },                         -- pas vendu (tenues de métier)
    ['ma_marque_luxe'] = { label = 'Maison Elyzea', price = 250 },  -- nom affiché + 250 % du prix du rayon
},
```

- `Config.Packs.showGTA = false` : la boutique ne vend plus que les packs.
- `Config.Packs.price` : prix par défaut des vêtements de pack, en % du prix du rayon.

### Pourquoi les tenues ne cassent plus quand on ajoute/enlève un pack

Un vêtement de pack est enregistré par **collection + numéro dans le pack** (pas par n° global de GTA).
Ajouter, retirer ou réordonner des packs ne change donc plus les vêtements achetés, ni ceux
de l'apparence (`ely_creator`). Si un pack est retiré, ses vêtements ne peuvent simplement plus être portés
(message « pack absent »), sans rien casser d'autre.

## Boutiques

Les PNJ vendeurs (admin_menu) appellent `exports.elyzea_clothing:OpenFor(src, shop)` :

| Champ | Rôle |
|---|---|
| `name` | Nom affiché |
| `multiplier` | Prix en % (100 = normal) |
| `categories` | Liste de rayons vendus (`nil` = tous) |
| `packs` | `'all'` (défaut), `'gta'` (seulement GTA) ou liste de noms de packs `{ 'ma_marque' }` |

Test staff : `/boutique_vetements` (permission `elyzea.clothing.test`).

## Images des vêtements (facultatif)

`html/images/`
- vêtement GTA : `<sexe>/<rayon>/<n°>_<coloris>.webp` (ex. `male/tops/12_0.webp`)
- vêtement de pack : `<sexe>/<rayon>/<pack>/<n° dans le pack>_<coloris>.webp` (ex. `male/tops/ma_marque/3_0.webp`)

Le studio `elyzea_clothing_photos` crée ces images tout seul (`/elyzea_photos`), y compris pour les packs.
Sans image, la boutique affiche l'icône du rayon.

## Fichiers

| Fichier | Rôle |
|---|---|
| `config.lua` | Réglages (paiement, packs, objets, images, F3…) |
| `shared/data.lua` | Rayons (noms, prix, caméra) |
| `server/packs.lua` | Détection automatique des packs |
| `server/shop.lua` | Ouverture, contrôle du panier, paiement |
| `server/items.lua` | Vêtements en objets, noms personnalisés |
| `client/catalog.lua` | Rayons et packs vus par le joueur |
| `client/shop.lua` | Boutique (caméra, essayage) |
| `client/items.lua` | Porter/ranger depuis l'inventaire, « Ma tenue » |
| `html/` | Interface |

Utilise `@elyzea_core/lib/clothing.lua` (lecture/pose des vêtements par collection), aussi utilisé par `ely_creator`.
