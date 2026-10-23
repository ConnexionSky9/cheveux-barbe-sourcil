# bebe/ — le bébé (dans la ressource `elyzea_bebe_modele`)

Ce dossier ne contient pas de code : le bébé est géré par la ressource **séparée** `elyzea_bebe_modele`, qui doit le rester.

Pourquoi ne pas la fusionner dans `elyzea_famille` :
- ses modèles 3D (`stream/`, 148 fichiers) sont chargés par FiveM sous le nom de la ressource ;
- d'autres ressources l'appellent par son nom : `exports.elyzea_bebe_modele:CreerBebe(...)` (naissance, `grossesse/server/suivi.lua`),
  le menu ALT commun (`elyzea_police/client/alt.lua`, fournisseur `elyzea_bebe_modele`), le menu admin (réglages et diagnostic
  transmis par `server/reglages.lua`) ;
- ses tables `rp_bebes` / `rp_poussettes` et les bébés déjà nés restent liés à cette ressource.
La renommer ou la déplacer casserait ces liens et les bébés enregistrés.

| Fichier (`elyzea_bebe_modele/`) | Rôle |
|---|---|
| `server/bebes.lua` | états du bébé (posé, porté, poussette, gardé), verrous, naissance, exports |
| `server/persistance.lua` | enregistrement et restauration (`rp_bebes`, `rp_poussettes`) |
| `server/main.lua` | commandes staff, aperçus |
| `client/main.lua`, `client/portage.lua` | affichage, prises (bras, contre soi), options ALT |
| `shared/modeles.lua` | liste des modèles (générée par `Outils_3D/bebe/scripts/make_resource.py`) |
| `config.lua` | réglages par défaut (modifiables dans le menu admin › Famille) |
