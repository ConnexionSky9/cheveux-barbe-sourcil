# elyzea_presse — métier de journaliste

> **État : écrit et testé hors jeu** (banc d'essai serveur sur une vraie base MariaDB : 203 vérifications ;
> interfaces testées dans Chromium : 34 (métier) + 16 (téléphone de service) + 5 (admin_menu) ; syntaxe Lua 5.4 / JS). **Rien n'a été testé sur un serveur FiveM
> ni à plusieurs joueurs.** Suivez « Tests à faire en jeu » avant l'ouverture. Détail : `docs/presse/LIVRAISON.md`.

Même socle que les métiers Elyzea existants (repris d'`elyzea_dynasty` / `elyzea_meca`) : métier `elyzea_core`,
grades et permissions en base, tablette, F6, téléphone de service, paie au taux horaire depuis le compte de la société,
plusieurs rédactions possibles avec `elyzea_agences`.

## Installation

1. Dépendances : `elyzea_core`, `elyzea_inventory` (obligatoires) ; `elyzea_agences`, `elyzea_police` (menu ALT),
   `elyzea_jobphone`, `elyzea_clothing`, `admin_menu`, `ely_creator` (utilisées si présentes).
2. `server.cfg` : `ensure elyzea_presse` après `elyzea_dynasty`, avant `elyzea_jobphone` (déjà ajouté).
3. Base de données : tables `presse_*` créées au démarrage (`sql/install.sql` pour une installation manuelle,
   `sql/uninstall.sql` pour revenir en arrière). Aucune table existante n'est modifiée.
4. Objets : `presse_micro`, `presse_camera`, `presse_appareil`, `presse_bloc`, `presse_carte` (déjà déclarés dans
   `elyzea_inventory/shared/items.lua` ; images `newsmic.png` et `newscam.png` existantes, les autres avec une icône).
5. Premier démarrage : métier `journaliste` (« Weazel News ») et ses 6 grades créés, compte de société `journaliste`.
6. Nommer la direction : admin_menu › **Métier staff › Presse** (ou `/agences` › Presse › Nommer le directeur).
7. La direction place les locaux **en jeu** (tablette › Locaux, garage, tenues) : véhicules, place de sortie, coffre,
   matériel, vestiaire, présentoirs du journal ; elle enregistre les tenues et règle les véhicules.

## Grades de départ (modifiables dans la tablette)

| Niveau | Grade | Permissions principales |
|---|---|---|
| 1 | Stagiaire | service, tablette, rédiger et soumettre, interviews, photos / séquences, matériel, vestiaire, garage |
| 2 | Journaliste junior | + coffre, Planning des annonces (envoi manuel, prime) |
| 3 | Journaliste | + publier sans validation |
| 4 | Journaliste confirmé | + valider / renvoyer les articles, archiver, flash info |
| 5 | Rédacteur en chef | + corriger / retirer tout article, tarif des annonces, primes, annulation des commandes, cartes de presse, direction (recruter, promouvoir, historique), finance |
| 6 | Directeur de la rédaction | toutes (dont grades, permissions, paie, locaux) |

Taux horaires de départ dans `Config.DefaultGrades` ; ensuite Finance (tablette). Le salaire « automatique »
d'elyzea_core reste à 0 pour ce métier : la direction paie les heures de service depuis le compte de la rédaction
(comme Dynasty 8 et le mécano) — pas de second circuit de paiement.

## Fonctionnement

- **Articles** : brouillon (privé) → soumis → publié → archivé ; renvoyé à l'auteur avec une note. Version contrôlée
  (deux modifications en même temps : la seconde est refusée), titre déjà publié ces 7 jours refusé (doublon),
  délai entre deux publications d'un même auteur, historique de chaque action. Correction d'un article publié tracée.
  Archivage automatique après 30 jours (réglable). Photos et séquences jointes en crédit.
- **Journal (tout le monde)** : `/journal` ou un présentoir (E) : articles de toutes les rédactions, rubriques,
  recherche, archives. Staff (`presse_manage`) : retirer un article.
- **Interviews** : ALT sur la personne › « Proposer une interview » (en service, micro sur soi). Elle **accepte ou refuse**,
  peut rester **anonyme** et arrêter quand elle veut (`/fininterview`). Fin aussi si éloignement, déconnexion, fin de service,
  45 min. Le journaliste écrit ses notes (bloc-notes ou tablette) ; date, journaliste, sujet et lieu sont gardés.
  **Aucune voix ni conversation n'est enregistrée.** « Article » depuis une interview : brouillon prérempli.
- **Photos et séquences** : appareil photo / caméra en main (inventaire › Utiliser), **G** viseur, molette zoom, clic
  photo / filmer, légende saisie. C'est une **fiche** (légende, lieu, heure, durée comptée par le serveur) :
  aucune image ni vidéo n'est capturée.
- **Flash info** : bandeau chez tous les joueurs, permission `flash`, en service, 1 par rédaction / 5 min et
  1 par auteur / 10 min. L'annonce d'un nouvel article à tout le serveur suit la même règle (seulement si celui qui publie a `flash`).
- **Annonces commandées par les entreprises** (voir la section dédiée ci-dessous) : application « Annonce » du téléphone de service
  pour toutes les entreprises, application « Planning » pour les journalistes, file d'attente unique, bandeau au-dessus de la mini-carte.
- **Matériel** : point « Matériel » : un exemplaire gratuit de chaque (micro, bloc-notes, appareil photo, caméra à partir du grade 2),
  marqué « service », à rendre. Utilisable seulement par un journaliste en service autorisé.
- **Carte de presse** : délivrée par la direction (cartes de presse), nominative ; « Utiliser » la montre aux personnes à moins de 3 m
  avec sa validité vérifiée par le serveur (révoquée, titulaire parti, porteur différent).
- **Vestiaire** : tenues de journaliste, de reporter de terrain et de présentation (grade 3+), enregistrées par la direction
  à partir de ce qu'elle porte (homme et femme, packs compris) ; « Tenue personnelle » ou fin de service : vêtements d'avant.
  La tenue n'est pas un objet : `elyzea_clothing` refuse les échanges de vêtements-objets pendant ce temps (state bag `elyUniform`).
- **Garage** : véhicules de service par grade (fourgon, véhicule de rédaction, transport du matériel, hélicoptère), modèles modifiables.
- **Direction et finance** : identiques aux autres métiers (recrutement avec accord, employés, grades, permissions, historique,
  taux horaires, commission, paie, transactions). Règles vérifiées par le serveur : on n'agit que sur un grade inférieur au sien.
- **Plusieurs rédactions** : `/agences` › Presse › Nouvelle agence (ex. `ls_times` · Los Santos Times). Chacune a ses grades,
  employés, compte, points, articles (le journal public les rassemble) et son téléphone de service.

## Annonces commandées (téléphone de service)

| Qui | Où | Quoi |
|---|---|---|
| Une entreprise (patron : droit d'accès au compte de l'entreprise) | Téléphone de service › **Annonce** | Choisir la rédaction (prix affiché), texte de **150 caractères** max. (compteur « 124/150 », emojis comptés comme on les voit), fréquence (30 min, 1 h, 1 fois par jour à 19 h 00), dates de début et de fin, récapitulatif (nombre de diffusions, prix unitaire, total), paiement **depuis le compte de l'entreprise** ; « Mes commandes » |
| Journaliste en service (permission `ads`) | Téléphone de service › **Planning** | Annonces à envoyer maintenant (dont en retard), en file, aujourd'hui, prochaines, envoyées ; client, montant, prime ; bouton **Envoyer l'annonce** (actif seulement à l'heure) |
| Direction de la rédaction (`ads_manage`) | Tablette › Diffusion › **Annonces commandées** | Tarif à l'unité, ouverture des commandes, prime par grade, commandes (annulation contrôlée avec remboursement) |
| Staff (`presse_manage`) | admin_menu › **Annonces presse** | Activer / couper, durée d'affichage, fréquence du planificateur, délai laissé aux journalistes, retard maximal, essais avant échec ; rédactions, commandes, diffusions, file (pause, relancer, annuler + rembourser, relancer les remboursements) |

Règles (toutes vérifiées par le serveur) :
- **Prix** = nombre de diffusions réellement programmées × prix unitaire de la rédaction, calculé par le serveur ; le client renvoie le total et le nombre
  qu'il a vus et le serveur refuse s'ils ont changé. Le prix est gardé dans la commande : un nouveau tarif ne change pas une commande payée.
- **Paiement** : compte de société de l'entreprise cliente (`elyzea_core`, débit atomique) → compte de la rédaction, tracé dans les deux journaux.
  Fonds insuffisants : refusé, rien n'est créé. Double clic / renvoi réseau : la même clé de demande ne crée et ne paie qu'une seule commande.
- **Calendrier** (heure du serveur) : créneaux à :00 / :30 (30 min), à :00 (1 h) ou à 19 h 00 (quotidien), seulement à venir, entre les deux dates incluses ;
  31 jours et 1 500 diffusions au maximum. Chaque diffusion est une ligne en base (`presse_ad_slots`, heure unique par commande).
- **Envoi** : à l'heure, si un journaliste de la rédaction est en service, la diffusion est proposée dans son Planning ; sinon elle part toute seule.
  Proposée mais non envoyée après le délai (5 min par défaut), ou plus personne en service : envoi automatique. Le premier journaliste qui appuie l'envoie ;
  les autres voient « Déjà envoyée par … ».
- **Prime** (montant fixe par grade, plafonné au prix de l'annonce) : seulement pour un envoi manuel, une seule fois, **après** l'affichage réel,
  prise sur le compte de la rédaction et tracée. Aucune prime pour un envoi automatique.
- **File d'attente unique** : une seule annonce à l'écran ; la suivante attend la fin de l'affichage (10 s par défaut, réglable). Les états sont en base :
  au redémarrage, une annonce coupée pendant l'affichage repart (elle n'est jamais comptée comme faite), une commande coupée pendant le paiement est annulée et remboursée.
  Erreur d'affichage : nouvel essai ; après 3 échecs, « en échec » dans admin_menu (bouton Relancer). Trop de retard (2 h par défaut) : annulée et remboursée.
- **Affichage** : juste au-dessus de la mini-carte (rectangle réel donné par `admin_menu`), nom de la rédaction puis texte (accents, espaces, emojis gardés).

## Commandes et touches

`F6` / `/presse_menu` menu rapide (ou téléphone de service) · tablette depuis F6 · `ALT` interview / annonce ·
`G` viseur, `X` ranger le matériel (seulement avec l'objet en main) · `/journal` le journal · `/fininterview` arrêter une interview ·
`/presse_pos` position actuelle · `/presse_debloquer` rend le curseur.

## Configuration (`config.lua`)

Nom technique et compte (`Config.Job`, `Config.Society`), grades de départ, statuts, rubriques et limites des articles
(`Config.Articles`), annonce des publications, flash info, interviews, objets et matériel, animations, médias,
emplacements du vestiaire, garage (modèles de départ), annonces commandées (`Config.Annonces` : 150 caractères, fréquences, heure de la diffusion quotidienne, durée max., prix par défaut, réglages globaux par défaut), journal,
permission staff. Tout ce qui dépend de la carte se place en jeu (aucune coordonnée codée en dur).

## Tests

- `python3 tests/run_server_bench.py` (paquets `lupa`, `pymysql`, base MariaDB de test vide `presse_test` : voir l'en-tête du fichier).
- `node tests/ui_nui.js`, `node tests/ui_phone.js`, `node tests/ui_admin.js` `[dossier des captures]` (paquet npm `playwright`).

## Tests à faire en jeu (au moins 3 joueurs : direction, journaliste, citoyen)

1. Démarrage sans erreur, tables `presse_*`, métier `journaliste` visible dans admin_menu › Métier staff › Presse.
2. Nommer la directrice, recruter un stagiaire (accepter / refuser), promouvoir, renvoyer ; reconnexion : grade gardé.
3. Placer les points ; garage (sortie, rangement, grade), coffre, matériel (prise / rendu, caméra verrouillée au stagiaire).
4. Vestiaire : enregistrer les 3 tenues (homme et femme), les mettre, « Tenue personnelle », fin de service ; essayer F3 / boutique
   pendant la tenue (refusé) ; se déconnecter en tenue puis revenir (vêtements d'avant).
5. Micro, caméra, appareil photo en main (animations, objets alignés), viseur, photo, séquence, légendes.
6. Article : brouillon, soumission, renvoi, validation, publication, annonce, journal pour un citoyen, archives, retrait staff.
7. Interview : refus, expiration, accord anonyme, notes, `/fininterview`, éloignement.
8. Annonces : commande depuis le téléphone d'un patron d'entreprise (150 / 151 caractères, emojis), fonds insuffisants, Planning d'un journaliste en service,
   envoi manuel + prime, envoi automatique sans journaliste, plusieurs annonces à la même heure, durée réglée dans admin_menu, `restart elyzea_presse` pendant un affichage.
9. Flash info et délais ; téléphone de service (préfixe 916) ; deuxième rédaction créée dans `/agences`.
10. `restart elyzea_presse` avec une interview en cours et une tenue portée ; vérifier les autres métiers (police, EMS, mécano, Dynasty 8).

## Limites connues

- Non testé en jeu. Les animations / objets tenus reprennent les valeurs des animations rpemotes « newsmic », « newscam »,
  « camera » : l'alignement des objets est à vérifier. Les modèles de véhicules de départ sont à vérifier sur le serveur.
- Photos et séquences : fiches RP, pas de capture d'image (il faudrait `screenshot-basic` et un hébergement d'images).
- Le coffre et les cartes passent par `elyzea_inventory` ; la tenue de service n'est pas un objet (comportement voulu).
- Les tenues du vestiaire sont vides au départ : la direction les enregistre en jeu.
