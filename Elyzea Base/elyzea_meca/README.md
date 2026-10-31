# elyzea_meca : métier Mécano

> **Aucun test en jeu n'a été fait.** Vérifié hors du jeu : syntaxe Lua et JS, simulation du vrai code serveur + client d'installation (`tests/run_install_sim.py`), interface et mini-jeux joués par un robot dans Chromium (`tests/ui_workshop.js`). Faites les tests de la liste en bas avant de l'ouvrir aux joueurs.

## Installation

1. Le dossier `elyzea_meca` est dans `Elyzea Base/`. `server.cfg` contient déjà `ensure elyzea_meca` (après `elyzea_ems`).
2. Dépendances : `oxmysql`, `elyzea_core` (obligatoires). Optionnelles : `elyzea_police` (menu ALT), `elyzea_inventory` (coffre d'atelier), `elyzea_aura` (téléphone : demandes de dépannage ; CarPlay libre, voir plus bas), `admin_menu` (onglet Métier staff).
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

- Placez-vous (à pied ou au volant) à l'endroit voulu, donnez un nom, cochez les rubriques (performances, carrosserie, peinture, roues, éclairage, intérieur, prestations), le grade minimum et la taille de la zone, puis **Créer ici**.
- « Déplacer ici », modifier et supprimer depuis la même page ; un point avec un devis en cours ne peut pas être supprimé.
- **Seuls les mécaniciens voient les points** (zone orange au sol). Changements appliqués tout de suite, sans redémarrage.

Les points sont gardés en base (`meca_settings`, clé `workshops`). Le serveur vérifie à chaque action que le véhicule est sur le point et que le mécanicien est avec lui.

Repérage : les points d'atelier ont un **blip** sur la carte et un **texte 3D** (mécaniciens seulement) ; le cercle est **orange** quand il est libre et **vert** quand un véhicule y est garé.

Déroulé : le mécanicien gare la voiture du client sur le cercle et appuie sur **E** (au volant, ou à pied à côté) — le véhicule est immobilisé, **moteur, phares et néons allumés** pendant l'intervention → l'atelier affiche le véhicule, son état et le catalogue compatible → chaque option cliquée **s'affiche tout de suite** sur le véhicule et s'ajoute au devis (re-cliquer la retire) ; la couleur personnalisée et la plaque s'affichent **pendant** qu'on les choisit / tape → choix du client (le propriétaire est proposé en premier) → **Envoyer le devis**. Le client voit les lignes et le total, accepte ou refuse. **Quitter l'atelier retire toujours tout ce qui n'a pas été payé et installé** : le véhicule revient à son état d'ouverture (ou à l'état de la dernière installation réussie), phares remis en automatique, véhicule débloqué. Rien n'est facturé sans acceptation du client.

## Atelier (v2) : interface, esthétique, performance

L'atelier s'ouvre avec **E** sur un point d'atelier (au volant, ou à pied à côté du véhicule garé dessus). Le véhicule est
immobilisé, moteur, phares et néons allumés. Interface en trois modes bien séparés :

| Mode | Contenu |
|---|---|
| **Esthétique** | Carrosserie (toutes les pièces GTA du modèle : pare-chocs avant / arrière, capot, coffre, bas de caisse, aileron, calandre, ailes, toit, portes, klaxon, rampe lumineuse…), Peinture et vitres (principale / secondaire, métallisé, mat, métal, chrome, nacré, couleur libre RVB, nacrage, livrées, livrée de toit, vitres teintées, style de plaque, plaque personnalisée), Roues (jantes et modèles, couleur des jantes, pneus à flancs, fumée, **pneus neufs**, **pneus DRIFT**), Éclairage (xénon et couleurs, néons par côté), Intérieur |
| **Performance** | Moteur, freins, transmission, suspension, turbo, blindage : pour chacun, niveau actuel, niveau proposé (jauge), prix de chaque niveau, effet sur le véhicule, état (Origine / Installé / Dans le devis / Non compatible) |
| **Prestations** | Réparations, nettoyage, remorquage |

- **Visualisation** : chaque option s'affiche tout de suite sur le véhicule ; la **caméra se place sur la pièce** choisie
  (avant pour le pare-chocs avant, arrière, côté, roue, toit, habitacle, moteur). Clic droit maintenu + glisser : tourner ;
  molette : zoom ; double-clic : recentrer.
