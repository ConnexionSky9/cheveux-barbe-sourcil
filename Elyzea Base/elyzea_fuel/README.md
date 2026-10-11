# elyzea_fuel : essence et stations-service

## Installation
1. Dossier `elyzea_fuel` dans `resources`.
2. `server.cfg` : `ensure elyzea_fuel` (après elyzea_core et admin_menu ; déjà ajouté juste après `ensure elyzea_hud`).
3. La table `elyzea_fuel` est créée toute seule. Au premier démarrage, les 27 stations-service de la carte GTA sont ajoutées à 3 $ le litre.

## En jeu
- Le **conducteur** consomme l'essence selon le régime moteur (ralenti : quelques heures ; conduite normale : ~1 h ; à fond : ~15 min).
  Les vélos et les véhicules électriques ne consomment rien.
- Sous 10 % : message d'alerte. **À 0 % : le moteur s'arrête et ne redémarre plus** tant que le plein n'est pas fait.
- Dans une station : à pied près du véhicule (ou au volant, à l'arrêt), **E** pour faire le plein. Le prix (litres manquants × prix du litre de la station)
  est affiché avant ; on paie à la fin (X pendant le remplissage : annulé, rien n'est payé). Le serveur revérifie la station, le véhicule et le prix.
- Le niveau est enregistré avec le véhicule (garage) et affiché sur le compteur du HUD. Un véhicule neuf de concession sort avec le plein.

## Menu admin › Stations essence (permission `fuel_manage`, SuperAdmin par défaut)
- Consommation active ou non, vitesse de consommation, paiement (liquide puis banque, liquide, banque), durée du plein, blips.
- Stations : **Ajouter une station à ma position** (nom, prix du litre, rayon), modifier, déplacer à sa position, ouvrir / fermer, supprimer, y aller,
  même prix pour toutes. **Remplir mon véhicule** (staff, gratuit, noté dans les logs).

## Pour les développeurs
`exports.elyzea_fuel:GetFuel(veh)` / `SetFuel(veh, 0-100)` (client et serveur). Le niveau est dans `Entity(veh).state.fuel`.
