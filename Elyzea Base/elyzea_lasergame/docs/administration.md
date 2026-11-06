# Guide staff — LaserGame ElyzeaFA

Accès : menu staff (admin_menu) › Économie et services › **LaserGame**, ou **`/lgadmin`**
(permission admin_menu « LaserGame », ou ACE `elyzea_lasergame.admin` sans admin_menu).
Chaque action est revérifiée par le serveur, validée (valeurs bornées) et **journalisée** (Journaux, table `lg_logs`, Discord facultatif).

## Créer une arène (pas à pas)
Les arènes n'existent plus « toutes faites » : tu les crées où tu veux, autant que tu veux.

1. **Va à l'endroit voulu** (entrepôt, parking, toit, terrain vague…).
2. Menu staff › LaserGame › **Arènes** › tape un nom › **📍 Créer ici**. L'arène est créée à ta position, **fermée** aux joueurs.
3. **✏️ Dessiner la zone en jeu** : vise le sol et pose les coins de la zone de combat **dans l'ordre du tour** (3 minimum, 60 maximum).
   - ↑ ↓ règle le plafond, ← → le sol (les joueurs ne peuvent pas en sortir, ni par le haut ni par le bas).
   - Le noclip marche pendant le dessin. Touche « enregistrer » pour valider.
4. **🎯 Apparitions ROUGE** puis **🎯 Apparitions BLEUE** : vise le sol, un point par joueur (20 maximum par équipe) ;
   la flèche suit la caméra = la direction dans laquelle le joueur regardera. Les points hors de la zone sont refusés.
   S'il y a plus de joueurs que de points, les joueurs supplémentaires apparaissent à côté d'un point existant.
5. **Décore** avec l'**Éditeur de map** d'admin_menu (bouton « 🧱 Décorer avec l'éditeur de map ») : murs, caisses, conteneurs,
   néons… Les objets de l'éditeur sont créés chez chaque joueur, **dans l'instance de la partie aussi**.
6. **Réglages** (facultatifs) : nom, description, joueurs max. par équipe (1 à 6), heure forcée, météo forcée, sol / plafond au mètre près.
7. **▶️ Ouvrir aux joueurs**. Le bouton reste grisé tant qu'il manque la zone ou une apparition (la liste « À faire » le dit).

Vérifier : **👁️ Voir la zone (60 s)** affiche le contour (sol et plafond) et les apparitions de chaque équipe, pour toi seul.
**🚀 Y aller** / **Aller au centre** te téléporte.

Sans admin_menu (ou pour ajuster vite) : `/lgadmin` › **Arènes** a les mêmes réglages et des outils **« à ma position »** :
« + Coin de la zone », « Sol = moi − 2 m », « Plafond = moi + 3 m », « + Apparition ROUGE / BLEUE » (orientée comme toi),
« Effacer », « Supprimer ».

### Bon à savoir
- Une partie en cours garde une **copie figée** de son arène : tu peux modifier une arène pendant qu'on y joue, la partie n'est pas touchée.
- Plusieurs parties peuvent utiliser **la même arène en même temps** (chacune dans son instance).
- **Fermer** une arène ferme les lobbies qui l'attendaient (mises remboursées). Une arène utilisée ne peut pas être **supprimée**.
- Supprimer une arène ne retire **pas** les objets posés avec l'éditeur de map (supprime-les dans l'éditeur si besoin).
- Les objets de l'éditeur sont aussi visibles en RP à cet endroit : choisis un lieu où un décor de LaserGame a du sens,
  ou un lieu peu fréquenté.

## Onglets de `/lgadmin`
| Onglet | Ce que tu peux faire |
|---|---|
| **Parties** | Voir tous les lobbies et parties (même privés), les joueurs, le score ; **expulser** un joueur ; **arrêter** une partie (toutes les mises sont remboursées, aucun point). |
| **Arènes** | Créer, régler, ouvrir / fermer, outils « à ma position », effacer, supprimer (voir ci-dessus). |
| **PVP** | Activer / désactiver le mode ; équipes égales / complètes ; élimination en un tir ; tirs alliés ; bouclier ; durée minimale classée ; mises min / max / pas / commission ; formats 1v1 → 6v6 ; **seuils des 8 rangs**. |
| **Armes** | Dégâts, portée, cadence, dispersion, chargeur, recharge ; activer / désactiver une arme. Appliqué immédiatement (clients compris). |
| **PNJ** | Poser un PNJ LaserGame à ta position (nom, modèle) ; retirer un PNJ ; rétablir ceux du fichier. |
| **Joueurs** | Rechercher (nom RP ou identifiant) ; statistiques et historique ; fixer les points ou le rang ; remettre les statistiques à zéro ; **exclure du LaserGame** (raison, durée en heures, 0 = définitif) ou lever l'exclusion. |
| **Journaux** | Staff, argent, PVP, sécurité, erreurs (50 derniers par page). |

## Commandes
| Commande | Effet |
|---|---|
| `/lgadmin` | interface staff |
| `/lgleave` | (joueur) quitter sa partie ou son lobby |
| `/lgrestore [id]` | (staff) force la restauration RP d'un joueur (le sort de sa partie si besoin et rejoue sa sauvegarde) |

## Argent : ce qu'il faut savoir
- Les mises sont débitées quand le joueur se met **prêt**, rendues s'il se remet « pas prêt » ou quitte le lobby.
- Chaque mise est une ligne de `lg_ledger` qui passe de `held` à `paid` / `refunded` / `lost` **une seule fois**.
- Fin de partie : le pot est partagé entre les gagnants (commission éventuelle déduite). Égalité, arrêt staff, crash, redémarrage :
  **tout est remboursé**. Un gagnant déconnecté est payé à sa prochaine connexion (`lg_pending`).

## Sécurité : journaux « sécurité »
Exemples : tir depuis une origine trop éloignée, cadence dépassée, tir sans recharge, impacts impossibles, sorties répétées
de la zone, action staff sans permission, flood d'événements.
Avec `Config.Security.banAfterSuspicious = N`, un joueur est automatiquement exclu du LaserGame après N événements suspects (0 = jamais).

## En cas de problème
- **Un joueur est bloqué hors du RP** : `/lgrestore <id>`. Sa sauvegarde (position, vie, gilet, tenue, instance) est en base.
- **Les joueurs apparaissent dans un mur** : déplace l'apparition (Apparitions › Placer en jeu) ou l'objet de l'éditeur.
- **Le décor n'apparaît pas au début de la partie** : le chargement attend ~3 s ; sur un décor très chargé, réduis le nombre d'objets
  ou augmente la distance d'affichage de l'éditeur de map.
- **Après un crash** : rien à faire, au redémarrage les mises en cours sont remboursées et les joueurs restaurés.
