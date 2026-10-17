-- =====================================================================
--  ELYZEA BÉBÉ (modèle) - réglages
--  Les modèles eux-mêmes sont listés dans shared/modeles.lua (fichier généré).
-- =====================================================================
Config = {}

-- Apparence par défaut quand une valeur manque ou est inconnue
Config.Defaut = { teinte = 'peau3', yeux = 'ardoise', coiffure = 'duvet_brun' }

-- Placement du bébé porté par un personnage.
-- Le bébé est attaché au personnage (pas à un os du bras) : il reste stable pendant l'animation.
-- pos = décalage en mètres (x = droite du personnage, y = devant, z = haut, depuis le bassin)
-- rot = rotation en degrés. VALEURS DE DÉPART : à ajuster en jeu avec /bebe_ajuster (voir README).
Config.Porter = {
    porte = {
        anim = { dict = 'anim@heists@box_carry@', clip = 'idle', flag = 49 },
        pos = vector3(0.10, 0.34, 0.18), rot = vector3(0.0, 0.0, 90.0),
    },
    ventral = {
        anim = nil,   -- porte-bébé : mains libres
        pos = vector3(0.0, 0.21, 0.16), rot = vector3(0.0, 0.0, 0.0),
    },
}

-- Commandes de test (staff). Permission ACE : add_ace group.admin command.bebe_test allow
-- (le groupe admin a déjà « command allow » dans permissions.cfg).
Config.Commandes = {
    test = 'bebe_test',          -- /bebe_test [pose] [teinte] [yeux] [coiffure|chauve]
    galerie = 'bebe_galerie',    -- /bebe_galerie [pose] : les 6 teintes côte à côte
    ajuster = 'bebe_ajuster',    -- /bebe_ajuster x y z rx ry rz : déplace le bébé porté et affiche les valeurs
    retirer = 'bebe_retirer',    -- supprime les bébés de test
}
