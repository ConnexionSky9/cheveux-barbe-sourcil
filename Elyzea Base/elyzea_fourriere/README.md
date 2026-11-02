# Elyzea Fourrière

Trois fourrières indépendantes, des garages spécialisés et le paiement en dollars ou en pesos.

| Fourrière | Véhicules | Commerce (monnaie) dans `elyzea_change/config.lua` |
|---|---|---|
| Terrestre | voitures, motos | `FourriereVoiture` |
| Aérienne | hélicoptères, avions | `FourriereAvion` |
| Maritime | bateaux | `FourriereBateau` |

## Fonctionnement

### Mise en fourrière
- **Par la police** (ALT › fourrière) : le serveur relève la catégorie et l'état du véhicule avant de le supprimer.
- **Épave** : un véhicule possédé et sorti qui est détruit (explosé, ou moteur / carrosserie à zéro) part tout seul à la bonne fourrière.
  - Un joueur proche le signale.
  - Le serveur vérifie lui-même l'état, le propriétaire et que le véhicule était sorti.
  - L'épave disparaît du monde après 20 s.

### Récupération (PNJ « Fourrière »)
Le joueur voit **ses** véhicules avec :
- le modèle, la plaque et le type ;
- le prix, dans la monnaie choisie ;
- l'état (récupérable ou complètement détruit) ;
- le motif ;
- la disponibilité, et pour une réparation, le temps restant.

Ce que l'interface empêche :
- les véhicules d'une autre fourrière sont grisés, avec la fourrière où aller ;
- le bouton de paiement est désactivé s'il manque de l'argent.

**Véhicule non détruit**
1. Le serveur cherche une place de sortie libre **de son type**, sinon une place « tous types ».
2. Si la place est occupée, un message demande de la libérer et de réessayer. Rien n'est débité.
3. Le joueur paie.
4. Le véhicule apparaît aussitôt sur la place, avec sa plaque, ses couleurs, ses pièces et son état enregistré. Le joueur est mis au volant et reçoit les clés.

**Véhicule complètement détruit**
1. Le joueur paie la réparation.
2. Le véhicule passe « en réparation » pendant 60 min (`Config.RepairMinutes`).
3. La date de fin est enregistrée **en base**. Elle continue pendant les déconnexions et les redémarrages du serveur.
4. Le serveur vérifie les réparations finies toutes les 60 s, au démarrage, à la connexion du joueur et à l'ouverture d'une fourrière.
5. À la fin, le véhicule est réparé à 100 % : moteur, carrosserie, réservoir, pneus, vitres, portes et déformations. Il est aussi lavé et le plein est fait.
6. Il revient au garage (`Config.ReturnGarage`), puis le joueur est prévenu (s'il est en ligne, sinon à sa connexion).

### Sécurité
Tout est vérifié **par le serveur** :
- le propriétaire (citizenid) et la distance au PNJ ;
- la catégorie et la fourrière ;
- l'état : en fourrière, en réparation ou sorti ;
- la place libre ;
- le moyen de paiement accepté et le solde.

Protections supplémentaires :
- **Double paiement** : le passage « fourrière → sorti / réparation » est verrouillé en base. Un seul paiement peut réussir ; un doublon est remboursé.
- **Catégorie inconnue** (ancien véhicule jamais relevé) : l'interface la propose d'après le modèle. Le serveur l'enregistre seulement si elle manquait, puis la **revérifie sur le véhicule créé**. Si elle est fausse, le véhicule est supprimé, le joueur remboursé, la catégorie corrigée, et le joueur renvoyé vers la bonne fourrière.
- **Modèle absent du serveur** : le véhicule payé est rangé au garage au lieu d'être perdu.

### Argent
Le prix est réglé dans `Config.Prices`, en dollars, par catégorie, avec un prix « non détruit » et un prix « détruit ».

Pour la monnaie, le choix du commerce dans `elyzea_change` passe en premier :
- `Currency = 'money' | 'pesos'` ;
- `ForceCurrency = true` : la monnaie est imposée, sans choix pour le joueur ;
- si le commerce n'impose rien, le réglage « Dollars ou pesos » du PNJ s'applique.

Les pesos sont l'objet `pesos` du bureau de change, pas une deuxième monnaie. Le taux est `Config.Payment.PesosRate` (1 par défaut).

L'argent d'une mise en fourrière par la police va à la société `police` (`Config.Society`).

## Installation
1. Copie `elyzea_fourriere` dans tes ressources. Remplace aussi les ressources modifiées (voir le rapport de livraison).
2. Dans `server.cfg`, ajoute `ensure elyzea_fourriere` **après** `elyzea_garage`, `elyzea_change` et `admin_menu`.
3. Rien à importer. La ressource crée elle-même :
   - la colonne `player_vehicles.vclass` ;
   - la table `elyzea_fourriere`.
   
   `sql/install.sql` est fourni pour une installation à la main.
4. En jeu, ouvre admin_menu › Éditeur de map › PNJ. Pose un PNJ, active le rôle **🚧 Fourrière**, choisis terrestre, aérienne ou maritime, puis enregistre. Ensuite :
   - place les **places de sortie** par type (voiture, moto, hélico, avion, bateau, ou tous types) ;
   - pour un bateau, vise l'eau : le bateau est posé à la surface.
5. Garages spécialisés : rôle **🅿️ Garage public / aérien / maritime**, avec le champ « Véhicules gérés » réglé sur :
   - tous ;
   - voitures et motos ;
   - hélicoptères et avions ;
   - bateaux.

Les PNJ sont illimités et enregistrés comme tous les PNJ de l'éditeur, donc gardés après un redémarrage.

## États de `player_vehicles.state`
| Valeur | Sens |
|---|---|
| 0 | sorti |
| 1 | au garage |
| 2 | en fourrière |
| 3 | garage d'une propriété (`elyzea_dynasty`) |
| **4** | **en réparation (nouveau)** |

## Exports serveur
- `exports.elyzea_fourriere:Impound(veh, plate, reason)` : met en fourrière en lisant la catégorie et l'état sur le véhicule.
- `exports.elyzea_fourriere:ImpoundPlate(plate, reason, destroyed)` : sans véhicule.
- `exports.elyzea_fourriere:OpenFor(src, { kind, name, spots, npc, currency, currencyForce })` : appelé par admin_menu.
- `exports.elyzea_fourriere:SaveVehicleClass(veh)` et `ClassOfEntity(veh)`.

## Tests hors jeu
Avec MariaDB, `lupa` et `pymysql` :
```
python3 tests/run_sim.py <socket MariaDB>
```
Ce test lance les vrais fichiers serveur (fourrière, `elyzea_change`, ShopPay d'admin_menu, `elyzea_garage`) sur une vraie base. Il simule aussi un redémarrage.

Avec Playwright :
```
NODE_PATH=$(npm root -g) node tests/ui.cjs
```
Ce test vérifie l'interface de la fourrière.
