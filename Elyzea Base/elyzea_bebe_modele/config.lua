-- =====================================================================
--  ELYZEA BÉBÉ (modèle) - réglages (V4)
--  Les modèles et les positions calculées par la chaîne 3D sont dans shared/modeles.lua (fichier généré) :
--  BebeModeles.equipements.geo. Les valeurs ci-dessous les reprennent ; tu peux les remplacer à la main.
--  Une partie de ces réglages est aussi modifiable dans le menu admin (F10 › Autres › Famille › Bébés et équipements).
-- =====================================================================
Config = {}

Config.Debug = false

-- Apparence par défaut quand une valeur manque ou est inconnue
Config.Defaut = { teinte = 'peau3', tenue = 'pyjama', yeux = 'ardoise', coiffure = 'duvet_brun' }   -- tenue : 'pyjama' ou 'couche'

local GEO = (BebeModeles and BebeModeles.equipements and BebeModeles.equipements.geo) or {}
local function v3(t, def) return t and vector3(t[1] + 0.0, t[2] + 0.0, t[3] + 0.0) or def end

-- ─────────────────────────── Portage (visible par tous les joueurs) ───────────────────────────
-- Le bébé porté est attaché au personnage (repère de l'entité : x = droite, y = devant, z = haut, depuis le bassin).
-- pos = décalage en mètres, rot = rotation en degrés. Réglables en jeu : /bebe_ajuster (voir README).
-- mainsOccupees = true : les deux mains tiennent le bébé (l'arme en main est rangée).
-- equipement = le mode n'est possible qu'avec ce porte-bébé équipé (objet d'inventaire).
Config.Portage = {
    modes = {
        bras = {
            label = 'Dans les bras', pose = 'porte', mainsOccupees = true,
            -- animation native vérifiée : porter devant soi à deux bras (aucune animation de bercement n'existe dans GTA)
            anim = { dict = 'anim@heists@box_carry@', clip = 'idle', flag = 49 },
            pos = vector3(0.02, 0.33, 0.20), rot = vector3(0.0, 0.0, 90.0),
        },
        face = {
            label = 'Face à moi', pose = 'ventral', mainsOccupees = true,
            anim = { dict = 'anim@heists@box_carry@', clip = 'idle', flag = 49 },
            pos = vector3(0.0, 0.30, 0.12), rot = vector3(0.0, 0.0, 0.0),
        },
        ventral = {
            label = 'Porte-bébé ventral', pose = 'ventral', mainsOccupees = false, equipement = 'ventral',
            pos = v3(GEO.ventral and GEO.ventral.pos, vector3(0.0, 0.22, 0.26)),
            rot = v3(GEO.ventral and GEO.ventral.rot, vector3(0.0, 0.0, 0.0)),
        },
        dorsal = {
            label = 'Porte-bébé dorsal', pose = 'ventral', mainsOccupees = false, equipement = 'dorsal',
            pos = v3(GEO.dorsal and GEO.dorsal.pos, vector3(0.0, -0.23, 0.30)),
            rot = v3(GEO.dorsal and GEO.dorsal.rot, vector3(0.0, 0.0, 180.0)),
        },
    },
    -- anciens noms (V3) acceptés par les commandes
    alias = { portebebe = 'ventral' },
    -- Poses au sol (lit, berceau, banc, sol)
    poses = {
        allonge = { label = 'Poser allongé', pose = 'allonge' },
        assis = { label = 'Poser assis', pose = 'assis' },
    },
    distancePrendre = 2.0,       -- mètres entre le joueur et le bébé posé
    distancePoser = 2.5,         -- distance max du point où l'on pose le bébé
    bloquerMelee = true,         -- le porteur ne peut pas frapper (il reste vulnérable : aucune protection)
    rangerArme = true,           -- modes « mains occupées » : l'arme en main est rangée tant que l'on porte le bébé
    verification = 2000,         -- ms entre deux vérifications serveur (attaches, mort, déconnexion, abandon)
    -- true : seuls les responsables du bébé peuvent le prendre (liste fournie à la création) ; false : tout le monde
    reserveAuxResponsables = false,
    -- Personnages féminins : bébé et porte-bébé décalés (personnage plus petit), par prise. Calculé sur le mannequin.
    morphologies = {
        [GetHashKey('mp_f_freemode_01')] = {
            ventral = v3(GEO.ventral and GEO.ventral.decalage_femme, vector3(0.0, 0.016, -0.07)),
            dorsal = v3(GEO.dorsal and GEO.dorsal.decalage_femme, vector3(0.0, 0.004, -0.07)),
            defaut = vector3(0.0, 0.0, -0.06),     -- bras, face, poussette
        },
    },
}

-- ─────────────────────────── Équipements (objets d'inventaire existants : elyzea_inventory) ───────────────────────────
-- Utiliser l'objet dans l'inventaire : équiper / retirer (porte-bébés), sortir la poussette.
-- Les objets ne sont jamais consommés.
Config.Equipements = {
    ventral = {
        actif = true, item = 'porte_bebe_ventral', label = 'Porte-bébé ventral', modele = 'pb_ventral',
        pos = vector3(0.0, 0.0, 0.0), rot = vector3(0.0, 0.0, 0.0),   -- modèle déjà dans le repère du personnage
    },
    dorsal = {
        actif = true, item = 'porte_bebe_dorsal', label = 'Porte-bébé dorsal', modele = 'pb_dorsal',
        pos = vector3(0.0, 0.0, 0.0), rot = vector3(0.0, 0.0, 0.0),
    },
    coloris = 'gris',            -- coloris par défaut des porte-bébés (gris, marine, sauge)
}

Config.Poussette = {
    actif = true, item = 'poussette', label = 'Poussette', modele = 'poussette',
    coloris = 'graphite',        -- graphite ou sable
    -- poussée : la poussette est attachée devant le personnage (poignée dans les mains), animation native vérifiée
    anim = { dict = 'amb@prop_human_bum_shopping_cart@male@base', clip = 'base', flag = 49 },
    pos = v3(GEO.poussette and GEO.poussette.poussee and GEO.poussette.poussee.pos, vector3(0.0, 0.90, -0.98)),
    rot = v3(GEO.poussette and GEO.poussette.poussee and GEO.poussette.poussee.rot, vector3(0.0, 0.0, 0.0)),
    -- bébé couché dans la nacelle (repère de la poussette)
    nacelle = {
        pos = v3(GEO.poussette and GEO.poussette.nacelle and GEO.poussette.nacelle.pos, vector3(0.0, -0.06, 0.585)),
        rot = v3(GEO.poussette and GEO.poussette.nacelle and GEO.poussette.nacelle.rot, vector3(0.0, 0.0, 180.0)),
    },
    distance = 2.0,              -- distance pour pousser / installer le bébé / ranger
    courseInterdite = true,      -- pas de course en poussant (marche et petit trot seulement)
    obstacle = 1.45,             -- mètres : avancer est bloqué si un mur / un objet est devant la poussette
    suiviSol = true,             -- la poussette suit les pentes et marches (hauteur réajustée)
    abandon = 20,                -- minutes : une poussette VIDE et garée loin de son propriétaire (ou propriétaire parti) est supprimée
    distanceAbandon = 60.0,
}

-- Commandes (joueurs)
Config.Commandes = {
    prendre = 'bebe_prendre',    -- /bebe_prendre [bras|face|ventral|dorsal] : le bébé posé le plus proche
    poser = 'bebe_poser',        -- /bebe_poser [allonge|assis]
    mode = 'bebe_mode',          -- /bebe_mode [bras|face|ventral|dorsal]
}

-- Commandes staff (permission ACE command.<nom> ; le groupe admin a déjà « command allow »)
Config.Staff = {
    creer = 'bebe_creer',        -- /bebe_creer [teinte] [yeux] [coiffure|chauve] [pyjama|couche] : bébé posé devant soi, visible par tous
    supprimer = 'bebe_supprimer',-- supprime le bébé posé le plus proche (ou tous : /bebe_supprimer tous) ; aussi les poussettes vides
    ajuster = 'bebe_ajuster',    -- /bebe_ajuster x y z rx ry rz : règle la position du bébé porté ; /bebe_ajuster equipement|poussette …
    test = 'bebe_test',          -- aperçu LOCAL (visible par soi seul) : /bebe_test [pose] [teinte] [yeux] [coiffure] [tenue]
    galerie = 'bebe_galerie',    -- aperçu LOCAL des 6 teintes : /bebe_galerie [pose]
    retirer = 'bebe_retirer',    -- supprime les aperçus locaux
    diagnostic = 'bebe_diag',    -- état de tous les bébés, porte-bébés et poussettes (console serveur)
}
