# Système famille — livraison V7 (restructuration, durées par trimestre, suivi, ALT bébé, collision de la poussette)

> **Rien n'a pu être testé dans le jeu** (pas de client GTA V / FiveM dans l'environnement de développement).
> Ce document distingue : **corrections écrites** (§2), **vérifications techniques et tests automatisés réellement exécutés**
> hors du jeu (§5), et **tests à faire en jeu** (§6). Aucune fonction n'est déclarée validée en jeu.

## 1. Audit et sauvegarde
- Sauvegarde avant toute modification : étiquette git `sauvegarde-v6` (commit `387d91e`) et paquet `elyzea_bebe_v6_complet.zip`.
- `admin_menu` : la version que vous avez envoyée (`admin_menu.zip`) a été importée telle quelle **avant** toute modification
  (commit `c3a4813`) ; seul `html/famille.js` a ensuite été modifié (il était identique à la version V6).
- Systèmes utilisés (aucun système parallèle créé) : base MariaDB via `elyzea_core` ; téléphone **blackphone** (applications =
  un fichier par application) ; menu ALT commun `elyzea_police/client/alt.lua` ; menu admin `admin_menu` (onglet Famille,
  permission `famille_manage`, revérifiée par `elyzea_famille`).

Causes trouvées :
| Problème | Cause |
|---|---|
| Durées : impossible de faire une grossesse rapide | une seule durée globale en jours, minimum 1 ; plusieurs réglages à minimum 5 ; un champ vidé était remplacé par la valeur par défaut (piège `or`) |
| ALT sur le bébé | (1) le rayon du curseur ignorait les **objets** (le bébé est un objet) ; (2) un objet touché n'était comparé qu'aux personnages ; (3) un joueur en face passait toujours avant une cible plus proche ; (4) la première ressource de la liste (bijouterie, banque) gagnait toujours |
| On traverse la poussette | le modèle 3D **n'avait aucun modèle de collision** (vérifié à la relecture du fichier `.ydr`) ; en plus, la collision était coupée pendant le roulement |

## 2. Ce qui a été fait (corrections écrites)
| Priorité | Réalisé |
|---|---|
| 1 Durées | durées **par trimestre** (T1, T2, T3) + **unité** (secondes / minutes / heures / jours) ; **0 accepté** (transition immédiate) ; total et durées cumulées affichés et mis à jour pendant la saisie ; validation côté serveur (négatif, texte, unité inconnue refusés ; champ vide = valeur actuelle conservée) ; appliqué sans redémarrage ; grossesses en cours : progression acquise conservée (le trimestre ne recule jamais), étapes restantes recalculées, chaque étape et la naissance **une seule fois** (mises à jour conditionnelles en base) ; naissance automatique réglable (délai 0 possible) ; boutons **grossesse de test** / **fin de test** (sans bébé, historique gardé) ; minimum 0 pour les autres durées où cela a un sens (moment intime, fondu, nausées, accouchement, pilule, implant, délai avant nouvelle grossesse, abandon de poussette) |
| 2 ALT bébé | correction dans le **menu ALT commun** : objets inclus dans le rayon, la cible la plus proche gagne entre joueurs et ressources ; aucun menu parallèle |
| 3 Collision | **vraie collision ajoutée au modèle** de la poussette (asset corrigé) : 4 boîtes (châssis + roues, nacelle, capote, poignée), matériau plastique, drapeaux standard (collision avec personnages, véhicules, objets) ; collision gardée pendant le roulement (objet figé déplacé par le script) |
| 4 Suivi | application **Grossesse** dans le téléphone existant (blackphone) : statut, trimestre, barre, temps écoulé, durée totale, avant le trimestre suivant, avant l'accouchement, date de début (date du serveur), nombre de bébés si connu, **historique** persistant (titre, description, date) ; états « terminée » et « aucune grossesse » ; données privées (seul le personnage concerné) ; `/grossesse` conservé en secours, même contenu |
| 5 Réorganisation | sous-dossiers réels par domaine, manifeste mis à jour, contrôle automatique du manifeste ; textes de l'historique dans `locales/fr.lua` |

## 3. Fichiers
### Déplacés (`elyzea_famille`, contenu inchangé sauf mention)
| Avant | Après |
|---|---|
| `config.lua` | `config/config.lua` |
| `server/consentement.lua`, `server/intimite.lua`, `client/intimite.lua` | `moment_intime/server/…`, `moment_intime/client/intimite.lua` |
| `server/contraception.lua` | `contraception/server/contraception.lua` |
| `server/conception.lua`, `server/grossesse.lua`, `server/suivi.lua` | `grossesse/server/…` |
| `client/grossesse.lua`, `client/ventre.lua`, `shared/ventre.lua` | `grossesse/client/…`, `grossesse/shared/ventre.lua` |
Restent : `server/base.lua`, `server/reglages.lua`, `server/staff.lua`, `client/main.lua`, `shared/regles.lua`, `html/`, `sql/`, `tests/`.
`bebe/` et `equipement_bebe/` contiennent un `README.md` : le bébé, les porte-bébés et la poussette restent dans la ressource
**séparée** `elyzea_bebe_modele` (ses modèles 3D, ses exports et le menu ALT dépendent de son nom ; la fusionner casserait les
bébés enregistrés).

