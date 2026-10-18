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
| **E** au volant sur un point d'atelier, ou à pied à côté du véhicule garé dessus, ou **F6 › Catalogue d'amélioration** près du point | Ouvre l'atelier pour ce véhicule |
| **G / I** | Accepter / refuser la dernière demande de dépannage |
| `/depannage <message>` | Tout le monde : demander un dépanneur |
| `/meca_pos` | Affiche votre position et le cap dans la console (aide) |

## Points d'atelier (placés en jeu)

Tablette › Direction › **Points d'atelier** (permission « Garage et points d'atelier ») : autant de points que vous voulez (30 au maximum, `Config.WorkshopMax`), n'importe où.

- Placez-vous (à pied ou au volant) à l'endroit voulu, donnez un nom, cochez les rubriques (performances, carrosserie, peinture, roues, éclairage, intérieur, CarPlay, prestations), le grade minimum et la taille de la zone, puis **Créer ici**.
- « Déplacer ici », modifier et supprimer depuis la même page ; un point avec un devis en cours ne peut pas être supprimé.
- **Seuls les mécaniciens voient les points** (zone orange au sol). Changements appliqués tout de suite, sans redémarrage.

Les points sont gardés en base (`meca_settings`, clé `workshops`). Le serveur vérifie à chaque action que le véhicule est sur le point et que le mécanicien est avec lui.

Repérage : les points d'atelier ont un **blip** sur la carte et un **texte 3D** (mécaniciens seulement) ; le cercle est **orange** quand il est libre et **vert** quand un véhicule y est garé.

Déroulé : le mécanicien gare la voiture du client sur le cercle et appuie sur **E** (au volant, ou à pied à côté) — le véhicule est immobilisé, **moteur, phares et néons allumés** pendant l'intervention → l'atelier affiche le véhicule, son état et le catalogue compatible → chaque option cliquée **s'affiche tout de suite** sur le véhicule et s'ajoute au devis (re-cliquer la retire) ; la couleur personnalisée et la plaque s'affichent **pendant** qu'on les choisit / tape → choix du client (le propriétaire est proposé en premier) → **Envoyer le devis**. Le client voit les lignes et le total, accepte ou refuse. **Quitter l'atelier retire toujours tout ce qui n'a pas été payé et installé** : le véhicule revient à son état d'ouverture (ou à l'état de la dernière installation réussie), phares remis en automatique, véhicule débloqué. Rien n'est facturé sans acceptation du client.

## Atelier : caméra et modifications

- **Caméra** : clic droit maintenu + glisser (hors du panneau) pour tourner autour du véhicule, molette pour zoomer, double-clic pour recentrer.
- **Modifications** : toutes les pièces GTA du modèle (carrosserie, intérieur, portes, rampe lumineuse), palette complète (0-160, nacré),
  couleurs d'intérieur et de tableau de bord, jantes (dont roues F1), pneus (flancs), fumée, néons par côté, xénon, vitres,
  style de plaque, livrées (dont toit), éléments optionnels.
- **Plus de pneus pare-balles** à l'atelier. **Couleur libre (RVB)** : peinture et fumée seulement. Néons : palette fixe
  (`Config.Lights`, vérifiée par le serveur) ; xénon : 13 couleurs GTA. Les couleurs libres et effets **multicolores animés**
  des néons, phares, plaques et peintures sont **réservés au staff** (admin_menu › Véhicules › Personnalisation).
- **Plaque personnalisée** (catalogue, 5 000 $ par défaut) : 1 à 8 caractères, unique, seulement sur un véhicule avec carte grise.
  Le serveur change la plaque à l'installation (`elyzea_core:ChangePlate`) : carte grise, clés, coffre du véhicule (le contenu suit).
  Si la plaque est prise entre-temps, la ligne n'est pas posée et elle est remboursée.
- Les nouveaux articles du catalogue de `config.lua` s'ajoutent automatiquement aux bases déjà installées.

## Devis, paiement, factures

- Il n'existe pas de système de factures différées sur le serveur : le client **paie au moment où il accepte** (banque, puis liquide). L'argent va sur le compte société `mechanic` (elyzea_core).
- Le total est **recalculé par le serveur** à partir du catalogue en base ; l'interface ne fait qu'afficher.
- Le prix est **copié dans le devis** : changer un tarif ne touche que les nouveaux devis.
- Après acceptation, le mécanicien clique **Installer** : il **réalise l'intervention en jeu** (voir « Interventions animées »). Chaque pièce est posée au moment où l'animation la monte, puis relue sur le véhicule. Ce qui n'a pas pu être installé est **remboursé** automatiquement ; la facture ne contient que ce qui a été posé.
- Devis payé jamais installé : remboursé après `Config.Quotes.installTimeout` (30 min) ou au redémarrage du serveur.
- Prestations (réparations, nettoyage, remorquage) : F6 › Véhicules › Devis de prestations (la dernière réparation faite est proposée).
- Remboursement d'une facture : tablette › Factures (permission « Annuler et rembourser »). Une seule fois par facture.
- Les modifications installées sont enregistrées dans `player_vehicles.mods` : elles restent après un rangement au garage et un redémarrage.

