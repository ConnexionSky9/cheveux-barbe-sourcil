-- =========================================================
--  ELYPICK : réseau social photo du téléphone (ex-InstaPick)
--  Fichier séparé de config.lua : ton config.lua (clé d'hébergeur…) n'est pas touché.
-- =========================================================
Config.ElyPick = {
    StoryHours = 24,            -- durée de vie d'une story (calculée en base de données)
    FeedPage = 8,               -- publications chargées à la fois dans le fil
    ExplorePage = 24,           -- photos chargées à la fois dans Recherche (chargement progressif)
    GridPage = 24,              -- photos chargées à la fois sur un profil
    CaptionLength = 280,        -- légende (la colonne existante en accepte 300)
    BioLength = 150,
    MessageLength = 500,
    HighlightsMax = 20,         -- catégories « à la une » par profil
    HighlightItemsMax = 50,     -- stories par catégorie
    NotificationDays = 60,      -- activité (likes, abonnés, stories) gardée N jours ; 0 = pour toujours

    -- Images : une photo de la galerie du joueur est toujours acceptée.
    -- Un lien collé n'est accepté que s'il vient d'un de ces hébergeurs (false = liens collés refusés).
    AllowLinks = true,
    ImageHosts = { 'fivemanage.com', 'r2.dev', 'cdn.discordapp.com', 'media.discordapp.net', 'i.imgur.com' },
    ImageFormats = { 'jpg', 'jpeg', 'png', 'webp', 'gif' },   -- vérifié quand le lien a une extension

    -- Musiques proposées à tous sur les publications (en plus de la bibliothèque Itoune de chaque joueur).
    -- url : lien YouTube ou fichier audio en https (comme Itoune).
    Music = {
        -- { title = 'Nuit sur Vinewood', artist = 'Los Santos Lofi', url = 'https://www.youtube.com/watch?v=XXXXXXXXXXX' },
    },
}
