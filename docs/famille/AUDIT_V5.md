# Audit avant la V5 (refonte du système famille) — bugs identifiés et plan de correction

Sauvegarde : V4 = commit `d9daf3f` (branche `claude/dreamy-ritchie-7vdqzv`), paquet `elyzea_famille_v4.zip`.
Fichiers examinés : `elyzea_famille` (tous les fichiers serveur, client, config, SQL, tests), `elyzea_bebe_modele` V4,
`elyzea_core` (joueurs, fiche d'identité, faim / soif, exports), `ely_creator` (sexe, date de naissance), `elyzea_multichar`,
`elyzea_clothing` (catégories de la boutique), `Serveur cfg/server.cfg`, liste publique des animations de GTA V.

## 1. Versions présentes
| Version | Contenu | État |
|---|---|---|
| V1 → V3 | moment intime avec consentement, contraception, conception, grossesse, test, examen EMS, réglages admin | code exécuté avec une vraie base MariaDB (tests) ; **jamais testé en jeu** |
| V4 (actuelle) | bébé V4, endormi, porte-bébés ventral / dorsal 3D, poussette 3D (objet attaché), états sous verrou | code testé hors du jeu ; **jamais testé en jeu** |

## 2. Bug prioritaire : « le test reste négatif, même à 100 % sans préservatif »
Chaîne vérifiée : moment → fin → tirage → enregistrement → test.

| # | Cause trouvée dans le code | Effet | Correction |
|---|---|---|---|
| **B1** | La part du moment « réellement faite » est calculée **à la seconde près depuis un départ arrondi** : un moment **terminé** peut valoir 93 % (ou moins si la durée est courte). Le seuil « part minimale » (`dureeMinPourConception`) est appliqué **à tous les moments**, pas seulement aux moments arrêtés. | Si ce seuil est réglé à 100 % dans le menu admin, **aucun moment terminé ne donne jamais de conception**, quel que soit le risque. | Un moment terminé par le serveur compte pour 100 % ; le seuil ne sert qu'aux moments arrêtés (si l'option est activée). |
| **B2** | Le test n'est positif **qu'après 24 h réelles** (`Config.Grossesse.test.delai = 24`) et ce délai **n'est pas dans le menu admin**. Avant, le test répond « négatif » avec le même message qu'un vrai négatif. | Un test fait juste après le moment est **toujours négatif**. | Délai réglable dans le menu (en minutes, défaut 60 min), message RP qui rappelle qu'un test trop précoce peut être négatif. |
| **B3** | Après le délai, 1 test sur 100 reste négatif (`fiabilite = 0.99`). | Contraire à la règle demandée (« après le délai : positif »). | Fiabilité 100 % par défaut, réglable. |
| **B4** | **Deux risques différents** : « volontaire » (les DEUX personnes cochent « souhaiter un enfant », 35 %) et « accidentel » (sinon, 12 %). Régler l'un à 100 % ne change rien si le moment tombe dans l'autre cas. | « 100 % » sans effet apparent. | Libellés explicites dans le menu, et le diagnostic staff affiche quel risque a été appliqué et pourquoi. |
| **B5** | Le diagnostic staff `/famille_etat` ne montre que les tentatives qui ont une « porteuse ». Les tentatives refusées (`interrompu`, `meme_sexe`, `accidentelle_desactivee`, `age_max`…) n'en ont pas : **elles sont invisibles**. | Impossible de voir pourquoi une tentative échoue. | Lecture par la session (personnes A et B), raison en clair, probabilité, tirage. |
| **B6** | Les étapes de grossesse sont en **jours fixes** (3, 7, 11, 13) : si la durée est changée (ex. 2 jours), les étapes ne correspondent plus. | Étapes et futur ventre faux. | Étapes en **pourcentage** de la grossesse, réglables. |
| **B7** | Au terme, rien ne se passe : la grossesse reste « Terme atteint » sans fin possible. | Grossesse sans fin, effets permanents. | Accouchement (EMS) qui clôt la grossesse proprement et crée le ou les bébés ; fin par le staff ; fin automatique des effets. |
| — | Vérifié sans problème : sexe (1 = femme dans `elyzea_core`, `ely_creator`, `elyzea_multichar`), date de naissance (`AAAA-MM-JJ`), une seule tentative par moment (contrainte SQL), transaction de création de grossesse, lien au bon personnage (`citizenid`), dates en secondes Unix (pas de fuseau horaire, continue hors ligne et après un redémarrage). | | |

## 3. Autres points de l'audit
| Sujet | Constat |
|---|---|
| Ventre **VeloxFv1** | **Aucun fichier du pack dans le dépôt** : il est chargé par `ensure [vetements]` (dossier non fourni). La catégorie boutique « Gants et bras » d'`elyzea_clothing` correspond au **composant GTA 3** (torse / bras, « uppr ») : ce composant définit la peau visible sous le haut ; le remplacer par un ventre explique les **trous / vêtements transparents** signalés. Le drawable et la texture exacts ne peuvent être connus qu'avec le pack ou en jeu (les numéros des vêtements ajoutés dépendent de l'ordre de chargement). |
| Faim | gérée par `elyzea_core` (−4,2 points toutes les 5 min) ; exports `GetMetadata` / `SetMetadata` disponibles : accélération possible sans toucher au core. |
| Nausées / vomissements | animations natives réelles : `anim@scripted@nightclub@vomit@` / `vomit`, `missfam5_blackout` / `vomit` ; démarche lourde `move_f@fat@a` (vérifiés dans la liste des animations de GTA V). |
| Bébé, portage, poussette (V4) | rien de bloquant dans le code ; **positions et rendu jamais vus en jeu**. La poussette V4 est un objet attaché / figé : **pas de physique** (pas de pente, pas de chute). Une vraie physique demande des collisions intégrées au modèle (objet dynamique) : nouveau travail (étape 6). |
| Sommeil du bébé | existe (V4, paupières fermées, synchronisé) ; état en mémoire du serveur comme le bébé lui-même. |
| Menu admin | un seul (onglet Famille), permission `famille_manage`, table `rp_famille_reglages` : à compléter, pas à dupliquer. |

## 4. Plan de correction (ordre imposé)
1. **Étape 2 — bugs** : B1, B2, B3, B5, B6 + libellés B4. Tests automatiques : 100 % → grossesse enregistrée et test positif après le délai ; 0 % → rien ; protection ; moment arrêté ; une tentative ; test trop tôt / après ; redémarrage.
2. **Étape 3 — grossesse, contraception, symptômes** : progression en pourcentage, fin de grossesse (accouchement EMS, fin staff, effets coupés), symptômes réglables un par un (faim ×N, nausées, vomissements, ralentissement), tous dans le menu admin.
3. **Étape 4 — ventre** : mécanisme générique (composant, drawable, texture par stade, sauvegarde / restauration de la tenue, réapplication après changement de tenue) + **outil d'identification en jeu** ; les vrais numéros VeloxFv1 restent à relever sur le serveur (fichiers absents).
4. **Étapes 5-6 — bébé, portage, porte-bébés, poussette** : après retour des tests en jeu de la V4 (positions), physique de poussette (objet dynamique avec collisions).
5. **Étapes 7-8 — menu admin, tests complets.**
