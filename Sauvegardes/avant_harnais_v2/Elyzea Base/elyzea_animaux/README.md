# elyzea_animaux — animaux de compagnie, vendeurs PNJ, harnais / laisse, ferme

Ressource **indépendante** (aucun lien avec `elyzea_famille` ni les bébés) qui réutilise ce qui existe déjà sur le serveur :
`elyzea_core` (personnages, argent, base de données, notifications), `elyzea_inventory` (objets), `admin_menu`
(onglet **Gestion des animaux**, mêmes grades et permissions), menu **ALT** d'`elyzea_police`.

> **État : non testé en jeu.** La logique serveur est vérifiée hors jeu (77 tests automatiques, voir « Tests »).
> L'IA des animaux, les animations, le rendu du harnais / de la laisse et l'interface doivent être testés à deux en jeu
> avec la liste de la section « Tests à faire en jeu ».

---

## 1. Installation

1. **Sauvegarde ta base de données** (aucune table existante n'est modifiée, mais c'est la règle).
   Les fichiers existants modifiés ont été copiés avant modification dans `Sauvegardes/avant_elyzea_animaux/` (racine du dépôt).
2. Copie le dossier `elyzea_animaux` dans tes `resources`, et remplace les fichiers modifiés (liste en section 7).
3. `server.cfg` : la ligne est déjà ajoutée, **après** `elyzea_core`, `elyzea_inventory`, `admin_menu` et `elyzea_police` :
   ```cfg
   ensure elyzea_animaux
   ```
