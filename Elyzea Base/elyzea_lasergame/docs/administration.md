# Guide staff — LaserGame ElyzeaFA

Ouverture : **`/lgadmin`** (permission admin_menu « LaserGame » ou ACE `elyzea_lasergame.admin`).
Chaque action est revérifiée par le serveur, validée (valeurs bornées) et **journalisée** (onglet Journaux, table `lg_logs`, Discord facultatif).

## Onglets
| Onglet | Ce que tu peux faire |
|---|---|
| **Parties** | Voir tous les lobbies et parties (même privés), les joueurs, le score ; **expulser** un joueur ; **arrêter** une partie (toutes les mises sont remboursées, aucun point). |
| **PVP** | Activer / désactiver le mode ; équipes égales / complètes ; élimination en un tir ; tirs alliés ; bouclier ; durée minimale classée ; mises min / max / pas / commission ; formats 1v1 → 6v6 ; **seuils des 8 rangs**. |
| **Armes** | Dégâts PVP et Zombie, portée, cadence, dispersion, chargeur, recharge ; activer / désactiver une arme. Appliqué immédiatement (clients compris). |
| **Zombie** | Activer / désactiver ; nombre de zombies, résistance, dégâts, vitesse, pause ; chaque type (résistance, dégâts, vitesse, récompense, fréquence, manche d'apparition) ; argent Zombie ; vie, régénération, temps à terre, réanimation. |
| **Prix Zombie** | Prix des 9 portes, des 13 armes murales (et quelle arme est sur chaque mur), des 8 atouts (et les désactiver), nombre d'atouts max. |
| **Cartes** | Activer / désactiver une carte ; **Placer ici** (déplace la carte entière sur ta position et ton orientation) ; **Aperçu en jeu** (visible par toi seul, 3 min) ; te téléporter ; revenir à la position d'origine. |
| **PNJ** | Poser un PNJ LaserGame à ta position (nom, modèle) ; retirer un PNJ ; rétablir ceux du fichier. |
| **Joueurs** | Rechercher (nom RP ou identifiant) ; voir les statistiques et l'historique ; fixer les points ou le rang ; réinitialiser PVP / Zombie / tout ; **exclure du LaserGame** (raison, durée en heures, 0 = définitif) ou lever l'exclusion. |
| **Journaux** | Staff, argent, PVP, Zombie, sécurité, erreurs (50 derniers par page). |

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
- L'argent du mode Zombie n'existe que dans la partie : il ne touche jamais l'argent RP.

## Sécurité : journaux « sécurité »
Exemples d'entrées : tir depuis une origine trop éloignée, cadence dépassée, tir sans recharge, impacts impossibles,
achat à distance, entrée dans une salle fermée, action staff sans permission, flood d'événements.
Avec `Config.Security.banAfterSuspicious = N`, un joueur est automatiquement exclu du LaserGame après N événements suspects (0 = jamais).

## En cas de problème
- **Un joueur est bloqué hors du RP** : `/lgrestore <id>`. Sa sauvegarde (position, vie, gilet, tenue, instance) est en base.
- **Une carte est mal placée** : Cartes › Aperçu, puis Placer ici sur un terrain plat.
- **Après un crash** : rien à faire, au redémarrage les mises en cours sont remboursées et les joueurs restaurés.
