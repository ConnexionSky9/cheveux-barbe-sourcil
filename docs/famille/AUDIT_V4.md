# Audit avant la V4 (bébé, portage, porte-bébés, poussette)

## 1. Sauvegarde et retour arrière
- Version fonctionnelle de référence : **V3 = commit `a8d61c0`** (branche `claude/dreamy-ritchie-7vdqzv`), marquée localement par l'étiquette `sauvegarde-v3`.
- Paquet d'installation V3 complet : `elyzea_famille_v3.zip` (livré précédemment) — c'est le paquet de retour arrière.
- La V4 est développée **par-dessus** la V3 (mêmes ressources, nouvelles versions) : rien n'est écrasé dans l'historique,
  chaque fichier V3 reste récupérable par `git checkout sauvegarde-v3 -- <fichier>`.

## 2. Fichiers réellement examinés
| Élément | Fichiers | Accès |
|---|---|---|
| Ressource bébé (V3, 1.2.0) | `elyzea_bebe_modele/` : `config.lua`, `client/main.lua`, `client/portage.lua`, `server/bebes.lua`, `server/main.lua`, `shared/modeles.lua`, `tests/test_portage.py`, `stream/` (111 binaires) | lus |
| Ressource famille (0.3.0) | `elyzea_famille/` : `server/{base,consentement,contraception,conception,intimite,grossesse,reglages,staff}.lua`, `client/*`, `html/*`, `sql/install.sql`, tests | lus |
| Chaîne 3D | `Outils_3D/bebe/scripts/*.py`, `convertisseur/*`, `build/source/bebe_elyzea.blend` (sources du modèle) | lus, exécutés |
| Menu admin | `admin_menu/server/famille.lua`, `html/famille.js`, `config.lua` (permissions) | lus |
| Inventaire | `elyzea_inventory/shared/items.lua`, exports `GetItemCount`, `RemoveItem`, `AddItem`, `RegisterUsableItem` | lus |
| Menu ALT | `elyzea_police/client/alt.lua` (fournisseurs `AltOptions` / `AltSelect` / `AltTarget` / `AltNearby`) | lus |
| Personnage | `elyzea_core` : événement serveur `elyzea:server:playerUnloaded(src, citizenid)` (déconnexion du personnage / changement) | lu |
| Animations du serveur | `elyzea_animations/anim_data.lua` (référence des animations déjà utilisées) | lu |
| Animations sur mesure du serveur (`custom@hold_umbrella`, `hold_flowers@dad`…) | les fichiers `.ycd` ne sont **pas** dans le dépôt (ressource de streaming non fournie) | **absents** |
| Fichiers du jeu GTA V (squelette des personnages, animations) | aucun | **absents** (voir §6) |

Comparaison des versions (rendus et rapports dans `Outils_3D/bebe/build/rendus/`, historique git) :
V1 (`c598a19`) → V2 (`d2b29cf` : bébé réseau, combat, normales) → V3 (`a8d61c0` : mains, pieds, tenue, 108 modèles).

## 3. Inventaire du système familial existant
| Fonction | État | Où |
|---|---|---|
| Création et gestion des **familles**, relations, membres | **absent** (jamais développé : prévu au module « enfants ») | — |
| Bébés et identifiants | **présent, non persistant** : identifiant `BB-…` en mémoire, créé par `/bebe_creer` ou l'export `CreerBebe` ; perdu au redémarrage (pas encore de naissance ni d'enfants en base) | `server/bebes.lua` |
| Apparence du bébé `{ teinte, tenue, yeux, coiffure }` | présent, validé côté serveur | `server/bebes.lua` |
| Interactions bébé : prendre (bras / face / « porte-bébé » sans accessoire), changer de prise, poser allongé / assis | présent | `client/portage.lua`, menu ALT |
| Combat pendant le portage : coups bloqués, aucune protection | présent | client + `weaponDamageEvent` |
| Moment intime, consentement, contraception, conception, grossesse, test, examen EMS | présent | `elyzea_famille` |
| Menu admin familial | **un seul** : onglet « Famille » d'admin_menu, permission `famille_manage`, valeurs en base (`rp_famille_reglages`) | `admin_menu` + `elyzea_famille/server/reglages.lua` |
| Permissions | ACE pour les commandes staff du bébé (`command.bebe_*`), `famille_manage` pour l'onglet | |
| Objets | `preservatif`, `pilule_contraceptive`, `implant_contraceptif`, `test_grossesse` | `elyzea_inventory/shared/items.lua` |
| Base de données | 8 tables `rp_*` d'elyzea_famille ; **aucune** table pour les bébés | `sql/install.sql` |
| Réseau | objets réseau créés par le serveur, attache par le porteur vérifiée toutes les 2 s, state bags `bebe`, `bebePiece`, `bebePorte` | |