4. Démarre le serveur. Les tables sont créées toutes seules (ou à la main : `sql/install.sql`) :
   `elyzea_animaux` (fiches des animaux), `elyzea_animaux_config` (réglages du menu), `elyzea_animaux_farm` (état des animaux d'enclos).
5. **Premier passage en jeu (staff)** :
   - admin_menu › Économie et services › **Gestion des animaux** › Diagnostic › **Lancer le scan** (ou `/animaux_scan`) :
     enregistre les modèles et textures réellement présents.
   - Onglet **Vendeurs** : va aux points de vente par défaut (bouton « Y aller ») et replace-les où tu veux avec **Placer ici**
     (les positions par défaut sont valides sur la carte de base, mais pas choisies devant un décor précis).
   - Onglet **Ferme** : pareil pour les enclos (« Centre ici »).

Dépendances : `elyzea_core`, `elyzea_inventory` (obligatoires), `admin_menu` (administration), `elyzea_police` (menu ALT, facultatif :
sans lui, tout reste faisable avec **F7**). OneSync (déjà utilisé par le serveur). **Aucune dépendance à Cayo Perico.**

Permissions (admin_menu › Grades) : `animaux_manage` (vendeurs, prix, pelages, réglages, ferme, diagnostic) et
`animaux_owned` (animaux des joueurs). Données au **SuperAdmin** au premier démarrage ; le Fondateur a tout.

---

## 2. Pour les joueurs

| Action | Comment |
|---|---|
| Acheter un animal | Aller voir le vendeur (icône sur la carte), **E**. Choisir l'espèce, le pelage (l'animal apparaît devant soi avec ce pelage, boutons Tourner), son nom, le paiement, confirmer. |
| Accessoires | Onglet **Accessoires** de l'animalerie : harnais (style + couleur), laisse, croquettes, friandises, trousse vétérinaire, aliment pour bétail. |
| Mes animaux | **F7** ou `/animaux` : sortir / ranger, ordres, nourrir, laisse, renommer, fiche (puce, date, besoins). |
| Ordres | **ALT** sur son animal : Suivre, Attendre ici, Revenir, Se promener autour de moi, Caresser + ordres de l'espèce (Assis, Couché, Aboyer, Donner la patte…). |
| Harnais | Utiliser l'objet près de son chien, ou ALT › Équiper. Visible par tout le monde. ALT › Retirer le rend dans l'inventaire. |
| Laisse | Avoir l'objet **Laisse** sur soi, ALT › Attacher la laisse. Se détache seule en montant en véhicule, au-delà de 12 m ou si l'on meurt. |
| Véhicule | Un animal qui suit monte avec son maître (places arrière puis avant) et redescend avec lui. Pas sur une moto, un vélo, un bateau. Les grands animaux (vaches, félins…) attendent sur place. |
| Soins | Croquettes (faim), eau (objet existant « Bouteille d'eau », soif), trousse vétérinaire, ou vétérinaire de l'animalerie (payant). |
| Ferme | ALT sur un animal d'enclos : observer, nourrir, soigner, ramasser les œufs / traire. |

---

## 3. Ce qui se règle (menu admin, sans redémarrage)

- **Vendeurs** : créer (à sa position), modifier position / orientation / modèle (liste de modèles valides) / scénario d'attente /
  distance d'interaction / icône, choisir les espèces vendues et un prix par vendeur, accessoires, vétérinaire, activer / désactiver,
  supprimer (avec confirmation), restaurer les valeurs par défaut.
- **Prix et pelages** : prix et frais de chaque espèce, retirer une espèce de la vente, renommer / activer / désactiver chaque pelage,
  supplément par pelage, **aperçu** du pelage devant soi, ajouter au catalogue une texture trouvée par le scan.
- **Équipements et comportements** : limites (possédés, sortis), invincibilité, rangement automatique, distance de suivi,
  besoins (activés, vitesse, seuils, dégâts, guérison), harnais, laisse (longueur, détachement, objet / harnais obligatoire),
  véhicules, exotiques (vente, maximum, objet obligatoire), prix du vétérinaire et des accessoires.
- **Ferme** : activer, distance d'apparition, faim, effet des aliments / trousses, récolte, enclos (créer, centre ici, rayon, composition).
- **Animaux possédés** : animaux sortis en ce moment (distance au maître, **copies en double**, entité disparue), recherche
  (puce, n°, nom, citizenid, prénom / nom du propriétaire), **Ranger**, **Corriger** (statut, santé, faim, soif), **Retirer**
  (confirmation par le numéro de puce), suppression des entités orphelines.
- **Diagnostic** : erreurs de configuration, modèles / textures (scan), problèmes vus en jeu (modèle absent, commande sans animation),
  erreurs de sauvegarde, paramètres chargés.

Chaque section a son bouton « par défaut » : **réinitialiser les vendeurs (ou le reste) ne touche jamais aux animaux possédés**.

Demande un **redémarrage de la ressource** (fichier `config.lua`) : noms des objets, touche F7, styles / couleurs de harnais,
profils d'animations par espèce, liste des modèles de PNJ autorisés, nouvelles espèces.

Commandes : `/animaux_diag` (console ou staff), `/animaux_scan` (staff, en jeu), `/animaux` (joueurs).

---

## 4. Choix techniques

- **Sécurité** : tout est revérifié côté serveur — propriété (citizenid), distance au vendeur / à l'animal, objets, argent,
  limites, permissions (deux fois : admin_menu puis elyzea_animaux), bornes de chaque réglage. Le prix payé est recalculé
  et doit être identique au prix affiché (sinon « Le prix a changé »). Verrou par joueur : deux achats / sorties simultanés sont impossibles.
- **Pas de duplication** : une sortie = un jeton serveur à usage unique ; l'entité est vérifiée (modèle, propriétaire réseau, distance)
  avant d'être enregistrée ; un animal ne peut être sorti qu'une fois. Déconnexion, changement de personnage, suppression du
  personnage, arrêt de la ressource : l'entité est supprimée par le serveur, l'animal redevient « rangé » (au démarrage, tout
  « sorti » redevient « rangé »).
- **Synchronisation** : l'animal est une entité réseau créée par son propriétaire, sans migration (c'est lui qui donne les ordres) ;
  les autres joueurs le voient bouger normalement. Nom, harnais et laisse sont diffusés par le serveur.
- **Pelages réels** : chaque pelage est une vraie texture du modèle (`SetPedComponentVariation`) ou un autre modèle de la même race
  (ex. `a_c_chop`, `a_c_pug_02`). Avant d'afficher le catalogue, le client du joueur crée l'animal en invisible et vérifie que
  la texture existe (`GetNumberOfPedTextureVariations`) : un pelage absent n'est jamais proposé, et l'aperçu est l'animal réel.
