-- =====================================================================
--  ELYZEA BÉBÉ (modèle) - réglages
--  Les modèles eux-mêmes sont listés dans shared/modeles.lua (fichier généré).
-- =====================================================================
Config = {}

Config.Debug = false

-- Apparence par défaut quand une valeur manque ou est inconnue
Config.Defaut = { teinte = 'peau3', yeux = 'ardoise', coiffure = 'duvet_brun' }

-- ─────────────────────────── Portage (visible par tous les joueurs) ───────────────────────────
-- Le bébé porté est attaché au personnage (pas à un os du bras) : il reste stable pendant l'animation.
-- pos = décalage en mètres (x = droite du personnage, y = devant, z = haut, depuis le bassin)
-- rot = rotation en degrés. VALEURS DE DÉPART : à ajuster en jeu avec /bebe_ajuster (voir README).
-- mainsOccupees = true : les deux mains tiennent le bébé (l'arme en main est rangée, voir README).
Config.Portage = {
    modes = {
        bras = {
            label = 'Dans les bras', pose = 'porte', mainsOccupees = true,
            anim = { dict = 'anim@heists@box_carry@', clip = 'idle', flag = 49 },
            pos = vector3(0.10, 0.34, 0.18), rot = vector3(0.0, 0.0, 90.0),
        },
        face = {
            label = 'Face à moi', pose = 'ventral', mainsOccupees = true,
            anim = { dict = 'anim@heists@box_carry@', clip = 'idle', flag = 49 },
            pos = vector3(0.0, 0.30, 0.12), rot = vector3(0.0, 0.0, 0.0),
        },
        portebebe = {
            label = 'Porte-bébé', pose = 'ventral', mainsOccupees = false,
            anim = nil,   -- mains libres
            pos = vector3(0.0, 0.21, 0.16), rot = vector3(0.0, 0.0, 0.0),
        },
    },
    -- Poses au sol (lit, berceau, banc, sol)
    poses = {
        allonge = { label = 'Poser allongé', pose = 'allonge' },
        assis = { label = 'Poser assis', pose = 'assis' },
    },
    distancePrendre = 2.0,       -- mètres entre le joueur et le bébé posé
    distancePoser = 2.5,         -- distance max du point où l'on pose le bébé
    bloquerMelee = true,         -- le porteur ne peut pas frapper (il reste vulnérable : aucune protection)
    rangerArme = true,           -- modes « mains occupées » : l'arme en main est rangée tant que l'on porte le bébé
    verification = 2000,         -- ms entre deux vérifications serveur (attache, mort, déconnexion)
    -- true : seuls les responsables du bébé peuvent le prendre (liste fournie à la création) ; false : tout le monde
    reserveAuxResponsables = false,
}

-- Commandes (joueurs)
Config.Commandes = {
    prendre = 'bebe_prendre',    -- /bebe_prendre [bras|face|portebebe] : le bébé posé le plus proche
    poser = 'bebe_poser',        -- /bebe_poser [allonge|assis]
    mode = 'bebe_mode',          -- /bebe_mode [bras|face|portebebe]
}

-- Commandes staff (permission ACE command.<nom> ; le groupe admin a déjà « command allow »)
Config.Staff = {
    creer = 'bebe_creer',        -- /bebe_creer [teinte] [yeux] [coiffure|chauve] : bébé posé devant soi, visible par tous
    supprimer = 'bebe_supprimer',-- supprime le bébé posé le plus proche (ou tous : /bebe_supprimer tous)
    ajuster = 'bebe_ajuster',    -- /bebe_ajuster x y z rx ry rz : règle la position du bébé porté (affiche les valeurs)
    test = 'bebe_test',          -- aperçu LOCAL (visible par soi seul) : /bebe_test [pose] [teinte] [yeux] [coiffure]
    galerie = 'bebe_galerie',    -- aperçu LOCAL des 6 teintes : /bebe_galerie [pose]
    retirer = 'bebe_retirer',    -- supprime les aperçus locaux
}
