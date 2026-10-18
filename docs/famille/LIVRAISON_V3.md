# Système familial — livraison V3 (Partie 10 : bébés plus réalistes · Partie 11 : réglages du moment intime)

> Rien n'a pu être testé **dans le jeu** (pas de client GTA V / FiveM dans l'environnement de développement).
> Tous les tests du §5 ont réellement été exécutés, hors du jeu, avec les résultats indiqués.

## 1. Partie 10 — bébés plus réalistes

**Résultat honnête : le modèle est nettement plus détaillé que la V2, mais il n'atteint pas le niveau de l'image de référence**
(poupées « reborn » photographiées). C'est un modèle de jeu généré par programme (16 000 triangles, textures de 1024 px pour la peau),
sans sculpture manuelle ; un rendu de ce niveau demanderait un sculpteur 3D et des textures peintes ou photographiées.
L'image de référence n'a été utilisée que comme repère visuel : rien n'en a été copié (et les étoiles bleues ne sont pas reproduites).

| Demande | Fait |
|---|---|
| Joues rondes, grosse tête, petit nez naturel | joues plus pleines, arête du nez basse, ailes et narines discrètes |
| Bouche et menton de nouveau-né | lèvre supérieure en arc, lèvre inférieure pleine, intérieur de la bouche sombre, menton rond |
| Yeux, paupières, sourcils naturels | orbites redessinées, iris plus grand, blanc de l'œil ombré dans les coins, sourcils très légers |
| Mains et pieds avec doigts et orteils | 4 doigts à 3 phalanges + pouce, ongles ; 5 orteils, talon, voûte ; plis des poignets et chevilles |
| Corps potelé (bras, jambes, ventre) | ventre rond, nombril, plis internes des cuisses, membres plus pleins |
| Peau réaliste | marbrure légère, rougeurs (joues, nez, mains, pieds, genoux, coudes, oreilles), micro-relief très léger |
| Toutes les variantes, teintes conservées | 6 teintes, 5 yeux, 10 coiffures, 4 poses + **nouveau** : tenue `pyjama` (défaut) ou `couche` → 108 modèles |
| Vérifier dans le contexte de GTA | les fichiers du jeu (`stream/`) sont relus par CodeWalker, réimportés et rendus : `Outils_3D/bebe/build/rendus/fichiers_du_jeu.png`. **Ce n'est pas une capture du jeu** (éclairage et moteur différents) |

Images : `Outils_3D/bebe/build/rendus/comparaison_v2_v3.png`, `galerie_tenues.png`, `galerie_variantes.png`, `planche_poses.png`, `fichiers_du_jeu.png`.

Défauts trouvés et corrigés en cours de route (vus sur les rendus) : UV superposées (905 faces, morceaux de peau sur le pyjama),
peau étirée dans la pose allongée (visible seulement en rendant les fichiers du jeu), traits noirs aux aines, peau trop granuleuse,
lèvres mal placées. Des contrôles automatiques empêchent maintenant les deux premiers de revenir.

Limites restantes : regard encore un peu fixe, cheveux peints sur une coque (pas de mèches en relief), petites marques aux aines dans
certaines poses, nombril visible à travers le pyjama, rendu réel dans GTA (éclairage, transparence des cheveux) non vérifié.

## 2. Partie 11 — durée et réglages du moment intime dans le menu admin existant

- **Aucun second menu** : onglet **Famille** ajouté au menu admin existant (F10 › Autres › Famille), même système d'onglets que les autres
  ressources (pont serveur `AM.Actions` / `AM.DataHooks`, fichier `html/famille.js`). Capture : `docs/famille/captures/menu_admin_famille.png`.
- Permission **`famille_manage`** (nouvelle case dans Administration › Rangs, donnée au rang superadmin par une migration),
  vérifiée par `admin_menu` **et** revérifiée par `elyzea_famille` côté serveur. Refus journalisé.
- 25 réglages en 6 sections : durée (durée, minimum, maximum, fondu, étreinte avant le noir), annulation, placement, conditions,
  risque de grossesse, contraception. Consulter, modifier, **Enregistrer**, **Annuler les modifications**, **Valeurs par défaut**.
- Validation serveur : type, bornes, règles croisées (min ≤ durée ≤ max ; jumeaux + triplés ≤ 100 % ; renouvellement ≤ durée de la pilule).
  Une valeur invalide → rien n'est enregistré, message précis.
