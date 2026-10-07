# Objet « permis » : Permis de conduire Elyzea

Ce dossier contient tout ce qu'il faut pour ajouter l'objet **`permis`** dans ton inventaire (ox_inventory).
Le joueur le reçoit automatiquement quand il **réussit son examen de conduite** à l'auto-école (ressource `elyzea_permis`).

| Fichier | À quoi il sert |
|---|---|
| `permis.png` | L'icône de l'objet dans l'inventaire (256 × 256, fond transparent). |
| `items.lua` | La déclaration de l'objet à coller dans ox_inventory. |
| `apercu_permis.png` | L'aperçu du permis tel qu'il s'affiche en jeu (la photo est celle du personnage). |

---

## Installation (3 étapes)

### 1. Déclarer l'objet
Ouvre `ox_inventory/data/items.lua` et colle ce bloc **à l'intérieur** de `return { ... }`
(par exemple juste avant la dernière accolade `}`) :

```lua
['permis'] = {
    label = 'Permis de conduire',
    weight = 10,
    stack = false,
    close = true,
    description = 'Permis de conduire Elyzea. Utilise-le pour le regarder ou le montrer.',
    client = { export = 'elyzea_permis.useLicense' },
},
```

- `stack = false` : chaque permis est unique (il porte le nom, la date de naissance, le numéro et les catégories du joueur).
- `client.export` : quand le joueur **utilise** l'objet, le permis s'affiche avec sa photo et le bouton
  **« Montrer à la personne la plus proche »**.

### 2. Ajouter l'icône
Copie `permis.png` dans :

```
ox_inventory/web/images/permis.png
```

Le nom du fichier doit être exactement le même que celui de l'objet : `permis`.

### 3. Redémarrer
Dans la console du serveur :

```
restart ox_inventory
ensure elyzea_permis
```

(ou redémarre entièrement le serveur).

---

## Comment le joueur obtient son permis
1. Il parle au PNJ **Auto-école** (Menu admin › Éditeur de map › PNJ › 🪪 Auto-école).
2. Il réussit le **code**, puis l'**examen de conduite**.
3. L'objet **`permis`** arrive dans son inventaire. S'il passe un autre permis plus tard (A, B ou C),
   le **même** permis est mis à jour avec la nouvelle catégorie : il n'en reçoit pas un deuxième.

## Ce qu'affiche le permis
- Le logo Elyzea, « PERMIS DE CONDUIRE · État de San Andreas · Elyzea » ;
- la **photo du personnage** (prise en jeu au moment où on le regarde) ;
- nom, prénom, date de naissance, sexe, numéro de permis ;
- les catégories **A** (moto), **B** (voiture), **C** (poids lourd), allumées avec leur date d'obtention.

## Vérifier que tout marche
- Donne-toi l'objet pour tester l'icône : `/giveitem [ton id] permis 1` (il sera vierge : le vrai permis, avec ton nom
  et tes catégories, s'obtient en réussissant l'examen).
- Si l'icône ne s'affiche pas : vérifie le nom du fichier (`permis.png`, en minuscules) et vide le cache de ton jeu.
- Si rien ne se passe quand on utilise l'objet : vérifie que la ressource `elyzea_permis` est bien démarrée.
