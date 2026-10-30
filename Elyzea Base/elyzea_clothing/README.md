# elyzea_clothing — Boutique de vêtements

Essayage en direct, panier, paiement liquide/banque, vêtements en objets d'inventaire,
panneau « Ma tenue » (F3) et **packs de vêtements détectés automatiquement**.

## Le panier

- **Plusieurs articles par rayon** : plusieurs hauts, plusieurs pantalons… (30 articles au plus, `Config.MaxCart`).
  Le même modèle dans un autre coloris compte comme un autre article.
- **Classé par rayon** : une rubrique par rayon (Hauts, Pantalons, Chaussures…), avec le nombre d'articles et le sous-total.
  En haut : le nombre d'articles et de rayons, et le bouton **Vider**.
- **« Sur toi »** : dans un rayon qui a plusieurs articles, une seule pièce est montrée sur le personnage.
  « Essayer » en choisit une autre. Cliquer sur un article le remet sur le personnage et ouvre son rayon.
- **Porter tout de suite** : une pièce par rayon est portée en sortant (celle marquée « Sur toi »).
  Le reste du panier et les vêtements que tu portais vont dans l'inventaire.
  Sans cette option, tout va dans l'inventaire.
- **Vérifié par le serveur avant de payer** :
  - le prix de chaque article ;
  - les rayons vendus dans cette boutique ;
  - les vêtements cachés ;
  - un même article payé une seule fois ;
  - la place dans l'inventaire pour **tout** ce qui y arrive (articles et anciens vêtements) ;
  - l'argent.

  Si un de ces points échoue, rien n'est débité.
- Sans les vêtements en objets (`Config.Items.enabled = false`), un seul article par rayon : tout ce qui est acheté est porté.

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

### Le pack n'apparaît pas ?

1. **Le fichier du pack doit s'appeler `fxmanifest.lua`** (ou `__resource.lua`, avec **un seul s**).
   `__ressource.lua` n'est pas reconnu par FiveM : la ressource n'existe pas pour le serveur.
2. Le pack doit contenir son fichier **`.meta`** (ex. `mp_m_freemode_01_mp_m_monpack.meta`) déclaré dans le fxmanifest :
   `data_file 'SHOP_PED_APPAREL_META_FILE' 'mp_m_freemode_01_mp_m_monpack.meta'`
   et le fichier **`.ymt`** du même nom dans `stream/`. Sans eux, GTA ne charge pas les vêtements.
3. En jeu, `F8` → `vetements_diag` : liste les packs vraiment chargés pour ton personnage.
   Un pack `mp_m_…` ne contient que des vêtements **homme**, `mp_f_…` que des vêtements **femme**.

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

## Tenues enregistrées (F3 › « Mes tenues »)

Dans le panneau **Ma tenue** (F3 ou `/tenue`), onglet **Mes tenues** :

| Action | Comment |
|---|---|
| Enregistrer la tenue portée | **＋ Enregistrer ma tenue actuelle**, un nom, une catégorie |
| Porter une tenue en une fois | **Porter** |
| Renommer / changer de catégorie | **Modifier** |
| Remplacer par ce que je porte | **Remplacer** (confirmation) |
| Supprimer | **Supprimer** (confirmation) ; les vêtements restent dans l'inventaire |
| Catégories | Filtres en haut de la liste ; **＋ Catégorie** pour en créer ; une catégorie personnelle sélectionnée se renomme ou se supprime (ses tenues sont gardées, sans catégorie) |

- **Ce qui est enregistré** : les 15 rayons de la boutique, c'est-à-dire haut, t-shirt, pantalon, chaussures, sac, gilet, gants et bras,
  collier ou cravate, masque, logo, chapeau ou casque, lunettes, boucles d'oreilles, montre et bracelet.
  Chaque pièce est gardée avec son coloris et, pour un pack, sa collection et son n° dans le pack (même système que les objets vêtements).
  Le ventre de grossesse (`elyzea_famille`) n'est jamais enregistré.
- **Porter passe par l'inventaire**, comme « utiliser » un vêtement : chaque pièce de la tenue doit être un objet de ton inventaire,
  et ce que tu portais à sa place y retourne. Une pièce que tu n'as pas est laissée de côté, avec un message
  (« Non mis : Chapeau (pas dans ton inventaire) »). La liste prévient d'avance des pièces manquantes.
  Rien n'est créé, rien n'est perdu : enregistrer ou supprimer une tenue ne touche jamais aux vêtements possédés.
