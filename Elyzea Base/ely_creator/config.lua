Config = {}

-- Base Elyzea (elyzea_core) : personnages dans la table `players`, apparence dans `ely_characters`.

-- Nombre de personnages par compte. 1 = connexion directe, plus de 1 = écran de sélection
-- (doit correspondre à Config.Slots d'elyzea_multichar).
Config.MaxCharacters = 2

-- Écran de sélection externe (intro + choix du perso). false = sélection intégrée d'ely_creator.
Config.ExternalSelection = 'elyzea_multichar'

-- Nom affiché dans l'interface
Config.ServerName = 'Elyzea'

-- Salle de création (la pièce du créateur GTA Online, sous la carte)
Config.CreatorCoords = vector4(402.86, -996.74, -99.0, 180.0)

-- Point d'apparition après la création.
-- Si admin_menu est installé, c'est le point « nouveaux arrivants » choisi dans
-- admin_menu (Éditeur > Points de spawn) qui est utilisé. Celui-ci ne sert que de secours.
Config.SpawnCoords = vector4(-1037.74, -2737.93, 20.17, 330.0)

-- Après la création : cinématique holographique d'admin_menu (« Arrivée en ville »)
Config.WelcomeResource = 'admin_menu'

-- Chaque joueur en création est isolé dans son propre routing bucket (offset + id serveur)
Config.BucketOffset = 5000

-- Commande admin pour rouvrir le créateur (ace : command.creator)
-- Utilisation : /creator        -> soi-même
--               /creator [id]   -> un autre joueur
Config.AdminCommand = 'creator'

Config.Identity = {
    nameMin   = 2,
    nameMax   = 16,
    minAge    = 18,
    maxAge    = 90,
    heightMin = 150,
    heightMax = 210,
    -- Prénoms / noms interdits (comparaison insensible à la casse)
    blacklist = { 'admin', 'staff', 'moderateur', 'fondateur', 'police', 'test' }
}

Config.Nationalities = {
    'Française', 'Belge', 'Suisse', 'Canadienne', 'Américaine', 'Britannique', 'Irlandaise',
    'Allemande', 'Italienne', 'Espagnole', 'Portugaise', 'Néerlandaise', 'Polonaise', 'Russe',
    'Ukrainienne', 'Marocaine', 'Algérienne', 'Tunisienne', 'Sénégalaise', 'Ivoirienne',
    'Malienne', 'Camerounaise', 'Congolaise', 'Haïtienne', 'Mexicaine', 'Colombienne',
    'Brésilienne', 'Argentine', 'Cubaine', 'Turque', 'Libanaise', 'Japonaise', 'Chinoise',
    'Coréenne', 'Vietnamienne', 'Indienne', 'Australienne', 'Autre'
}

Config.Camera = {
    fov    = 38.0,
    -- Décale le personnage vers la droite de l'écran pour qu'il soit au milieu
    -- de la zone libre (le panneau occupe la gauche). 0 = centré sur l'écran.
    sideShift = 0.16,
    minFov = 15.0,
    maxFov = 70.0,
    -- dist : distance devant le ped, z : hauteur caméra, lookZ : hauteur visée (relatives au ped)
    presets = {
        face  = { dist = 0.75, z = 0.68, lookZ = 0.64 },
        torso = { dist = 1.45, z = 0.38, lookZ = 0.30 },
        legs  = { dist = 1.45, z = -0.35, lookZ = -0.55 },
        full  = { dist = 2.90, z = 0.15, lookZ = -0.05 }
    }
}

-- ─────────────────────────────────────────────────────────────
-- TENUES PRÉFAITES (onglet « Tenue »)
-- Le joueur choisit une tenue complète, il ne règle plus pièce par pièce.
-- Format : ['composant'] = { modèle, couleur }
--   1 masque · 3 bras/torse · 4 pantalon · 5 sac · 6 chaussures
--   7 accessoire cou · 8 sous-haut · 9 gilet · 10 badge · 11 haut
-- Astuce : pour trouver les numéros, essaie-les en jeu avec /creator ou un
-- magasin de vêtements, puis recopie-les ici. La 1re tenue est celle par défaut.
-- ─────────────────────────────────────────────────────────────
Config.Outfits = {
    [0] = { -- Homme
        { label = 'Décontracté', desc = 'T-shirt, jean et baskets',
          components = { ['1']={0,0}, ['3']={0,0}, ['4']={1,0}, ['5']={0,0}, ['6']={1,0}, ['7']={0,0}, ['8']={15,0}, ['9']={0,0}, ['10']={0,0}, ['11']={0,0} } },
        { label = 'Streetwear', desc = 'Sweat, jogging et sneakers',
          components = { ['1']={0,0}, ['3']={0,0}, ['4']={7,0}, ['5']={0,0}, ['6']={7,0}, ['7']={0,0}, ['8']={15,0}, ['9']={0,0}, ['10']={0,0}, ['11']={7,0} } },
        { label = 'Chic', desc = 'Costume et chaussures de ville',
          components = { ['1']={0,0}, ['3']={4,0}, ['4']={10,0}, ['5']={0,0}, ['6']={10,0}, ['7']={0,0}, ['8']={4,0}, ['9']={0,0}, ['10']={0,0}, ['11']={4,0} } },
        { label = 'Sport', desc = 'Débardeur, short et running',
          components = { ['1']={0,0}, ['3']={5,0}, ['4']={6,0}, ['5']={0,0}, ['6']={1,0}, ['7']={0,0}, ['8']={15,0}, ['9']={0,0}, ['10']={0,0}, ['11']={5,0} } },
    },
    [1] = { -- Femme
        { label = 'Décontractée', desc = 'Top, jean et baskets',
          components = { ['1']={0,0}, ['3']={15,0}, ['4']={0,0}, ['5']={0,0}, ['6']={3,0}, ['7']={0,0}, ['8']={14,0}, ['9']={0,0}, ['10']={0,0}, ['11']={2,0} } },
        { label = 'Streetwear', desc = 'Sweat, jogging et sneakers',
          components = { ['1']={0,0}, ['3']={3,0}, ['4']={2,0}, ['5']={0,0}, ['6']={3,0}, ['7']={0,0}, ['8']={14,0}, ['9']={0,0}, ['10']={0,0}, ['11']={3,0} } },
        { label = 'Chic', desc = 'Tailleur et escarpins',
          components = { ['1']={0,0}, ['3']={3,0}, ['4']={6,0}, ['5']={0,0}, ['6']={0,0}, ['7']={0,0}, ['8']={14,0}, ['9']={0,0}, ['10']={0,0}, ['11']={6,0} } },
        { label = 'Sport', desc = 'Brassière, legging et running',
          components = { ['1']={0,0}, ['3']={15,0}, ['4']={10,0}, ['5']={0,0}, ['6']={3,0}, ['7']={0,0}, ['8']={14,0}, ['9']={0,0}, ['10']={0,0}, ['11']={15,0} } },
    }
}

-- Tenue de secours si Config.Outfits est vide [composant] = { modèle, couleur }
Config.DefaultOutfit = {
    [0] = { ['1'] = { 0, 0 }, ['3'] = { 0, 0 }, ['4'] = { 0, 0 }, ['5'] = { 0, 0 }, ['6'] = { 1, 0 },
            ['7'] = { 0, 0 }, ['8'] = { 15, 0 }, ['9'] = { 0, 0 }, ['10'] = { 0, 0 }, ['11'] = { 0, 0 } },
    [1] = { ['1'] = { 0, 0 }, ['3'] = { 0, 0 }, ['4'] = { 0, 0 }, ['5'] = { 0, 0 }, ['6'] = { 0, 0 },
            ['7'] = { 0, 0 }, ['8'] = { 14, 0 }, ['9'] = { 0, 0 }, ['10'] = { 0, 0 }, ['11'] = { 0, 0 } }
}

-- Type de palette par calque (1 = cheveux, 2 = maquillage, 0 = pas de couleur)
Config.OverlayColorType = {
    [0] = 0, [1] = 1, [2] = 1, [3] = 0, [4] = 2, [5] = 2, [6] = 0,
    [7] = 0, [8] = 2, [9] = 0, [10] = 1, [11] = 0, [12] = 0
}

Config.ComponentIds = { 1, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
Config.PropIds = { 0, 1, 2, 6, 7 }
