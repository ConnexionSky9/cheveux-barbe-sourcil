# Installer un pack sur un serveur FiveM

L'application ne modifie jamais votre serveur : ces étapes se font à la main.

## Avant de commencer

Ouvrez `export_report.json` ou la fin de l'assistant d'export :

- **Prêt à installer** : tous les contrôles automatiques sont réussis. Le test en jeu reste à faire.
- **Incomplet** : des textures doivent encore être placées dans des `.ytd` (dossier `<ressource>_a_convertir/`, fichier `A_LIRE.txt`). Sans cela, ces variantes ne sont pas dans la ressource.

## Étapes

1. **Ouvrez** le dossier de la ressource exportée (bouton « Ouvrir le dossier » à la fin de l'export).
2. **Copiez** ce dossier dans le dossier `resources` de votre serveur, par exemple `resources/[vetements]/mon_pack_vetements`.
3. **Vérifiez le nom** : le dossier doit porter exactement le nom technique de la ressource (celui affiché dans `fxmanifest.lua`, ligne `name`).
4. **Ajoutez** dans `server.cfg`, après vos autres ressources :

   ```
   ensure mon_pack_vetements
   ```

5. **Redémarrez** le serveur, ou dans la console du serveur :

   ```
   refresh
   ensure mon_pack_vetements
   ```

   Les joueurs déjà connectés doivent se reconnecter pour recevoir les nouveaux fichiers.
6. **Vérifiez la console** : aucune erreur ne doit mentionner la ressource. Un avertissement « oversized » signale un fichier trop lourd (plus de 16 Mo).
7. **Testez en jeu** avec le système de vêtements de votre serveur.

## Mode « remplacement »

Les fichiers remplacent les vêtements du jeu ayant **le même personnage, le même slot et le même numéro** (indiqués dans `export_report.json`). Tous les joueurs qui portent ces vêtements voient la nouvelle version. Aucune configuration supplémentaire n'est nécessaire.

## Mode « collection additionnelle »

- Le manifeste déclare `data_file 'SHOP_PED_APPAREL_META_FILE' 'data/<collection>.meta'` et le `.ymt` est diffusé depuis `stream/`.
- Les nouveaux vêtements s'ajoutent **après** ceux du jeu et des autres collections installées : leur numéro réel en jeu dépend donc de l'ordre et du nombre des collections présentes sur le serveur.
- Votre boutique ou menu de vêtements doit proposer ces nouveaux numéros.

## Systèmes de vêtements (ESX, QBCore, scripts de boutique…)

La ressource exportée contient uniquement les fichiers du jeu et le manifeste : elle ne dépend d'**aucun** framework.

La disponibilité d'un vêtement dans une boutique dépend du script utilisé (liste de vêtements autorisés, prix, numéros maximum, etc.). L'application ne génère pas de fichier de configuration pour ces scripts, car leurs formats varient : ajoutez vos vêtements dans la configuration de votre boutique selon sa documentation.

## En cas de problème

| Symptôme | Piste |
|---|---|
| Le vêtement n'apparaît pas | Nom du dossier ≠ nom de la ressource ; `ensure` manquant ; joueur non reconnecté ; mauvais personnage (homme / femme). |
| Vêtement invisible ou déformé | Le `.ydd` ne correspond pas au personnage ou au slot ; modèle mal préparé dans Blender (squelette, poids). |
| Texture noire ou violette | Nom de texture dans le `.ytd` différent de celui attendu par le `.ydd` ; format de texture non pris en charge. |
| « oversized » dans la console | Réduisez la taille des textures (2048 ou 1024 px). |
| Collection : numéros décalés | Normal : ils dépendent des autres collections installées. |