- **Harnais et laisse** : GTA V n'a **aucun modèle 3D de harnais** pour chien. Plutôt que d'inventer un fichier, les sangles sont
  **dessinées** chaque image autour du corps à partir des os de l'animal (encolure, poitrail, ventre) : elles suivent la posture.
  La laisse est dessinée entre la main gauche du maître et le collier / l'anneau du harnais, avec un mou qui dépend de la distance :
  elle reste toujours accrochée aux deux bouts, il n'y a ni corde physique qui saute, ni objet à nettoyer à la déconnexion.
- **Comportement** : suivi avec décalage (pas dans les jambes), allure calée sur le maître avec un temps de latence (pas d'à-coups),
  nouveau chemin si l'animal est bloqué ; replacé près du maître **seulement** s'il est bloqué loin **et hors de l'écran**.
  Un animal qui a faim / soif (sous le seuil) ne court plus et refuse les tours. À 0 de faim ou de soif, il perd de la santé ;
  à 0 de santé il est **blessé** : il rentre et ne ressort qu'après des soins (trousse ou vétérinaire).
- **Ferme** : animaux créés par le serveur quand un joueur approche (les mêmes pour tous), animés par le joueur le plus proche,
  supprimés quand plus personne n'est autour ; faim / santé enregistrées par animal ; un animal tué est remplacé 2 minutes plus tard.

---

## 5. Modèles, textures et ce qu'il manque

Aucun fichier 3D ou texture n'a été créé ni ajouté : **tout utilise les modèles du jeu de base** (build 3258, licence Rockstar,
comme le reste du serveur). Aucune ressource tierce.

| Besoin du cahier des charges | État |
|---|---|
| Chiens (rottweiler, berger, husky, retriever, caniche, carlin, westie) | Modèles du jeu, plusieurs robes réelles par race selon le modèle. |
| Chats unicolores / bicolores / tricolores / tigrés / tachetés | Le modèle `a_c_cat_01` n'a que **3 robes** dans le jeu. 7 robes supplémentaires sont **déjà prévues** dans `config.lua` (marquées `addon`) et restent cachées. Pour les débloquer : un pack de textures pour `a_c_cat_01` (fichiers `a_c_cat_01.ytd` avec les textures `head_diff_003_a_uni` à `head_diff_009_a_uni` et le `a_c_cat_01.ymt` qui déclare 10 textures), à faire dans OpenIV / CodeWalker et à streamer dans une ressource. Ensuite : **Lancer le scan** ; les robes trouvées apparaissent seules. |
| Moutons, chèvres | **Aucun modèle dans GTA V** : il faut des modèles addon (signalé au Diagnostic). |
| Harnais visible | Dessiné (voir section 4) : 3 styles × 7 couleurs. Un vrai modèle 3D demanderait un `.ydr` attaché à l'os de l'animal. |
| Libellés des robes | Estimés : à vérifier avec **Aperçu** (Prix et pelages) et à renommer dans le menu si besoin. |
| Images d'inventaire | Pas d'image fournie : l'emoji de l'objet s'affiche. Pour une image : `elyzea_inventory/html/img/<nom>.png` (256 × 256). |

---

## 6. Tests

