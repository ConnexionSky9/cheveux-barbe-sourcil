# Elyzea Aura 5

Téléphone complet pour FiveM, compatible **Qbox**, QBCore, ESX et standalone (détection automatique).

## Nouveautés de la version 5
- **Nouveau design** : thèmes sombre « Abysse » et clair « Nacre » (ou Auto selon l'heure du jeu), halo lumineux derrière l'heure, liseré de lumière sur le cadre.
- **Intro de premier démarrage** : animation, choix de la langue (français, anglais, espagnol), du thème, du code, de Face ID et du style.
- **Sécurité** : code à 4 ou 6 chiffres (stocké haché côté serveur), Face ID, verrouillage à la fermeture, blocage après plusieurs erreurs.
- **AuraDrop** : partage de sa fiche contact avec les joueurs à proximité, qui l'enregistrent en un geste.
- **Mon numéro** visible sur l'accueil, dans Contacts (Ma fiche) et dans Réglages, avec copie en un geste.
- **Banque connectée** au compte du framework : solde en temps réel, courbe du solde, virements (même hors ligne), demandes de paiement, envoi d'argent depuis un contact ou une conversation.
- **Personnalisation** : 7 fonds d'écran + image personnalisée, 6 accents + couleur libre, 3 styles d'icônes (Prisme, Verre, Mono), 3 horloges, 4 cadres, 4 sonneries, taille, nom de l'appareil.

## Nouveautés de la version 5.1
- **Appareil photo et caméra** dans le téléphone : viseur en direct, photos et vidéos (jusqu'à 20 s) envoyées automatiquement dans la galerie. screenshot-basic n'est plus nécessaire.
- **Galerie** avec filtres Photos / Vidéos et lecture des vidéos.
- **Itoune** : collez un lien YouTube ou Spotify, la musique se lance. Mode haut-parleur : les joueurs autour l'entendent, le volume baisse avec la distance (aucune ressource externe nécessaire).
- **Étincelle**, application de rencontre : profil avec photos, cartes à glisser, coups de cœur, matchs et messagerie privée.

## Nouveautés de la version 5.2
- **Livrézy** : commande de repas, snacks, boissons et alcool depuis le téléphone (plus cher qu'en supérette, avec frais de livraison). Un livreur PNJ part en voiture du commerce le plus proche, se suit en direct sur la carte et dans l'app, descend vous remettre la commande puis repart. Paiement par banque ou en espèces, annulation possible, remboursement automatique en cas de problème.

## Nouveautés : application Santé
- **Santé** (magasin Appli) : trois onglets.
  - **Rendez-vous** : demander un rendez-vous à l'hôpital (consultation médicale, psychiatrique, prise de sang, suivi de grossesse), avec un motif facultatif.
    On suit sa demande : *En attente* (avec le temps avant annulation), *Accepté par …*, *Annulé : aucun EMS disponible*.
    On peut annuler. Notification quand un EMS accepte (« L'EMS Prénom a accepté votre rendez-vous ») ou quand la demande expire.
  - **Ma santé** : maladies et blessures connues ou découvertes par un examen EMS, avec conseils, et antécédents.
  - **Grossesse** : même suivi que l'application Grossesse (temps écoulé, temps restant, trimestre, historique), avec un raccourci « Prendre un rendez-vous de suivi ».
- Données fournies par `elyzea_ems` (rendez-vous, santé) et `elyzea_famille` (grossesse). Sans elles, l'onglet affiche « indisponible ».
- **Correctif** : l'application Grossesse n'avait pas de réponse côté serveur (`grossesseSuivi`) ; elle lit maintenant `exports.elyzea_famille:SuiviGrossesse`.

## Nouveautés : application Services
- **Services** (sur l'écran d'accueil, pas besoin de la télécharger) : liste de **toutes les entreprises** du serveur
  (restaurants, boîtes, concessions, police, EMS, mécano, Dynasty 8, presse…), rangées par métier, avec recherche,
  filtre « Ouvertes », état **Ouverte / Fermée**, nombre d'employés en service et **numéro public**.
- **Appeler** : sonne sur le téléphone de service des employés en service (elyzea_jobphone) ; **Message** : conversation
  dans Messages avec le numéro public, les réponses de l'entreprise y arrivent. Le nom de l'entreprise remplace son numéro.
- Nécessite `elyzea_jobphone` (sinon : « Annuaire des entreprises indisponible »).

## Applications
Téléphone, Messages (position GPS, fiche contact, envoi d'argent), Contacts, Banque, Galerie, Appareil photo, Notes, Plans, Urgences, Calcul, Annonces, Réglages, et le magasin **Appli** pour télécharger Birdy, **ElyPick** (ex-InstaPick), Itoune, Étincelle, Livrézy, HelpMécano, Garage, CarPlay, **Santé** et **Grossesse** (suivi de grossesse : données de la ressource `elyzea_famille`, privées). La tablette de bord ElyzeaCarPlay s'ouvre en voiture avec F7.

## Exports
```lua
-- Serveur
exports.elyzea_aura:GetPhoneNumber(source)
exports.elyzea_aura:SendNotification(source, 'Titre', 'Texte', 'system')
exports.elyzea_aura:GetFramework()
-- Client
exports.elyzea_aura:OpenPhone()
exports.elyzea_aura:ClosePhone()
exports.elyzea_aura:IsOpen()
```

## Commande admin
`/elyzea_resetcode [id]` supprime le code d'un joueur qui l'a oublié (permission `command.elyzea_resetcode`).

Voir `INSTALLATION.md` pour l'installation pas à pas.

## Nouveautés : thème Elyzea FA, appli Identité, AuraDrop
### Thème Elyzea FA
- Fond d'écran « Elyzea » animé : aurore violette, emblème E, ville de nuit dont les fenêtres s'allument.
- Cadre et couleur d'accent « Elyzea ».
- Emblème animé au démarrage et sur l'écran verrouillé.

Les téléphones restés sur l'apparence d'origine (Halo, Titane, Plasma) passent une fois au thème Elyzea. Le joueur peut toujours changer dans Réglages.

Les animations du fond se mettent en pause sous une appli et téléphone rangé.

### Appli « Identité »
L'appli est sur l'accueil.

**Mes cartes** : carte d'identité, permis de conduire (B voiture, A moto, C poids lourd) et PPA, au design du logo.
- **Montrer** : la carte part sur le téléphone d'une personne proche, seulement si son téléphone est **sorti**.
- **Enregistrer** : une copie de la carte arrive dans la galerie, onglet « Cartes ».

**Reçues** : les cartes qu'on vous montre.
- Vous pouvez les enregistrer dans votre galerie.
- Le propriétaire est alors prévenu : « … a enregistré votre carte ».

**Police en service** : sur un permis ou un PPA reçu, le policier peut :
- suspendre ou rétablir une catégorie du permis (B, A ou C), tout le permis, ou le PPA ;
- indiquer un motif (facultatif).

Une carte suspendue ne disparaît pas : « SUSPENDU » est écrit dessus. C'est vrai partout : dans le téléphone, quand on la montre, et quand on la sort de l'inventaire.

Données et règles : `elyzea_papiers` (table `elyzea_doc_suspensions`, créée toute seule).

### AuraDrop
On ne voit, et on ne peut envoyer sa fiche qu'aux personnes proches qui ont leur **téléphone sorti**. Le serveur le vérifie. Un téléphone rangé est invisible.

### Tests hors jeu
- `python3 tests/run_identity_sim.py <socket MariaDB>` : vrais fichiers serveur, vraie base ; 38 vérifications.
- `NODE_PATH=$(npm root -g) node tests/ui_identite.cjs` : téléphone dans Chromium ; 18 vérifications.

## ElyPick (ex-InstaPick) : réseau social photo
InstaPick est devenu **ElyPick**, directement dans le téléphone (aucune ressource à ajouter).
L'identifiant interne reste `instapick` : les joueurs qui l'avaient installé le gardent, et leurs anciens comptes, publications, j'aime et commentaires apparaissent dans ElyPick.

### Fonctionnalités
- **Navigation** (barre du bas) : Accueil, Recherche, Créer, Messages, Profil. L'appli s'ouvre et se ferme comme les autres (barre d'accueil, bouton retour).
- **Compte** : nom d'utilisateur unique, nom affiché, photo de profil, biographie, tout modifiable. Le compte est lié au personnage (citizenid), pas au pseudo.
- **Abonnements** : s'abonner / se désabonner, listes d'abonnés et d'abonnements, « Vous suit ». Pas de doublon, pas d'abonnement à soi-même.
- **Accueil** : stories des comptes suivis, puis le fil (mes photos et celles des comptes suivis, des plus récentes aux plus anciennes, chargées par pages).
- **Publications** : photo de la galerie (ou de l'appareil photo, ou un lien d'hébergeur autorisé), description, musique facultative, aperçu, puis partage.
  - Chaque publication affiche j'aime, commentaires, partage en message privé et date.
  - Double-tap pour aimer. Seul l'auteur peut supprimer sa publication.
  - Profil en grille de 3 colonnes ; un tap ouvre la photo en grand.
- **Musique** : choisie dans les musiques du serveur (`Config.ElyPick.Music`) ou dans la bibliothèque **Itoune** du joueur. Lecture / arrêt sur la photo, avec le même lecteur qu'Itoune (YouTube ou lien audio).
- **Stories (24 h)** : visibles par les abonnés. La date d'expiration est enregistrée en base, et une story expirée n'est plus jamais renvoyée. La visionneuse plein écran propose :
  - une barre de progression, story suivante / précédente, pause en maintenant ;
  - les stories du compte suivant à la fin ;
  - pour l'auteur, le nombre de vues ;
  - pour les autres, un bouton « Répondre » qui ouvre les messages privés.
- **Stories à la une** : ajouter une story à une catégorie (créée à la volée), renommer, choisir la couverture, retirer une story, supprimer une catégorie.
  - Une **copie** est enregistrée : la story reste à la une après ses 24 h et après le nettoyage automatique.
- **Recherche** : par nom d'utilisateur ou nom affiché. En dessous, **Explorer** affiche toutes les photos du serveur en grille, chargées par pages au fil du défilement.
- **Messages privés** :
  - fonctions : conversations, non lus, dernier message, date, chargement des anciens messages, partage d'une publication ;
  - en direct : réception immédiate, pastille sur l'icône de l'appli et sur l'onglet Messages, bouton Actualiser.
- **Activité** (cœur en haut de l'accueil) : nouveaux abonnés, j'aime, nouvelles stories.
  - Ces notifications sont enregistrées en base, sans doublon grâce à une clé unique.
  - Une alerte s'affiche en direct si le joueur est connecté.

### Base de données
Les tables sont créées au démarrage (`sql/elypick.sql`, rien à importer) :
- `elyzea_ep_profiles`
- `elyzea_ep_follows`
- `elyzea_ep_stories`
- `elyzea_ep_story_views`
- `elyzea_ep_highlights`
- `elyzea_ep_highlight_items`
- `elyzea_ep_conversations`
- `elyzea_ep_messages`
- `elyzea_ep_notifications`

Ajouts aux tables existantes, sans rien supprimer :
- colonnes `music_*` sur `elyzea_social_posts` ;
- index pour le fil, les profils et la recherche.

Les images sont des **liens** (photos de la galerie envoyées par l'appareil photo via l'hébergeur), jamais des fichiers en base.

Nettoyage toutes les 10 minutes :
- stories expirées (les copies à la une restent) ;
- notifications plus vieilles que `NotificationDays`.

### Sécurité
- Tout est vérifié par le serveur : le compte utilisé est celui du personnage, jamais une valeur envoyée par le téléphone.
- On ne peut supprimer ou modifier que ses propres publications, stories, catégories et commentaires.
- On ne peut lire et écrire que ses propres conversations.
- Images acceptées : photo de la galerie du joueur, ou lien d'un hébergeur listé dans `Config.ElyPick.ImageHosts` ; formats JPG, PNG, WEBP ou GIF.
- Musique : uniquement une musique du serveur ou de la bibliothèque Itoune du joueur.
- Requêtes SQL paramétrées, pages limitées, anti-spam (publication, story, message, j'aime, abonnement).

### Réglages
Tous les réglages sont dans `config_elypick.lua`, fichier séparé : ton `config.lua` n'est pas touché :
- durée des stories ;
- tailles des pages ;
- longueurs ;
- hébergeurs d'images autorisés ;
- musiques du serveur ;
- durée de conservation de l'activité.

### Tests hors jeu
- `python3 tests/run_elypick_sim.py <socket MariaDB>` : vrais fichiers serveur, vraie base MariaDB, 3 joueurs, puis redémarrage simulé ; 91 vérifications.
- `NODE_PATH=$(npm root -g) node tests/ui_elypick.cjs` : l'interface complète dans le navigateur, avec des données de démonstration.
