# elyzea_lscustom

Métier **LsCustom** complet pour Qbox (ox_lib, oxmysql). Aucun menu admin séparé :
toute la gestion se fait dans **admin_menu › Métiers › LsCustom**.

## Installation
1. Place `elyzea_lscustom` dans `resources/`.
2. Dans `server.cfg` :
   ```
   ensure admin_menu
   ensure elyzea_lscustom
   ```
3. Les tables `lscustom_settings` et `lscustom_invoices` sont créées automatiquement. Le métier `lscustom`
   est créé dans Qbox avec 5 grades (Stagiaire → Patron).
4. Des zones de départ sont posées au LS Customs de Burton (positions approximatives) : vérifie-les avec
   « Y aller » dans le menu admin et déplace-les avec 📍 si besoin.

## Pour les mécaniciens
- **Accueil (zone Service)** : E pour prendre / terminer le service. La tenue de travail du grade se met toute seule.
- **Vestiaire** : E ouvre les tenues enregistrées (illenium-appearance).
- **Zone Modification** : en haut du menu, **Réparation complète**, **Réparation des roues** et **Nettoyage**
  (avec l'état du véhicule : moteur, carrosserie, pneus crevés, saleté), ajoutés à la même facture et faits au paiement.
  E au volant du véhicule (ou à côté s'il est vide) → menu de personnalisation avec aperçu en direct.
  La caméra montre la partie modifiée : devant pour le pare-choc avant, derrière pour l'arrière, la roue pour les jantes,
  capot ouvert pour le moteur, coffre ouvert pour la sono, l'habitacle pour l'intérieur, vue d'ensemble pour la peinture.
  **Clic droit maintenu** sur le décor : caméra libre autour du véhicule ; **molette** : zoom.
  **Néons animés** : 🌈 arc-en-ciel ou ✨ Elyzea (bleu · or · rouge), visibles par tous les joueurs, gardés dans les garages
  (concession et garages publics). Au volant, `/neons` (ou une touche à assigner dans Raccourcis › FiveM) allume / éteint les néons.
  Vitesse de l'arc-en-ciel : `Config.NeonSpeed`.
  Peintures, néons et fumée des pneus : **couleur personnalisée** avec une palette (et finition pour les peintures :
  normal, métallisé, nacré, mat, métal, chrome), en plus des couleurs prêtes
  (performance, carrosserie, jantes, peintures, néons, xénon, vitres, plaques, livrées, intérieur…),
  total calculé avec les prix du staff, puis « Facturer au client ». Payé = modifications gardées et enregistrées
  sur le véhicule ; refusé = tu peux renvoyer la facture ou tout annuler (le véhicule revient comme avant).
- **Zones Réparation / Nettoyage** : E près d'un véhicule → barre de progression, puis facture préremplie.
- **Garage / Spawn véhicule / Parking** : sortir un véhicule de service (selon le grade), le ranger.
- **F6** : menu de l'atelier : **prendre / terminer le service** (de n'importe où), réparer, nettoyer, personnaliser,
  facturer, tarifs, mécanos en service.
- Personnalisation : au volant, ou véhicule vide. Réparation et nettoyage : véhicule vide (fais descendre le client).
- Chaque facture payée : commission au mécanicien (20 % par défaut), le reste au compte du métier (Renewed-Banking).

## Pour les clients
La facture s'affiche à l'écran : « Payer par banque » ou « Refuser ».

## Exports (serveur)
```lua
exports.elyzea_lscustom:GetJobName()       -- 'lscustom'
exports.elyzea_lscustom:IsOnDuty(source)
```
