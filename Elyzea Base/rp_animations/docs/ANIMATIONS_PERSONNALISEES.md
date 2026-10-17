# Animations personnalisées : état et procédure

## État actuel

**Aucune animation personnalisée n'a été produite.** Un script Lua ou une interface ne crée pas de mouvement 3D : il faut
des données d'animation (fichiers `.ycd`) faites pour le squelette des personnages de GTA V. Dans l'environnement où cette
ressource a été écrite, il n'y a ni logiciel 3D, ni squelette GTA, ni outil d'export, ni jeu pour tester. Aucun fichier vide
ou factice n'a été ajouté : les 29 fiches « à créer » restent grisées dans le menu tant qu'un vrai fichier n'existe pas.

## Ce qu'il manque

| Besoin | Outils possibles |
|---|---|
| Données de mouvement | Capture de mouvement (combinaison inertielle, Rokoko, Xsens), capture vidéo IA (Move.ai, Plask…), animation à la main, ou banque d'animations **sous licence autorisant cet usage** |
| Squelette cible | Squelette des peds freemode `mp_m_freemode_01` / `mp_f_freemode_01` (extrait du jeu avec OpenIV ou CodeWalker) |
| Logiciel 3D | Blender (gratuit) |
| Import / export GTA | Plugin **Sollumz** pour Blender (import du squelette, export `.ycd`) ; CodeWalker pour vérifier |
| Retargeting | Blender (contraintes, Auto-Rig Pro, Rokoko retargeting) vers le squelette GTA |
| Test | Un serveur FiveM de test, deux joueurs |

## Procédure pour une danse en duo

1. **Chorégraphie** : décrire les pas, la durée d'une boucle (idéalement 4 à 16 s, début = fin pour boucler sans saut),
   les rôles A et B, la distance et l'orientation de départ.
2. **Squelette** : importer `mp_m_freemode_01` et `mp_f_freemode_01` dans Blender avec Sollumz.
3. **Production** : capturer ou animer les **deux danseurs dans la même scène**, à partir d'une même origine
   (c'est ce qui permet ensuite `off = { x = 0, y = 0, z = 0, h = 0 }` dans le catalogue).
4. **Retargeting** sur le squelette GTA, nettoyage (pieds qui glissent, mains qui traversent le partenaire),
   déplacement racine figé (la danse reste sur place).
5. **Export** : un dictionnaire par animation, un clip par rôle, par exemple
   `rpa_salsa_debutant.ycd` contenant les clips `salsa_a` et `salsa_b`.
6. **Intégration** : créer `rp_animations/stream/` et y placer le `.ycd`, puis dans `shared/catalog.lua` remplacer la fiche :

   ```lua
   { n = 15, id = 'salsa_debutant', label = 'Salsa débutant', cat = 'salsa', type = 'duo', source = 'custom',
     status = 'a_valider', desc = 'Pas de base de salsa face à face.', loop = true,
     steps = { { A = { d = 'rpa_salsa_debutant', c = 'salsa_a' }, B = { d = 'rpa_salsa_debutant', c = 'salsa_b' },
                 off = { x = 0.0, y = 0.0, z = 0.0, h = 0.0 } } } },
   ```

   Le dossier `stream/` est diffusé automatiquement par FiveM (aucune ligne à ajouter au `fxmanifest.lua`).
7. **Test sur un personnage** : `rpanim_check` en F8 doit trouver le clip ; lancer en solo de test si besoin.
8. **Test en duo** : chaque rôle, homme et femme, orientation, distance (`/rpanim_calib` si besoin), boucle, arrêt par
   chacun, déconnexion.
9. **Validation** : `/rpanim_valider salsa_debutant` → statut « Personnalisée produite et testée ».

## Priorités suggérées (les plus demandées en RP, sans équivalent existant)

1. Salsa débutant, bachata classique, valse classique (duo, boucle sur place).
2. Slow avec rotations, faire tourner son partenaire, fin de danse élégante (révérence).
3. Tango, kizomba, merengue, versions solo de salsa et bachata.
4. Variantes suggestives (toujours habillées, non graphiques).
