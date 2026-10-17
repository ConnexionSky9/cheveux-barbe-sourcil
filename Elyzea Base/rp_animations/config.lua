-- =====================================================================
--  rp_animations : configuration (partagée client / serveur)
-- =====================================================================
Config = {}

-- Ouverture du menu
Config.OpenCommand = 'danses'          -- /danses
Config.OpenKey     = 'F7'              -- libre sur Elyzea (K = elyzea_animations, F6 = métiers)

-- Arrêt de l'animation (solo ou duo). X est aussi la touche d'arrêt d'elyzea_animations :
-- les deux ressources s'arrêtent ensemble, c'est voulu.
Config.StopCommand = 'stopanim'        -- /stopanim
Config.StopKey     = 'X'
Config.StopOnMove  = true              -- avancer / sauter arrête l'animation

-- Réponse aux invitations (même convention qu'elyzea_animations : Y / L, N = voix)
Config.AcceptKey = 'Y'
Config.RefuseKey = 'L'

-- Invitations
Config.Invite = {
    Timeout        = 20,    -- secondes pour répondre
    Cooldown       = 5,     -- secondes entre deux invitations d'un même joueur
    MaxPerMinute   = 6,     -- invitations maximum par minute et par joueur
    MaxDistance    = 3.0,   -- distance max pour inviter (mètres)
    StartDistance  = 4.0,   -- distance max au moment d'accepter (nouvelle vérification)
    ListRadius     = 5.0,   -- rayon de la liste « joueurs proches » dans le menu
    ShowNames      = false, -- false : « Une personne (ID 12) » ; true : nom du personnage (elyzea_core)
}

-- Sessions en duo
Config.Session = {
    PrepareTimeout = 10,    -- secondes pour que les deux joueurs soient en place
    MaxDistance    = 6.0,   -- au-delà, la session s'arrête toute seule
    CheckInterval  = 1000,  -- ms entre deux contrôles serveur (seulement s'il y a des sessions)
}

-- Positionnement avant une animation en duo
Config.Positioning = {
    WalkSpeed      = 1.0,   -- vitesse de marche vers sa place
    WalkTimeout    = 4000,  -- ms max pour rejoindre sa place
    SnapDistance   = 0.35,  -- en dessous : on ne marche pas, simple ajustement
    MaxSnap        = 1.2,   -- correction finale max : au-delà on annule au lieu de téléporter
    CheckObstacle  = true,  -- refuse si un mur sépare les deux joueurs
}

-- Contenu adulte (animations suggestives, non graphiques)
Config.Adult = {
    Enabled        = true,  -- false : catégorie masquée et invitations refusées par le serveur
    FadeAllowed    = true,  -- fondu au noir facultatif, choisi par chaque participant pour lui-même
    FadeDuration   = 1500,
}

-- Catalogue : les animations « à valider » sont exécutables (fichiers vérifiés au chargement)
-- mais leur rendu n'a pas encore été validé en jeu par le staff.
Config.ShowUnvalidated = true
-- Afficher les animations « à créer » en grisé (message clair au clic)
Config.ShowPlanned = true

-- États qui interdisent une animation en duo (state bags posés par les ressources Elyzea)
Config.BlockingStates = { 'emsDown', 'cuffed', 'carriedBy', 'escortedBy', 'emsEscortedBy' }

-- Calibrage des positions en jeu (/rpanim_calib) : permission ACE
Config.AdminAce = 'rp_animations.admin'

-- Contrôles bloqués pendant une animation en duo (tir, visée, armes, coups)
Config.DisabledControls = { 24, 25, 37, 44, 45, 140, 141, 142, 257, 263, 264 }
