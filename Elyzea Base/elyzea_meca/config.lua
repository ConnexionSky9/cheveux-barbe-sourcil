-- =====================================================================
--  ELYZEA MÉCANO - configuration
--  Les tarifs, le catalogue, les grades, les permissions et les taux horaires
--  se gèrent EN JEU dans la tablette › Direction (ils sont gardés en base).
--  Ici : les points d'atelier, les durées, les limites et les valeurs de départ.
-- =====================================================================
Config = {}

-- Métier et compte de société d'elyzea_core
Config.Job = { name = 'mechanic', label = 'Mécano', type = 'mechanic' }
Config.Society = 'mechanic'

Config.Keys = {
    menu = 'F6',
    acceptAlert = 'G', declineAlert = 'I',
    workshop = 38,                -- E (code de contrôle GTA) aux points d'atelier
}

Config.Distances = {
    vehicle = 4.0,                -- réparer / nettoyer / retourner : distance au véhicule
    quote = 6.0,                  -- envoyer un devis : distance du client
}

Config.Matricule = { prefix = 'MECA-', digits = 3 }
Config.Recruit = { distance = 5.0, timeout = 30, cooldown = 8 }

-- ---------------------------------------------------------------------
-- Réparations (ALT sur un véhicule) : durées en millisecondes
-- full = moteur + carrosserie + pneus + réservoir (permission « repair_full »)
-- ---------------------------------------------------------------------
Config.Repair = {
    engine = { label = 'Réparer le moteur',      duration = 12000 },
    body   = { label = 'Réparer la carrosserie', duration = 12000 },
    tyres  = { label = 'Réparer les pneus',      duration = 8000 },
    full   = { label = 'Réparation complète',    duration = 20000 },
    clean  = { label = 'Nettoyer le véhicule',   duration = 8000 },
    flip   = { label = 'Retourner le véhicule',  duration = 6000 },
    -- Pièces de stock consommées par chaque réparation (code de pièce = quantité). {} = aucune
    parts = { engine = { engine_parts = 1 }, body = { body_parts = 1 }, tyres = { tyre = 1 }, full = { engine_parts = 1, body_parts = 1, tyre = 1 } },
    -- Une réparation sans pièce en stock est-elle autorisée ? (false = refusée tant que le stock manque)
    allowWithoutStock = true,
}

-- ---------------------------------------------------------------------
-- Points d'atelier (touche E). Ajoutez, retirez, déplacez librement.
--  coords  : position où se place le mécanicien (à pied)
--  vehicle : centre de l'emplacement du véhicule ; radius : tolérance
--  categories : 'perf', 'cosmetic', 'paint', 'wheels', 'lights', 'interior', 'carplay', 'service'
--  minLevel : niveau de grade minimum ; label : nom affiché
--  Astuce : /meca_pos en jeu affiche votre position au format à copier ici.
-- ---------------------------------------------------------------------
Config.Workshops = {
    { id = 'lsc_perf', label = 'Banc performances', coords = vector3(-337.36, -136.86, 39.01), vehicle = vector3(-339.45, -132.0, 39.01), radius = 3.5,
      categories = { 'perf' }, minLevel = 2 },
    { id = 'lsc_body', label = 'Atelier carrosserie', coords = vector3(-323.8, -132.6, 39.01), vehicle = vector3(-325.6, -137.4, 39.01), radius = 3.5,
      categories = { 'cosmetic', 'paint', 'wheels', 'lights', 'interior' }, minLevel = 1 },
    { id = 'lsc_carplay', label = 'Installation CarPlay', coords = vector3(-347.3, -133.4, 39.01), vehicle = vector3(-345.6, -128.6, 39.01), radius = 3.5,
      categories = { 'carplay', 'service' }, minLevel = 1 },
}
Config.WorkshopMarker = true      -- marqueur au sol pour les mécaniciens en service

-- ---------------------------------------------------------------------
-- Devis et paiement
-- ---------------------------------------------------------------------
Config.Quotes = {
    acceptTimeout = 90,           -- secondes pour que le client accepte le devis
    installTimeout = 1800,        -- secondes après acceptation pour installer (sinon remboursement automatique)
    maxItems = 40,
    payWith = 'bank_then_cash',   -- prélevé à l'acceptation : banque, puis liquide
}

