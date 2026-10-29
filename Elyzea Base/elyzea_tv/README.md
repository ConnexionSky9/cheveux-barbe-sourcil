# elyzea_tv : télés et écrans géants (YouTube)

Les télés à écran plat du jeu diffusent des vidéos YouTube, avec l'image et le son.

- **Télés du jeu** : avec **ALT** sur la télé, puis **Télécommande**, tu colles un lien YouTube.
- **Écrans du staff** : le staff pose un écran **n'importe où**, à **n'importe quelle taille** (jusqu'à 60 × 35 m, pour un écran géant sur une façade), depuis le menu admin.

Tous les joueurs voient la même vidéo au même moment, et le son baisse avec la distance.

## Installation

1. Copier le dossier `elyzea_tv` dans `Elyzea Base/`.
2. Remplacer ou ajouter ces fichiers (ils sont dans le zip) :
   - `elyzea_police/client/alt.lua` : 1 ligne ajoutée (la télé dans le menu ALT) ;
   - `admin_menu/server/tv.lua` et `admin_menu/html/tv.js` : nouveaux ;
   - `admin_menu/fxmanifest.lua` : 2 lignes ;
   - `admin_menu/html/index.html` : 1 ligne ;
   - `admin_menu/html/script.js` : onglet ajouté à « Serveur et monde » ;
   - `admin_menu/permissions_extra.lua` : permission `tv_manage` ;
   - `admin_menu/server/main.lua` : la permission est donnée au SuperAdmin une seule fois.

   **`admin_menu/config.lua` n'est pas touché.**
3. Dans `server.cfg`, ajouter la ligne **après** `elyzea_core`, `admin_menu` et `elyzea_police` :
   ```
   ensure elyzea_tv
   ```
4. Redémarrer le serveur. La table `tv_screens` est créée toute seule.

## Utiliser une télé (joueurs)

1. Approche-toi d'une télé à écran plat (moins de 3 m), maintiens **ALT** et clique la télé, ou choisis-la si tu es juste devant.
2. **Télécommande : mettre une vidéo YouTube** ouvre un petit panneau. Tu y colles le lien, puis tu cliques **Lire** ou tu appuies sur Entrée.
   Formats acceptés :
   - `https://www.youtube.com/watch?v=…` ;
   - `https://youtu.be/…` ;
   - `/shorts/…`, `/live/…`, `/embed/…` ;
   - avec un départ : `&t=1m30s`.
3. Dans le panneau : pause / reprise, ±10 s, volume, éteindre.
4. Directement par ALT : pause, volume +/−, éteindre.

Points à savoir :

- Seules les télés **à écran plat** sont utilisables. Les vieilles télés cathodiques ne le sont pas. La liste des modèles est dans `Config.FlatTVs`.
- Pour réserver les télés au staff, mettre `Config.Flat.everyone = false`.

## Poser un écran (staff, menu admin › Serveur et monde › Écrans / TV)

1. Choisis une taille, par exemple **Géant 16 × 9 m**, ou tape largeur et hauteur.
2. Clique **Placer en jeu**. Le menu se ferme et l'écran **suit ton regard** : il se colle au mur ou à la façade que tu vises, tourné vers toi.
3. Règle-le avec les touches :

   | Touche | Effet |
   |---|---|
   | Clic gauche | Fige l'endroit |
   | Molette | Taille (le format est gardé) |
   | Q / E | Tourner |
   | Page préc. / suiv. | Hauteur |
   | Flèches | Déplacer |
   | MAJ | Réglage précis |
   | ENTRÉE | Enregistrer |
   | RETOUR | Annuler |
4. **Là où tu te tiens quand tu valides devient la télécommande de l'écran** : les joueurs y font **E**.

Dans la fiche de chaque écran :

- lancer une vidéo, pause, éteindre ;
- nom, largeur / hauteur exactes, portée du son (5 à 300 m), volume ;
- accès « tout le monde » ou « staff seulement » ;
- **Placer / modifier en jeu**, aller à la télécommande, supprimer.

La page liste aussi les **télés du jeu allumées**. Tu peux les éteindre une par une, ou **tout éteindre**.

## Comment ça marche

- **Vidéo** : chaque écran allumé et proche ouvre chez le joueur une petite page avec le lecteur YouTube officiel (`html/player.html`). Son image sert de texture.
- **Télés du jeu** : l'image est posée **sur la face avant de la télé** (un écran 16:9 calculé d'après la taille du modèle, en haut, dans le cadre).
  Elle est aussi envoyée sur **l'écran d'origine du modèle** (le même système que les émissions de télé du jeu).
  Réglage `Config.Flat.display` : `'both'` (par défaut), `'overlay'` ou `'rendertarget'`. Pour un modèle dont l'image déborde du cadre, mets un réglage fin `screen = { x, z, w, h }` dans `Config.FlatTVs`.
