# Elyzea Aura 5 — Guide d'installation

Version 5.2. Compatible Qbox, QBCore, ESX et standalone (détection automatique).

Ce guide t'accompagne de l'archive zip jusqu'au premier appel en jeu. Compte environ 10 minutes.

---

## 1. Ce qu'il te faut

| Ressource | Obligatoire | Rôle |
|---|---|---|
| **oxmysql** | Oui | Base de données |
| **qbx_core**, **qb-core** ou **es_extended** | Recommandé | Noms des personnages, banque, métiers |
| **pma-voice**, **mumble-voip** ou **saltychat** | Recommandé | La voix pendant les appels |
| **ox_inventory** | Non | Détecté automatiquement si tu exiges un item téléphone |

> ⚠️ **Retire tout autre téléphone** (qb-phone, gksphone, high_phone, npwd…). Deux téléphones se battent pour la même touche et le même item. Avec Qbox, **npwd** est souvent installé d'office : supprime son dossier ou déplace-le hors de `resources`.

---

## 2. Placer la ressource

1. Décompresse `elyzea_aura.zip`.
2. Copie le dossier `elyzea_aura` dans le dossier `resources` de ton serveur. Tu peux le mettre dans un sous-dossier comme `resources/[telephone]/`.
3. Vérifie que le dossier s'appelle **exactement** `elyzea_aura`. Les événements internes utilisent ce nom.

L'arborescence doit ressembler à ceci :

```
resources/
└── elyzea_aura/
    ├── fxmanifest.lua
    ├── config.lua
    ├── client/main.lua
    ├── server/main.lua
    ├── html/ (index.html, style.css, js/)
    └── sql/
        ├── elyzea_aura.sql
        ├── mise_a_jour_v1.1.sql
        ├── mise_a_jour_v5.sql
        ├── mise_a_jour_v5.1.sql
        └── mise_a_jour_v5.2.sql
```

---

## 3. Base de données

**Rien à faire à la main.** À chaque démarrage, le téléphone crée les tables manquantes et ajoute les colonnes des nouvelles versions. La console confirme en vert :

```
[elyzea_aura] Base de données à jour (19 tables vérifiées, 0 colonne(s) ajoutée(s)).
```

La seule condition : `oxmysql` doit démarrer **avant** `elyzea_aura`. Les fichiers du dossier `sql/` restent disponibles si tu préfères tout importer toi-même.

> ⚠️ Garde **un seul** dossier `elyzea_aura` dans `resources`. Si la console affiche « elyzea_aura exists in more than one place », supprime le doublon. Sinon, le serveur peut utiliser une ancienne copie.

---

## 4. Configurer `config.lua`

Ouvre `config.lua` et règle au minimum ces points.

### Framework

```lua
Config.Framework = 'auto'       -- 'auto', 'esx', 'qb' ou 'standalone'
```

