-- =====================================================================
--  ELYZEA EMS / SAMS - configuration
--  Tout ce qui est réglable en jeu (grades, permissions, taux horaires, tarifs
--  des soins, prix des PPA, garage) se gère dans la tablette › Direction.
--  Les valeurs ci-dessous ne servent qu'au premier démarrage ou comme limites.
-- =====================================================================
Config = {}

-- Métier et compte de société d'elyzea_core (même nom que celui utilisé par elyzea_papiers)
Config.Job = { name = 'ambulance', label = 'SAMS', type = 'ems' }
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
                'records_view', 'records_write', 'reports_write', 'map', 'billing', 'ppa_civil' } },
    { name = 'Médecin',       level = 4, salary = 900,
      perms = { 'duty', 'medical', 'heal', 'stabilize', 'revive', 'escort', 'vehicle', 'calls', 'calls_manage', 'support', 'support_close', 'tablet',
                'records_view', 'records_write', 'reports_write', 'reports_manage', 'map', 'billing', 'ppa_civil', 'ppa_fdo', 'stats_view' } },
    { name = 'Chef de service', level = 5, salary = 1100,
      perms = { 'duty', 'medical', 'heal', 'stabilize', 'revive', 'escort', 'vehicle', 'calls', 'calls_manage', 'support', 'support_close', 'tablet',
                'records_view', 'records_write', 'reports_write', 'reports_manage', 'map', 'billing', 'ppa_civil', 'ppa_fdo', 'stats_view',
                'direction', 'recruit', 'employees_view', 'promote', 'demote', 'history_view' } },
    { name = 'Directeur',     level = 6, salary = 1400, perms = 'all' },
}
