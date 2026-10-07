-- =====================================================================
--  CATALOGUE DU TATOUEUR
-- =====================================================================
--  Les tatouages du jeu sont lus automatiquement (data/tattoos_catalog.lua,
--  voir Config.Tattoo.sources). Ce fichier sert à :
--   • renommer les zones et les collections en français ;
--   • AJOUTER tes propres tatouages (addon) : voir TattooData.custom ;
--   • CACHER des tatouages : voir TattooData.hidden.
--  Après une modification : restart admin_menu
-- =====================================================================

TattooData = {}

-- Zones du corps (ordre d'affichage). « price » = clé de prix dans l'éditeur.
TattooData.zones = {
    { id = 'ZONE_HEAD',      label = 'Tête et cou',  icon = '🙂', price = 'head',      cam = 'face' },
    { id = 'ZONE_TORSO',     label = 'Torse et dos', icon = '👕', price = 'torso',     cam = 'torso' },
    { id = 'ZONE_LEFT_ARM',  label = 'Bras gauche',  icon = '💪', price = 'left_arm',  cam = 'larm' },
    { id = 'ZONE_RIGHT_ARM', label = 'Bras droit',   icon = '💪', price = 'right_arm', cam = 'rarm' },
    { id = 'ZONE_LEFT_LEG',  label = 'Jambe gauche', icon = '🦵', price = 'left_leg',  cam = 'legs' },
    { id = 'ZONE_RIGHT_LEG', label = 'Jambe droite', icon = '🦵', price = 'right_leg', cam = 'legs' },
}

-- Noms français des collections (les « catégories » du salon)
TattooData.collections = {
    multiplayer_overlays   = 'Classiques',
    mpbeach_overlays       = 'Plage',
    mpbusiness_overlays    = 'Business',
    mphipster_overlays     = 'Hipster',
    mpbiker_overlays       = 'Bikers',
    mpairraces_overlays    = 'Courses aériennes',
    mpchristmas2_overlays  = 'Fêtes',
    mpchristmas2017_overlays = 'Fin du monde',
    mpchristmas2018_overlays = 'Arène',
    mpchristmas3_overlays  = 'Fêtes 2',
    mpgunrunning_overlays  = 'Trafic d\'armes',
    mpimportexport_overlays = 'Import / Export',
    mplowrider_overlays    = 'Lowriders',
    mplowrider2_overlays   = 'Lowriders 2',
    mpluxe_overlays        = 'Luxe',
    mpluxe2_overlays       = 'Luxe 2',
    mpsmuggler_overlays    = 'Contrebande',
    mpstunt_overlays       = 'Cascades',
    mpbattle_overlays      = 'Boîtes de nuit',
    mpvinewood_overlays    = 'Casino',
    mpheist3_overlays      = 'Braquage du casino',
    mpheist4_overlays      = 'Cayo Perico',
    mptuner_overlays       = 'Tuners',
    mpsecurity_overlays    = 'Le Contrat',
    mpsum2_overlays        = 'Entreprises criminelles',
    mpsum_overlays         = 'Été',
    mpgunrunning2_overlays = 'Trafic d\'armes 2',
}

-- Tes propres tatouages (addon streamés, ou tatouages du jeu absents de la liste)
--   collection : nom de la collection (fichier .ymt / overlays)
--   male / female : nom du tatouage pour chaque sexe ('' = pas disponible)
--   zone : une des zones ci-dessus
TattooData.custom = {
    -- { label = 'Mon tatouage', collection = 'mon_pack_overlays', male = 'MonPack_M_000', female = 'MonPack_F_000', zone = 'ZONE_TORSO' },
}

-- Tatouages cachés du salon (nom du tatouage homme OU femme)
TattooData.hidden = {
    -- ['MP_Bea_M_Back_000'] = true,
}
