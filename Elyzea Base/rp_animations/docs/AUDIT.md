# Audit du serveur (avant développement)

Audit fait **sur les fichiers du dépôt** `cheveux-barbe-sourcil` (dossiers `Elyzea Base` et `Serveur cfg`), pas sur le
serveur en marche : je n'ai accès ni à la machine de production, ni à son dossier `resources` complet, ni au jeu.

## Framework et versions

| Élément | Constat |
|---|---|
| Framework | **Base maison `elyzea_core`** (README racine : migration complète depuis Qbox ; qbx_core, ox_lib, oxmysql, ox_inventory remplacés). Ni ESX ni QBCore. |
| Lua | `lua54 'yes'`, `fx_version 'cerulean'` partout |
| Build du jeu | `sv_enforceGameBuild 3258` |
| OneSync | Non défini dans les `.cfg` versionnés : probablement activé par txAdmin (dossier `txData/Qbox_…`). **À vérifier.** Les ressources existantes utilisent déjà `GetPlayerPed` / `GetEntityCoords` côté serveur, qui l'exigent. |
| Joueurs max | 48 (`sv_maxclients`) |
| Permissions | ACE : `group.admin` a `command` et `admin` (`permissions.cfg`) |

## Animations déjà présentes

- **rpemotes** (version nox-rpemotes) : démarré par `server.cfg`, **absent du dépôt**. Il diffuse de nombreux fichiers
  d'animations tierces (couples, baisers, poses).
- **elyzea_animations** : menu (touche K) qui pilote rpemotes. Son `anim_data.lua` (1 500 entrées générées depuis rpemotes)
  donne les noms exacts des dictionnaires et clips : c'est la source utilisée pour le catalogue de `rp_animations`.
  Il exclut volontairement les animations « adultes » de rpemotes.
- Aucune danse de couple chorégraphiée (slow, valse, salsa, bachata, tango) ni dans le jeu de base ni dans rpemotes.

## Menus, ciblage, notifications

- Menus NUI propres à chaque ressource ; pas d'ox_lib ni d'ox_target (supprimés).
- Interaction ciblée : menu ALT de `elyzea_police` (porter, escorter). Pas de système de « target » générique.
- Notifications : `exports.elyzea_core:Notify`. `rp_animations` affiche ses propres messages dans sa NUI pour rester autonome.

## Touches et commandes déjà prises (relevé `RegisterKeyMapping` et configs)

K (menu animations), X (arrêt animation), Y / L (invitations elyzea_animations), J (placer), N (voix), U (clés),
TAB (inventaire), 1-9 (raccourcis), R (recharger), E / G / I (interactions et alertes métiers), F1 (téléphone),
F2 (noclip staff), F3 (tenue), F4 (CarPlay), F5 (illégal), F6 (menus métiers), F9 / F10 / F11 (staff), ALT (interactions).

**Choix pour rp_animations** : menu **F7** (libre), arrêt **X** (partagé exprès avec elyzea_animations), invitations
**Y / L** (même convention ; chaque ressource ne réagit qu'à sa propre invitation en attente).
Commandes nouvelles : `/danses`, `/stopanim`, `rpanim_check`, `/rpanim_calib`, `/rpanim_valider`, `/rpanim_reset` : aucun conflit trouvé.

## États des joueurs réutilisés (state bags)

`emsDown` (à terre, elyzea_ems), `cuffed`, `carriedBy`, `escortedBy` (elyzea_police), `emsEscortedBy` (elyzea_ems).
Un joueur dans l'un de ces états ne peut ni inviter ni être invité, et une danse en cours s'arrête.

## Conflits possibles

- Une emote rpemotes lancée pendant une danse remplace l'animation : `rp_animations` le détecte et termine proprement la session.
- X arrête à la fois l'emote rpemotes / elyzea_animations et la danse : voulu.
- Aucune ressource existante n'est modifiée ou remplacée ; seule une ligne `ensure rp_animations` est ajoutée à `server.cfg`.

## Outils de création d'animations

Aucun dans cet environnement : pas de Blender, pas d'outil d'export `.ycd` (OpenIV, CodeWalker, plugin Sollumz), pas de
squelette GTA V, pas de capture de mouvement, pas de jeu pour tester. Voir `ANIMATIONS_PERSONNALISEES.md`.

## Architecture retenue

Ressource autonome `rp_animations`, sans dépendance obligatoire, à côté d'`elyzea_animations` (pas de remplacement) :

```
rp_animations/
├── fxmanifest.lua
├── config.lua                  configuration partagée
├── shared/catalog.lua          catalogue technique des 70 fiches (source unique)
├── server/security.lua         limites d'appels, état des joueurs, distances, droits
├── server/sessions.lua         sessions duo (préparation, départ, étapes, fin, surveillance)
├── server/invitations.lua      invitations et consentement
├── server/main.lua             événements réseau, calibrage, validations, déconnexions
├── client/anim.lua             lecture des clips, vérification des fichiers
├── client/positioning.lua      placement de B, obstacles, attache, collisions
├── client/session.lua          animation en cours, synchronisation, arrêt, nettoyage
├── client/menu.lua             NUI, favoris, récents, réglages, invitations
├── client/calibrate.lua        calibrage des positions en jeu (staff)
├── html/                       interface (index.html, style.css, app.js)
├── docs/                       audit, catalogue, animations personnalisées, tests
└── tests/                      tests hors jeu (Lua 5.4 + natives simulées, interface dans Chromium)
```
