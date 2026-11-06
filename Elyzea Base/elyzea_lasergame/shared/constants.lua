-- =====================================================================
--  ELYZEA LASERGAME - CONSTANTES PARTAGÉES
-- =====================================================================
LG = LG or {}

LG.Resource = GetCurrentResourceName and GetCurrentResourceName() or 'elyzea_lasergame'
LG.Version = '2.0.0'

-- Phases d'une partie
LG.Phase = {
    LOBBY = 'lobby',            -- en attente de joueurs
    LOADING = 'loading',        -- téléportation et chargement de la map
    COUNTDOWN = 'countdown',    -- décompte avant la manche
    ROUND = 'round',            -- manche en cours
    ROUND_END = 'round_end',    -- résultat de manche
    ENDED = 'ended',            -- écran de fin
    CLOSED = 'closed',          -- terminée, joueurs rendus au RP
}

LG.Mode = { PVP = 'pvp' }

-- Résultats d'une partie / d'un joueur
LG.Result = { WIN = 'win', LOSS = 'loss', DRAW = 'draw', CANCEL = 'cancel', LEFT = 'left' }

-- Catégories de journaux
LG.LogCat = { ADMIN = 'admin', MONEY = 'money', PVP = 'pvp', SECURITY = 'security', ERROR = 'error' }

-- Nom du state bag partagé avec les autres ressources Elyzea (inventaire RP verrouillé,
-- pas de coma EMS ni de réapparition à l'hôpital pendant une partie) : même contrat que pvp_arena.
LG.StateArena = 'pvpArena'
LG.StateGame = 'laserGame'      -- 'pvp' | 'spectator' | nil
