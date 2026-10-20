# Procédure de test

## Hors jeu (déjà passés)
```
python3 tests/static_check.py      # 41/41 : objets, postes, recettes, modèles, manifeste
python3 tests/run_server_sim.py    # 73/73 : serveur simulé (base et inventaire factices)
```
Couvert : fabrication (distance, durée minimale, ingrédients, verrou de poste, pertes), culture (pose, plantation,
arrosage, lampe, croissance hors ligne, mort, récolte, vol, destruction police), vente (prix serveur, limites,
paiement impossible → rien n'est retiré), réglages admin (fusion, objets inconnus refusés, permissions).

## En jeu (à faire : rien n'a encore été vérifié en jeu)
Préparer : grade avec `drugs_manage`, de l'argent, `/car` si besoin.

1. **Démarrage** : console sans erreur `elyzea_drogues` ; les 4 tables existent.
2. **Placement** : placer un fournisseur, un acheteur, un plant de coca et les postes de la cocaïne. Ils apparaissent,
   restent après un redémarrage, se déplacent et se suppriment.
3. **ALT** : Alt + clic sur un poste (objet) → surbrillance et options. *Point à surveiller : le second rayon « objets ».*
4. **Fournisseur** : acheter pot, lampe, arrosoir, eau, graines, sachets, solvant, réactif.
5. **Cocaïne de bout en bout** : récolter (le plant disparaît puis repousse), broyer, pâte, ensacher, raffiner, finition.
   Vérifier animations, barre annulable (rien n'est perdu à l'annulation) et pertes.
6. **Culture** : utiliser `plant_pot` → aperçu → poser. Planter chaque variété, installer la lampe, arroser.
   *À vérifier : hauteur de la plante dans le pot, lueur colorée, changement de modèle par étape.*
   Réglez `growMinutes` à 2 dans le menu pour aller vite. Se déconnecter, revenir : la croissance a continué.
   Laisser sans eau : la plante meurt. Récolter : feuilles (+ graine parfois). Policier en service : « Détruire ».
7. **Joint par variété** : têtes → préparer → rouler → fumer. *À vérifier : animation, joint en main, fumée de la bonne
   couleur vue par un second joueur à côté.*
8. **Autres filières** : crack, méth, ecstasy (3 couleurs), opiacés (comprimés + seringue), kétamine, champignons.
9. **Consommation** : chaque produit fini. *À vérifier : animations pipe, sniff, seringue (repli si absente).*
   Les effets s'arrêtent à la fin, à la mort, avec « Arrêter les effets ». Le labo EMS détecte la substance.
10. **Vente** : vendre à l'acheteur, recevoir l'argent sale ; prix 0 → refusé ; inventaire plein → refusé sans perte.
11. **Admin** : modifier une recette, un prix, une couleur de variété → effet immédiat ; Réinitialiser ; journal rempli.
12. **Sécurité** : s'éloigner pendant une fabrication → refusé ; deux joueurs sur le même poste → le second attend.