Laisse `'auto'` : le téléphone détecte Qbox, QBCore ou ESX tout seul. Au démarrage, la console affiche `Elyzea Aura 5 démarré (framework : qb)` (Qbox apparaît comme `qb`, c'est normal). En standalone, il n'y a ni banque ni urgences par métier.

### Sécurité du téléphone

```lua
Config.Security = {
    Salt = 'change-moi-elyzea',  -- remplace par une phrase unique à ton serveur
    MaxAttempts = 5,
    LockoutSeconds = 30,
}
```

Change `Salt` **avant** que les joueurs créent leur code. Si tu le changes après, tous les codes existants deviennent invalides et il faudra les réinitialiser.

### AuraDrop et banque

```lua
Config.AuraDrop = { Enabled = true, Distance = 6.0 }     -- portée en mètres
Config.Bank.OfflineTransfers = true                      -- virer à un joueur déconnecté
```

### Voix pendant les appels

```lua
Config.Voice = 'pma-voice'      -- 'pma-voice', 'mumble-voip', 'saltychat' ou 'none'
```

### Touche d'ouverture

```lua
Config.OpenKey = 'F1'
```

> ⚠️ FiveM mémorise la touche **chez chaque joueur** dès la première connexion. Si tu changes `Config.OpenKey` plus tard, les joueurs déjà venus garderont l'ancienne touche. Ils peuvent la modifier dans **Paramètres → Raccourcis → FiveM → Ouvrir le téléphone Elyzea Aura**.

### Se déplacer avec le téléphone

```lua
Config.MoveWhileOpen = true
```

Téléphone ouvert, le joueur peut marcher, courir et conduire. Il maintient le **clic droit** pour regarder autour. Quand il écrit dans un champ, ses touches ne font plus bouger le personnage. Mets `false` pour revenir à un téléphone qui immobilise le joueur. Chaque joueur peut aussi le couper dans Réglages → Général.

### Services d'urgence

Le champ `job` doit correspondre **exactement** au nom du métier dans ton framework (`police`, `ambulance`, `mechanic`…) :

```lua
{ id = 'police', label = 'Police', job = 'police', color = '#8E7CFF', icon = 'shield' },
```

Les icônes disponibles sont `shield`, `cross`, `wrench` et `car`.

### Format des numéros

```lua
Config.NumberFormat = '555-####'   -- chaque # devient un chiffre aléatoire
```

Le numéro est attribué à la première ouverture du téléphone et ne change plus ensuite.

---

## 5. (Facultatif) Exiger un item téléphone

Dans `config.lua` :

```lua
Config.RequireItem = true
Config.ItemName = 'phone'
```

Ensuite, déclare l'item dans ton inventaire.

**ox_inventory**, dans `ox_inventory/data/items.lua` :

```lua
['phone'] = { label = 'Téléphone', weight = 190, stack = false, close = true },
```

**ESX** (sans ox_inventory), dans ta base de données :

```sql
INSERT INTO items (name, label, weight, rare, can_remove) VALUES ('phone', 'Téléphone', 1, 0, 1);
```

**QBCore**, dans `qb-core/shared/items.lua` :

```lua
phone = { name = 'phone', label = 'Téléphone', weight = 700, type = 'item', image = 'phone.png', unique = true, useable = false, shouldClose = true, description = 'Elyzea Aura' },
```

Sans l'item, un joueur qui appuie sur la touche reçoit le message « Vous n'avez pas de téléphone ». Il est aussi injoignable par appel.

---

## 6. Appareil photo, caméra et musique

### Photos et vidéos

Le viseur affiche le jeu en direct dans le téléphone : **screenshot-basic n'est plus nécessaire**. Il faut seulement un hébergeur pour stocker les fichiers. **Fivemanage** est gratuit pour démarrer.

**Obtenir ta clé Fivemanage :**
1. Crée un compte sur fivemanage.com et connecte-toi.
2. Dans le tableau de bord, ouvre **Tokens** (ou **API Keys**) et crée un nouveau token.
3. Copie la clé affichée.

**La coller dans `config.lua` :**

```lua
Config.Camera = {
    Enabled = true,
    UploadMethod = 'presigned',   -- lien d'envoi à usage unique : rapide, et la clé reste secrète
    PresignedUrl = 'https://api.fivemanage.com/api/presigned-url?fileType=%s',
    ImageUrl = 'https://api.fivemanage.com/api/image',
    VideoUrl = 'https://api.fivemanage.com/api/video',
    ImageField = 'file',
    VideoField = 'file',
    Headers = { Authorization = 'colle-ta-cle-ici' },
    ResponsePath = 'url',
    MaxVideoSeconds = 20,
    VideoBitrate = 1500000,
    FlipY = false,
}
```

> ⚠️ Remplace **tout** le texte `TA_CLE_API_FIVEMANAGE`, en gardant les guillemets, sans espace avant ni après la clé. Redémarre ensuite la ressource. Si la clé manque, la console l'indique en rouge au démarrage.

En jeu, ouvre l'app **Photo** :
- **Caméra arrière :** maintiens le **clic droit** pour viser, puis clique sur le déclencheur. L'onglet **Vidéo** filme jusqu'à 20 secondes.
- **Selfie :** le bouton de retournement passe en selfie, bras tendu et visage entier. Maintiens le clic droit et bouge la souris pour tourner autour du visage ou changer la hauteur. La **molette** (ou les boutons + / −) rapproche ou éloigne la caméra. La distance par défaut se règle dans `Config.Camera.Selfie`.

Si l'image du viseur apparaît à l'envers, mets `FlipY = true`.

### Musique YouTube et Spotify (Itoune)

Itoune n'a besoin d'**aucune ressource externe** : le téléphone lit YouTube lui-même grâce au lecteur officiel de YouTube.

1. Les liens **YouTube** fonctionnent tout de suite : vidéo classique, lien court `youtu.be`, Shorts ou YouTube Music.
2. Avec le **haut-parleur** activé (par défaut), les joueurs proches entendent la musique, de plus en plus fort à mesure qu'ils s'approchent.
3. Pour les liens **Spotify**, crée une clé API **YouTube Data v3** gratuite sur console.cloud.google.com et colle-la dans `Config.Itoune.YouTubeApiKey`. Spotify ne permet pas de lire ses morceaux en dehors de son application : le téléphone lit le titre du lien Spotify puis joue la même chanson depuis YouTube.

Réglages utiles : `Config.Itoune.Distance` (portée du haut-parleur en mètres) et `Config.Itoune.MaxVolume`.

### Étincelle (rencontres)

Rien à installer : l'application se télécharge depuis **Appli**. `Config.Dating.MinAge` fixe l'âge minimum des profils (18 par défaut).

### Livrézy (livraison de courses)

L'app se télécharge depuis **Appli**. Tout se règle dans `Config.Delivery` :

- **Catalogue** (`Categories`) : chaque article a un `name` qui doit être **le nom exact de l'item** dans ton inventaire. Les noms fournis (`burger`, `sandwich`, `water_bottle`, `kurkakola`, `beer`…) sont des exemples : vérifie-les dans `ox_inventory/data/items.lua` et remplace ceux qui n'existent pas chez toi. Fixe les prix au-dessus de ceux de ta supérette et de tes restaurants.
- **Frais** : `Fee` (25 $ par défaut). Moyens de paiement : `PayWith = { 'bank', 'cash' }`.
- **Commerces de départ** (`Shops`) : le livreur part de celui qui est le plus proche du joueur. Ajoute ou déplace les points comme tu veux.
- **Livreur** : modèles de voitures (`Vehicles`) et de PNJ (`Peds`), vitesse (`DriveSpeed`), temps de préparation (`PrepTime`).
- **Images** : `ImagePath` pointe vers les images d'ox_inventory. Avec qb-inventory, mets `'nui://qb-inventory/html/images/%s.png'`. Sans image, l'app affiche une vignette colorée.

Le serveur recalcule toujours le prix et ne donne les articles qu'une fois le PNJ arrivé. Si le livreur n'arrive pas avant `Timeout`, si le joueur se déconnecte, ou si un article ne tient pas dans l'inventaire, le joueur est remboursé automatiquement.

### HelpMécano (dépannage)

L'app se télécharge depuis **Appli**. Tout se règle dans `Config.Mechanic` :

- **Services et prix** (`Services`) : Nettoyage, Réparation, Remise sur roues et Formule complète, avec leur prix et la durée de l'intervention en secondes.
- **Garages de départ** (`Garages`) : la dépanneuse part du plus proche.
- **Dépanneuse** : `Truck` (`towtruck`, `towtruck2` ou `flatbed`) et les modèles de mécaniciens (`Peds`).
- **RP avec de vrais mécaniciens** : mets `BlockIfMechanicsOnline = true`. L'app redirige alors vers l'app Urgences quand un joueur avec le métier `MechanicJob` est en service.

L'app affiche la liste des véhicules du joueur actuellement sortis, avec leur état et leur distance, ainsi que le véhicule à côté de lui s'il en emprunte un. Il choisit celui à dépanner. Les véhicules à plus de `MaxVehicleDistance` (300 m) peuvent être localisés sur le GPS, mais il faut s'en rapprocher pour appeler la dépanneuse. S'il annule pendant le trajet, 20 % du prix sont retenus ; avant le départ, il est remboursé en totalité. Le paiement est remboursé automatiquement si la dépanneuse n'arrive pas ou si le véhicule disparaît.

### Garage (voiturier)

L'app se télécharge depuis **Appli**. Elle lit les véhicules du joueur dans `player_vehicles` (Qbox / QBCore) ou `owned_vehicles` (ESX) et affiche leur statut : au garage, sorti (avec localisation GPS s'il est en ville) ou en fourrière.

