-- =====================================================================
--  rp_animations : catalogue technique des 70 animations
--
--  Chaque fiche :
--    n        numéro dans le cahier des charges (1 à 70)
--    id       identifiant unique (utilisé par le réseau, les favoris, le calibrage)
--    label    nom affiché          desc  description affichée
--    cat      catégorie            type  'solo' | 'duo' | 'groupe'
--    source   'gta' (jeu de base) | 'rpemotes' (fichiers tiers streamés par rpemotes) | 'custom'
--    status   voir Catalog.Statuses
--    steps    étapes jouées dans l'ordre. Chaque étape :
--               A / B   { d = dictionnaire, c = clip }  (B seulement en duo)
--               off     position de B par rapport à A : x (droite), y (devant), z, h (cap relatif)
--               time    durée de l'étape en ms (nil = jusqu'à la fin du clip ou en boucle)
--    loop     la dernière étape tourne en boucle      cycle  les étapes recommencent au début
--    move     solo : le joueur peut marcher (haut du corps seulement)
--    adult    animation suggestive : acceptation explicite et option activée par chaque participant
--    fade     fondu au noir facultatif proposé (chaque participant le choisit pour lui seul)
--    roles    nom des rôles A et B affichés dans le menu
--    deps     ressources nécessaires          ref  d'où viennent les noms de clips
--    note     remarque technique (approximation, rendu à vérifier…)
--
--  Les offsets ne sont PAS validés en jeu : ce sont des estimations (convention rpemotes pour les
--  interactions GTA face à face, origine commune pour les clips enregistrés ensemble).
--  Ils se corrigent en jeu avec /rpanim_calib, sans modifier ce fichier.
-- =====================================================================
Catalog = {}

Catalog.Categories = {
    { id = 'romantiques', label = 'Danses romantiques',            icon = 'heart',    desc = 'Moments tendres à deux' },
    { id = 'slow',        label = 'Slow et danses de mariage',     icon = 'rings',    desc = 'Slows, valses, première danse' },
    { id = 'salsa',       label = 'Salsa et danses latines',       icon = 'flame',    desc = 'Salsa, merengue, kizomba' },
    { id = 'bachata',     label = 'Bachata et tango',              icon = 'rose',     desc = 'Bachata, tango' },
    { id = 'colle',       label = 'Collé-serré',                   icon = 'embrace',  desc = 'Danses rapprochées' },
    { id = 'solo',        label = 'Danses solo',                   icon = 'person',   desc = 'Seul sur la piste' },
    { id = 'soiree',      label = 'Danses de soirée',              icon = 'disco',    desc = 'Boîte de nuit et fête' },
    { id = 'seduction',   label = 'Séduction',                     icon = 'spark',    desc = 'Jeux de regard et de charme' },
    { id = 'adulte',      label = 'Animations adultes suggestives', icon = 'lock',    desc = 'Réservé aux adultes, consentement explicite', adult = true },
    { id = 'complement',  label = 'Animations complémentaires',    icon = 'plus',     desc = 'Invitations, étreintes, baisers, poses' },
}

Catalog.Statuses = {
    native_validee = 'Native validée',
    perso_testee   = 'Personnalisée produite et testée',
    a_valider      = 'À valider en jeu',
    a_creer        = 'À créer',
    bloquee        = 'Indisponible ou bloquée',
}
-- Statuts jouables (si les fichiers sont présents chez le joueur)
Catalog.Playable = { native_validee = true, perso_testee = true, a_valider = true }

Catalog.Sources = {
    gta      = 'GTA V (jeu de base)',
    rpemotes = 'rpemotes (fichiers tiers streamés)',
    custom   = 'Création rp_animations',
}

local function C(d, c) return { d = d, c = c } end
local SAME = { x = 0.0, y = 0.0,  z = 0.0, h = 0.0 }    -- clips enregistrés ensemble : même origine
local FACE = { x = 0.0, y = 1.05, z = 0.0, h = 180.0 }  -- face à face (valeur rpemotes pour mp_ped_interaction)

