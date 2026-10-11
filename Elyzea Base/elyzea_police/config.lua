-- =====================================================================
--  ELYZEA POLICE - configuration
--  Les grades et leurs permissions se gèrent ensuite en jeu : tablette › Direction.
--  Les grades ci-dessous ne servent qu'au tout premier démarrage (table vide).
-- =====================================================================
Config = {}

Config.Job = { name = 'police', label = 'LSPD', type = 'leo' }

Config.Keys = {
    menu = 'F6',      -- menu rapide (service, alerte agent, tablette)
    alt  = 'LMENU',   -- ALT maintenu : curseur, clic sur une personne / un véhicule
    acceptAlert = 'G', declineAlert = 'I',
}

Config.Distances = {
    interact = 3.0,   -- menotter, escorter, amende
    vehicle  = 6.0,   -- véhicule pour y placer / en sortir quelqu'un
    alt      = 4.0,   -- portée du curseur ALT sur une personne
}

-- Matricule donné au recrutement (numéro suivant le plus grand déjà donné)
Config.Matricule = { prefix = 'LSPD-', digits = 3 }

-- Recrutement : joueur le plus proche, demande à accepter
Config.Recruit = { distance = 5.0, timeout = 30, cooldown = 8 }

-- ---------------------------------------------------------------------
-- Amendes : prélevées sur la banque, puis le liquide ; sinon l'amende reste due (/amendes)
-- ---------------------------------------------------------------------
Config.Fines = {
    maxAmount = 100000,
    toSociety = true,          -- l'argent va sur le compte de la société « police »
    offenses = {
        { id = 'speed',     label = 'Excès de vitesse',            amount = 250 },
        { id = 'redlight',  label = 'Feu rouge grillé',            amount = 150 },
        { id = 'reckless',  label = 'Conduite dangereuse',         amount = 750 },
        { id = 'nolicense', label = 'Conduite sans permis',        amount = 1000 },
        { id = 'parking',   label = 'Stationnement gênant',        amount = 100 },
        { id = 'insult',    label = 'Outrage à agent',             amount = 500 },
        { id = 'refusal',   label = 'Refus d\'obtempérer',         amount = 1500 },
        { id = 'assault',   label = 'Agression',                   amount = 1500 },
        { id = 'theft',     label = 'Vol',                         amount = 1000 },
        { id = 'carjack',   label = 'Vol de véhicule',             amount = 2500 },
        { id = 'weapon',    label = 'Port d\'arme illégal',        amount = 3000 },
        { id = 'drugs',     label = 'Possession de stupéfiants',   amount = 2000 },
        { id = 'other',     label = 'Autre infraction',            amount = 0 },
    },
}

-- ---------------------------------------------------------------------
-- Alertes agent (F6 › Alerte agent) : GPS automatique chez tous les agents en service
-- ---------------------------------------------------------------------
Config.AgentAlerts = {
    cooldown = 15,              -- secondes entre deux alertes d'un même agent
    levels = {
        low    = { label = 'Faible',  color = '#22c55e', blipColor = 2,  text = 'Renfort ou assistance non urgente demandé' },
        medium = { label = 'Moyenne', color = '#f59e0b', blipColor = 47, text = 'Renfort nécessaire rapidement' },
        high   = { label = 'Urgente', color = '#ef4444', blipColor = 1,  text = 'Intervention immédiate nécessaire' },
    },
    -- Si l'auteur quitte le serveur : 'close' (clôture immédiate) ou 'keep' (reste active, clôturée après keepMinutes)
    onAuthorLeave = 'keep',
    keepMinutes = 10,
    maxMinutes = 120,           -- clôture automatique d'une alerte oubliée
}

-- ---------------------------------------------------------------------
-- Alertes générales (valider / décliner)
-- ---------------------------------------------------------------------
Config.Alerts = {
    lifetime = 600,             -- secondes avant qu'une alerte non prise en charge disparaisse
    mergeRadius = 60.0,         -- même type, même endroit, moins d'une minute : on regroupe
    types = {
        shots    = { label = 'Coups de feu',         sprite = 110, color = 1,  auto = true,  chance = 70, cooldown = 30 },
        assault  = { label = 'Agression',            sprite = 280, color = 1,  auto = false },
        carjack  = { label = 'Vol de véhicule',      sprite = 229, color = 17, auto = true,  chance = 60, cooldown = 60 },
        robbery  = { label = 'Braquage',             sprite = 156, color = 1,  auto = false },
        distress = { label = 'Appel de détresse',    sprite = 280, color = 3,  auto = false },
        other    = { label = 'Signalement',          sprite = 280, color = 5,  auto = false },
    },
    -- Commande pour appeler la police (tout le monde) : /police <message>
    callCommand = 'police',
    callCooldown = 60,
}

