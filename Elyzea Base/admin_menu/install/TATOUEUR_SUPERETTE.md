# Tatoueur, supérette et magasins d'illenium

## 1. Poser les PNJ
F10 › Éditeur › PNJ › rôle tout prêt **🖋️ Tatoueur** ou **🏪 Supérette**, puis « Modifier son rôle ».
Comme le coiffeur : horaires, métiers autorisés, monnaie et icône sur la carte se règlent dans l'éditeur.

## 2. Tatoueur
- **Prix** : un prix par zone du corps (tête, torse/dos, chaque bras, chaque jambe) et un prix de retrait au laser.
- **Les tatouages** sont lus dans `illenium-appearance/shared/tattoos.lua` (plusieurs centaines).
  Au démarrage, la console serveur affiche : `Tatoueur : 1234 tatouages chargés`.
  Les noms sont ceux du jeu (en français si le jeu du joueur est en français), sinon ceux d'illenium.
- **`tattoo_data.lua`** (racine du menu) permet de :
  - renommer les zones et les catégories (collections) ;
  - ajouter tes propres tatouages (`TattooData.custom`) ;
  - cacher des tatouages (`TattooData.hidden`).
- **Emplacement** : GTA place chaque tatouage à un endroit fixe du corps (on ne peut pas le déplacer
  librement). Le joueur choisit la zone sur la silhouette, puis le tatouage parmi tous ceux de cette zone.
- **Enregistrement** : dans illenium-appearance s'il est démarré, sinon par le menu (`data/tattoo_looks.json`).

## 3. Supérette
Dans la carte « Supérette » de l'éditeur :
- **+ Ajouter un produit** : une ligne = un produit. `Objet` = nom dans ton inventaire (la liste propose tes objets),
  `Nom affiché` facultatif, `Rayon` = catégorie (tape un nouveau nom pour créer un rayon), `Prix`, `Max / achat`.
- **↑** pour réordonner, **✕** pour retirer, **Prix ±10 %** pour tout ajuster, **Ajouter les produits de base**
  (liste de `Config.Market.defaultItems` dans config.lua).
- Les images viennent d'ox_inventory (`web/images/<objet>.png`) ; sans image, une icône du rayon s'affiche.
- Inventaire plein : le joueur est remboursé automatiquement de ce qu'il n'a pas pu recevoir.

## 4. Magasins d'illenium-appearance (« [E] Barber - Price: $100 »…)
Au démarrage, le menu retire tout seul les magasins d'illenium (coiffeurs, vêtements, tatoueurs, chirurgiens),
leurs icônes et leurs PNJ, en gardant une sauvegarde (`shared/config.lua.admin_menu.bak`).
**Redémarre le serveur une fois** après la première installation.

Console serveur :
| Commande | Effet |
|---|---|
| `magasins status` | état actuel |
| `magasins off` | retire les magasins |
| `magasins on` | remet le fichier d'origine (mets aussi `Config.OtherShops.enabled = false`) |

Réglages : `Config.OtherShops` dans config.lua (`jobRooms = true` retire aussi les vestiaires des métiers).

## 5. Zone pour parler à un PNJ
Pour **n'importe quel PNJ avec un rôle** (supérette, tatoueur, coiffeur, vêtements, garage…) :
F10 › Éditeur › PNJ › « Modifier son rôle » › section **📍 Zone pour lui parler**.

| Choix | Effet |
|---|---|
| 🧍 Près du PNJ | comme avant : à moins de 2,2 m |
| ⭕ Cercle autour | rayon réglable de 1 à 40 m (et 3 m au-dessus / en dessous) |
| ✏️ Zone dessinée | forme libre, comme les safe zones : le menu se ferme, tu vises le sol et poses les coins un par un, puis tu termines |

- La zone dessinée est enregistrée dès que tu la termines. Enregistre tes autres réglages du PNJ **avant** de la dessiner.
  Elle doit avoir entre 3 et 60 coins, tous à moins de 80 m du PNJ. Pour un PNJ que tu viens de poser,
  enregistre-le une première fois avant de dessiner.
- Pour **voir les zones** en jeu : onglet Zones › « Afficher les limites (staff) ». Les zones des PNJ apparaissent en **or**
  avec le nom du PNJ.
- Le serveur vérifie aussi la zone (avec 2 m de marge) : impossible d'ouvrir un magasin de loin.
