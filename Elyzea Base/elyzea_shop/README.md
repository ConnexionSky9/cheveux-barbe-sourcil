# elyzea_shop — Boutique Elyzea RP 100 % en jeu

Boutique NUI ouverte **dans GTA V** (touche **F7** par défaut, ou `/boutique`). On y trouve :

- l'accueil ;
- les catégories VIP, Elyzea Coins et Véhicules premium ;
- une fiche par produit ;
- des fenêtres de confirmation ;
- l'historique des achats et des coins ;
- le solde d'Elyzea Coins.

Les paiements en argent réel passent par **Tebex**, avec l'intégration **officielle** intégrée à FiveM (`sv_tebexSecret`). Il n'y a **aucun site internet personnalisé**.

## 1. Ce qui a été trouvé sur le serveur (analyse)

| Point | Constat |
|---|---|
| Framework | **ESX n'est pas installé.** Le serveur tourne sur **elyzea_core**, un core maison de type QBCore (personnages `citizenid`, argent `cash` / `bank`). La ressource gère **les deux** : `Config.Framework = 'auto'` détecte `es_extended`, sinon `elyzea_core`. |
| Base de données | **oxmysql n'est pas installé** : elyzea_core le remplace (exports `db_query`, `db_insert`, `db_update`, `db_transaction`). La ressource utilise oxmysql s'il est démarré, sinon elyzea_core. |
| Garage | **elyzea_garage**, table `player_vehicles` (`citizenid`, `plate`, `state = 1` = au garage). Sous ESX : `owned_vehicles`, configurable. |
| Inventaire | **elyzea_inventory** (`AddItem`, `CanCarryItem`). Sous ESX : ox_inventory s'il est présent, sinon l'inventaire ESX. |
| Permissions | Groupes ACE (`group.admin`…), plus `elyzea_core:HasPermission`. |
| Identité visuelle | Logo et couleurs Elyzea (écran de chargement) : noir encre, or champagne, bleu (légal), rouge (illégal). Polices Cinzel et Barlow Semi Condensed. |
| **Touche F7** | **Déjà utilisée par `elyzea_animaux`** (`Config.Keys.menu = 'F7'`). F7 est conservée par défaut comme demandé, mais elle ouvrirait les deux interfaces. **Changez l'une des deux** (`Config.Key` ici, ou dans `elyzea_animaux/config.lua`). Chaque joueur peut aussi la changer dans Paramètres › Raccourcis › FiveM. |

Aucune ressource existante n'a été modifiée, et aucune table existante n'est changée : la ressource ajoute seulement ses 5 tables `elyzea_shop_*`.

## 2. Comment marche un achat

```
Joueur (F7) ──► NUI : choisit « Elyzea Sapphire » ──► confirmation ──► le serveur renvoie le lien du paquet Tebex
          ──► le navigateur du joueur s'ouvre sur la boutique Tebex officielle (connexion Cfx.re + paiement)
Tebex (paiement confirmé) ──► exécute dans la CONSOLE du serveur :  elyzea_shop_deliver <transaction> <id Cfx.re> sapphire
Serveur ──► enregistre la livraison (une seule fois par transaction) ──► donne le produit
            (tout de suite si le joueur est connecté, sinon à sa prochaine connexion)
```

**Le paiement ne se fait pas dans la NUI.** Tebex n'a pas d'API documentée pour payer à l'intérieur de l'interface du jeu. La page de paiement est celle de Tebex et s'ouvre dans le navigateur, avec `invokeNative('openUrl')`, sans créer de site.

Si l'ouverture automatique ne fonctionne pas, la boutique affiche le lien avec un bouton **Copier**.

Un clic sur « Acheter » **n'accorde rien**. Seule la commande que Tebex exécute dans la console après paiement déclenche la livraison. Ces commandes sont **refusées si un joueur les tape**, même un admin : seule la console peut les lancer.

## 3. Installation

1. Copiez le dossier `elyzea_shop` dans `resources` (par exemple à côté des autres ressources Elyzea).
2. Importez `sql/install.sql` dans la base du serveur. C'est facultatif : la ressource crée aussi les tables manquantes au démarrage.
3. Ajoutez dans **server.cfg** :
   ```cfg
   # Tebex : clé fournie par Tebex (Integrations › Game Servers › Connect Game Server › Plugin)
   # À la fin du fichier, avec la commande telle quelle (jamais avec "sets" / "setr" : la clé deviendrait publique)
   sv_tebexSecret VOTRE_CLE_TEBEX

   # Boutique : après elyzea_core et elyzea_inventory (ou es_extended / oxmysql sous ESX)
   ensure elyzea_shop

   # Administrateurs de la boutique
   add_ace group.admin elyzea_shop.admin allow
   ```
   Si vous préférez garder la clé à part, mettez `sv_tebexSecret` dans `secrets.cfg`, qui est déjà chargé par votre server.cfg.
