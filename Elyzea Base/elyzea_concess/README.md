# elyzea_concess — Concessions automobiles (multi-concessions)

> **État : écrit et vérifié hors jeu uniquement** (syntaxe Lua/JS, correspondance de toutes les actions
> interface ↔ client ↔ serveur, aperçus des interfaces dans un navigateur avec des données fictives).
> **Rien n'a été testé sur un serveur FiveM.** Suivez la liste « Tests à faire en jeu » avant l'ouverture.

## Ressources réutilisées (aucun système concurrent)

| Besoin | Utilisé |
|---|---|
| Joueurs, métiers, grades, argent | `elyzea_core` (`GetPlayer`, `AddPlayerToJob`, `CreateJob`, `AddMoney`/`RemoveMoney` banque et espèces) |
| Compte de chaque concession | comptes de société d'`elyzea_core` (`Add/Remove/GetSocietyMoney`, journal) |
| Propriété des véhicules | table `player_vehicles` d'`elyzea_core` (aucune autre table de propriété) |
| Clés | `elyzea_core:GiveKeys` (démarrage) + propriétaire inscrit dans `player_vehicles` (clés permanentes) + objet `concess_key` d'`elyzea_inventory` (plaque en métadonnée, reconnu par la touche U) |
| Garage | `elyzea_garage` : le véhicule acheté est enregistré au garage public (`public`) ; l'export `EnsureKey` (déjà appelé par le garage) redonne une clé perdue au **propriétaire** |
| Essence | `elyzea_fuel:SetFuel` (véhicule livré avec le plein) |
| Permissions staff | `admin_menu:HasPermission(src, 'dealer_manage')` |
| PNJ « Catalogue concession » d'admin_menu | export `ViewCatalog` : ouvre le catalogue de la concession la plus proche du PNJ |

## Installation

1. `server.cfg` : `ensure elyzea_concess` après `elyzea_core`, `elyzea_inventory`, `admin_menu`, `elyzea_garage` (déjà ajouté).
2. Base de données : tables `cd_*` créées automatiquement (`sql/install.sql` pour une installation manuelle). D'anciennes tables `concess_*` ne sont ni lues ni modifiées.
3. admin_menu : permission **`dealer_manage`** (donnée au SuperAdmin ; le Fondateur a tout), onglet **Administration automobile** (ou `/concessadmin`).

## Configuration (staff)

1. **Modèles** › « + Ajouter » : recherche dans la liste réelle des modèles chargés par le jeu (`GetAllVehicleModels`, véhicules ajoutés compris), ou nom de spawn exact puis « Vérifier dans le jeu ». Un modèle qui n'existe pas ou n'est pas un véhicule est refusé ; un nom saisi seul n'est jamais accepté. Fiche : nom commercial, marque, catégorie, description, image, prix de référence, actif, vente autorisée, exposition autorisée.
2. **Catégories** : 13 catégories proposées au départ, toutes modifiables (nom, icône, image, ordre, active), association / retrait de modèles, liste des concessions qui l'utilisent.
3. **Concessions** › « + Nouvelle » : nom, adresse, métier (créé dans elyzea_core), compte de société, préfixe des matricules, service obligatoire, remise maximale, blip. Créée **fermée**, avec 4 grades (Employé, Commercial, Responsable, Directeur).
4. Pour chaque concession, indépendamment des autres :
   - **Catégories** : activée / visible / vendable / ordre ; « + Tous ses modèles » ajoute la catégorie entière au prix de référence ;
   - **Modèles et prix** : activé / visible / vendable / exposable / prix propre (vide = prix de référence). La colonne « Résultat » montre l'effet réel (règles globales comprises) ;
   - **Réglages et points** : consultation du catalogue (clients), aperçu du véhicule, point de gestion (employés), places de sortie (plusieurs, orientation comprise). Rayon, orientation, activation, suppression, « Aller ». « Aperçu en jeu » affiche tous les points ;
   - **Exposition** : emplacements (nom, position, orientation, activation) ;
   - **Personnel** : « Nommer » donne le plus haut grade à un joueur (ID serveur).
5. **Ouvrir** la concession (refusé sans point de catalogue ni place de sortie).

