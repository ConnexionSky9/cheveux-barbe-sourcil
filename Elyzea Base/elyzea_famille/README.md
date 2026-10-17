# elyzea_famille — moment intime, contraception, conception (version 0.1)

> **Non testé en jeu.** Ce qui a été vérifié hors du jeu :
> - règles de calcul : **39/39 tests** (`lua5.4 tests/test_regles.lua`), dont des tirages statistiques sur 200 000 essais ;
> - code serveur réel exécuté contre une **vraie base MariaDB** (FiveM simulé) : **37/37 contrôles** (`python3 tests/integration_test.py`) ;
> - syntaxe Lua et JavaScript ; interfaces affichées dans Chromium.
>
> À tester en jeu : placement face à face, animation, fondu au noir, touche X, menu ALT.

Première brique de l'écosystème famille (architecture : `docs/famille/AUDIT_ARCHITECTURE.md`).
Les modules suivants (découverte et suivi de grossesse, accouchement, enfants, crèche…) s'ajouteront dans cette même ressource.

## Installation
1. Dossier `elyzea_famille` dans `Elyzea Base` ; `server.cfg` : `ensure elyzea_famille` (déjà ajouté, après les métiers).
2. Tables créées automatiquement au démarrage (`sql/install.sql` contient les mêmes requêtes). Console : `[elyzea_famille] Prêt (...)`.
3. Objets ajoutés dans `elyzea_inventory/shared/items.lua` : `preservatif`, `pilule_contraceptive`, `implant_contraceptif`.
   Pour les vendre, ajoute-les à une boutique existante (pharmacie, supérette) ; staff : `/giveitem [id] preservatif 5`.

## Utilisation
| Action | Comment |
|---|---|
| Proposer un moment intime | **ALT** sur la personne › *Proposer un moment intime* (ou `/intimite` face à elle) |
| Accepter / refuser | fenêtre de consentement (Échap = refuser ; sans réponse en 30 s = refus) |
| Arrêter à tout moment | **X** (pour les deux personnes) |
| Préservatif | case à cocher dans la demande, ou utiliser l'objet pendant le moment |
| Pilule | utiliser l'objet : 48 h de protection, renouvelable dans les 12 dernières heures |
| Implant | posé par un EMS en service : **ALT** sur le patient › *Poser un implant contraceptif* (le patient accepte) |
| Mon état (privé) | `/contraception` |
| Staff | `/famille_etat [id]` (contraception, grossesse, dernières tentatives) — ACE `command.famille_etat` |

## Déroulé d'un moment intime
1. Demande → le serveur vérifie : deux personnages chargés, **majeurs** (date de naissance de la fiche), proches (2,5 m),
   ni à terre ni menottés, pas déjà occupés, limite de demandes (3/min, 60 s entre deux demandes à la même personne).
2. L'autre personne accepte → nouvelle vérification → préservatif retiré **une seule fois** s'il a été coché.
3. Les deux personnages se placent face à face, étreinte (animation native GTA `mp_ped_interaction`), **fondu au noir** pendant 30 s.
   Aucune image explicite : l'écran reste noir. Commandes bloquées sauf la voix et X.
4. Fin (durée écoulée, X, déconnexion, ressource arrêtée, redémarrage) : chacun retrouve son état normal.

## Contraception et conception (valeurs par défaut, `config.lua`)
| Réglage | Défaut |
|---|---|
| Probabilité « volontaire » (les deux ont coché *essayer d'avoir un enfant*) | 35 % |
| Probabilité « accidentelle » (`accidentelle = false` : jamais) | 12 % |
| Fiabilité préservatif / pilule / implant | 98 % / 99 % / 99,5 % |
| Durée pilule / implant | 48 h / 30 jours |
| Jumeaux / triplés (tirés séparément, après une conception) | 3 % / 0,2 % |
| Durée de grossesse | 336 h (14 jours) |
| Arrêt avant 60 % de la durée | aucune conception |
| Âge maximum de la personne qui porte | 55 ans |
| Délai après une grossesse | 48 h |

Calcul (serveur, une seule fois par moment) : `probabilité = base × (1 − fiabilité)` de chaque protection active de la personne qui porte
(pilule, implant) et du préservatif. Exemple : accidentelle + préservatif + pilule = 12 % × 2 % × 1 % = 0,0024 %.
Règle RP : la personne de sexe féminin porte l'enfant, avec un partenaire de sexe masculin ; sinon aucune conception (l'adoption viendra plus tard).

Résultats enregistrés (`rp_conception_attempts.resultat`) : `conception`, `echec_contraception` (conception malgré une protection),
`protege`, `aucune`, `impossible` (+ raison : `meme_sexe`, `age_max`, `deja_enceinte`, `delai_apres_grossesse`), `interrompu`,
`accidentelle_desactivee`, `desactive`.
**Rien n'est annoncé aux joueurs** : la grossesse se découvrira par les symptômes, un test ou un examen (module suivant).

## Garanties techniques
- Une seule tentative par moment (contrainte unique SQL) ; une seule grossesse en cours par personne (index unique `active_key`).
- Grossesse créée dans une transaction (grossesse + événement + lien) : tout ou rien.
- Objets retirés par le serveur après validation ; rendus si l'écriture en base échoue.
- Réponses de consentement vérifiées (identifiant de demande) ; toute réponse sans demande est journalisée (`rp_famille_logs`, action `suspect`).
- Déconnexion pendant un moment : interrompu, aucune conception. Redémarrage : moments en cours marqués interrompus.
- Dates en secondes Unix : la protection et le terme continuent hors ligne et après redémarrage.

## Fichiers modifiés ailleurs
- `elyzea_inventory/shared/items.lua` : 3 objets ajoutés.
- `elyzea_police/client/alt.lua` : fournisseur `elyzea_famille` ajouté au menu ALT ; `elyzea_police/html/app.js` : 3 icônes.
- `Serveur cfg/server.cfg` : `ensure elyzea_famille`.

## Limites connues
- **Animation** : animation native réutilisée (étreinte), pas une animation créée pour l'occasion ; le reste est un écran noir.
  Une animation duo sur mesure demanderait le squelette des personnages GTA (fichiers du jeu).
- La distance est vérifiée par le serveur seulement avec OneSync (sinon `verifierDistance = false` : seule la vérification du client reste).
- Ordonnance de pilule : prévue mais désactivée par défaut (`pilule.ordonnance = false`).
- Les objets n'ont pas encore d'image (icône émoji) ; ils ne sont dans aucune boutique.
