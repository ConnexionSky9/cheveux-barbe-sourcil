# bank_heist — Braquage de banque

> **État : écrit et vérifié hors jeu uniquement.**
>
> Vérifications faites :
> - syntaxe Lua 5.4 (compilateur réel) et JavaScript ;
> - les 5 mini-jeux et les 3 tentatives exécutés avec le vrai code serveur (réponses justes et fausses, ordinateur grillé, C4 autorisée ensuite) ;
> - validation des réglages et aller-retour « Enregistrer » depuis l'onglet admin ;
> - interfaces affichées dans un navigateur avec des données fictives.
>
> **Rien n'a été testé sur un serveur FiveM.** Suivez « Tests à faire en jeu ».

## Déroulement

1. **Marchand** (PNJ, ALT → « Acheter du matériel ») : ordinateur de piratage, sac de braqueur, C4 (si la vente est activée). Prix réglables, paiement vérifié par le serveur.
2. **« Braquer la banque »** (ALT au point de départ). Le serveur vérifie :
   - banque active, pas de braquage en cours, pas trop de braquages simultanés ;
   - délai de la banque et délai global écoulés, heures autorisées ;
   - policiers en service ;
   - nombre de braqueurs (les joueurs proches du point de départ, hors police) ;
   - matériel réuni par les braqueurs.

   Ensuite il enregistre la session et les braqueurs, met la banque en délai et **alerte la police tout de suite, une seule fois**.
3. **Menacer l'employé** (ALT sur le PNJ, arme en main) : mains levées, puis à genoux pour le reste du braquage.
4. **Pirater le coffre** (ALT au coffre) : l'ordinateur sort (animation + objet en main) et un mini-jeu **tiré au sort** s'ouvre parmi :
   - séquence de symboles ;
   - connexion de circuits ;
   - déchiffrement de code ;
   - synchronisation ;
   - décryptage de données.

   Chaque mini-jeu a sa durée et sa difficulté. **3 tentatives par ordinateur**, enregistrées sur le serveur par numéro de série. Le nom de l'objet affiche « (2/3) » ou « (grillé) ».
5. **C4** (ALT au coffre) : possible **seulement quand l'ordinateur a grillé ses tentatives** sur ce coffre.
   - Pose : animation, puis la charge est consommée.
   - Bips, puis explosion modérée (sans dégâts) synchronisée pour tous.
   - Le coffre s'ouvre.
6. **Coffre ouvert** : la porte tourne et des chariots de billets apparaissent. Le butin est tiré **une seule fois**, avec un bonus ou un malus éventuel. Il est commun à tous les braqueurs.
7. **« Ramasser les billets »** (ALT sur un chariot) : animation, puis le serveur verse une tranche par seconde dans le sac.
   - Au premier ramassage, le **sac de braqueur** de l'inventaire devient un sac porté sur le dos (même système que la bijouterie).
   - Une fenêtre affiche le montant transporté, la capacité et le pourcentage.
