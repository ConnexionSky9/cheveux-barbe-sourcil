# elyzea_famille — moment intime, contraception, conception, grossesse, symptômes, accouchement, ventre, suivi de grossesse (version 0.8)

> **Non testé en jeu.** Ce qui a été vérifié hors du jeu :
> - règles de calcul : **68/68 tests** (`lua5.4 tests/test_regles.lua`), dont des tirages statistiques ;
> - code serveur réel exécuté contre une **vraie base MariaDB** (FiveM simulé) : **113/113 contrôles** (`python3 tests/integration_test.py`) ;
> - ventre (logique client, fonctions du jeu simulées) : **17/17** (`lua5.4 tests/test_ventre.lua`) ;
> - syntaxe Lua et JavaScript ; onglet admin affiché dans Chromium (`docs/famille/captures/`).
>
> Chiffres ci-dessus : V5. Résultats V7 (durées par trimestre, historique, réorganisation) : `docs/famille/LIVRAISON_V7.md`.
> **V8** (accouchement obligatoirement assisté par un EMS, application Aura fiabilisée, baiser) : `docs/famille/LIVRAISON_V8.md`
> — 171/171 contrôles d'intégration, 85/85 règles, 17/17 ventre ; protocole de test à deux joueurs au §7.

Première brique de l'écosystème famille (architecture : `docs/famille/AUDIT_ARCHITECTURE.md`).
Les modules suivants (découverte et suivi de grossesse, accouchement, enfants, crèche…) s'ajouteront dans cette même ressource.

## Organisation des fichiers (V7)
| Dossier | Contenu |
|---|---|
| `config/config.lua` | valeurs par défaut (remplacées par les réglages du menu admin, sans modifier le fichier) |
| `locales/fr.lua` | textes de l'historique de grossesse |
| `shared/regles.lua` | règles de calcul communes (durées, trimestres, risques, tests) |
| `server/` | commun : base de données et migrations (`base.lua`), réglages admin (`reglages.lua`), commandes staff (`staff.lua`) |
| `client/main.lua` | commun : interface, objets, `/grossesse` |
| `moment_intime/` | consentement, moment intime (serveur + client) |
| `contraception/` | préservatif, pilule, implant |
| `grossesse/` | conception, test, examen, suivi et trimestres, historique, accouchement, symptômes, ventre |
| `bebe/`, `equipement_bebe/` | renvoi vers la ressource séparée `elyzea_bebe_modele` (voir leur `README.md`) |
| (téléphone) | application **Grossesse** du téléphone légal Elyzea Aura (magasin « Appli ») : export serveur `SuiviGrossesse(source)`, mêmes données que `/grossesse` |
| `sql/install.sql` | tables (créées aussi automatiquement au démarrage) |
| `html/` | interface du panneau de grossesse et du moment intime |
| `tests/` | tests hors du jeu |

