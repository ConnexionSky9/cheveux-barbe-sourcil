-- =====================================================================
--  Elyzea animations : catalogue des danses lentes, en duo et en groupe
--
--  Fiche :
--    id, label, desc, cat ('lentes' | 'duo' | 'groupe'), type ('duo' | 'groupe')
--    source  'gta' (jeu de base) | 'rpemotes' (fichiers diffusés par rpemotes)
--    status  'a_valider' | 'validee' | 'bloquee'   (voir DanseCatalog.Statuses)
--    steps   étapes jouées dans l'ordre :
--              A   clip du meneur (rôle A, reste sur place)        { d = dictionnaire, c = clip }
--              B   clip du partenaire (duo, attaché au meneur)
--              off position de B par rapport à A : x, y, z, h (rotation), bone (os du meneur, -1 = racine)
--              time durée de l'étape en ms (nil = boucle ou fin du clip)
--    loop    la dernière étape tourne en boucle      turn  rotation lente du couple (degrés / seconde)
--    formations (groupe) : formations proposées, la première est celle par défaut
--
--  Positions des duos : valeurs officielles de rpemotes (client/AnimationList.lua de rpemotes-reborn,
--  options Attachto / SyncOffset de chaque animation partagée), reprises telles quelles.
--  Le rendu en jeu reste à valider : /danse_valider <id> une fois vérifiée, /danse_calib pour corriger.
-- =====================================================================
DanseCatalog = {}

DanseCatalog.Categories = {
    { id = 'lentes', label = 'Danses lentes',    icon = 'heart', desc = 'Slows et moments romantiques à deux, face à face.' },
    { id = 'duo',    label = 'Danses en duo',    icon = 'users', desc = 'Danses et portés à deux : choisis ton ou ta partenaire.' },
    { id = 'groupe', label = 'Danses en groupe', icon = 'party-popper', desc = 'Invite plusieurs joueurs : tout le monde démarre ensemble.' },
}

DanseCatalog.Statuses = {
    a_valider = 'À valider en jeu',
    validee   = 'Validée en jeu',
    bloquee   = 'Indisponible',
}

local function C(d, c) return { d = d, c = c } end

-- Attache façon rpemotes « Attachto » : B est attaché au meneur (os 0) avec cette position / rotation
local function attach(x, y, z, h) return { x = x, y = y, z = z, h = h, bone = 0 } end
-- Placement façon rpemotes « SyncOffset » : B devant le meneur (côté, avant, hauteur), tourné vers lui
local function sync(side, front, height) return { x = side or 0.0, y = front or 1.0, z = height or 0.0, h = 180.0, bone = -1 } end

local AMN = 'amnilka@photopose@couple@couplefirst'
local PAIRED = 'anim@amb@nightclub@mini@dance@dance_paired@'
local REF = 'rpemotes-reborn, client/AnimationList.lua, RP.Shared : '

-- Duo : { A, B } (B est le joueur attaché / placé)
local HOLD_FACE = { C('mx_couple5_2_a', 'mx_couple5_2_a_clip'), C('mx_couple5_2_b', 'mx_couple5_2_b_clip') }
local HOLD_BACK = { C('mx_couple5_1_a', 'mx_couple5_1_a_clip'), C('mx_couple5_1_b', 'mx_couple5_1_b_clip') }
local HUGR      = { C('misscarsteal2chad_goodbye', 'chad_armsaround_girl'), C('misscarsteal2chad_goodbye', 'chad_armsaround_chad') }
local WED2      = { C('EnchantedBrwny@wedding2b', 'wedding2b'), C('EnchantedBrwny@wedding2a', 'wedding2a') }
local WED1      = { C('EnchantedBrwny@wedding1a', 'wedding1a'), C('EnchantedBrwny@wedding1b', 'wedding1b') }
local KISS      = { C('chocoholic@couple14', 'couple14_clip'), C('chocoholic@couple13', 'couple13_clip') }
local LIFT1     = { C('couplepose1pack1anim2@animation', 'couplepose1pack1anim2_clip'), C('couplepose1pack1anim1@animation', 'couplepose1pack1anim1_clip') }
local LIFT2     = { C('couplepose2pack1anim2@animation', 'couplepose2pack1anim2_clip'), C('couplepose2pack1anim1@animation', 'couplepose2pack1anim1_clip') }

local OFF_HOLD_FACE = attach(-0.12, 0.36, -0.01, -180.0)   -- holdmed
local OFF_KISS      = attach(0.16, 0.27, 0.0, 130.0)       -- kisslips

local function step(pair, off, time) return { A = pair[1], B = pair[2], off = off, time = time } end
local function gstep(d, c) return { A = C(d, c) } end