-- Catalogue de départ : copié en base au premier démarrage, ensuite modifiable dans la tablette.
-- kind : service | perf | cosmetic | carplay | custom
-- mod / level : modification GTA concernée et niveau (perf) ; category : rubrique de l'atelier
Config.DefaultCatalog = {
    -- Prestations
    { code = 'repair_engine', name = 'Réparation moteur',        category = 'service', kind = 'service', price = 600 },
    { code = 'repair_body',   name = 'Réparation carrosserie',   category = 'service', kind = 'service', price = 500 },
    { code = 'repair_tyres',  name = 'Réparation des pneus',     category = 'service', kind = 'service', price = 250 },
    { code = 'repair_full',   name = 'Réparation complète',      category = 'service', kind = 'service', price = 1200, minLevel = 2 },
    { code = 'clean',         name = 'Nettoyage',                category = 'service', kind = 'service', price = 150 },
    { code = 'flip',          name = 'Remise sur roues',         category = 'service', kind = 'service', price = 300 },
    { code = 'tow',           name = 'Remorquage / déplacement', category = 'service', kind = 'service', price = 400 },
    -- Performances (un article par niveau)
    { code = 'engine_1', name = 'Moteur niveau 1', category = 'perf', kind = 'perf', mod = 'engine', level = 1, price = 2500, part = 'engine_parts' },
    { code = 'engine_2', name = 'Moteur niveau 2', category = 'perf', kind = 'perf', mod = 'engine', level = 2, price = 4500, part = 'engine_parts' },
    { code = 'engine_3', name = 'Moteur niveau 3', category = 'perf', kind = 'perf', mod = 'engine', level = 3, price = 7500, part = 'engine_parts', minLevel = 2 },
    { code = 'engine_4', name = 'Moteur niveau 4', category = 'perf', kind = 'perf', mod = 'engine', level = 4, price = 11000, part = 'engine_parts', minLevel = 3 },
    { code = 'brakes_1', name = 'Freins niveau 1', category = 'perf', kind = 'perf', mod = 'brakes', level = 1, price = 1500 },
    { code = 'brakes_2', name = 'Freins niveau 2', category = 'perf', kind = 'perf', mod = 'brakes', level = 2, price = 2800 },
    { code = 'brakes_3', name = 'Freins niveau 3', category = 'perf', kind = 'perf', mod = 'brakes', level = 3, price = 4200 },
    { code = 'transmission_1', name = 'Transmission niveau 1', category = 'perf', kind = 'perf', mod = 'transmission', level = 1, price = 2000 },
    { code = 'transmission_2', name = 'Transmission niveau 2', category = 'perf', kind = 'perf', mod = 'transmission', level = 2, price = 3800 },
    { code = 'transmission_3', name = 'Transmission niveau 3', category = 'perf', kind = 'perf', mod = 'transmission', level = 3, price = 5600 },
    { code = 'suspension_1', name = 'Suspension niveau 1', category = 'perf', kind = 'perf', mod = 'suspension', level = 1, price = 1000 },
    { code = 'suspension_2', name = 'Suspension niveau 2', category = 'perf', kind = 'perf', mod = 'suspension', level = 2, price = 1800 },
    { code = 'suspension_3', name = 'Suspension niveau 3', category = 'perf', kind = 'perf', mod = 'suspension', level = 3, price = 2600 },
    { code = 'suspension_4', name = 'Suspension niveau 4', category = 'perf', kind = 'perf', mod = 'suspension', level = 4, price = 3400 },
    { code = 'armor_1', name = 'Blindage 20 %', category = 'perf', kind = 'perf', mod = 'armor', level = 1, price = 3000, enabled = false },
    { code = 'armor_2', name = 'Blindage 40 %', category = 'perf', kind = 'perf', mod = 'armor', level = 2, price = 5000, enabled = false },
    { code = 'turbo', name = 'Turbo', category = 'perf', kind = 'perf', mod = 'turbo', level = 1, price = 6000, part = 'turbo_kit' },
    -- Esthétique : un prix par pièce installée dans chaque rubrique
    { code = 'cosmetic_body',     name = 'Pièce de carrosserie',     category = 'cosmetic', kind = 'cosmetic', mod = 'body', price = 750 },
    { code = 'cosmetic_paint',    name = 'Peinture',                 category = 'paint',    kind = 'cosmetic', mod = 'paint', price = 900 },
    { code = 'cosmetic_pearl',    name = 'Nacrage',                  category = 'paint',    kind = 'cosmetic', mod = 'pearl', price = 600 },
    { code = 'cosmetic_livery',   name = 'Livrée',                   category = 'paint',    kind = 'cosmetic', mod = 'livery', price = 1200 },
    { code = 'cosmetic_tint',     name = 'Vitres teintées',          category = 'paint',    kind = 'cosmetic', mod = 'tint', price = 500 },
    { code = 'cosmetic_plate',    name = 'Style de plaque',          category = 'paint',    kind = 'cosmetic', mod = 'plate', price = 300 },
    { code = 'cosmetic_wheels',   name = 'Jantes',                   category = 'wheels',   kind = 'cosmetic', mod = 'wheels', price = 1500 },
    { code = 'cosmetic_wheelcolor', name = 'Couleur des jantes',     category = 'wheels',   kind = 'cosmetic', mod = 'wheelcolor', price = 400 },
    { code = 'cosmetic_smoke',    name = 'Fumée des pneus',          category = 'wheels',   kind = 'cosmetic', mod = 'smoke', price = 800 },
    { code = 'cosmetic_neon',     name = 'Néons',                    category = 'lights',   kind = 'cosmetic', mod = 'neon', price = 1500 },
    { code = 'cosmetic_xenon',    name = 'Phares xénon',             category = 'lights',   kind = 'cosmetic', mod = 'xenon', price = 900 },
    { code = 'cosmetic_interior', name = 'Pièce d\'intérieur',       category = 'interior', kind = 'cosmetic', mod = 'interior', price = 450 },
    -- CarPlay (téléphone elyzea_aura)
    { code = 'carplay', name = 'Installation CarPlay', category = 'carplay', kind = 'carplay', price = 3500, part = 'carplay_kit',
      description = 'Rend le véhicule compatible avec ElyzeaCarPlay (tablette F4 et contrôle depuis le téléphone). Liée au véhicule.' },
    { code = 'carplay_reinstall', name = 'Réinstallation CarPlay', category = 'carplay', kind = 'carplay', price = 1000, enabled = false,
      description = 'Remplacement sur un véhicule déjà équipé (désactivé par défaut).' },
}

