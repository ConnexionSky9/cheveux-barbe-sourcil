# elyzea_vetements_correctifs

Ressource **séparée** pour réparer des vêtements abîmés (trous, zones transparentes, morceaux manquants)
sans toucher aux packs de vêtements, au système famille ni aux autres ressources.

Elle contient :

| Dossier / fichier | Rôle |
|---|---|
| `stream/` | Les fichiers **corrigés** (`.ydd` modèle 3D, `.ytd` textures), avec **exactement** le nom du fichier d'origine. |
| `originaux/` | Une copie des fichiers d'origine, pour revenir en arrière (ce dossier n'est **pas** envoyé aux joueurs). |
| `/vet_diag` | Commande staff : ce que porte le personnage, de quel pack ça vient, **le nom des fichiers** du vêtement. |
| `/vet_essai` | Commande staff : change un seul emplacement pour un essai, **sans rien enregistrer**. |

> Un script Lua **ne peut pas** réparer un modèle 3D ni une texture : il ne fait que choisir quel vêtement
> est porté. La vraie réparation se fait dans les fichiers `.ydd` / `.ytd` ; cette ressource sert à
> trouver la cause, puis à installer les fichiers corrigés proprement (et à les retirer en une ligne).

---

## 1. Ce que montrent les captures (robe rouge)

- Sous le décolleté, au niveau du ventre et du bassin : une **zone blanche aux bords déchiquetés**,
  traversée par une **bande gris foncé incurvée**, avec des lambeaux rouges sur les côtés.
- La forme est **la même sur les deux captures** (cadrages et postures différents) : c'est un défaut fixe
  du vêtement ou de la combinaison portée, pas un simple accrochage passager pendant une animation.
- Le blanc est **plus clair que la peau** du personnage et la bande grise ressemble à une ceinture ou un
  élastique : on voit très probablement **soit une pièce portée SOUS la robe** (jambes / sous-vêtement,
  sous-haut, torse), **soit la couleur « cachée » sous une zone transparente de la texture** (souvent blanche).

