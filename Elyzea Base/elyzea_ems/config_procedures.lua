-- =====================================================================
--  ELYZEA EMS - ACTES MÉDICAUX EN MINI-JEUX (valeurs de départ)
--  Tout ce qui est marqué « réglable » se change en jeu : admin_menu › Santé ›
--  « Actes médicaux (mini-jeux) » (enregistré en base, table ems_settings).
--  Les contrôles de sécurité (distance, service, permission, durée minimale,
--  verrous anti-doublon, consentement) ne sont PAS réglables.
--
--  Chaque acte :
--    perm      : permission EMS (tablette › Direction › Grades › Permissions)
--    minLevel  : niveau de grade minimum (0 = aucun)                         [réglable]
--    duration  : durée indicative du mini-jeu en secondes                    [réglable]
--    difficulty: 1 facile · 2 intermédiaire · 3 difficile                     [réglable]
--    maxMistakes: erreurs tolérées avant échec                               [réglable]
--    retry     : un échec permet de recommencer tout de suite                [réglable]
--    items     : matériel vérifié AVANT le début ; consume = retiré à la réussite  [réglable]
--    consent   : 'always' (patient conscient obligatoire) · 'conscious' (demandé s'il est conscient) · false
--    patient   : 'any' · 'conscious' (debout) · 'down' (inconscient obligatoire)
--    service   : prestation ajoutée aux actes facturables (Config.Billing.services)
-- =====================================================================
Config.Procedures = {
    enabled = true,                 -- [réglable] coupe tous les mini-jeux (les anciens actes simples reprennent)
    distance = 3.0,                 -- distance EMS / patient (contrôlée par le serveur)
    consentTimeout = 25,            -- secondes laissées au patient pour accepter
    -- Marge réseau sur les durées : le serveur refuse un résultat arrivé avant
    -- minRatio × durée (impossible pour un humain) ou après durée × maxRatio + 20 s.
    minRatio = 0.35, maxRatio = 4.0,

    acts = {
        blood = { label = 'Prise de sang', icon = '🩸', perm = 'lab_sample', minLevel = 0, enabled = true,
            duration = 28, difficulty = 2, maxMistakes = 3, retry = true, consent = 'conscious', patient = 'any', service = 'blood',
            items = { { item = 'kit_prelevement', count = 1, consume = true } } },
        xray = { label = 'Radiographie', icon = '🦴', perm = 'imaging', minLevel = 0, enabled = true,
            duration = 26, difficulty = 2, maxMistakes = 2, retry = true, consent = 'conscious', patient = 'any', service = 'xray',
            items = {} },
        cast = { label = 'Attelle / plâtre', icon = '🩼', perm = 'heal', minLevel = 0, enabled = true,
            duration = 32, difficulty = 2, maxMistakes = 3, retry = true, consent = 'conscious', patient = 'any', service = 'splint',
            items = {} },   -- le matériel dépend du choix (attelle ou plâtre) : voir Config.Procedures.cast.materials
        hemostasis = { label = 'Contrôle d\'hémorragie', icon = '🩸', perm = 'stabilize', minLevel = 0, enabled = true,
            duration = 20, difficulty = 2, maxMistakes = 3, retry = true, consent = false, patient = 'any', service = 'hemostasis',
            items = { { item = 'gauze', count = 1, consume = true } } },
        dressing = { label = 'Pansement compressif', icon = '🩹', perm = 'stabilize', minLevel = 0, enabled = true,
            duration = 12, difficulty = 1, maxMistakes = 3, retry = true, consent = false, patient = 'any', service = 'hemostasis',
            items = { { item = 'bandage', count = 1, consume = true } } },
        cpr = { label = 'Massage cardiaque', icon = '❤️', perm = 'revive', minLevel = 0, enabled = true,
            duration = 36, difficulty = 2, maxMistakes = 6, retry = true, consent = false, patient = 'down', service = 'revive',
            items = {} },   -- le défibrillateur (facultatif) est vu dans Config.Procedures.cpr
        echo = { label = 'Échographie', icon = '🫀', perm = 'imaging', minLevel = 0, enabled = true,
            duration = 32, difficulty = 2, maxMistakes = 3, retry = true, consent = 'conscious', patient = 'any', service = 'echo',
            items = {} },
        scan = { label = 'Scanner', icon = '🧠', perm = 'imaging', minLevel = 0, enabled = true,
            duration = 28, difficulty = 2, maxMistakes = 3, retry = true, consent = 'conscious', patient = 'any', service = 'scan',
            items = {} },
        vaccine = { label = 'Vaccination', icon = '💉', perm = 'vaccinate', minLevel = 0, enabled = true,
            duration = 20, difficulty = 2, maxMistakes = 2, retry = true, consent = 'always', patient = 'conscious', service = 'vaccine',
            items = {} },   -- l'objet dépend du vaccin choisi (Config.Procedures.vaccines)
        implant = { label = 'Pose d\'implant contraceptif', icon = '💊', perm = 'implant', minLevel = 0, enabled = true,
            duration = 32, difficulty = 2, maxMistakes = 3, retry = true, consent = 'always', patient = 'conscious', service = 'implant',
            items = { { item = 'implant_contraceptif', count = 1, consume = false } } },   -- retiré par elyzea_famille à la pose
        implant_remove = { label = 'Retrait d\'implant contraceptif', icon = '💊', perm = 'implant', minLevel = 0, enabled = true,
            duration = 22, difficulty = 1, maxMistakes = 3, retry = true, consent = 'always', patient = 'conscious', service = 'implant',
            items = {} },
    },

    -- ------------------------------------------------------------------
    -- Zones du corps (radiographie, attelle, hémorragie, scanner, échographie)
    -- region : head / torso / abdomen / arm / leg (sert au scanner et à l'échographie)
    -- xray / cast : la zone peut être radiographiée / immobilisée
    -- ------------------------------------------------------------------
    zones = {
        { id = 'tete',        label = 'Tête',               region = 'head' },
        { id = 'thorax',      label = 'Thorax',             region = 'torso' },
        { id = 'abdomen',     label = 'Abdomen',            region = 'abdomen' },
        { id = 'bras_g',      label = 'Bras gauche',        region = 'arm', xray = true, cast = true },
        { id = 'bras_d',      label = 'Bras droit',         region = 'arm', xray = true, cast = true },
        { id = 'avantbras_g', label = 'Avant-bras gauche',  region = 'arm', xray = true, cast = true },
        { id = 'avantbras_d', label = 'Avant-bras droit',   region = 'arm', xray = true, cast = true },
        { id = 'jambe_g',     label = 'Jambe gauche',       region = 'leg', xray = true, cast = true },
        { id = 'jambe_d',     label = 'Jambe droite',       region = 'leg', xray = true, cast = true },
    },

    -- ------------------------------------------------------------------
    -- Blessures RP (table ems_injuries). Créées par le serveur :
    --   · coups reçus (le client signale la zone touchée et le type d'arme ; plafonné par le serveur) ;
    --   · chute de haut (jambe, en plus de la « Blessure à la jambe » existante) ;
    --   · staff : admin_menu › Santé › « Blessures ».
    -- ------------------------------------------------------------------
    injuries = {
        enabled = true,                 -- [réglable] détection des blessures par les coups reçus
        minDamage = 8,                  -- dégâts minimum d'un coup pour compter
        cooldown = 4,                   -- secondes minimum entre deux blessures signalées par un joueur
        maxActive = 6,                  -- blessures actives au maximum par personne
        -- hémorragie : arme à feu / arme blanche. Gravité selon les dégâts du coup
        bleed = { light = 8, major = 25, critical = 45 },     -- [réglable] seuils de dégâts → 1 légère · 2 importante · 3 critique
        -- fracture : coups violents (mêlée contondante, véhicule) sur un membre. Chance en % [réglable]
        fractureChance = 35, fractureMajorDamage = 40,
        -- lésion interne (tête, thorax, abdomen) : coup violent. Chance en % [réglable]
        internalChance = 25, internalMinDamage = 30,
        -- chute : fracture d'une jambe (en plus de la boiterie). Au-delà de « majorHeight » m : fracture à plâtrer
        fall = { majorHeight = 12.0 },
        -- saignement actif d'une personne consciente : perte de santé par minute (jamais en dessous du plancher du niveau)
        drain = { [1] = 1, [2] = 3, [3] = 6 }, drainFloor = 120,
        floors = { [1] = 170, [2] = 140, [3] = 110 },          -- santé minimale atteinte par le saignement, par niveau (200 = pleine)
        -- Hémorragie (audit V9) : perte de sang mesurée (ml), évolution du niveau, récupération
        hemorrhage = {
            rate = { [1] = 15, [2] = 60, [3] = 150 },          -- ml perdus par minute par plaie qui saigne, selon le niveau
            stopMinutes = 8,                                   -- niveau 1 (faible) non soigné : s'arrête seul après X min (caillot)
            worsenMinutes = 12,                                -- niveau 2 (moyen) non soigné : passe au niveau 3 après X min
            lossLevel2 = 750,                                  -- perte totale (ml) à partir de laquelle l'hémorragie est au moins moyenne
            lossLevel3 = 1500,                                 -- … au moins importante (patient critique)
            recoverPerMin = 15,                                -- ml récupérés par minute quand plus rien ne saigne
            maxLoss = 4000,                                    -- plafond de la perte enregistrée
            tick = 10,                                         -- secondes entre deux calculs (serveur)
        },
        healMinutes = 0,                -- [réglable] 0 = une blessure traitée est guérie ; sinon elle le devient après X min
    },

    -- Niveaux de gravité (affichage)
    bleedLevels = { [1] = 'Hémorragie faible', [2] = 'Hémorragie moyenne', [3] = 'Hémorragie importante' },
    fractureLevels = { [1] = 'Blessure nécessitant une immobilisation', [2] = 'Fracture nécessitant un plâtre' },
    internalLabels = { head = 'Traumatisme crânien', torso = 'Contusion thoracique', abdomen = 'Lésion abdominale' },

    -- ------------------------------------------------------------------
    -- Contrôle d'hémorragie : durée de compression selon la gravité (secondes) [réglable]
    -- dressingFrom : à partir de cette gravité, le pansement compressif est une étape à part, obligatoire
    -- assistBonus  : un 2e EMS « aide à la compression » élargit la zone de pression stable (critique)
    -- ------------------------------------------------------------------
    hemostasis = { seconds = { [1] = 12, [2] = 24, [3] = 34 }, dressingFrom = 2, assistBonus = 0.06 },

    -- ------------------------------------------------------------------
    -- Réanimation : chance de reprise par séquence RÉUSSIE (jamais garantie) [réglable]
    -- Une séquence ratée ne fait rien de plus (aucune mort automatique).
    -- ------------------------------------------------------------------
    cpr = {
        compressions = 30, bpm = 110,   -- compressions par séquence et cadence demandée
        passScore = 0.6,                -- part de compressions dans le rythme pour valider la séquence
        base = 0.15, perScore = 0.30,   -- chance = base + score × perScore + bonus…
        perSequence = 0.05, maxSequenceBonus = 0.20,   -- chaque séquence réussie précédente ajoute un peu
        stabilized = 0.15,              -- patient stabilisé
        defibrillator = 0.20, defibItem = 'defibrillator',   -- l'EMS a un défibrillateur (non consommé)
        bleeding = 0.30,                -- hémorragie importante / critique non contrôlée : chance réduite
        min = 0.03, max = 0.85,
        extendSeconds = 60,             -- séquence réussie sans reprise : délai avant perte du patient prolongé (perfusion maintenue)
        health = 130,                   -- santé à la reprise (sur 200)
    },

    -- ------------------------------------------------------------------
    -- Attelle / plâtre : matériel et blessure traitée [réglable : objets]
    -- treats : gravités de fracture que ce matériel prend en charge (1 immobilisation, 2 fracture)
    -- ------------------------------------------------------------------
    cast = {
        materials = {
            { id = 'attelle', label = 'Attelle', item = 'splint', treats = { 1 } },
            { id = 'platre',  label = 'Plâtre',  item = 'platre', treats = { 1, 2 } },
        },
        requireXray = true,             -- non réglable en jeu : la blessure doit avoir été radiographiée avant
    },

    -- Prise de sang : analyses proposées (tube attendu). Seule l'analyse « alcool et substances » a un résultat
    -- (laboratoire existant) : on n'invente aucun autre résultat.
    blood = {
        tubes = {
            { id = 'gris',   label = 'Tube gris (fluorure)', color = '#9ca3af' },
            { id = 'violet', label = 'Tube violet (EDTA)',   color = '#a855f7' },
            { id = 'rouge',  label = 'Tube rouge (sec)',     color = '#ef4444' },
        },
        analyses = {
            { id = 'tox', label = 'Alcool et substances', tube = 'gris' },
        },
    },

    -- Échographie : types proposés
    echo = {
        types = {
            { id = 'pregnancy', label = 'Suivi de grossesse', sensitive = true },
            { id = 'abdomen',   label = 'Échographie abdominale', regions = { 'abdomen' } },
            { id = 'thorax',    label = 'Échographie thoracique', regions = { 'torso' } },
        },
    },
    -- Scanner : types proposés
    scan = {
        types = {
            { id = 'head',    label = 'Scanner cérébral',   regions = { 'head' } },
            { id = 'torso',   label = 'Scanner thoracique', regions = { 'torso' } },
            { id = 'abdomen', label = 'Scanner abdominal',  regions = { 'abdomen' } },
            { id = 'body',    label = 'Scanner corps entier', regions = { 'head', 'torso', 'abdomen', 'arm', 'leg' } },
        },
    },

    -- ------------------------------------------------------------------
    -- Vaccins [réglable : activation, durées, délai, rappel]
    --   protects       : maladies (Config.Health.conditions) qu'il empêche d'attraper
    --   delayHours     : délai avant d'être protégé ; protectionDays : durée de protection (0 = à vie)
    --   boosterDays    : délai minimum avant un nouveau vaccin identique
    --   contraindications.active : maladies en cours qui interdisent le vaccin
    -- ------------------------------------------------------------------
    vaccines = {
        { id = 'grippe', label = 'Vaccin anti-grippal / rhume', item = 'vaccin_grippe', enabled = true, zone = 'deltoide',
          protects = { 'cold' }, delayHours = 1, protectionDays = 30, boosterDays = 25, contraindications = { active = { 'cold' } } },
        { id = 'tetanos', label = 'Vaccin antitétanique', item = 'vaccin_tetanos', enabled = true, zone = 'deltoide',
          protects = {}, delayHours = 0, protectionDays = 0, boosterDays = 180, contraindications = { active = {} } },
        -- Prévention MST : fictive, à activer si la règle du serveur le prévoit
        { id = 'mst', label = 'Prévention MST (protocole RP)', item = 'vaccin_mst', enabled = false, zone = 'deltoide',
          protects = { 'chlamydia', 'gonorrhea', 'syphilis' }, delayHours = 2, protectionDays = 30, boosterDays = 25,
          contraindications = { active = { 'chlamydia', 'gonorrhea', 'syphilis', 'herpes' } } },
    },
    injectionZones = {
        { id = 'deltoide', label = 'Deltoïde (épaule)' },
        { id = 'cuisse',   label = 'Face externe de la cuisse' },
        { id = 'fesse',    label = 'Quadrant supérieur externe de la fesse' },
    },

    -- ------------------------------------------------------------------
    -- Comptes rendus types [réglable : textes]. {zone}, {level}, {type}, {day}, {days}, {babies} sont remplacés.
    -- ------------------------------------------------------------------
    reports = {
        xray_none     = 'Radiographie {zone} : aucune fracture identifiée.',
        xray_immob    = 'Radiographie {zone} : lésion nécessitant une immobilisation (attelle).',
        xray_fracture = 'Radiographie {zone} : fracture nécessitant une prise en charge par plâtre.',
        xray_full_none  = 'Radiographie intégrale : aucune anomalie décelée (tête, thorax, abdomen, membres).',
        xray_full_found = 'Radiographie intégrale : {count} anomalie(s). {list} Zones sans anomalie : {normal}.',
        imaging_none  = '{type} : aucune lésion enregistrée dans la zone examinée.',
        imaging_found = '{type} : {level} ({zone}).',
        echo_preg_no  = 'Échographie : pas de grossesse visible.',
        echo_preg_yes = 'Échographie : grossesse évolutive, jour {day} sur {days}, {babies}.',
        cast_done     = '{material} posé(e) : {zone}.',
        hemo_done     = 'Hémorragie contrôlée par compression : {zone} ({level}).',
        dressing_done = 'Pansement compressif posé : {zone}.',
    },
}

-- ---------------------------------------------------------------------
-- Animations (client). ems = secouriste, patient = patient conscient (le patient inconscient
-- reste allongé ; pour le massage, il est mis sur le dos). flag 1 = boucle, 49 = haut du corps.
-- Rien n'est téléporté : le personnage joue l'animation là où il est, puis tout est arrêté et libéré.
-- ---------------------------------------------------------------------
Config.ProcedureAnims = {
    blood          = { ems = { 'mini@repair', 'fixing_a_ped', 1 },                          patient = { 'amb@world_human_picnic@male@base', 'base', 1 } },
    xray           = { ems = { 'amb@medic@standing@kneel@base', 'base', 1 },                patient = { 'amb@world_human_sunbathe@male@back@base', 'base', 1 } },
    cast           = { ems = { 'amb@medic@standing@kneel@idle_a', 'idle_a', 1 },            patient = { 'amb@world_human_picnic@male@base', 'base', 1 } },
    hemostasis     = { ems = { 'amb@medic@standing@tendtodead@idle_a', 'idle_a', 1 },       patient = { 'amb@world_human_sunbathe@male@back@base', 'base', 1 } },
    dressing       = { ems = { 'amb@medic@standing@kneel@idle_a', 'idle_a', 1 },            patient = { 'amb@world_human_sunbathe@male@back@base', 'base', 1 } },
    cpr            = { ems = { 'mini@cpr@char_a@cpr_str', 'cpr_pumpchest', 1 },             patient = { 'mini@cpr@char_b@cpr_str', 'cpr_pumpchest', 1 } },
    echo           = { ems = { 'amb@medic@standing@kneel@idle_a', 'idle_a', 1 },            patient = { 'amb@world_human_sunbathe@male@back@base', 'base', 1 } },
    scan           = { ems = { 'amb@world_human_clipboard@male@idle_a', 'idle_c', 49 },     patient = { 'amb@world_human_sunbathe@male@back@base', 'base', 1 } },
    vaccine        = { ems = { 'mini@repair', 'fixing_a_ped', 1 },                          patient = { 'amb@world_human_stand_impatient@male@no_sign@base', 'base', 1 } },
    implant        = { ems = { 'mini@repair', 'fixing_a_ped', 1 },                          patient = { 'amb@world_human_picnic@male@base', 'base', 1 } },
    implant_remove = { ems = { 'mini@repair', 'fixing_a_ped', 1 },                          patient = { 'amb@world_human_picnic@male@base', 'base', 1 } },
    assist         = { ems = { 'amb@medic@standing@tendtodead@idle_a', 'idle_a', 1 } },
    -- patient inconscient pendant un acte : allongé sur le dos (au lieu de la position du coma)
    downBack       = { 'mini@cpr@char_b@cpr_def', 'cpr_pumpchest_idle', 1 },
}
