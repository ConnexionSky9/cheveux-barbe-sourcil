# elyzea_garage · Elyzea Public Garage

Garages publics **connectés** pour la base Elyzea (elyzea_core), attribués aux PNJ du menu admin.

## Installation
1. Place `elyzea_garage` dans `resources/` et, dans `server.cfg` : `ensure elyzea_garage` (après admin_menu).
2. **Menu admin › Éditeur de map › PNJ** : crée ou ouvre un PNJ, active **🅿️ Garage public**, donne-lui un nom, enregistre,
   puis **📍 Placer les places de sortie** (véhicule fantôme, molette pour l'orienter, E ; plusieurs à la suite).
3. **🔴 Placer une zone de rangement** (même outil) et règle le rayon du cercle : les joueurs y rangent au volant avec E.
4. Répète pour chaque garage de la ville : ils partagent tous les mêmes véhicules.

## Pour les joueurs
- Parler au gardien ouvre **Elyzea Public Garage** : véhicules au garage, en circulation, à la fourrière, recherche par nom ou plaque.
- Chaque véhicule affiche son **état** : moteur, carrosserie, réservoir, essence, pneus crevés, vitres cassées,
  portières arrachées, carrosserie déformée, saleté, et le garage où il a été rangé.
- **Sortir** : le véhicule apparaît sur la première place libre et le joueur est **directement au volant**, avec ses clés.
- **Ranger** : entre au volant dans le **cercle rouge** au sol et appuie sur **E** (le véhicule est rangé tel quel),
  ou gare-le près du garage et reparle au gardien (carte « Véhicule à ranger »).
- **Garages connectés** : rangé dans un garage, il ressort de n'importe quel autre garage public.
- **État exact** : un véhicule rangé cassé ressort cassé (dégâts moteur et carrosserie, pneus, vitres, portières,
  déformations de la carrosserie, saleté, essence, pièces et peintures).
- Un véhicule sorti puis disparu (détruit, nettoyé) peut être ressorti. Les véhicules à la fourrière ne sortent pas d'ici.
- Avec `elyzea_concess` : si le propriétaire a perdu sa clé d'inventaire, un double lui est remis à la sortie.

## Réglages (`config.lua`)
Distance d'utilisation, distance de rangement, enregistrement des déformations.
Les déformations sont relevées sur une vingtaine de points de la carrosserie et reproduites à la sortie : le rendu est très proche,
mais pas forcément identique au millimètre.