Pour un véhicule au garage, le joueur paie `Config.Garage.Price` (250 $ par défaut). Un voiturier PNJ sort alors le véhicule avec ses modifications, son essence et son état, puis le conduit jusqu'au joueur. Il se gare à côté, lui remet les clés (qbx_vehiclekeys ou qb-vehiclekeys) et repart à pied. Le véhicule est marqué « sorti » en base dès la commande. En cas d'annulation, d'échec ou de déconnexion, il est remis au garage et le joueur est remboursé.

`Config.Garage.Labels` traduit les noms techniques des garages (par exemple `pillboxgarage`) en noms lisibles.

### ElyzeaCarPlay (tablette de bord)

Dans un véhicule, appuie sur **F4** (modifiable par chaque joueur dans Paramètres → Raccourcis → FiveM → « Ouvrir la tablette ElyzeaCarPlay »). À la première ouverture dans un véhicule, une caméra tourne autour de la voiture pendant que « Bienvenue sur ElyzeaCarPlay » s'affiche ; « Passer » saute l'animation.

La tablette permet d'ouvrir et fermer chaque porte, le capot et le coffre (touche-les sur le schéma), de baisser ou monter les vitres, d'allumer les LED avec 7 couleurs, de verrouiller, et de lancer de la musique YouTube ou d'un lien audio. Les passagers l'entendent à plein volume, les gens dehors selon la distance, et moins fort si les vitres sont fermées. On peut continuer à conduire tablette ouverte (clic droit maintenu pour regarder autour).