Règles appliquées par le serveur (pas seulement cachées dans l'interface) :
- **proposé** : modèle actif et non retiré + catégorie active + catégorie et modèle activés dans la concession ;
- **visible** : proposé + catégorie visible + modèle visible ;
- **vendable** : proposé + vente autorisée (global) + catégorie vendable + modèle vendable + prix > 0 ;
- **exposable** : proposé + exposition autorisée (global) + modèle exposable.

« Retirer du catalogue », « désactiver » ou « supprimer une concession » ne touchent jamais aux véhicules achetés, aux clés, aux garages, aux ventes ni aux finances.

## En jeu

- **Clients** : E sur le point bleu → catalogue (catégories, recherche, tri, filtre « vendables », fiche avec caractéristiques lues dans le jeu, « Voir en 3D » : véhicule local figé, caméra clic droit + molette). Consulter ne débite rien et ne crée aucun véhicule. Un modèle visible mais non vendable affiche « Non disponible à la vente ».
- **Employés** (F6 : `concess_menu`) : service, statut, catalogue (Vendre / Exposer), tablette.
- **Vente** : le vendeur choisit le client proche (identifié par son citizenid), banque ou espèces, remise éventuelle (permission « discount », plafond de la concession). Le client voit le récapitulatif et accepte. Le serveur revérifie tout (vendeur, service, concession, modèle, catégorie, vente autorisée, prix en base, fonds, vente non déjà faite), puis : paiement → compte de la concession → plaque unique → `player_vehicles` → vente → clés → commission du vendeur. Toute étape qui échoue après le paiement rembourse le client (tracé).
- **Livraison** : tentative immédiate à la première place de sortie libre. Sinon, l'acheteur appuie sur E à la zone verte (« Récupérer mon véhicule ») ou un employé « Livrer » depuis la tablette. Le véhicule est cherché en ville avant : jamais de doublon, jamais de second paiement. Le véhicule est aussi sorti normalement par un garage public.
- **Exposition** : véhicules affichés localement par chaque joueur (impossible d'y monter, de les voler ou d'en avoir les clés), restaurés après redémarrage, un véhicule par emplacement. Une vente ne retire pas le véhicule exposé : l'acheteur reçoit un véhicule neuf.
- **Tablette** : tableau de bord (chiffres réels), catalogue et prix (+ historique), exposition, ventes et livraisons (relivrer, redonner la clé), clients, configuration (lecture), direction (recrutement, employés, grades, permissions, historique), finance (compte de la concession, salaires horaires, **commission % par grade fixée par la direction**, moyens de paiement, transactions).
- **Paie** : même système que la police, les EMS, le mécano et Dynasty 8 (temps de service compté par le serveur, payé par la direction au taux du grade de la période).

## Commandes

`F6` / `/concess_menu` · `/concessadmin` (staff) · `/concess_debloquer` (rend le curseur) · `/concess_pos` (position).

## Tests à faire en jeu (aucun n'a été fait)

1. Démarrage : aucune erreur, tables `cd_*` créées, 13 catégories.
2. Ajout d'un modèle de base (`adder`) puis d'un véhicule ajouté par une ressource ; un nom inexistant est refusé.
3. Deux concessions (ex. voitures et motos) : catégories, modèles et prix différents ; modifier l'une ne change pas l'autre.
4. Catalogue client : seuls les modèles visibles apparaissent, « Non disponible à la vente » affiché, aucun débit, aperçu 3D supprimé à la fermeture.
5. Vente banque puis espèces, fonds insuffisants, refus, client qui s'éloigne, remise au-delà du plafond refusée.
6. Propriété : véhicule dans `player_vehicles` au bon citizenid, plaque unique, clé physique reçue, démarrage possible, rangement et sortie au garage public, U pour verrouiller.
7. Livraison : places occupées (message, pas de nouveau débit), nouvelle tentative, pas de doublon si le véhicule est déjà sorti.
8. Exposition : placer, remplacer, tourner, retirer ; redémarrage de la ressource (restauration) ; impossible de monter dans un véhicule exposé.
9. Commission : % réglé par la direction, versement au vendeur, transaction « Commissions ».
10. Modèle désactivé / retiré : plus vendable ni exposé ; les véhicules déjà vendus restent.
11. Personnel : recrutement, grades, permissions, paie ; nommer un responsable depuis le staff.
12. Suppression d'une concession : employés retirés du métier, ventes et véhicules conservés.

## Limites connues

- **Non testé en jeu.**
- La vérification d'un modèle se fait dans le jeu du staff (le serveur FiveM ne peut pas lire les modèles chargés). Un modèle ajouté puis supprimé du serveur reste en catalogue : il apparaît alors « Aperçu indisponible » et la livraison échoue proprement (le véhicule reste au garage public).
- Images : automatiques pour les véhicules du jeu de base ; pour les véhicules ajoutés, saisir une adresse d'image.
- Stock illimité (pas de stock physique), comme demandé.
- Le véhicule livré a les couleurs d'origine du modèle (pas de choix de couleur à l'achat).
- Les véhicules exposés sont locaux : chaque joueur les voit, mais ils ne sont pas synchronisés physiquement (personne ne peut les déplacer).
- admin_menu › Métier staff ne gère pas ces concessions (plusieurs métiers) : utilisez « Nommer » dans l'administration automobile.