### Créés
- `elyzea_famille/locales/fr.lua`, `bebe/README.md`, `equipement_bebe/README.md`
- `blackphone/html/js/apps/grossesse.js` (application)
- `elyzea_police/tests/test_alt.lua`
- `docs/famille/LIVRAISON_V7.md`, captures `docs/famille/captures/*_v7.png`, `telephone_grossesse_*.png`

### Modifiés
- `elyzea_famille` : `fxmanifest.lua` (0.7.0), `shared/regles.lua` (durées, avancement, étapes franchies, textes), `config/config.lua`,
  `server/base.lua` (migrations), `server/reglages.lua`, `grossesse/server/suivi.lua`, `grossesse/server/grossesse.lua`,
  `grossesse/server/conception.lua`, `moment_intime/server/intimite.lua`, `grossesse/client/grossesse.lua`, `client/main.lua`,
  `html/app.js`, `html/style.css`, `sql/install.sql`, `README.md`, tests
- `admin_menu/html/famille.js` (unité, total, cumuls, tests de grossesse)
- `blackphone/client/main.lua` (relais vers `elyzea_famille`), `blackphone/html/index.html`, `blackphone/fxmanifest.lua`
- `elyzea_police/client/alt.lua`
- `elyzea_bebe_modele/client/poussette.lua`, `elyzea_bebe_modele/stream/` (modèles régénérés ; poussettes avec collision)
- `Outils_3D/bebe/scripts/export_gta.py` (collision), `Outils_3D/bebe/convertisseur/Program.cs` (affiche la collision à la relecture)

## 4. Base de données (migrations)
Faites **automatiquement** au démarrage d'`elyzea_famille` (ajout de colonnes seulement, aucune suppression, aucune donnée modifiée) :
```sql
ALTER TABLE `rp_pregnancies` ADD COLUMN `trimestre` TINYINT NOT NULL DEFAULT 1 AFTER `due_at`;
ALTER TABLE `rp_pregnancies` ADD COLUMN `terme_at` BIGINT NULL AFTER `trimestre`;
```
L'historique utilise la table existante `rp_pregnancy_events`. Les nouveaux réglages sont des lignes de `rp_famille_reglages`.
Grossesses déjà en cours : elles passent aux nouvelles durées ; le trimestre atteint est calculé au premier passage du suivi,
les étapes déjà dépassées sont inscrites une fois dans l'historique.

## 5. Vérifications réellement exécutées (hors du jeu)
| Test | Résultat |
|---|---|
| `elyzea_famille/tests/integration_test.py` — vrais fichiers serveur, **vraie base MariaDB**, FiveM simulé, temps virtuel | **145/145** |
| dont manifeste : fichiers existants, ordre de chargement, aucun fichier oublié (après réorganisation) | 3/3 |
| dont **cahier test 1** : grossesse de 60 s (3 × 20 s) : 2e trimestre à 20 s, 3e à 40 s, terme et naissance à 60 s, un seul bébé, rien en double ensuite (test 50-51) | OK |
| **test 2** : 2e trimestre à 0 (test 52) | OK |
| **test 3** : trimestres tous à 0 : transitions immédiates, une seule fois, pas de boucle (test 53) | OK |
| **test 4** : durées modifiées pendant la grossesse (raccourcies, allongées : progression conservée) (test 54) | OK |
| **test 5** : déconnexion et reconnexion (test 55) | OK |
| **test 6** : redémarrage de la ressource (test 56) | OK |
| **test 7** : application et historique (en cours / terminée / aucune) (tests 51, 58) | OK |
| **test 8** : joueur non autorisé, valeurs invalides ou vides (test 57) | OK |
| `elyzea_famille/tests/test_regles.lua` (règles de calcul) | **85/85** |
| `elyzea_famille/tests/test_ventre.lua` | **17/17** |
| **test 9** (logique seulement) : `elyzea_police/tests/test_alt.lua` — bébé visé, bébé à côté d'un joueur, joueur plus proche, plusieurs ressources, poussette visée, objet du décor, hors de portée ; l'**ancienne** version échoue à 5 de ces contrôles | **10/10** |
| `elyzea_bebe_modele` : portage 83/83, poussette 23/23, persistance (MariaDB) 19/19, physique 15/15, client 11/11 | tous OK |
| **test 10** (fichier seulement) : chaîne 3D relancée ; **148/148** fichiers convertis ; relecture CodeWalker : `ely_bebe_poussette_graphite.ydr` et `_sable.ydr` → « **collision composite (4 formes)** », matériau plastique, collision avec les personnages ; contrôles du modèle **37/37** | OK |
| Onglet admin rendu dans Chromium (sections « Durée et progression de grossesse » et « Tests de grossesse », total et cumuls mis à jour à la saisie, 0 erreur JavaScript) | `captures/menu_admin_progression_v7.png`, `menu_admin_tests_v7.png` |
| Application Grossesse rendue dans Chromium avec le **vrai** `index.html` du blackphone et les données produites par le test d'intégration (0 erreur) | `captures/telephone_grossesse_en_cours.png`, `_terminee.png`, `_aucune.png` |
| Syntaxe Lua (`luac -p`) et JavaScript (`node --check`) des fichiers modifiés | OK |

