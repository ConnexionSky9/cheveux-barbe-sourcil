-- =====================================================================
--  Elyzea animations : réglages des danses à deux et en groupe (partagé client / serveur)
--  Les danses solo passent par le système d'animations habituel (rpemotes).
-- =====================================================================
DanseConfig = {}

-- Invitations (duo et groupe)
DanseConfig.Invite = {
    Timeout       = 20,    -- secondes pour répondre
    Cooldown      = 5,     -- secondes entre deux invitations d'un même joueur
    MaxPerMinute  = 8,     -- invitations maximum par minute et par joueur (une invitation de groupe compte pour une)
    MaxDistance   = 3.0,   -- duo : distance max pour inviter (mètres), comme les animations partagées
    StartDistance = 4.0,   -- duo : distance max au moment d'accepter (nouvelle vérification)
}

-- Groupes
DanseConfig.Group = {
    MaxMembers     = 8,     -- meneur compris
    InviteDistance = 8.0,   -- distance max entre le meneur et les invités
    MaxDistance    = 15.0,  -- au-delà, le participant quitte le groupe automatiquement
    Spacing        = 1.1,   -- écart entre deux danseurs (mètres)
    CircleRadius   = 1.6,   -- rayon du cercle
}

-- Sessions
DanseConfig.Session = {
    PrepareTimeout = 10,    -- secondes pour que tout le monde soit en place
    MaxDistance    = 6.0,   -- duo : au-delà, la danse s'arrête
    CheckInterval  = 1000,  -- ms entre deux contrôles serveur (seulement s'il y a des danses)
}

-- Positionnement
DanseConfig.Positioning = {
    WalkSpeed     = 1.0,    -- vitesse de marche vers sa place
    WalkTimeout   = 4000,   -- ms max pour rejoindre sa place
    SnapDistance  = 0.35,   -- en dessous : pas de marche
    MaxSnap       = 1.2,    -- duo : correction finale max, au-delà on annule au lieu de téléporter
    CheckObstacle = true,   -- duo : refuse si un mur sépare les deux joueurs
}

-- Arrêt : avancer / sauter arrête la danse (X et /stopanim aussi)
DanseConfig.StopOnMove = true
DanseConfig.StopCommand = 'stopanim'

-- États Elyzea qui interdisent une danse (state bags)
DanseConfig.BlockingStates = { 'emsDown', 'cuffed', 'carriedBy', 'escortedBy', 'emsEscortedBy' }

-- Calibrage des positions en jeu (/danse_calib) et validation (/danse_valider) : permission ACE
-- ('admin' de group.admin fonctionne aussi)
DanseConfig.AdminAce = 'elyzea_animations.admin'

-- Contrôles bloqués pendant une danse à plusieurs (tir, visée, armes, coups)
DanseConfig.DisabledControls = { 24, 25, 37, 44, 45, 140, 141, 142, 257, 263, 264 }
