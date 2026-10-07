-- =====================================================================
--  CATALOGUE DU COIFFEUR  —  le SEUL fichier à modifier pour le contenu
-- =====================================================================
--
--  ► AJOUTER / RENOMMER UNE COUPE
--    Le salon lit tout seul le nombre de coupes du jeu (+ tes coupes
--    addon). Ce fichier ne sert qu'à leur donner un NOM :
--
--        [41] = 'Ma nouvelle coupe',
--
--    Le numéro est celui de la coupe dans le jeu (affiché sur chaque carte
--    du salon). Une coupe sans nom s'affiche « Coupe n°41 ».
--
--  ► CACHER UNE COUPE
--        [23] = false,
--
--  ► APRÈS UNE MODIFICATION
--    `restart admin_menu` (ou `ensure admin_menu`) dans la console.
--
--  ► AJOUTER UNE VRAIE NOUVELLE COUPE (fichiers .ydd / .ytd)
--    Les fichiers vont dans admin_menu/stream/ : voir install/COIFFEUR.md,
--    partie « 4.3 ».
-- =====================================================================

BarberData = {}

-- ---------------------------------------------------------------------
--  COUPES DE CHEVEUX  (composant 2 du personnage)
-- ---------------------------------------------------------------------
BarberData.hair = {
    male = {
        [0]  = 'Rasé de près',
        [1]  = 'Coupe en brosse',
        [2]  = 'Faux hawk',
        [3]  = 'Hipster',
        [4]  = 'Raie sur le côté',
        [5]  = 'Coupe courte',
        [6]  = 'Biker',
        [7]  = 'Queue de cheval',
        [8]  = 'Tresses plaquées',
        [9]  = 'Plaqué en arrière',
        [10] = 'Court brossé',
        [11] = 'Hérissé',
        [12] = 'César',
        [13] = 'Effilé',
        [14] = 'Dreadlocks',
        [15] = 'Cheveux longs',
        [16] = 'Boucles en bataille',
        [17] = 'Surfeur',
        [18] = 'Raie courte sur le côté',
        [19] = 'Côtés plaqués',
        [20] = 'Long plaqué',
        [21] = 'Hipster jeune',
        [22] = 'Mulet',
        [23] = false,                       -- bug du jeu (coiffure « vision nocturne »)
        [24] = 'Tresses classiques',
        [25] = 'Tresses palmier',
        [26] = 'Tresses éclair',
        [27] = 'Tresses fouettées',
        [28] = 'Tresses zigzag',
        [29] = 'Tresses escargot',
        [30] = 'Hightop',
        [31] = 'Coiffé en arrière',
        [32] = 'Undercut en arrière',
        [33] = 'Undercut sur le côté',
        [34] = 'Crête hérissée',
        [35] = 'Mod',
        [36] = 'Mod dégradé',
        [37] = 'Flattop',
        [38] = 'Coupe militaire',
        -- [80] = 'Ma coupe addon',          ← exemple d'ajout
    },
    female = {
        [0]  = 'Rasée de près',
        [1]  = 'Court',
        [2]  = 'Carré dégradé',
        [3]  = 'Couettes',
        [4]  = 'Queue de cheval',
        [5]  = 'Crête tressée',
        [6]  = 'Tresses',
        [7]  = 'Carré',
        [8]  = 'Faux hawk',
        [9]  = 'Chignon banane',
        [10] = 'Carré long',
        [11] = 'Attaché lâche',
        [12] = 'Pixie',
        [13] = 'Frange rasée',
        [14] = 'Chignon haut',
        [15] = 'Carré ondulé',
        [16] = 'Chignon décoiffé',
        [17] = 'Pin-up',
        [18] = 'Chignon serré',
        [19] = 'Carré torsadé',
        [20] = 'Carré garçonne',
        [21] = 'Grande frange',
        [22] = 'Chignon haut tressé',
        [23] = 'Royal Amber',               -- admin_menu/stream : mp_f_freemode_01_mp_f_bikerdlc_01^hair_000 (remplace « Mulet »)
        [24] = 'Natt',                      -- admin_menu/stream : mp_f_freemode_01_female_heist^hair_000 (remplace la coiffure de vision nocturne)
        [25] = 'Tresses pincées',
        [26] = 'Tresses en feuille',
        [27] = 'Tresses zigzag',
        [28] = 'Couettes à frange',
        [29] = 'Tresses ondulées',
        [30] = 'Tresses enroulées',
        [31] = 'Banane roulée',
        [32] = 'Coiffée en arrière',
        [33] = 'Undercut en arrière',
        [34] = 'Undercut sur le côté',
        [35] = 'Crête hérissée',
        [36] = 'Bandana et tresse',
        [37] = 'Mod dégradé',
        [38] = 'Skinbyrd',
        [39] = 'Chignon soigné',
        [40] = 'Carré court',
        -- [85] = 'Ma coupe addon',          ← exemple d'ajout
    },
}

