# elyzea_skate

Skateboard du kit de départ (objet `skateboard`, elyzea_inventory).

- **Utiliser l'objet** : la planche est posée au sol et le joueur monte directement dessus (l'utiliser à nouveau la range).
- **F** : descendre / remonter · **W** : pousser · **S** : freiner · **A / D** : tourner (corps et planche penchés dans le virage)
- **E** à côté, à pied : ramasser. Pas de saut.
- Posture de glisse genoux fléchis (première animation disponible de `Config.RideAnims`), direction progressive, pentes prises en compte.
- Vitesse imposée à chaque image : **25 km/h maximum**, même en descente (`Config.MaxSpeed`).
- Choc contre un obstacle à pleine vitesse : chute.
- La planche (`v_res_skateboard`) est posée sur un petit véhicule RC invisible (`rcbandito`, build 2060+) qui donne
  les roues, les pentes et les collisions. Le joueur est attaché debout, corps à 30°, et ses pieds sont recalés automatiquement sur le plateau (mesure des os des orteils) juste après être monté.
- Un skate par joueur ; l'objet reste dans l'inventaire (rien ne se perd à la déconnexion).

Test hors jeu : `python3 tests/run_skate_sim.py`
