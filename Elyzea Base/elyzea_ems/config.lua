-- =====================================================================
--  ELYZEA EMS / SAMS - configuration
--  Tout ce qui est réglable en jeu (grades, permissions, taux horaires, tarifs
--  des soins, prix des PPA, garage) se gère dans la tablette › Direction.
--  Les valeurs ci-dessous ne servent qu'au premier démarrage ou comme limites.
-- =====================================================================
Config = {}

-- Métier et compte de société d'elyzea_core (même nom que celui utilisé par elyzea_papiers)
Config.Job = { name = 'ambulance', label = 'SAMS', type = 'ems' }
-- Agences (elyzea_agences) : plusieurs agences de ce métier, chacune son métier elyzea_core,
-- ses grades, son compte, son téléphone et sa zone d'alerte. Config.Job ci-dessus = première agence.
Config.AgencyKind = 'ems'
Config.Society = 'ambulance'

Config.Keys = {
    menu = 'F6',                  -- menu rapide EMS
    acceptAlert = 'G', declineAlert = 'I',
}

Config.Distances = {
    interact = 3.0,               -- soins, réanimation, facture, PPA
    vehicle  = 6.0,               -- véhicule pour y installer / en sortir un patient
}

Config.Matricule = { prefix = 'SAMS-', digits = 3 }
Config.Recruit = { distance = 5.0, timeout = 30, cooldown = 8 }

-- ---------------------------------------------------------------------
-- Coma (tous les joueurs) : à terre au lieu de mort
-- ---------------------------------------------------------------------
Config.Death = {
    enabled = true,
    bleedout = 600,               -- secondes à terre avant de pouvoir réapparaître (si personne ne réanime)
    respawnHold = 3,              -- secondes à maintenir E pour réapparaître à l'hôpital
    stabilizeBonus = 300,         -- secondes ajoutées au délai quand un EMS stabilise
    autoCall = true,              -- appel EMS automatique à la mise à terre
    respawnFee = 500,             -- frais d'hôpital à la réapparition (banque puis liquide, 0 = gratuit)
    -- Lieu de réveil si aucun lit n'est réglé dans le menu admin (Réapparition)
    hospital = { x = 298.7, y = -584.6, z = 43.26, h = 70.0 },
}

-- Santé rendue
Config.Revive = { health = 150, duration = 10000 }   -- réanimation (sur 200) et durée du massage cardiaque (ms)
Config.Heal = { duration = 6000 }
Config.Stabilize = { duration = 5000 }

-- Matériel médical (objets d'elyzea_inventory, déjà déclarés dans shared/items.lua).
-- enabled = false : aucun objet demandé. consume = true : 1 objet retiré à la fin de l'acte.
Config.Equipment = {
    enabled = false,
    heal      = { item = 'bandage', consume = true },
    stabilize = { item = 'gauze', consume = true },
    revive    = { item = 'defibrillator', consume = false },
}

-- ---------------------------------------------------------------------
-- Alertes de soutien entre EMS (F6 › Soutien)
-- ---------------------------------------------------------------------
Config.Support = {
    cooldown = 15,
    levels = {
        low    = { label = 'Faible',  color = '#22c55e', blipColor = 2,  text = 'Soutien non urgent demandé' },
        medium = { label = 'Moyen',   color = '#f59e0b', blipColor = 47, text = 'Soutien nécessaire rapidement' },
        high   = { label = 'Urgent',  color = '#ef4444', blipColor = 1,  text = 'Soutien immédiat nécessaire' },
    },
}

-- ---------------------------------------------------------------------
-- Appels d'urgence (dispatch médical)
-- ---------------------------------------------------------------------
Config.Calls = {
    command = 'ems',              -- /ems <message> : appeler les secours (tout le monde)
    commandCooldown = 60,
    lifetime = 1800,              -- secondes avant qu'un appel non pris disparaisse (il reste dans l'historique)
    urgencies = {
        { id = 1, label = 'Faible',   color = '#22c55e' },
        { id = 2, label = 'Moyenne',  color = '#f59e0b' },
        { id = 3, label = 'Vitale',   color = '#ef4444' },
    },
    statuses = {
        pending   = 'En attente',
        accepted  = 'Accepté',
        enroute   = 'En route',
        onsite    = 'Sur place',
        care      = 'Prise en charge',
        transport = 'Transport à l\'hôpital',
        done      = 'Terminé',
        cancelled = 'Annulé',
    },
}

