# elyzea_meca : métier Mécano

> **Aucun test en jeu n'a été fait.** Le code a été vérifié hors du jeu (syntaxe Lua de tous les fichiers, syntaxe JS, cohérence entre l'interface et les actions serveur, aperçu de l'interface dans un navigateur avec des données fictives). Faites les tests de la liste en bas avant de l'ouvrir aux joueurs.

## Installation

1. Le dossier `elyzea_meca` est dans `Elyzea Base/`. `server.cfg` contient déjà `ensure elyzea_meca` (après `elyzea_ems`).
2. Dépendances : `oxmysql`, `elyzea_core` (obligatoires). Optionnelles : `elyzea_police` (menu ALT), `elyzea_inventory` (coffre d'atelier), `elyzea_aura` (téléphone : CarPlay et demandes de dépannage), `admin_menu` (onglet Métier staff).
3. Les tables sont créées **automatiquement** au démarrage. `sql/install.sql` contient les mêmes requêtes pour une installation à la main.
4. Au premier démarrage, la ressource crée les grades et le catalogue de départ (`config.lua`). Ensuite tout se règle dans la tablette.
5. Le métier `mechanic` est créé / mis à jour dans elyzea_core à partir des grades de la tablette. Pour vous donner le métier la première fois : admin_menu › Métier staff › Mécano, ou recrutement par un Directeur.

## Touches

| Touche | Action |
|---|---|
| **F6** | Menu rapide : service et temps, statut, véhicules (devis de prestations, historique), clients (devis, factures), dépannage, tablette, direction |
| **ALT** (menu d'interaction de elyzea_police) sur un véhicule | Réparer moteur / carrosserie / pneus, réparation complète, nettoyer, retourner. Seules les actions utiles à l'état du véhicule sont proposées |
| **E** au volant, sur un point d'atelier | Ouvre l'atelier pour ce véhicule |
| **G / I** | Accepter / refuser la dernière demande de dépannage |
| `/depannage <message>` | Tout le monde : demander un dépanneur |
| `/meca_pos` | Affiche votre position et le cap dans la console (aide) |

## Points d'atelier (placés en jeu)

Tablette › Direction › **Points d'atelier** (permission « Garage et points d'atelier ») : autant de points que vous voulez (30 au maximum, `Config.WorkshopMax`), n'importe où.

- Placez-vous (à pied ou au volant) à l'endroit voulu, donnez un nom, cochez les rubriques (performances, carrosserie, peinture, roues, éclairage, intérieur, CarPlay, prestations), le grade minimum et la taille de la zone, puis **Créer ici**.
- « Déplacer ici », modifier et supprimer depuis la même page ; un point avec un devis en cours ne peut pas être supprimé.
- **Seuls les mécaniciens voient les points** (zone orange au sol). Changements appliqués tout de suite, sans redémarrage.

Les points sont gardés en base (`meca_settings`, clé `workshops`). Le serveur vérifie à chaque action que le véhicule est sur le point et que le mécanicien est avec lui.

Déroulé : le mécanicien prend la voiture du client, la conduit sur le point et appuie sur **E** au volant (le véhicule est immobilisé pendant l'intervention) → l'atelier affiche le véhicule, son état et le catalogue compatible (seules les pièces qui existent sur ce modèle sont proposées) → aperçu en direct sur le véhicule (annulable) → ajout au devis → choix du client (le propriétaire est proposé en premier) → **Envoyer le devis**. Le client voit les lignes et le total, accepte ou refuse. Fermer l'atelier sans installer remet le véhicule tel qu'il était et **ne facture rien**.

## Atelier : caméra et modifications

- **Caméra** : clic droit maintenu + glisser (hors du panneau) pour tourner autour du véhicule, molette pour zoomer, double-clic pour recentrer.
- **Modifications** : toutes les pièces GTA du modèle (carrosserie, intérieur, portes, rampe lumineuse), palette complète (0-160, nacré),
  couleurs d'intérieur et de tableau de bord, jantes (dont roues F1), pneus (flancs, pare-balles), fumée, néons par côté, xénon, vitres,
  style de plaque, livrées (dont toit), éléments optionnels.
- **Plaque personnalisée** (catalogue, 5 000 $ par défaut) : 1 à 8 caractères, unique, seulement sur un véhicule avec carte grise.
  Le serveur change la plaque à l'installation (`elyzea_core:ChangePlate`) : carte grise, clés, coffre du véhicule (le contenu suit).
  Si la plaque est prise entre-temps, la ligne n'est pas posée et elle est remboursée.
- Les nouveaux articles du catalogue de `config.lua` s'ajoutent automatiquement aux bases déjà installées.

## Devis, paiement, factures

- Il n'existe pas de système de factures différées sur le serveur : le client **paie au moment où il accepte** (banque, puis liquide). L'argent va sur le compte société `mechanic` (elyzea_core).
- Le total est **recalculé par le serveur** à partir du catalogue en base ; l'interface ne fait qu'afficher.
- Le prix est **copié dans le devis** : changer un tarif ne touche que les nouveaux devis.
- Après acceptation, le mécanicien clique **Installer**. Chaque ligne est appliquée puis relue sur le véhicule. Ce qui n'a pas pu être installé est **remboursé** automatiquement ; la facture ne contient que ce qui a été posé.
- Devis payé jamais installé : remboursé après `Config.Quotes.installTimeout` (30 min) ou au redémarrage du serveur.
- Prestations (réparations, nettoyage, remorquage) : F6 › Véhicules › Devis de prestations (la dernière réparation faite est proposée).
- Remboursement d'une facture : tablette › Factures (permission « Annuler et rembourser »). Une seule fois par facture.
- Les modifications installées sont enregistrées dans `player_vehicles.mods` : elles restent après un rangement au garage et un redémarrage.

## CarPlay (installation payante)

- Le CarPlay existant de `elyzea_aura` (tablette F4 + télécommande du téléphone) est maintenant **réservé aux véhicules équipés** (`Config.CarPlay.RequireInstall = true` dans `elyzea_aura/config.lua`).
- L'installation est liée à l'**identifiant de carte grise** (`player_vehicles.id`), pas à la plaque ni au propriétaire : elle reste après une vente du véhicule ou un redémarrage.
- La vérification est faite **côté serveur** par `elyzea_aura` (`exports.elyzea_meca:HasCarPlay(plate)`) à chaque action (état, verrouillage, flotte, appel du véhicule) : impossible de la contourner depuis le client.
- Pas de double facturation : l'article « CarPlay » est refusé sur un véhicule déjà équipé. L'article « Réinstallation » existe mais est **désactivé** par défaut.
- La direction règle prix, activation et grade minimum dans **Catalogue et tarifs**, et y voit le nombre d'installations et les recettes.
- Si `elyzea_meca` est arrêté, le CarPlay est refusé partout (message clair) tant que `RequireInstall = true`.

## Dépannage

Demandes depuis le téléphone (Urgences › service Mécano), `/depannage`, ou `exports.elyzea_meca:CreateTowRequest(src, message, coords, opts)`. Statuts : en attente → acceptée → en route → sur place → diagnostic → devis → réparation → terminée (ou annulée). Chaque changement est journalisé avec son auteur. Le client est prévenu à l'acceptation, à l'arrivée et à la clôture. **Aucun système de renfort** entre mécaniciens.

## Tablette

- **Tableau de bord** : équipe en service, dépannages, devis ouverts, chiffres du jour.
- **Dépannage** : en cours et historique, accepter / rejoindre, GPS, statuts, clôture.
- **Véhicules clients** : recherche par plaque ou propriétaire, état relevé, performances installées, CarPlay, interventions, devis, factures.
- **Devis / Factures** : filtres, annulation (avec remboursement si déjà payé), remboursement.
- **Carte**, **Statistiques**.
- **Direction** : recrutement de la personne la plus proche (Accepter / Refuser), employés (promotion, rétrogradation, changement de grade, retrait), grades (créer, renommer, niveau, recrues, **désactiver sans casser les données**), permissions, historique, **Catalogue et tarifs**, **Points d'atelier**, garage de service.
- **Finance** : solde réel, entrées / sorties sur 7 jours, recettes par type, taux horaire par grade (jamais rétroactif), paiement d'un employé ou de tous (confirmation, recalcul, contrôle du solde, débit société, crédit banque même hors ligne, journal), transactions.

Les grades n'ont pas de salaire : le taux horaire est réglé dans Finance et chaque période de service est payée au taux et au grade qu'elle avait.

## Modifications faites dans d'autres ressources

- `elyzea_aura` : CarPlay réservé aux véhicules équipés (serveur + message côté client) ; les alertes Urgences du service mécano créent une demande de dépannage dans elyzea_meca. **La clé FiveManage de votre `config.lua` n'est pas dans le dépôt** : remettez la vôtre (`Headers.Authorization`).
- `elyzea_police/client/alt.lua` : le menu ALT accepte plusieurs ressources (EMS + Mécano).
- `admin_menu/server/staffjob.lua` : Mécano ajouté à l'onglet Métier staff.

## Exports serveur

`IsMechanic(src)`, `IsOnDuty(src)`, `HasPermission(src, perm)`, `GetOnDutyCount()`, `HasCarPlay(plate)`, `CreateTowRequest(src, message, coords, opts)`, et pour admin_menu : `AdminGrades`, `AdminSetGrade`, `AdminRemove`, `AdminInfo`, `AdminDuty`.

## Limites connues

- **Rien n'a été testé en jeu.**
- Aucun point d'atelier au départ : la direction les pose en jeu.
- Pas de stock de pièces : l'entreprise n'achète rien, les réparations et installations ne consomment rien.
- Finition de peinture (mat, métal, chrome…) : elyzea_core n'enregistre le type de peinture qu'avec une couleur personnalisée ; une finition peut revenir au réglage d'origine après une sortie de garage.
- Les véhicules sans carte grise (PNJ, véhicules de service) peuvent être réparés et modifiés, mais sans historique ni CarPlay.
- Pas de factures à payer plus tard (aucun système existant) : paiement immédiat à l'acceptation.
- Les mods sont relus côté client avant facturation ; un client modifié pourrait mentir sur le résultat, mais le serveur ne facture que des articles du catalogue, au prix du catalogue, sur un devis accepté.
- L'application HelpMécano du téléphone (missions PNJ) n'a pas été modifiée.

## Tests à faire en jeu

1. Démarrage : console `[MECA] Prêt`, tables créées, grades et catalogue de départ.
2. admin_menu › Métier staff › Mécano : se mettre Directeur ; F6 › prendre son service.
3. ALT sur un véhicule abîmé : actions proposées, barre de progression, historique du véhicule.
4. Tablette › Points d'atelier : créer 2 ou 3 points, déplacer, supprimer ; vérifier qu'un autre mécanicien les voit sans redémarrage et qu'un civil ne les voit pas ; arriver au volant sur un point, E : aperçu, annuler, fermer (véhicule remis à l'état d'origine et débloqué).
5. Devis avec un 2ᵉ joueur : refus, puis acceptation (argent débité, compte société crédité), installation, facture, rangement au garage et ressortie (mods conservés).
6. Installation partielle (une pièce esthétique qui ne se pose pas) : remboursement de la différence.
7. CarPlay : refusé avant installation (F4 et téléphone), installé, fonctionne, toujours actif après vente du véhicule et redémarrage ; second achat refusé.
8. Dépannage depuis le téléphone et `/depannage` : notification, G / I, GPS, statuts, clôture, historique.
9. Tablette : chaque page ; catalogue (prix, désactivation, nouvel article) ; finance (taux, paiement en ligne et hors ligne, payer tout le monde) ; grades (créer, désactiver, supprimer avec réaffectation) ; recrutement, promotion, rétrogradation, retrait.
10. Déconnexion pendant le service et pendant un devis ; redémarrage avec un devis payé non installé (remboursé).

> Mise à jour : si une version précédente a déjà tourné, les tables `meca_stock` / `meca_stock_moves` et les colonnes `part_code` / `part_qty` de `meca_catalog` restent en base mais ne servent plus. Vous pouvez les supprimer à la main ; la ressource n'y touche pas.
