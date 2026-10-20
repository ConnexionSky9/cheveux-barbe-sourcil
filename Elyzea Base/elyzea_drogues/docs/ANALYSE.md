# Système de drogues — analyse des ressources existantes (phase 1)

Tout ce qui suit a été lu dans les fichiers du serveur avant d'écrire le code.

## Ressources et points d'intégration

| Besoin | Ressource réelle | Ce qui est utilisé |
|---|---|---|
| Framework | `elyzea_core` (maison, API proche de QBCore) | `GetPlayer`, `GetPlayerData`, `Notify`, `AddMoney`/`RemoveMoney`, `AddNeeds` (serveur) ; `Notify`, `ShowTextUI`/`HideTextUI`, `ProgressBar({duration,label,canCancel,disable,anim,prop})` (client) ; `Ely.callback.register/await` (`@elyzea_core/lib/ely.lua`) |
| Inventaire | `elyzea_inventory` (maison) | objets dans `shared/items.lua` (prioritaires sur `data/items.lua`) ; serveur : `AddItem`, `RemoveItem`, `GetItemCount`, `CanCarryItems`, `RegisterUsableItem`, `RegisterShop`, `OpenInventory(src,'shop',id)` ; client : `Search('count', item)` |
| ALT | `elyzea_police/client/alt.lua` (pour tout le monde) | fournisseurs `ALT_PROVIDERS` : exports `AltTarget(ent)`, `AltNearby()`, `AltOptions(ctx)`, `AltSelect(id, ctx)` ; surbrillance et menu communs. **Limite trouvée** : les cibles externes n'étaient acceptées que sur des PNJ (le rayon ne touchait pas les objets) |
| Menu admin | `admin_menu` | onglets `TABS`/`VIEWS` (html), `AM.Actions` + `AM.DataHooks` (serveur), permissions des grades (`config.lua`), outil de placement `StartPlacement({kind, model, …})` (aperçu, rotation, hauteur, aimant) avec envoi par `confirmPlacement` |
| Progression | `elyzea_core` `ProgressBar` | animation + prop + annulation (X / Retour) |
| Notifications | `elyzea_core` `Notify` | |
| Économie | `elyzea_core` (cash / bank) ; `Argent sale` = objet `black_money` (comme `elyzea_illegal`) | |
| SQL | `@elyzea_core/lib/MySQL.lua` (style oxmysql : `query/insert/update/scalar/single .await`) | |
| Laboratoire EMS | `elyzea_ems` | `exports.elyzea_ems:RecordConsumption(src, substance)` |
| Police (serveur) | `elyzea_police` | `exports.elyzea_police:IsOnDuty(src)` (destruction de plantes) |

## Existant conservé (non remplacé)
- `admin_menu` › éditeur : champs de récolte (dont champignons `prop_stoneshroom1`) et ateliers (`weed_leaf → weed_pouch`, `coca_leaf → cocaine`) : ils continuent de fonctionner.
- `elyzea_illegal` › vente de rue (`weed_pouch`) : inchangée.
- `elyzea_drogues` (version précédente : effets, hallucinations) : étendue, pas remplacée.

## Modèles 3D retenus (vérifiés dans le catalogue de l'éditeur ou les données d'animations du serveur)
`bkr_prop_weed_table_01a`, `bkr_prop_coke_table01a`, `bkr_prop_meth_table01a`, `bkr_prop_weed_01_small_01b/01c`,
`bkr_prop_weed_med_01a`, `bkr_prop_weed_lrg_01a/01b`, `bkr_prop_weed_bucket_open_01a`, `h4_prop_bush_cocaplant_01`,
`prop_stoneshroom1/2`, `prop_worklight_01a…04a`, `prop_barrel_01a/02a`, `prop_table_01…08`, `prop_tool_box_01/02/04`,
`prop_drug_package`, `prop_coke_block_01`, `prop_weed_block_01`, `prop_weed_bottle`, `ng_proc_cigarette01a`, `p_cs_joint_01`,
`hei_heist_sh_bong_01`. Les modèles non vérifiés sont filtrés en jeu par `IsModelInCdimage` (jamais de blocage).

## Limites connues (dites, pas cachées)
- Aucun modèle 3D personnalisé n'est créé : je ne peux pas produire de fichiers `.ydr/.ytd` fiables. Les variétés de cannabis
  utilisent les plantes de GTA ; leur couleur est rendue par une lueur colorée autour de la plante et la fumée colorée.
- Rien n'a pu être lancé en jeu : tests hors jeu (simulations Lua du serveur) et vérifications statiques seulement.

## Modification d'une ressource existante (minime, réversible)
- `elyzea_police/client/alt.lua` : ajout du fournisseur `elyzea_drogues` et d'un **second** rayon « objets » utilisé
  seulement quand le premier ne trouve rien (comportement d'avant inchangé).
- `admin_menu` : nouvelle sorte de placement `drugsite`, onglet « Gestion des drogues », permission `drugs_manage`.
- `elyzea_inventory/shared/items.lua` : bloc d'objets « Drogues ».