-- Statuts opérationnels (F6, carte)
Config.Statuses = {
    { id = 'available', label = 'Disponible',     color = '#22c55e' },
    { id = 'enroute',   label = 'En route',       color = '#3b82f6' },
    { id = 'busy',      label = 'En intervention', color = '#f59e0b' },
    { id = 'pause',     label = 'Indisponible',   color = '#94a3b8' },
}

-- ---------------------------------------------------------------------
-- Facturation médicale (paiement toujours immédiat : banque puis liquide)
-- Valeurs de départ : la direction les modifie dans Finance › Facturation.
-- ---------------------------------------------------------------------
Config.Billing = {
    mode = 'service',             -- 'service' (par prestation), 'flat' (forfait), 'mixed' (forfait + prestations)
    flat = 1000,                  -- forfait d'intervention
    maxPrice = 100000,            -- limite d'un tarif
    services = {
        { id = 'consult',   label = 'Consultation / examen', price = 200,  enabled = true },
        { id = 'heal',      label = 'Soins',                 price = 500,  enabled = true },
        { id = 'stabilize', label = 'Stabilisation',         price = 400,  enabled = true },
        { id = 'revive',    label = 'Réanimation',           price = 1500, enabled = true },
        { id = 'transport', label = 'Transport en ambulance', price = 800, enabled = true },
        { id = 'splint',    label = 'Pose d\'une attelle',    price = 600,  enabled = true },
        { id = 'treat',     label = 'Traitement (rhume, MST…)', price = 300, enabled = true },
        -- Actes médicaux en mini-jeux (config_procedures.lua)
        { id = 'blood',      label = 'Prise de sang',          price = 300, enabled = true },
        { id = 'xray',       label = 'Radiographie',           price = 400, enabled = true },
        { id = 'hemostasis', label = 'Contrôle d\'hémorragie', price = 400, enabled = true },
        { id = 'echo',       label = 'Échographie',            price = 500, enabled = true },
        { id = 'scan',       label = 'Scanner',                price = 800, enabled = true },
        { id = 'vaccine',    label = 'Vaccination',            price = 150, enabled = true },
        { id = 'implant',    label = 'Implant contraceptif (pose / retrait)', price = 400, enabled = true },
    },
}

