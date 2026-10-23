# elyzea_tags · Tags des quartiers

Les joueurs peignent des **tags** (graffitis) sur les murs de leurs quartiers avec une bombe de peinture.
Les tags sont **enregistrés en base** : ils restent après un redémarrage du serveur. On les **efface** avec un
solvant anti-graffiti, et le staff peut voir **qui a écrit quoi** et tout supprimer depuis le menu.

## Installation
1. Place `elyzea_tags` dans `resources/` (à côté des autres ressources Elyzea).
2. `server.cfg`, **après** `elyzea_inventory`, `admin_menu` et `elyzea_illegal` (déjà ajouté dans `Serveur cfg/server.cfg`) :
   ```cfg
   ensure elyzea_tags
   ```
3. La table `elyzea_tags` est créée automatiquement au premier démarrage (`sql/install.sql` si tu préfères la créer à la main).
4. Deux objets sont ajoutés dans `elyzea_inventory/shared/items.lua` (images déjà présentes) :
   - `spraycan` : **Bombe de peinture** (peindre un tag)
   - `sprayremover` : **Solvant anti-graffiti** (effacer un tag)

   Mets-les en vente où tu veux (magasins, PNJ illégaux, commandes de gang…) ou donne-les avec le menu staff.
5. Dans la console après la mise à jour : `refresh`, puis `ensure elyzea_inventory`, `ensure admin_menu`, `ensure elyzea_illegal`, `ensure elyzea_tags`.

## Joueurs
**Peindre** : utiliser la *Bombe de peinture* →
1. une fenêtre s'ouvre : texte (20 caractères), couleur (★ = couleur de ton groupe illégal), style d'écriture, aperçu ;
2. le texte est vérifié **avant** de peindre (mots interdits) ;
3. vise un mur (ou mets-toi simplement face à lui) : l'aperçu et son contour sont **blancs** si l'emplacement est bon, **rouges** sinon,
   avec la raison affichée (pas un mur, trop loin, zone protégée, le tag dépasse du mur…) ;
   **molette** ou **↑ / ↓** pour la taille, **← / →** pour la rotation (45° max), **E** pour peindre, **Retour** pour annuler ;
4. le serveur vérifie l'emplacement **avant** l'animation (aucune bombe perdue pour rien) ;
5. animation de graffiti de 7 s (annulable avec **X**), puis le tag apparaît pour tout le monde.