- Persistance : table `rp_famille_reglages`, réappliquée à chaque démarrage, `config.lua` jamais modifié. Chaque modification journalisée.
- **Moment en cours** : il garde la durée et le fondu de son démarrage (instantané pris au début) ; les nouvelles valeurs
  s'appliquent aux moments suivants. La décision de conception reste calculée une seule fois, côté serveur, à la fin.

## 3. Fichiers ajoutés et modifiés

| Fichier | Rôle |
|---|---|
| `elyzea_famille/server/reglages.lua` (nouveau) | schéma des réglages, validation, enregistrement, rechargement, exports pour admin_menu |
| `elyzea_famille/server/base.lua`, `server/intimite.lua`, `shared/regles.lua`, `config.lua`, `sql/install.sql`, `fxmanifest.lua` (0.3.0) | table des réglages, chargement au démarrage, durée figée au début du moment |
| `admin_menu/server/famille.lua`, `admin_menu/html/famille.js` (nouveaux) | pont serveur et onglet « Famille » |
| `admin_menu/config.lua`, `server/main.lua`, `fxmanifest.lua`, `html/index.html` | permission `famille_manage`, migration, chargement de l'onglet |
| `elyzea_bebe_modele/stream/*` (111 fichiers, remplacent les 86 de la V2) | modèles V3 : 108 `.ydr`, 2 `.ytd`, 1 `.ytyp` |
| `elyzea_bebe_modele/shared/modeles.lua` (généré), `config.lua`, `client/main.lua`, `server/bebes.lua`, `server/main.lua`, `fxmanifest.lua` (1.2.0) | dimension « tenue » (`Config.Defaut.tenue`, 4ᵉ argument de `/bebe_creer`), contrôle des 2 dictionnaires |
| `Outils_3D/bebe/scripts/*`, `convertisseur/Program.cs`, `convertisseur/relire.sh`, `construire.sh` | chaîne V3, relecture binaire → XML, rendu des fichiers du jeu, contrôles |

## 4. Dépendances
Inchangées : `elyzea_core`, `elyzea_inventory`, `admin_menu`, `elyzea_police` (menu ALT), OneSync. Aucune nouvelle dépendance en jeu.

## 5. Tests réellement exécutés (hors du jeu)

| Test | Résultat |
|---|---|
| Règles de calcul (`lua5.4 elyzea_famille/tests/test_regles.lua`) | **51/51** |
| Code serveur famille + vraie base MariaDB (`python3 elyzea_famille/tests/integration_test.py`), dont §34 : durée réduite puis augmentée et appliquée au moment suivant, joueur sans permission refusé (et journalisé), persistance après redémarrage simulé, valeur invalide / hors bornes / incohérente refusée sans rien écrire, moment en cours qui garde sa durée, une seule tentative de conception, contraception et grossesse toujours correctes, valeurs par défaut | **71/71** |
| Portage (`python3 elyzea_bebe_modele/tests/test_portage.py`), dont tenue `couche`, tenue inconnue → pyjama, teinte/yeux inconnus → défaut | **33/33** |
| Choix de l'apparence côté client (teinte/tenue invalides) | 4/4 |
| Modèle 3D (`validate.py`) : maillage fermé, normales, poids, squelette, poses, **UV sans superposition**, **peau peu étirée par pose**, textures, 111 fichiers, chacun < 16 Mo | **26/26** |
| Conversion et relecture CodeWalker | **111/111** |
| Rendu à partir des binaires relus (toutes les textures retrouvées) | fait (`fichiers_du_jeu.png`) |
| Onglet admin « Famille » affiché dans Chromium avec les vraies données du serveur | fait (capture) |
| Syntaxe Lua (`luac5.4 -p`) et JavaScript (`node --check`) | OK |
| **En jeu** : rendu du bébé, menu F10 réel, moment intime à deux joueurs | **non fait** |

## 6. Installation
Voir `INSTALLATION.txt` et `MODIFICATIONS_A_FAIRE.md` du paquet. En résumé : remplacer `elyzea_famille`, `elyzea_bebe_modele`
(supprimer d'abord l'ancien dossier `stream/`), ajouter/remplacer les 6 fichiers d'`admin_menu`, redémarrer le serveur.
La table `rp_famille_reglages` se crée seule ; la permission est donnée au superadmin au premier démarrage.