DanseCatalog.List = {
    -- ── Danses lentes ────────────────────────────────────────────────────────
    { id = 'slow_face', label = 'Slow face à face', cat = 'lentes', type = 'duo', source = 'rpemotes', status = 'a_valider',
      desc = 'Enlacés face à face, on se tient l\'un contre l\'autre.', loop = true,
      steps = { step(HOLD_FACE, OFF_HOLD_FACE) }, ref = REF .. 'holdmec / holdmed (pos -0.12, 0.36, -0.01 ; rot -180)' },
    { id = 'slow_tournant', label = 'Slow tournant', cat = 'lentes', type = 'duo', source = 'rpemotes', status = 'a_valider',
      desc = 'Le même slow face à face, et le couple tourne lentement sur lui-même.', loop = true, turn = 7.0,
      steps = { step(HOLD_FACE, OFF_HOLD_FACE) }, ref = REF .. 'holdmec / holdmed',
      note = 'La rotation est faite par le script (le meneur tourne, le partenaire suit) : environ un tour en 50 secondes.' },
    { id = 'etreinte_romantique', label = 'Étreinte romantique', cat = 'lentes', type = 'duo', source = 'gta', status = 'a_valider',
      desc = 'Les bras autour de l\'autre, face à face (animation du jeu).', loop = true,
      steps = { step(HUGR, sync(-0.05, 0.52)) }, ref = REF .. 'hugr / hugr2 (SyncOffsetSide -0.05, SyncOffsetFront 0.52)' },
    { id = 'slow_maries', label = 'Danse des mariés', cat = 'lentes', type = 'duo', source = 'rpemotes', status = 'a_valider',
      desc = 'La première danse des mariés.', loop = true,
      steps = { step(WED2, attach(0.01, 0.25, 0.0, -88.9)) }, ref = REF .. 'couplewed2a / couplewed2b (pos 0.01, 0.25, 0 ; rot -88.9)' },
    { id = 'pose_maries', label = 'Pose des mariés', cat = 'lentes', type = 'duo', source = 'rpemotes', status = 'a_valider',
      desc = 'Pose de cérémonie, main dans la main.', loop = true,
      steps = { step(WED1, attach(0.03, 1.0, 0.02, 130.0)) }, ref = REF .. 'couplewed1a / couplewed1b (pos 0.03, 1.0, 0.02 ; rot 130)' },
    { id = 'enlaces_dos', label = 'Enlacés par derrière', cat = 'lentes', type = 'duo', source = 'rpemotes', status = 'a_valider',
      desc = 'L\'un enlace l\'autre par derrière : les deux regardent dans la même direction.', loop = true,
      steps = { step(HOLD_BACK, attach(-0.02, 0.24, -0.01, 0.0)) }, ref = REF .. 'holdme / holdmeb (pos -0.02, 0.24, -0.01 ; rot 0)' },
    { id = 'baiser_slow', label = 'Baiser', cat = 'lentes', type = 'duo', source = 'rpemotes', status = 'a_valider',
      desc = 'Un baiser tendre, face à face.', loop = true,
      steps = { step(KISS, OFF_KISS) }, ref = REF .. 'kisslips / kisslips2 (pos 0.16, 0.27, 0 ; rot 130)' },
    { id = 'slow_puis_baiser', label = 'Slow puis baiser', cat = 'lentes', type = 'duo', source = 'rpemotes', status = 'a_valider',
      desc = 'Vingt secondes de slow face à face, puis un baiser.', loop = true,
      steps = { step(HOLD_FACE, OFF_HOLD_FACE, 20000), step(KISS, OFF_KISS) }, ref = REF .. 'holdmec / holdmed puis kisslips',
      note = 'Enchaînement de deux animations existantes (fondu entre les deux), pas un mouvement continu.' },

    -- ── Danses en duo ────────────────────────────────────────────────────────
    { id = 'duo_club', label = 'Danse de club face à face', cat = 'duo', type = 'duo', source = 'gta', status = 'a_valider',
      desc = 'Chacun danse face à l\'autre, styles assortis, départ ensemble.', loop = true,
      steps = { step({ C('anim@amb@nightclub@mini@dance@dance_solo@male@var_a@', 'high_center'),
                       C('anim@amb@nightclub@mini@dance@dance_solo@female@var_a@', 'high_center') }, sync(0.0, 1.0)) },
      ref = 'GTA V : clips dance3 et dancef2 de rpemotes',
      note = 'Deux danses individuelles face à face, synchronisées au départ : ce n\'est pas une chorégraphie avec contacts.' },
    { id = 'duo_paire', label = 'Danse en paire (boîte de nuit)', cat = 'duo', type = 'duo', source = 'gta', status = 'a_valider',
      desc = 'La danse « en paire » des boîtes de nuit du jeu.', loop = true,
      steps = { step({ C(PAIRED .. 'dance_a@', 'ped_a_dance_idle'), C(PAIRED .. 'dance_a@', 'ped_b_dance_idle') }, attach(0.0, 0.0, 0.0, 0.0)) },
      ref = 'GTA V : dictionnaire dance_paired@dance_a@ (clip ped_a_dance_idle utilisé par rpemotes)',
      note = 'Le clip ped_b_dance_idle n\'est pas listé par rpemotes : s\'il n\'existe pas, cette danse est masquée automatiquement.' },
    { id = 'porte', label = 'Le porté', cat = 'duo', type = 'duo', source = 'rpemotes', status = 'a_valider',
      desc = 'L\'un soulève l\'autre face à lui (pose tenue).', loop = true,
      steps = { step(LIFT1, attach(0.002, 0.287, 0.25, 180.0)) }, ref = REF .. 'liftme / liftme2 (pos 0.002, 0.287, 0.25 ; rot 180)',
      note = 'Pose tenue, pas le mouvement de porté dynamique de la vidéo « Dirty Dancing » (il faudrait une animation personnalisée).' },
    { id = 'grand_porte', label = 'Le grand porté', cat = 'duo', type = 'duo', source = 'rpemotes', status = 'a_valider',
      desc = 'Porté plus haut, bras tendus (pose tenue).', loop = true,
      steps = { step(LIFT2, attach(0.01, 0.48, 0.53, 180.0)) }, ref = REF .. 'liftme3 / liftme4 (pos 0.01, 0.48, 0.53 ; rot 180)' },


    -- ── Danses en groupe (tout le monde fait le même mouvement, départ synchronisé) ──
    { id = 'groupe_thriller', label = 'Thriller', cat = 'groupe', type = 'groupe', source = 'rpemotes', status = 'a_valider',
      desc = 'La chorégraphie de Thriller, tout le monde en même temps.', loop = true, formations = { 'ligne', 'cercle' },
      steps = { gstep('mj_thriller', 'mj_thriller_dance') }, ref = 'rpemotes : dancethriller' },
    { id = 'groupe_club', label = 'Soirée club', cat = 'groupe', type = 'groupe', source = 'gta', status = 'a_valider',
      desc = 'Danse de boîte énergique, face au meneur ou en cercle.', loop = true, formations = { 'cercle', 'ligne' },
      steps = { gstep('anim@amb@nightclub@dancers@crowddance_facedj@hi_intensity', 'hi_dance_facedj_09_v2_female^1') }, ref = 'GTA V : dancef4 de rpemotes' },
    { id = 'groupe_shuffle', label = 'Shuffle', cat = 'groupe', type = 'groupe', source = 'gta', status = 'a_valider',
      desc = 'Le shuffle, pieds en avant, tous en ligne.', loop = true, formations = { 'ligne', 'cercle' },
      steps = { gstep('anim@amb@nightclub@mini@dance@dance_solo@shuffle@', 'high_center') }, ref = 'GTA V : danceclubo de rpemotes' },
    { id = 'groupe_robot', label = 'Robot', cat = 'groupe', type = 'groupe', source = 'rpemotes', status = 'a_valider',
      desc = 'Danse robot synchronisée.', loop = true, formations = { 'ligne', 'cercle' },
      steps = { gstep('dancing_wave_part_one@anim', 'robot_dance') }, ref = 'rpemotes : dancewave10' },
    { id = 'groupe_salsa', label = 'Pas balancés (ligne)', cat = 'groupe', type = 'groupe', source = 'gta', status = 'a_valider',
      desc = 'Petits pas balancés façon danse en ligne.', loop = true, formations = { 'ligne', 'cercle' },
      steps = { gstep('anim@amb@casino@mini@dance@dance_solo@female@var_a@', 'med_center') }, ref = 'GTA V : dance5 de rpemotes',
      note = 'Pas une vraie salsa (aucun pas de salsa dans GTA V) : un balancement proche.' },
    { id = 'groupe_woogie', label = 'Woogie', cat = 'groupe', type = 'groupe', source = 'gta', status = 'a_valider',
      desc = 'La danse « woogie », joyeuse.', loop = true, formations = { 'cercle', 'ligne' },
      steps = { gstep('anim@mp_player_intcelebrationfemale@the_woogie', 'the_woogie') }, ref = 'GTA V : dancesilly9 de rpemotes' },
}