- Un élément que le modèle ne propose pas est grisé (« Rien de compatible avec ce véhicule ») : rien ne casse.
- Le devis est classé **Esthétique / Performance / Prestations**, total recalculé par le serveur.
- Néons : palette fixe (`Config.Lights`, vérifiée par le serveur). Couleurs libres et effets multicolores des néons / phares /
  plaques : staff seulement (admin_menu › Véhicules › Personnalisation), comme avant.
- **Plaque personnalisée** : inchangée (1 à 8 caractères, unique, carte grise, clés et coffre suivent).

### Pneus
- **Pneus neufs** (prix par pneu) : « Les 4 pneus (une seule intervention) » ou un seul pneu (avant gauche, avant droit…,
  « crevé » indiqué). Le devis compte le bon nombre de pneus.
- **Pneus DRIFT** (badge DRIFT) : vrai comportement de dérive du jeu (`SetDriftTyresEnabled`, build 2944 ou plus ; ton
  `server.cfg` est en 3258). Seuls les véhicules équipés glissent : c'est le conducteur qui l'applique, d'après l'état du
  véhicule posé par le serveur ou la carte grise (`driftTyres`, déjà gérée par elyzea_core). « Pneus route » les retire.
  Sur un build trop ancien, l'option est grisée.

## Devis, paiement, installation par mini-jeux

1. Le mécanicien compose le devis puis **Envoyer le devis** au client (ou « Moi-même · je paie »).
2. Le client voit les lignes et le total, **accepte et paie** (banque puis liquide). Paiement unique, protégé contre le double clic.
3. Étapes affichées dans l'atelier : Devis envoyé → Paiement reçu → Installation → Remise des clés.
   **Aucune installation n'est possible avant le paiement** : le serveur refuse de donner une seule pièce d'un devis non payé.
4. **Commencer l'installation** : l'atelier se ferme, la liste des interventions s'affiche à gauche.

### Installation (`client/install.lua`)
Les lignes du devis sont regroupées en interventions, chacune avec **son point autour du véhicule** (flèche bleue pour la
prochaine, orange pour les autres, cercle au sol). Le mécanicien y va lui-même (plus de personnage qui court tout seul),
appuie sur **E** : le mini-jeu s'ouvre et le personnage joue le geste adapté. À la fin du mini-jeu, la pièce est posée sur
le véhicule, relue, puis comptée par le serveur.

