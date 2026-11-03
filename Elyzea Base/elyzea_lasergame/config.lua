-- =====================================================================
--  ELYZEA LASERGAME - CONFIGURATION PRINCIPALE
--  Réglages généraux, framework, PNJ, argent, PVP, spectateur, sécurité.
--  Les armes, les rangs et le mode Zombie se règlent dans shared/config.lua.
--  Presque tout est aussi modifiable EN JEU par le staff (/lgadmin) : les valeurs
--  modifiées en jeu sont enregistrées en base (table lg_settings) et remplacent celles-ci.
-- =====================================================================
Config = {}

Config.Locale = 'fr'
Config.Debug = false                      -- true : messages détaillés dans la console F8 / serveur

-- ---------------------------------------------------------------- framework
-- 'auto' : détecte elyzea_core, puis es_extended (ESX), puis qb-core / qbx_core (QBCore)
Config.Framework = 'auto'                 -- 'auto' | 'elyzea' | 'esx' | 'qbcore'

-- ---------------------------------------------------------------- permissions staff
Config.Permission = 'lasergame_manage'    -- permission admin_menu (case à cocher dans les rangs staff)
Config.AcePermission = 'elyzea_lasergame.admin'  -- ou ACE : add_ace group.admin elyzea_lasergame.admin allow
Config.AdminCommand = 'lgadmin'           -- ouvre l'interface staff

-- ---------------------------------------------------------------- instances
Config.BucketBase = 63000                 -- parties : 63001, 63002… (pvp_arena : 61000+, labos : 52000+)
Config.MaxParallelGames = 10              -- parties simultanées (PVP + Zombie)

-- ---------------------------------------------------------------- PNJ d'accès
-- Deux méthodes, cumulables :
--   1. éditeur de map (admin_menu › Éditeur de map › PNJ › rôle « 🔫 LaserGame ») ;
--   2. la liste ci-dessous, et les PNJ ajoutés en jeu depuis /lgadmin › PNJ (« Poser ici »).
Config.Npcs = {
    {
        id = 'lg_accueil',
        enabled = true,
        model = 's_m_y_ammucity_01',
        coords = vector4(-1256.66, -1440.81, 4.37, 125.0),   -- EXEMPLE (Vespucci) : déplace-le depuis /lgadmin › PNJ
        scenario = 'WORLD_HUMAN_CLIPBOARD',                   -- ou nil pour utiliser anim ci-dessous
        anim = nil,                                           -- { dict = 'anim@amb@...', name = '...' }
        distance = 2.2,                                       -- distance d'interaction (m)
        label = 'LaserGame ElyzeaFA',
        text = 'Ouvrir le LaserGame',
        blip = { enabled = true, sprite = 432, color = 27, scale = 0.85, label = 'LaserGame ElyzeaFA' },
    },
}
Config.NpcLoadDistance = 60.0             -- le PNJ n'existe que si un joueur est à moins de N m (supprimé au-delà)
Config.InteractKey = 'E'                  -- touche par défaut (modifiable par chaque joueur dans les réglages GTA)

-- ---------------------------------------------------------------- argent RP (mises PVP)
Config.Account = 'bank'                   -- 'bank' ou 'cash'
Config.Stake = {
    enabled = true,
    min = 0,                              -- 0 = partie sans mise autorisée
    max = 250000,
    step = 100,
    houseFeePct = 0,                      -- commission prélevée sur le pot (0 = aucune)
}
Config.LeaverForfeitsShare = true         -- un joueur parti en cours de partie ne touche pas de part du pot

