# NOIR X — Underground Network

Téléphone clandestin pour la base **Elyzea** (FiveM, sans ESX ni QBCore).
**Version 0.3.0.** Installation : voir [INTEGRATION.md](INTEGRATION.md).

## Ce qui fonctionne

| Application | Contenu |
|---|---|
| **Portefeuille** (accueil) | Argent sale (`black_money` de l'inventaire) et argent propre (compte `cash` du core), gains en attente, mise à jour automatique |
| **Ratline** | Discussion avec des informateurs PNJ : champs de weed, revendeurs et ce qu'ils vendent, opportunités, rumeurs. Questions à choix ou texte libre (mots-clés). Infos payantes en sale ou propre, point GPS, fiabilité (l'informateur nuance quand l'info est douteuse). Une info achetée reste gratuite pour ce personnage. Tout est géré par le staff. |
| **Blanchiment** | Argent sale → argent propre, moins une commission, avec une durée qui dépend du montant. Pendant l'opération, un pirate PNJ peut attaquer : il faut recopier une ligne de code plus vite que lui (copier-coller bloqué, frappe vérifiée par le serveur), sinon on perd un pourcentage du montant. |
| **Dark Chat** | Messages privés et groupes, invitations, membres, favoris, blocage, messages éphémères, accusés de lecture. Le serveur vérifie l'appartenance à chaque lecture. |
| **Ghostline** | Pseudonymes clandestins, contacts, réputation. L'identité civile n'est jamais affichée. |
| **Burner** | Pseudonymes temporaires payants, expiration, révocation par le staff |
| **Réglages** | Fond d'écran, sons, volume, numéro de série |

Les applications Dark Market, Contrats, Blackbreach, Mercenaires, Blackfile, Dead Drop et Black Auction sont sur l'écran d'accueil, mais affichent « Réseau indisponible » : elles ne sont pas encore développées. Le PC policier, Countertrace et l'onglet NOIR X d'admin_menu ne sont pas faits non plus. Pour l'onglet, il me faut `admin_menu`.

## Sécurité

- Le téléphone ne s'ouvre que si le serveur trouve l'objet dans l'inventaire. Il se ferme si l'objet disparaît, à la mort, au changement de personnage ou à la déconnexion.
- Chaque action du téléphone porte un jeton de session et un numéro de requête croissant (anti-rejeu), avec une limite de fréquence par action.
- Les montants sont validés côté serveur. Les opérations d'argent sont verrouillées par personnage, et l'argent est retiré avant d'être crédité.
- Les gains passent par une file de versements : versés exactement une fois, même après un redémarrage.
- Les blanchiments en cours reprennent après un redémarrage. Les requêtes SQL sont paramétrées.
- Tout est journalisé dans `noirx_audit`.

## Configuration

Tout se règle dans `config.lua`. La plupart des valeurs se modifient aussi en jeu par le staff (`/nx_set`, ou `AdminAction('setSetting')`) et sont conservées en base (`noirx_settings`).

| Section | Exemples |
|---|---|
| `Config.Money` | objet d'argent sale, compte propre (`cash` / `bank`) |
| `Config.Laundering` | montants min/max, commission, durée, délai, chance d'attaque PNJ, durée du duel, pertes |
| `Config.Ratline` | catégories, délai entre questions |
| `Config.Apps` | activer ou désactiver chaque application |
| `Config.Admin` | ressource et permission staff (`admin_menu`, `noirx_staff`) |

## Exports

**Serveur** : `UseNoirphone(src)`, `ForceClose(src, raison)`, `IsPhoneOpen(src)`, `Notify(src, titre, texte)`, `RefreshWallet(src)`, `RefreshPlayer(src)`, `AdminData(src)`, `AdminAction(src, nom, données)`, ainsi que les exports `Admin*` de `server/admin_api.lua`.

**Client** : `PhoneNotify(titre, texte)`, utilisé par elyzea_illegal.

## Tests

```bash
lua5.4 tests/server_spec.lua   # ouverture, jeton, anti-spam, réglages, perte de l'objet (13 tests)
lua5.4 tests/logic_spec.lua    # blanchiment, duel, Ratline, pseudos, filtrage des requêtes (20 tests)
```

Ces tests utilisent des natives FiveM simulées et passent tous. La liaison avec elyzea_core, elyzea_inventory et admin_menu n'a **pas** de test automatique et n'a pas été essayée en jeu : utilise la checklist d'INTEGRATION.md.

## Mise à jour depuis 0.1 / 0.2

1. Sauvegarde `config.lua` si tu l'as modifié.
2. Remplace le dossier `noirx`, puis fais `refresh` et `ensure noirx`.
3. Les nouvelles tables se créent seules.

## Assets

Logo, icône d'inventaire, fonds d'écran, écran de démarrage, icônes d'applications, coque et identité du PC policier : dossier `assets/`, tous originaux. Régénérables avec `node tools/build-assets.js`.