-- Statuts opérationnels (F6 › Statut, visibles sur la tablette et la carte)
Config.Statuses = {
    { id = 'available', label = 'Disponible',       color = '#22c55e' },
    { id = 'patrol',    label = 'En patrouille',    color = '#3b82f6' },
    { id = 'busy',      label = 'En intervention',  color = '#f59e0b' },
    { id = 'pause',     label = 'Indisponible',     color = '#94a3b8' },
}

-- Rapports
Config.Reports = {
    types = { 'Interpellation', 'Contrôle routier', 'Intervention', 'Plainte', 'Enquête', 'Incident', 'Autre' },
    maxAttachments = 6,
}

-- Carte de la tablette : positions envoyées toutes les N ms (seulement tablette ouverte sur la carte)
Config.MapRefresh = 3000
-- Fourrière (ALT police sur un véhicule vide) : durée à genoux avant l'enlèvement
Config.Impound = { duration = 8000 }

-- Carte satellite de la tablette (html/img/map.jpg) : coordonnées du jeu aux bords de l'image.
-- Calibrée pour l'image fournie ; supprime l'image pour revenir à la carte tactique dessinée.
Config.MapImage = { file = 'img/map.jpg', minX = -5661.2, maxX = 6694.0, minY = -4058.5, maxY = 8429.3 }

-- Grades du premier démarrage (level : hiérarchie, plus grand = plus haut)
-- salary : $ par heure de service, versés par la direction (tablette › Finance), modifiable en jeu
Config.DefaultGrades = {
    { name = 'Cadet',              level = 1, salary = 400,  default = true,
      perms = { 'duty', 'alt', 'cuff', 'escort', 'vehicle', 'alerts_receive', 'alert_agent', 'tablet', 'search', 'wanted_view', 'reports_view' } },
    { name = 'Gardien de la paix', level = 2, salary = 500,
      perms = { 'duty', 'alt', 'cuff', 'escort', 'vehicle', 'fine', 'impound', 'alerts_receive', 'alert_agent', 'tablet', 'search', 'wanted_view', 'reports_view', 'reports_write', 'map', 'agents_view' } },
    { name = 'Brigadier',          level = 3, salary = 600,
      perms = { 'duty', 'alt', 'cuff', 'escort', 'vehicle', 'fine', 'impound', 'alerts_receive', 'alert_agent', 'alert_close', 'tablet', 'search', 'wanted_view', 'wanted_manage', 'reports_view', 'reports_write', 'map', 'agents_view' } },
    { name = 'Brigadier-chef',     level = 4, salary = 700,
      perms = { 'duty', 'alt', 'cuff', 'escort', 'vehicle', 'fine', 'impound', 'alerts_receive', 'alert_agent', 'alert_close', 'tablet', 'search', 'wanted_view', 'wanted_manage', 'reports_view', 'reports_write', 'reports_manage', 'map', 'agents_view' } },
    { name = 'Lieutenant',         level = 5, salary = 850,
      perms = { 'duty', 'alt', 'cuff', 'escort', 'vehicle', 'fine', 'impound', 'alerts_receive', 'alert_agent', 'alert_close', 'tablet', 'search', 'wanted_view', 'wanted_manage', 'reports_view', 'reports_write', 'reports_manage', 'map', 'agents_view',
                'direction', 'recruit', 'employees_view', 'history_view' } },
    { name = 'Capitaine',          level = 6, salary = 1000,
      perms = { 'duty', 'alt', 'cuff', 'escort', 'vehicle', 'fine', 'impound', 'alerts_receive', 'alert_agent', 'alert_close', 'tablet', 'search', 'wanted_view', 'wanted_manage', 'reports_view', 'reports_write', 'reports_manage', 'map', 'agents_view',
                'direction', 'recruit', 'employees_view', 'history_view', 'promote', 'demote' } },
    { name = 'Commandant',         level = 7, salary = 1200,
      perms = { 'duty', 'alt', 'cuff', 'escort', 'vehicle', 'fine', 'impound', 'alerts_receive', 'alert_agent', 'alert_close', 'tablet', 'search', 'wanted_view', 'wanted_manage', 'reports_view', 'reports_write', 'reports_manage', 'map', 'agents_view',
                'direction', 'recruit', 'employees_view', 'history_view', 'promote', 'demote', 'fire', 'employees_edit', 'grades_manage', 'finance' } },
    { name = 'Commissaire',        level = 8, salary = 1500, perms = 'all' },
}