-- ---------------------------------------------------------------------
--  COULEURS DES YEUX  { nom, couleur de l'aperçu }
--  Les 9 premières sont naturelles, les autres sont des lentilles
--  fantaisie (activables PNJ par PNJ dans l'éditeur).
-- ---------------------------------------------------------------------
BarberData.naturalEyes = 9
BarberData.eyes = {
    { 'Vert', '#4f8f3a' }, { 'Émeraude', '#1f9a6b' }, { 'Bleu clair', '#7fb6e6' }, { 'Bleu océan', '#2c63b5' },
    { 'Marron clair', '#9a6a3a' }, { 'Marron foncé', '#4e2f1b' }, { 'Noisette', '#8a6b2c' }, { 'Gris foncé', '#4b5560' },
    { 'Gris clair', '#a9b3bd' }, { 'Rose', '#e58bb5' }, { 'Jaune', '#e5c43a' }, { 'Violet', '#7a4bc9' },
    { 'Noir total', '#050505' }, { 'Nuances de gris', '#777777' }, { 'Tequila sunrise', '#f08a24' }, { 'Atomique', '#9be52f' },
    { 'Distorsion', '#5a2fd1' }, { 'E-Cola', '#c4161c' }, { 'Space ranger', '#1fb8d6' }, { 'Yin-yang', '#dddddd' },
    { 'Cible', '#d6312a' }, { 'Lézard', '#b3a12c' }, { 'Dragon', '#d9661a' }, { 'Extraterrestre', '#3fd17a' },
    { 'Chèvre', '#c9a04a' }, { 'Smiley', '#f2d13c' }, { 'Possédé', '#f4f4f4' }, { 'Démon', '#b3121b' },
    { 'Infecté', '#cfd65a' }, { 'Alien', '#1c1c1c' }, { 'Mort-vivant', '#c8d0c8' }, { 'Zombie', '#9fb07a' },
}

-- Teintes de cheveux : les 29 premières sont naturelles, ensuite fantaisie
BarberData.naturalHairColors = 29

-- ---------------------------------------------------------------------
--  CALQUES DU VISAGE ET DU CORPS (barbe, sourcils, maquillage, peau…)
--   key       : nom interne (ne pas changer après la mise en service)
--   index     : numéro du calque dans GTA (0 à 12)
--   palette   : 'hair' (teintes de cheveux), 'makeup' (teintes de maquillage) ou nil (pas de couleur)
--   highlight : true = un second choix « Reflets »
--   none      : nom du choix « rien »
--   esx       : (inutilisé)
--   styles    : noms des styles ; un style sans nom s'affiche « <label> n°X »
--               (même principe que les coupes : [12] = false le cache)
-- ---------------------------------------------------------------------
BarberData.overlays = {
    beard = {
        index = 1, label = 'Barbe', palette = 'hair', highlight = true, none = 'Rasé de près', esx = 'beard',
        styles = { [0] = 'Barbe de 3 jours légère', 'Balbo', 'Barbe ronde', 'Bouc', 'Collier de menton', 'Duvet au menton',
            'Collier fin', 'Négligée', 'Mousquetaire', 'Moustache', 'Barbe taillée', 'Barbe de 3 jours', 'Barbe ronde fine',
            'Fer à cheval', 'Crayon et favoris', 'Collier', 'Balbo et favoris', 'Côtelettes', 'Barbe négligée', 'Bouclée',
            'Bouclée fournie', 'Moustache guidon', 'Faustienne', 'Otto et touffe', 'Otto pleine', 'Franz légère', 'Hampstead',
            'Ambrose', 'Collier Lincoln' },
    },
    brows = {
        index = 2, label = 'Sourcils', palette = 'hair', none = 'Aucun (épilés)', esx = 'eyebrows',
        styles = { [0] = 'Équilibrés', 'Mode', 'Cléopâtre', 'Interrogateurs', 'Féminins', 'Séducteurs', 'Pincés', 'Chola',
            'Triomphe', 'Insouciants', 'Galbés', 'Fins et courts', 'Double trait', 'Fins', 'Crayonnés', 'Épilés',
            'Droits et étroits', 'Naturels', 'Duveteux', 'Broussailleux', 'Chenille', 'Classiques', 'Méditerranéens',
            'Soignés', 'Touffus', 'Plumes', 'Épineux', 'Monosourcil', 'Ailés', 'Triple trait', 'Trait arqué', 'Découpés',
            'Estompés', 'Trait unique' },
    },
    makeup = {
        index = 4, label = 'Maquillage des yeux', palette = 'makeup', highlight = true, none = 'Sans maquillage', esx = 'makeup',
        styles = { [0] = 'Smoky noir', 'Bronze', 'Gris doux', 'Glamour rétro', 'Naturel', 'Œil de chat', 'Chola', 'Vamp',
            'Glamour Vinewood', 'Bubblegum', 'Rêve aqua', 'Pin-up', 'Passion violette', 'Œil de chat fumé', 'Rubis ardent',
            'Princesse pop' },
    },
    blush = {
        index = 5, label = 'Blush', palette = 'makeup', none = 'Sans blush', esx = 'blush',
        styles = { [0] = 'Complet', 'Incliné', 'Arrondi', 'Horizontal', 'Haut', 'Cœur', 'Années 80' },
    },
    lipstick = {
        index = 8, label = 'Rouge à lèvres', palette = 'makeup', none = 'Sans rouge à lèvres', esx = 'lipstick',
        styles = { [0] = 'Mat', 'Brillant', 'Contour mat', 'Contour brillant', 'Contour marqué mat', 'Contour marqué brillant',
            'Contour nude mat', 'Contour nude brillant', 'Estompé', 'Geisha' },
    },
    blemishes = {
        index = 0, label = 'Imperfections', none = 'Peau nette', esx = 'blemishes',
        styles = { [0] = 'Rougeole', 'Boutons', 'Taches', 'Éruption', 'Points noirs', 'Accumulation', 'Pustules', 'Boutons rouges',
            'Acné complète', 'Acné', 'Rougeurs des joues', 'Rougeurs du visage', 'Grattages', 'Puberté', 'Œil irrité',
            'Rougeurs du menton', 'Deux visages', 'Zone T', 'Peau grasse', 'Marquée', 'Cicatrices d\'acné',
            'Cicatrices d\'acné marquées', 'Boutons de fièvre', 'Impétigo' },
    },
    ageing = {
        index = 3, label = 'Rides', none = 'Sans rides', esx = 'age',
        styles = { [0] = 'Pattes d\'oie', 'Premiers signes', 'Âge mûr', 'Rides d\'inquiétude', 'Fatigue', 'Distingué', 'Âgé',
            'Buriné', 'Ridé', 'Affaissé', 'Vie difficile', 'Vintage', 'Retraité', 'Usé', 'Très âgé' },
    },
    complexion = {
        index = 6, label = 'Teint', none = 'Teint uniforme', esx = 'complexion',
        styles = { [0] = 'Joues rosées', 'Irritation de rasage', 'Bouffée de chaleur', 'Coup de soleil', 'Contusions',
            'Alcoolique', 'Irrégulier', 'Totem', 'Vaisseaux apparents', 'Abîmé', 'Pâle', 'Fantomatique' },
    },
    sundamage = {
        index = 7, label = 'Dommages solaires', none = 'Aucun', esx = 'sun',
        styles = { [0] = 'Inégal', 'Papier de verre', 'Irrégulier', 'Rugueux', 'Tanné', 'Texturé', 'Grossier', 'Rude',
            'Plissé', 'Craquelé', 'Granuleux' },
    },
    moles = {
        index = 9, label = 'Grains de beauté', none = 'Aucun', esx = 'moles',
        styles = { [0] = 'Chérubin', 'Partout', 'Irréguliers', 'Points et tirets', 'Sur le nez', 'Poupée', 'Lutin',
            'Embrassé par le soleil', 'Grains de beauté', 'Alignés', 'Mannequin', 'Occasionnels', 'Mouchetés',
            'Gouttes de pluie', 'Double', 'D\'un seul côté', 'Par paires', 'Excroissance' },
    },
    chest = {
        index = 10, label = 'Pilosité du torse', palette = 'hair', none = 'Torse lisse', esx = 'chest',
        styles = { [0] = 'Naturel', 'La bande', 'L\'arbre', 'Poilu', 'Hirsute', 'Singe', 'Singe soigné', 'Bikini',
            'Éclair', 'Éclair inversé', 'Cœur', 'Moustache de torse', 'Smiley', 'Tête de mort', 'Ligne du ventre',
            'Ligne et tétons', 'Bras poilus' },
    },
    bodyblemishes = {
        index = 11, label = 'Imperfections du corps', none = 'Peau nette', esx = 'bodyb',
        styles = {},
    },
}

-- ---------------------------------------------------------------------
--  ONGLETS DU SALON
--   service : nom du service (prix et services réglés dans l'éditeur)
--   cam     : 'head', 'face', 'eyes', 'lips' ou 'bust'
--   modes   : sous-onglets ; key = ce qui part au panier
--     <calque>             → style (ex : 'lipstick')
--     <calque>_color       → couleur
--     <calque>_highlight   → reflets / 2e couleur
--   female/male = false : onglet caché pour ce sexe
--     (Config.Barber.beardForFemale / chestForFemale peuvent forcer)
--   Retirer un onglet = supprimer son bloc. Changer l'ordre = déplacer le bloc.
-- ---------------------------------------------------------------------
BarberData.tabs = {
    { id = 'hair', icon = '✂️', label = 'Coupes', service = 'hair', cam = 'head',
      modes = { { key = 'hair', label = 'Coupe', cart = 'Coupe' } } },
    { id = 'color', icon = '🎨', label = 'Couleurs', service = 'hair_color', cam = 'head',
      modes = { { key = 'hair_color', label = 'Couleur', cart = 'Couleur des cheveux' },
                { key = 'hair_highlight', label = 'Reflets', cart = 'Reflets des cheveux' } } },
    { id = 'beard', icon = '🧔', label = 'Barbe', service = 'beard', cam = 'face', female = false,
      modes = { { key = 'beard', label = 'Taille', cart = 'Barbe' },
                { key = 'beard_color', label = 'Couleur', cart = 'Couleur de barbe' },
                { key = 'beard_highlight', label = 'Reflets', cart = 'Reflets de barbe' } } },
    { id = 'brows', icon = '〰️', label = 'Sourcils', service = 'brows', cam = 'face',
      modes = { { key = 'brows', label = 'Forme', cart = 'Sourcils' },
                { key = 'brows_color', label = 'Couleur', cart = 'Couleur des sourcils' } } },
    { id = 'eyes', icon = '👁️', label = 'Yeux', service = 'eyes', cam = 'eyes',
      modes = { { key = 'eyes', label = 'Lentilles', cart = 'Lentilles' } } },
    { id = 'makeup', icon = '💄', label = 'Maquillage', service = 'makeup', cam = 'eyes',
      modes = { { key = 'makeup', label = 'Style', cart = 'Maquillage des yeux' },
                { key = 'makeup_color', label = 'Couleur', cart = 'Couleur du maquillage' },
                { key = 'makeup_highlight', label = '2e couleur', cart = '2e couleur du maquillage' } } },
    { id = 'blush', icon = '🌸', label = 'Blush', service = 'makeup', cam = 'face',
      modes = { { key = 'blush', label = 'Style', cart = 'Blush' },
                { key = 'blush_color', label = 'Couleur', cart = 'Couleur du blush' } } },
    { id = 'lips', icon = '👄', label = 'Lèvres', service = 'makeup', cam = 'lips',
      modes = { { key = 'lipstick', label = 'Style', cart = 'Rouge à lèvres' },
                { key = 'lipstick_color', label = 'Couleur', cart = 'Couleur du rouge à lèvres' } } },
    { id = 'skin', icon = '🧴', label = 'Peau', service = 'skin', cam = 'face',
      modes = { { key = 'blemishes', label = 'Imperfections', cart = 'Imperfections' },
                { key = 'ageing', label = 'Rides', cart = 'Rides' },
                { key = 'complexion', label = 'Teint', cart = 'Teint' },
                { key = 'sundamage', label = 'Soleil', cart = 'Dommages solaires' },
                { key = 'moles', label = 'Grains de beauté', cart = 'Grains de beauté' } } },
    { id = 'body', icon = '💪', label = 'Corps', service = 'chest', cam = 'bust',
      modes = { { key = 'chest', label = 'Torse', cart = 'Pilosité du torse', female = false },
                { key = 'chest_color', label = 'Couleur', cart = 'Couleur du torse', female = false },
                { key = 'bodyblemishes', label = 'Imperfections', cart = 'Imperfections du corps' } } },
}

-- ---------------------------------------------------------------------
--  SERVICES (cases à cocher dans l'éditeur du PNJ)
-- ---------------------------------------------------------------------
BarberData.services = {
    { id = 'hair',       label = '✂️ Coupes' },
    { id = 'hair_color', label = '🎨 Couleur des cheveux' },
    { id = 'beard',      label = '🧔 Barbe' },
    { id = 'brows',      label = '〰️ Sourcils' },
    { id = 'eyes',       label = '👁️ Yeux' },
    { id = 'makeup',     label = '💄 Maquillage, blush, rouge à lèvres' },
    { id = 'skin',       label = '🧴 Soins de la peau' },
    { id = 'chest',      label = '💪 Corps' },
}

-- ---------------------------------------------------------------------
--  TOUTES LES CLÉS DU PANIER (calculées : ne rien toucher ici)
--  BarberData.keys[key] = { service, label, kind = 'hair'|'eyes'|'style'|'color', overlay }
-- ---------------------------------------------------------------------
BarberData.keys = {}
BarberData.keyOrder = {}
for _, tab in ipairs(BarberData.tabs) do
    for _, m in ipairs(tab.modes) do
        local kind, ov = 'color', nil
        if m.key == 'hair' then kind = 'hair'
        elseif m.key == 'eyes' then kind = 'eyes'
        elseif BarberData.overlays[m.key] then kind, ov = 'style', m.key
        else ov = m.key:match('^(.-)_color$') or m.key:match('^(.-)_highlight$') end
        if ov == 'hair' then ov = nil end
        BarberData.keys[m.key] = { service = tab.service, label = m.cart or m.label, kind = kind, overlay = ov }
        BarberData.keyOrder[#BarberData.keyOrder + 1] = m.key
    end
end
