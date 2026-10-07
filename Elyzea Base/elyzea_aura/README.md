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

## Applications
Téléphone, Messages (position GPS, fiche contact, envoi d'argent), Contacts, Banque, Galerie, Appareil photo, Notes, Plans, Urgences, Calcul, Annonces, Réglages, et le magasin **Appli** pour télécharger Birdy, InstaPick, Itoune, Étincelle, Livrézy, HelpMécano, Garage et CarPlay. La tablette de bord ElyzeaCarPlay s'ouvre en voiture avec F7.

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