## Devis pour soi-même (custom personnel)
- Dans la liste des clients de l'atelier (et du devis de prestations F6), **« 🔧 Moi-même · je paie »** : le mécanicien se fait son propre devis.
- Pas de fenêtre d'acceptation : à la confirmation, le total est prélevé tout de suite (banque puis liquide) et versé à l'entreprise, puis **Installer** lance l'intervention comme pour un client. Pièces non posées : remboursées.
- Pas de commission sur ses propres devis (`Config.Quotes.selfCommission`). Désactivable avec `Config.Quotes.allowSelf = false`.

## Interventions animées (installation d'un devis payé)
« Installer » ne pose plus tout d'un coup : l'atelier se ferme et le mécanicien fait le travail, dans un ordre logique,
seulement pour les pièces achetées. Les prix, le paiement (à l'acceptation, une seule fois) et la facture ne changent pas.

| Travail | Ce qui se passe |
|---|---|
| Transmission, échappement, suspension, freins | véhicule levé **une seule fois** pour tout : chandelles sous les roues (ou ton pont, voir plus bas), mécanicien allongé sur le chariot sous le véhicule (scénario du jeu `WORLD_HUMAN_VEHICLE_MECHANIC`), puis redescente progressive |
| Freins | roues avant (et arrière si `brakesRear`) : accroupi, pneu retiré, étrier en main, remontage |
| Jantes / pneus | roue par roue (avant gauche, avant droite, arrière gauche, arrière droite) : cric si le véhicule n'est pas levé, desserrage, **pneu retiré**, roue portée à l'établi, nouvelle roue, serrage |
| Moteur, turbo, bloc, filtre, barres | capot ouvert, penché sur le moteur, clé en main ; le capot reste ouvert entre ces travaux |
| Capot | ouverture, démontage, **l'ancien capot disparaît**, porté à l'établi, nouveau capot, remontage (la nouvelle pièce apparaît), fixation, fermeture |
| Pare-chocs, calandre, aileron, coffre, ailes, bas de caisse, portières | à l'endroit de la pièce : démontage, ancienne pièce à l'établi, nouvelle pièce, fixation |
| Blindage | soudure des deux côtés |
| Peinture, vitres teintées | tour du véhicule (préparation), la teinte apparaît à la fin |
| Phares, néons, plaque, intérieur, CarPlay | phares capot ouvert, néons accroupi sur le côté, plaque à l'arrière, intérieur et CarPlay portière ouverte (tablette) |

**Pont roulant (objet d'inventaire `pont_roulant`, 5 kg)**
- **Poser** : un mécanicien en service, à pied à côté d'un véhicule garé sur un point d'atelier, **utilise** l'objet (inventaire) : le pont est posé sous ce véhicule (orienté comme lui, enregistré, visible par tous) et l'objet quitte l'inventaire. Un seul pont par point.
- **Reprendre** : n'importe quel mécanicien en service, à côté du pont, appuie sur **H** (texte « H · Reprendre le pont roulant ») ou tape `/meca_pont_retirer` : le pont revient dans **son** inventaire. Impossible pendant une intervention ou sans place dans l'inventaire.
- Sur un point équipé : le véhicule monte jusqu'à laisser ~1,95 m sous la caisse, le mécanicien **passe dessous** et travaille debout bras levés (scénario `PROP_HUMAN_MOVIE_BULB`, repli `WORLD_HUMAN_WELDING`) ; le pont redescend à hauteur des roues pour les freins et les roues, puis au sol. Le mécanicien sort toujours de dessous avant une descente.
- Le pont est **dessiné par le script** : 2 colonnes jaunes, 2 chariots et **4 bras**. Au repos les bras sont repliés le long des colonnes ; au début de l'intervention ils pivotent sous les 4 points de levage, puis les chariots montent avec la voiture ; à la fin ils se replient (état partagé par le véhicule : tous les joueurs voient la même chose). Le jeu de base n'a pas de modèle de pont garanti : si ta map ou un pack en fournit un, mets son nom dans `Config.Interventions.lift.models`.
- Supprimer un point équipé rend aussi l'objet.
- Points sans pont : chandelles et chariot, comme avant.
- Obtenir l'objet : `pont_roulant` se donne comme les autres objets (menu staff / give).

**Déplacements et sécurité du personnage**
- Le mécanicien **fait le tour** du véhicule par les coins (chemin le plus court) au lieu de marcher contre la carrosserie ; s'il est bloqué, il recalcule un trajet (navmesh) ; **aucune téléportation**. Sous un véhicule levé au pont, il passe directement dessous.
- **Anti-chute** : pendant toute l'intervention, la dernière position sûre est mémorisée ; si le personnage passe sous le sol ou tombe, il y est replacé immédiatement. Ragdoll désactivé pendant le travail, rétabli à la fin. Les scénarios ne téléportent plus le personnage.

**Sécurité et multijoueur**
- Une seule intervention par point d'atelier (un autre mécanicien ne peut pas l'ouvrir) et par mécanicien.
- Le serveur ne donne les propriétés d'une pièce qu'**au moment de la pose**, une seule fois ; il compte lui-même les pièces posées. Le client ne peut ni se déclarer payé, ni obtenir une pièce non achetée.
- Occupants descendus et portes verrouillées pendant le travail ; véhicule, objets et animations en réseau : tout le monde voit la même scène.

**Interruptions** (touche **X**, mort, fin de service, éloignement, véhicule déplacé ou détruit, déconnexion, arrêt de la ressource) :
objets supprimés, véhicule redescendu à sa place exacte, capot / pneus remis, portes refermées et déverrouillées, contrôles rendus.
Les pièces déjà posées restent posées ; le devis reste payé : **rouvrir l'atelier et « Installer » reprend la suite**.
Sans reprise : après `installTimeout`, ou au redémarrage du serveur, les pièces posées sont facturées et enregistrées, le reste remboursé.
Déconnexion du mécanicien : le serveur supprime ses objets et fait remettre le véhicule en état par le joueur qui le contrôle.

**Réglages** : `Config.Interventions` dans `config.lua` (vitesse `speed` = 0.6 par défaut, marche `walkSpeed`, durées, animations, objets et leur position en main, levage, `lift.armSwing`).
- Néons : proposés seulement si le véhicule accepte des néons (certains véhicules de packs ne les affichent pas). Une pièce qui ne se pose pas est réessayée une fois ; sinon la console F8 indique la valeur attendue et la valeur relue.
- **Pont élévateur** : le jeu de base n'a pas, à ma connaissance, de pont animé fiable. Par défaut : chandelles (`prop_carjack`) et véhicule levé de 50 cm, mécanicien sur chariot. Si ta map contient un modèle de pont, mets son nom dans `lift.model` (et `lift.height`, `lift.platformMoves` si c'est un plateau qui doit monter avec la voiture) : le véhicule monte alors à `lift.height` et le mécanicien travaille debout dessous.
- `underHeadingOffset` / `underOffset` : si le mécanicien s'allonge dans le mauvais sens ou trop loin, ajuste ces valeurs.
- Les objets en main (`props`) ont une position réglable ; les modèles `imp_prop_impexp_*` viennent du DLC Import/Export (inclus dans le build du serveur). Un modèle absent est simplement ignoré.

