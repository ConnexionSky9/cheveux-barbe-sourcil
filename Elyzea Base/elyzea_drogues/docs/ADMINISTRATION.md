# Guide d'administration

Menu : **admin_menu › Illégal › 💊 Gestion des drogues**.
- `drugs_manage` : tout l'onglet.
- `drugs_effects` : seulement « Effets » (durées, hallucinations, joueurs sous effet).

Toutes les modifications sont gardées en base (`elyzea_drogues_settings`) et appliquées tout de suite à tous les joueurs,
sans redémarrage. **Réinitialiser** remet les valeurs de `config/*.lua`.

## 1. Installations (postes, récoltes, PNJ)
1. Choisir le type (ex. « Table de transformation », « Plant de coca », « Acheteur », « Fournisseur ») et le modèle.
2. **Placer** : l'outil de placement de l'éditeur s'ouvre (aperçu, rotation, hauteur, aimant au sol). Valider.
3. L'installation apparaît pour tout le monde. Les joueurs l'utilisent avec Alt + clic.

Boutons d'une ligne : 🚀 s'y téléporter · ✋ déplacer / tourner · ⧉ placer une copie · ✕ supprimer.

Pour une filière complète, placer au minimum un poste par étape (ex. cocaïne : plant de coca, broyeur, table de
transformation, ensachage, cuve de raffinage, poste de finition), un fournisseur et un acheteur.

## 2. Recettes
Pour chaque étape : activée ou non, ingrédients et quantités, produits obtenus, durée (s), perte (% de chance de perdre
chaque unité produite). Un objet inconnu de l'inventaire est refusé à l'enregistrement.
Cannabis : par variété, l'étape « préparer » peut être désactivée (on roule alors directement les têtes).

## 3. Prix et vente
- Prix à l'unité et quantité maximale par vente ; prix 0 = l'acheteur ne prend pas l'objet.
- Paiement : objet (argent sale `black_money` par défaut) ou compte (`cash` / `bank`).
- Délai entre deux ventes, limite d'unités par heure (0 = illimité).
- Boutique des fournisseurs : objets et prix.

## 4. Culture
Pots par joueur, distance entre pots, eau (réserve, arrosage, baisse par heure), perte de santé sans eau, vitesse avec et
sans lampe, engrais, disparition des plantes mortes, droits (propriétaire seul pour planter / récolter, destruction par la police).
Par variété : nom, couleur (fumée et lueur), durée de croissance, rendement, chance de graine, étape « préparer ».
Liste des plantes posées : propriétaire, variété, avancement ; suppression.

## 5. Récolte
Par point de récolte : activé, quantité min/max, temps de repousse, durée.

## 6. Effets
Par drogue : activée, durée, délai avant d'en reprendre, intensité visuelle. Hallucinations : créatures, fréquence, coups,
temps au sol. Joueurs sous effet avec **Arrêter les effets** ; **Tester sur moi**.

## 7. Journal
Dernières fabrications, récoltes, ventes, pots, saisies, alertes (fabrication trop rapide) et actions du staff (30 jours en base).