Les captures ne suffisent pas pour trancher entre ces causes. Les fichiers de la robe ne sont pas dans ce
dépôt (elle vient d'un pack de `[vetements]`, `clothes` ou `fsclothes`). Les tests ci-dessous désignent la
cause en quelques minutes.

## 2. Diagnostic en jeu (5 minutes)

Personnage habillé avec la robe, puis :

1. **`/vet_diag`** puis ouvrir la console **F8**. Noter pour « Haut / robe » (n° 11) :
   le pack, le n° dans le pack, le coloris, et les noms des fichiers (`…^jbib_012_u.ydd`,
   `…^jbib_diff_012_a_uni.ytd`). Si la ligne « Modèle » n'est pas `mp_f_freemode_01`, la robe n'est pas faite
   pour ce personnage : c'est la cause.
2. **Test des couches dessous** : changer UNE pièce à la fois et regarder la zone blanche.
   - `/vet_essai 4 +` (plusieurs fois) : jambes / pantalon / sous-vêtement
   - `/vet_essai 8 14` : sous-haut « rien » (femme)
   - `/vet_essai 3 15` puis `/vet_essai 3 +` : bras / torse
3. **Test des coloris** : `/vet_essai 11 <n° de la robe> 2`, puis `3`, … (même robe, autre coloris).
4. **En mouvement** : marcher, courir, s'asseoir, et regarder si la forme bouge ou clignote.
5. **`/vet_essai annuler`** pour remettre la tenue (ne pas ouvrir la boutique / « Ma tenue » pendant les
   essais : elles enregistreraient la tenue d'essai).

| Ce qu'on observe | Cause | Réparation |
|---|---|---|
| La zone blanche **change** quand on change les jambes (ou le sous-haut / le torse), et grossit avec un pantalon épais | La pièce dessous **traverse** la robe (accrochage de maillages) | Aucun fichier à modifier : porter avec la robe des jambes / un sous-haut qui ne dépassent pas (souvent sous-vêtement ou « rien »). Si aucune ne convient, la robe doit être retouchée (fichier `.ydd`). |
| La zone change avec les pièces dessous mais garde **la même forme** quoi qu'on mette | Il y a un **trou** dans la robe : on voit ce qu'il y a dessous | Étape 3 du tableau : texture ou modèle. |
| Le trou n'existe **que sur un coloris** | **Texture** de ce coloris (`…jbib_diff_NNN_<lettre>_uni.ytd`) : zone transparente par erreur | Réparation de la texture (section 3). |
| Le trou existe sur **tous les coloris** | **Modèle 3D** (`.ydd`) : polygones manquants, normales inversées, mauvais shader, ou texture alpha commune | Analyser la texture (section 3) ; si elle n'a aucune zone invisible à cet endroit, c'est le `.ydd` (section 4). |
| La forme **bouge / clignote** en marchant | Maillage de la robe trop proche du corps (pondération) | Retouche du `.ydd` (section 4). |
| Le même nom de fichier existe dans **deux ressources** (voir ci-dessous) | **Conflit de packs** : modèle d'un pack + texture d'un autre | Renommer / retirer le doublon. |

**Conflit de packs** : sur la machine du serveur, dans le dossier `resources`, chercher le nom donné par
`/vet_diag` (ligne « chercher »). Sous Windows (PowerShell) :

```powershell
Get-ChildItem -Recurse -Filter "*jbib_012*" | Select-Object FullName
```

Le même nom de fichier dans deux ressources différentes (par exemple `clothes` et `fsclothes`, ou une
ressource `…_test`) = conflit.

## 3. Réparer une texture transparente

Avec **FiveM Clothing Studio** (dossier `FiveM Clothing Studio/` de ce dépôt, `npm install` une fois) :

```bash
# 1. Analyse : rapport + images (couleur, alpha, aperçu avec les zones invisibles en magenta)
node scripts/transparence.js analyse "chemin/mp_f_freemode_01_PACK^jbib_diff_012_a_uni.ytd"

# 2. Masque : copier jbib_diff_012_a_uni_alpha.png, peindre en BLANC uniquement les trous à boucher
#    (laisser noires les transparences voulues : dentelle, découpes), enregistrer en masque.png

# 3. Réparation (le fichier d'origine n'est jamais modifié ; résultat dans le dossier « corrige »)
node scripts/transparence.js reparer "chemin/…^jbib_diff_012_a_uni.ytd" --texture jbib_diff_012_a_uni --masque masque.png
#    ou, pour un rectangle : --zone x,y,largeur,hauteur (en pixels de la texture)
```

Les pixels rebouchés reprennent la couleur rouge de leurs voisins (option `--sans-remplissage` pour garder
la couleur d'origine). Formats réécrits : DXT5, DXT1 (refusé s'il reste d'autres transparences), A8R8G8B8.
BC7 : convertir d'abord la texture en DXT5 (OpenIV, CodeWalker, Texconv).

## 4. Réparer le modèle 3D (.ydd)

Polygones manquants, normales inversées, mauvais shader ou maillage qui rentre dans le corps : cela se
corrige dans **Blender + Sollumz** (ou CodeWalker pour le shader), pas par script. Pour que je le fasse,
fournir :

1. le `.ydd` de la robe (`mp_f_freemode_01_PACK^jbib_NNN_u.ydd` ou `_r.ydd`) ;
2. **tous** ses `.ytd` (`…^jbib_diff_NNN_a_uni.ytd`, `_b_`, … et `jbib_normal` / `jbib_spec` s'il y en a) ;
3. le `.ymt` du pack (`mp_f_freemode_01_PACK.ymt`) et son `fxmanifest.lua` ;
4. la sortie complète de `/vet_diag` (console F8, capture ou copie) ;
5. si possible la source d'origine de la robe (`.fbx`, `.blend`, `.obj`) fournie par son créateur ;
6. le nom des ressources qui contiennent un fichier du même nom (test « conflit » ci-dessus).

## 5. Installer un fichier corrigé

1. Copier `elyzea_vetements_correctifs` dans `resources`.
2. Copier le fichier **d'origine** dans `originaux/` (sauvegarde).
3. Créer le dossier `stream/` (il n'est pas livré vide, pour ne rien envoyer aux joueurs tant qu'il n'y a pas
   de correctif) et y mettre le fichier **corrigé**, sous **le même nom**.
4. Dans `server.cfg`, la ligne est **après** les packs de vêtements (déjà en place dans `Serveur cfg/server.cfg`) :

   ```cfg
   ensure [vetements]
   ensure clothes
   ensure fsclothes
   …
   ensure elyzea_staff_assets
   ensure elyzea_vetements_correctifs
   ensure elyzea_clothing
   ```

5. Redémarrer le serveur (un `restart` de la ressource ne suffit pas toujours pour les fichiers streamés),
   se reconnecter, vérifier la robe.

Le fichier de `stream/` remplace celui du pack parce que la ressource démarre après lui. Si la robe reste
abîmée après redémarrage (version de serveur qui garde le premier fichier), plan B : copier le fichier
corrigé directement dans le pack, en gardant l'original dans `originaux/`.

Aucun changement de `fxmanifest.lua` n'est nécessaire : tout ce qui est dans `stream/` est envoyé
automatiquement.

## 6. Tests après correction

1. Robe entière, sans trou, de face, de dos et de profil.
2. Bas de la robe (bassin, hanches) opaque.
3. Rouge et détails d'origine conservés (comparer avec les captures d'avant).
4. Marcher, courir, s'asseoir (`/e sit` ou un banc) : rien n'apparaît au travers.
5. Les autres coloris et les autres vêtements du pack : inchangés.
6. Console serveur et F8 : aucune erreur au démarrage de `elyzea_vetements_correctifs`.

## 7. Revenir en arrière

- **Tout désactiver** : mettre `#` devant `ensure elyzea_vetements_correctifs`, redémarrer. Les packs
  d'origine reprennent la main, rien d'autre n'est touché.
- **Une seule pièce** : supprimer son fichier de `stream/` (l'original est dans `originaux/`), redémarrer.
- Plan B utilisé : recopier le fichier de `originaux/` dans le pack.