### Faits (automatiques, hors jeu) — `python3 tests/run_tests.py`
Vrai interpréteur Lua 5.4 (`pip install lupa`) qui charge les fichiers serveur de la ressource ; les requêtes SQL de la ressource
s'exécutent sur une base SQLite ; natives FiveM, inventaire, argent et permissions simulés ; 2 joueurs + 1 staff.
**Résultat : 77 réussis, 0 échec.** Couvert : catalogue et prix (supplément, frais), achat au bon prix, prix modifié / faux refusé,
distance au vendeur, argent insuffisant, robes addon cachées, achats simultanés, limites (possession, exotiques, sortis),
sortie (jeton, double sortie, entité d'un autre joueur, mauvais jeton), propriété (renommer / ranger l'animal d'un autre),
harnais (équiper, retirer, diffusion à tous, sauvegarde), laisse (objet requis, véhicule, distance), besoins (soins, baisse réelle,
animal rangé, blessure, sortie refusée, trousse), vétérinaire, déconnexion, changement et suppression de personnage, permissions
admin, bornes des réglages, persistance après rechargement, vendeurs (placer ici, modèle invalide, désactivé, remise à zéro sans
toucher aux animaux), registre (recherche, incohérence, ranger, retirer avec puce), copies orphelines, ferme (apparition, nourrir,
récolte, délai, disparition, aucun animal attribué à un joueur).

Aussi vérifiés : syntaxe Lua de tous les fichiers ajoutés / modifiés, syntaxe JavaScript (`node --check`) de l'interface et de l'onglet admin.

### À faire en jeu (à deux)
1. Joueur A achète un chien à l'animalerie (aperçu = pelage reçu ? argent retiré = prix affiché ?).
2. A se déconnecte / reconnecte : l'animal est toujours dans F7, rangé.
3. A essaie chaque pelage d'un husky et d'un chat dans l'aperçu ; noter les libellés à corriger.
4. A sort / range / ressort son chien ; F7 plusieurs fois très vite : jamais deux chiens.
5. A marche, court, sprinte, monte un escalier, traverse une route : le chien suit sans glisser ni téléportation visible.
6. B regarde : il voit le chien de A au même endroit, avec son harnais et la laisse.
7. Harnais : équiper / retirer chaque style ; Laisse : attacher, promener, s'éloigner (téléport staff), monter en voiture.
8. Voiture : A monte, le chien monte à l'arrière ; A roule, s'arrête, descend : le chien descend.
9. Ferme : A et B vont aux enclos ; mêmes animaux pour les deux ; nourrir, traire, ramasser des œufs.
10. Staff : déplacer un vendeur (Placer ici), changer un prix, redémarrer la ressource : tout est conservé.
11. B (sans permission) : pas d'onglet Gestion des animaux.
12. `/animaux_scan` puis Diagnostic : aucun modèle « introuvable ».
13. Couper Cayo Perico du server.cfg : rien ne change (aucun point n'y est).
Non fait : test de charge à plusieurs dizaines de joueurs (la ressource ne fait que des boucles légères : 400 ms par animal pour son
maître, 1 à 3 s pour la ferme et les vendeurs, rendu des sangles seulement à moins de 35 m).

---

## 7. Fichiers

**Nouveaux** : `elyzea_animaux/` (tout), `admin_menu/server/animaux.lua`, `admin_menu/html/animaux.js`.

**Modifiés** (copies d'origine dans `Sauvegardes/avant_elyzea_animaux/`) :
| Fichier | Changement |
|---|---|
| `admin_menu/config.lua` | permissions `animaux_manage`, `animaux_owned` (+ grade SuperAdmin par défaut) |
| `admin_menu/server/main.lua` | migration `animaux1` : donne les deux permissions au SuperAdmin existant |
| `admin_menu/fxmanifest.lua`, `html/index.html`, `html/script.js` | chargement de l'onglet, rangé dans « Économie et services » |
| `elyzea_police/client/alt.lua` | une ligne : `elyzea_animaux` ajouté aux fournisseurs du menu ALT |
| `elyzea_inventory/shared/items.lua` | objets `pet_harness`, `pet_leash`, `pet_food`, `pet_treat`, `pet_medkit`, `farm_feed`, `farm_egg` |
| `Serveur cfg/server.cfg` | `ensure elyzea_animaux` |

---

## 8. Limites connues / reste à faire

- Non testé en jeu (voir la liste ci-dessus) ; certaines animations d'ordres peuvent ne pas exister pour un modèle : elles sont alors
  refusées proprement (« ne sait pas faire ») et listées au Diagnostic.
- Sangles et laisse dessinées : pas de collision (la laisse peut traverser un poteau), éclairage plat.
- Animal attaché dans un véhicule : position assise approximative (`vehicleOffset` du profil dans `config.lua`).
- Chats, chèvres, moutons : voir section 5 (textures / modèles addon nécessaires).
- Les animaux de compagnie ne nagent pas après leur maître en mer profonde (comportement du jeu) ; ils attendent puis rentrent
  si le maître s'éloigne de plus de 250 m pendant 30 s.