## 6. Tests à faire en jeu (non faits)
1. F10 › Famille : unité **secondes**, 20 / 20 / 20, enregistrer. Bloc « Tests de grossesse » : votre ID › *Démarrer*. Téléphone › Grossesse :
   1er trimestre, puis 2e (≈ 20 s), 3e (≈ 40 s), terme et naissance (≈ 60 s) : **un seul** bébé ; historique complet.
2. Même chose avec 20 / 0 / 20, puis 0 / 0 / 0.
3. Pendant une grossesse de test, changer les durées : elle continue sans revenir en arrière.
4. Se déconnecter au 1er trimestre, revenir après 1 min : étapes passées, un seul bébé. Même chose avec `restart elyzea_famille`.
5. Un joueur sans `famille_manage` : onglet Famille refusé.
6. **ALT** sur le bébé posé, dans la poussette, porté, à côté d'un autre joueur, près d'une bijouterie / banque : le menu du bébé s'ouvre.
7. **Poussette garée** : marcher dedans → on est arrêté (et on ne la déplace pas, elle est figée). La pousser, la garer, la lâcher dans une pente :
   elle roule, s'arrête aux obstacles ; un autre joueur ne la traverse pas quand elle roule. Le bébé reste dans la nacelle.
8. Se reconnecter, `restart elyzea_bebe_modele` : poussette revenue garée, toujours solide, ALT fonctionne.
9. Vérifier que la collision ne gêne pas pour prendre le bébé ou pousser (si oui : réduire les boîtes dans `export_gta.py`, `POUSSETTE_BOITES`).

## 7. Problèmes restants / limites
- **Pendant la poussée**, la poussette est attachée au personnage : sa collision est coupée (sinon elle se bloquerait contre son propre
  pousseur). Un autre joueur peut donc la traverser pendant qu'elle est poussée. Garée, renversée ou en roulement : solide.
- Collision en **boîtes** (forme simplifiée) : vérifiée dans le fichier, **pas vue en jeu**. Elle ne pousse pas les joueurs quand elle roule
  (physique simulée : elle s'arrête devant eux).
- Pas de calendrier RP trouvé sur le serveur : les dates viennent de l'heure du serveur.
- `blackphone` et `elyzea_police` ont été modifiés à partir de la version du dépôt : si vos versions en service sont différentes,
  envoyez-les (sans secrets) et je reporte les modifications dessus. Changements : `blackphone` 3 fichiers + 1 nouveau, `elyzea_police` 1 fichier.
- Les fichiers `.ydr` du bébé ont aussi été régénérés (même source, même résultat aux contrôles) ; seule la poussette change réellement.

## 8. Installation / mise à jour
1. Arrêter le serveur. Sauvegarder la base (`mysqldump`), par précaution.
2. **Supprimer puis remplacer en entier** `Elyzea Base/elyzea_famille/` (les anciens fichiers `server/conception.lua`, etc. ont été déplacés :
   les laisser créerait des doublons) et `Elyzea Base/elyzea_bebe_modele/` (`stream/` compris).
3. Remplacer : `admin_menu/html/famille.js` ; `blackphone/client/main.lua`, `blackphone/html/index.html`, `blackphone/fxmanifest.lua`,
   ajouter `blackphone/html/js/apps/grossesse.js` ; `elyzea_police/client/alt.lua`.
4. Démarrer. Console : `[elyzea_famille] Prêt (...)` ; les colonnes `trimestre` et `terme_at` sont ajoutées automatiquement.
5. Réglages par défaut : 112 h par trimestre (≈ 14 jours au total) ; à changer dans F10 › Famille › « Durée et progression de grossesse ».

Dépendances : FXServer avec **OneSync** ; `elyzea_core`, `elyzea_inventory`, `admin_menu`, `elyzea_police` (ALT), `blackphone` (application ;
sans lui, `/grossesse` reste disponible), `elyzea_bebe_modele` ; `elyzea_ems` facultatif.

Retour arrière : `git checkout sauvegarde-v6 -- "Elyzea Base/elyzea_famille" "Elyzea Base/elyzea_bebe_modele" "Elyzea Base/blackphone" "Elyzea Base/elyzea_police/client/alt.lua" "Elyzea Base/admin_menu/html/famille.js"`
après avoir supprimé le dossier `elyzea_famille` (ses nouveaux sous-dossiers ne seraient pas retirés), ou les fichiers du paquet V6. Les colonnes ajoutées peuvent rester (ignorées par la V6).