| Intervention | Point | Mini-jeu |
|---|---|---|
| Pare-chocs avant / arrière | devant / derrière | glisser la pièce sur son gabarit, puis 3 agrafes |
| Capot, coffre et aileron, carrosserie gauche / droite, toit, blindage, plaque, intérieur | à la pièce (portière ouverte pour l'intérieur, capot / coffre ouverts) | serrer 5 vis (clic maintenu) |
| Phares, xénon, klaxon, rampe ; néons | avant (capot ouvert) ; côté gauche | brancher les fils sur la borne de leur couleur |
| Moteur et turbo ; freins ; transmission, suspension, échappement | avant (capot ouvert) ; roue avant droite (roues démontées) ; sous le véhicule | clé dynamométrique (3 serrages dans la zone verte) |
| Roues et pneus (jantes, pneus neufs, DRIFT, fumée, couleur des jantes) | roue avant gauche | **un seul mini-jeu** : les écrous de chaque roue ; sur le véhicule, chaque roue est démontée puis remontée l'une après l'autre. Un seul pneu demandé : seule cette roue |
| Peinture (+ nacrage, livrées) | à côté du véhicule | pulvériser la carrosserie : **la couleur passe de l'ancienne à la nouvelle sur le véhicule au fur et à mesure** (visible par le client) ; à 100 % la vraie couleur du jeu est posée |
| Vitres teintées | côté droit | lisser le film sur les vitres |

- Dessous de caisse : sans pont, le mécanicien est allongé sous le véhicule ; avec le **pont roulant** du point, le véhicule
  monte, il passe dessous, puis ressort avant la descente.
- Mini-jeux : simples, rapides (quelques secondes), sans pénalité. **Échap** ou ✕ : annuler (rien n'est posé, E pour
  recommencer). Fermés d'office après `Config.Install.gameTimeout` (120 s).
- Une pièce que le véhicule refuse (modèle incompatible) n'est pas facturée ; l'intervention continue.
- **X maintenu 1 s** : interrompre. Aussi en cas de mort, fin de service, éloignement (`maxDistance`), véhicule déplacé ou
  disparu, déconnexion, arrêt de la ressource : scène remise en état, véhicule libéré, devis toujours payé ;
  **Installer** reprend seulement ce qui reste. Sans reprise, remboursement automatique après `installTimeout` (30 min).
- Le client voit en direct (à droite de son écran) l'intervention en cours, son avancement et les pièces posées.

### Fin de l'intervention : remise des clés
- Quand tout est posé : le serveur facture les pièces réellement posées (le reste est remboursé), le mécanicien est prévenu.
- Le véhicule reste verrouillé et immobilisé. Une **flèche verte** au-dessus du client : **E** à côté de lui →
  animation de remise des clés des deux côtés, clés données au client, véhicule déverrouillé, intervention clôturée.
- Client parti, mécanicien déconnecté ou `handoverTimeout` (10 min) dépassé : le véhicule est rendu automatiquement.
- Devis pour soi-même : pas de remise de clés, le véhicule est libéré tout de suite.

### Retirés
- L'ancienne intervention animée (`client/interventions.lua` : personnage déplacé automatiquement autour du véhicule,
  pièces portées à l'établi, chandelles) et ses réglages (`Config.Interventions.durations / anims / props…`).
- Le **CarPlay** des installations mécano : rubrique, article (désactivé en base, historique conservé), permission
  « Installer le CarPlay ». Avec `Config.CarPlayFree = true` (défaut), `exports.elyzea_meca:HasCarPlay` répond oui pour
  tous les véhicules : le CarPlay d'elyzea_aura reste utilisable par tout le monde. Mettre `false` pour le réserver aux
  véhicules déjà équipés.

**Pont roulant (objet d'inventaire `pont_roulant`, 5 kg)** : inchangé (poser en utilisant l'objet à côté d'un véhicule garé
sur un point, **H** pour le reprendre, dessiné par le script). Il sert au mini-jeu « dessous de caisse ».

**Réglages** : `Config.Install` (distance du point, délai des mini-jeux, remise des clés, animations, objets en main),
`Config.Drift`, `Config.CarPlayFree`, `Config.Interventions.lift` / `liftItem` (pont roulant).

**Tests hors jeu** :
- `pip install lupa` puis `python3 tests/run_install_sim.py` : 71 vérifications (vrai code serveur + vrai client
  d'installation, natives imitées) : paiement avant toute pose, regroupement, 4 pneus / 1 pneu, DRIFT, peinture
  progressive, abandon, délai, double appui, X, reprise, véhicule déplacé, déconnexion, pont roulant, remise des clés, facture unique.
- `NODE_PATH=$(npm root -g) node tests/ui_workshop.js <dossier>` : 40 vérifications dans Chromium (interface réelle,
  chaque mini-jeu joué par un robot, délai, Échap, suivi client, remise des clés) + captures.

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

- `elyzea_aura` : le CarPlay demande `exports.elyzea_meca:HasCarPlay` (avec `Config.CarPlayFree = true`, tous les véhicules y ont droit) ; les alertes Urgences du service mécano créent une demande de dépannage dans elyzea_meca. **La clé FiveManage de votre `config.lua` n'est pas dans le dépôt** : remettez la vôtre (`Headers.Authorization`).
- `elyzea_police/client/alt.lua` : le menu ALT accepte plusieurs ressources (EMS + Mécano).
- `admin_menu/server/staffjob.lua` : Mécano ajouté à l'onglet Métier staff.

## Exports serveur

`IsMechanic(src)`, `IsOnDuty(src)`, `HasPermission(src, perm)`, `GetOnDutyCount()`, `HasCarPlay(plate)`, `CreateTowRequest(src, message, coords, opts)`, et pour admin_menu : `AdminGrades`, `AdminSetGrade`, `AdminRemove`, `AdminInfo`, `AdminDuty`.

## Limites connues

- **Rien n'a été testé en jeu** : rendu des animations, positions exactes des points autour de chaque modèle, effets du jeu
  (brume de peinture `scr_playerlamgraff`, animation de bombe de peinture `switch@franklin@lamar_tagging_wall`, objets
  `ng_proc_spraycan01b` / `p_car_keys_01`) : noms du jeu vérifiés à l'exécution, un élément absent est simplement ignoré.
- Peinture progressive : la couleur intermédiaire est une couleur libre (RVB) qui va de l'ancienne à la nouvelle ; la
  carrosserie change d'un bloc (le jeu ne permet pas de peindre panneau par panneau). La couleur cible d'une teinte de la
  palette est lue sur le véhicule (`GetVehicleColor`) : si le jeu renvoie une valeur inattendue, seul le dégradé est faux,
  la vraie couleur est toujours posée à 100 %.
- Jantes : GTA pose la même jante sur les 4 roues ; un « seul pneu » ne concerne que les pneus neufs.
- **Pas d'option « taille des jantes » ni « feux arrière » séparés** : la taille des jantes du jeu n'est ni synchronisée
  entre joueurs ni enregistrée par elyzea_core, et GTA n'a pas de pièce « feux arrière » distincte (ils font partie du
  pare-chocs / de la carrosserie sur la plupart des modèles).
- Rétroviseurs, autocollants : disponibles seulement quand le modèle les fournit comme pièce (souvent « Garnitures » ou livrées).
- Finition de peinture (mat, métal, chrome…) : elyzea_core n'enregistre le type de peinture qu'avec une couleur personnalisée ; une finition peut revenir au réglage d'origine après une sortie de garage.
- Les véhicules sans carte grise (PNJ, véhicules de service) peuvent être modifiés, mais sans historique ; leurs pneus DRIFT ne sont pas gardés après disparition du véhicule.
- Pas de factures à payer plus tard (aucun système existant) : paiement immédiat à l'acceptation.
- L'application HelpMécano du téléphone (missions PNJ) n'a pas été modifiée.

## Tests à faire en jeu

**Atelier et installation (v2)**
- a. Atelier : Esthétique / Performance / Prestations ; la caméra suit la pièce choisie ; un aperçu par option ; devis classé.
- b. Devis envoyé à un 2ᵉ joueur : « Commencer l'installation » absent tant qu'il n'a pas payé ; il paie : étape « Paiement reçu ».
- c. Installer : flèches autour du véhicule ; E sur chaque point ; chaque mini-jeu ; la pièce change sur le véhicule à la fin.
- d. Peinture : le 2ᵉ joueur regarde la couleur changer pendant le mini-jeu, et le suivi à droite de son écran.
- e. Pneus : « Les 4 pneus » → un mini-jeu, les 4 roues démontées / remontées l'une après l'autre ; un seul pneu → une roue.
- f. Pneus DRIFT : le véhicule glisse en virage ; un autre véhicule du même modèle sans DRIFT roule normalement ; ranger et ressortir du garage : toujours DRIFT.
- g. Échap pendant un mini-jeu, X maintenu, s'éloigner, déplacer le véhicule : rien n'est posé en trop, reprise possible.
- h. Fin : flèche verte sur le client, E : animation des clés des deux côtés, véhicule déverrouillé ; facture = pièces posées.
- i. Dessous de caisse avec un pont roulant posé : véhicule levé, mécanicien dessous, puis ressorti avant la descente.

**Général**

1. Démarrage : console `[MECA] Prêt`, tables créées, grades et catalogue de départ.
2. admin_menu › Métier staff › Mécano : se mettre Directeur ; F6 › prendre son service.
3. ALT sur un véhicule abîmé : actions proposées, barre de progression, historique du véhicule.
4. Tablette › Points d'atelier : créer 2 ou 3 points, déplacer, supprimer ; vérifier qu'un autre mécanicien les voit sans redémarrage et qu'un civil ne les voit pas ; arriver au volant sur un point, E : aperçu, annuler, fermer (véhicule remis à l'état d'origine et débloqué).
5. Devis avec un 2ᵉ joueur : refus, puis acceptation (argent débité, compte société crédité), installation, facture, rangement au garage et ressortie (mods conservés).
6. Installation partielle (une pièce esthétique qui ne se pose pas) : remboursement de la différence.
7. CarPlay : utilisable sur n'importe quel véhicule (F4 et téléphone) avec `Config.CarPlayFree = true` ; plus aucun article CarPlay à l'atelier.
8. Dépannage depuis le téléphone et `/depannage` : notification, G / I, GPS, statuts, clôture, historique.
9. Tablette : chaque page ; catalogue (prix, désactivation, nouvel article) ; finance (taux, paiement en ligne et hors ligne, payer tout le monde) ; grades (créer, désactiver, supprimer avec réaffectation) ; recrutement, promotion, rétrogradation, retrait.
10. Déconnexion pendant le service et pendant un devis ; redémarrage avec un devis payé non installé (remboursé).

> Mise à jour : si une version précédente a déjà tourné, les tables `meca_stock` / `meca_stock_moves` et les colonnes `part_code` / `part_qty` de `meca_catalog` restent en base mais ne servent plus. Vous pouvez les supprimer à la main ; la ressource n'y touche pas.