-- Clips réutilisés (noms repris de elyzea_animations/anim_data.lua, généré depuis rpemotes)
local HOLD1   = { C('mx_couple5_1_a', 'mx_couple5_1_a_clip'), C('mx_couple5_1_b', 'mx_couple5_1_b_clip') }
local HOLD2   = { C('mx_couple5_2_a', 'mx_couple5_2_a_clip'), C('mx_couple5_2_b', 'mx_couple5_2_b_clip') }
local HOLD3   = { C('mx_couple5_3_a', 'mx_couple5_3_a_clip'), C('mx_couple5_3_b', 'mx_couple5_3_b_clip') }
local WED1    = { C('EnchantedBrwny@wedding1a', 'wedding1a'), C('EnchantedBrwny@wedding1b', 'wedding1b') }
local WED2    = { C('EnchantedBrwny@wedding2b', 'wedding2b'), C('EnchantedBrwny@wedding2a', 'wedding2a') }
local AMN     = 'amnilka@photopose@couple@couplefirst'
local HUGPOSE = { C(AMN, 'amnilka_couple_mal_001'), C(AMN, 'amnilka_couple_fem_001') }
local PICPOSE = { C(AMN, 'amnilka_couple_mal_004'), C(AMN, 'amnilka_couple_fem_004') }
local HANDS   = { C(AMN, 'amnilka_couple_mal_005'), C(AMN, 'amnilka_couple_fem_005') }
local HUGR    = { C('misscarsteal2chad_goodbye', 'chad_armsaround_chad'), C('misscarsteal2chad_goodbye', 'chad_armsaround_girl') }
local CHEEKS  = { C('mp_ped_interaction', 'kisses_guy_a'), C('mp_ped_interaction', 'kisses_guy_b') }
local FRIEND  = { C('littlespoon@friendship007', 'friendship007'), C('littlespoon@friendship008', 'friendship008') }
local BFF     = { C('anim@male_couple_03_b', 'm_couple_03_b_clip'), C('anim@female_couple_03_b', 'f_couple_03_b_clip') }
local KISS    = { C('chocoholic@couple13', 'couple13_clip'), C('chocoholic@couple14', 'couple14_clip') }
local KNECK   = { C('genesismods_kissme@kissmale8', 'kissmale8'), C('genesismods_kissme@kissfemale8', 'kissfemale8') }
local KCHEEK  = { C('genesismods_kissme@kissmale9', 'kissmale9'), C('genesismods_kissme@kissfemale9', 'kissfemale9') }
local KFORE   = { C('genesismods_kissme@kissmale10', 'kissmale10'), C('genesismods_kissme@kissfemale10', 'kissfemale10') }
local LIFT    = { C('couplepose1pack1anim2@animation', 'couplepose1pack1anim2_clip'), C('couplepose1pack1anim1@animation', 'couplepose1pack1anim1_clip') }
local PAIRED  = 'anim@amb@nightclub@mini@dance@dance_paired@'
local CLUB_A  = { C(PAIRED .. 'dance_a@', 'ped_a_dance_idle'), C(PAIRED .. 'dance_a@', 'ped_b_dance_idle') }
local CLUB_B  = { C(PAIRED .. 'dance_b@', 'ped_a_dance_idle'), C(PAIRED .. 'dance_b@', 'ped_b_dance_idle') }
local CLUB_D  = { C(PAIRED .. 'dance_d@', 'ped_a_dance_idle'), C(PAIRED .. 'dance_d@', 'ped_b_dance_idle') }

local function duo(pair, off, time) return { A = pair[1], B = pair[2], off = off or SAME, time = time } end
local function solo(d, c, time) return { A = C(d, c), time = time } end

local RP  = { 'rpemotes' }
local REF_RP = 'rpemotes (via elyzea_animations/anim_data.lua)'
local REF_PAIRED = 'Dictionnaire GTA (rpemotes utilise ped_a_dance_idle) ; clip ped_b_dance_idle supposé, vérifié au chargement'

local function todo(n, id, label, cat, typ, desc, extra)
    local e = { n = n, id = id, label = label, cat = cat, type = typ, source = 'custom', status = 'a_creer', desc = desc,
        note = 'Aucun clip GTA V ni rpemotes ne reproduit ce mouvement : création personnalisée nécessaire (voir docs/ANIMATIONS_PERSONNALISEES.md).' }
    for k, v in pairs(extra or {}) do e[k] = v end
    return e
end

