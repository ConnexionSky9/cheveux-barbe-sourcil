# elyzea_presse — métier de journaliste

> **État : écrit et testé hors jeu** (banc d'essai serveur sur une vraie base MariaDB : 139 vérifications ;
> interface testée dans Chromium : 33 vérifications ; syntaxe Lua 5.4 / JS). **Rien n'a été testé sur un serveur FiveM
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
| 2 | Journaliste junior | + coffre, vendre des annonces |
| 3 | Journaliste | + publier sans validation |
| 4 | Journaliste confirmé | + valider / renvoyer les articles, archiver, flash info |
| 5 | Rédacteur en chef | + corriger / retirer tout article, tarifs des annonces, cartes de presse, direction (recruter, promouvoir, historique), finance |
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
  recherche, archives, petites annonces. Staff (`presse_manage`) : retirer un article ou une annonce.
- **Interviews** : ALT sur la personne › « Proposer une interview » (en service, micro sur soi). Elle **accepte ou refuse**,
  peut rester **anonyme** et arrêter quand elle veut (`/fininterview`). Fin aussi si éloignement, déconnexion, fin de service,
  45 min. Le journaliste écrit ses notes (bloc-notes ou tablette) ; date, journaliste, sujet et lieu sont gardés.
  **Aucune voix ni conversation n'est enregistrée.** « Article » depuis une interview : brouillon prérempli.
- **Photos et séquences** : appareil photo / caméra en main (inventaire › Utiliser), **G** viseur, molette zoom, clic
  photo / filmer, légende saisie. C'est une **fiche** (légende, lieu, heure, durée comptée par le serveur) :
  aucune image ni vidéo n'est capturée.
- **Flash info** : bandeau chez tous les joueurs, permission `flash`, en service, 1 par rédaction / 5 min et
  1 par auteur / 10 min. L'annonce d'un nouvel article à tout le serveur suit la même règle (seulement si celui qui publie a `flash`).
- **Annonces payantes** : ALT sur un joueur › « Proposer une annonce payante » ; il voit texte et prix (tarifs de la rédaction),
  paie en banque ou liquide, ou refuse. Argent sur le compte de la rédaction, transaction et commission du vendeur
  journalisées ; retrait / remboursement par la direction.
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

## Commandes et touches

`F6` / `/presse_menu` menu rapide (ou téléphone de service) · tablette depuis F6 · `ALT` interview / annonce ·
`G` viseur, `X` ranger le matériel (seulement avec l'objet en main) · `/journal` le journal · `/fininterview` arrêter une interview ·
`/presse_pos` position actuelle · `/presse_debloquer` rend le curseur.

## Configuration (`config.lua`)

Nom technique et compte (`Config.Job`, `Config.Society`), grades de départ, statuts, rubriques et limites des articles
(`Config.Articles`), annonce des publications, flash info, interviews, objets et matériel, animations, médias,
emplacements du vestiaire, garage (modèles de départ), annonces payantes (formules et prix de départ), journal,
permission staff. Tout ce qui dépend de la carte se place en jeu (aucune coordonnée codée en dur).

## Tests

- `python3 tests/run_server_bench.py` (paquets `lupa`, `pymysql`, base MariaDB de test vide `presse_test` : voir l'en-tête du fichier).
- `node tests/ui_nui.js [dossier des captures]` (paquet npm `playwright`).

## Tests à faire en jeu (au moins 3 joueurs : direction, journaliste, citoyen)

1. Démarrage sans erreur, tables `presse_*`, métier `journaliste` visible dans admin_menu › Métier staff › Presse.
2. Nommer la directrice, recruter un stagiaire (accepter / refuser), promouvoir, renvoyer ; reconnexion : grade gardé.
3. Placer les points ; garage (sortie, rangement, grade), coffre, matériel (prise / rendu, caméra verrouillée au stagiaire).
4. Vestiaire : enregistrer les 3 tenues (homme et femme), les mettre, « Tenue personnelle », fin de service ; essayer F3 / boutique
   pendant la tenue (refusé) ; se déconnecter en tenue puis revenir (vêtements d'avant).
5. Micro, caméra, appareil photo en main (animations, objets alignés), viseur, photo, séquence, légendes.
6. Article : brouillon, soumission, renvoi, validation, publication, annonce, journal pour un citoyen, archives, retrait staff.
7. Interview : refus, expiration, accord anonyme, notes, `/fininterview`, éloignement.
8. Annonce payante : refus, fonds insuffisants, banque, liquide, remboursement ; compte de la rédaction et commission.
9. Flash info et délais ; téléphone de service (préfixe 916) ; deuxième rédaction créée dans `/agences`.
10. `restart elyzea_presse` avec une interview en cours et une tenue portée ; vérifier les autres métiers (police, EMS, mécano, Dynasty 8).

## Limites connues

- Non testé en jeu. Les animations / objets tenus reprennent les valeurs des animations rpemotes « newsmic », « newscam »,
  « camera » : l'alignement des objets est à vérifier. Les modèles de véhicules de départ sont à vérifier sur le serveur.
- Photos et séquences : fiches RP, pas de capture d'image (il faudrait `screenshot-basic` et un hébergement d'images).
- Le coffre et les cartes passent par `elyzea_inventory` ; la tenue de service n'est pas un objet (comportement voulu).
- Les tenues du vestiaire sont vides au départ : la direction les enregistre en jeu.