- **Pack retiré du serveur** : la pièce est laissée de côté (« pack absent »), le reste de la tenue est mis et l'objet reste dans l'inventaire.
- **Par personnage** : les tenues sont rattachées au `citizenid`. Un autre personnage du même joueur ne les voit pas.
  Une tenue homme ne se met pas sur un personnage femme.
- Impossible pendant la boutique, menotté, porté, à terre ou en **tenue de service** (admin_menu), pour ne pas transformer l'uniforme en objets.
- Réglages : `Config.Outfits` dans `config.lua` (activation, `max` tenues, `maxCategories`, longueur des noms, catégories par défaut).
- Base de données : tables `elyzea_outfits` et `elyzea_outfit_categories`, créées au démarrage (ou à la main : `sql/outfits.sql`).
  Le wipe d'un personnage (admin_menu) les vide aussi.
- Tests hors jeu de la partie serveur : `python3 tests/run_outfits_sim.py`, `python3 tests/run_hidden_sim.py`, `python3 tests/run_cart_sim.py` (paquet Python `lupa`).
- Test de l'interface (Chromium + Playwright) : `node tests/ui_cart.cjs <dossier des captures>`.

## Boutiques

Les PNJ vendeurs (admin_menu) appellent `exports.elyzea_clothing:OpenFor(src, shop)` :

| Champ | Rôle |
|---|---|
| `name` | Nom affiché |
| `multiplier` | Prix en % (100 = normal) |
| `categories` | Liste de rayons vendus (`nil` = tous) |
| `packs` | `'all'` (défaut), `'gta'` (seulement GTA) ou liste de noms de packs `{ 'ma_marque' }` |

Test staff : `/boutique_vetements` (permission `elyzea.clothing.test`).

## Cacher des vêtements (staff)

Permission admin_menu **`clothing_manage`** (ou la permission ACE `elyzea.clothing.test`).
1. Ouvre n'importe quelle boutique de vêtements et choisis le modèle.
2. **🙈 Cacher pour tout le monde** : plus aucun joueur ne le voit ni ne peut l'acheter, dans toutes les boutiques, tous coloris confondus.
   Ceux qui l'avaient dans leur panier le perdent, et le serveur refuse l'achat (même en trichant).
3. Toi, tu le vois encore, grisé avec l'étiquette « Caché ». Le filtre **🙈 Cachés** les liste tous ; **👁 Remettre en vente** l'annule.

- Gardé en base (table `elyzea_clothing_hidden`, créée toute seule) : ça reste après un redémarrage ou une mise à jour.
- Un vêtement de pack est retenu par son pack et son n° dans le pack : ajouter ou retirer d'autres packs ne le décale pas.
- Les modèles homme et femme sont différents : un vêtement caché en personnage homme ne l'est que pour les hommes.
- Les vêtements déjà achetés (inventaire, tenues enregistrées) restent à leurs propriétaires.
- `Config.Blacklist` (config.lua) marche toujours, et l'achat y est maintenant refusé aussi côté serveur.

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
| `server/shop.lua` | Ouverture, contrôle du panier (plusieurs articles par rayon), paiement |
| `server/hidden.lua` | Vêtements cachés par le staff (base, permission, envoi aux joueurs) |
| `server/items.lua` | Vêtements en objets, noms personnalisés |
| `server/outfits.lua` | Tenues enregistrées (base de données, porter via l'inventaire) |
| `client/catalog.lua` | Rayons et packs vus par le joueur |
| `client/shop.lua` | Boutique (caméra, essayage) |
| `client/items.lua` | Porter/ranger depuis l'inventaire, « Ma tenue » |
| `client/outfits.lua` | Onglet « Mes tenues » |
| `sql/outfits.sql` | Tables des tenues (création manuelle facultative) |
| `tests/` | Simulations serveur (tenues, vêtements cachés, panier) et test de l'interface |
| `html/` | Interface |

Utilise `@elyzea_core/lib/clothing.lua` (lecture/pose des vêtements par collection), aussi utilisé par `ely_creator`.
