# elyzea_concess

Concessionnaire automobile complet pour la **base Elyzea** (elyzea_core, elyzea_inventory), relié au menu admin (`admin_menu`).

## Installation
1. Place `elyzea_concess` dans `resources/` (arrête tout autre script de concession).
2. `server.cfg` :
   ```
   ensure admin_menu
   ensure elyzea_concess
   ```
3. **Clé de véhicule** : l'objet `concess_key` est déjà déclaré dans `elyzea_inventory` (image comprise).
   La touche **U** (elyzea_core) ouvre / ferme le véhicule pour qui a la clé dans son inventaire.
4. Tables créées automatiquement : `concess_settings`, `concess_vehicles` (50 véhicules du jeu de base au départ),
   `concess_sales`. Les véhicules vendus vont dans `player_vehicles` (table de la base Elyzea).
5. Le métier `cardealer` (5 grades) est créé dans elyzea_core. Des zones sont posées au Premium Deluxe Motorsport
   (positions approximatives) : vérifie-les dans **Menu admin › Métiers › Concession › Zones** (Y aller, 📍).

## Employés (F6)
- **Tableau de bord** : entreprise, grade, statut, mes ventes et mon chiffre (30 j), chiffre de l'entreprise si autorisé,
  équipe en service, dernières ventes. Bouton **SE METTRE EN SERVICE** : tenue de travail mise, vêtements gardés et rendus
  (géré par admin_menu, même après une déconnexion ou un crash).
- **Catalogue** : catégories, recherche, tri, pagination, véhicules masqués (si autorisé). Fiche : image, caractéristiques
  (vitesse, accélération, freinage, adhérence, places), description, et les actions :
  - **Vendre** : acheteur = « Personne la plus proche » (moins de 6 m, choisie par le serveur) ou « Moi-même »
    (sans commission), remise bornée par le grade. L'acheteur reçoit « Voulez-vous acheter ce véhicule à ce prix ? » Oui / Non ;
  - **Mettre en exposition** sur l'emplacement du showroom choisi ;
  - Modifier / Masquer / Supprimer selon les permissions.
- **Showroom** : « Mettre en exposition » fait apparaître le véhicule directement sur l'emplacement choisi, posé au sol,
  totalement verrouillé (personne ne peut entrer ni le démarrer), immobile, indestructible, toujours là après un redémarrage, Exposer / Retirer. Avec la permission « Gérer les emplacements du showroom » :
  ajouter un emplacement à ta position (le véhicule prend ton orientation), le déplacer 📍, le supprimer.
- **Direction** (selon les permissions) : ajout et modification de véhicules (modèle vérifié en jeu, image, description),
  catégories, employés (recruter, grade, renvoyer, ventes par employé), permissions et remise par grade, finances
  (solde du compte, jour / 7 j / 30 j, graphique 14 jours, top véhicules, top vendeurs, historique).

## Vente (tout est vérifié côté serveur)
Le prix vient du catalogue serveur, la remise est limitée par le grade. Si l'acheteur répond Oui : paiement par banque,
commission du vendeur, reste au compte de l'entreprise (compte d'entreprise elyzea_core), véhicule enregistré à son nom avec une plaque
unique, livré sur le parking, et **une clé dans son inventaire** (objet `concess_key`, plaque dans la description).
Tant qu'il a cette clé, **U** près du véhicule (ou dedans) le verrouille / déverrouille (bip, phares). La clé se donne,
se perd, se vole comme un objet. S'il la perd, le garage de la concession lui remet un double à la sortie.
Les clés de la session (elyzea_core) sont aussi données.

## Garage de la concession
Zone **Garage** : liste de ses véhicules (état moteur, carrosserie, essence), sortie à la zone **Sortie du garage**.
Zone **Rangement** : le véhicule est rangé dans l'état exact (pièces, peinture, dégâts, pneus, vitres, portes, saleté,
essence) et ressort identique. Désactivable (`Configuration › Garage de la concession`) si tu utilises seulement elyzea_garage.

## Catalogue et essais sur un PNJ
Dans **Menu admin › Éditeur de map › PNJ**, active « 🚘 Catalogue concession » sur un PNJ : en lui parlant, les joueurs
voient le catalogue (catégories, recherche, fiches, caractéristiques) sans pouvoir acheter. Les véhicules masqués n'y sont pas.
Avec « 🏁 Essai routier » : choisis la durée et place le point de départ (véhicule fantôme, molette pour l'orienter, E).
Le joueur appuie sur **Essai** dans une fiche : le véhicule apparaît au point choisi, il est mis au volant, le temps
s'affiche en haut de l'écran, puis le véhicule disparaît et il revient à côté du PNJ (aussi s'il descend plus de 10 s).
Un essai toutes les 30 secondes par joueur.

## Staff
**Menu admin › Métiers › Concession** (permission `concess_staff`) : ouvrir la **tablette direction** avec tous les droits,
informations, grades, zones, tenues par grade, permissions et remises, configuration.