8. **Transport** : le sac reste sur le dos, à pied et en véhicule. **E** le pose au sol, **ALT** près d'un sac le ramasse : le contenu est inchangé et le porteur change. Le sac ne s'ouvre pas.
9. **Encaissement** : **E** dans un point de dépôt, à pied (ou en passager si c'est autorisé). Le sac est retiré et l'argent versé (liquide, banque ou argent sale).

## Systèmes réutilisés (rien d'inventé)

| Besoin | Utilisé |
|---|---|
| Objets, numéro de série de l'ordinateur | `elyzea_inventory` : `AddItem` (métadonnées), `RemoveItem`, `CanCarryItem`, `GetItemCount`, `Search(…'slots'…)`, `SetMetadata` |
| Sac porté, posé, ramassé | `jewelry_heist`. Son système de sac gagne un type « sac de billets » (capacité, ne s'ouvre pas) et des exports : `CreateCarriedBag`, `GetCarriedBag`, `AddBagMoney`, `CashOutCarriedBag`, `GetBagInfo` |
| Argent | `elyzea_core` : `AddMoney`, `RemoveMoney`, `GetMoney`. Ou objet (`black_money`) |
| Police | `elyzea_police` : `SendAlert('robbery', …)`, `GetOnDutyCount`, `IsOnDuty`. Repli : alerte interne aux métiers réglés |
| Menu ALT | menu ALT d'`elyzea_police` (fournisseur `bank_heist`) ; sans lui, menu ALT autonome |
| Notifications | `elyzea_core:Notify` |
| Staff | `admin_menu:HasPermission(src, 'bankheist_manage')` (repli : ACE `bank_heist.admin`) |
| Base de données | oxmysql via `@elyzea_core/lib/MySQL.lua` |

## Arborescence

```
bank_heist/
├─ fxmanifest.lua · config.lua (défauts) · shared/util.lua
├─ adapters/  notifications, permissions, inventory, money, police, bag (sac de jewelry_heist)
├─ server/
│  ├─ main.lua      tables, journal, limite de fréquence, verrous, dispatcher
│  ├─ settings.lua  validation et persistance des réglages, copie publique
│  ├─ laptop.lua    numéros de série et tentatives des ordinateurs
│  ├─ shop.lua      marchand
│  ├─ heist.lua     sessions (machine à états), lancement, menace, C4, ouverture, fin, délais persistants
│  ├─ hack.lua      5 mini-jeux : énigmes générées et réponses vérifiées par le serveur
│  ├─ loot.lua      collecte par tranches, objets bonus, encaissement
│  └─ admin.lua     AdminData / AdminAction
├─ client/  main, peds (employé, marchand), bank (porte, chariots, C4, explosion), hack, loot (collecte, sac, dépôt), alt
├─ html/    index.html, style.css, app.js (marchand, menu, ordinateur, sac), games.js (5 mini-jeux), img/
└─ sql/install.sql
```

## Fichiers modifiés ailleurs

- **elyzea_inventory**
  - `shared/items.lua` : objets `bank_laptop` (non empilable, numéro de série), `bank_bag` et `bank_c4`.
  - `html/img/` : `bank_laptop.png`, `bank_bag.png`, `bank_c4.png`.
- **jewelry_heist** (sac de billets)
  - `server/bags.lua` : type et capacité, nouveaux exports, refus d'ouvrir un sac de billets.
  - `server/main.lua` : ajout automatique des colonnes `kind` et `capacity`.
  - `client/alt.lua` : pas de « Ouvrir » sur un sac de billets.
  - `client/bag.lua` : E ne pose pas le sac dans un point de dépôt.
  - `locales/` : nouveau message.
- **elyzea_police**
  - `client/alt.lua` : fournisseur `bank_heist`.
  - `html/app.js` : icônes.
- **admin_menu**
  - `config.lua` : permission `bankheist_manage`.
  - `server/main.lua` : migration `v47` (SuperAdmin).
  - `server/bankheist.lua`, `html/bankheist.js` : onglet.
  - `html/index.html`, `html/script.js`, `fxmanifest.lua` : déclaration de l'onglet.
- **server.cfg** : `ensure bank_heist` après `ensure jewelry_heist`.

## Icônes

Dessinées par programme (canvas), puis exportées en PNG 256 × 256 avec fond transparent :
- ordinateur à écran de piratage ;
- sac noir rempli de billets ;
- pains de C4 avec fils et minuteur.

Ce ne sont pas des rendus photoréalistes. Pour les remplacer, gardez les mêmes noms de fichiers.

## Installation

1. Copier `bank_heist` et mettre à jour `jewelry_heist`, `elyzea_inventory`, `elyzea_police`, `admin_menu` et `server.cfg`.
2. Redémarrer le serveur. Les tables sont créées automatiquement (sinon `sql/install.sql`).
3. admin_menu › Illégal › **Braquage de banque** :
   - **B. Banques** : pour la Fleeca de Legion Square, les positions par défaut sont celles de l'intérieur d'origine. **Avec cfx-fm-fleeca-banks-v2, replacez chaque point** avec « Placer ici » :
     - le départ ;
     - l'employé ;
     - le coffre ;
     - devant la porte ;
     - les chariots.
   - **D. Marchands**, **H. Dépôts** : placez-les.
   - **E. Objets et prix**, **F. Piratage**, **G. Coffre et butin** : prix, tentatives, mini-jeux, butin, capacité du sac.
4. **Porte du coffre** : objet de la carte cherché autour du point « porte ».
   - Modèle par défaut : `v_ilev_gb_vaultdr` (porte Fleeca d'origine).
   - Avec un intérieur modifié, renseignez le modèle de sa porte, ou désactivez « Porte du coffre animée ».

## Sécurité

- **Le client n'envoie que des identifiants et ses réponses aux mini-jeux.**
  - Il n'envoie jamais un montant, un état ni un « réussi ».
  - Les positions sont lues par le serveur.
- **Énigmes générées par le serveur** et réponses vérifiées par lui :
  - code : chaque essai est vérifié par le serveur ;
  - synchronisation : les temps sont recalculés et doivent tenir dans le temps réellement écoulé.
- **Tentatives** :
  - consommées au lancement du mini-jeu : quitter ou se déconnecter = échec ;
  - liées au numéro de série et enregistrées en base : changer l'objet de place ou de main ne les remet pas à zéro ;
  - un ordinateur au numéro inconnu est considéré grillé.
- **Une seule action sur un coffre à la fois** (verrou).
- **Butin** :
  - tiré une seule fois et partagé ;
  - jamais dépassé ;
  - capacité du sac respectée ;
  - collecte comptée par le serveur et arrêtée si on s'éloigne ou tombe.
- **C4** : vérifiée avant la pose, consommée seulement à la pose effective, ouverture unique.
- **Encaissement** :
  - le sac est retiré avant le paiement ;
  - si le paiement échoue, le sac est rendu avec son contenu exact ;
  - impossible en conducteur ou hors d'un point de dépôt.
- **Délais par banque et délai global** enregistrés en base. Un redémarrage termine les braquages en cours sans rien redistribuer, et la banque reste en délai. Les sacs remplis sont conservés par jewelry_heist.
- **Abandon** : session terminée si plus aucun braqueur n'est dans la banque pendant N minutes.
- **Journal `bh_logs`** : braquages, piratage, collecte, encaissements, achats, staff, anomalies.

## Tests à faire en jeu (aucun n'a été fait)

1. Démarrage sans erreur, tables `bh_*` créées. L'onglet est visible avec `bankheist_manage`, invisible sans.
2. **Marchand** : achats (argent débité, objet reçu, l'ordinateur s'appelle « (3/3) »), possession maximale, fonds insuffisants, policier refusé.
3. **Lancement refusé** : sans matériel, pas assez de policiers, pas assez de braqueurs, hors des heures, pendant le délai.
4. **Lancement accepté** : alerte police immédiate et unique (tablette police, position, heure).
5. **Menace** sans arme (refusée), puis avec arme : l'employé lève les mains puis se met à genoux, et tout le monde le voit.
6. **Piratage** :
   - un deuxième joueur ne peut pas pirater en même temps ;
   - échouer : tentative perdue, « (2/3) » ;
   - quitter : tentative perdue ;
   - donner l'ordinateur à un autre : toujours « (2/3) » ;
   - réussir : le coffre s'ouvre une seule fois ;
   - essayer chacun des 5 mini-jeux (activer un seul jeu dans l'onglet F pour forcer).
7. **C4** :
   - refusée tant que l'ordinateur a des tentatives ;
   - après 3 échecs : pose, bips, explosion sans dégâts, ouverture ;
   - pose interrompue : charge non consommée.
8. **Coffre** : la porte tourne (sinon réglez le modèle ou la rotation), les chariots apparaissent, se vident, puis le coffre se referme après la durée réglée.
9. **Collecte** :
   - le sac apparaît sur le dos, la fenêtre de montant s'affiche ;
   - la capacité est respectée, la réserve est partagée entre deux braqueurs, le total n'est jamais dépassé ;
   - s'éloigner arrête la collecte.
10. **Transfert** : E pour poser, un autre joueur ramasse avec ALT, montant identique ; « Ouvrir » n'apparaît pas.
11. **Encaissement** : E au dépôt (argent versé, sac retiré). Refusé en conducteur et hors dépôt. Un second encaissement est impossible.
12. **Redémarrages** :
    - de `bank_heist` pendant un braquage : la banque reste en délai, rien n'est redistribué ;
    - de `jewelry_heist` avec un sac rempli : le sac est conservé.
13. **Journal** (onglet K) : chaque étape est tracée.

## Limites connues

- **Non testé en jeu.**
- Les positions par défaut correspondent à l'intérieur d'origine de la Fleeca de Legion Square. L'intérieur `cfx-fm-fleeca-banks-v2` peut les décaler : replacez les points.
- La porte du coffre tourne localement chez chaque joueur (objet de la carte), à partir de l'état synchronisé par le serveur.
- Le mini-jeu « séquence » montre la séquence à l'écran : il teste la mémoire. Le serveur vérifie la réponse et le temps, mais un joueur qui note la séquence n'est pas bloqué.
- « Synchronisation » : le serveur recalcule les positions à partir des temps annoncés et vérifie qu'ils tiennent dans le temps réellement écoulé. Un client modifié pourrait encore annoncer de « bons » temps.
- Animations par défaut : animations GTA connues. Si l'une ne charge pas, l'action continue sans elle (l'employé a un scénario de secours).
- Les icônes sont dessinées par programme (voir plus haut).
