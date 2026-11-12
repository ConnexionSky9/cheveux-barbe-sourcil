-- =========================================================
--  ELYFY : streaming musical du téléphone (+ studio IA)
--  Fichier séparé de config.lua : ton config.lua (clé d'hébergeur…) n'est pas touché.
-- =========================================================
Config.ElyFy = {
    -- ---------- Catalogue ----------
    -- Audius : musique libre et légale (titres complets), aucune clé nécessaire.
    Audius = { Enabled = true, Host = 'https://api.audius.co', AppName = 'ElyzeaFA' },
    -- YouTube : recherche de n'importe quel titre (lecture par le lecteur YouTube officiel).
    -- Clé API YouTube Data v3 (gratuite, console.cloud.google.com). Vide = celle d'Itoune (Config.Itoune.YouTubeApiKey).
    YouTubeApiKey = '',
    -- Titres du serveur (fichiers audio en https : Fivemanage, etc.), visibles par tous
    Catalog = {
        -- { title = 'Hymne de Los Santos', artist = 'Elyzea FA', url = 'https://r2.fivemanage.com/xxx/hymne.mp3', thumb = '', genre = 'pop' },
    },
    -- Artistes de la ville : un joueur peut publier son propre titre (lien audio de ces hébergeurs)
    UploadHosts = { 'fivemanage.com', 'r2.dev', 'cdn.discordapp.com', 'media.discordapp.net' },

    -- ---------- Téléchargements (à partir de l'ElyAura 4) ----------
    -- Les titres téléchargés sont enregistrés DANS le téléphone : onglet Téléchargements, toujours disponibles.
    Downloads = { MinTier = 4, Max = { [4] = 100, [5] = 300, [6] = 1000 } },

    -- ---------- Bibliothèque ----------
    PlaylistsMax = 50,
    PlaylistItemsMax = 300,

    -- ---------- Studio IA : paroles + instru → chanson (comme Suno) ----------
    -- Fournisseur : Replicate (replicate.com > API tokens). Modèle de musique avec paroles : minimax/music-1.5.
    -- Le jeton reste sur le serveur : il n'est jamais envoyé aux joueurs.
    AI = {
        Enabled = true,
        Token = '',                       -- jeton Replicate (r8_...) : vide = studio désactivé (message aux joueurs)
        Model = 'minimax/music-1.5',      -- 'proprio/modele' ou 'proprio/modele:version'
        LyricsField = 'lyrics',           -- champ « paroles » du modèle
        PromptField = 'prompt',           -- champ « style / instru » du modèle
        Extra = { audio_format = 'mp3' }, -- champs en plus envoyés au modèle
        Price = 2500,                     -- prix d'une création ($ en banque), remboursé si elle échoue
        DailyPerPlayer = 3,               -- créations par personnage et par jour
        DailyServer = 60,                 -- créations par jour pour tout le serveur (protège ta facture)
        Concurrent = 4,                   -- créations envoyées en même temps au fournisseur
        LyricsMax = 600,                  -- caractères de paroles
        TimeoutMinutes = 15,              -- au-delà : échec et remboursement
        -- Le fichier du fournisseur expire (~1 h) : le téléphone du créateur le copie sur ton hébergeur
        -- (même méthode que l'appareil photo, UploadMethod = 'presigned'). Sinon : échec et remboursement.
        KeepTempMinutes = 55,
    },
    -- Instrus proposées (style envoyé à l'IA). Libellé, couleur de la carte, description pour le modèle.
    Styles = {
        { id = 'trap',    label = 'Trap',          color = '#9B5CFF', prompt = 'French trap, 140 BPM, heavy 808 bass, fast hi-hats, dark atmospheric pads, modern mix' },
        { id = 'drill',   label = 'Drill',         color = '#FF2D55', prompt = 'UK drill, 142 BPM, sliding 808, syncopated hi-hats, dark piano, aggressive' },
        { id = 'boom',    label = 'Rap old school', color = '#FFB547', prompt = '90s boom bap hip hop, 90 BPM, dusty drums, vinyl crackle, jazzy sample' },
        { id = 'afro',    label = 'Afro',          color = '#3EE6B0', prompt = 'Afrobeats, 105 BPM, log drums, bouncy percussion, warm guitar, sunny vibe' },
        { id = 'pop',     label = 'Pop',           color = '#FF6FB5', prompt = 'Catchy modern pop, 120 BPM, bright synths, punchy drums, radio ready' },
        { id = 'rnb',     label = 'R&B',           color = '#C9A6FF', prompt = 'Smooth contemporary R&B, 75 BPM, soft keys, deep bass, intimate' },
        { id = 'lofi',    label = 'Lo-fi',         color = '#6FE7F2', prompt = 'Lo-fi chill hop, 80 BPM, mellow piano, soft drums, warm tape saturation' },
        { id = 'rock',    label = 'Rock',          color = '#E8590C', prompt = 'Energetic rock, 130 BPM, distorted electric guitars, live drums, powerful' },
        { id = 'electro', label = 'Électro',       color = '#2EE6F0', prompt = 'Electro house, 126 BPM, big synth leads, four on the floor, club energy' },
        { id = 'reggaeton', label = 'Reggaeton',   color = '#F59E0B', prompt = 'Reggaeton, 95 BPM, dembow rhythm, latin percussion, catchy' },
        { id = 'zouk',    label = 'Zouk / Kompa',  color = '#EC4899', prompt = 'Caribbean zouk kompa, 95 BPM, romantic guitars, smooth groove' },
        { id = 'ballade', label = 'Ballade piano', color = '#A99BC9', prompt = 'Emotional piano ballad, 70 BPM, strings, cinematic, heartfelt' },
    },
    Moods = { 'Énergique', 'Mélancolique', 'Chill', 'Sombre', 'Joyeux', 'Romantique', 'Motivant', 'Festif' },
}
