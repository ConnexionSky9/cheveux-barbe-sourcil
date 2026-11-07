# bank_heist 2.0 — Braquage de banque + guichet bancaire

> **État : écrit et vérifié hors jeu uniquement. Rien n'a été testé sur un serveur FiveM.**
>
> Vérifié :
> - compilation de tout le Lua, `node --check` de tout le JavaScript ;
> - simulation du VRAI code serveur (`tests/server_sim.py tests/test_flow.lua`, 75 vérifications, 0 échec) :
>   guichet (dépôt, retrait, virement, historique), indic, marchand, braquage du banquier, alerte police
>   avec position, décryptage (échec puis réussite), C4 (explosion, 2e alerte), fils de l'alarme
>   (mauvais fil, bon ordre, police), chariots, perceuse (anti-triche sur la durée), HUD, encaissement,
>   fin / délai, actions du menu staff et revalidation des valeurs ;
> - interfaces dans Chromium (`tests/ui_previews.cjs`, mode `index.html?demo=bank|talk|shop|menu|hack|wires|drill|hud|banner`) ;
> - onglet du menu staff (`admin_menu/tests/bankheist_ui.cjs`, 14 sous-onglets, enregistrement).
>
> Non vérifiable hors jeu : animations GTA (scènes synchronisées), objets et porte de la carte, sons GTA,
> lumières, particules, rendu du NUI dans FiveM.

## Déroulement

1. **Indic** (PNJ, ALT → « Lui parler ») : contre un billet, la position du marchand est marquée sur le GPS (itinéraire + repère temporaire).
2. **Marchand** (ALT → « Acheter du matériel ») : ordinateur de décryptage, sac de braqueur, C4, perceuse.
3. **Banquier** (ALT) : « Accéder à mon compte » (guichet : aperçu, dépôt, retrait, virement par numéro de téléphone, historique).
   Arme en main : **« BRAQUER LA BANQUE »** → banquier mains en l'air puis à genoux, **alarme** (sirène, lumières rouges, bords d'écran rouges),
   **alerte police avec la position**, bandeau « BRAQUAGE EN COURS », HUD en haut à droite.
4. **Porte du coffre** (ALT devant la porte) : **décryptage** (scène ordinateur + carte, mini-jeu, 3 tentatives par ordinateur) → la porte s'ouvre lentement ;
   ou **C4** (pose animée, bips accélérés, explosion sans dégâts, fumée, secousse) → la porte est soufflée.
5. **Butin** (points placés par le staff, type au choix) : chariots de billets / lingots / diamants, liasses, lingots sur table,
   coffres individuels (perceuse + mini-jeu de surchauffe), modèle personnalisé. Les billets vont dans le sac, tranche par tranche, « +5 000 $ » dans le HUD.
6. **Alarme** (ALT sur le boîtier) : braqueurs → mini-jeu des fils (mauvais fil = nouvelle alerte) ; policier en service → coupée directement.
7. **Encaissement** : E à une planque avec le sac.

## Menu staff (admin_menu › Braquage de banque)

A. Général et guichet · B. Banques (banquier, porte, boîtier d'alarme) · C. Points de butin (type, modèle, montant, objet, position) ·
D. Conditions (policiers, braqueurs, heures, outil exigé) · E. Porte et outils (décryptage / C4 / perceuse, mini-jeux) · F. Alarme ·
G. Marchands · H. Indics · I. Objets et prix · J. Butin et encaissement · K. Dépôts · L. Visuels · M. Sessions en direct · N. Journal.

## Dépendances

elyzea_core, elyzea_inventory (objets `bank_laptop`, `bank_bag`, `bank_c4`, `bank_drill`), jewelry_heist (sac porté),
elyzea_police (menu ALT, alerte, effectifs ; sinon menu ALT autonome et alerte interne), elyzea_aura (virements, historique).

## Tests à faire en jeu

1. ALT sur le banquier sans arme → guichet ; dépôt / retrait / virement → soldes et historique du téléphone.
2. Arme en main → « BRAQUER LA BANQUE » : police alertée (blip), sirène audible, lumières, HUD.
3. Décryptage : scène correcte (sac, ordinateur, carte), porte qui tourne dans le bon sens (régler « Rotation à l'ouverture »).
4. C4 : position de la charge sur la porte, explosion, porte soufflée.
5. Chaque type de butin : objet bien posé (sinon « Déplacer ici »), animation, billets dans le sac.
6. Perceuse, fils de l'alarme, encaissement.
