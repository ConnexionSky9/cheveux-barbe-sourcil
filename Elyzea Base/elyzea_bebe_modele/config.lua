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
        -- V8 : UNE seule prise à la main, « contre soi » (l'ancienne prise « Dans les bras » est supprimée ; « bras » = alias).
        -- Pose bercée : le bébé (modèle « porté » : couché sur le dos, jambes repliées) est allongé à l'horizontale en
        -- travers du buste, tête vers le bras gauche (creux du coude), soutenu par les avant-bras croisés contre le torse.
        -- GTA n'a aucune animation de bercement (vérifié dans les 20 179 dictionnaires) : les bras croisés natifs sont
        -- la position la plus proche (avant-bras à l'horizontale contre le torse). Position et rotations réglables
        -- dans le menu admin (Famille › Position du bébé porté) et en jeu (/bebe_ajuster).
        face = {
            label = 'Contre soi', pose = 'porte', mainsOccupees = true,
            anim = { dict = 'amb@world_human_hang_out_street@female_arms_crossed@base', clip = 'base', flag = 49 },
            -- contrôle hors du jeu : Outils_3D/bebe/scripts/controle_portage.py (écart au buste du mannequin : 2,9 cm homme, 1,3 cm femme)
            pos = vector3(0.06, 0.22, 0.27), rot = vector3(0.0, -20.0, -90.0),
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
    alias = { portebebe = 'ventral', bras = 'face', contre = 'face' },
    -- Poses au sol (lit, berceau, banc, sol)
    poses = {
        allonge = { label = 'Poser allongé', pose = 'allonge' },
        assis = { label = 'Poser assis', pose = 'assis' },
    },
    -- Gestes natifs vérifiés (se pencher) pour prendre et déposer le bébé ; durée en ms
    gestes = {
        prendre = { dict = 'pickup_object', clip = 'pickup_low', duree = 1100 },
        poser = { dict = 'pickup_object', clip = 'putdown_low', duree = 1100 },
    },
    distancePrendre = 2.0,       -- mètres entre le joueur et le bébé posé
    distancePoser = 2.5,         -- distance max du point où l'on pose le bébé
    bloquerMelee = true,         -- le porteur ne peut pas frapper (il reste vulnérable : aucune protection)
    rangerArme = true,           -- modes « mains occupées » : l'arme en main est rangée tant que l'on porte le bébé
    verification = 2000,         -- ms entre deux vérifications serveur (attaches, mort, déconnexion, abandon)
    -- V8 : tout le monde peut prendre un bébé contre soi (le portage ne change jamais la filiation ni les responsables).
    -- On ne prend jamais un bébé déjà porté : son porteur doit d'abord le poser.
    reserveAuxResponsables = false,
    -- Personnages féminins : bébé et porte-bébé décalés (personnage plus petit), par prise. Calculé sur le mannequin.
    morphologies = {
        [GetHashKey('mp_f_freemode_01')] = {
            ventral = v3(GEO.ventral and GEO.ventral.decalage_femme, vector3(0.0, 0.016, -0.07)),
            dorsal = v3(GEO.dorsal and GEO.dorsal.decalage_femme, vector3(0.0, 0.004, -0.07)),
            defaut = vector3(0.0, 0.0, -0.06),     -- contre soi, poussette
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
    -- V6 : physique (shared/physique.lua). Garée = frein serré ; « Lâcher sans frein » ou frein desserré : elle roule
    -- si la pente le justifie, suit le terrain, s'arrête devant un obstacle, peut se renverser (le bébé est alors posé à côté).
    physique = {
        actif = true,
        distanceSimulation = 120.0,  -- m : joueur le plus proche qui calcule le mouvement (vu par tous)
        distanceMax = 250.0,         -- m : trajet maximal accepté par le serveur
        dureeMax = 90,               -- s : au-delà, la poussette est garée là où elle est
        parametres = {               -- valeurs de shared/physique.lua remplacées (vide = valeurs par défaut)
            -- crr = 0.035, seuilDepart = 0.045, vChoc = 2.6, roulisMax = math.rad(32),
        },
    },
    roues = true,                -- roues séparées qui tournent (objets locaux, vus par chaque joueur)
}

-- Commandes (joueurs)
Config.Commandes = {
    prendre = 'bebe_prendre',    -- /bebe_prendre [contre|ventral|dorsal] : le bébé posé le plus proche (contre soi par défaut)
    poser = 'bebe_poser',        -- /bebe_poser [allonge|assis]
    mode = 'bebe_mode',          -- /bebe_mode [contre|ventral|dorsal]
}

-- ─────────────────────────── Persistance (base de données, tables créées automatiquement) ───────────────────────────
-- Les bébés « enregistrés » (nés d'une grossesse, elyzea_famille) et les poussettes sortie sont gardés en base :
-- état (posé, dans la poussette, avec un parent), position, sommeil. Ils reviennent après un redémarrage.
-- Les bébés de test (/bebe_creer) ne sont pas enregistrés.
Config.Persistance = {
    actif = true,
    -- Porteur d'un bébé enregistré qui se déconnecte / change de personnage : le bébé reste avec lui (aucune entité
    -- dans le monde) et revient à ses pieds à sa prochaine connexion. false : le bébé est reposé là où il était.
    garderALaDeconnexion = true,
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
