# jewelry_heist — Braquage de bijouterie

> **État : écrit et vérifié hors jeu uniquement.**
> - Syntaxe Lua 5.4 (compilateur réel) et JavaScript.
> - Validation des réglages exécutée avec le vrai code Lua : défauts, puis aller-retour « Enregistrer » depuis l'onglet admin.
> - Interfaces affichées dans un navigateur avec des données fictives.
>
> **Rien n'a été testé sur un serveur FiveM.** Suivez la liste « Tests à faire en jeu » avant l'ouverture.

## Ce que fait la ressource

- **Bijoutier (PNJ)**, menu ALT :
  - « Acheter des bijoux » et « Vendre des bijoux » (vente normale, réglable) ;
  - « Braquer la bijouterie » (arme autorisée en main).
- **Braquage**, contrôlé par le serveur :
  1. Le serveur vérifie les conditions : distance, arme, policiers en service, délais, disponibilité, pas de braquage en cours, pas de sac déjà porté.
  2. Il tire le butin au sort et envoie l'alerte police.
  3. Le PNJ panique, puis remplit un sac (sac en main) pendant la durée réglée.
  4. Après le délai de remise, il pose le sac sur le comptoir.
  5. Le braqueur ramasse le sac (ALT).
- **Sac** :
  - porté au dos, à pied et en véhicule ;
  - déposé avec **E** (à pied) ;
  - au sol, ALT donne « Ramasser le sac » / « Ouvrir le sac » ;
  - l'ouverture montre le contenu réel avec les icônes : on prend tout ou ligne par ligne ;
  - un policier en service peut « Saisir le contenu ».
- **5 pierres** : `diamond`, `ruby`, `sapphire`, `emerald`, `amethyst`. Ce sont de vrais objets d'inventaire avec leurs icônes PNG.
- **Racheteurs (PNJ)** :
  - rachètent les pierres acceptées, à leur prix, avec une quantité choisie ;
  - le total est recalculé par le serveur.
- **Alerte police** dès le début du braquage, avec :
  - le titre « Braquage de bijouterie en cours » ;
  - le nom et l'identifiant de la bijouterie ;
  - les coordonnées GPS ;
  - l'heure.
- **Onglet admin_menu « Braquage bijouterie »** (catégorie Illégal, permission `heist_manage`) : tout se règle en jeu, sans redémarrage.

## Ressources réutilisées (aucun export inventé)

| Besoin | Utilisé |
|---|---|
| Objets | `elyzea_inventory` : `AddItem`, `RemoveItem`, `CanCarryItem`, `GetItemCount`, `Items` |
| Argent | `elyzea_core` : `AddMoney`, `RemoveMoney`, `GetMoney` (`cash` / `bank`) ou objet (`black_money`) |
| Joueurs | `elyzea_core` : `GetCitizenId`, `GetCharName`, `GetSourceByCitizenId`, `GetPlayerData`, événement `elyzea:server:playerLoaded` |
| Notifications | `elyzea_core:Notify` |
| Police | `elyzea_police` : `GetOnDutyCount`, `IsOnDuty`, `SendAlert('robbery', …)`. Repli : métiers réglés et `job.onduty` |
| Menu ALT | menu ALT d'`elyzea_police`, avec `jewelry_heist` ajouté comme fournisseur. Sans elyzea_police : menu ALT autonome |
| Staff | `admin_menu:HasPermission(src, 'heist_manage')`. Repli : ACE `jewelry_heist.admin` |
| Base de données | oxmysql via `@elyzea_core/lib/MySQL.lua`. Tables `jh_settings`, `jh_bags`, `jh_logs` créées automatiquement |

Les points d'adaptation sont isolés dans `adapters/` :

- `inventory.lua`
- `money.lua`
- `permissions.lua`
- `police.lua`
- `dispatch.lua`
- `notifications.lua`

## Arborescence