4. Réglez `config.lua` :
   - `Config.Tebex.storeUrl` (adresse de votre boutique Tebex) ;
   - la touche ;
   - les produits (textes, images, `tebexPackageId`, `coinsPrice`, récompenses).
5. Redémarrez le serveur. La console affiche :
   ```
   [elyzea_shop] prêt (framework : elyzea, base : ely)
   ```

## 4. Configuration Tebex (pas à pas)

1. Suivez le guide officiel : <https://docs.fivem.net/docs/server-manual/setting-up-a-tebex-store/>
   - création du compte et du projet ;
   - Integrations › Game Servers › **Connect Game Server › Plugin** ;
   - ajout de `sv_tebexSecret` ;
   - redémarrage du serveur.
2. Pour **chaque produit vendu en argent réel**, créez un **paquet** Tebex. Dans **Game Server Commands** du paquet :

   | Moment | Commande |
   |---|---|
   | **Achat** (commande exécutée à l'achat) | `elyzea_shop_deliver {transaction} {id} sapphire` |
   | **Expiration / retrait** (paquet à durée, abonnement, et selon les options de votre panneau Tebex : remboursement, opposition bancaire) | `elyzea_shop_revoke {transaction} {id} sapphire` |

   Les moments proposés (achat, expiration, renouvellement, remboursement…) dépendent de l'interface Tebex de votre paquet : mettez la commande `revoke` sur tous ceux qui doivent retirer le produit. Si votre panneau ne propose rien pour les remboursements, faites-le à la main : `elyzea_shop_revoke <transaction> <id Cfx.re> <clé>` dans la console, ou `/shopadmin`.

   - Remplacez `sapphire` par la **clé du produit** dans `config.lua` : `sapphire`, `royale`, `divinity`, `coins_1000`, etc.
   - **Ne cochez pas** « exiger que le joueur soit en ligne ». La ressource gère elle-même les joueurs hors ligne et livre à la connexion. La commande peut donc s'exécuter tout de suite.
   - Désactivez la **quantité** sur ces paquets : une commande correspond à un produit.
3. Reportez l'ID du paquet dans `config.lua` › `tebexPackageId`. C'est ce qui affiche le bouton « Acheter avec Tebex ».

### Variables Tebex : à vérifier avant d'ouvrir

- `{id}` est documentée par Tebex comme l'**identifiant principal du joueur** pour le jeu. Pour FiveM, c'est l'identifiant **Cfx.re**, le même que `fivem:XXXX` en jeu. La ressource accepte `XXXX` et `fivem:XXXX`.
- `{transaction}` est la référence de la transaction Tebex. Elle rend la livraison **idempotente** : une même transaction ne livre jamais deux fois.
- Je n'ai pas pu tester ces variables contre un vrai Tebex. Faites l'**achat test** de la section 9. Si un paramètre arrive vide ou différent, la commande est refusée et l'erreur s'affiche dans la console et dans `elyzea_shop_logs` (`tebex_bad_command`), avec les valeurs reçues.
- La documentation Tebex mentionne aussi `{hexid}` (identifiant Steam), et les forums parlent de `{sid}` (id serveur, joueur en ligne uniquement). **Ne les utilisez pas** : elles ne désignent pas de façon fiable le compte, et `{sid}` change à chaque connexion.

## 5. Produits et récompenses (`config.lua`)

Chaque produit a une **clé**, celle qui apparaît dans la commande Tebex, et les champs suivants :

- `label`, `description`, `image`, `perks` : textes et image affichés ;
- `displayPrice` : prix affiché, ou rien pour afficher « Prix affiché sur Tebex » ;
- `tebexPackageId` : paquet Tebex correspondant ;
- `coinsPrice` : prix en Elyzea Coins ;
- `durationDays` : durée du produit ;
- `rewards` : ce que le produit donne en jeu.

**Les prix et les avantages des grades Elyzea Sapphire, Royale et Divinity sont des emplacements à remplir** : rien n'a été inventé.

| Récompense | Effet | Joueur connecté requis | Retirée au remboursement / à l'expiration |
|---|---|---|---|
| `group` | Groupe ACE `group.<nom>`, et `exports.elyzea_shop:HasPerk(src, nom)` | non (appliqué à la connexion) | oui |
| `perk` | Avantage nommé pour vos scripts (`HasPerk`) | non | oui |
| `coins` | Crédit d'Elyzea Coins | non | oui, dans la limite du solde (`revokeOnRefund`) |
| `vehicle` | Véhicule au garage du personnage actif, avec plaque générée et clés | oui | oui (suppression par plaque) |
| `item` | Objet d'inventaire | oui | non : signalé dans les journaux |
| `money` | Argent de jeu (désactivé : `Config.Integrations.money`) | oui | non : signalé |
| `command` | Commande **prédéfinie** dans `Config.Commands` | selon la commande | si `revoke` est défini |

- **Durée** :
  - `durationDays` pose une date de fin sur les grades et avantages ;
  - un rachat **prolonge** à partir de la fin actuelle ;
  - une vérification chaque minute retire ce qui a expiré ;
  - pour un paquet Tebex à durée, la commande d'expiration Tebex retire aussi le grade, la première des deux qui arrive l'emporte.
- **Pour vos autres scripts** :
  - `exports.elyzea_shop:HasPerk(source, 'vip_sapphire')`
  - `exports.elyzea_shop:GetPerks(source)`
  - `exports.elyzea_shop:GetCoins(source)`
  - ou `IsPlayerAceAllowed(source, 'group.vip_sapphire')` / `IsPrincipalAceAllowed`.

## 6. Elyzea Coins

- Solde **par compte Cfx.re**, commun à tous les personnages, **séparé** de l'argent de jeu.
- Achat en coins dans la boutique :
  - le prix est lu dans `config.lua`, jamais envoyé par la NUI ;
  - un verrou par compte empêche deux opérations simultanées ;
  - le **débit, l'historique et la création de la livraison** se font dans **une seule transaction SQL**.
- Le solde est une colonne `UNSIGNED`. Un débit supérieur au solde provoque une erreur SQL qui **annule toute la transaction** : le solde ne peut pas devenir négatif. C'est vérifié par les tests sur MariaDB 10.11.
  - Ne mettez pas `NO_UNSIGNED_SUBTRACTION` dans le `sql_mode`. Ce n'est pas le réglage par défaut.
- Chaque opération a une référence unique : un même crédit Tebex reçu deux fois ne crédite qu'une fois.
- **Conformité** : avant de vendre des coins contre de l'argent réel, vérifiez que c'est autorisé par le [PLA Cfx.re](https://fivem.net/terms) et par la politique d'utilisation et les CGU de Tebex en vigueur. Le pack `coins_1000` est fourni **sans** `tebexPackageId` : il n'est pas vendu tant que vous ne l'activez pas vous-même. Les coins ne peuvent pas être échangés contre de l'argent réel, ni transférés entre joueurs.

## 7. Administration

Commande `/shopadmin`. Elle demande l'ACE `elyzea_shop.admin`, ou le groupe admin du framework ; elle marche aussi depuis la console.

| Commande | Effet |
|---|---|
| `/shopadmin status <transaction>` | État de la livraison d'une transaction Tebex (livrée, en attente, échouée + erreur) |
| `/shopadmin retry <n°>` | Relance une livraison échouée ou interrompue, après vérification en jeu |
| `/shopadmin cancel <n°>` | Annule une livraison en attente ou échouée |
| `/shopadmin give <id joueur \| fivem:ID> <clé>` | Donne un produit (geste commercial, journalisé) |
| `/shopadmin coins <id \| fivem:ID> <+/-montant> [raison]` | Ajuste les coins (débit refusé si le solde est insuffisant) |
| `/shopadmin balance <id \| fivem:ID>` | Solde |
| `/shopadmin pending` | Nombre de livraisons en attente ou échouées |

Le journal complet est dans la table `elyzea_shop_logs` : commandes Tebex reçues, erreurs, actions admin, achats en coins.

## 8. Fiabilité des livraisons

- **Idempotence** :
  - la clé unique (transaction, produit, action) empêche toute double livraison ;
  - les entitlements ont leur propre clé unique ;
  - les coins aussi (référence unique).
- Les récompenses d'un produit sont exécutées **une à une**, et la progression est enregistrée après chacune.
- **Arrêt du serveur en pleine livraison** : la livraison n'est **pas** refaite automatiquement. Elle passe « échouée » avec le message « interrompue ». Un admin vérifie puis fait `/shopadmin retry`.
- **Échec** (inventaire plein, personnage non chargé…) : nouvel essai toutes les 60 s tant que le joueur est connecté. Après 10 essais, la livraison est « échouée ».
- Les grades ACE sont réappliqués à chaque connexion et retirés à la déconnexion.

## 9. Procédure de test (à faire vous-même)

Je n'ai pas pu lancer un vrai serveur FiveM ni faire un vrai paiement Tebex. Voici les étapes manuelles.

1. **Ouverture**
   - F7 (ou `/boutique`) ouvre la boutique ;
   - Échap ferme une fenêtre de confirmation, puis la boutique ;
   - après fermeture, vérifiez que le joueur peut bouger et tirer normalement ;
   - en mourant boutique ouverte, elle doit se fermer.
2. **Commande Tebex simulée depuis la console**. C'est exactement ce que fera Tebex : remplacez l'id par le vôtre, visible avec `/shopadmin balance <votre id serveur>`.
   ```
   elyzea_shop_deliver test-001 VOTRE_ID_CFX sapphire
   elyzea_shop_deliver test-001 VOTRE_ID_CFX sapphire     (2e fois : « déjà traitée », rien de plus)
   shopadmin status test-001
   elyzea_shop_revoke test-001 VOTRE_ID_CFX sapphire
   ```
3. **Hors ligne** : déconnectez-vous, lancez `elyzea_shop_deliver test-002 VOTRE_ID_CFX vehicle_example` depuis la console, puis reconnectez-vous. Le véhicule doit arriver au garage dans les secondes qui suivent le chargement du personnage.
4. **Coins** :
   - `shopadmin coins fivem:VOTRE_ID_CFX 1000` ;
   - mettez `coinsPrice = 600` sur `vehicle_example` et achetez-le dans la boutique ;
   - le solde doit passer à 400, et un deuxième achat doit être refusé.
5. **Vrai paiement**, en mode test Tebex ou sur un paquet à petit prix :
   - achetez depuis la boutique ;
   - vérifiez la ligne `[elyzea_shop] Tebex grant …` dans la console, puis `shopadmin status <transaction>` ;
   - Tebex exécute les commandes environ une fois par minute.
6. **Remboursement** depuis le panneau Tebex : le grade et le véhicule doivent être retirés.

## 10. Tests réalisés (hors jeu)

- `python3 tests/run_sim.py elyzea` (puis `esx`) : **41/41** et **39/39**. Le test exécute les vrais fichiers Lua sur une vraie base MariaDB, avec les commandes Tebex simulées comme Tebex les envoie. Il couvre :
  - sécurité des commandes ;
  - joueur hors ligne ;
  - doublons ;
  - véhicule, grade, coins ;
  - achat en coins ;
  - garde SQL anti-solde négatif ;
  - échec puis nouvel essai ;
  - livraison interrompue ;
  - remboursement ;
  - expiration ;
  - administration.
- `node tests/nui.e2e.cjs` : **21/21**. L'interface est testée dans Chromium : navigation, confirmations, ouverture de Tebex, refus du serveur, historique, texte jamais interprété comme du HTML, Échap, rendu en 1280×720.
- Ces tests ont trouvé et fait corriger deux défauts :
  - un paramètre SQL `nil` faisait décaler les valeurs ;
  - le bouton Historique était caché quand le contenu était long.

## 11. Limites connues

- **Paiement dans le navigateur, pas dans la NUI** : c'est une limite de Tebex, qui n'a pas de paiement intégré documenté pour FiveM. Le joueur doit se connecter à Tebex avec le **même compte Cfx.re** qu'en jeu.
- **Délai** : l'intégration FiveM de Tebex récupère les commandes environ toutes les minutes.
- **Variables `{transaction}` / `{id}`** : à confirmer par un achat test (voir section 4).
- Les **objets** et l'**argent de jeu** ne sont pas retirés automatiquement après un remboursement. Ils sont signalés dans `elyzea_shop_logs`.
- Les **images** fournies sont des visuels de départ : remplacez-les dans `html/assets/products/` (format webp conseillé).
- La boutique en jeu n'a pas de panier : on achète un produit à la fois.
- `boutique/` (à la racine du dépôt) contient une autre version **avec site web**. **N'utilisez qu'une des deux** : `elyzea_shop` est celle demandée ici, sans site.
