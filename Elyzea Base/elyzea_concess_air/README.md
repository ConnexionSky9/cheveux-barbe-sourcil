# elyzea_concess_air

Concession aérienne (hélicoptères, avions, jets) pour la **base Elyzea**. Même fonctionnement que `elyzea_concess`
(concession automobile), séparé : son métier, ses tables, ses réglages, son catalogue.

## Installation
1. `server.cfg`, après `elyzea_concess` :
   ```
   ensure elyzea_concess_air
   ```
2. Tables créées automatiquement : `concessair_settings`, `concessair_vehicles` (catalogue aérien de départ), `concessair_sales`.
3. Métier `planedealer` (« Elyzea Aviation ») créé automatiquement. Zones posées à l'aéroport de Los Santos (LSIA),
   positions approximatives : vérifie-les dans **Menu admin › Métiers › Concession aérienne › Zones**.
4. Plaques des appareils vendus : préfixe `AV`. La clé (`concess_key`) est la même que pour les voitures.

## Employés (F6)
Tableau de bord, catalogue (catégories Hélicoptères, Avions, Jets, Acrobatie, Utilitaires), vente avec acceptation de
l'acheteur, exposition au showroom, essais, livraison, direction (employés, grades, permissions). Voir le README de
`elyzea_concess` : les écrans et les permissions sont identiques.

## Staff
**Menu admin › Métiers › Concession aérienne** (permission `concessair_staff`) : réglages, catalogue, catégories,
zones, grades, permissions, ventes.

## PNJ catalogue (consultation seule)
**Menu admin › Éditeur de map › PNJ** : rôle **📚 Catalogue**, choisis **Concession aérienne** dans la liste.
Les joueurs peuvent regarder le catalogue sans pouvoir acheter.