-- ---------------------------------------------------------------- PVP
Config.PvP = {
    enabled = true,
    formats = {                            -- joueurs par équipe
        { id = '1v1', label = '1 VS 1', size = 1 },
        { id = '2v2', label = '2 VS 2', size = 2 },
        { id = '3v3', label = '3 VS 3', size = 3 },
        { id = '4v4', label = '4 VS 4', size = 4 },
        { id = '5v5', label = '5 VS 5', size = 5 },
        { id = '6v6', label = '6 VS 6', size = 6 },
    },
    roundsOptions = { 1, 3, 5, 7, 9 },     -- nombre de manches (la partie s'arrête dès qu'une équipe ne peut plus être rattrapée)
    defaultRounds = 3,
    roundTimeOptions = { 60, 90, 120, 180, 240, 300 }, -- secondes
    defaultRoundTime = 120,
    requireFullTeams = false,              -- true : les deux équipes doivent être complètes pour lancer
    requireEqualTeams = true,              -- équipes de même taille obligatoires (équilibrage)
    minPlayersPerTeam = 1,
    lobbyIdleTimeout = 20 * 60,            -- lobby fermé (et remboursé) après N secondes sans lancement
    passwordMaxLength = 16,
    matchNameMaxLength = 28,
    shield = 100,                          -- « bouclier » laser d'un joueur (points de vie LaserGame)
    oneHitElimination = false,             -- true : un seul impact élimine (laser game classique)
    timeoutRule = 'most_alive',            -- 'most_alive' (plus de vivants, puis plus de bouclier) | 'draw'
    friendlyFire = false,
    timers = {
        loading = 3,                       -- chargement de la map après la téléportation
        countdown = 5,                     -- décompte avant chaque manche
        roundEnd = 5,                      -- écran de fin de manche
        matchEnd = 12,                     -- écran de victoire / défaite avant le retour au RP
    },
    ranked = { public = true, private = false }, -- les parties privées ne comptent pas au classement (anti-farm)
    minRankedDuration = 45,                -- une partie plus courte (secondes de jeu) ne donne pas de points
}

-- Couleurs des équipes (lasers, HUD, tenues). Personnalisables.
Config.Teams = {
    A = { id = 'A', name = 'ROUGE', color = { 255, 45, 70 }, hex = '#FF2D46' },
    B = { id = 'B', name = 'BLEUE', color = { 40, 140, 255 }, hex = '#288CFF' },
}

-- Tenue LaserGame (gilet coloré). nil = garder les vêtements RP (ils sont toujours restaurés à la sortie).
Config.Outfits = {
    enabled = true,
    -- composants GTA : [id] = { drawable, texture } (homme / femme). 9 = gilet pare-balles (bodyarmor)
    male   = { A = { [9] = { 15, 0 } }, B = { [9] = { 15, 1 } }, Z = { [9] = { 15, 2 } } },
    female = { A = { [9] = { 17, 0 } }, B = { [9] = { 17, 1 } }, Z = { [9] = { 17, 2 } } },
}

-- ---------------------------------------------------------------- spectateur
Config.Spectator = {
    enabled = true,
    maxPerMatch = 12,
    eliminatedSeeTeamOnly = true,          -- un joueur éliminé ne peut observer que ses coéquipiers
    hideEnemyHealthToEliminated = true,    -- pas d'infos stratégiques (bouclier ennemi) pour un éliminé
    outsidersDelay = 0,                    -- délai (s) de mise à jour du score pour les spectateurs extérieurs
}

-- ---------------------------------------------------------------- classement
-- ---------------------------------------------------------------- appli « LaserGame » du téléphone (elyzea_aura)
-- Classement, points, demandes de match PVP, annonces programmées (bouton Rejoindre = point GPS, jamais de téléportation),
-- messages entre joueurs. L'appli se télécharge dans « Appli » du téléphone.
Config.Phone = {
    MaxOpenPerPlayer = 3,       -- annonces / demandes ouvertes en même temps par joueur
    PostCooldown = 60,          -- secondes entre deux publications d'un même joueur
    MessageCooldown = 2,        -- secondes entre deux messages
    MessageLength = 300,        -- caractères par message
    PostTextLength = 160,       -- caractères du texte d'une annonce
    MaxDaysAhead = 7,           -- une annonce se programme au plus N jours à l'avance
    ReminderMinutes = 10,       -- rappel aux inscrits N minutes avant l'heure (puis à l'heure)
    MatchRequestHours = 2,      -- une demande « dès que possible » disparaît après N heures
    EventGraceMinutes = 60,     -- une annonce reste visible N minutes après son heure
}

Config.LeaderboardPageSize = 10
Config.LeaderboardCacheSeconds = 30       -- les classements sont recalculés au plus toutes les N secondes

-- ---------------------------------------------------------------- sécurité
Config.Security = {
    maxEventsPerSecond = 25,               -- au-delà, l'événement est ignoré et journalisé
    maxShotDistanceSlack = 6.0,            -- tolérance (m) entre la position serveur et l'origine du tir
    banAfterSuspicious = 0,                -- 0 = jamais d'exclusion automatique (journalisation seulement)
}

-- ---------------------------------------------------------------- journaux
-- Webhook Discord facultatif : NE PAS l'écrire ici. Dans secrets.cfg :
--   set elyzea_lasergame_webhook "https://discord.com/api/webhooks/..."
Config.Logs = {
    console = true,
    database = true,
    discord = true,                        -- utilisé seulement si le convar ci-dessus est défini
    keepDays = 60,                         -- journaux plus anciens supprimés au démarrage
}
