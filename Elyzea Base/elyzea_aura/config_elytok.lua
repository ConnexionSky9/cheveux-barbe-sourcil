-- =========================================================
--  ELYTOK : réseau social vidéo du téléphone (à partir de l'ElyAura 3)
--  Fichier séparé de config.lua : ton config.lua (clé d'hébergeur…) n'est pas touché.
--  Les vidéos publiées sont celles de la galerie du joueur (filmées avec l'appareil photo).
-- =========================================================
Config.ElyTok = {
    FeedPage = 6,               -- vidéos chargées à la fois dans le fil
    GridPage = 24,              -- vidéos chargées à la fois sur un profil / un hashtag
    CaptionLength = 220,        -- légende (hashtags et @mentions compris)
    BioLength = 120,
    CommentLength = 150,
    MessageLength = 400,
    MaxSeconds = 60,            -- durée maximale d'une vidéo publiée (0 = pas de limite)

    -- Sons proposés à tous (en plus de la bibliothèque Itoune de chaque joueur et du son des autres vidéos).
    -- url : lien YouTube ou fichier audio en https (comme Itoune).
    Music = {
        -- { title = 'Nuit sur Vinewood', artist = 'Los Santos Lofi', url = 'https://www.youtube.com/watch?v=XXXXXXXXXXX' },
    },
}