**Surfaces acceptées** : tout le décor de la map (murs extérieurs et intérieurs, façades, béton, brique…) et les objets fixes du décor,
murs inclinés jusqu'à ~37° (`Config.Spray.maxSlope`). Refusés : sols, plafonds, véhicules, joueurs, objets posés par un script ou un joueur,
matières listées dans `Config.Spray.forbiddenMaterials` (le staff obtient le numéro d'une matière avec `/tagmat` en la visant),
et les zones de `Config.ForbiddenZones` (commissariat, hôpital, mairie par défaut, coordonnées approximatives à ajuster).
Le tag doit tenir sur la surface : centre + au moins 3 coins, avec 15 cm de creux / bosses tolérés (briques, joints).

**Effacer** : se placer devant un tag et utiliser le *Solvant anti-graffiti* → animation de 9 s → le tag disparaît pour tout le monde.
Réglable : réservé à certains métiers (`Config.CleanJobs`, ex. `{ 'police', 'mairie' }`) et prime par tag effacé (menu).

## Modération (« éviter les bêtises »)
- **Mots interdits** : insultes, propos haineux, pubs… refusés **avant** que le joueur peigne. Le filtre ignore majuscules, accents,
  lettres répétées, espaces et points, et lit le l33t (`P.u.u.t.3` = `pute`, `N4Z1` = `nazi`). Liste modifiable en jeu.
  Un mot de 6 lettres et plus est cherché partout, même collé ; un mot plus court seulement écrit seul (`pute` oui, `dispute` non),
  sauf s'il commence par `*` (`*nazi` : cherché partout).
- Seuls lettres (accents compris), chiffres, espaces et `- _ . ! ? ' & # * + @ $` sont acceptés (pas de liens, pas de HTML).
- **Chaque tag garde son auteur** (personnage, citizenid, licence Rockstar, groupe, territoire, date) : visible par le staff seulement.
- **Logs** : chaque tag peint / effacé / supprimé va dans l'onglet **Logs** du menu staff (+ son Discord), et `Config.DiscordWebhook` si rempli.
- **admin_menu › Illégal › Tags** (permission `tags_manage`, donnée automatiquement aux Modérateurs, Administrateurs et SuperAdmins) :
  - réglages : activer / couper, seulement dans les territoires, réservé aux groupes, repasse, bombe / solvant consommés,
    délai entre deux tags, maximum par personnage et par territoire, expiration (0 = jamais), prime de nettoyage, **mots interdits** ;
  - liste des tags (recherche texte / auteur / citizenid / groupe / territoire) : **Y aller**, **Supprimer**,
    **Tous ses tags** (efface tous les tags d'un joueur), **Supprimer une zone**, **Tout supprimer**.
- En jeu (staff `tags_manage`) : `/taginfo` (auteur du tag le plus proche, 6 m), `/tagclean` (efface le tag le plus proche, sans solvant)
  et `/tagmat` (numéro de la matière visée, pour interdire les vitres par exemple).

## Limites (anti-spam)
- Délai entre deux tags d'un même personnage (120 s par défaut).
- Maximum de tags par personnage (10) et par territoire (40) : au-delà, le **plus ancien** disparaît (le quartier se renouvelle tout seul).
- Repasse : peindre à moins de 1 m d'un tag le remplace (gangs rivaux qui recouvrent les tags). Désactivable.
- Expiration facultative après N jours (`0` par défaut : les tags restent jusqu'au nettoyage).

## Territoires
Par défaut, on tague **partout** (sauf zones protégées). Avec « Seulement dans les territoires » (menu), on ne tague que dans les zones de l'éditeur de map cochées
**Territoire de vente** (les mêmes que la vente de drogue d'`elyzea_illegal`). Le territoire et le groupe de l'auteur sont enregistrés avec le tag.
Si `elyzea_illegal` n'est pas démarré, coupe ce réglage dans le menu pour taguer partout.

## Sécurité
Le client n'envoie que le texte, la couleur, le style, la taille et la position visée. Le serveur revérifie tout :
objet réellement utilisé juste avant, bombe dans l'inventaire (retirée seulement une fois le tag peint), texte, couleur, style,
taille, distance joueur → mur, mur (pas le sol), territoire, groupe, délai, limites ; anti-spam sur chaque action.

## Performances
Chaque tag est une petite page (`html/tag.html`) rendue en texture et collée sur le mur. Seuls les **16 tags les plus proches**
(à moins de 60 m) ont une texture ; les autres ne coûtent rien. Réglable dans `Config.Render`.
Les polices viennent de Google Fonts (chargées par le jeu) ; sans Internet, le tag s'affiche en Impact.

## Fichiers modifiés hors de cette ressource
| Fichier | Modification |
|---|---|
| `elyzea_inventory/shared/items.lua` | objets `spraycan` et `sprayremover` |
| `elyzea_illegal/server/main.lua` | export `GetTerritoryAt(coords)` ; `GetPlayerGroup` renvoie aussi `color` |
| `admin_menu/server/tags.lua`, `admin_menu/html/tags.js` | **nouveaux** : onglet Tags |
| `admin_menu/fxmanifest.lua`, `html/index.html`, `html/script.js` | chargement de l'onglet (catégorie Illégal) |
| `admin_menu/config.lua`, `server/main.lua` | permission `tags_manage` (Modérateur et au-dessus) |
| `Serveur cfg/server.cfg` | `ensure elyzea_tags` |
