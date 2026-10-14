# NOIR X — Contrôle avant installation

## Vérifications effectuées
- Contrôle de l’archive et des références du `fxmanifest.lua`.
- Vérification de la présence des scripts NUI et serveur Attaque, Police Hack et Amélioration.
- Contrôle syntaxique JavaScript (`node --check`) sur tous les fichiers JS.
- Déclaration des applications dans `Config.Apps`, pour qu’elles apparaissent au téléphone et puissent être activées/désactivées par le menu admin existant.
- Ajout de la migration `006_noirx_upgrades.sql` à l’installation automatique des tables.
- Correction du passage des arguments de l’adaptateur MDT et de l’événement de fin de duel Police Hack.
- Ajout de la chance de défense automatique et de la révélation GPS approximative selon le niveau acheté.
- Ajout de réglages scalaires Police Hack/Amélioration à la liste de paramètres du menu admin NOIR X.

## Limites à connaître
- Le JavaScript a été contrôlé syntaxiquement, mais ce ZIP n’a pas été lancé sur un serveur FiveM réel. Aucune compilation Lua complète ni test multijoueur en jeu n’a pu être exécuté ici.
- Elyzea Police/MDT doit encore fournir un adaptateur avec les exports `IsPolice`, `ListReports` et `DeleteReport` (ou un pont équivalent configuré). Les rapports réels ne seront pas accessibles avant cette intégration.
- Les renseignements PNJ et leurs coordonnées/prix restent à relier aux données de ta ressource d’informateurs.
- Les interrupteurs d’applications passent par le système de réglages `Apps.<index>.enabled` du menu admin ; l’accès RPC est aussi contrôlé côté serveur.

## Installation
1. Sauvegarde la ressource `noirx`.
2. Fusionne le dossier `noirx` de l’archive avec la ressource serveur.
3. Vérifie le pilote SQL et l’item `noirphone`. La table `noirx_upgrades` est ajoutée via l’installation automatique si activée.
4. Lance `refresh`, puis `restart noirx`.
5. Teste avec deux joueurs et la console serveur avant ouverture au public.
