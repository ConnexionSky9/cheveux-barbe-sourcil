-- =====================================================================
--  ELYZEA FAMILLE - configuration
--  Toutes les durées « réelles » sont en heures sauf mention contraire (minutes : « Minutes » dans le nom).
--  Les probabilités sont entre 0 et 1 (0.25 = 25 %).
-- =====================================================================
Config = {}

Config.Debug = false

-- Modules (false = désactivé, sans effet sur les autres)
Config.Modules = {
    intimite = true,         -- demande / consentement / animation
    contraception = true,    -- préservatif, pilule, implant
    conception = true,       -- tirage de conception à la fin d'un moment intime
}

-- Âge minimum d'un personnage (date de naissance de la fiche d'identité). ely_creator l'impose déjà à la création.
Config.AgeMin = 18

-- ─────────────────────────── Moment intime ───────────────────────────
Config.Intimite = {
    distanceMax = 2.5,           -- mètres entre les deux personnages pour envoyer / accepter une demande
    verifierDistance = true,     -- contrôle serveur de la distance (OneSync requis ; false si le serveur n'a pas OneSync)
    expirationDemande = 30,      -- secondes pour accepter
    attenteEntreDemandes = 60,   -- secondes entre deux demandes vers la même personne
    demandesParMinute = 3,       -- demandes max envoyées par minute (toutes personnes confondues)
    duree = 15,                  -- secondes d'écran noir (durée de l'interaction) — modifiable dans admin_menu › Famille
    dureeMin = 5,                -- bornes que la durée ne peut pas dépasser (aussi modifiables dans le menu)
    dureeMax = 120,
    dureeMinPourConception = 0.6, -- seulement pour un moment ARRÊTÉ, si Config.Conception.siInterrompu = true (un moment terminé compte toujours)
    delaiEntreMoments = 30,      -- minutes : délai pour chaque personne après un moment intime terminé (0 = aucun)
    distanceCouple = 1.0,        -- distance entre les deux personnages pendant l'étreinte (mètres)
    fondu = 1500,                -- millisecondes du fondu au noir / retour
    delaiAvantNoir = 2500,       -- millisecondes d'étreinte visible avant le fondu
    toucheAnnuler = 73,          -- contrôle GTA « X » (INPUT_VEH_DUCK) : arrêter
    -- Animations natives de GTA V (paire utilisée aussi par rpemotes pour « hug »). Aucune animation explicite.
    anim = {
        demandeur = { dict = 'mp_ped_interaction', clip = 'kisses_guy_a' },
        partenaire = { dict = 'mp_ped_interaction', clip = 'kisses_guy_b' },
    },
    commande = 'intimite',       -- /intimite : proposer à la personne en face (si le menu ALT n'est pas disponible)
}

-- ─────────────────────────── Contraception ───────────────────────────
-- fiabilite = probabilité que la méthode empêche une conception (0.98 = échoue 2 fois sur 100).
-- Plusieurs méthodes actives se combinent : risque = probabilité de base × (1 - f1) × (1 - f2)…
Config.Contraception = {
    preservatif = {
        actif = true, item = 'preservatif', label = 'Préservatif', fiabilite = 0.98,
    },
    pilule = {
        actif = true, item = 'pilule_contraceptive', label = 'Pilule contraceptive', fiabilite = 0.99,
        duree = 48,              -- heures de protection après une prise
        renouvellement = 12,     -- une nouvelle prise n'est acceptée que dans les X dernières heures (pas de cumul)
        ordonnance = false,      -- true : une ordonnance (EMS) en cours de validité est exigée
        dureeOrdonnance = 720,   -- heures de validité d'une ordonnance (30 jours)
    },
    implant = {
        actif = true, item = 'implant_contraceptif', label = 'Implant contraceptif', fiabilite = 0.995,
        duree = 720,             -- heures (30 jours réels)
        poseParEms = true,       -- true : posé par un EMS en service (menu ALT) ; false : utilisable seul
    },
    historique = 15,             -- lignes affichées dans « Ma contraception »
    commande = 'contraception',  -- /contraception : état privé
}

-- ─────────────────────────── Conception ───────────────────────────
Config.Conception = {
    -- « Volontaire » = les deux personnes ont coché « nous souhaitons un enfant ».
    probaVolontaire = 0.35,
    -- « Accidentelle » = au moins une des deux ne l'a pas coché.
    accidentelle = true,         -- false : seule une tentative volontaire peut aboutir
    probaAccidentelle = 0.12,
    -- Règle RP : la personne qui porte l'enfant est la personne de sexe féminin (fiche d'identité),
    -- son ou sa partenaire de sexe masculin. Autres cas : aucune conception (adoption plus tard).
    ageMaxPorteur = 55,          -- au-delà : aucune conception
    delaiApresGrossesse = 48,    -- heures après la fin d'une grossesse avant une nouvelle conception
    -- Grossesses multiples : tirées SÉPARÉMENT, seulement après une conception réussie
    multiples = { actif = true, jumeaux = 0.03, triples = 0.002, triplesActifs = true },
    -- Moment arrêté avant la fin (X, déconnexion…) : false = AUCUNE tentative (défaut) ;
    -- true = tentative si au moins Config.Intimite.dureeMinPourConception de la durée a été atteinte
    siInterrompu = false,
    forcer = false,              -- TEST UNIQUEMENT : conception à 100 % (toujours false en production)
}

