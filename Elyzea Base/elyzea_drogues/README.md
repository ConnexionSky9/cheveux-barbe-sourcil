# elyzea_drogues

Toutes les drogues du serveur deviennent consommables (inventaire › clic droit › **Utiliser**), chacune avec ses propres effets.
`server.cfg` : `ensure elyzea_drogues` **après** `elyzea_inventory` et `elyzea_ems`.

| Drogue | Objets | Effets |
|---|---|---|
| 🌿 Cannabis | `weed_pouch`, `joint`, variétés `weed_*` | marche lente, vision douce, regagne un peu de vie, faim, moins de stress |
| ❄️ Cocaïne | `cocaine`, `cokebaggy` | court plus vite, endurance illimitée, mains qui tremblent |
| 💎 Crack | `crack_baggy` | cocaïne en plus fort et plus court, puis 30 s de descente (lent, tremblant) |
| ⚗️ Méth | `meth` | coups de poing plus forts, +25 de gilet, endurance, vision agressive, soif |
| 💊 Ecstasy | `xtcbaggy` | couleurs saturées, endurance, un peu plus rapide |
| 💉 Opiacés | `oxy` | regagne de la vie, marche lente, vision floue et somnolente |
| 🐴 Kétamine | `ketamine` (nouvel objet) | très lent, vision très floue, trébuche de temps en temps (sans se blesser) |
| 🍄 Champignons | `magic_mushroom`, `dried_mushroom` | **hallucinations** : singes, clowns, extraterrestres, Bigfoot… viennent le frapper |

## Champignons hallucinogènes
- Les créatures sont des PNJ **locaux** : seul le joueur défoncé les voit, les autres joueurs ne voient rien.
- Elles apparaissent autour de lui, courent vers lui et le frappent : il **tombe**, sans perdre de vie
  (elles n'ont aucune arme et ne combattent pas vraiment ; la vie perdue en tombant est rendue).
- Elles disparaissent dans un nuage à la fin de leur durée de vie et à la fin de l'effet.

## Réglages (admin_menu › Illégal › 💊 Drogues (effets), permission `drugs_effects`)
- par drogue : activée ou non, **durée de défonce**, délai avant d'en reprendre ;
- hallucinations : créatures en même temps, fréquence, délai entre deux coups, temps au sol, durée de vie, créatures possibles ;
- joueurs sous effet (temps restant) et bouton **Arrêter les effets** ; **Tester sur moi** (sans objet).
Les réglages sont gardés en base (`elyzea_drogues_settings`) ; `config.lua` donne les valeurs par défaut.

## Règles
- Tout est décidé par le serveur : drogue activée, délai, joueur à terre, menotté ou en arène PvP (refusé).
- Reprendre la même drogue prolonge l'effet, jusqu'à 2 fois sa durée (`Config.MaxStack`).
- Effets arrêtés à la mort ou à terre.
- Chaque prise est enregistrée pour le **laboratoire EMS** (`exports.elyzea_ems:RecordConsumption`) : l'analyse sanguine la détecte.
- Exports : `exports.elyzea_drogues:IsHigh(source)`, `exports.elyzea_drogues:ClearEffects(source)` (serveur), `IsHigh()` (client).

Tests hors jeu : `python3 tests/run_drogues_sim.py` (23/23).
