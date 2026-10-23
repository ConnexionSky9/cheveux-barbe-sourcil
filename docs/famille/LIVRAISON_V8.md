# Famille, grossesse, bébé — livraison V8

> **Rien n'a pu être testé dans le jeu** (pas de client GTA V / FiveM dans l'environnement de développement).
> Ce document distingue : **corrections écrites** (§2), **tests automatiques réellement exécutés hors du jeu** (§6),
> et le **protocole de test à deux joueurs** à faire en jeu (§7, résultats attendus ; colonne « observé » à remplir).

## 1. Audit et sauvegarde
- Sauvegarde : étiquette git `sauvegarde-v7` (avant toute modification V8) ; paquet V7.
- `admin_menu` : votre version envoyée (`admin_menu.zip`, avec la presse et la permission vêtements) a été importée telle quelle,
  puis seul `html/famille.js` a été modifié. **Constat** : le `famille.js` de votre serveur était encore la version **V6**
  → la V7 n'était probablement pas (entièrement) installée sur le serveur.
- Systèmes réutilisés (aucun menu ni système parallèle) : menu admin (onglet Famille, permission `famille_manage`), inventaire
  `elyzea_inventory`, boutique de PNJ du menu admin (préréglage « Puériculture »), notifications `elyzea_core`, menu ALT commun,
  `elyzea_ems` (service, dispatch, dossier médical), téléphone légal Elyzea Aura, base MariaDB.
- La « deuxième image » de référence pour le portage **n'était pas jointe** (seul `admin_menu.zip` est arrivé) : la pose suit la
  description écrite du cahier.

### Causes trouvées
| Problème | Cause |
|---|---|
| Application : « Suivi indisponible » | Le message s'affichait pour **toute** erreur. Causes possibles relevées dans le code (vos journaux serveur ne sont pas disponibles ici) : (1) `elyzea_famille` d'une version antérieure à la V7, sans l'export `SuiviGrossesse` — probable vu le `famille.js` V6 ; (2) `config.lua` de l'Aura non mis à jour → l'application était retirée des applications installées ; (3) limite de fréquence commune avec `/grossesse` ; (4) erreur serveur non interceptée. Les quatre sont corrigées, et chaque cause a désormais son message et sa ligne dans la console. |
| Poussette : ne roule pas avec le bébé | Le bébé était attaché à la poussette, elle-même attachée au joueur : GTA synchronise mal ces **attaches en chaîne** ; la vérification serveur échouait et reposait le bébé au sol au bout de 3 essais. |
| Poussette : s'envole frein serré | **Régression V7 (de ma part)** : la collision restait active pendant le roulement et la mesure du sol sous les roues touchait la poussette elle-même, qui « montait » à chaque image puis restait en l'air une fois le frein serré. De plus, une poussette garée n'était figée que par le serveur (réglage non garanti chez chaque joueur). |
| Moment intime « câlin » | La paire `mp_ped_interaction` `kisses_guy_a/b` (depuis la V1) est la **bise de salutation** avec accolade de GTA Online. |

