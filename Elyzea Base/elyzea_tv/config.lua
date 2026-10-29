-- =====================================================================
--  ELYZEA TV - réglages
-- =====================================================================
Config = {}
Config.Debug = false

-- ---------------------------------------------------------------- télés à écran plat du jeu (ALT › Télécommande)
-- Seuls ces modèles sont des télés utilisables (écrans plats). Les vieilles télés cathodiques ne le sont pas.
-- rt = nom de l'écran d'origine du modèle (« render target ») ; si ce nom ne donne rien, les autres noms
-- de RenderTargets sont essayés automatiquement au chargement.
Config.FlatTVs = {
    { model = 'prop_tv_flat_01',          rt = 'tvscreen' },
    { model = 'prop_tv_flat_02',          rt = 'tvscreen' },
    { model = 'prop_tv_flat_02b',         rt = 'tvscreen' },
    { model = 'prop_tv_flat_03',          rt = 'tvscreen' },
    { model = 'prop_tv_flat_03b',         rt = 'tvscreen' },
    { model = 'prop_tv_flat_michael',     rt = 'tvscreen' },
    { model = 'prop_trev_tv_01',          rt = 'tvscreen' },
    { model = 'des_tvsmash_start',        rt = 'tvscreen' },
    { model = 'ex_prop_ex_tv_flat_01',    rt = 'ex_tvscreen' },
    { model = 'sm_prop_smug_tv_flat_01',  rt = 'tvscreen' },
    { model = 'xm_prop_x17_tv_flat_01',   rt = 'tvscreen' },
    { model = 'xm_prop_x17_tv_flat_02',   rt = 'tvscreen' },
    { model = 'v_med_cor_flatscreentv',   rt = 'tvscreen' },
}
Config.RenderTargets = { 'tvscreen', 'ex_tvscreen', 'tv_flat_01', 'tvscreen_big' }

Config.Flat = {
    controlDistance = 3.0,      -- distance max pour utiliser la télécommande (le serveur la vérifie)
    soundRange = 14.0,          -- le son s'entend jusqu'à X m (de plus en plus faible)
    renderRange = 25.0,         -- l'image est diffusée quand on est à moins de X m
    everyone = true,            -- true : tout le monde peut utiliser une télé ; false : seulement le staff (tv_manage)
    -- Affichage de l'image sur la télé :
    --   'both'         : écran d'origine du modèle + image posée sur la face avant de la télé (par défaut, marche toujours)
    --   'overlay'      : seulement l'image posée sur la face avant
    --   'rendertarget' : seulement l'écran d'origine du modèle (comme les émissions du jeu)
    display = 'both',
    margin = 0.035,             -- bord de la télé (cadre) laissé autour de l'image, en part de la largeur
}
-- Réglage fin par modèle (facultatif) : screen = { x = décalage gauche/droite, z = hauteur du centre, w = largeur, h = hauteur } en mètres,
-- dans le repère du modèle. Sans réglage, l'écran est calculé d'après la taille du modèle (16:9, en haut de la télé).

-- ---------------------------------------------------------------- écrans posés par le staff (menu admin › Écrans / TV)
Config.Custom = {
    remoteDistance = 3.0,       -- [E] Télécommande : à moins de X m du point de commande (là où se tenait le staff)
    defaultRange = 45.0,        -- portée du son par défaut (réglable écran par écran)
    minW = 0.4, maxW = 60.0,    -- largeur (m)
    minH = 0.25, maxH = 35.0,   -- hauteur (m)
    defaultW = 4.0, defaultH = 2.25,
    maxScreens = 60,
    idleColor = { 8, 8, 12 },   -- couleur d'un écran éteint
}

-- ---------------------------------------------------------------- lecture
Config.Player = {
    width = 1280, height = 720, -- taille de l'image de la page vidéo
    maxActive = 4,              -- vidéos affichées en même temps au maximum chez un joueur (performances)
    masterVolume = 1.0,         -- volume général (0 … 1)
    defaultVolume = 60,         -- volume d'une télé au démarrage (0 … 100)
    syncEvery = 10,             -- resynchronisation de la position de la vidéo (s)
    changeCooldown = 3,         -- délai minimum entre deux changements de vidéo par joueur (s)
}

Config.Keys = { interact = 38, back = 177 }