-- Stock de pièces de l'entreprise (quantités en base, commandes payées par le compte société)
Config.DefaultParts = {
    { code = 'engine_parts', label = 'Pièces moteur',      cost = 250, min = 10 },
    { code = 'body_parts',   label = 'Pièces carrosserie', cost = 150, min = 10 },
    { code = 'tyre',         label = 'Pneu',               cost = 60,  min = 16 },
    { code = 'turbo_kit',    label = 'Kit turbo',          cost = 2500, min = 2 },
    { code = 'carplay_kit',  label = 'Kit CarPlay',        cost = 900, min = 3 },
}
Config.Stock = { requireParts = true }   -- false : les pièces sont décomptées mais une installation reste possible à 0

-- ---------------------------------------------------------------------
-- Dépannage : demandes des joueurs (app Urgences du téléphone › Dépannage, ou /depannage)
-- ---------------------------------------------------------------------
Config.Tow = {
    command = 'depannage',
    commandCooldown = 60,
    lifetime = 1800,
    statuses = {
        pending = 'En attente', accepted = 'Acceptée', enroute = 'En route', onsite = 'Sur place',
        diagnostic = 'Diagnostic en cours', quote = 'Devis en attente', repair = 'Réparation en cours',
        done = 'Terminée', cancelled = 'Annulée',
    },
}

Config.Statuses = {
    { id = 'available', label = 'Disponible',     color = '#22c55e' },
    { id = 'enroute',   label = 'En route',       color = '#3b82f6' },
    { id = 'busy',      label = 'En intervention', color = '#f59e0b' },
    { id = 'pause',     label = 'Indisponible',   color = '#94a3b8' },
}

-- Véhicules de service (garage placé en jeu par la direction)
Config.Garage = {
    vehicles = {
        { model = 'flatbed',   label = 'Plateau',    minLevel = 1 },
        { model = 'towtruck',  label = 'Dépanneuse', minLevel = 1 },
        { model = 'towtruck2', label = 'Dépanneuse légère', minLevel = 1 },
    },
    storeRadius = 8.0,
    pharmacy = { slots = 60, weight = 300000 },   -- coffre d'atelier (elyzea_inventory)
}

Config.Pay = { maxRate = 100000 }
Config.Catalog = { maxPrice = 1000000 }
Config.MapRefresh = 3000
Config.MapImage = { file = 'img/map.jpg', minX = -5661.2, maxX = 6694.0, minY = -4058.5, maxY = 8429.3 }

-- Grades du premier démarrage (salary = taux horaire de départ, réglé ensuite dans Finance)
Config.DefaultGrades = {
    { name = 'Apprenti',            level = 1, salary = 350, default = true,
      perms = { 'duty', 'repair', 'clean', 'flip', 'workshop', 'cosmetic', 'tow', 'tablet', 'vehicles_view' } },
    { name = 'Mécanicien',          level = 2, salary = 500,
      perms = { 'duty', 'repair', 'clean', 'flip', 'workshop', 'cosmetic', 'perf', 'carplay', 'quotes', 'tow', 'tablet', 'vehicles_view', 'stock_view' } },
    { name = 'Mécanicien confirmé', level = 3, salary = 650,
      perms = { 'duty', 'repair', 'repair_full', 'clean', 'flip', 'workshop', 'cosmetic', 'perf', 'carplay', 'quotes', 'tow', 'tow_manage', 'tablet',
                'vehicles_view', 'stock_view', 'stats_view', 'garage' } },
    { name = 'Chef d\'atelier',     level = 4, salary = 850,
      perms = { 'duty', 'repair', 'repair_full', 'clean', 'flip', 'workshop', 'cosmetic', 'perf', 'carplay', 'quotes', 'quotes_manage', 'tow', 'tow_manage',
                'tablet', 'vehicles_view', 'stock_view', 'stock_manage', 'stats_view', 'garage', 'direction', 'recruit', 'employees_view', 'promote',
                'demote', 'history_view' } },
    { name = 'Directeur',           level = 5, salary = 1100, perms = 'all' },
}
