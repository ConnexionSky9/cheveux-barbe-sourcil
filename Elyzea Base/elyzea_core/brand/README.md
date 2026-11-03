# Kit de marque Elyzea FA

Ce kit regroupe le thème du nouveau logo : nuit, violet néon, E blanc avec son arc lumineux, ville de nuit.

| Fichier | Rôle |
|---|---|
| `brand.css` | Couleurs, polices (Exo 2 italique, Manrope), boutons, panneaux, animations (emblème qui se dessine, reflet, arc, fenêtres) |
| `brand.js` | `Ely.mark({ size, anim, live })` donne l'emblème E en SVG animable ; `Ely.skyline({ w, h, seed })` donne la ville de nuit en SVG |
| `cards.css` / `cards.js` | Cartes officielles : carte d'identité, permis, PPA. Elles portent le tampon « SUSPENDU » quand il le faut. Utilisation : `ElyCards.render(doc, { width })` |
| `mark.svg` | L'emblème E seul, en vectoriel |
| `logo_full.webp` | Le logo complet, détouré (fond transparent) |

Interfaces qui l'utilisent :
- `elyzea_multichar`, `elyzea_hud`, `elyzea_aura` ;
- `elyzea_papiers`, `elyzea_permis`.

Elles en ont chacune une copie dans leur dossier `html/`.

**Après une modification du kit**, depuis « Elyzea Base », lance :
```
bash elyzea_core/brand/sync_brand.sh
```
