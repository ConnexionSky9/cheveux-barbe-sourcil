# elyzea_fuel : essence et stations-service (v2.0.0)

## Installation
1. Dossier `elyzea_fuel` dans `resources`.
2. `server.cfg` : `ensure elyzea_fuel` (après elyzea_core et admin_menu ; déjà ajouté juste après `ensure elyzea_hud`).
3. La table `elyzea_fuel` est créée toute seule. Au premier démarrage, les 27 stations-service de la carte GTA sont ajoutées à 3 $ le litre.
   Mise à jour depuis la v1 : rien à faire, les réglages sont conservés (le débit de la pompe prend sa valeur par défaut).

## Faire le plein (comme en vrai)
1. **Gare-toi à côté d'une pompe et coupe le moteur.**
2. À la pompe : **E** → tu prends le **pistolet**, relié à la pompe par son **tuyau** (6 m).
   Avec le pistolet en main : pas d'arme, pas de course, pas de saut, on ne monte pas en voiture.
3. Approche-toi de la **trappe à essence** du véhicule : **E** → le pistolet est inséré.
4. **Clic droit maintenu** → l'essence coule (1,2 L/s par défaut). **Lâche quand tu veux.**
   Le petit écran de la pompe montre en direct **l'argent qui monte** (au centime), **les litres** mis et **le réservoir qui se remplit**
   (repère du niveau de départ, litres libres, pourcentage).
5. Réservoir plein et tu continues : **l'essence déborde** et coule au sol (particules + flaque qui s'agrandit, inflammable comme dans GTA).
   L'écran passe en alerte rouge et compte les litres renversés (payés par défaut, comme sur une vraie pompe).
6. **E** près de la trappe → tu reprends le pistolet : **le plein est payé** (arrondi au dollar), un ticket s'affiche.
7. **E** à la pompe → tu raccroches le pistolet.

Ce qui peut mal tourner (et c'est voulu) :
- Tu t'éloignes de plus de 6 m de la pompe avec le pistolet en main → il t'échappe et revient à la pompe.
- Quelqu'un démarre et bouge la voiture pendant le plein → **tuyau arraché**, ce qui a coulé est payé.
- Tu quittes la station (25 m) en laissant le pistolet dans la trappe → plein terminé et payé.
- Moteur allumé → la pompe se bloque. Plus d'argent → la pompe s'arrête au dernier dollar.
- Paiement impossible au moment de payer (argent dépensé ailleurs entre-temps) → le réservoir revient à son niveau de départ.

Les autres joueurs voient ton pistolet, ton tuyau et l'essence qui déborde.
Un véhicule électrique ou un vélo ne se remplit pas. Une station ajoutée en jeu sans pompe du jeu à côté reçoit une petite pompe à son point.

## Consommation (inchangée)
- Le **conducteur** consomme l'essence selon le régime moteur (ralenti : quelques heures ; conduite normale : ~1 h ; à fond : ~15 min).
- Sous 10 % : message d'alerte. **À 0 % : le moteur s'arrête et ne redémarre plus** tant que le plein n'est pas fait.
- Le niveau est enregistré avec le véhicule (garage) et affiché sur le compteur du HUD (`Entity(veh).state.fuel`).

## Menu admin › Stations essence (permission `fuel_manage`, SuperAdmin par défaut)
- Consommation active ou non, vitesse de consommation, paiement (liquide puis banque, liquide, banque),
  **débit de la pompe** (L/s), **essence renversée payée ou offerte**, blips.
- Stations : ajouter à sa position (nom, prix du litre, rayon), modifier, déplacer, ouvrir / fermer, supprimer, y aller,
  même prix pour toutes. **Remplir mon véhicule** (staff, gratuit, noté dans les logs).

## Sécurité
Le client n'envoie que des intentions (prendre, insérer, « je presse la gâchette », reprendre, raccrocher). Le serveur vérifie la station,
la pompe, les distances, le véhicule (moteur, immobile, un seul pistolet par véhicule) et calcule les litres **au temps serveur**,
jamais plus vite que le débit : envoyer plus de messages ne remplit pas plus vite. Le montant et le paiement sont faits côté serveur.

## Réglages (`config.lua`)
`Config.Defaults` (premier démarrage, puis menu admin) · `Config.Pump` (modèles de pompes, pistolet, portée, longueur du tuyau,
distance de la trappe, durée max d'une session, réglage du pistolet planté dans la trappe `inCar`) · `Config.Controls` (E, clic droit).

## Tests (réellement exécutés hors jeu)
| Test | Commande | Résultat |
|---|---|---|
| Serveur réel, natives simulées | `python3 tests/run_server_sim.py` | 49 / 49 |
| Client réel, natives simulées (déroulé complet, tuyaux des autres, blocages) | `python3 tests/run_client_sim.py` | 38 / 38 |
| Écran de la pompe dans Chromium | `node tests/ui.cjs` | 15 / 15 |
| Onglet admin_menu « Stations essence » | `node ../admin_menu/tests/fuel_ui.cjs` | 3 / 3 |

À valider en jeu (impossible sans GTA V) : position exacte du pistolet dans la main et dans la trappe (réglable : `Config.Pump.inCar`),
rendu du tuyau (corde GTA), particules et flaque d'essence, animations.

## Pour les développeurs
`exports.elyzea_fuel:GetFuel(veh)` / `SetFuel(veh, 0-100)` (client et serveur). Le niveau est dans `Entity(veh).state.fuel`.
État répliqué du tuyau d'un joueur : `Player(src).state.fuelHose = { pump, mode = 'hand' | 'car', veh, spill }`.