- **Écrans du staff** : l'image est un rectangle dessiné dans le monde, à la position et à la taille choisies. Le dos de l'écran est noir.
- **Synchronisation** :
  - le serveur garde, pour chaque écran, la vidéo, l'heure de départ, la pause et le volume ;
  - chaque joueur calcule la position de la vidéo avec l'heure commune ;
  - la page se recale si elle dérive de plus de 2,5 s.
- **Son** : le volume suit la distance entre ta caméra et l'écran (14 m pour une télé, réglable par écran). Au-delà, la page est fermée pour économiser les ressources.
- **Performances** : au plus 4 vidéos en même temps chez un joueur (`Config.Player.maxActive`), les plus proches.
- **Sécurité** : tout est revérifié par le serveur.
  - Seuls les liens YouTube sont acceptés, aucun autre site.
  - Il faut être à moins de 3 m de la télé ou de la télécommande.
  - Un même joueur doit attendre 3 s entre deux changements de vidéo.
  - Les écrans « staff seulement » sont refusés aux joueurs.
  - Le placement d'un écran n'est accepté qu'avec le jeton donné par le menu admin (valable 15 min).

## Tests hors jeu

Depuis `elyzea_tv/` :

```
pip install lupa
python3 tests/run_tests.py            # liens, ALT, lecture, synchro, son, écrans, sécurité (1 serveur + 2 joueurs imités)
node tests/ui.cjs <dossier>           # page vidéo (lecteur YouTube imité) et télécommande
node tests/admin_ui.cjs <dossier>     # onglet Écrans / TV du menu admin
```

Ces tests ne remplacent pas un essai en jeu : la vraie lecture YouTube et l'affichage sur les modèles ne peuvent être vérifiés que dans GTA.

## Procédure de test en jeu (à faire)

1. `ensure elyzea_tv` : aucune erreur dans la console serveur ni dans la console F8.
2. **Télé à écran plat** (appartement, Vanilla Unicorn…) :
   - faire ALT, puis Télécommande, et coller un lien ;
   - vérifier que l'image s'affiche sur l'écran de la télé et que le son est là.
3. **Deuxième joueur** :
   - il voit la même vidéo au même moment ;
   - le son baisse quand il s'éloigne et se coupe au-delà de 14 m.
4. **Commandes** : pause, reprise, ±10 s, volume, éteindre, et vérifier que c'est synchronisé chez l'autre joueur.
5. **Écran géant** :
   - menu admin › Écrans / TV › Géant 16 × 9 › Placer en jeu ;
   - viser une façade, régler, puis ENTRÉE ;
   - à la télécommande, faire E et lancer une vidéo, visible de loin.
6. **Vieille télé** : vérifier que l'option ALT n'apparaît pas.

## Limites connues

- **Cadre de l'image** : sur la face avant, la taille de l'écran est calculée d'après la taille du modèle. Selon le modèle, l'image peut déborder un peu sur le cadre ou laisser une marge (réglable par modèle).
  - Avec `display = 'rendertarget'` seul, deux télés du même modèle tout près montrent la même vidéo (celle de la plus proche) : c'est une limite du jeu.
  - En mode `'both'` (par défaut), chaque télé montre la sienne.
- **Vidéos refusées** :
  - certaines vidéos interdisent leur diffusion hors de YouTube (le choix du propriétaire) ; l'écran affiche alors un message ;
  - les vidéos réservées aux adultes ou bloquées dans un pays ne passent pas non plus.
- **Publicités** : le lecteur intégré peut afficher les publicités prévues par YouTube.
- **Son à travers les murs** : il suit la distance, pas les murs (il ne s'arrête pas quand on sort d'une pièce si on reste assez près).
- **Pas de test en jeu** : le nom de l'écran d'origine de chaque modèle n'a pas pu être vérifié en jeu.
  - Si l'image ne s'affiche pas, tape **`/tv_debug`** près de la télé : la console F8 indique le modèle, l'écran d'origine, la vidéo et l'état de la page.
