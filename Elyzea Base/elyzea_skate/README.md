# elyzea_skate

Skateboard du kit de départ (objet `skateboard`, elyzea_inventory).

- **Utiliser l'objet** : la planche est posée au sol devant le joueur (l'utiliser à nouveau à côté la range).
- **F** : monter / descendre · **W** : pousser · **S** : freiner (petit recul à l'arrêt) · **A / D** : tourner
- **Espace** : petit saut · **E** à côté : ramasser.
- Vitesse imposée à chaque image : **25 km/h maximum**, même en descente (`Config.MaxSpeed`).
- Choc contre un obstacle à pleine vitesse : chute.
- La planche (`v_res_skateboard`) est posée sur un petit véhicule RC invisible (`rcbandito`, build 2060+) qui donne
  les roues, les pentes et les collisions. Le joueur est attaché debout, de profil.
- Un skate par joueur ; l'objet reste dans l'inventaire (rien ne se perd à la déconnexion).

Test hors jeu : `python3 tests/run_skate_sim.py`