Catalog.List = {
    -- ── A. Slow et danses romantiques ────────────────────────────────────────
    { n = 1, id = 'slow_classique', label = 'Slow classique', cat = 'slow', type = 'duo', source = 'rpemotes', status = 'a_valider',
      desc = 'Le couple se tient et se balance doucement.', steps = { duo(HOLD1) }, loop = true, deps = RP, ref = REF_RP .. ' : holdme / holdmeb' },
    { n = 2, id = 'slow_rapproche', label = 'Slow rapproché', cat = 'slow', type = 'duo', source = 'rpemotes', status = 'a_valider',
      desc = 'Variante plus serrée du slow.', steps = { duo(HOLD2) }, loop = true, deps = RP, ref = REF_RP .. ' : holdmec / holdmed' },
    { n = 3, id = 'slow_elegant', label = 'Slow élégant', cat = 'slow', type = 'duo', source = 'rpemotes', status = 'a_valider',
      desc = 'Tenue de danse de cérémonie.', steps = { duo(WED1) }, loop = true, deps = RP, ref = REF_RP .. ' : couplewed1a / couplewed1b' },
    { n = 4, id = 'slow_balancement', label = 'Slow avec balancement', cat = 'slow', type = 'duo', source = 'rpemotes', status = 'a_valider',
      desc = 'Le couple enlacé se balance.', steps = { duo(HOLD3) }, loop = true, deps = RP, ref = REF_RP .. ' : holdmee / holdmef' },
    todo(5, 'slow_rotations', 'Slow avec rotations', 'slow', 'duo', 'Slow avec tours lents du couple.'),
    { n = 6, id = 'slow_rapprochement', label = 'Slow avec rapprochement progressif', cat = 'slow', type = 'duo', source = 'rpemotes', status = 'a_valider',
      desc = 'Mains dans les mains, puis enlacés, puis slow.', loop = true, deps = RP, ref = REF_RP,
      steps = { duo(HANDS, SAME, 8000), duo(HUGPOSE, SAME, 8000), duo(HOLD1) },
      note = 'Enchaînement de trois clips existants (fondu de 0,5 s entre chaque) : ce n\'est pas un mouvement continu.' },
    todo(7, 'romantique_mains', 'Danse romantique avec les mains', 'romantiques', 'duo', 'Danse en se tenant les mains, bras tendus.'),
    { n = 8, id = 'couple_enlace', label = 'Danse de couple enlacé', cat = 'romantiques', type = 'duo', source = 'gta', status = 'a_valider',
      desc = 'Les bras autour de l\'autre, longuement.', steps = { duo(HUGR) }, loop = true, ref = 'GTA V (mission Chad) : hugr / hugr2 de rpemotes' },
    { n = 9, id = 'romantique_positions', label = 'Danse romantique avec changement de position', cat = 'romantiques', type = 'duo', source = 'rpemotes', status = 'a_valider',
      desc = 'Trois tenues de slow qui s\'enchaînent en boucle.', loop = true, cycle = true, deps = RP, ref = REF_RP,
      steps = { duo(HOLD1, SAME, 10000), duo(HOLD2, SAME, 10000), duo(HOLD3, SAME, 10000) } },
    { n = 10, id = 'danse_mariage', label = 'Danse de mariage', cat = 'slow', type = 'duo', source = 'rpemotes', status = 'a_valider',
      desc = 'La première danse des mariés.', steps = { duo(WED2) }, loop = true, deps = RP, ref = REF_RP .. ' : couplewed2a / couplewed2b' },
    todo(11, 'valse_classique', 'Valse classique', 'slow', 'duo', 'Pas de valse à trois temps en tournant.'),
    todo(12, 'valse_mariage', 'Valse de mariage', 'slow', 'duo', 'Valse lente de cérémonie.'),
    todo(13, 'tango_elegant', 'Tango élégant', 'bachata', 'duo', 'Marche de tango, tenue fermée.'),
    todo(14, 'tango_romantique', 'Tango romantique', 'bachata', 'duo', 'Tango lent avec arrêts et regards.'),

    -- ── B. Danses latines ───────────────────────────────────────────────────
    todo(15, 'salsa_debutant', 'Salsa débutant', 'salsa', 'duo', 'Pas de base de salsa face à face.'),
    todo(16, 'salsa_dynamique', 'Salsa dynamique', 'salsa', 'duo', 'Salsa rapide.'),
    todo(17, 'salsa_rotations', 'Salsa avec rotations', 'salsa', 'duo', 'Salsa avec passes et tours.'),
    todo(18, 'salsa_guidage', 'Salsa avec guidage du partenaire', 'salsa', 'duo', 'Le guide fait tourner sa ou son partenaire.'),
    { n = 19, id = 'salsa_solo', label = 'Salsa solo', cat = 'salsa', type = 'solo', source = 'gta', status = 'a_valider',
      desc = 'Mouvement de bras salsa.', steps = { solo('anim@mp_player_intuppersalsa_roll', 'idle_a') }, loop = true, move = true,
      ref = 'GTA V : emote salsa de rpemotes',
      note = 'Approximation : animation du haut du corps seulement (on peut marcher en même temps).' },
    todo(20, 'bachata_classique', 'Bachata classique', 'bachata', 'duo', 'Pas de bachata, tenue fermée.'),
    todo(21, 'bachata_romantique', 'Bachata romantique', 'bachata', 'duo', 'Bachata lente et proche.'),
    todo(22, 'bachata_sensuelle', 'Bachata sensuelle', 'bachata', 'duo', 'Bachata sensuelle avec ondulations.'),
    todo(23, 'bachata_solo', 'Bachata solo', 'bachata', 'solo', 'Pas de bachata seul.'),
    todo(24, 'merengue', 'Merengue', 'salsa', 'duo', 'Pas de merengue sur place.'),
    todo(25, 'kizomba', 'Kizomba', 'salsa', 'duo', 'Kizomba lente et collée.'),
    todo(26, 'latine_festive', 'Danse latine festive', 'salsa', 'duo', 'Danse latine joyeuse face à face.'),

    -- ── C. Collé-serré et danses sensuelles ─────────────────────────────────
    { n = 27, id = 'colle_lent', label = 'Collé-serré lent', cat = 'colle', type = 'duo', source = 'rpemotes', status = 'a_valider',
      desc = 'Le couple serré l\'un contre l\'autre.', steps = { duo(BFF) }, loop = true, deps = RP, ref = REF_RP .. ' : bff / bffb',
      note = 'Rendu exact du clip non vu : à valider en jeu.' },
    todo(28, 'colle_rythme', 'Collé-serré rythmé', 'colle', 'duo', 'Collé-serré sur un rythme plus marqué.'),
    { n = 29, id = 'rapprochee_boite', label = 'Danse rapprochée de boîte de nuit', cat = 'soiree', type = 'duo', source = 'gta', status = 'a_valider',
      desc = 'Danse de club face à face, proches.', steps = { duo(CLUB_A) }, loop = true, ref = REF_PAIRED },
    todo(30, 'couple_sensuelle', 'Danse de couple sensuelle', 'colle', 'duo', 'Danse lente avec ondulations.'),
    todo(31, 'rotations_rapprochees', 'Danse avec rotations rapprochées', 'colle', 'duo', 'Tours lents en restant serrés.'),
    { n = 32, id = 'fin_de_soiree', label = 'Danse romantique de fin de soirée', cat = 'soiree', type = 'duo', source = 'gta', status = 'a_valider',
      desc = 'Une dernière danse puis on s\'enlace.', loop = true, ref = REF_PAIRED,
      steps = { duo(CLUB_B, SAME, 12000), duo(HUGR) } },
    todo(33, 'seduction_duo', 'Danse de séduction en duo', 'seduction', 'duo', 'Jeu de séduction dansé à deux.'),
    { n = 34, id = 'club_duo', label = 'Danse de club en duo', cat = 'soiree', type = 'duo', source = 'gta', status = 'a_valider',
      desc = 'Danse de boîte de nuit à deux.', steps = { duo(CLUB_D) }, loop = true, ref = REF_PAIRED },
    todo(35, 'lente_sensuelle', 'Danse lente et sensuelle', 'colle', 'duo', 'Danse très lente, corps proches.'),
    { n = 36, id = 'rapprochement_progressif', label = 'Danse avec rapprochement progressif', cat = 'colle', type = 'duo', source = 'rpemotes', status = 'a_valider',
      desc = 'On danse face à face, puis on se rapproche.', loop = true, deps = RP, ref = REF_PAIRED .. ' + ' .. REF_RP,
      steps = { duo(CLUB_A, SAME, 10000), duo(HOLD2) }, note = 'Enchaînement de deux clips existants.' },
    { n = 37, id = 'etreinte_consentie', label = 'Danse avec étreinte consentie', cat = 'colle', type = 'duo', source = 'rpemotes', status = 'a_valider',
      desc = 'Une étreinte affectueuse.', steps = { duo(FRIEND) }, loop = true, deps = RP, ref = REF_RP .. ' : hugtip / hugtip2' },

    -- ── D. Danses solo ──────────────────────────────────────────────────────
    { n = 38, id = 'solo_elegante_f', label = 'Danse féminine élégante', cat = 'solo', type = 'solo', source = 'gta', status = 'a_valider',
      desc = 'Style féminin, fonctionne sur tous les personnages.', loop = true, ref = 'GTA V : dancef de rpemotes',
      steps = { solo('anim@amb@nightclub@dancers@solomun_entourage@', 'mi_dance_facedj_17_v1_female^1') } },
    { n = 39, id = 'solo_elegante_m', label = 'Danse masculine élégante', cat = 'solo', type = 'solo', source = 'gta', status = 'a_valider',
      desc = 'Style masculin sobre, fonctionne sur tous les personnages.', loop = true, ref = 'GTA V : danceshy de rpemotes',
      steps = { solo('anim@amb@nightclub@mini@dance@dance_solo@male@var_a@', 'low_center') } },
    { n = 40, id = 'solo_latine', label = 'Danse latine solo', cat = 'solo', type = 'solo', source = 'gta', status = 'a_valider',
      desc = 'Déhanché aux accents orientaux et latins.', loop = true, ref = 'GTA V : danceglowstick3 de rpemotes (sans les bâtons)',
      steps = { solo('anim@amb@nightclub@lazlow@hi_railing@', 'ambclub_09_mi_hi_bellydancer_laz') }, note = 'Approximation : danse du ventre de club.' },
    { n = 41, id = 'solo_salsa', label = 'Danse salsa solo', cat = 'solo', type = 'solo', source = 'gta', status = 'a_valider',
      desc = 'Petits pas balancés.', loop = true, ref = 'GTA V : dance5 de rpemotes',
      steps = { solo('anim@amb@casino@mini@dance@dance_solo@female@var_a@', 'med_center') }, note = 'Approximation : pas de vrai pas de salsa dans GTA V.' },
    todo(42, 'solo_bachata', 'Danse bachata solo', 'solo', 'solo', 'Pas de bachata seul.'),
    { n = 43, id = 'solo_festive', label = 'Danse festive', cat = 'soiree', type = 'solo', source = 'gta', status = 'a_valider',
      desc = 'La danse « woogie », joyeuse.', loop = true, ref = 'GTA V : dancesilly9 de rpemotes',
      steps = { solo('anim@mp_player_intcelebrationfemale@the_woogie', 'the_woogie') } },
    { n = 44, id = 'solo_energique', label = 'Danse énergique de boîte de nuit', cat = 'soiree', type = 'solo', source = 'gta', status = 'a_valider',
      desc = 'Haute intensité, face au DJ.', loop = true, ref = 'GTA V : dancef4 de rpemotes',
      steps = { solo('anim@amb@nightclub@dancers@crowddance_facedj@hi_intensity', 'hi_dance_facedj_09_v2_female^1') } },
    { n = 45, id = 'solo_jambes', label = 'Danse avec jeu de jambes', cat = 'soiree', type = 'solo', source = 'gta', status = 'a_valider',
      desc = 'Shuffle, les pieds en avant.', loop = true, ref = 'GTA V : danceclubo de rpemotes',
      steps = { solo('anim@amb@nightclub@mini@dance@dance_solo@shuffle@', 'high_center') } },
    todo(46, 'solo_rotations', 'Danse avec rotations', 'soiree', 'solo', 'Danse solo avec pirouettes.'),
    { n = 47, id = 'solo_lente', label = 'Danse lente solo', cat = 'solo', type = 'solo', source = 'gta', status = 'a_valider',
      desc = 'Balancement doux.', loop = true, ref = 'GTA V : danceslow2 de rpemotes',
      steps = { solo('anim@amb@nightclub@mini@dance@dance_solo@female@var_a@', 'low_center') } },
    { n = 48, id = 'solo_seduction', label = 'Danse de séduction solo', cat = 'seduction', type = 'solo', source = 'gta', status = 'a_valider',
      desc = 'Danse de club lascive.', loop = true, ref = 'GTA V : danceclube de rpemotes',
      steps = { solo('anim@amb@nightclub_island@dancers@club@', 'hi_idle_a_f02') } },
    { n = 49, id = 'solo_sensuelle', label = 'Danse sensuelle solo', cat = 'seduction', type = 'solo', source = 'gta', status = 'a_valider', adult = true,
      desc = 'Danse de club très suggestive.', loop = true, ref = 'GTA V : danceglowstick de rpemotes (sans les bâtons)',
      steps = { solo('anim@amb@nightclub@lazlow@hi_railing@', 'ambclub_13_mi_hi_sexualgriding_laz') } },
    { n = 50, id = 'solo_celebration', label = 'Danse de célébration', cat = 'soiree', type = 'solo', source = 'gta', status = 'a_valider',
      desc = 'On fête une victoire.', loop = true, ref = 'GTA V : idle4 de rpemotes',
      steps = { solo('anim@mp_celebration@idles@female', 'celebration_idle_f_a') } },

    -- ── E. Animations romantiques complémentaires ───────────────────────────
    { n = 51, id = 'inviter_danser', label = 'Inviter à danser', cat = 'complement', type = 'solo', source = 'gta', status = 'a_valider',
      desc = 'Un geste doux de la main : « viens ».', loop = false, move = true,
      steps = { solo('gestures@m@standing@casual', 'gesture_come_here_soft') },
      ref = 'GTA V : dictionnaire présent dans rpemotes ; clip gesture_come_here_soft vérifié au chargement' },
    { n = 52, id = 'prendre_mains', label = 'Prendre les mains', cat = 'complement', type = 'duo', source = 'rpemotes', status = 'a_valider',
      desc = 'Se tenir les mains face à face.', steps = { duo(HANDS) }, loop = true, deps = RP, ref = REF_RP .. ' : couplehhands' },
    todo(53, 'faire_tourner', 'Faire tourner son partenaire', 'complement', 'duo', 'Le guide fait tourner sa ou son partenaire sous son bras.'),
    { n = 54, id = 'fin_etreinte', label = 'Terminer une danse par une étreinte', cat = 'complement', type = 'duo', source = 'gta', status = 'a_valider',
      desc = 'Quelques pas puis une étreinte.', loop = true, ref = REF_PAIRED, steps = { duo(CLUB_A, SAME, 10000), duo(HUGR) } },
    { n = 55, id = 'calin_apres', label = 'Câlin après la danse', cat = 'complement', type = 'duo', source = 'gta', status = 'a_valider',
      desc = 'Bise et accolade, quelques secondes.', loop = false, steps = { duo(CHEEKS, FACE) }, ref = 'GTA V : hug / hug2 de rpemotes' },
    { n = 56, id = 'baiser_romantique', label = 'Baiser romantique en duo', cat = 'complement', type = 'duo', source = 'rpemotes', status = 'a_valider',
      desc = 'Un baiser tendre.', steps = { duo(KISS) }, loop = true, deps = RP, ref = REF_RP .. ' : kisslips / kisslips2' },
    { n = 57, id = 'pose_photo', label = 'Pose romantique pour une photo', cat = 'complement', type = 'duo', source = 'rpemotes', status = 'a_valider',
      desc = 'Pose de couple pour la photo.', steps = { duo(PICPOSE) }, loop = true, deps = RP, ref = REF_RP .. ' : cutepicpose' },
    todo(58, 'fin_elegante', 'Fin de danse élégante', 'complement', 'duo', 'Révérence et salut de fin de danse.'),
    { n = 59, id = 'etreinte_prolongee', label = 'Étreinte prolongée', cat = 'complement', type = 'duo', source = 'rpemotes', status = 'a_valider',
      desc = 'Rester enlacés.', steps = { duo(HUGPOSE) }, loop = true, deps = RP, ref = REF_RP .. ' : hugpose' },
    { n = 60, id = 'rapprochement_visage', label = 'Rapprochement du visage', cat = 'complement', type = 'duo', source = 'rpemotes', status = 'a_valider',
      desc = 'Front contre front, baiser sur le front.', steps = { duo(KFORE) }, loop = true, deps = RP, ref = REF_RP .. ' : kisscutefh' },

    -- ── F. Animations adultes suggestives (non graphiques) ──────────────────
    todo(61, 'adulte_tres_rapprochee', 'Danse très rapprochée', 'adulte', 'duo', 'Danse corps contre corps.', { adult = true }),
    { n = 62, id = 'adulte_seduction_lente', label = 'Danse de séduction lente', cat = 'adulte', type = 'solo', source = 'gta', status = 'a_valider', adult = true,
      desc = 'Danse privée lente, debout.', loop = true, ref = 'GTA V : lapdance2 de rpemotes',
      steps = { solo('mini@strip_club@private_dance@idle', 'priv_dance_idle') } },
    { n = 63, id = 'adulte_etreinte', label = 'Étreinte sensuelle', cat = 'adulte', type = 'duo', source = 'rpemotes', status = 'a_valider', adult = true,
      desc = 'Baiser dans le cou.', steps = { duo(KNECK) }, loop = true, deps = RP, ref = REF_RP .. ' : kisscuteneck' },
    todo(64, 'adulte_couple_intime', 'Danse de couple intime', 'adulte', 'duo', 'Danse lente et intime.', { adult = true }),
    { n = 65, id = 'adulte_rapprochement', label = 'Rapprochement romantique', cat = 'adulte', type = 'duo', source = 'rpemotes', status = 'a_valider', adult = true,
      desc = 'Bisou sur la joue, puis baiser.', loop = true, deps = RP, ref = REF_RP, steps = { duo(KCHEEK, SAME, 8000), duo(KISS) } },
    { n = 66, id = 'adulte_pose_duo', label = 'Pose sensuelle en duo', cat = 'adulte', type = 'duo', source = 'rpemotes', status = 'a_valider', adult = true,
      desc = 'L\'un soulève l\'autre.', steps = { duo(LIFT) }, loop = true, deps = RP, ref = REF_RP .. ' : liftme / liftme2',
      note = 'Rendu exact du clip non vu : à valider en jeu.' },
    todo(67, 'adulte_interaction', 'Interaction de couple suggestive', 'adulte', 'duo', 'Jeu de couple suggestif, habillé.', { adult = true }),
    { n = 68, id = 'adulte_scene_privee', label = 'Transition vers une scène privée', cat = 'adulte', type = 'duo', source = 'rpemotes', status = 'a_valider', adult = true, fade = true,
      desc = 'Étreinte puis baiser ; fondu au noir facultatif, choisi par chacun pour soi.', loop = true, deps = RP, ref = 'GTA V + ' .. REF_RP,
      steps = { duo(HUGR, SAME, 8000), duo(KISS) } },
    { n = 69, id = 'adulte_seduction_poses', label = 'Séduction avec changement de pose', cat = 'adulte', type = 'solo', source = 'rpemotes', status = 'a_valider', adult = true,
      desc = 'Trois poses qui s\'enchaînent.', loop = true, cycle = true, deps = RP, ref = REF_RP .. ' : sexypose 1 à 3',
      steps = { solo('littlespoon@sexy003', 'sexy003', 6000), solo('littlespoon@sexy004', 'sexy004', 6000), solo('littlespoon@sexy005', 'sexy005', 6000) } },
    { n = 70, id = 'adulte_boite', label = 'Danse suggestive de boîte de nuit', cat = 'adulte', type = 'solo', source = 'gta', status = 'a_valider', adult = true,
      desc = 'Danse de club provocante.', loop = true, ref = 'GTA V : danceglowstick2 de rpemotes (sans les bâtons)',
      steps = { solo('anim@amb@nightclub@lazlow@hi_railing@', 'ambclub_12_mi_hi_bootyshake_laz') } },
}

-- Index et valeurs par défaut
Catalog.ById = {}
for _, e in ipairs(Catalog.List) do
    e.roles = e.roles or (e.type == 'duo' and { A = 'Guide', B = 'Partenaire' } or nil)
    e.steps = e.steps or {}
    Catalog.ById[e.id] = e
end

function Catalog.Get(id)
    return type(id) == 'string' and Catalog.ById[id] or nil
end

-- Animations validées en jeu par le staff (/rpanim_valider), tenu à jour par server/main.lua et client/session.lua
Catalog.Validated = {}

-- Jouable d'après le catalogue (les fichiers sont vérifiés à part, côté client)
function Catalog.IsPlayable(e)
    if not e or not Catalog.Playable[e.status] or #e.steps == 0 then return false end
    if e.status == 'a_valider' and not Config.ShowUnvalidated and not Catalog.Validated[e.id] then return false end
    if e.adult and not Config.Adult.Enabled then return false end
    return true
end