**Tests hors jeu** (logique, natives imitées) : `pip install lupa` puis `python3 tests/run_intervention_sim.py` (85 vérifications : ordre, pose au bon moment, facturation unique, verrous, interruption + reprise, véhicule détruit, objets absents, carrosserie abîmée, déconnexion, redémarrage, marche réelle autour du véhicule sans contact ni téléportation, pont roulant posé sous un véhicule / utilisé / repris avec H, passage sous le véhicule, chute rattrapée).

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

**Interventions animées**
- a. Devis « Freins + Transmission » : chandelles, véhicule levé, mécanicien allongé dessous, freins aux roues avant, redescente. Vérifier la position allongée (régler `underHeadingOffset` / `underOffset` si besoin).
- b. Devis « Capot » sur un véhicule intact : capot ouvert, disparaît, porté, réapparaît avec la nouvelle pièce ; sur un véhicule cabossé : pas de démontage visuel, carrosserie inchangée.
- c. Devis « Jantes » : 4 roues, pneu retiré puis remis à chaque roue, jante changée à la première roue.
- d. Devis « Moteur + Turbo + Peinture » : capot ouvert une fois pour les deux, peinture à la fin.
- e. Appuyer sur X pendant le moteur : tout est rangé ; rouvrir l'atelier, Installer : seul le reste est refait ; facture = devis.
- f. Un 2ᵉ mécanicien essaie d'ouvrir le même point pendant l'intervention : refusé.
- g. Le client regarde depuis à côté : il voit le véhicule monter, les pièces, les animations.
- h. Déconnexion du mécanicien pendant le levage : véhicule redescendu par un autre joueur proche, objets supprimés.
- i. Donner `pont_roulant`, l'utiliser à côté d'un véhicule garé sur un point : pont visible par un 2ᵉ joueur ; H à côté : il revient dans l'inventaire. Devis transmission + freins : voiture en haut, mécanicien debout dessous, puis roues à mi-hauteur.
- j. Pièces à l'opposé (aile gauche puis aile droite) : le mécanicien contourne par l'avant ou l'arrière, sans traverser ni se téléporter.


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
