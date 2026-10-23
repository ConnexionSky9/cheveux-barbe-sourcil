-- =========================================================
--  ELYZEA TAGS - CONFIGURATION
--  Les réglages marqués (menu) se changent aussi en jeu :
--  admin_menu › Illégal › Tags (permission « tags_manage »).
--  Ici, seulement les valeurs de départ.
-- =========================================================
Config = {}

Config.AdminResource = 'admin_menu'
Config.AdminPermission = 'tags_manage'
Config.IllegalResource = 'elyzea_illegal'   -- territoires et groupes (facultatif)

-- Logs Discord propres aux tags (en plus de l'onglet Logs du menu staff). Laisser vide pour désactiver.
Config.DiscordWebhook = ''

-- ---------------------------------------------------------
--  Objets (déclarés dans elyzea_inventory/shared/items.lua)
-- ---------------------------------------------------------
Config.Items = {
    spray = 'spraycan',          -- bombe de peinture : peindre un tag
    remover = 'sprayremover',    -- solvant anti-graffiti : effacer un tag
}

-- ---------------------------------------------------------
--  Réglages modifiables en jeu (menu)
-- ---------------------------------------------------------
Config.Defaults = {
    enabled = true,          -- false : plus personne ne peut peindre (les tags existants restent)
    requireGroup = false,    -- true : seuls les membres d'un groupe illégal peuvent taguer
    consumeSpray = true,     -- une bombe est utilisée par tag
    consumeRemover = true,   -- un solvant est utilisé par tag effacé
    cooldown = 120,          -- secondes entre deux tags d'un même personnage
    maxPerPlayer = 10,       -- tags actifs par personnage (au-delà, son plus ancien tag disparaît)
    maxPerZone = 40,         -- tags dans un même territoire (au-delà, le plus ancien du territoire disparaît) ; hors territoire : seule la limite par personnage compte
    expireDays = 0,          -- 0 : les tags restent jusqu'au nettoyage ; sinon ils s'effacent après N jours
    overwrite = true,        -- peindre par-dessus un tag (moins de 1 m) le remplace (repasse des gangs rivaux)
    cleanReward = 0,         -- argent donné pour chaque tag effacé (0 = rien), sur Config.CleanRewardAccount
    -- Mots refusés (insultes, propos haineux, pubs…), toujours repérés malgré les majuscules, accents,
    -- lettres répétées, espaces ou points et l33t (« P.u.u.t.3 » = « pute »).
    -- Un mot de 6 lettres et plus est cherché partout, même collé à un autre (« salope » dans « grossalope »).
    -- Un mot plus court n'est refusé qu'écrit seul (« pute » oui, « dispute » non), sauf s'il commence par *
    -- (« *nazi » : cherché partout).
    blacklist = {
        'pute', 'putain', 'salope', 'connard', 'connasse', 'encule', 'enculer', 'batard', '*fdp', '*ntm', 'tg', 'nique', 'niquer',
        'pd', 'tapette', 'pede', 'gouine', 'negre', 'negro', 'bougnoul', 'bicot', 'youpin', '*nazi', '*hitler', 'sieg', 'heil', '*kkk', 'ss',
        'bite', 'chatte', 'couille', 'zizi', '*pedo', 'viol', 'violer', 'suicide', 'terroriste',
        '*fuck', 'shit', 'bitch', 'cunt', '*nigg', 'faggot', 'whore', 'rape', 'porn',
        '*discord', 'http', 'www', 'twitch', 'youtube', 'tiktok',
    },
}

Config.CleanRewardAccount = 'cash'   -- compte elyzea_core payé quand cleanReward > 0
-- Métiers autorisés à effacer les tags (vide = tout le monde avec un solvant). Ex. : { 'police', 'mairie' }
Config.CleanJobs = {}

-- ---------------------------------------------------------
--  Texte et apparence
-- ---------------------------------------------------------
Config.MaxLength = 20         -- caractères par tag
Config.Size = { min = 0.8, max = 3.0, default = 1.6, step = 0.1 }   -- largeur du tag (mètres)
Config.Colors = { '#f2f2f2', '#111111', '#e0433b', '#ff8a1f', '#f5d000', '#46c35a', '#1fb5c9', '#3b6fe0', '#9b4de0', '#ff5fb4' }
-- Styles d'écriture (polices Google Fonts, chargées par le jeu)
Config.Fonts = {
    { key = 'graff',  label = 'Graff',     family = 'Sedgwick Ave Display' },
    { key = 'marker', label = 'Marqueur',  family = 'Permanent Marker' },
    { key = 'drip',   label = 'Coulures',  family = 'Rubik Wet Paint' },
    { key = 'bubble', label = 'Bulles',    family = 'Bangers' },
    { key = 'scrawl', label = 'Gribouillé', family = 'Rock Salt' },
}

-- ---------------------------------------------------------
--  Peinture / nettoyage
-- ---------------------------------------------------------
Config.Spray = {
    duration = 7000,          -- ms d'animation pour peindre
    reach = 3.0,              -- distance max joueur → mur
    maxSlope = 0.6,           -- 0 = mur vertical, 1 = sol ; 0.6 accepte les murs inclinés (≈ 37°), refuse sols et plafonds
    flatness = 0.15,          -- creux / bosses tolérés sous le tag (m) : briques, joints, moulures
    minSpacing = 1.0,         -- distance sous laquelle deux tags se superposent
    -- Matières interdites (vitres, eau…) : numéros affichés par /tagmat (staff) en visant la surface.
    -- Exemple : forbiddenMaterials = { 1500272081, 937503243 }
    forbiddenMaterials = {},
}

-- Rotation du tag sur le mur (flèches ← →)
Config.Rotation = { max = 45.0, speed = 1.5 }   -- degrés max de chaque côté ; degrés par image en maintenant la flèche

-- On tague PARTOUT sur la carte, dans un territoire ou non.
-- Zones protégées (facultatif) : aucun tag possible dedans (vérifié par le client ET le serveur).
-- Vide = aucune zone protégée. Pour en remettre, enlève les -- devant les lignes voulues
-- (coordonnées approximatives : ajuste-les avec ta position dans le menu staff).
Config.ForbiddenZones = {
    -- { name = 'Commissariat de Mission Row', x = 441.0,  y = -982.0, z = 30.7, radius = 60.0 },
    -- { name = 'Hôpital Pillbox',             x = 300.0,  y = -584.0, z = 43.3, radius = 70.0 },
    -- { name = 'Mairie',                      x = -544.0, y = -204.0, z = 38.2, radius = 50.0 },
}
Config.Clean = {
    duration = 9000,          -- ms d'animation pour effacer
    reach = 3.0,              -- distance max joueur → tag
}

-- ---------------------------------------------------------
--  Affichage (performances)
-- ---------------------------------------------------------
Config.Render = {
    distance = 60.0,          -- distance à laquelle un tag devient visible
    maxVisible = 16,          -- tags affichés en même temps (les plus proches)
    texture = { w = 1024, h = 512 },
    nightDim = 0.6,           -- luminosité la nuit (21 h → 6 h), 1 = pas de différence
}
