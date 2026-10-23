-- =====================================================================
--  ELYZEA - Téléphone de service des métiers : configuration
-- =====================================================================
Config = {}

-- F6 sort le téléphone de service (le menu rapide F6 de chaque métier reste
-- accessible dans l'application « Menu rapide »). false = ancien F6 inchangé,
-- téléphone via /telpro.
Config.ReplaceF6 = true
Config.Command = 'telpro'

-- Métiers raccordés (ordre = priorité). prefix : début du numéro pro (XXX-XXXX)
Config.Jobs = {
    { res = 'elyzea_police',  bag = 'police',  label = 'LSPD',      prefix = '911', color = '#3b82f6' },
    { res = 'elyzea_ems',     bag = 'ems',     label = 'SAMS',      prefix = '912', color = '#ef4444' },
    { res = 'elyzea_meca',    bag = 'meca',    label = 'Mécano',    prefix = '913', color = '#f59e0b' },
    { res = 'elyzea_dynasty', bag = 'd8',      label = 'Dynasty 8', prefix = '914', color = '#22c55e' },
    { res = 'elyzea_concess', bag = 'concess', label = 'Concession', prefix = '915', color = '#a855f7' },
    { res = 'elyzea_presse',  bag = 'presse',  label = 'Presse',    prefix = '916', color = '#e11d48' },
}

-- Alertes (mêmes niveaux que la police et l'EMS ; pour les autres métiers,
-- le téléphone gère lui-même l'alerte, le blip et l'itinéraire)
Config.Alerts = {
    cooldown = 15,          -- secondes entre deux alertes d'un même employé
    maxMinutes = 30,        -- clôture automatique
    levels = {
        low    = { label = 'Faible',  color = '#22c55e', blipColor = 2,  text = 'Assistance non urgente demandée' },
        medium = { label = 'Moyenne', color = '#f59e0b', blipColor = 47, text = 'Renfort nécessaire rapidement' },
        high   = { label = 'Urgente', color = '#ef4444', blipColor = 1,  text = 'Intervention immédiate nécessaire' },
    },
}

-- Messages
Config.Messages = { maxLength = 300, history = 60, cooldownMs = 800 }

-- Appels (pma-voice, canal d'appel = base + id ; distinct des appels du téléphone perso)
Config.Calls = { channelBase = 80000, ringSeconds = 30 }

-- Carte : image satellite d'un métier (bornes identiques à Config.MapImage des métiers)
Config.Map = {
    image = 'https://cfx-nui-elyzea_ems/html/img/map.jpg',
    minX = -5661.2, maxX = 6694.0, minY = -4058.5, maxY = 8429.3,
    refresh = 3000,
}

-- Animation (le joueur garde le contrôle de ses déplacements)
Config.Anim = {
    dict = 'cellphone@', text = 'cellphone_text_read_base', call = 'cellphone_call_listen_base',
    carDict = 'anim@cellphone@in_car@ps', prop = 'prop_npc_phone_02', bone = 28422,
}
