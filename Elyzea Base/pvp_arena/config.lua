-- =========================================================
--  PVP ARENA - CONFIGURATION CENTRALE
--  Tout ce qui se règle est ici (sauf les arènes posées en jeu, gardées dans data/arenas.json).
-- =========================================================
Config = {}

Config.Locale = 'fr'                      -- fichier locales/<langue>.lua (textes du serveur et de l'interface)
Config.Permission = 'pvp_manage'          -- permission admin_menu des commandes d'administration
Config.Debug = false

-- ---------------------------------------------------------------- PNJ d'accès
-- Méthode conseillée : éditeur de map (admin_menu) › PNJ › rôle « ⚔️ Arène PvP ».
-- Méthode de secours (sans éditeur) : PNJ posé par cette ressource. Mets enabled = true et tes coordonnées.
Config.Npc = {
    enabled = false,                       -- false = on utilise le PNJ de l'éditeur de map
    model = 's_m_y_blackops_01',
    coords = vector4(0.0, 0.0, 0.0, 0.0),  -- EXEMPLE à remplacer (x, y, z, cap)
    scenario = 'WORLD_HUMAN_GUARD_STAND',
    label = 'Arène PvP',
    distance = 2.0,                        -- distance d'interaction (m)
}
Config.InteractKey = 38                    -- E (contrôle GTA) pour le PNJ de secours

-- ---------------------------------------------------------------- argent
Config.Account = 'bank'                    -- compte débité / crédité : 'bank' ou 'cash'
Config.Stake = { min = 0, max = 250000, step = 100 }   -- mise de participation (fixée par l'hôte, identique pour tous)
Config.Bet = { enabled = true, min = 100, max = 500000 } -- paris sur l'équipe gagnante (joueurs et spectateurs)
Config.HouseFeePct = { stake = 0, bet = 0 }  -- commission prélevée sur le pot (0 = aucune)
-- Un participant peut-il parier ? 'own' = seulement sur son équipe · 'none' = jamais · 'any' = sur n'importe quelle équipe
Config.ParticipantBets = 'own'
-- Un joueur qui quitte une partie en cours perd sa part (sa mise reste dans le pot, partagée entre les gagnants restants)
Config.LeaverForfeitsShare = true

-- ---------------------------------------------------------------- lobbies et parties
Config.MaxLobbies = 8                      -- parties simultanées maximum (lobbies + parties en cours)
Config.Modes = {                           -- formats proposés à l'hôte (joueurs par équipe)
    { id = '1v1', label = '1 contre 1', teamSize = 1 },
    { id = '2v2', label = '2 contre 2', teamSize = 2 },
    { id = '3v3', label = '3 contre 3', teamSize = 3 },
    { id = '5v5', label = '5 contre 5', teamSize = 5 },
}
Config.MaxTeamSize = 5
Config.WinsOptions = { 1, 2, 3, 5, 7 }     -- « première équipe à N manches »
Config.DefaultWins = 3
Config.RequireFullTeams = true             -- true : les deux équipes doivent être complètes pour lancer
Config.AllowFriendlyFireOption = true      -- l'hôte peut activer les dégâts alliés
Config.LobbyIdleTimeout = 30 * 60          -- lobby fermé (et remboursé) après N secondes sans lancement

Config.Teams = {
    A = { name = 'ALPHA', color = '#22d3ee' },
    B = { name = 'OMEGA', color = '#f97362' },
}

-- ---------------------------------------------------------------- manches et délais (secondes)
Config.Timers = {
    weaponSelect = 15,                     -- choix de l'arme
    loading = 2,                           -- chargement après la téléportation (avant le décompte)
    countdown = 3,                         -- décompte synchronisé
    roundEnd = 5,                          -- affichage du résultat de manche
    matchEnd = 10,                         -- écran de fin avant le retour au RP
    teleportGrace = 4,                     -- tolérance après une téléportation (contrôle de zone)
    deathSettle = 0.4,                     -- attente avant de juger la manche (morts presque simultanées)
}
Config.RoundTimes = { 60, 90, 120, 180 }   -- durées de manche proposées à l'hôte
Config.DefaultRoundTime = 120
-- Fin du temps : 'most_alive' (plus de joueurs vivants, puis plus de vie restante, sinon nulle) · 'draw' (manche nulle)
Config.TimeoutRule = 'most_alive'
-- Si les deux équipes sont éliminées en même temps : manche nulle (personne ne marque)
Config.MaxRounds = 25                      -- sécurité : au-delà, la partie s'arrête (plus de manches gagnées, sinon annulée)

-- Abandon / déconnexion pendant la partie quand une équipe n'a plus personne :
-- 'forfeit' = victoire de l'autre équipe (les mises restent jouées) · 'cancel' = partie annulée et tout remboursé
Config.AbandonPolicy = 'forfeit'

-- ---------------------------------------------------------------- instances (routing buckets)
Config.BucketBase = 61000                  -- buckets 61001…61000+MaxLobbies (n'utilise pas ceux des autres ressources)

-- ---------------------------------------------------------------- zone
Config.Zone = {
    checkInterval = 500,                   -- ms entre deux contrôles serveur
    maxExitsPerRound = 3,                  -- sorties tolérées par manche ; au-delà le joueur est éliminé de la manche
}

-- ---------------------------------------------------------------- armes (aucune ne vient de l'inventaire RP)
-- stats : 0-100, affichées dans l'interface
Config.WeaponCategories = {
    { id = 'pistol', label = 'Pistolets', icon = '🔫', weapons = {
        { name = 'WEAPON_PISTOL', label = 'Pistolet', stats = { damage = 26, rate = 40, range = 35, accuracy = 60 } },
        { name = 'WEAPON_COMBATPISTOL', label = 'Pistolet de combat', stats = { damage = 27, rate = 45, range = 38, accuracy = 62 } },
        { name = 'WEAPON_HEAVYPISTOL', label = 'Pistolet lourd', stats = { damage = 40, rate = 35, range = 40, accuracy = 55 } },
        { name = 'WEAPON_PISTOL50', label = 'Pistolet .50', stats = { damage = 51, rate = 30, range = 42, accuracy = 50 } },
    } },
    { id = 'smg', label = 'Mitraillettes', icon = '💨', weapons = {
        { name = 'WEAPON_MICROSMG', label = 'Micro SMG', stats = { damage = 21, rate = 85, range = 25, accuracy = 35 } },
        { name = 'WEAPON_SMG', label = 'SMG', stats = { damage = 22, rate = 80, range = 35, accuracy = 48 } },
        { name = 'WEAPON_COMBATPDW', label = 'PDW de combat', stats = { damage = 28, rate = 70, range = 40, accuracy = 52 } },
    } },
    { id = 'rifle', label = 'Fusils d\'assaut', icon = '🎯', weapons = {
        { name = 'WEAPON_ASSAULTRIFLE', label = 'Fusil d\'assaut', stats = { damage = 30, rate = 65, range = 60, accuracy = 55 } },
        { name = 'WEAPON_CARBINERIFLE', label = 'Carabine', stats = { damage = 32, rate = 65, range = 65, accuracy = 62 } },
        { name = 'WEAPON_SPECIALCARBINE', label = 'Carabine spéciale', stats = { damage = 32, rate = 68, range = 66, accuracy = 65 } },
        { name = 'WEAPON_BULLPUPRIFLE', label = 'Fusil bullpup', stats = { damage = 32, rate = 68, range = 60, accuracy = 64 } },
    } },
}
Config.DefaultWeapon = 'WEAPON_PISTOL'     -- donnée si le joueur ne choisit pas à temps (doit être autorisée, sinon la 1re autorisée)
Config.Health = 200                        -- vie au début de chaque manche (200 = max)
Config.Armor = 100                         -- gilet au début de chaque manche (0-100)
Config.Ammo = 250                          -- munitions données (illimitées dans l'arène : le chargeur se recharge normalement)

-- ---------------------------------------------------------------- arènes
-- EXEMPLES À REMPLACER : ces coordonnées ne sont pas tes arènes.
-- Le plus simple : en jeu, commandes /pvp_arena_* (voir README) → enregistré dans data/arenas.json, qui remplace ces exemples.
--   spawns.A / spawns.B : points d'apparition (x, y, z, cap) ; au moins un par joueur conseillé (sinon décalage automatique)
--   zone.points : coins de la zone (polygone, 3 minimum), zone.minZ / zone.maxZ : hauteur autorisée
--   safe : points sûrs où renvoyer un joueur sorti de la zone (vide = son point d'apparition)
Config.Arenas = {
    {
        id = 'exemple', label = 'Arène d\'exemple (à remplacer)',
        center = vector3(0.0, 0.0, 70.0),
        spawns = {
            A = { vector4(-20.0, 0.0, 70.0, 270.0), vector4(-20.0, 2.0, 70.0, 270.0) },
            B = { vector4(20.0, 0.0, 70.0, 90.0), vector4(20.0, 2.0, 70.0, 90.0) },
        },
        zone = { points = { vector2(-40.0, -30.0), vector2(40.0, -30.0), vector2(40.0, 30.0), vector2(-40.0, 30.0) }, minZ = 60.0, maxZ = 90.0 },
        safe = {},
        time = 12, weather = 'CLEAR',      -- heure et météo forcées pour les joueurs de l'arène (nil = celles du serveur)
    },
}

-- ---------------------------------------------------------------- interface
Config.UI = {
    accent = '#22d3ee',                    -- couleur principale (cyan)
    accent2 = '#3b82f6',                   -- bleu électrique
    showKillFeed = true,
    spectate = true,                       -- un joueur éliminé regarde ses coéquipiers encore en vie
}

-- Commandes d'administration (toutes protégées par Config.Permission ; utilisables depuis la console serveur)
Config.Commands = {
    list = 'pvp_list', info = 'pvp_info', cancel = 'pvp_cancel', kick = 'pvp_kick', stats = 'pvp_stats',
    arenaNew = 'pvp_arena_new', arenaAdd = 'pvp_arena_add', arenaReset = 'pvp_arena_reset', arenaHeight = 'pvp_arena_height',
    arenaShow = 'pvp_arena_show', arenaTp = 'pvp_arena_tp', arenaList = 'pvp_arenas', arenaDelete = 'pvp_arena_delete',
}