```
jewelry_heist/
├─ fxmanifest.lua
├─ config.lua              valeurs par défaut (le staff les modifie en jeu)
├─ locales/fr.lua, en.lua  messages
├─ shared/util.lua         copie, fusion, traduction
├─ adapters/               inventaire, argent, permissions, police, dispatch, notifications
├─ server/
│  ├─ main.lua             tables, journal, limites de fréquence, verrous, dispatcher
│  ├─ settings.lua         validation complète, persistance, copie publique pour les clients
│  ├─ heist.lua            braquage (étapes, butin, alerte, annulations)
│  ├─ bags.lua             sacs (porter, déposer, ouvrir, transférer, saisir, mort, déconnexion, redémarrage, nettoyage)
│  ├─ shops.lua            vente normale au bijoutier et racheteurs
│  └─ admin.lua            AdminData / AdminAction pour admin_menu
├─ client/
│  ├─ main.lua             requêtes, NUI, animations, utilitaires
│  ├─ peds.lua             PNJ et blips, animations du bijoutier pendant le braquage
│  ├─ heist.lua            barre de progression du braqueur
│  ├─ bag.lua              sacs au sol, sac porté (objet au dos ou sac de tenue), touche E
│  ├─ alt.lua              fournisseur du menu ALT et menu autonome
│  └─ police.lua           alerte interne (blip, zone, notification)
├─ html/                   index.html, style.css, app.js, img/*.png (copie de secours des icônes)
└─ sql/install.sql
```

## Fichiers modifiés dans les autres ressources

### elyzea_inventory

- `shared/items.lua` : définition des 5 objets.

  | Objet | Nom | Poids | Empilable | Image |
  |---|---|---|---|---|
  | `diamond` | Diamant | 20 g | oui | `diamond.png` |
  | `ruby` | Rubis | 20 g | oui | `ruby.png` |
  | `sapphire` | Saphir | 20 g | oui | `sapphire.png` |
  | `emerald` | Émeraude | 20 g | oui | `emerald.png` |
  | `amethyst` | Améthyste | 20 g | oui | `amethyst.png` |

  L'entrée `diamond` remplace l'ancienne « Diamond » de `data/items.lua`. Ce fichier a la priorité et le nom de l'objet est inchangé.
- `html/img/diamond.png`, `ruby.png`, `sapphire.png`, `emerald.png`, `amethyst.png` : PNG 256 × 256, fond transparent.

### elyzea_police

- `client/alt.lua` : `jewelry_heist` est ajouté comme fournisseur du menu ALT, avec ses propres cibles (PNJ, sac proche).
- `html/app.js` : icônes des nouvelles actions.

### admin_menu

- `config.lua` : nouvelle permission `heist_manage`, donnée au SuperAdmin. Le Fondateur a tout.
- `server/main.lua` : migration `v46`.
- `server/jewelry.lua`, `html/jewelry.js` : le nouvel onglet.
- `html/index.html`, `html/script.js`, `fxmanifest.lua` : déclaration de l'onglet.

### server.cfg

- `ensure jewelry_heist`, après `elyzea_concess`.

## Icônes

Les icônes ont été dessinées par programme : facettes, reflets, ombre, rendu en canvas puis exportées en PNG avec canal alpha. Ce ne sont pas des rendus photoréalistes. Pour les remplacer, gardez le même nom de fichier dans `elyzea_inventory/html/img/` (et `jewelry_heist/html/img/`).

## Installation

1. Copier `jewelry_heist` dans les ressources, et mettre à jour `elyzea_inventory`, `elyzea_police`, `admin_menu` et `server.cfg`.
2. Redémarrer le serveur. Les tables sont créées automatiquement (sinon : `sql/install.sql`).
3. admin_menu › Illégal › **Braquage bijouterie** :
   - **B. Bijouteries** : placez-vous derrière le comptoir de Vangelico puis « Placer le PNJ ici », éventuellement « Placer le sac ici », puis **Enregistrer**. Une position par défaut est déjà proposée pour Vangelico.
   - **I. Racheteurs** : placez le receleur.
   - **F. Bijoux** : prix, quantités, chances. **C. Conditions** : armes, policiers, délais.
4. « Tester le braquage (staff) » lance un braquage réel sans arme, sans policiers, sans délai et sans alerte police (tracé « TEST STAFF »).

Le menu d'interaction s'ouvre en maintenant **ALT** puis en cliquant sur le PNJ, ou n'importe où près d'un sac au sol.

## Sécurité

- **Le client n'envoie que des identifiants.** Il n'envoie jamais de prix, de montant, de contenu ou de position. Les positions sont lues par le serveur.
- **Missions et sacs à identifiant unique :**
  - les étapes sont chronométrées par le serveur ;
  - le butin est tiré par le serveur ;
  - un seul braquage par bijouterie et par braqueur.
