# Actes médicaux en mini-jeux (EMS)

> **Rien de ce qui suit n'a été testé en jeu.** Ce qui a été vérifié, hors du jeu, est listé au § 8 avec les résultats
> réels. Les tests en jeu (§ 9) restent à faire avant la mise en production.

Les actes médicaux ne sont plus de simples barres de progression. Chaque acte est un court mini-jeu
de difficulté intermédiaire, réglable. Le résultat est vérifié par le serveur, puis l'acte est enregistré dans le dossier médical.

---

## 1. Audit des ressources existantes, et ce qui est réutilisé

| Besoin | Ressource existante | Utilisation |
|---|---|---|
| Framework (joueurs, métiers, notifications, rappels client ↔ serveur) | `elyzea_core` | Le même que tout l'EMS (`Ely.callback`, `Notify`, `ShowTextUI`). |
| EMS : grades, permissions, service, actes, coma | `elyzea_ems` | Les actes passent par le point d'entrée existant `ems:req` : permission, service et limite de fréquence sont vérifiés là. Les permissions des grades se règlent dans la tablette (Direction › Grades). |
| Menu d'interaction | `elyzea_police` (menu **ALT**, exports `AltOptions` / `AltSelect`) | Les nouveaux actes y sont ajoutés. Aucun nouveau menu. Les mêmes actes sont aussi dans **F6 › Actions médicales** et dans la fenêtre d'examen. |
| Inventaire | `elyzea_inventory` | Matériel vérifié avant l'acte et retiré à la réussite (`Search`, `RemoveItem`, `AddItem` pour rendre en cas d'erreur). 5 objets ajoutés (§ 5). |
| Dossiers médicaux | `elyzea_ems` (postes des dossiers, `ems_treatments`) | Nouvelles sections « Examens et actes », « Blessures localisées », « Vaccinations » dans le dossier existant. Chaque acte reste facturable (`ems_treatments`). |
| Laboratoire | `elyzea_ems/server/lab.lua` | La prise de sang crée le **même** prélèvement que l'ancien bouton. L'analyse se lance toujours depuis la tablette › Laboratoire. |
| Maladies et blessures | `elyzea_ems/server/health.lua` | Les vaccins protègent des maladies existantes (rhume…). L'ancienne « Blessure à la jambe » (chute) est retrouvée par la radiographie et guérie par l'attelle. |
| Grossesse, implant | `elyzea_famille` | 4 exports ajoutés (échographie, pose, retrait, état de l'implant). Durée de l'implant inchangée (réglée dans l'onglet Famille). |
| Menu d'administration | `admin_menu` › onglet **Santé** (permission `health_manage`) | Nouvelle partie « Actes médicaux (mini-jeux) » dans le même onglet. |
| Moteur de mini-jeux | `elyzea_drogues` (illégal) | **Pas réutilisé tel quel** : il appartient à une ressource illégale et à son interface. Son principe (défi envoyé par le serveur, résultat revérifié) est repris dans l'interface de l'EMS. |

**Aucune nouvelle dépendance.** `elyzea_famille` reste facultatif : sans lui, l'échographie de grossesse et l'implant
sont simplement indisponibles (message clair), le reste fonctionne.

Conflits identifiés et traités : les anciens actes simples « Réanimer », « Poser une attelle » et « Prélèvement sanguin »,
ainsi que la pose / le retrait d'implant d'`elyzea_famille`, auraient permis de contourner les mini-jeux. Ils sont
**refusés par le serveur** et retirés des menus tant que l'acte en mini-jeu correspondant est actif. Si le staff coupe
un mini-jeu, l'ancien acte revient automatiquement.

---

## 2. Comment ça se passe en jeu

1. L'EMS, en service, vise le patient avec **ALT** › **« Actes et examens… »** (ou **F6** › Actions médicales, ou la fenêtre d'examen).
2. La fenêtre liste les actes possibles pour ce patient. Un acte impossible est grisé avec la raison (pas de fracture radiographiée, patient conscient pour un massage, grade insuffisant…).
3. Si l'acte le demande, le **patient** reçoit une demande de consentement à l'écran (Accepter / Refuser, 25 s max).
4. Le serveur vérifie tout et envoie le défi. L'EMS se tourne vers le patient, est figé et joue l'animation. Le patient prend la position de l'acte (assis, allongé sur le dos…). Ces animations sont visibles par les autres joueurs.
5. Le mini-jeu s'ouvre. **Échap** annule à tout moment.
6. Le résultat est vérifié par le serveur. Si c'est réussi : effet appliqué, matériel retiré une seule fois, acte enregistré, compte rendu affiché à l'EMS. Si c'est raté : rien n'est appliqué ni retiré, et l'EMS peut **recommencer** (selon le réglage).
7. Les deux personnages sont libérés. Le patient peut aussi se relever lui-même avec **X**, ce qui interrompt l'acte.

Accès d'urgence sans passer par la liste : **ALT › « Contrôler l'hémorragie »** et **ALT › « Massage cardiaque »** (patient à terre).

---

## 3. Les mini-jeux

Les durées réelles dépendent du joueur. Le serveur refuse tout résultat arrivé avant 35 % de la durée prévue.
L'interface attend 42 % au minimum, en affichant « Finition des gestes… ».

| Acte | Étapes du mini-jeu | Résultat (jamais inventé) | Durée prévue |
|---|---|---|---|
| **Prise de sang** | Choisir le tube adapté à l'analyse (imposé par le serveur) → piquer dans la veine → garder l'aiguille dans la zone (curseur à maintenir dans une cible qui bouge) pendant que le tube se remplit | Prélèvement `LAB-xxxxx` enregistré (date, patient, préleveur, tube). L'analyse se lance depuis la tablette › Laboratoire ; le résultat n'existe qu'après cette analyse. | 28 s |
| **Radiographie** | Placer le membre sur la plaque → centrer et orienter le cadre (souris + A/D) → déclencher quand le patient ne bouge plus → valider le bon cliché | Selon les blessures enregistrées de **ce** membre : aucune fracture / immobilisation (attelle) / fracture (plâtre). Cliché raté : « examen à refaire ». | 26 s |
| **Attelle / plâtre** | Étapes à faire dans le bon ordre : pouls, réalignement (maintenir), rembourrage ou jersey, attaches ou bandes plâtrées (dans l'ordre), modelage du plâtre, contrôle de la circulation | Possible seulement sur une lésion **radiographiée** ; le matériel doit convenir (attelle : immobilisation ; plâtre : immobilisation ou fracture). La blessure est traitée ; la boiterie de chute est guérie. | 32 s |
| **Contrôle d'hémorragie** | Appuyer sur la plaie et garder la pression dans la zone verte (relâcher si elle monte trop, la pression varie) | Gravité venant de l'état du patient : légère 12 s, importante 24 s, critique 34 s (réglable). Critique : un 2e EMS peut **aider** (zone de pression plus large). Une erreur fait reprendre le saignement (temps perdu), jamais de mort. | 12-34 s |
| **Pansement compressif** | Poser la compresse → enrouler la bande → serrer au bon moment | Étape **distincte**, obligatoire dès l'hémorragie importante (réglable). | 12 s |
| **Massage cardiaque** | (Défibrillateur si l'EMS en a un : choc au bon moment) → 30 compressions au rythme de 110 / min → 2 insufflations | Séquence validée si ≥ 60 % des compressions sont dans le rythme. Ensuite, **chance** de reprise : base + régularité + patient stabilisé + défibrillateur − hémorragie non contrôlée (bornée de 3 à 85 %). Sans reprise : délai avant perte du patient prolongé, nouvelle séquence ou relais par un autre EMS. Aucun échec ne tue. | 36 s par séquence |
| **Échographie** | Gel → chercher l'image nette avec la sonde (clic maintenu) → la figer (Espace) | Grossesse : résultat d'`elyzea_famille` (jour, terme, nombre de bébés), **confidentiel**. Abdomen / thorax : blessures enregistrées dans la zone, sinon « aucune lésion ». | 32 s |
| **Scanner** | Positionner la table sous le laser → acquisition en rassurant le patient quand il bouge (E) → choisir la coupe sans artefact | Blessures enregistrées dans les régions examinées, sinon « aucune lésion ». Le score ne donne jamais de diagnostic. | 28 s |
| **Vaccination** | Cliquer la zone d'injection indiquée (imposée par le serveur) → désinfecter → piquer à 90° → injecter lentement | Vaccin enregistré **une fois** (identifiant unique). Contre-indication si malade, rappel trop tôt refusé. Protection seulement après le délai réglé. | 20 s |
| **Pose d'implant** | Désinfecter → anesthésie locale → insertion sous la peau (suivre le tracé) → pansement | Implant posé par `elyzea_famille` (objet retiré à ce moment), date de pose et fin de protection enregistrées, confidentiel. | 32 s |
| **Retrait d'implant** | Désinfecter → palper pour le trouver → incision → retrait (tracé) → pansement | Acte distinct, avec son propre consentement. | 22 s |

**Blessures localisées** (nouvelle table `ems_injuries`) : hémorragie, fracture ou lésion interne, sur une des 9 zones
(tête, thorax, abdomen, bras / avant-bras / jambe gauche et droite). Elles sont créées par le serveur :
- **coups reçus** : le client signale l'os touché et le type d'arme. Le serveur décide de la blessure et de sa gravité selon les dégâts : balle ou lame → hémorragie ; coup violent → fracture d'un membre ou lésion interne, selon une chance réglable. Fréquence plafonnée, une seule blessure par zone et par type (la plus grave est gardée) ;
- **chute de haut** : fracture d'une jambe, en plus de la boiterie existante ;
- **staff** : admin_menu › Santé › « Blessures des joueurs connectés ».

Une hémorragie importante non contrôlée fait perdre un peu de santé à la personne consciente. Elle ne descend jamais sous 120 / 200.
La réapparition à l'hôpital soigne les hémorragies et les lésions internes. Les fractures restent : il faut une radiographie puis une attelle ou un plâtre.
Tout est gardé en base : blessures, vaccins et implant sont retrouvés à la reconnexion.

---

## 4. Sécurité (côté serveur, non réglable)

- Permission du grade, grade minimum, service, distance (3 m + marge), aucun des deux dans un véhicule, revérifiés au début **et** à la validation.
- État du patient compatible : inconscient pour le massage ; conscient pour la vaccination, l'implant et le consentement.
- **Consentement** demandé au patient lui-même. Il est valable 5 min pour cet EMS, ce patient, cet acte et ce vaccin ou ce type d'examen. Un autre joueur ne peut pas répondre à sa place.
- **Un acte à la fois** par EMS et par patient ; le résultat d'un acte n'est accepté qu'**une fois** (double clic, latence) ; identifiant de défi unique.
- Le résultat est refusé s'il arrive trop tôt ou trop tard, avec plus d'erreurs que permis, un score hors limites, ou un tube / une zone d'injection différents de ceux imposés.
- Matériel retiré seulement à la réussite, tout ou rien. Il est rendu si l'effet échoue ensuite. Aucun effet n'est appliqué avant la validation.
- Patient déconnecté, qui se relève (X) ou qui perd connaissance pendant un acte qui le demande conscient : l'acte est arrêté et rien n'est enregistré.
- Actes confidentiels (grossesse, implant, prévention MST) : visibles dans le dossier seulement avec la nouvelle permission `records_sensitive`.

---

## 5. Installation et redémarrage

1. Remplacer les dossiers `elyzea_ems`, `admin_menu`, `elyzea_famille` et `elyzea_inventory` par ceux du dépôt.
2. **Base de données** : rien à faire, tout est créé au démarrage d'`elyzea_ems`, comme ses autres tables. Les requêtes sont aussi dans `sql/install.sql`. Nouvelles tables : `ems_injuries`, `ems_procedures`, `ems_vaccinations`. Aucune table existante n'est modifiée.
3. **Redémarrer** dans cet ordre, serveur arrêté de préférence, sinon en console : `restart elyzea_inventory`, `restart elyzea_ems`, `restart elyzea_famille`, `restart admin_menu`. L'ordre des `ensure` du `server.cfg` ne change pas.
4. Au premier démarrage, la console affiche une seule fois « Actes médicaux : permissions ajoutées à N grade(s) existant(s) ». Les nouvelles permissions sont alors données :
   - `imaging` et `vaccinate` aux grades qui peuvent réanimer ;
   - `implant` et `records_sensitive` en plus aux médecins et à la direction.

   À ajuster ensuite dans la tablette › Direction › Grades.
5. **Nouveaux objets** (`elyzea_inventory/shared/items.lua`) : `kit_prelevement`, `platre`, `vaccin_grippe`, `vaccin_tetanos`, `vaccin_mst`.
   Ils s'ajoutent aux objets déjà présents (`gauze`, `bandage`, `splint`, `defibrillator`, `implant_contraceptif`).
   À mettre dans la pharmacie EMS (coffre du garage) ou dans une boutique. Pas d'image fournie : une icône est affichée.

Matériel par défaut (modifiable dans admin_menu) :

| Acte | Objet |
|---|---|
| Prise de sang | `kit_prelevement` |
| Compression | `gauze` |
| Pansement compressif | `bandage` |
| Attelle | `splint` |
| Plâtre | `platre` |
| Vaccins | `vaccin_*` |
| Implant | `implant_contraceptif` (retiré par `elyzea_famille`) |
| Massage cardiaque | `defibrillator` facultatif, jamais retiré : il augmente la chance de reprise |

---

## 6. Réglages : admin_menu › Santé › « Actes médicaux (mini-jeux) »

- **Tous les actes** : interrupteur général.
- **Pour chaque acte** : actif / coupé, durée, difficulté (facile, intermédiaire, difficile), erreurs tolérées, grade minimum, possibilité de recommencer après un échec, matériel (objet, quantité, retiré ou non).
- **Blessures** : détection par les coups, seuils de dégâts des hémorragies, chances de fracture et de lésion interne, délai de guérison après soin.
- **Hémorragies** : durée de compression par gravité, gravité à partir de laquelle le pansement est une étape à part.
- **Massage cardiaque** : seuil de validation, chance de base, bonus et malus, chance maximale.
- **Attelle / plâtre** : objet de chaque matériel.
- **Vaccins** : actif, nom, objet, délai avant protection, durée de protection, délai avant rappel.
- **Comptes rendus types** : textes modifiables (les résultats viennent toujours des données enregistrées).
- **Blessures des joueurs connectés** : ajouter ou soigner, pour préparer un scénario ou tester.

Valeurs de départ et réglages non modifiables en jeu (zones, animations, analyses, types d'échographie et de scanner) : `config_procedures.lua`.
Les catégories d'EMS autorisées sont les permissions des grades (tablette › Direction › Grades › Permissions : « Actes »).

---

## 7. Fichiers

**Créés**

| Fichier | Contenu |
|---|---|
| `elyzea_ems/config_procedures.lua` | Configuration des actes, zones, blessures, vaccins, comptes rendus et animations |
| `elyzea_ems/shared/procedure_rules.lua` | Règles pures : réglages, défi, vérification du résultat, blessures, résultats d'examens, réanimation, vaccins |
| `elyzea_ems/server/injuries.lua` | Blessures localisées (base, coups reçus, chute, hôpital) |
| `elyzea_ems/server/procedures.lua` | Consentement, début, résultat, effets, dossier, aide à la compression, déconnexions, staff |
| `elyzea_ems/client/procedures.lua` | Scène EMS et patient, consentement, blessures par les coups, saignement, nettoyage |
| `elyzea_ems/html/proc.js` | Les mini-jeux |
| `elyzea_ems/html/proc.css` | Leur affichage |
| `elyzea_ems/tests/procedures_sim.lua` | Test du serveur |
| `elyzea_ems/tests/procedures_client_sim.lua` | Test du client |
| `elyzea_ems/tests/run_procedures_sim.py` | Lanceur des deux tests Lua |
| `elyzea_ems/tests/ui_proc.js` | Test de l'interface |
| `admin_menu/html/sante_actes.js` | Partie « Actes médicaux » de l'onglet Santé |
| `elyzea_ems/ACTES_MEDICAUX.md` | Ce document |

**Modifiés**

| Ressource | Fichiers et changements |
|---|---|
| `elyzea_ems` | `fxmanifest.lua` · `config.lua` (prestations facturables, permissions des grades par défaut) · `shared/perms.lua` (4 permissions) · `server/medical.lua` (anciens actes redirigés, blessures dans l'examen) · `server/lab.lua` (`CreateSample` partagé, prélèvement simple seulement si le mini-jeu est coupé) · `server/health.lua` (vaccins, fracture de chute, onglet staff) · `server/death.lua` (délai prolongé par le massage, soins de l'hôpital) · `server/records.lua` (dossier) · `client/medical.lua` (ALT, F6, examen) · `client/death.lua` (patient sur le dos pendant un acte) · `html/index.html`, `html/app.js` (examen, F6), `html/tablet.js` (dossier) · `sql/install.sql` |
| `elyzea_famille` | `grossesse/server/grossesse.lua` (export `EchographieEms`) · `contraception/server/contraception.lua` (exports `ImplantFin`, `PoseImplantEms`, `RetraitImplantEms` ; ancienne pose par ALT refusée si le mini-jeu est actif) · `client/main.lua` (options ALT implant masquées si le mini-jeu est actif) · `tests/integration_test.py` (contrôles 60) |
| `admin_menu` | `server/sante.lua` (3 opérations), `html/index.html`, `fxmanifest.lua` |
| `elyzea_inventory` | `shared/items.lua` (5 objets) |

---

## 8. Tests réellement effectués (hors jeu) et résultats

| Test | Commande | Résultat |
|---|---|---|
| Serveur : règles + vrais fichiers serveur (FiveM, MySQL, inventaire, famille simulés) : chaque acte, consentement, matériel, doublons, échecs, permissions, déconnexion, reconnexion, staff | `python3 tests/run_procedures_sim.py` | **120 / 120** |
| Client : vrai `client/procedures.lua` et `client/medical.lua` (jeu simulé) : déroulé, interruptions (éloignement, chute, arrêt serveur), échec puis nouvel essai, consentement, position du patient, X, arrêt de la ressource, menu ALT | `python3 tests/run_procedures_sim.py --client` | **34 / 34** |
| Interface (Chromium) : les 11 actes (14 variantes) joués jusqu'au bout par un joueur automatique (souris et clavier seulement), échec, annulation (Échap), fenêtres de choix, consentement, question, examen | `node tests/ui_proc.js` | **45 / 45**, aucune erreur JavaScript |
| Onglet staff admin_menu › Santé (Chromium, données tirées de la vraie configuration) : affichage, enregistrement, blessure donnée | test ponctuel (non gardé dans le dépôt) | **9 / 9** ; a révélé et fait corriger un plantage (table Lua vide reçue en `{}`) |
| Dossier médical dans la tablette (Chromium) : nouvelles sections, acte confidentiel masqué | test ponctuel | **6 / 6** |
| `elyzea_famille` : test d'intégration existant sur une vraie base MariaDB + nouveaux contrôles 60 (échographie, pose / retrait d'implant) | `python3 tests/integration_test.py` | **156 / 156** (147 avant ; les 147 passaient aussi avant les changements) |
| Suites existantes, non régression | `run_health_sim.py`, `run_lab_sim.py` (EMS), `run_alt_sim.py` (police) | **73 / 73**, **19 / 19**, **15 / 15** |
| Syntaxe | tous les fichiers Lua et JavaScript modifiés | aucune erreur |

Durées mesurées avec le joueur automatique (il ne se trompe jamais) : de 4 à 18 s pour les durées d'essai raccourcies du test.
L'attente minimale de 42 % a été respectée partout. Un vrai joueur mettra plus longtemps. Les durées sont à ajuster en jeu.

---

## 9. Tests à faire en jeu (deux joueurs : un EMS, un patient) — non faits

Pour chaque acte : démarrage, réussite, échec puis « Recommencer », annulation (Échap ; patient qui s'éloigne ; patient qui appuie sur X),
animations vues par le patient **et par un 3e joueur si possible**, objet retiré une seule fois (double clic rapide à la fin),
ligne dans le dossier (poste des dossiers), contrôles rendus aux deux joueurs (marcher, courir, curseur).

Scénarios conseillés :
1. Staff : donner une fracture `jambe_d` gravité 2 au patient → radiographie de la **jambe gauche** (aucune fracture) puis de la droite (plâtre) → attelle refusée → plâtre posé → déconnexion / reconnexion du patient : blessure guérie.
2. Tirer sur le patient (arène / staff) → examen : hémorragie → compression → pansement. Critique : un 2e EMS « Aide à la compression ».
3. Patient à terre → massage raté (rythme irrégulier : rien ne se passe) → séquences correctes jusqu'à la reprise ; relais par un 2e EMS.
4. Prise de sang → tablette › Laboratoire › analyse → résultat.
5. Vaccin anti-grippal → rappel refusé → plus de rhume attrapé après le délai.
6. Implant : pose (consentement), « /contraception » côté patient, retrait.
7. Échographie de grossesse sur une patiente enceinte et non enceinte ; dossier consulté par un grade sans `records_sensitive` (masqué).
8. Permissions : stagiaire sans `imaging` (refusé) ; hors service (refusé) ; staff qui coupe un acte (disparaît des menus, ancien acte simple de retour).

---

## 10. Limites connues et points à vérifier

- **Aucun test en jeu.** À vérifier en priorité :
  - les noms d'animations (`Config.ProcedureAnims`, modifiables) ;
  - la position allongée du patient ;
  - les indices de l'événement `CEventNetworkEntityDamage` (arme = 7e valeur) utilisés pour détecter les coups ;
  - le bon retour du curseur au patient après le consentement.
- Les blessures par les coups sont détectées par le client du blessé. Le serveur limite leur fréquence et décide de la gravité, mais ne peut pas confirmer le coup. Le risque est faible : cela ne concerne que le joueur lui-même.
- Rien n'est téléporté. Dans un endroit étroit, l'animation peut donc traverser un mur ou un lit : le personnage reste là où il est.
- La prise de sang ne propose que l'analyse « Alcool et substances », la seule dont le laboratoire peut calculer un résultat à partir de données réelles. Les autres tubes servent au mini-jeu. Ajouter une analyse demande une source de données.
- Les lésions internes n'ont pas encore de soin dédié. Elles sont décelées par le scanner ou l'échographie, puis soignées par la réapparition à l'hôpital ou par le staff.
- Le plâtre est facturé avec la prestation « Pose d'une attelle ».
- Le massage cardiaque est un acte par séquence. Chaque séquence validée est enregistrée dans le dossier ; la prestation « Réanimation » n'est ajoutée qu'à la reprise.

---

## 11. Intégration au dépôt (fusion avec les changements récents)

Le zip partait d'une version un peu plus ancienne de certains fichiers. La fusion a été faite fichier par fichier
(changements des actes + changements récents), sans conflit. Gardés en plus des actes :

- **Staff en service** (admin_menu) : ni blessé ni malade. Ajouté aussi aux **blessures localisées** :
  `P.InjuryAdd` refuse les coups et les chutes d'un staff en service, et le saignement est suspendu (`bleed = 0`)
  tant qu'il est en service ; tout revient en mode RP (`adminmenu:server:dutyChanged`). Le staff peut toujours
  donner une blessure depuis l'onglet Santé (pour tester).
- **Permissions** : `admin_menu/permissions_extra.lua` (onglet Santé visible même avec un ancien `config.lua`).
- **Tags** et `admin_menu/server/main.lua` : versions récentes gardées (le zip en contenait d'anciennes, sans rapport avec les actes).

Les dossiers `tests/` décrits au § 8 n'étaient pas dans le zip. Tests lancés après la fusion :

| Test | Commande (depuis `elyzea_ems/`) | Résultat |
|---|---|---|
| Branchements : chute → boiterie + fracture, balle → hémorragie + saignement, staff en service (chute, balle, saignement, fin de service), onglet Santé (données, soin), hôpital | `python3 tests/run_procedures_link_sim.py` | **16 / 16** |
| Santé (non-régression) | `python3 tests/run_health_sim.py` | **80 / 80** |
| Laboratoire | `python3 tests/run_lab_sim.py` | **19 / 19** |
| Police ALT | `elyzea_police` : `python3 tests/run_alt_sim.py` | **15 / 15** |
| Famille (règles, ventre) | `elyzea_famille/tests/test_regles.lua`, `test_ventre.lua` | **85**, **17** |
| Interfaces EMS et admin_menu chargées dans Chromium | — | aucune erreur JavaScript |

Non relancé ici : le test d'intégration d'`elyzea_famille` (il faut une base MariaDB). Toujours **aucun test en jeu**.
