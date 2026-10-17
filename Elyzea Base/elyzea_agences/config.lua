-- =====================================================================
--  ELYZEA AGENCES - configuration
--  Plusieurs agences pour un même métier : plusieurs polices (LSPD, BCSO…),
--  plusieurs EMS, plusieurs garages mécano, plusieurs agences Dynasty 8.
--  Chaque agence a son métier elyzea_core, son compte de société, ses grades,
--  ses employés, son préfixe de matricule, son téléphone de service et sa
--  zone d'alerte (dessinée sur la carte ou en jeu). Tout se gère EN JEU :
--  admin_menu › Agences des métiers (permission « agencies_manage ») ou /agences.
-- =====================================================================
Config = {}

Config.Command = 'agences'
Config.Permission = 'agencies_manage'      -- permission admin_menu
Config.Ace = 'elyzea.agences'              -- sans admin_menu : add_ace group.admin elyzea.agences allow

-- Types de métier raccordés. defaults = agence créée au premier démarrage
-- (reprend le métier existant : employés, grades et argent sont conservés).
-- alerts = le métier reçoit des alertes du public (zone d'alerte utile).
Config.Kinds = {
    { id = 'police',  res = 'elyzea_police',  label = 'Police',    icon = '🚓', alerts = true,
      defaults = { job = 'police',     label = 'LSPD',      short = 'LSPD', mat = 'LSPD-', phone = '911', color = '#3b82f6' } },
    { id = 'ems',     res = 'elyzea_ems',     label = 'EMS',       icon = '🚑', alerts = true,
      defaults = { job = 'ambulance',  label = 'SAMS',      short = 'SAMS', mat = 'SAMS-', phone = '912', color = '#ef4444' } },
    { id = 'meca',    res = 'elyzea_meca',    label = 'Mécano',    icon = '🔧', alerts = true,
      defaults = { job = 'mechanic',   label = 'Mécano',    short = 'MECA', mat = 'MECA-', phone = '913', color = '#f59e0b' } },
    { id = 'dynasty', res = 'elyzea_dynasty', label = 'Dynasty 8', icon = '🏠', alerts = false,
      defaults = { job = 'realestate', label = 'Dynasty 8', short = 'D8',   mat = 'D8-',   phone = '914', color = '#22c55e' } },
}

-- Alerte hors de toutes les zones dessinées :
--  'nearest' : agence dont la zone est la plus proche ; 'all' : toutes les agences du métier
-- (les agences SANS zone reçoivent toujours les alertes qui ne tombent dans aucune zone)
Config.Outside = 'nearest'

-- Carte satellite du panneau (mêmes bornes que les tablettes des métiers)
Config.Map = { file = 'img/map.jpg', minX = -5661.2, maxX = 6694.0, minY = -4058.5, maxY = 8429.3 }

Config.Limits = { polygons = 12, points = 120 }   -- par agence
