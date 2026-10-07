# Armurerie (armes, munitions, accessoires + essai au stand de tir)

## Poser l'armurerie
F10 › Éditeur › PNJ › rôle tout prêt **🔫 Armurerie**, puis « Modifier son rôle ».
Horaires, métiers autorisés, monnaie, **zone pour lui parler** et icône sur la carte : comme les autres PNJ.

## Les articles
Une ligne = un article :
| Colonne | Rôle |
|---|---|
| Objet | nom dans ton inventaire (`WEAPON_PISTOL`, `ammo-9`, `at_flashlight`…) |
| Type | 🔫 Arme (vendue à l'unité, essayable), 🧨 Munitions, 🔦 Accessoire |
| Nom affiché | facultatif (vide = nom de l'inventaire) |
| Rayon | catégorie (Pistolets, Munitions… ; tape un nouveau nom pour en créer un) |
| Prix | prix pour 1 achat |
| Lot | munitions/accessoires : quantité donnée pour 1 achat (ex : boîte de 30 balles) |
| Max | quantité maximale par achat |

Boutons : **+ Arme**, **+ Munitions**, **+ Accessoire**, **Ajouter les articles de base** (`Config.GunShop.defaultItems`),
**Prix ±10 %**, ↑ pour réordonner, ✕ pour retirer.

**Permis de port d'arme** (case à cocher) : exigé pour acheter ET essayer.
Vérifié dans `metadata.licences.weapon` (Qbox / QBCore) ou `esx_license` (ESX). Clé réglable : `Config.GunShop.licenceKey`.

## L'essai au stand de tir
1. Coche **🎯 Essai des armes** et enregistre le PNJ.
2. Va au stand de tir, **regarde vers les cibles**, puis clique **📍 Placer le point d'essai ici (ma position)**.
3. Règle la **durée** (10 s à 10 min) et la **distance max** autour du point.

Pendant l'essai :
- le joueur est téléporté au point, l'arme lui est **prêtée** (pas un objet d'inventaire : impossible de la garder, la jeter ou la donner) ;
- munitions illimitées, minuteur à l'écran, **X** pour arrêter plus tôt ;
- **🫧 Seul pendant l'essai** : il est placé dans une dimension à part et ne peut blesser personne ;
- s'il meurt, monte dans un véhicule ou s'éloigne trop, l'essai s'arrête ;
- à la fin, il revient au comptoir et la boutique se rouvre ;
- le serveur force la fin si le joueur ne revient pas ;
- un délai entre deux essais évite les abus (`Config.GunShop.trialCooldown`, 60 s par défaut).

⚠️ ox_inventory retire normalement les armes qui ne viennent pas de l'inventaire. Le menu active la roue des armes
d'ox_inventory pendant l'essai pour l'éviter. Si l'arme disparaît tout de suite chez toi, ajoute dans server.cfg :
`setr inventory:weaponmismatch false`.