- **Contenu d'un sac :**
  - il n'existe qu'à un seul endroit ;
  - il est enregistré en base après chaque changement ;
  - il est restauré après redémarrage.
- **Transferts :**
  - un verrou par sac ;
  - un seul joueur « regarde » un sac à la fois ;
  - seul ce que l'inventaire ou le compte a réellement accepté est retiré du sac.
- **Ventes :**
  - les objets sont retirés avant le paiement, et rendus si le paiement échoue ;
  - pour un achat, l'argent est retiré avant l'objet, et rendu si l'objet ne peut pas être donné ;
  - un verrou par joueur.
- **Limite de fréquence** par joueur.
- **Journal `jh_logs`** : braquages, sacs, ventes, staff et anomalies, visible dans l'onglet J.

## Tests à faire en jeu (aucun n'a été fait)

1. Démarrage sans erreur ; tables `jh_*` créées ; onglet visible avec `heist_manage`, invisible sans.
2. **Objets :**
   - `/giveitem` (ou le menu admin) de `diamond`… `amethyst` ;
   - les icônes s'affichent dans l'inventaire.
3. **Bijouterie :** placer le PNJ, enregistrer, redémarrer la ressource. Le PNJ et les réglages sont toujours là.
4. **Menu ALT** sur le bijoutier : achat et vente (argent débité ou crédité, objets reçus ou retirés).
5. **Refus du braquage :**
   - sans arme ;
   - avec une arme non cochée ;
   - avec moins de policiers que le minimum ;
   - pendant le délai.
6. **Braquage avec une arme autorisée :**
   - panique, puis remplissage avec le sac en main ;
   - durée exacte (essayer 30 s puis 120 s) ;
   - barre de progression ;
   - sac posé sur le comptoir.
7. **Alerte police :**
   - elle apparaît sur la tablette police et sur la carte, à la bonne position ;
   - essayer aussi le mode « Interne » (blip, zone, durée).
8. **Annulations :**
   - s'éloigner au-delà de la distance d'annulation ;
   - tomber ;
   - se déconnecter pendant le braquage ;
   - dans chaque cas : aucun sac, et un délai selon le réglage.
9. **Sac :**
   - ramasser : le sac est visible au dos ;
   - courir ;
   - entrer et sortir d'un véhicule (vérifier l'affichage ; essayer aussi le mode « Sac de tenue GTA ») ;
   - déposer avec E ;
   - ramasser à nouveau.
10. **Ouvrir le sac :**
    - les icônes et les quantités sont justes ;
    - « Prendre » ligne par ligne, puis « Tout prendre » : l'argent arrive sur le bon compte et les objets dans l'inventaire ;
    - inventaire plein : le reste reste dans le sac ;
    - sac vide : il disparaît.
11. **Doublons :**
    - deux joueurs ouvrent le même sac (le second est refusé) ;
    - double clic sur « Tout prendre » ;
    - redémarrage de la ressource avec un sac porté puis un sac au sol (contenu identique, jamais dupliqué).
12. **Mort et déconnexion du porteur :** sac au sol, ou conservé selon le réglage.
13. **Racheteur :**
    - quantités, prix, total ;
    - vendre plus que possédé (refus) ;
    - prix modifié dans l'admin puis vente immédiate (nouveau prix appliqué).
14. **Nettoyage :** sac abandonné supprimé après le délai ; boutons « Supprimer » de l'onglet G.
15. **Journal (onglet J) :** les entrées des étapes précédentes sont présentes.

## Limites connues

- **Non testé en jeu.**
- Le décalage et la rotation du sac attaché au dos (`bag.offset` / `bag.rotation`) sont des valeurs de départ, réglables dans l'onglet G. En véhicule, l'objet suit le personnage ; selon le véhicule il peut traverser le siège. Le mode « Sac de tenue GTA » (composant 5) s'affiche mieux en véhicule, mais remplace temporairement le sac de la tenue. La tenue est restaurée au dépôt.
- Les animations par défaut sont des animations GTA connues. Si l'une ne charge pas, le scénario de secours est joué.
- Le nom et la description modifiés dans l'onglet F s'affichent dans les menus du braquage. L'inventaire garde ceux de `shared/items.lua`.
- La touche E de dépôt peut entrer en conflit avec d'autres actions sur E au même endroit.
- Les PNJ sont locaux à chaque joueur : chacun voit le bijoutier animé selon l'étape publiée par le serveur, sans synchronisation physique.