-- ─────────────────────────── Grossesse (utilisé dès la conception) ───────────────────────────
Config.Grossesse = {
    -- Durée par trimestre (V7), dans l'unité choisie : 'secondes', 'minutes', 'heures' ou 'jours'. 0 est accepté
    -- (trimestre instantané). Durée totale = somme des trois. Modifiables dans le menu admin (Famille › Durée et progression).
    -- Une modification s'applique aussi aux grossesses en cours (progression déjà acquise conservée).
    unite = 'heures',
    trimestres = { 112, 112, 112 },  -- 3 × 112 h = 14 jours réels
    -- Test de grossesse (objet) : négatif avant ce délai depuis la conception, positif après (fiabilité 1 = toujours)
    test = { item = 'test_grossesse', delaiMinutes = 60, fiabilite = 1.0 },
    examenEms = true,            -- EMS en service : « Examen de grossesse » (menu ALT) = résultat sûr + nombre de bébés
    commande = 'grossesse',      -- /grossesse : suivi privé (si la grossesse est connue)
    -- Étapes (part de la grossesse écoulée -> description) : en POURCENTAGE de la durée, pour rester justes
    -- quelle que soit la durée réglée (0.25 = jusqu'au quart de la grossesse). La dernière s'applique au-delà et au terme.
    etapes = {
        { jusqua = 0.20, label = 'Ventre presque plat' },
        { jusqua = 0.50, label = 'Léger arrondi' },
        { jusqua = 0.80, label = 'Ventre visible' },
        { jusqua = 0.95, label = 'Ventre très arrondi' },
        { jusqua = 1.00, label = 'Terme atteint' },
    },
    suiviApresFin = 168,         -- heures pendant lesquelles l'application montre encore une grossesse terminée (accouchement…)
    suivi = 5,                   -- secondes entre deux calculs (trimestres, terme, symptômes, ventre) : tests rapides possibles
    -- Symptômes (personne enceinte seulement, découverte ou non). Étapes : 1 presque plat … 4 très arrondi, 5 terme.
    -- Tous réglables un par un dans le menu admin (F10 › Autres › Famille › Symptômes).
    symptomes = {
        -- faim plus rapide : elyzea_core retire tauxBase points toutes les intervalle minutes ; on retire en plus
        -- (multiplicateur - 1) × tauxBase au même rythme. tauxBase / intervalle = Config.Needs de elyzea_core.
        faim = { actif = true, desEtape = 1, jusquaEtape = 5, multiplicateur = 2.0, tauxBase = 4.2, intervalle = 5 },
        -- nausées : vision troublée et caméra qui tangue (aucune animation), parHeure = fréquence moyenne
        nausees = { actif = true, desEtape = 1, jusquaEtape = 3, parHeure = 2.0, duree = 20, intensite = 0.5 },
        -- vomissements : animation native vérifiée (anim@scripted@nightclub@vomit@ / vomit) ; jamais en véhicule,
        -- dans l'eau, à terre ou en portant un bébé (le message seul est affiché)
        vomissements = { actif = true, desEtape = 1, jusquaEtape = 2, parHeure = 0.5 },
        -- ralentissement : démarche lourde native (move_f@fat@a), course interdite en option
        ralentissement = { actif = true, desEtape = 3, jusquaEtape = 5, courseInterdite = false, demarche = 'move_f@fat@a' },
    },
    -- Fin de grossesse
    fin = {
        accouchementDes = 0.90,  -- part de la grossesse à partir de laquelle un EMS peut faire accoucher (1 = au terme seulement)
        dureeAccouchement = 20,  -- secondes (écran noir pour la patiente, l'EMS reste à genoux)
        naissanceAutoActive = true, -- naissance automatique sans EMS (personnage connecté)
        naissanceAuto = 24,      -- heures après le terme avant cette naissance automatique ; 0 = dès le terme
        bebesEnJeu = true,       -- crée le ou les bébés (ressource elyzea_bebe_modele) à côté de la patiente
        apparenceBebe = { teinte = 'peau3', tenue = 'pyjama', yeux = 'ardoise', coiffure = 'duvet_brun' },
    },
}

-- ─────────────────────────── Ventre de grossesse (vêtement d'un pack, ex. VeloxFv1) ───────────────────────────
-- Le ventre est un VÊTEMENT du pack posé par-dessus la tenue, à partir d'une étape. La pièce d'origine est
-- gardée et remise à la fin (et n'est jamais remplacée dans la tenue enregistrée, ni dans les objets vêtements).
-- Les numéros du pack ne sont PAS dans ce dépôt (pack chargé par « ensure [vetements] ») : à relever en jeu.
--   1. Porter le ventre (boutique ou /ventre_essai), puis /ventre_info : composant, collection et n° local s'affichent.
--   2. Recopier ces valeurs ici ou dans le menu admin (Famille › Ventre de grossesse), puis activer.
-- collection = nom de la collection du pack (fiable même si l'ordre des packs change) ; vide = n° « global » GTA.
-- li = n° du ventre dans la collection (-1 = rien à cette étape), texture = n° de texture.
Config.Ventre = {
    actif = false,               -- à activer une fois les numéros relevés
    composant = 3,               -- composant GTA qui porte le ventre (3 = torse / bras ; à confirmer avec /ventre_info)
    collection = '',
    etapes = {
        e2 = { li = -1, texture = 0 },   -- Léger arrondi
        e3 = { li = -1, texture = 0 },   -- Ventre visible
        e4 = { li = -1, texture = 0 },   -- Ventre très arrondi
        e5 = { li = -1, texture = 0 },   -- Terme atteint
    },
    -- Compatibilité : 'toujours' = ventre quel que soit le haut ; 'sansHaut' = seulement sans haut (composant 11 nu) ;
    -- 'liste' = seulement avec un haut de la liste hautsCompatibles ({ col = '…', li = n } ou { drawable = n })
    compatibilite = 'toujours',
    hautsCompatibles = {},
    hautNu = { [0] = 15, [1] = 15 },     -- n° « haut nu » (homme, femme), comme elyzea_clothing
}

-- Commandes staff (permission ACE : command.<nom>, déjà incluse dans group.admin)
Config.Staff = {
    etat = 'famille_etat',       -- /famille_etat [id] : contraception, grossesse, dernier moment intime
    fin = 'famille_fin',         -- /famille_fin [id] [naissance] : met fin à la grossesse (sans bébé, ou avec « naissance »)
}

-- ─────────── Bébés et équipements (valeurs par défaut ; modifiables dans le menu admin › Famille) ───────────
-- Transmis à la ressource elyzea_bebe_modele (porte-bébés, poussette). Mêmes valeurs que sa config.lua.
Config.Bebe = {
    ventral = true,           -- porte-bébé ventral utilisable
    dorsal = true,            -- porte-bébé dorsal utilisable
    poussette = true,         -- poussette utilisable
    courseInterdite = true,   -- pas de course en poussant
    abandon = 20,             -- minutes avant de ranger une poussette vide abandonnée
    diagnostic = false,       -- journal détaillé dans la console serveur
    -- V6
    garder = true,            -- porteur déconnecté : le bébé reste avec lui et revient à sa connexion
    physique = true,          -- poussette lâchée sans frein : elle roule selon la pente
    crr = 0.035,              -- résistance au roulement
    seuilDepart = 0.045,      -- pente minimale (tan) pour qu'une poussette arrêtée parte toute seule
    vChoc = 2.6,              -- m/s : choc au-delà duquel elle se renverse
    roues = true,             -- roues qui tournent
    colorisPb = 'gris',       -- coloris par défaut des porte-bébés (gris, marine, sauge)
    colorisPoussette = 'graphite', -- coloris par défaut de la poussette (graphite, sable)
    -- V8 : soins (mêmes valeurs que Config.Soins d'elyzea_bebe_modele) ; « vitesse » accélère tout pour les tests
    soins = { actif = true, vitesse = 1, faim = 14, fatigue = 10, couche = 9, sommeilCouche = 30, sommeilPorte = 15,
              seuilAlerte = 60, seuilUrgent = 85, rappel = 10, dureeBiberon = 12, dureeCouche = 15, pauseGarde = true, reveilAuto = true },
    animPoussee = 'tondeuse',  -- V8 : animation de poussée (tondeuse = buste droit, bras vers la poignée ; chariot = ancienne)
    decalagePoussette = { y = 0, z = 0 },   -- V8 : cm, poussette poussée (réglage fin après essai en jeu)
    -- décalages de chaque prise (cm, degrés), ajoutés aux positions calculées : réglage fin après essai en jeu
    decalages = {
        face = { x = 0, y = 0, z = 0, rx = 0, ry = 0, rz = 0 },   -- V8 : « contre soi » (seule prise à la main)
        ventral = { x = 0, y = 0, z = 0, rz = 0 }, dorsal = { x = 0, y = 0, z = 0, rz = 0 },
    },
}