## 2. Corrections et ajouts (code écrit)
| § cahier | Réalisé |
|---|---|
| 2 Suivi | Application Aura fiabilisée (cause précise de chaque erreur, bouton Réessayer) ; **date de découverte, examens, prochaines étapes, procédure d'accouchement** en cours ; trois états (enceinte / non enceinte / erreur réelle) ; données privées ; une prise en charge EMS confirme la grossesse ; **diagnostic admin** « Vérifier son suivi » (Famille › Tests). |
| 3.1–3.2 Portage | « Dans les bras » **supprimé** (ancien nom = alias, aucune option / commande restante) ; une seule prise à la main : **« Prendre contre soi »** ; **ouverte à tous** (plus de réservation aux parents ni de `/bebe_confier`) ; filiation jamais modifiée ; impossible de prendre un bébé déjà porté (le porteur doit le poser) ; deux prises simultanées : une seule réussit (verrou serveur) ; sortie propre de la poussette. Porte-bébés proposés seulement quand ils sont équipés. |
| 3.3 Pose | Bébé **allongé à l'horizontale en travers du buste, tête vers le creux du bras gauche**, soutenu par les avant-bras croisés (modèle « porté » du bébé, couché, jambes repliées). Contrôle hors du jeu : aucune interpénétration avec le buste du mannequin (écart 2,9 cm homme, 1,3 cm femme). Réglage fin (cm / degrés, dont bascule et hauteur de tête) dans le menu admin. **GTA n'a aucune animation de bercement** (vérifié dans les 20 179 dictionnaires) : voir §8. |
| 4.1 Poussette + bébé | Bébé attaché **au pousseur** à l'endroit de la nacelle (plus d'attache en chaîne), suit le tangage dans les pentes ; ré-attache automatique pendant le roulement libre. |
| 4.2 Animation | **Jardinier poussant une tondeuse** (`timetable@gardener@lawnmow@`, buste droit, bras vers une poignée à hauteur de taille, haut du corps seulement : les jambes marchent normalement) au lieu du « sans-abri au chariot » (dos voûté). Ancienne au choix ; décalages de la poignée réglables. |
| 4.3 Frein | Collision coupée pendant le roulement ; état `garee / libre / renversee` transmis à tous ; **chaque joueur fige localement** une poussette garée ou renversée ; frein identique avec ou sans bébé ; la pente sans frein reste possible. |
| 5 Puériculture | Objets **biberon, couche, 3 pyjamas** (définitions d'inventaire + images rendues à partir des vrais modèles) ; ajoutés au préréglage **Puériculture** de la boutique existante (paiement, capacité d'inventaire, quantités, anti-doublon, prix éditables : déjà gérés par la boutique du menu admin). |
| 5 Vêtements | **Vraiment portés** : nouveaux modèles (pyjamas rose et bleu, en plus du blanc) ; habiller / déshabiller (ALT ou objet) ; l'ancien pyjama revient dans l'inventaire (refus si inventaire plein) ; enregistré en base, vu par tous, conservé après redémarrage. |
| 6 Besoins | Jauges persistantes **faim et soif** (une seule : le biberon de lait fait les deux), **fatigue**, **couche** ; biberon et couche **retirés une fois** au début du soin ; un soin à la fois par bébé et par joueur ; animation (biberon tenu en main — modèle 3D créé, aucun n'existe dans GTA ; accroupi près d'un bébé posé) ; sommeil : récupération plus rapide couché, **réveil automatique** propre ; « Coucher le bébé » ; notifications **au porteur**, sinon au pousseur, sinon aux parents connectés ; seuils, rappels espacés, aucun doublon, nouveau porteur prévenu tout de suite ; pause quand le bébé est « avec » un personnage déconnecté ; « Voir l'état du bébé » ; `/bebe_besoins` (staff) pour tester. |
| 7 Nouveau-né | À la naissance : **couche seule**, chevelure **« naissance »** (plus fournie, naturelle : capture `cheveux_v8.png`) ; les bébés existants gardent leur apparence enregistrée. Remarque honnête : l'apparence du nouveau-né vient d'un réglage (`Config.Grossesse.fin.apparenceBebe`) ; il n'existait **pas** d'héritage physique des parents, rien n'a donc été cassé ni ajouté sur ce point. |
| 8 Accouchement EMS | Parcours **obligatoire** : prise en charge (consentement) → évaluation → préparation → **péridurale** (proposée par l'EMS, choix de la patiente, ne fait jamais naître le bébé) → travail → naissance → **validation finale par l'EMS**, seule à créer le bébé (rattaché aux parents). EMS **en service vérifié par le serveur**, distance, ordre, délais ; transitions conditionnelles en base (jamais deux fois) ; reprise après déconnexion / redémarrage ; EMS hors service pendant un acte → étape annulée ; actes inscrits au **dossier médical EMS** (consultation, péridurale, accouchement). **Plus aucune naissance automatique.** Secours admin : refusé si un EMS est en service, **motif obligatoire**, journalisé ; `/famille_fin naissance` soumis aux mêmes règles. |
| 9 Baiser | Baiser natif (Lester et Georgina, épilogue du braquage du casino : `hs3_ext-20`), la personne qui accepte est placée face à l'autre, contre elle ; consentement, X pour arrêter, conception inchangés ; retour à la normale (détachement). Ancienne « bise » au choix. |
| 10 Admin | Nouvelles sections : **Soins du bébé**, **Accouchement assisté par un EMS** ; réglages animation de poussée, poussette, pose « contre soi », animation du moment intime ; boutons de test (grossesse de test, diagnostic, secours). Toutes les valeurs revalidées par le serveur ; « vitesse des besoins » et délais à 0 pour tester vite. |

## 3. Fichiers
**Créés** : `elyzea_famille/grossesse/server/accouchement.lua` · `elyzea_bebe_modele/server/soins.lua`, `client/soins.lua`,
`tests/test_soins.py` · `Outils_3D/bebe/scripts/controle_portage.py`, `icones_soins.py` · images `elyzea_inventory/html/img/`
`biberon.png`, `couche.png`, `vetement_bebe_blanc.png`, `_rose.png`, `_bleu.png` · `docs/famille/LIVRAISON_V8.md`, captures `*_v8*`.

**Modifiés** :
- `elyzea_famille` : `fxmanifest.lua`, `config/config.lua`, `server/base.lua` (migrations), `server/reglages.lua`, `shared/regles.lua`,
  `client/main.lua` (ALT EMS), `grossesse/server/grossesse.lua` (suivi), `grossesse/server/suivi.lua` (plus de naissance automatique),
  `grossesse/client/grossesse.lua`, `moment_intime/client|server/intimite.lua`, `sql/install.sql`, tests.
- `elyzea_bebe_modele` : `config.lua`, `fxmanifest.lua`, `server/bebes.lua`, `server/persistance.lua`, `client/portage.lua`,
  `client/poussette.lua`, `shared/modeles.lua` (généré), **`stream/` (217 fichiers, régénéré)**, tests.
- `elyzea_aura` : `server/main.lua`, `html/js/grossesse.js`, `html/js/i18n.js`.
- `elyzea_ems` : `server/api.lua` (export `AddTreatment`), `config.lua` (tarifs accouchement, péridurale).
- `elyzea_inventory/shared/items.lua` (5 objets) · `admin_menu/config.lua` (préréglage Puériculture) · `admin_menu/html/famille.js`.
- `Outils_3D/bebe/scripts` : `generate_baby.py`, `equipements.py`, `export_gta.py`, `validate.py`, `render_galerie.py`.

## 4. Base de données (aucune suppression, ajouts automatiques au démarrage)
```sql
ALTER TABLE `rp_pregnancies` ADD COLUMN `travail_etape` VARCHAR(24) NULL AFTER `terme_at`;   -- elyzea_famille
ALTER TABLE `rp_pregnancies` ADD COLUMN `travail` TEXT NULL AFTER `travail_etape`;
ALTER TABLE `rp_bebes` ADD COLUMN `besoins` TEXT NULL AFTER `endormi`;                        -- elyzea_bebe_modele
```
Sauvegarder la base (`mysqldump`) avant la mise à jour, par précaution. Les tenues des bébés sont désormais réécrites dans
`rp_bebes.apparence` (colonne existante).

## 5. Installation / redémarrage
1. Arrêter le serveur ; sauvegarder la base.
2. **Remplacer en entier** : `elyzea_famille/`, `elyzea_bebe_modele/` (`stream/` compris).
3. Remplacer les fichiers : `elyzea_aura` (`server/main.lua`, `html/js/grossesse.js`, `html/js/i18n.js` + ceux de la V7 si absents),
   `elyzea_ems/server/api.lua` et `elyzea_ems/config.lua`, `elyzea_inventory/shared/items.lua` + les 5 images,
   `admin_menu/config.lua` et `admin_menu/html/famille.js`.
4. Démarrer. Console : colonnes ajoutées, `Persistance : …`.
5. **Votre PNJ de puéricultrice existant** garde son catalogue enregistré : dans l'éditeur de PNJ (menu admin), ajoutez-lui
   `biberon`, `couche`, `vetement_bebe_blanc`, `vetement_bebe_rose`, `vetement_bebe_bleu` (prix au choix), ou réappliquez le
   préréglage « Puériculture ». Les nouveaux PNJ créés avec ce préréglage les ont directement.
6. Réglages pour tester vite : Famille › Soins (vitesse 60 = 1 h par minute), Accouchement (délais 0), Durée de grossesse (secondes).
7. Si un dossier médical EMS doit facturer l'accouchement : tablette EMS › Finance › Tarifs (accouchement 2 500 $, péridurale 600 $ par défaut).

Dépendances : inchangées (OneSync, `elyzea_core`, `elyzea_inventory`, `admin_menu`, `elyzea_police`, `elyzea_ems`, `elyzea_aura`).

## 6. Tests automatiques réellement exécutés (hors du jeu)
| Suite | Résultat |
|---|---|
| `elyzea_famille/tests/integration_test.py` (vraie base MariaDB, FiveM simulé) — dont accouchement EMS complet, refus non-EMS / patiente seule / trop tôt / délai, péridurale, EMS hors service pendant un acte, redémarrage au milieu, secours (EMS en service, sans motif, sans permission, autorisé), pas de seconde naissance, pas de naissance automatique, application, diagnostic, baiser | **171/171** |
| `elyzea_famille/tests/test_regles.lua` / `test_ventre.lua` | **85/85** / **17/17** |
| `elyzea_bebe_modele/tests/test_soins.py` — besoins, notifications au bon joueur sans répétition, nouveau porteur, biberon (une fois, un à la fois, objet 3D), couche (bébé posé, deux joueurs), vêtements (modèle changé, ancien rendu, inventaire plein), sommeil et réveil, pause garde, réglages | **25/25** |
| `test_persistance.py` (MariaDB) — dont migration `besoins`, besoins et tenue retrouvés après redémarrage, non-parent qui prend le bébé, filiation inchangée, pas d'arrachage | **23/23** |
| `test_portage.py` (prise unique, bébé attaché au pousseur, toujours dans la poussette 12 s plus tard) / `test_poussette.py` (état garée / libre transmis) | **84/84** / **25/25** |
| `test_client.lua` (options ALT : une seule prise, soins) / `test_physique.lua` | **14/14** / **15/15** |
| `elyzea_police/tests/test_alt.lua` | **10/10** |
| Contrôle de la pose « contre soi » sur le mannequin (`controle_portage.py`) | aucune interpénétration |
| Chaîne 3D : 217 fichiers convertis, **0 échec**, relus par CodeWalker ; **37/37** contrôles ; dictionnaire du corps 10 Mo (< 16 Mo) | OK |
| Application Aura et onglet admin affichés dans Chromium avec les vraies données du test (0 erreur JavaScript) | captures `*_v8*` |
| Syntaxe Lua / JavaScript de tous les fichiers modifiés | OK |

Limite de ces tests : ils vérifient la logique serveur et client avec FiveM simulé. Ils **ne peuvent pas** montrer la synchronisation
réelle des attaches par GTA, les animations, la physique du jeu ni le rendu des modèles en jeu.

## 7. Protocole de test à deux joueurs (A = joueuse, B = EMS / autre joueur)
Préparation : F10 › Famille : Durée de grossesse en **secondes** 20/20/20 ; Accouchement : délais 0 ; Soins : vitesse 60. B a le
métier EMS et se met en service. Notez pour chaque test : résultat observé, erreurs console (F8 et serveur).

| # | Action | Résultat attendu |
|---|---|---|
| 1 | Tests › votre ID › Démarrer une grossesse de test ; A ouvre Aura › Appli › Grossesse | Grossesse en cours, trimestre, découverte, prochaines étapes, historique |
| 2 | B (non enceinte) ouvre l'application | « Aucune grossesse confirmée » |
| 3 | A se déconnecte / reconnecte, rouvre | Mêmes informations ; en cas d'erreur, message précis + bouton Réessayer, et « Vérifier son suivi » dans le menu admin donne la cause |
| 4 | A (parent) : ALT sur un bébé › Prendre contre soi | Bébé couché en travers du buste, tête au creux du bras gauche |
| 5 | B (non parent) prend le bébé contre soi | Accepté |
| 6 | Diagnostic (Famille) après 5 | Responsables inchangés |
| 7 | A regarde B porter le bébé | Même pose vue par A |
| 8 | A et B choisissent « Prendre » en même temps | Un seul porteur |
| 9 | A tente de prendre le bébé porté par B | Refus (« pas disponible ») |
| 10 | Installer le bébé dans la poussette, Pousser, marcher | La poussette avance, bébé dedans |
| 11 | Pente, virages | Bébé reste dans la nacelle chez A et chez B |
| 12 | Observer la posture | Buste droit, mains vers la poignée ; arrêt propre en garant |
| 13 | Garer frein serré, marcher dedans, la heurter en voiture lentement | Elle ne bouge pas, ne s'envole pas |
| 14 | Garer dans une pente frein desserré | Elle roule et s'arrête ; jamais d'envol |
| 15 | Acheter biberon, couche, pyjama chez la puéricultrice | Paiement, objets reçus ; inventaire plein → remboursé |
| 16 | Inventaire | Objets présents avec images |
| 17 | ALT › Donner le biberon (bébé porté) | Biberon en main ~12 s, 1 biberon retiré, faim à 0 (« Voir l'état ») |
| 18 | Poser le bébé, ALT › Changer la couche | Accroupi, 1 couche retirée, couche à 0 |
| 19 | « Voir l'état » plusieurs fois ; Coucher le bébé | Sommeil monte éveillé, descend endormi, réveil seul |
| 20 | Attendre les seuils (vitesse 60) | Notification au porteur seulement, pas de répétition avant le rappel |
| 21 | Se déconnecter / redémarrer `elyzea_bebe_modele` | Besoins et pyjama conservés |
| 22 | Accouchement complet (test 23-25) | Nouveau-né en couche, chevelure « naissance » |
| 23 | A au terme sans EMS ; attendre | Aucune naissance ; A invitée à appeler les EMS |
| 24 | B : ALT › Accouchement : étape suivante (×6), « où en est-on ? » | Étapes dans l'ordre, au dossier médical (tablette › Patients) |
| 25 | B : proposer la péridurale ; A accepte / refuse | Choix enregistré ; ne fait pas naître ; naissance sans écran noir si acceptée |
| 26 | Secours (Famille › Tests) avec B en service, puis sans motif, puis par un joueur sans permission | Refusé dans les trois cas ; accepté seulement sans EMS en service, avec motif |
| 27 | Relancer l'étape suivante / le secours après la naissance | Aucun second bébé |
| 28 | A propose un moment intime à B | Baiser (pas d'accolade) |
| 29 | Observer | Face à face, alignés, chez A et chez B |
| 30 | X pendant le moment ; puis une emote | Arrêt propre, personnages libres |
| 31–34 | Console F8 et serveur ; autres ressources (téléphone, EMS, police, inventaire) ; redémarrer le serveur ; bébés existants | Aucune erreur ; tout est conservé ; fonctions famille existantes intactes |

## 8. Problèmes restants (honnêtes)
- **Aucun test en jeu.** Le protocole §7 est à faire.
- **Pose de portage** : GTA n'a pas d'animation de bercement ; les bras croisés natifs sont la plus proche. Pour une animation sur
  mesure (bras qui enveloppent vraiment le bébé), il faut le squelette des personnages (`mp_f_freemode_01.yft`,
  `mp_m_freemode_01.yft`, extraits de votre jeu avec OpenIV / CodeWalker) : envoyez-les si vous le souhaitez.
- **Baiser** : clips `hs3_ext-20` vérifiés présents dans le jeu ; leur rendu exact (contact des visages) est à confirmer en jeu,
  l'écart est réglable (Famille › Positionnement) et l'ancienne animation reste disponible.
- **Animation de poussée** : la tondeuse est vérifiée présente dans le jeu, mais l'alignement des mains sur la poignée est à
  vérifier ; décalages réglables dans le menu admin.
- Sens de la bascule du bébé dans une pente (poussette poussée) : calculé, à confirmer en jeu.
- **« Suivi indisponible »** : sans vos journaux serveur, la cause exacte sur votre serveur n'est pas prouvée ; toutes les causes
  trouvées dans le code sont corrigées et la console indique désormais la cause précise.
- Le PNJ de puéricultrice existant doit recevoir les nouveaux articles dans l'éditeur (§5.5).

## 9. Retour arrière
Supprimer `elyzea_famille` et `elyzea_bebe_modele`, puis remettre ceux du paquet V7 (ou `git checkout sauvegarde-v7 -- …`), ainsi que
les fichiers V7 d'`elyzea_aura`, `elyzea_ems`, `elyzea_inventory`, `admin_menu`. Les colonnes ajoutées peuvent rester (ignorées).