DanseCatalog.ById = {}
for _, e in ipairs(DanseCatalog.List) do DanseCatalog.ById[e.id] = e end

-- Validées en jeu par le staff (/danse_valider), tenu à jour par le serveur
DanseCatalog.Validated = {}

function DanseCatalog.Get(id) return type(id) == 'string' and DanseCatalog.ById[id] or nil end

function DanseCatalog.IsPlayable(e)
    return e ~= nil and e.status ~= 'bloquee' and #e.steps > 0
end

-- Position d'un membre de groupe par rapport au meneur (slot 0 = meneur)
-- Renvoie x (droite), y (devant), h (rotation par rapport au meneur)
function DanseCatalog.Slot(formation, slot, total)
    local g = DanseConfig.Group
    if slot == 0 then return 0.0, 0.0, 0.0 end
    if formation == 'cercle' then
        local r = g.CircleRadius
        local a = math.rad(360.0 * slot / total)
        -- sur un cercle devant le meneur, chacun tourné vers le centre
        return r * math.sin(a), r - r * math.cos(a), 360.0 * slot / total
    end
    -- ligne : alternativement à droite et à gauche du meneur, même direction
    local side = (slot % 2 == 1) and 1.0 or -1.0
    return side * math.ceil(slot / 2) * g.Spacing, 0.0, 0.0
end
