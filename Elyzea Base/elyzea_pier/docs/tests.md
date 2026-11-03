# Tests — elyzea_pier

Tests réellement exécutés hors jeu (environnement Linux, sans GTA V ni serveur FiveM).

## Résultats
| Suite | Résultat |
|---|---|
| Simulation du vrai code serveur (`tests/run_server_sim.py`) | ✅ 72 / 72, 0 erreur |
| Syntaxe Lua 5.4 + contrats serveur ↔ client ↔ interface (`tests/contract_check.py`) | ✅ 11 / 11 |
| Interface dans Chromium (`tests/ui_screens.cjs`) | ✅ 6 / 6 écrans sans erreur |
| Tests existants d'elyzea_inventory après ajout des 2 tickets | ✅ (voir le rapport de livraison) |

## Ce qui est vérifié
**Calculs (formules du jeu original)** : rail de 224 nœuds / 549 m ; trajet de 61 s à la vitesse du jeu ; vitesse maximale 17,7 m/s ;
au plus 0,59 m entre deux images (mouvement fluide, aucune téléportation) ; wagons exactement sur le rail ; retour exact en gare ;
montées et descentes ; orientation valide partout ; durée configurable ; chaque cabine de la roue exactement en bas à son arrêt.

**Billetterie** : refus loin du PNJ, quantité invalide, ticket inconnu, argent insuffisant (rien débité) ; achats en liquide et par carte
(montants exacts) ; remboursement automatique si l'objet ne peut pas être donné ; inventaire plein refusé avant tout débit ;
aucun argent créé ; informations (tickets, prix, places, attente).

**Grande roue** : refus à distance, sans ticket, à terre ; file d'attente sans consommer le ticket ; pas deux fois dans la file ;
pas deux attractions à la fois ; arrêt exact avec une cabine en gare ; 4 joueurs → 2 par cabine dans 2 cabines qui se suivent ;
un seul ticket consommé à l'embarquement ; état et places publiés à tous ; position assise farfelue refusée ; non-passager refusé ;
impossible de descendre pendant le tour ; déconnexion pendant le tour (place libérée) ; tour complet (≈ 195 s avec un arrêt
intermédiaire) puis descente des deux passagers ensemble ; place libérée ; téléportation hors de la roue (retiré) ;
s'éloigner de la file (retiré, ticket conservé).

**Montagnes russes** : embarquement immédiat avec consommation du ticket ; compte à rebours ; places dans l'ordre (groupe dans des
wagons voisins) ; descendre avant le départ (ticket rendu) ; départ ; impossible de descendre pendant le trajet ; inscription pendant
le trajet → file, ticket conservé ; déconnexion pendant le trajet ; passager mort pendant le trajet déposé en gare ; arrivée après
61 s ; descente ensemble ; train suivant pour la file.

**Sécurité** : déclaration de place sans être passager refusée ; limite de fréquence (35 requêtes refusées sur 40 en rafale) ;
aucun événement réseau client → serveur ne peut lancer ou terminer un trajet ; remise à zéro par le staff.

## Ce qui n'a pas pu être testé ici (à valider en jeu)
Ces points demandent GTA V et un serveur FiveM :
1. **Rendu** de la roue et du train créés par le script (modèles du jeu, valeurs du jeu original : risque faible).
2. **Animations** d'entrée / sortie et position assise dans les cabines et les wagons. Elles viennent du jeu, mais l'origine de
   la scène des places de wagon (`Config.Coaster.seats`) est déduite du script original : si un passager est décalé, ajuster
   ces 2 valeurs.
3. **Attache des autres passagers** sur chaque client (procédé du jeu original, dépend de la synchronisation réseau de FiveM).
4. **Position du PNJ** (`Config.Npc.coords`) : posé sur le sol automatiquement ; `/pier_here` pour le déplacer.
5. **Décor de la carte** : si ta carte contient déjà une roue ou des wagons immobiles au même endroit (mod de carte), ils
   s'afficheraient en double.

Procédure (≈ 10 minutes à deux) : acheter un ticket de chaque, faire un tour de grande roue ensemble (même cabine), faire un tour
de montagnes russes ensemble, vérifier que chacun voit l'autre assis et que les tickets ont bien été consommés.
