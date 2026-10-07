# elyzea_permis · Auto-école Elyzea

Permis **B (voiture)**, **A (moto)** et **C (poids lourd)** pour Qbox (ox_lib, oxmysql, ox_inventory), sur un PNJ du menu admin.

## Installation
1. Place `elyzea_permis` dans `resources/` et, dans `server.cfg`, après admin_menu : `ensure elyzea_permis`.
2. **Objet permis** : colle `install/ox_inventory_items.lua` dans `ox_inventory/data/items.lua`, copie
   `install/permis.png` dans `ox_inventory/web/images/`, redémarre ox_inventory.
3. **Menu admin › Métiers › Auto-école** : questions du code et prix de chaque permis.
4. **Menu admin › Éditeur de map › PNJ** : active **🪪 Auto-école** sur un PNJ (nom, nombre de questions,
   bonnes réponses nécessaires, fautes autorisées, tolérance de vitesse, permis proposés, véhicules d'examen), enregistre, puis :
   - **📍 Placer le point de départ** (voiture fantôme, molette, E) ;
   - **🎥 Enregistrer le parcours** : au volant, sur le point de départ, conduis le trajet (~5 min). Un point est posé tous
     les 60 m, **← / →** changent la limitation de la portion en cours, **Entrée** termine (l'arrivée = le départ), **Retour** annule.

## Pour les joueurs
1. **Code** (payant à chaque tentative) : questions une par une, réponses mélangées, corrigées par le serveur.
   Réussi : « Félicitations, vous pouvez passer à la conduite ». Échoué : score, corrections, « Repayer et recommencer ».
2. **Conduite** : le véhicule d'examen apparaît au point de départ, le joueur est au volant. Points dorés + itinéraire GPS,
   compteur avec la limitation de la portion, fautes (excès de vitesse au-delà de la tolérance, chocs), temps.
   Échec si trop de fautes, véhicule détruit, sortie du véhicule plus de 10 s ou temps largement dépassé.
   Le code reste acquis : seule la conduite est à repasser.
3. **Réussite** : l'objet **`permis`** (Permis de conduire) arrive dans l'inventaire (un seul permis qui regroupe B, A, C avec leurs dates).
   Le permis est aussi enregistré dans Qbox (`licences.driver`, `moto`, `truck` : visibles par la police).
4. **Utiliser le permis** : il s'affiche (photo du titulaire, nom, date de naissance, n°, catégories) avec
   **Montrer à la personne la plus proche** (3 m) : elle voit le permis avec la photo du titulaire.
