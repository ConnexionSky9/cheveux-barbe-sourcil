# equipement_bebe/ — porte-bébés et poussette (dans la ressource `elyzea_bebe_modele`)

Ce dossier ne contient pas de code : porte-bébés et poussette font partie de la ressource **séparée** `elyzea_bebe_modele`
(mêmes raisons que `bebe/README.md` : modèles 3D dans `stream/`, exports et menu ALT appelés par le nom de la ressource,
table `rp_poussettes`).

| Fichier (`elyzea_bebe_modele/`) | Rôle |
|---|---|
| `server/bebes.lua` | porte-bébés équipés, états de la poussette (garée, poussée, libre, renversée), frein, simulation |
| `client/portage.lua` | porte-bébés ventral / dorsal, pousser / garer la poussette, options ALT |
| `client/poussette.lua` | poussette qui roule (physique simulée), roues qui tournent ; collision active (V7) |
| `shared/physique.lua` | calcul du roulement (pente, frein, obstacles, renversement) |
| `stream/ely_bebe_poussette_*.ydr` | modèle de la poussette, **avec collision intégrée** depuis la V7 (4 boîtes) |
| `stream/ely_bebe_porte_*.ydr`, `ely_bebe_roue_*.ydr` | porte-bébés, roues |

Fabrication des modèles : `Outils_3D/bebe/construire.sh` (collision : `Outils_3D/bebe/scripts/export_gta.py`, `POUSSETTE_BOITES`).
