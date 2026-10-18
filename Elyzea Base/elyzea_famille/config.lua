-- =====================================================================
--  ELYZEA FAMILLE - configuration
--  Toutes les durées « réelles » sont en heures sauf mention contraire.
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
    duree = 30,                  -- secondes d'écran noir (durée de l'interaction)
    dureeMinPourConception = 0.6, -- utilisé seulement si Config.Conception.siInterrompu = true
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
    duree = 336,                 -- heures réelles (14 jours) entre conception et terme
    -- Test de grossesse (objet) : positif seulement après ce délai depuis la conception
    test = { item = 'test_grossesse', delai = 24, fiabilite = 0.99 },   -- heures · 0.99 = 1 faux négatif sur 100
    examenEms = true,            -- EMS en service : « Examen de grossesse » (menu ALT) = résultat sûr + nombre de bébés
    commande = 'grossesse',      -- /grossesse : suivi privé (si la grossesse est connue)
    -- Étapes affichées (jour de grossesse -> description) ; la dernière s'applique au-delà
    etapes = {
        { jusqua = 3, label = 'Ventre presque plat' },
        { jusqua = 7, label = 'Léger arrondi' },
        { jusqua = 11, label = 'Ventre visible' },
        { jusqua = 13, label = 'Ventre très arrondi' },
        { jusqua = 999, label = 'Terme atteint' },
    },
}

-- Commandes staff (permission ACE : command.<nom>, déjà incluse dans group.admin)
Config.Staff = {
    etat = 'famille_etat',       -- /famille_etat [id] : contraception, grossesse, dernier moment intime
}