L'app téléphone **CarPlay** (dans Appli) affiche **toute la flotte** du joueur : chaque véhicule sorti, où qu'il soit en ville, avec son état (verrouillé, moteur, LED, phares, portes ouvertes, musique). On peut verrouiller chaque voiture d'un geste depuis la liste, ou toute la flotte avec « Tout verrouiller ».

En ouvrant un véhicule, on le contrôle **à distance** : verrouillage, moteur, phares, LED avec couleurs, portes (sur le schéma), vitres, musique, alarme, et **localisation** (le véhicule clignote et klaxonne, l'itinéraire est ajouté au GPS). **« Venir à moi »** fait venir la voiture seule jusqu'au joueur, en conduite autonome, s'il est à moins de `SummonDistance` (350 m) et que personne n'est au volant. Elle se gare à côté de lui, moteur allumé et déverrouillée, avec la même sécurité anti-perte que les autres PNJ.

Réglages dans `Config.CarPlay` : touche, places autorisées (`Seats`), intro, portée de la musique, volume, couleurs des LED. Tout l'état des voitures est synchronisé par FiveM (state bags) : tous les joueurs voient les mêmes portes ouvertes, LED et vitres.

---

## 7. Démarrer la ressource

Dans `server.cfg`, ajoute la ligne **après** oxmysql, ton framework et ton système vocal :

```cfg
ensure oxmysql
ensure qbx_core         # ou qb-core / es_extended
ensure pma-voice
# ... tes autres ressources ...
ensure elyzea_aura
```

Redémarre le serveur. Dans la console, aucune ligne `[elyzea_aura] Erreur` ne doit apparaître.

---

## 8. Vérifier que tout marche

Connecte-toi avec deux joueurs, ou demande à quelqu'un de t'aider, puis coche ces points :

- [ ] À la première ouverture, l'intro se lance : langue, thème, code, Face ID, style.
- [ ] La touche ouvre le téléphone et Échap le ferme. Après fermeture, le code ou Face ID est demandé.
- [ ] Ton numéro et ton solde s'affichent sur l'accueil.
- [ ] L'app Photo prend une photo et une vidéo, et les deux apparaissent dans la Galerie.
- [ ] Dans Itoune, un lien YouTube se lance ; avec le haut-parleur activé, un joueur à côté entend la musique.
- [ ] Deux joueurs créent un profil Étincelle, se likent mutuellement et peuvent discuter.
- [ ] HelpMécano détecte le véhicule ; la dépanneuse arrive, le mécanicien répare et le véhicule est remis à neuf.
- [ ] Une commande Livrézy est débitée ; après la préparation, un point vert et un tracé GPS apparaissent ; le livreur arrive, remet le sac et les articles arrivent dans l'inventaire.
- [ ] AuraDrop (touche le widget « Mon numéro ») détecte un joueur proche et lui envoie ta fiche.
- [ ] Une demande de paiement arrive chez l'autre joueur, qui peut la payer depuis Banque → Demandes.
- [ ] Tu peux ajouter un contact, puis lui envoyer un message.
- [ ] Un appel fait sonner l'autre joueur, et vous vous entendez après avoir décroché.
- [ ] Un virement dans **Banque** crédite bien l'autre joueur.
- [ ] Dans **Appli**, tu peux télécharger Birdy, créer un compte et publier.
- [ ] Une alerte **Urgences** arrive chez un joueur qui a le bon métier, avec un point sur la carte.

---

## 9. Problèmes fréquents

**Le téléphone ne s'ouvre pas.**
Vérifie la touche dans Paramètres → Raccourcis → FiveM. Elle peut entrer en conflit avec une autre ressource. Regarde aussi si un autre téléphone est encore démarré.

**Le téléphone s'ouvre mais reste vide, ou les apps chargent dans le vide.**
`Config.Framework` ne correspond pas à ton serveur, ou le personnage n'était pas encore chargé. Reconnecte-toi après avoir corrigé la config.

**Erreurs SQL dans la console (`Table ... doesn't exist`).**
Le fichier SQL n'a pas été importé dans la bonne base. Recommence l'étape 3.

**On décroche mais on ne s'entend pas.**
Vérifie `Config.Voice` et que le système vocal démarre **avant** `elyzea_aura` dans `server.cfg`.

**« Destinataire hors ligne » lors d'un virement.**
C'est normal : les virements ne fonctionnent qu'entre joueurs connectés.

**Le livreur Livrézy remet la commande mais l'inventaire reste vide.**
Le nom de l'item dans `Config.Delivery.Categories` ne correspond à aucun item de ton inventaire. Corrige le `name` ; le joueur a été remboursé de l'article manquant.

**Le livreur reste bloqué ou fait de grands détours.**
Il se replace automatiquement sur une route plus proche après 15 secondes d'immobilité. Dans les zones sans route (montagne, intérieur), il finit le trajet à pied. Tu peux réduire `MaxSpawnDistance` pour des trajets plus courts.

**Un joueur a oublié son code.**
Tape `elyzea_resetcode ID` dans la console du serveur (ID = numéro du joueur en jeu). En jeu, les admins ont besoin de la permission `command.elyzea_resetcode`.

**L'intro réapparaît pour tout le monde après la mise à jour.**
C'est normal : elle s'affiche une fois pour chaque joueur venant d'une ancienne version. Ses messages, contacts et photos sont conservés.

**Itoune affiche « Cette vidéo ne peut pas être lue en dehors de YouTube ».**
L'auteur de la vidéo a interdit sa lecture sur d'autres sites. C'est fréquent pour les clips officiels (VEVO, maisons de disques). Prends une autre version du morceau : « audio », « lyrics » ou une mise en ligne non officielle.

**Itoune ne lit rien du tout.**
Le jeu du joueur doit pouvoir accéder à youtube.com. Vérifie qu'aucun pare-feu ou antivirus ne bloque FiveM. Si tu avais installé xsound pour une ancienne version, tu peux le garder ou le retirer : le téléphone ne l'utilise plus.

**« Les liens Spotify ne sont pas activés ».**
Ajoute une clé YouTube Data v3 dans `Config.Itoune.YouTubeApiKey`.

**« L'hébergeur a refusé le fichier ».**
Regarde la console du serveur. Une ligne `Lien d'envoi refusé par l'hébergeur` donne le code et la réponse de Fivemanage : envoie-la si le problème persiste. Pour un autre hébergeur ou un webhook Discord, mets `UploadMethod = 'server'`.

**« Échec de l'envoi (code 401) » dans la console.**
Fivemanage refuse ta clé : elle est absente, mal copiée, ou le token a été supprimé. Recolle-la dans `Config.Camera.Headers.Authorization`, puis redémarre la ressource.

**Les photos ou vidéos ne s'enregistrent pas.**
Regarde la console du serveur : la ligne `[elyzea_aura] Échec de l'envoi` affiche la réponse de l'hébergeur (clé invalide, mauvais nom de champ…). Les vidéos très longues peuvent dépasser la limite de ton hébergeur : baisse `VideoBitrate` ou `MaxVideoSeconds`.

**Les polices sont différentes de l'aperçu.**
Les polices se chargent depuis Google Fonts. Si le joueur n'a pas accès à Internet, une police système les remplace.

---

## 10. Aperçu sans serveur

Ouvre `html/index.html` dans Chrome ou Edge. L'interface se lance avec des données fictives, ce qui permet de tester les couleurs ou de montrer le téléphone à ton équipe.

---

## 11. Pour les développeurs

```lua
-- Côté serveur
local numero = exports.elyzea_aura:GetPhoneNumber(source)
exports.elyzea_aura:SendNotification(source, 'Titre', 'Texte', 'system')
local framework = exports.elyzea_aura:GetFramework()

-- Côté client
exports.elyzea_aura:OpenPhone()
exports.elyzea_aura:ClosePhone()
local ouvert = exports.elyzea_aura:IsOpen()
```
