-- =====================================================================
--  ELYZEA FAMILLE - serveur : réglages modifiables depuis le menu admin (admin_menu › Famille)
--  · Chaque réglage a un type, des bornes strictes et une description (SCHEMA ci-dessous).
--  · Les valeurs enregistrées sont stockées dans `rp_famille_reglages` et réappliquées au démarrage.
--  · Elles remplacent les valeurs de config.lua sans toucher au fichier ; « Valeurs par défaut » revient à config.lua.
--  · Permission : admin_menu « famille_manage », vérifiée par admin_menu ET revérifiée ici.
--  · Un moment intime déjà commencé garde les réglages de son démarrage (durée, fondu…) : les nouveaux
--    réglages s'appliquent aux moments suivants.
-- =====================================================================
local RES = GetCurrentResourceName()
local PERM = 'famille_manage'

-- section, clé, chemin dans Config, type (int | num | pct | bool | str | choix), bornes, libellé, aide
local SCHEMA = {
    -- Moment intime : durée
    { s = 'duree', k = 'intimite.duree', p = { 'Intimite', 'duree' }, t = 'int', min = 0, max = 600, u = 's',
      l = 'Durée de l\'écran noir', a = 'Durée du moment intime (après l\'étreinte). Doit rester entre la durée minimale et maximale ci-dessous.' },
    { s = 'duree', k = 'intimite.dureeMin', p = { 'Intimite', 'dureeMin' }, t = 'int', min = 0, max = 600, u = 's',
      l = 'Durée minimale autorisée', a = 'Garde-fou : la durée ne peut pas être réglée en dessous.' },
    { s = 'duree', k = 'intimite.dureeMax', p = { 'Intimite', 'dureeMax' }, t = 'int', min = 0, max = 600, u = 's',
      l = 'Durée maximale autorisée', a = 'Garde-fou : la durée ne peut pas être réglée au-dessus.' },
    { s = 'duree', k = 'intimite.fondu', p = { 'Intimite', 'fondu' }, t = 'int', min = 0, max = 5000, u = 'ms',
      l = 'Fondu au noir / retour', a = 'Durée du fondu d\'écran au début et à la fin.' },
    { s = 'duree', k = 'intimite.delaiAvantNoir', p = { 'Intimite', 'delaiAvantNoir' }, t = 'int', min = 0, max = 10000, u = 'ms',
      l = 'Étreinte visible avant le noir', a = 'Temps pendant lequel l\'étreinte est visible avant le fondu.' },
    -- Annulation
    { s = 'annulation', k = 'conception.siInterrompu', p = { 'Conception', 'siInterrompu' }, t = 'bool',
      l = 'Tentative même si le moment est arrêté', a = 'Désactivé (conseillé) : un moment arrêté avant la fin (X, déconnexion) ne déclenche aucune tentative. Activé : tentative si le seuil ci-dessous est atteint.' },
    { s = 'annulation', k = 'intimite.dureeMinPourConception', p = { 'Intimite', 'dureeMinPourConception' }, t = 'pct', min = 0.1, max = 1.0,
      l = 'Seuil pour un moment arrêté', a = 'Utilisé seulement si l\'option précédente est activée : part de la durée à atteindre.' },
    -- Positionnement
    { s = 'position', k = 'intimite.animation', p = { 'Intimite', 'animation' }, t = 'choix', choix = { 'baiser', 'bise' },
      l = 'Animation', a = 'baiser (V8) : face à face, contre l\'autre. bise : ancienne animation (bise sur la joue, ressemble à un câlin).' },
    { s = 'position', k = 'intimite.baiserAvant', p = { 'Intimite', 'anims', 'baiser', 'attache', 'avant' }, t = 'num', min = 0, max = 0.6, step = 0.01, u = 'm',
      l = 'Baiser : écart entre les deux personnages', a = 'Distance entre les bassins (0,08 m par défaut). À ajuster en jeu si les visages ne se touchent pas.' },
    { s = 'position', k = 'intimite.distanceCouple', p = { 'Intimite', 'distanceCouple' }, t = 'num', min = 0.3, max = 2.0, step = 0.05, u = 'm',
      l = 'Distance (animation « bise »)', a = 'La personne qui accepte se place face à l\'autre, à cette distance.' },
    -- Conditions de déclenchement
    { s = 'conditions', k = 'intimite.distanceMax', p = { 'Intimite', 'distanceMax' }, t = 'num', min = 1.0, max = 10.0, step = 0.5, u = 'm',
      l = 'Distance maximale pour proposer', a = 'Distance entre les deux personnes pour envoyer et accepter une demande.' },
    { s = 'conditions', k = 'intimite.expirationDemande', p = { 'Intimite', 'expirationDemande' }, t = 'int', min = 10, max = 120, u = 's',
      l = 'Temps pour répondre', a = 'Sans réponse dans ce délai, la demande est refusée.' },
    { s = 'conditions', k = 'intimite.attenteEntreDemandes', p = { 'Intimite', 'attenteEntreDemandes' }, t = 'int', min = 0, max = 3600, u = 's',
      l = 'Attente entre deux demandes', a = 'Entre deux demandes vers la même personne.' },
    { s = 'conditions', k = 'intimite.demandesParMinute', p = { 'Intimite', 'demandesParMinute' }, t = 'int', min = 1, max = 20,
      l = 'Demandes maximum par minute', a = 'Anti-abus, toutes personnes confondues.' },
    { s = 'conditions', k = 'intimite.delaiEntreMoments', p = { 'Intimite', 'delaiEntreMoments' }, t = 'int', min = 0, max = 1440, u = 'min',
      l = 'Délai après un moment terminé', a = 'Pour chaque personne, avant un nouveau moment intime (0 = aucun).' },
    -- Risque de grossesse
    { s = 'grossesse', k = 'modules.conception', p = { 'Modules', 'conception' }, t = 'bool',
      l = 'Conception activée', a = 'Désactivé : aucun moment intime ne peut donner de grossesse, le test est toujours négatif.' },
    { s = 'grossesse', k = 'conception.probaVolontaire', p = { 'Conception', 'probaVolontaire' }, t = 'pct', min = 0, max = 1,
      l = 'Risque si LES DEUX ont coché « souhaiter un enfant »', a = 'Utilisé seulement si les deux personnes ont coché la case dans la demande. Moment terminé, sans contraception. Le diagnostic /famille_etat indique quel risque a été appliqué.' },
    { s = 'grossesse', k = 'conception.accidentelle', p = { 'Conception', 'accidentelle' }, t = 'bool',
      l = 'Grossesses accidentelles', a = 'Désactivé : seule une tentative où les deux ont coché « souhaiter un enfant » peut aboutir.' },
    { s = 'grossesse', k = 'conception.probaAccidentelle', p = { 'Conception', 'probaAccidentelle' }, t = 'pct', min = 0, max = 1,
      l = 'Risque accidentel (case non cochée)', a = 'Utilisé dès qu\'au moins une personne n\'a PAS coché « souhaiter un enfant ». Moment terminé, sans contraception. Pour tester à 100 %, réglez les DEUX risques à 100 %.' },
    { s = 'grossesse', k = 'conception.jumeaux', p = { 'Conception', 'multiples', 'jumeaux' }, t = 'pct', min = 0, max = 0.5,
      l = 'Jumeaux', a = 'Tiré séparément, seulement après une conception.' },
    { s = 'grossesse', k = 'conception.triples', p = { 'Conception', 'multiples', 'triples' }, t = 'pct', min = 0, max = 0.2,
      l = 'Triplés', a = 'Tiré séparément, seulement après une conception.' },
    { s = 'progression', k = 'grossesse.unite', p = { 'Grossesse', 'unite' }, t = 'choix', choix = { 'secondes', 'minutes', 'heures', 'jours' },
      l = 'Unité des durées', a = 'Unité des trois trimestres ci-dessous (conversion exacte en secondes par le serveur).' },
    { s = 'progression', k = 'grossesse.t1', p = { 'Grossesse', 'trimestres', 1 }, t = 'num', min = 0, max = 100000, step = 0.01,
      l = 'Durée du 1er trimestre', a = 'Avant le passage au 2e trimestre. 0 = instantané.' },
    { s = 'progression', k = 'grossesse.t2', p = { 'Grossesse', 'trimestres', 2 }, t = 'num', min = 0, max = 100000, step = 0.01,
      l = 'Durée du 2e trimestre', a = 'Commence à la fin du 1er. 0 = instantané.' },
    { s = 'progression', k = 'grossesse.t3', p = { 'Grossesse', 'trimestres', 3 }, t = 'num', min = 0, max = 100000, step = 0.01,
      l = 'Durée du 3e trimestre', a = 'Commence à la fin du 2e ; le terme arrive à sa fin. Durée totale = somme des trois (affichée en haut).' },
    { s = 'progression', k = 'conception.delaiApresGrossesse', p = { 'Conception', 'delaiApresGrossesse' }, t = 'num', min = 0, max = 720, step = 0.01, u = 'h',
      l = 'Délai avant une nouvelle grossesse', a = 'Heures après la fin d\'une grossesse avant qu\'une nouvelle conception soit possible (0 = aucun).' },
    { s = 'grossesse', k = 'grossesse.test.delaiMinutes', p = { 'Grossesse', 'test', 'delaiMinutes' }, t = 'int', min = 0, max = 10080, u = 'min',
      l = 'Délai de détection du test', a = 'Temps après la conception avant qu\'un test de grossesse puisse être positif. Avant : négatif (le message rappelle qu\'un test trop tôt peut être négatif). 0 = détectable tout de suite.' },
    { s = 'grossesse', k = 'grossesse.test.fiabilite', p = { 'Grossesse', 'test', 'fiabilite' }, t = 'pct', min = 0.5, max = 1,
      l = 'Fiabilité du test après le délai', a = '100 % = toujours positif après le délai en cas de grossesse.' },
    { s = 'etapes', k = 'grossesse.etape1', p = { 'Grossesse', 'etapes', 1, 'jusqua' }, t = 'pct', min = 0.01, max = 0.99,
      l = 'Fin de l\'étape « Ventre presque plat »', a = 'Part de la grossesse écoulée (les étapes suivent la durée réglée).' },
    { s = 'etapes', k = 'grossesse.etape2', p = { 'Grossesse', 'etapes', 2, 'jusqua' }, t = 'pct', min = 0.01, max = 0.99,
      l = 'Fin de l\'étape « Léger arrondi »', a = 'Doit être plus grand que l\'étape précédente.' },
    { s = 'etapes', k = 'grossesse.etape3', p = { 'Grossesse', 'etapes', 3, 'jusqua' }, t = 'pct', min = 0.01, max = 0.99,
      l = 'Fin de l\'étape « Ventre visible »', a = 'Doit être plus grand que l\'étape précédente.' },
    { s = 'etapes', k = 'grossesse.etape4', p = { 'Grossesse', 'etapes', 4, 'jusqua' }, t = 'pct', min = 0.01, max = 0.99,
      l = 'Fin de l\'étape « Ventre très arrondi »', a = 'Ensuite : « Terme atteint » (au terme réel seulement).' },
    -- Symptômes (chacun réglable séparément ; étapes 1 = presque plat … 4 = très arrondi, 5 = terme)
    { s = 'symptomes', k = 'symptomes.faim.actif', p = { 'Grossesse', 'symptomes', 'faim', 'actif' }, t = 'bool',
      l = 'Faim plus rapide', a = 'La faim baisse plus vite (en plus de la baisse normale de elyzea_core).' },
    { s = 'symptomes', k = 'symptomes.faim.multiplicateur', p = { 'Grossesse', 'symptomes', 'faim', 'multiplicateur' }, t = 'num', min = 1, max = 5, step = 0.1, u = '×',
      l = 'Vitesse de la faim', a = '2 = la faim baisse deux fois plus vite.' },
    { s = 'symptomes', k = 'symptomes.faim.desEtape', p = { 'Grossesse', 'symptomes', 'faim', 'desEtape' }, t = 'int', min = 1, max = 5,
      l = 'Faim : à partir de l\'étape', a = '1 = dès la conception.' },
    { s = 'symptomes', k = 'symptomes.nausees.actif', p = { 'Grossesse', 'symptomes', 'nausees', 'actif' }, t = 'bool',
      l = 'Nausées', a = 'Vision troublée et caméra qui tangue quelques secondes.' },
    { s = 'symptomes', k = 'symptomes.nausees.desEtape', p = { 'Grossesse', 'symptomes', 'nausees', 'desEtape' }, t = 'int', min = 1, max = 5,
      l = 'Nausées : à partir de l\'étape', a = '' },
    { s = 'symptomes', k = 'symptomes.nausees.jusquaEtape', p = { 'Grossesse', 'symptomes', 'nausees', 'jusquaEtape' }, t = 'int', min = 1, max = 5,
      l = 'Nausées : jusqu\'à l\'étape', a = '' },
    { s = 'symptomes', k = 'symptomes.nausees.parHeure', p = { 'Grossesse', 'symptomes', 'nausees', 'parHeure' }, t = 'num', min = 0, max = 30, step = 0.5, u = '/h',
      l = 'Nausées : fréquence', a = 'Nombre moyen d\'épisodes par heure de jeu (moments tirés au hasard).' },
    { s = 'symptomes', k = 'symptomes.nausees.duree', p = { 'Grossesse', 'symptomes', 'nausees', 'duree' }, t = 'int', min = 0, max = 120, u = 's',
      l = 'Nausées : durée', a = 'Durée d\'un épisode.' },
    { s = 'symptomes', k = 'symptomes.nausees.intensite', p = { 'Grossesse', 'symptomes', 'nausees', 'intensite' }, t = 'pct', min = 0.1, max = 1,
      l = 'Nausées : intensité', a = 'Force du flou et du tangage.' },
    { s = 'symptomes', k = 'symptomes.vomissements.actif', p = { 'Grossesse', 'symptomes', 'vomissements', 'actif' }, t = 'bool',
      l = 'Vomissements', a = 'Animation native de GTA. Jamais en véhicule, dans l\'eau, à terre ou en portant un bébé (message seul).' },
    { s = 'symptomes', k = 'symptomes.vomissements.desEtape', p = { 'Grossesse', 'symptomes', 'vomissements', 'desEtape' }, t = 'int', min = 1, max = 5,
      l = 'Vomissements : à partir de l\'étape', a = '' },
    { s = 'symptomes', k = 'symptomes.vomissements.jusquaEtape', p = { 'Grossesse', 'symptomes', 'vomissements', 'jusquaEtape' }, t = 'int', min = 1, max = 5,
      l = 'Vomissements : jusqu\'à l\'étape', a = '' },
    { s = 'symptomes', k = 'symptomes.vomissements.parHeure', p = { 'Grossesse', 'symptomes', 'vomissements', 'parHeure' }, t = 'num', min = 0, max = 10, step = 0.1, u = '/h',
      l = 'Vomissements : fréquence', a = 'Nombre moyen d\'épisodes par heure de jeu.' },
    { s = 'symptomes', k = 'symptomes.ralentissement.actif', p = { 'Grossesse', 'symptomes', 'ralentissement', 'actif' }, t = 'bool',
      l = 'Démarche lourde', a = 'Démarche native « lourde » (move_f@fat@a).' },
    { s = 'symptomes', k = 'symptomes.ralentissement.desEtape', p = { 'Grossesse', 'symptomes', 'ralentissement', 'desEtape' }, t = 'int', min = 1, max = 5,
      l = 'Démarche lourde : à partir de l\'étape', a = '' },
    { s = 'symptomes', k = 'symptomes.ralentissement.courseInterdite', p = { 'Grossesse', 'symptomes', 'ralentissement', 'courseInterdite' }, t = 'bool',
      l = 'Course interdite (démarche lourde)', a = 'Activé : la touche de course est bloquée pendant la démarche lourde.' },
    -- Fin de grossesse
    { s = 'fin', k = 'fin.accouchementDes', p = { 'Grossesse', 'fin', 'accouchementDes' }, t = 'pct', min = 0.5, max = 1,
      l = 'Accouchement possible à partir de', a = 'Part de la grossesse écoulée à partir de laquelle un EMS peut faire accoucher (100 % = au terme).' },
    { s = 'fin', k = 'fin.dureeAccouchement', p = { 'Grossesse', 'fin', 'dureeAccouchement' }, t = 'int', min = 0, max = 120, u = 's',
      l = 'Durée de l\'étape « Naissance »', a = 'Écran noir pour la patiente (sauf péridurale) ; l\'EMS doit rester à côté. Plus aucune naissance automatique (V8).' },
    { s = 'fin', k = 'fin.bebesEnJeu', p = { 'Grossesse', 'fin', 'bebesEnJeu' }, t = 'bool',
      l = 'Bébé placé dans le jeu à la naissance', a = 'Le ou les bébés (elyzea_bebe_modele) apparaissent à côté de la patiente.' },
    -- V8 : accouchement obligatoirement assisté par un EMS (étapes, délais, péridurale, secours)
    { s = 'accouchement', k = 'acc.evaluation.delai', p = { 'Grossesse', 'accouchement', 'etapes', 2, 'delai' }, t = 'int', min = 0, max = 3600, u = 's',
      l = 'Évaluation : délai après l\'étape précédente', a = 'Secondes minimales (0 = aussitôt, pour les tests).' },
    { s = 'accouchement', k = 'acc.evaluation.duree', p = { 'Grossesse', 'accouchement', 'etapes', 2, 'duree' }, t = 'int', min = 0, max = 120, u = 's',
      l = 'Évaluation : durée de l\'acte', a = 'Secondes pendant lesquelles l\'EMS et la patiente restent sur place (0 = immédiat).' },
    { s = 'accouchement', k = 'acc.preparation.delai', p = { 'Grossesse', 'accouchement', 'etapes', 3, 'delai' }, t = 'int', min = 0, max = 3600, u = 's',
      l = 'Préparation : délai après l\'étape précédente', a = 'Secondes minimales (0 = aussitôt, pour les tests).' },
    { s = 'accouchement', k = 'acc.preparation.duree', p = { 'Grossesse', 'accouchement', 'etapes', 3, 'duree' }, t = 'int', min = 0, max = 120, u = 's',
      l = 'Préparation : durée de l\'acte', a = 'Secondes pendant lesquelles l\'EMS et la patiente restent sur place (0 = immédiat).' },
    { s = 'accouchement', k = 'acc.travail.delai', p = { 'Grossesse', 'accouchement', 'etapes', 4, 'delai' }, t = 'int', min = 0, max = 3600, u = 's',
      l = 'Travail : délai après l\'étape précédente', a = 'Secondes minimales (0 = aussitôt, pour les tests).' },
    { s = 'accouchement', k = 'acc.travail.duree', p = { 'Grossesse', 'accouchement', 'etapes', 4, 'duree' }, t = 'int', min = 0, max = 120, u = 's',
      l = 'Travail : durée de l\'acte', a = 'Secondes pendant lesquelles l\'EMS et la patiente restent sur place (0 = immédiat).' },
    { s = 'accouchement', k = 'acc.naissance.delai', p = { 'Grossesse', 'accouchement', 'etapes', 5, 'delai' }, t = 'int', min = 0, max = 3600, u = 's',
      l = 'Naissance : délai après l\'étape précédente', a = 'Secondes minimales (0 = aussitôt, pour les tests).' },
    { s = 'accouchement', k = 'acc.validation.delai', p = { 'Grossesse', 'accouchement', 'etapes', 6, 'delai' }, t = 'int', min = 0, max = 3600, u = 's',
      l = 'Validation finale : délai après l\'étape précédente', a = 'Secondes minimales (0 = aussitôt, pour les tests).' },
    { s = 'accouchement', k = 'acc.peridurale', p = { 'Grossesse', 'accouchement', 'peridurale' }, t = 'bool',
      l = 'Péridurale proposée', a = 'L\'EMS peut la proposer après l\'évaluation ; la patiente accepte ou refuse. Elle ne fait jamais naître le bébé.' },
    { s = 'accouchement', k = 'acc.distance', p = { 'Grossesse', 'accouchement', 'distance' }, t = 'num', min = 1, max = 15, step = 0.5, u = 'm',
      l = 'Distance EMS / patiente', a = 'Distance maximale pour chaque étape.' },
    { s = 'accouchement', k = 'acc.appelAuTerme', p = { 'Grossesse', 'accouchement', 'appelAuTerme' }, t = 'bool',
      l = 'Appel automatique des EMS au terme', a = 'Activé : un appel part vers le dispatch EMS quand l\'accouchement devient possible. Sinon la patiente appelle (Urgences, /ems).' },
    { s = 'accouchement', k = 'acc.secours', p = { 'Grossesse', 'accouchement', 'secours' }, t = 'bool',
      l = 'Procédure de secours (administration)', a = 'Bloc « Tests » : accouchement sans EMS, permission famille_manage, motif obligatoire, journalisé.' },
    { s = 'accouchement', k = 'acc.secoursSansEms', p = { 'Grossesse', 'accouchement', 'secoursSansEmsSeulement' }, t = 'bool',
      l = 'Secours seulement si aucun EMS en service', a = 'Activé : refusée dès qu\'un EMS est en service (la procédure normale reste obligatoire).' },
    -- Ventre (vêtement d'un pack ; numéros à relever en jeu avec /ventre_info)
    { s = 'ventre', k = 'ventre.actif', p = { 'Ventre', 'actif' }, t = 'bool',
      l = 'Ventre de grossesse', a = 'Pose le ventre du pack par-dessus la tenue selon l\'étape. N\'activer qu\'après avoir relevé les numéros (/ventre_info).' },
    { s = 'ventre', k = 'ventre.composant', p = { 'Ventre', 'composant' }, t = 'int', min = 0, max = 11,
      l = 'Composant GTA du ventre', a = 'Affiché par /ventre_info en portant le ventre (3 = torse / bras, 8 = sous-haut, 11 = haut…).' },
    { s = 'ventre', k = 'ventre.collection', p = { 'Ventre', 'collection' }, t = 'str', max = 64,
      l = 'Collection du pack', a = 'Nom affiché par /ventre_info (« col »). Vide = numéros globaux (déconseillé : changent si l\'ordre des packs change).' },
    { s = 'ventre', k = 'ventre.e2.li', p = { 'Ventre', 'etapes', 'e2', 'li' }, t = 'int', min = -1, max = 4000,
      l = 'Étape 2 (léger arrondi) : n°', a = 'N° local dans la collection (« li »). -1 = pas de ventre.' },
    { s = 'ventre', k = 'ventre.e2.texture', p = { 'Ventre', 'etapes', 'e2', 'texture' }, t = 'int', min = 0, max = 63,
      l = 'Étape 2 : texture', a = '' },
    { s = 'ventre', k = 'ventre.e3.li', p = { 'Ventre', 'etapes', 'e3', 'li' }, t = 'int', min = -1, max = 4000,
      l = 'Étape 3 (ventre visible) : n°', a = '-1 = pas de ventre.' },
    { s = 'ventre', k = 'ventre.e3.texture', p = { 'Ventre', 'etapes', 'e3', 'texture' }, t = 'int', min = 0, max = 63,
      l = 'Étape 3 : texture', a = '' },
    { s = 'ventre', k = 'ventre.e4.li', p = { 'Ventre', 'etapes', 'e4', 'li' }, t = 'int', min = -1, max = 4000,
      l = 'Étape 4 (très arrondi) : n°', a = '-1 = pas de ventre.' },
    { s = 'ventre', k = 'ventre.e4.texture', p = { 'Ventre', 'etapes', 'e4', 'texture' }, t = 'int', min = 0, max = 63,
      l = 'Étape 4 : texture', a = '' },
    { s = 'ventre', k = 'ventre.e5.li', p = { 'Ventre', 'etapes', 'e5', 'li' }, t = 'int', min = -1, max = 4000,
      l = 'Étape 5 (terme) : n°', a = '-1 = pas de ventre.' },
    { s = 'ventre', k = 'ventre.e5.texture', p = { 'Ventre', 'etapes', 'e5', 'texture' }, t = 'int', min = 0, max = 63,
      l = 'Étape 5 : texture', a = '' },
    -- Contraception
    { s = 'contraception', k = 'contraception.preservatif.fiabilite', p = { 'Contraception', 'preservatif', 'fiabilite' }, t = 'pct', min = 0, max = 1,
      l = 'Fiabilité du préservatif', a = '98 % = le risque est multiplié par 0,02.' },
    { s = 'contraception', k = 'contraception.pilule.fiabilite', p = { 'Contraception', 'pilule', 'fiabilite' }, t = 'pct', min = 0, max = 1,
      l = 'Fiabilité de la pilule', a = 'Appliquée si une prise est encore active pour la personne qui porte.' },
    { s = 'contraception', k = 'contraception.pilule.duree', p = { 'Contraception', 'pilule', 'duree' }, t = 'int', min = 0, max = 720, u = 'h',
      l = 'Protection d\'une pilule', a = 'Durée de protection après une prise.' },
    { s = 'contraception', k = 'contraception.pilule.renouvellement', p = { 'Contraception', 'pilule', 'renouvellement' }, t = 'int', min = 0, max = 720, u = 'h',
      l = 'Renouvellement de la pilule', a = 'Nouvelle prise acceptée seulement dans ces dernières heures (pas de cumul).' },
    { s = 'contraception', k = 'contraception.implant.fiabilite', p = { 'Contraception', 'implant', 'fiabilite' }, t = 'pct', min = 0, max = 1,
      l = 'Fiabilité de l\'implant', a = 'Appliquée tant que l\'implant est actif.' },
    { s = 'contraception', k = 'contraception.implant.duree', p = { 'Contraception', 'implant', 'duree' }, t = 'int', min = 0, max = 8760, u = 'h',
      l = 'Durée de l\'implant', a = 'S\'applique aux implants posés ensuite.' },
    -- Bébés et équipements (ressource elyzea_bebe_modele : valeurs transmises à chaque enregistrement et au démarrage)
    { s = 'bebe', k = 'bebe.ventral', p = { 'Bebe', 'ventral' }, t = 'bool',
      l = 'Porte-bébé ventral', a = 'Désactivé : l\'objet ne peut plus être équipé ni recevoir le bébé (les porte-bébés déjà en cours restent jusqu\'à leur retrait).' },
    { s = 'bebe', k = 'bebe.dorsal', p = { 'Bebe', 'dorsal' }, t = 'bool',
      l = 'Porte-bébé dorsal', a = 'Désactivé : l\'objet ne peut plus être équipé ni recevoir le bébé.' },
    { s = 'bebe', k = 'bebe.poussette', p = { 'Bebe', 'poussette' }, t = 'bool',
      l = 'Poussette', a = 'Désactivé : impossible de sortir, pousser une poussette ou d\'y installer le bébé (on peut encore en sortir le bébé et la ranger).' },
    { s = 'bebe', k = 'bebe.courseInterdite', p = { 'Bebe', 'courseInterdite' }, t = 'bool',
      l = 'Pas de course avec la poussette', a = 'Activé : en poussant, la touche de course est bloquée (marche et petit trot).' },
    { s = 'bebe', k = 'bebe.abandon', p = { 'Bebe', 'abandon' }, t = 'int', min = 0, max = 240, u = 'min',
      l = 'Poussette vide abandonnée', a = 'Une poussette vide, garée loin de son propriétaire (ou propriétaire parti), est rangée après ce délai.' },
    { s = 'bebe', k = 'bebe.diagnostic', p = { 'Bebe', 'diagnostic' }, t = 'bool',
      l = 'Journal de diagnostic', a = 'Activé : chaque prise, pose, attache refusée… est écrite dans la console serveur (pour le développement).' },
    { s = 'bebe', k = 'bebe.garder', p = { 'Bebe', 'garder' }, t = 'bool',
      l = 'Bébé gardé à la déconnexion', a = 'Activé : un bébé porté par un joueur qui se déconnecte reste avec ce personnage et revient à ses pieds à sa connexion. Désactivé : posé au sol.' },
    { s = 'bebe', k = 'bebe.physique', p = { 'Bebe', 'physique' }, t = 'bool',
      l = 'Poussette : physique', a = 'Activé : lâchée sans frein (ou frein desserré), elle roule selon la pente, s\'arrête aux obstacles, peut se renverser. Désactivé : toujours garée frein serré.' },
    { s = 'bebe', k = 'bebe.roues', p = { 'Bebe', 'roues' }, t = 'bool',
      l = 'Poussette : roues qui tournent', a = 'Roues séparées animées par chaque joueur (aucun coût réseau).' },
    { s = 'bebe', k = 'bebe.crr', p = { 'Bebe', 'crr' }, t = 'num', min = 0.005, max = 0.2, step = 0.005,
      l = 'Poussette : résistance au roulement', a = 'Plus haut = s\'arrête plus vite (0,035 ≈ roues gonflées sur bitume).' },
    { s = 'bebe', k = 'bebe.seuilDepart', p = { 'Bebe', 'seuilDepart' }, t = 'num', min = 0, max = 0.3, step = 0.005,
      l = 'Poussette : pente de départ', a = 'Pente (0,045 = 4,5 %) à partir de laquelle une poussette arrêtée, frein desserré, se met à rouler.' },
    { s = 'bebe', k = 'bebe.vChoc', p = { 'Bebe', 'vChoc' }, t = 'num', min = 1, max = 8, step = 0.1, u = 'm/s',
      l = 'Poussette : choc qui la renverse', a = 'Vitesse au moment d\'un choc au-delà de laquelle elle se renverse (le bébé est posé à côté).' },
    { s = 'bebe', k = 'bebe.animPoussee', p = { 'Bebe', 'animPoussee' }, t = 'choix', choix = { 'tondeuse', 'chariot' },
      l = 'Animation de poussée', a = 'tondeuse : buste droit, bras tendus vers la poignée (V8). chariot : ancienne animation (dos voûté).' },
    { s = 'soins', k = 'bebe.soins.actif', p = { 'Bebe', 'soins', 'actif' }, t = 'bool',
      l = 'Soins du bébé', a = 'Activé : faim, sommeil et couche évoluent ; biberon, couche et vêtements utilisables.' },
    { s = 'soins', k = 'bebe.soins.vitesse', p = { 'Bebe', 'soins', 'vitesse' }, t = 'num', min = 0, max = 3600, step = 1, u = '×',
      l = 'Vitesse des besoins (tests)', a = '1 = temps normal ; 60 = une heure de besoins par minute (tests à deux joueurs). 0 = besoins figés.' },
    { s = 'soins', k = 'bebe.soins.faim', p = { 'Bebe', 'soins', 'faim' }, t = 'num', min = 0, max = 1000, step = 0.5, u = 'pts/h',
      l = 'Faim et soif gagnées par heure', a = 'Points par heure (sur 100).' },
    { s = 'soins', k = 'bebe.soins.fatigue', p = { 'Bebe', 'soins', 'fatigue' }, t = 'num', min = 0, max = 1000, step = 0.5, u = 'pts/h',
      l = 'Fatigue gagnée par heure éveillé', a = 'Points par heure.' },
    { s = 'soins', k = 'bebe.soins.couche', p = { 'Bebe', 'soins', 'couche' }, t = 'num', min = 0, max = 1000, step = 0.5, u = 'pts/h',
      l = 'Couche : salissure par heure', a = 'Points par heure.' },
    { s = 'soins', k = 'bebe.soins.sommeilCouche', p = { 'Bebe', 'soins', 'sommeilCouche' }, t = 'num', min = 0, max = 1000, step = 0.5, u = 'pts/h',
      l = 'Sommeil couché : récupération par heure', a = 'Points de fatigue perdus par heure de sommeil, bébé posé ou dans la poussette.' },
    { s = 'soins', k = 'bebe.soins.sommeilPorte', p = { 'Bebe', 'soins', 'sommeilPorte' }, t = 'num', min = 0, max = 1000, step = 0.5, u = 'pts/h',
      l = 'Sommeil porté : récupération par heure', a = 'Points de fatigue perdus par heure de sommeil, bébé porté.' },
    { s = 'soins', k = 'bebe.soins.seuilAlerte', p = { 'Bebe', 'soins', 'seuilAlerte' }, t = 'num', min = 1, max = 100, step = 1, u = '%',
      l = 'Seuil de notification', a = 'Besoin à partir duquel le porteur (ou les parents) est prévenu.' },
    { s = 'soins', k = 'bebe.soins.seuilUrgent', p = { 'Bebe', 'soins', 'seuilUrgent' }, t = 'num', min = 1, max = 100, step = 1, u = '%',
      l = 'Seuil urgent', a = 'Seconde notification, plus insistante (au moins égal au seuil de notification).' },
    { s = 'soins', k = 'bebe.soins.rappel', p = { 'Bebe', 'soins', 'rappel' }, t = 'num', min = 0, max = 240, step = 1, u = 'min',
      l = 'Délai entre deux rappels', a = 'Minutes entre deux notifications pour un même besoin (aucune répétition en dessous).' },
    { s = 'soins', k = 'bebe.soins.dureeBiberon', p = { 'Bebe', 'soins', 'dureeBiberon' }, t = 'num', min = 0, max = 120, step = 1, u = 's',
      l = 'Durée du biberon', a = 'Secondes (0 = immédiat).' },
    { s = 'soins', k = 'bebe.soins.dureeCouche', p = { 'Bebe', 'soins', 'dureeCouche' }, t = 'num', min = 0, max = 120, step = 1, u = 's',
      l = 'Durée du change', a = 'Secondes (0 = immédiat).' },
    { s = 'soins', k = 'bebe.soins.pauseGarde', p = { 'Bebe', 'soins', 'pauseGarde' }, t = 'bool',
      l = 'Pause quand le bébé est avec un joueur déconnecté', a = 'Activé : ses besoins n\'évoluent pas tant que la personne qui le garde est déconnectée.' },
    { s = 'soins', k = 'bebe.soins.reveilAuto', p = { 'Bebe', 'soins', 'reveilAuto' }, t = 'bool',
      l = 'Réveil automatique', a = 'Activé : le bébé se réveille seul une fois reposé.' },
    { s = 'decalages', k = 'bebe.dec.poussette.y', p = { 'Bebe', 'decalagePoussette', 'y' }, t = 'num', min = -30, max = 30, step = 0.5, u = 'cm',
      l = 'Poussette poussée : plus près / plus loin', a = 'Rapproche la poignée des mains selon l\'animation de poussée.' },
    { s = 'decalages', k = 'bebe.dec.poussette.z', p = { 'Bebe', 'decalagePoussette', 'z' }, t = 'num', min = -30, max = 30, step = 0.5, u = 'cm',
      l = 'Poussette poussée : plus haut / plus bas', a = '' },
    { s = 'bebe', k = 'bebe.colorisPb', p = { 'Bebe', 'colorisPb' }, t = 'choix', choix = { 'gris', 'marine', 'sauge' },
      l = 'Coloris par défaut des porte-bébés', a = 'Chaque joueur peut choisir le sien (/coloris_porte_bebe).' },
    { s = 'bebe', k = 'bebe.colorisPoussette', p = { 'Bebe', 'colorisPoussette' }, t = 'choix', choix = { 'graphite', 'sable' },
      l = 'Coloris par défaut de la poussette', a = 'Chaque joueur peut choisir le sien (/coloris_poussette).' },
    { s = 'decalages', k = 'bebe.dec.face.x', p = { 'Bebe', 'decalages', 'face', 'x' }, t = 'num', min = -20, max = 20, step = 0.5, u = 'cm',
      l = 'Contre soi : gauche / droite', a = '' },
    { s = 'decalages', k = 'bebe.dec.face.y', p = { 'Bebe', 'decalages', 'face', 'y' }, t = 'num', min = -20, max = 20, step = 0.5, u = 'cm',
      l = 'Contre soi : avant / arrière', a = '' },
    { s = 'decalages', k = 'bebe.dec.face.z', p = { 'Bebe', 'decalages', 'face', 'z' }, t = 'num', min = -20, max = 20, step = 0.5, u = 'cm',
      l = 'Contre soi : haut / bas', a = '' },
    { s = 'decalages', k = 'bebe.dec.face.rz', p = { 'Bebe', 'decalages', 'face', 'rz' }, t = 'num', min = -45, max = 45, step = 0.5, u = '°',
      l = 'Contre soi : rotation', a = '' },
    { s = 'decalages', k = 'bebe.dec.face.rx', p = { 'Bebe', 'decalages', 'face', 'rx' }, t = 'num', min = -45, max = 45, step = 0.5, u = '°',
      l = 'Contre soi : bascule avant / arrière', a = 'Incline le bébé vers le porteur ou vers l\'extérieur.' },
    { s = 'decalages', k = 'bebe.dec.face.ry', p = { 'Bebe', 'decalages', 'face', 'ry' }, t = 'num', min = -45, max = 45, step = 0.5, u = '°',
      l = 'Contre soi : tête plus haute / plus basse', a = 'Relève ou abaisse la tête du bébé dans le creux du bras.' },
    { s = 'decalages', k = 'bebe.dec.ventral.x', p = { 'Bebe', 'decalages', 'ventral', 'x' }, t = 'num', min = -20, max = 20, step = 0.5, u = 'cm',
      l = 'Porte-bébé ventral : gauche / droite', a = '' },
    { s = 'decalages', k = 'bebe.dec.ventral.y', p = { 'Bebe', 'decalages', 'ventral', 'y' }, t = 'num', min = -20, max = 20, step = 0.5, u = 'cm',
      l = 'Porte-bébé ventral : avant / arrière', a = '' },
    { s = 'decalages', k = 'bebe.dec.ventral.z', p = { 'Bebe', 'decalages', 'ventral', 'z' }, t = 'num', min = -20, max = 20, step = 0.5, u = 'cm',
      l = 'Porte-bébé ventral : haut / bas', a = '' },
    { s = 'decalages', k = 'bebe.dec.ventral.rz', p = { 'Bebe', 'decalages', 'ventral', 'rz' }, t = 'num', min = -45, max = 45, step = 0.5, u = '°',
      l = 'Porte-bébé ventral : rotation', a = '' },
    { s = 'decalages', k = 'bebe.dec.dorsal.x', p = { 'Bebe', 'decalages', 'dorsal', 'x' }, t = 'num', min = -20, max = 20, step = 0.5, u = 'cm',
      l = 'Porte-bébé dorsal : gauche / droite', a = '' },
    { s = 'decalages', k = 'bebe.dec.dorsal.y', p = { 'Bebe', 'decalages', 'dorsal', 'y' }, t = 'num', min = -20, max = 20, step = 0.5, u = 'cm',
      l = 'Porte-bébé dorsal : avant / arrière', a = '' },
    { s = 'decalages', k = 'bebe.dec.dorsal.z', p = { 'Bebe', 'decalages', 'dorsal', 'z' }, t = 'num', min = -20, max = 20, step = 0.5, u = 'cm',
      l = 'Porte-bébé dorsal : haut / bas', a = '' },
    { s = 'decalages', k = 'bebe.dec.dorsal.rz', p = { 'Bebe', 'decalages', 'dorsal', 'rz' }, t = 'num', min = -45, max = 45, step = 0.5, u = '°',
      l = 'Porte-bébé dorsal : rotation', a = '' },
}

local SECTIONS = {
    { id = 'duree', label = 'Durée du moment intime' },
    { id = 'annulation', label = 'Annulation' },
    { id = 'position', label = 'Positionnement des personnages' },
    { id = 'conditions', label = 'Conditions de déclenchement' },
    { id = 'grossesse', label = 'Risque de grossesse' },
    { id = 'progression', label = 'Durée et progression de grossesse' },
    { id = 'etapes', label = 'Étapes de la grossesse' },
    { id = 'symptomes', label = 'Symptômes de grossesse' },
    { id = 'fin', label = 'Fin de grossesse' },
    { id = 'accouchement', label = 'Accouchement assisté par un EMS' },
    { id = 'ventre', label = 'Ventre de grossesse' },
    { id = 'contraception', label = 'Effets de la contraception' },
    { id = 'bebe', label = 'Bébés et équipements' },
    { id = 'soins', label = 'Soins du bébé (faim, sommeil, couche)' },
    { id = 'decalages', label = 'Position du bébé porté (réglage fin)' },
}

local PAR_CLE = {}
for _, d in ipairs(SCHEMA) do PAR_CLE[d.k] = d end

local function lire(p)
    local t = Config
    for i = 1, #p do t = t and t[p[i]] end
    return t
end

local function ecrire(p, v)
    local t = Config
    for i = 1, #p - 1 do t = t[p[i]] end
    t[p[#p]] = v
end

-- Valeurs de config.lua (copie prise au démarrage, avant tout réglage enregistré)
local DEFAUTS = {}
for _, d in ipairs(SCHEMA) do DEFAUTS[d.k] = lire(d.p) end

-- Valide UNE valeur. Renvoie la valeur propre ou nil, raison
local function valider(d, v)
    if d.t == 'bool' then
        if type(v) ~= 'boolean' then return nil, 'oui / non attendu' end
        return v
    end
    if d.t == 'choix' then
        for _, c in ipairs(d.choix) do if v == c then return v end end
        return nil, 'choix : ' .. table.concat(d.choix, ', ')
    end
    if d.t == 'str' then
        if type(v) ~= 'string' then return nil, 'texte attendu' end
        v = v:gsub('^%s+', ''):gsub('%s+$', '')
        if #v > (d.max or 64) or not v:match('^[%w_%-%.]*$') then return nil, 'lettres, chiffres, _ - . seulement' end
        return v
    end
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil, 'nombre attendu' end
    if v < d.min or v > d.max then return nil, ('entre %s et %s'):format(d.min, d.max) end
    if d.t == 'int' then v = math.floor(v + 0.5) end
    return v
end

-- Valide un ensemble complet (règles croisées comprises). Renvoie table propre ou nil, liste d'erreurs
local function validerTout(valeurs)
    local out, err = {}, {}
    for _, d in ipairs(SCHEMA) do
        local v = valeurs[d.k]
        if v == nil then v = lire(d.p) end
        local ok, why = valider(d, v)
        if ok == nil then err[#err + 1] = ('%s : %s'):format(d.l, why) else out[d.k] = ok end
    end
    if #err == 0 then
        if out['intimite.dureeMin'] > out['intimite.dureeMax'] then err[#err + 1] = 'La durée minimale dépasse la durée maximale.' end
        local du = out['intimite.duree']
        if du < out['intimite.dureeMin'] or du > out['intimite.dureeMax'] then
            err[#err + 1] = ('La durée doit être entre %d et %d s.'):format(out['intimite.dureeMin'], out['intimite.dureeMax'])
        end
        if out['conception.jumeaux'] + out['conception.triples'] > 1 then err[#err + 1] = 'Jumeaux + triplés ne peuvent pas dépasser 100 %.' end
        for i = 2, 4 do
            if out['grossesse.etape' .. i] <= out['grossesse.etape' .. (i - 1)] then
                err[#err + 1] = ('L\'étape %d doit finir après l\'étape %d.'):format(i, i - 1)
            end
        end
        for _, n in ipairs({ 'nausees', 'vomissements' }) do
            if out['symptomes.' .. n .. '.desEtape'] > out['symptomes.' .. n .. '.jusquaEtape'] then
                err[#err + 1] = ('%s : l\'étape de début dépasse l\'étape de fin.'):format(n == 'nausees' and 'Nausées' or 'Vomissements')
            end
        end
        if out['contraception.pilule.renouvellement'] > out['contraception.pilule.duree'] then
            err[#err + 1] = 'Le renouvellement de la pilule ne peut pas dépasser sa durée de protection.'
        end
    end
    if #err > 0 then return nil, err end
    return out
end

local function appliquerLocal(valeurs)
    for _, d in ipairs(SCHEMA) do
        if valeurs[d.k] ~= nil then ecrire(d.p, valeurs[d.k]) end
    end
end

-- Réglages des bébés : transmis à elyzea_bebe_modele (qui les applique et les publie aux clients)
local function reglagesBebe()
    local v = {}
    for _, d in ipairs(SCHEMA) do if d.s == 'bebe' or d.s == 'decalages' then v[d.k] = lire(d.p) end end
    return v
end

local function transmettreBebe()
    if GetResourceState('elyzea_bebe_modele') ~= 'started' then return end
    pcall(function() exports.elyzea_bebe_modele:AppliquerReglages(reglagesBebe()) end)
end

-- Réglages du ventre : publiés à tous les clients (chacun pose le ventre sur son propre personnage)
local function publierVentre()
    local V = Config.Ventre
    GlobalState.famVentre = { actif = V.actif, composant = V.composant, collection = V.collection, etapes = V.etapes,
        compatibilite = V.compatibilite, hautsCompatibles = V.hautsCompatibles, hautNu = { h = V.hautNu[0], f = V.hautNu[1] } }
end

local function appliquer(valeurs)
    appliquerLocal(valeurs)
    transmettreBebe()
    publierVentre()
end
publierVentre()

exports('ReglagesBebe', reglagesBebe)

local function actuelles()
    local v = {}
    for _, d in ipairs(SCHEMA) do v[d.k] = lire(d.p) end
    return v
end

-- ─────────── Chargement au démarrage ───────────

function Fam.ChargerReglages()
    local rows = MySQL.query.await('SELECT `cle`, `valeur` FROM `rp_famille_reglages`') or {}
    local enregistrees = {}
    for _, r in ipairs(rows) do
        local d = PAR_CLE[r.cle]
        if d then
            local ok, v = pcall(json.decode, r.valeur)
            if ok and v ~= nil then enregistrees[r.cle] = v end
        end
    end
    if next(enregistrees) == nil then return 0 end
    local propre, err = validerTout(enregistrees)
    if not propre then
        Fam.err('réglages enregistrés invalides, valeurs de config.lua utilisées : ' .. table.concat(err, ' ; '))
        return 0
    end
    appliquer(propre)
    local n = 0
    for _ in pairs(enregistrees) do n = n + 1 end
    print(('[%s] %d réglage(s) du menu admin appliqué(s).'):format(RES, n))
    return n
end

-- ─────────── Permission (revérifiée ici, même si admin_menu l'a déjà fait) ───────────

local function autorise(src)
    src = tonumber(src)
    if src == 0 then return true end
    if not src or GetResourceState('admin_menu') ~= 'started' then return false end
    local ok, r = pcall(function() return exports.admin_menu:HasPermission(src, PERM) end)
    return ok and r == true
end

-- ─────────── Exports pour admin_menu ───────────

exports('AdminData', function(src)
    if not autorise(src) then return { available = true, denied = true } end
    local schema = {}
    for _, d in ipairs(SCHEMA) do
        schema[#schema + 1] = { section = d.s, key = d.k, type = d.t, min = d.min, max = d.max, step = d.step, unit = d.u, label = d.l, help = d.a, choices = d.choix }
    end
    return {
        available = true,
        sections = SECTIONS, schema = schema,
        values = actuelles(), defaults = DEFAUTS,
        dureeTotale = (function() local _, _, _, t = Regles.durees(Config.Grossesse) return { secondes = t, texte = Regles.texteDuree(t) } end)(),
        sessions = Fam.SessionsEnCours and Fam.SessionsEnCours() or 0,
        diagnostic = (function()
            if GetResourceState('elyzea_bebe_modele') ~= 'started' then return nil end
            local ok, l = pcall(function() return exports.elyzea_bebe_modele:Diagnostic() end)
            return ok and l or nil
        end)(),
    }
end)

exports('AdminAction', function(src, name, data)
    if not autorise(src) then
        Fam.Suspect(src, 'réglages famille sans permission')
        return false, 'Permission refusée.'
    end
    local acteur = src == 0 and 'console' or ((Fam.Joueur(src) or {}).cid or ('src:' .. tostring(src)))
    if name == 'save' then
        if type(data) ~= 'table' or type(data.values) ~= 'table' then return false, 'Données invalides.' end
        local entree = {}
        for k, v in pairs(data.values) do if PAR_CLE[k] then entree[k] = v end end
        local propre, err = validerTout(entree)
        if not propre then return false, 'Refusé : ' .. table.concat(err, ' ; ') end
        local now = os.time()
        local q = {}
        for k, v in pairs(propre) do
            q[#q + 1] = { query = 'INSERT INTO `rp_famille_reglages` (`cle`, `valeur`, `updated_at`, `par`) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE `valeur` = VALUES(`valeur`), `updated_at` = VALUES(`updated_at`), `par` = VALUES(`par`)',
                values = { k, json.encode(v), now, acteur } }
        end
        if not MySQL.transaction.await(q) then return false, 'Erreur de base de données : rien n\'a été modifié.' end
        local avant = actuelles()
        appliquer(propre)
        local changes = {}
        for k, v in pairs(propre) do if avant[k] ~= v then changes[#changes + 1] = ('%s=%s'):format(k, tostring(v)) end end
        Fam.Audit(acteur, 'reglages_enregistres', nil, table.concat(changes, ', '))
        return true, #changes > 0 and ('Réglages enregistrés (%d modification(s)). Ils s\'appliquent aux prochains moments.'):format(#changes) or 'Aucune modification.'
    elseif name == 'test_debut' or name == 'test_fin' then
        if type(Fam.ActionTest) ~= 'function' then return false, 'Indisponible.' end
        return Fam.ActionTest(name, acteur, data)
    elseif name == 'accouchement_secours' then
        if type(Fam.AccouchementSecours) ~= 'function' then return false, 'Indisponible.' end
        return Fam.AccouchementSecours(data, acteur)
    elseif name == 'diag_suivi' then
        if type(Fam.DiagSuivi) ~= 'function' then return false, 'Indisponible.' end
        return Fam.DiagSuivi(data)
    elseif name == 'reset' then
        if not MySQL.transaction.await({ { query = 'DELETE FROM `rp_famille_reglages`', values = {} } }) then
            return false, 'Erreur de base de données : rien n\'a été modifié.'
        end
        appliquer(DEFAUTS)
        Fam.Audit(acteur, 'reglages_reinitialises')
        return true, 'Valeurs par défaut (config.lua) rétablies.'
    end
    return false, 'Action inconnue.'
end)

-- Tables déjà prêtes (ordre de chargement différent) : appliquer tout de suite
if Fam.TablesPretes then Fam.ChargerReglages() end

-- Pour les tests
Fam.ReglagesSchema = SCHEMA