Défauts constatés dans la V3 (corrigés en V4) :
1. Mode « porte-bébé » : aucun accessoire, le bébé est simplement collé au torse.
2. Pas de porte-bébé dorsal, pas de poussette.
3. Changement de personnage (sans déconnexion) : le bébé porté n'était pas reposé (seule la déconnexion était gérée).
4. Deux demandes simultanées sur le même bébé : protégées par `b.verrou`, mais le verrou n'était pas posé pendant les changements de prise.

## 4. Dépendances
| Dépendance | Version / remarque |
|---|---|
| FXServer | artefact 35245 (indiqué par toi), **OneSync obligatoire** |
| `elyzea_core` | notifications, citizenid, événement `playerUnloaded` |
| `elyzea_inventory` | objets (aucun inventaire parallèle) |
| `elyzea_police` | menu ALT (aucun système de ciblage parallèle) |
| `admin_menu` + `elyzea_famille` | onglet admin unique |
| `elyzea_ems` (facultatif) | coma = bébé reposé |
| Outils (hors serveur) | Blender 5.2 (bpy), Sollumz 2.9.0, szio, CodeWalker.Core (ElyConvert, .NET 8), Python 3 (numpy, scikit-image, Pillow) |

## 5. Formats
- Modèles : props `.ydr` (un par pose et par variante), dictionnaires de textures `.ytd`, archétypes `.ytyp` ; sources `.blend` / `.glb` / `.fbx`.
- Le bébé est un **objet** (pas un PNJ) : les poses sont des modèles figés obtenus avec le squelette de 20 os du bébé (`.glb`).
- Animations des parents : animations **natives** de GTA (`TaskPlayAnim`).

## 6. Animations : ce qui existe vraiment
Vérifié dans la liste publique des dictionnaires d'animation de GTA V (20 179 dictionnaires, `DurtyFree/gta-v-data-dumps`) :
- aucune animation native de bercement / portage de nourrisson (« baby » ne renvoie que des émotes de pleurs) ;
- `anim@heists@box_carry@` / `idle` (porter devant soi à deux bras) : existe, déjà utilisée par la V3 et par `elyzea_animations` ;
- `amb@prop_human_bum_shopping_cart@male@base` / `base` (mains posées sur la poignée d'un chariot) : existe → **pousser la poussette**.
- aucun objet natif « poussette », « landau » ou « porte-bébé » dans la liste des objets du jeu (21 631 objets) → **à créer**.

Une animation **sur mesure** du parent (`.ycd`) demande le squelette des personnages GTA (fichiers du jeu, non disponibles ici et
non redistribuables). Je n'invente donc aucun nom d'animation : la V4 utilise les deux animations natives ci-dessus, et le bébé
(dont je contrôle la forme) est posé pour épouser ces animations. Voir §8 pour la solution si tu veux une vraie animation de bercement.

## 7. Architecture V4 (choix et conséquences)
- **Un seul système** : `elyzea_bebe_modele` reste la ressource du bébé ; ses états passent de `pose | porte` à
  `pose | porte (bras, face) | ventral | dorsal | poussette`. Un bébé = un seul état, changé par le serveur sous verrou.
- **Porte-bébés** : objets 3D créés par le serveur, attachés au personnage par lui-même (comme le bébé) ; ils ont **la même origine
  que la pose du bébé** correspondante : bébé et porte-bébé s'emboîtent exactement, un seul réglage de position pour les deux.
- **Poussette** : objet 3D (pas un véhicule : un véhicule demanderait un modèle de véhicule complet, une physique de roues et
  un conducteur). Poussée : attachée devant le personnage, qui joue l'animation du chariot ; garée : objet figé posé au sol,
  le bébé allongé dans la nacelle. Ces choix sont ceux des scripts de chariots / fauteuils roulants qui fonctionnent sur FiveM.
- **Objets d'inventaire** (aucun inventaire parallèle) : `porte_bebe_ventral`, `porte_bebe_dorsal`, `poussette` (objets non consommés).
- **Base de données** : aucune nouvelle table. Les nouveaux réglages vont dans la table existante `rp_famille_reglages`
  (nouvelles clés, aucune migration de structure). Les données existantes ne sont pas touchées.
- **Menu admin** : l'onglet « Famille » existant reçoit une section « Bébés et équipements » (activer chaque équipement, règles de la poussette, diagnostic).

## 8. Ce qui ne peut pas être fait ici (et la solution la plus simple)
| Blocage | Conséquence | Solution |
|---|---|---|
| Pas de client GTA V / FiveM | aucun test en jeu (rendu réel, positions sur le personnage, multijoueur réel) | tests manuels décrits dans le README, positions réglables en direct (`/bebe_ajuster`) |
| Squelette des personnages GTA indisponible | pas d'animation de bercement sur mesure | m'envoyer `mp_m_freemode_01.yft` et `mp_f_freemode_01.yft` (extraits avec CodeWalker depuis TON jeu) : la chaîne pourra alors produire un `.ycd` |
| Forme exacte des personnages GTA inconnue | porte-bébés ajustés sur un mannequin de 1,80 m (homme) ; possible léger flottement ou contact sur d'autres morphologies | décalages séparés homme / femme dans `config.lua`, réglables en jeu |