## Installation
1. Dossier `elyzea_famille` dans `Elyzea Base` ; `server.cfg` : `ensure elyzea_famille` (déjà ajouté, après les métiers).
2. Tables créées automatiquement au démarrage (`sql/install.sql` contient les mêmes requêtes). Console : `[elyzea_famille] Prêt (...)`.
3. Objets (dans `elyzea_inventory/shared/items.lua`, avec image) : `preservatif`, `pilule_contraceptive`, `implant_contraceptif`, `test_grossesse`.
4. **Obtenir les objets** (supérette existante d'admin_menu, aucun nouveau commerce) :
   - nouvelle supérette posée dans l'éditeur : rayon **Santé** inclus (préservatif 15 $, pilule 40 $, test de grossesse 25 $) ;
   - supérette déjà posée : Éditeur › PNJ › la supérette › **« Ajouter les produits de base »** (ajoute le rayon Santé) › Enregistrer ;
   - ou un PNJ **« Pharmacie »** (nouveau préréglage de l'éditeur, même système que la supérette) ;
   - l'implant n'est pas vendu : il se donne aux EMS (coffre de pharmacie EMS ou `/giveitem`).

## Utilisation
| Action | Comment |
|---|---|
| Proposer un moment intime | **ALT** sur la personne › *Proposer un moment intime* (ou `/intimite` face à elle) |
| Accepter / refuser | fenêtre de consentement (Échap = refuser ; sans réponse en 30 s = refus) |
| Arrêter à tout moment | **X** (pour les deux personnes) |
| Préservatif | case à cocher dans la demande, ou utiliser l'objet pendant le moment |
| Pilule | utiliser l'objet : 48 h de protection, renouvelable dans les 12 dernières heures |
| Implant | posé par un EMS en service : **ALT** sur le patient › *Poser un implant contraceptif* (le patient accepte) |
| Mon état (privé) | `/contraception` |
| Test de grossesse | utiliser l'objet : résultat privé ; négatif avant le délai de détection (60 min par défaut, menu admin), positif après (fiabilité 100 % par défaut) |
| Suivi de grossesse (privé) | `/grossesse` : jour, étape du ventre, terme ; nombre de bébés après un examen EMS |
| Examen de grossesse (EMS en service) | **ALT** sur la patiente › *Examen de grossesse* (elle accepte) : résultat sûr pour les deux |
| Accouchement (EMS en service) | **ALT** sur la patiente › *Accouchement* (elle accepte), à partir de 90 % de la grossesse : le ou les bébés apparaissent à côté d'elle |
| Naissance sans EMS | automatique 24 h après le terme, personnage connecté (réglable, 0 = jamais) |
| Symptômes | faim plus rapide, nausées, vomissements, démarche lourde : selon l'étape, chacun réglable dans le menu admin |
| Ventre | vêtement du pack posé par-dessus la tenue selon l'étape (à configurer : `/ventre_info`, voir LIVRAISON_V5) |
| Staff | `/famille_etat [id]` (contraception, grossesse, 5 derniers moments avec la tentative, la raison et le risque appliqué) — ACE `command.famille_etat` ; `/famille_fin [id] [naissance]` (met fin à la grossesse, sans ou avec bébé) — ACE `command.famille_fin` |
| Identification du ventre | `/ventre_info` (composants portés : n° global, collection, n° local), `/ventre_scan [composant]`, `/ventre_essai composant n° [texture] [collection]` (20 s) |

## Déroulé d'un moment intime
1. Demande → le serveur vérifie : deux personnages chargés, **majeurs** (date de naissance de la fiche), proches (2,5 m),
   ni à terre ni menottés, pas déjà occupés, **ne portant pas de bébé**, limite de demandes (3/min, 60 s entre deux demandes
   à la même personne) et **délai de 30 min** après un moment terminé (`delaiEntreMoments`).
2. L'autre personne accepte → nouvelle vérification → préservatif retiré **une seule fois** s'il a été coché.
3. Les deux personnages se placent face à face, étreinte (animation native GTA `mp_ped_interaction`), **fondu au noir** pendant la durée réglée (15 s par défaut, modifiable dans le menu admin).
   Aucune image explicite : l'écran reste noir. Commandes bloquées sauf la voix et X.
4. Fin (durée écoulée, X, déconnexion, ressource arrêtée, redémarrage) : chacun retrouve son état normal.

## Réglages depuis le menu admin (F10 › Autres › Famille)
Aucun second menu : un onglet **Famille** est ajouté au menu admin existant (`admin_menu`). Il n'apparaît qu'aux rangs ayant la permission
**`famille_manage`** (donnée automatiquement au rang `superadmin` ; à cocher dans Administration › Rangs pour les autres).

| Section | Réglages (bornes vérifiées par le serveur) |
|---|---|
| Durée | durée de l'écran noir (5–600 s, entre le minimum et le maximum), durée minimale et maximale autorisées, fondu (ms), étreinte visible avant le noir (ms) |
| Annulation | tentative de conception si le moment est arrêté avant la fin (oui/non), part minimale du moment à atteindre |
| Placement | distance entre les deux personnages, distance maximale pour proposer |
| Conditions | expiration de la demande, attente entre deux demandes, demandes par minute, délai entre deux moments |
| Risque de grossesse | probabilité volontaire, accidentelle (oui/non + valeur), jumeaux, triplés, durée de grossesse |
| Contraception | fiabilité préservatif / pilule / implant, durée et fenêtre de renouvellement de la pilule, durée de l'implant |
| Bébés et équipements (V4) | porte-bébé ventral, dorsal, poussette (activés ou non), pas de course avec la poussette, délai avant de ranger une poussette vide abandonnée, journal de diagnostic — transmis à `elyzea_bebe_modele` |

- **Enregistrer** : chaque valeur est revalidée par `elyzea_famille` (type, bornes, règles croisées : minimum ≤ durée ≤ maximum,
  jumeaux + triplés ≤ 100 %, renouvellement ≤ durée de la pilule). Une seule valeur invalide = rien n'est enregistré, message précis.
- Les valeurs sont stockées dans la table `rp_famille_reglages` et **réappliquées à chaque démarrage** ; `config/config.lua` n'est jamais modifié.
- **Valeurs par défaut** : supprime les valeurs enregistrées et revient à `config/config.lua`.
- **Moment déjà commencé** : il garde la durée et le fondu de son démarrage ; les nouveaux réglages valent pour les moments suivants.
- La permission est vérifiée **deux fois côté serveur** (admin_menu, puis `elyzea_famille`) ; un appel sans permission est refusé
  et journalisé (`rp_famille_logs`, action `suspect`). Chaque modification est journalisée (`reglages_enregistres`, `reglages_reinitialises`).
- X arrête toujours un moment, pour les deux personnes : ce n'est pas un réglage.

## Contraception et conception (valeurs par défaut, `config/config.lua`)
| Réglage | Défaut |
|---|---|
| Probabilité « volontaire » (les deux ont coché *essayer d'avoir un enfant*) | 35 % |
| Probabilité « accidentelle » (`accidentelle = false` : jamais) | 12 % |
| Fiabilité préservatif / pilule / implant | 98 % / 99 % / 99,5 % |
| Durée pilule / implant | 48 h / 30 jours |
| Jumeaux / triplés (tirés séparément, après une conception) | 3 % / 0,2 % |
| Durée de grossesse | 336 h (14 jours) |
| Moment arrêté avant la fin (X, déconnexion) | **aucune tentative** (`siInterrompu = false`) |
| Délai entre deux moments terminés (par personne) | 30 min |
| Âge maximum de la personne qui porte | 55 ans |
| Délai après une grossesse | 48 h |

Calcul (serveur, une seule fois par moment) : `probabilité = base × (1 − fiabilité)` de chaque protection active de la personne qui porte
(pilule, implant) et du préservatif. Exemple : accidentelle + préservatif + pilule = 12 % × 2 % × 1 % = 0,0024 %.
Règle RP : la personne de sexe féminin porte l'enfant, avec un partenaire de sexe masculin ; sinon aucune conception (l'adoption viendra plus tard).

Résultats enregistrés (`rp_conception_attempts.resultat`) : `conception`, `echec_contraception` (conception malgré une protection),
`protege`, `aucune`, `impossible` (+ raison : `meme_sexe`, `age_max`, `deja_enceinte`, `delai_apres_grossesse`), `interrompu`,
`accidentelle_desactivee`, `desactive`.
**Rien n'est annoncé aux joueurs** au moment de la conception : la grossesse se découvre par le test ou l'examen EMS,
puis se suit avec `/grossesse` (avancement calculé depuis les dates : il continue hors ligne et après un redémarrage).
Pas encore fait : symptômes, tenues de grossesse, accouchement (module suivant). Au terme, `/grossesse` affiche « Terme atteint ».

## Garanties techniques
- Une seule tentative par moment (contrainte unique SQL) ; une seule grossesse en cours par personne (index unique `active_key`).
- Grossesse créée dans une transaction (grossesse + événement + lien) : tout ou rien.
- Mise à jour depuis la 0.1 : la nouvelle colonne est ajoutée automatiquement au démarrage (données conservées).
- Objets retirés par le serveur après validation ; rendus si l'écriture en base échoue.
- Réponses de consentement vérifiées (identifiant de demande) ; toute réponse sans demande est journalisée (`rp_famille_logs`, action `suspect`).
- Déconnexion pendant un moment : interrompu, aucune conception. Redémarrage : moments en cours marqués interrompus.
- Dates en secondes Unix : la protection et le terme continuent hors ligne et après redémarrage.
- Fin de grossesse écrite une seule fois (mise à jour conditionnelle `active_key IS NOT NULL`) : deux accouchements simultanés ne créent pas deux fois les bébés.
- Ventre : la pièce d'origine est gardée ; la tenue enregistrée (ely_creator), les objets vêtements et « Ma tenue » (elyzea_clothing) lisent toujours la pièce d'origine (`ElyCloth.readReal`).

## Fichiers modifiés ailleurs
- `elyzea_inventory/shared/items.lua` : 4 objets ; `elyzea_inventory/html/img/` : 4 images (rendues dans Blender, `Outils_3D/icones`).
- `admin_menu/config.lua` : rayon « Santé » de la supérette, préréglage de PNJ « Pharmacie », permission `famille_manage`.
- `admin_menu/server/famille.lua` (nouveau), `admin_menu/html/famille.js` (nouveau), `admin_menu/fxmanifest.lua`, `admin_menu/html/index.html`
  (chargement de l'onglet), `admin_menu/server/main.lua` (migration : `famille_manage` donnée au rang superadmin).
- `elyzea_police/client/alt.lua` : fournisseurs `elyzea_famille` et `elyzea_bebe_modele` ; `elyzea_police/html/app.js` : 3 icônes.
- `Serveur cfg/server.cfg` : `ensure elyzea_famille`.
- V5 : `elyzea_core/lib/clothing.lua` (`ElyCloth.readReal`), `ely_creator/client/main.lua` (SaveOutfit), `elyzea_clothing/client/items.lua`
  (objet vêtement, « Ma tenue »), `admin_menu/html/famille.js` (champ texte).

## Limites connues
- **Animation** : animation native réutilisée (étreinte), pas une animation créée pour l'occasion ; le reste est un écran noir.
  Une animation duo sur mesure demanderait le squelette des personnages GTA (fichiers du jeu).
- La distance est vérifiée par le serveur seulement avec OneSync (sinon `verifierDistance = false` : seule la vérification du client reste).
- Ordonnance de pilule : prévue mais désactivée par défaut (`pilule.ordonnance = false`).
- Les supérettes déjà posées ne reçoivent pas le rayon Santé toutes seules : un clic « Ajouter les produits de base » dans l'éditeur.