-- ---------------------------------------------------------------------
-- PPA délivrés par les EMS (deux catégories, jamais d'autres)
-- Prix et activation : réglés par la direction (Finance › Gestion des PPA).
-- Grades autorisés : permissions « ppa_civil » / « ppa_fdo » (Grades › Permissions).
-- ---------------------------------------------------------------------
Config.PPA = {
    requireDuty = true,           -- l'EMS doit être en service
    maxPrice = 100000,
    types = {
        civil = { label = 'PPA civil', price = 1500, enabled = true },
        fdo   = { label = 'PPA force de l\'ordre', price = 0, enabled = true },
    },
    -- Conditions RP (à adapter aux règles du serveur)
    conditions = {
        noDuplicate = true,       -- refuser si le bénéficiaire a déjà ce PPA sur lui
        fdoJobs = { 'police' },   -- métiers qui peuvent recevoir le PPA force de l'ordre (vide = tout le monde)
        requireIdCard = false,    -- le bénéficiaire doit avoir sa carte d'identité sur lui
        idCardItem = 'carte_identite',
    },
}

-- ---------------------------------------------------------------------
-- Garage et pharmacie : points placés en jeu par la direction (tablette › Direction › Garage)
-- ---------------------------------------------------------------------
Config.Garage = {
    vehicles = {                  -- modèles proposés (modifiables en jeu) ; minLevel = niveau de grade minimum
        { model = 'ambulance', label = 'Ambulance', minLevel = 1 },
    },
    storeRadius = 6.0,
    pharmacy = { slots = 50, weight = 200000 },   -- coffre de matériel médical (elyzea_inventory), en grammes
}

-- Paie : temps de service compté au taux du grade de chaque période (Finance › Salaires)
Config.Pay = { maxRate = 100000 }

Config.Reports = {
    outcomes = { 'Soigné sur place', 'Transporté à l\'hôpital', 'Réanimé', 'Refus de soins', 'Décédé', 'Autre' },
}

Config.MapRefresh = 3000
Config.MapImage = { file = 'img/map.jpg', minX = -5661.2, maxX = 6694.0, minY = -4058.5, maxY = 8429.3 }

-- Grades du premier démarrage (level : hiérarchie). salary = taux horaire de départ (réglé ensuite dans Finance)
Config.DefaultGrades = {
    { name = 'Stagiaire',     level = 1, salary = 400, default = true,
      perms = { 'duty', 'medical', 'heal', 'escort', 'vehicle', 'calls', 'support', 'tablet', 'records_view' } },
    { name = 'Ambulancier',   level = 2, salary = 550,
      perms = { 'duty', 'medical', 'heal', 'stabilize', 'revive', 'escort', 'vehicle', 'calls', 'support', 'support_close', 'tablet',
                'records_view', 'records_write', 'reports_write', 'map', 'billing' } },
    { name = 'Infirmier',     level = 3, salary = 700,
      perms = { 'duty', 'medical', 'heal', 'stabilize', 'revive', 'escort', 'vehicle', 'calls', 'calls_manage', 'support', 'support_close', 'tablet',
                'records_view', 'records_write', 'reports_write', 'map', 'billing', 'ppa_civil', 'lab_sample', 'lab_view', 'imaging', 'vaccinate' } },
    { name = 'Médecin',       level = 4, salary = 900,
      perms = { 'duty', 'medical', 'heal', 'stabilize', 'revive', 'escort', 'vehicle', 'calls', 'calls_manage', 'support', 'support_close', 'tablet',
                'records_view', 'records_write', 'reports_write', 'reports_manage', 'map', 'billing', 'ppa_civil', 'ppa_fdo', 'stats_view',
                'lab_sample', 'lab_analyze', 'lab_view', 'imaging', 'vaccinate', 'implant', 'records_sensitive' } },
    { name = 'Chef de service', level = 5, salary = 1100,
      perms = { 'duty', 'medical', 'heal', 'stabilize', 'revive', 'escort', 'vehicle', 'calls', 'calls_manage', 'support', 'support_close', 'tablet',
                'records_view', 'records_write', 'reports_write', 'reports_manage', 'map', 'billing', 'ppa_civil', 'ppa_fdo', 'stats_view',
                'lab_sample', 'lab_analyze', 'lab_view', 'imaging', 'vaccinate', 'implant', 'records_sensitive', 'direction', 'recruit', 'employees_view', 'promote', 'demote', 'history_view' } },
    { name = 'Directeur',     level = 6, salary = 1400, perms = 'all' },
}

-- ---------------------------------------------------------------------
-- LABORATOIRE : analyse sanguine « Alcool et substances »
-- Résultats SIMULÉS pour le jeu de rôle (pas des mesures médicales réelles).
-- Ils viennent uniquement des consommations enregistrées par le serveur :
--   · objets consommés dans l'inventaire (événement elyzea_inventory:usedItem), liste « items » ci-dessous ;
--   · autres scripts (serveur) : exports.elyzea_ems:RecordConsumption(source, 'cocaine' [, quantité])
--     (elyzea_drogues enregistre ainsi chaque prise de drogue)
-- Rien n'est tiré au hasard. Sans données suffisantes, le résultat est « indéterminé ».
-- ---------------------------------------------------------------------
Config.Lab = {
    sampleDistance = 3.0,           -- distance max patient / EMS pour le prélèvement
    sampleTime = 6000,              -- durée du prélèvement (ms)
    sampleCooldown = 60,            -- secondes entre deux prélèvements du même patient
    keepConsumptionsDays = 14,      -- consommations gardées en base (au-delà : effacées)
    keepSamplesDays = 180,          -- prélèvements et rapports gardés

    alcohol = {
        -- grammes d'alcool pur par objet consommé (1 verre standard ≈ 10 g)
        items = {
            nc_shot = 10, nc_coupe = 12, nc_whiskycoca = 14, nc_vodkaenergy = 14,
            beer = 13, wine = 16, vodka = 30, whiskey = 30,
        },
        bodyWeight = 70,            -- poids simulé (kg) et coefficient de diffusion (formule de Widmark)
        diffusion = 0.65,
        eliminationPerHour = 0.15,  -- g/L éliminés par heure
        detectionHours = 12,        -- au-delà, un verre ne compte plus du tout
        recentHours = 2,            -- dernier verre il y a moins de X h : « consommation récente »
        -- niveaux (g/L) : 0 = nul, sous « moderate » = faible, sous « high » = modéré, au-dessus = élevé
        thresholds = { moderate = 0.5, high = 1.0 },
    },

    -- Dépistage des substances. detectionHours : durée pendant laquelle une prise reste détectable.
    -- items : objets d'inventaire qui comptent comme une prise (vide = seulement RecordConsumption).
    -- Ajouter une substance : copier une ligne avec un nouvel id (lettres, chiffres, _).
    substances = {
        { id = 'thc',          label = 'Cannabis (THC)',          detectionHours = 72, recentHours = 6,  items = { 'joint', 'weed_pouch' } },
        { id = 'cocaine',      label = 'Cocaïne',                 detectionHours = 48, recentHours = 4,  items = { 'cocaine', 'cokebaggy', 'crack_baggy' } },
        { id = 'mdma',         label = 'MDMA / ecstasy',          detectionHours = 48, recentHours = 4,  items = { 'xtcbaggy' } },
        { id = 'amphetamines', label = 'Amphétamines',            detectionHours = 48, recentHours = 4,  items = { 'meth' } },
        { id = 'opiates',      label = 'Opiacés',                 detectionHours = 48, recentHours = 4,  items = { 'oxy' } },
        { id = 'ketamine',     label = 'Kétamine',                detectionHours = 24, recentHours = 3,  items = { 'ketamine' } },
        { id = 'psilocybin',   label = 'Psilocybine (champignons)', detectionHours = 24, recentHours = 4, items = { 'magic_mushroom', 'dried_mushroom' } },
        -- Exemple de substance personnalisée :
        -- { id = 'lsd', label = 'LSD', detectionHours = 24, recentHours = 4, items = { 'lsd_tab' } },
    },
}

-- ---------------------------------------------------------------------
-- POSTES DES DOSSIERS MÉDICAUX
-- Les dossiers ne sont plus dans la tablette : on les consulte à un poste
-- (ex. PC de l'accueil), placé par la direction (tablette › Direction › Garage)
-- ou par le staff (admin_menu › Santé). E au poste : recherche par nom / prénom.
-- ---------------------------------------------------------------------
-- ---------------------------------------------------------------------
-- Brancard (objet suivi par le serveur)
--  · ALT sur le patient › « Allonger sur le brancard » : sort un brancard (ou prend celui qui est à côté)
--  · ALT sur le brancard : prendre / lâcher, retirer le patient, charger dans un véhicule, ranger
--  · ALT sur le véhicule : charger / sortir le brancard (le patient reste dessus)
--  Le brancard roule au sol devant l'EMS, qui se tient à son bout. Longueur et hauteur lues sur le modèle.
--  Positions à ajuster en jeu avec /brancard_reglage (voir README). enabled = false : ancien mode (bras / épaule).
-- ---------------------------------------------------------------------
Config.Stretcher = {
    enabled = true,
    models = { 'v_med_emptybed' },              -- 1er modèle disponible utilisé (lit roulant de l'hôpital, jeu de base)
    perEms = 1,                                 -- brancards sortis en même temps par EMS
    reach = 3.0,                                -- distance EMS ↔ brancard pour agir (m)
    stretcher = {
        gap = 0.25,          -- distance entre l'EMS et le bout du brancard (m)
        height = 0.0,        -- décalage vertical si le brancard s'enfonce / flotte (m)
        heading = 0.0,       -- rotation en plus (180 = l'autre bout vers l'EMS)
        turnSmooth = 0.12,   -- 0.05 = tourne lentement derrière l'EMS, 1 = suit instantanément
    },
    -- patient par rapport au brancard : allongé dans la longueur, sur le matelas
    patient = { pos = { 0.0, 0.0, 1.05 }, rot = { 0.0, 0.0, 180.0 } },
    -- dans un véhicule : le brancard est posé à l'arrière, dans l'axe (calculé sur le véhicule)
    vehicle = {
        reach = 6.0,         -- distance EMS ↔ véhicule pour charger / sortir (m)
        floor = 0.55,        -- hauteur du plancher au-dessus du bas du véhicule (m)
        inset = 0.30,        -- distance entre l'arrière du véhicule et le bout du brancard (m)
        heading = 0.0,       -- rotation en plus dans le véhicule
        side = 0.0,          -- décalage gauche / droite (m)
    },
    emsAnim = { 'anim@heists@box_carry@', 'idle', 49 },              -- l'EMS tient le bout du brancard
    patientAnim = { 'anim@gangops@morgue@table@', 'body_search', 1 }, -- allongé à plat sur le dos
    noSprint = true,                            -- pas de course en tirant le brancard
}

-- ---------------------------------------------------------------------
-- MedicalBag (sac médical EMS)
--  · Donné à la prise de service (1 par EMS), retiré de l'inventaire à la fin du service
--    (et à la connexion si la personne n'est pas en service).
--  · Utiliser l'objet : le sac est posé au sol devant soi.
--  · ALT sur le sac : « Ouvrir le sac » (tous les objets EMS ci-dessous, à prendre gratuitement,
--    ils vont dans l'inventaire) ou « Ramasser le sac » (il revient dans l'inventaire).
--  · Réservé aux EMS en service. Fin de service / déconnexion : le sac posé disparaît aussi.
-- ---------------------------------------------------------------------
Config.MedicalBag = {
    enabled = true,
    item = 'medicbag',                                   -- objet de l'inventaire (image medicbag.png)
    models = { 'xm_prop_x17_bag_med_01a', 'prop_ld_health_pack' },
    reach = 2.5,                                         -- distance pour ouvrir / ramasser (m)
    perEms = 1,                                          -- sacs posés en même temps par EMS
    -- contenu du sac (illimité) : objets utilisés par l'EMS (soins, actes, vaccins…)
    items = {
        'bandage', 'gauze', 'splint', 'platre', 'defibrillator', 'kit_prelevement',
        'vaccin_grippe', 'vaccin_tetanos', 'vaccin_mst', 'implant_contraceptif',
        'painkiller', 'morphine', 'blood_bag',
    },
}

-- ---------------------------------------------------------------------
-- Fauteuil roulant : objet « wheelchair » de l'inventaire (utiliser = s'asseoir, X ou réutiliser = se lever)
-- ZQSD / WASD : avancer, reculer, tourner. Le fauteuil n'est pas consommé.
-- ---------------------------------------------------------------------
Config.Wheelchair = {
    enabled = true,
    item = 'wheelchair',
    models = { 'prop_wheelchair_01' },
    seat = { pos = { 0.0, 0.05, 0.42 }, rot = { 0.0, 0.0, 180.0 } },    -- personne par rapport au fauteuil
    anim = { 'missfinale_c2leadinoutfin_c_int', '_leadin_loop2_lester', 1 }, -- assis (fauteuil de Lester)
    speed = 1.6,            -- m/s en avançant
    reverse = 0.8,          -- m/s en reculant
    turn = 90.0,            -- degrés par seconde
    heading = 180.0,        -- rotation du fauteuil (avec seat.rot = 180 : la personne regarde vers l avant)
}

Config.Records = {
    radius = 1.5,        -- distance pour appuyer sur E
    useRadius = 3.0,     -- distance contrôlée par le serveur pour lire ou modifier un dossier
    marker = true,       -- petit marqueur au sol (visible des EMS)
    maxPoints = 30,
    minSearch = 2,       -- lettres minimum pour une recherche
}

-- ---------------------------------------------------------------------
-- RENDEZ-VOUS (application Santé d'Elyzea Aura ↔ application « Rendez-vous » du téléphone de service EMS)
-- Réglages modifiables en jeu : admin_menu › Santé.
-- ---------------------------------------------------------------------
Config.Appointments = {
    enabled = true,
    expireMinutes = 120,    -- demande non acceptée au bout de ce délai : annulée, le joueur est prévenu
    acceptedHours = 24,     -- rendez-vous accepté : classé « terminé » au bout de ce délai
    maxOpen = 2,            -- demandes en cours au maximum par personne
    cooldown = 60,          -- secondes entre deux demandes
    keepDays = 30,          -- historique gardé
    types = {
        { id = 'medical',   label = 'Consultation médicale',      icon = '🩺' },
        { id = 'psy',       label = 'Consultation psychiatrique', icon = '🧠' },
        { id = 'blood',     label = 'Prise de sang',              icon = '🩸' },
        { id = 'pregnancy', label = 'Suivi de grossesse',         icon = '🤰' },
    },
}

-- ---------------------------------------------------------------------
-- MALADIES ET BLESSURES
-- Valeurs de départ : tout se règle ensuite dans admin_menu › Santé (enregistré en base).
--   cure = 'treat'  : un EMS soigne avec « Traitement »
--   cure = 'splint' : un EMS pose une attelle
--   duration : minutes avant guérison toute seule (0 = jamais, il faut un EMS)
--   known : la personne le sait tout de suite (sinon il faut un examen EMS)
-- ---------------------------------------------------------------------
Config.Health = {
    enabled = true,
    tick = 60,                      -- secondes entre deux vérifications (contagion, guérison)
    fall = { enabled = true, minHeight = 6.0 },   -- chute d'au moins X m (à pied) : blessure à la jambe
    splint = { duration = 8000, healMinutes = 0 },   -- attelle : 0 = guéri tout de suite ; sinon plus de boiterie mais pas de course pendant X min
    treat = { duration = 6000 },
    conditions = {
        cold = { label = 'Rhume', type = 'illness', cure = 'treat', known = true, enabled = true,
            durationMin = 45, durationMax = 90,         -- disparaît tout seul entre 45 et 90 min
            randomPerHour = 2,                          -- % de chance par heure de jeu d'attraper un rhume
            contagionRadius = 2.0, contagionChance = 4, -- % par minute passée près d'un malade
            symptomEvery = 90 },                        -- secondes entre deux quintes de toux / éternuements
        leg = { label = 'Blessure à la jambe', type = 'injury', cure = 'splint', known = true, enabled = true,
            durationMin = 0, durationMax = 0 },         -- boite jusqu'à la pose d'une attelle
        chlamydia = { label = 'Chlamydia', type = 'std', cure = 'treat', known = false, enabled = true,
            durationMin = 0, durationMax = 0, transmission = 35, symptomEvery = 900,
            symptoms = { 'Vous ressentez une brûlure en urinant.', 'Vous avez des douleurs au bas-ventre.' } },
        gonorrhea = { label = 'Gonorrhée', type = 'std', cure = 'treat', known = false, enabled = true,
            durationMin = 0, durationMax = 0, transmission = 30, symptomEvery = 900,
            symptoms = { 'Vous ressentez une forte brûlure en urinant.', 'Vous vous sentez fiévreux.' } },
        herpes = { label = 'Herpès génital', type = 'std', cure = 'treat', known = false, enabled = true,
            durationMin = 0, durationMax = 0, transmission = 20, symptomEvery = 1200,
            symptoms = { 'Vous avez des démangeaisons très gênantes.', 'De petites lésions douloureuses apparaissent.' } },
        syphilis = { label = 'Syphilis', type = 'std', cure = 'treat', known = false, enabled = true,
            durationMin = 0, durationMax = 0, transmission = 15, symptomEvery = 1500,
            symptoms = { 'Vous remarquez une petite plaie indolore.', 'Vous êtes fatigué et avez mal à la tête.' } },
    },
}
