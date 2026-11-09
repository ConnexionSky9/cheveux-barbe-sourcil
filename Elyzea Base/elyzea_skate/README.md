# elyzea_skate

Skateboard du kit de départ (objet `skateboard`, elyzea_inventory).

- **Utiliser l'objet** : la planche est posée au sol et le joueur monte directement dessus (l'utiliser à nouveau la range).
- **F** : descendre : le skate retourne directement dans l'inventaire (aussi en cas de chute) · **W** : pousser · **S** : freiner · **A / D** : tourner (corps et planche penchés dans le virage)
- Pas de saut.
- Posture debout (première animation disponible de `Config.RideAnims`), direction progressive, pentes prises en compte.
- Vitesse imposée à chaque image : **25 km/h maximum**, même en descente (`Config.MaxSpeed`).
- Choc contre un obstacle à pleine vitesse : chute.
- La planche (`v_res_skateboard`) est posée sur un petit véhicule RC invisible (`rcbandito`, build 2060+) qui donne
  les roues, les pentes et les collisions. Le joueur est attaché debout, et recalé juste après être monté (mesure des os des orteils) : la ligne des deux pieds est tournée dans la longueur de la planche, centrée, semelles sur le plateau.
- Un skate par joueur ; l'objet reste dans l'inventaire (rien ne se perd à la déconnexion).

Test hors jeu : `python3 tests/run_skate_sim.py`
