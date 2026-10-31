-- =========================================================
--  BUILDER STUDIO - KITS DE CONSTRUCTION ET MATÉRIAUX
--
--  GTA V ne sait PAS créer de géométrie à la volée : tout ce qui apparaît
--  en jeu est un modèle (.ydr) existant. Les murs, sols, toits… sont donc
--  assemblés à partir de MODULES (morceaux de taille fixe) répétés.
--
--  Deux kits :
--   - « blocs » : props vanilla (blocs de course du DLC Stunt). Fonctionne
--     sans rien installer. Leurs dimensions sont MESURÉES en jeu
--     (GetModelDimensions). Couleur = teinte du prop (SetObjectTextureVariation),
--     pas de vrais matériaux : on ne simule pas un béton ou une brique.
--   - « ubk » : kit architectural personnalisé (vrais matériaux texturés).
--     Les modèles sont générés par tools/kit_generator.js (OBJ + textures),
--     convertis en YDR/YTD/YBN avec Blender + Sollumz, puis streamés par la
--     ressource builder_studio_kit. Tant qu'ils ne sont pas installés, le jeu
--     les signale absents et le kit est grisé dans l'interface.
--  Ce fichier est copié tel quel dans chaque ressource exportée.
-- =========================================================
BKits = {}

-- Matériaux du kit personnalisé. kind = opaque | glass.
-- alpha : la transparence (SetEntityAlpha) est proposée seulement pour le verre,
-- c'est la seule où le rendu GTA reste correct.
-- Répétition / échelle / orientation de texture : appliquées à la GÉNÉRATION
-- des modèles (UV du kit_generator), pas en jeu (le moteur ne le permet pas).
-- Réflexion : définie par le shader choisi dans Sollumz (spec / glass), pas en jeu.
BKits.materials = {
    { id = 'beton',        label = 'Béton',             kind = 'opaque', color = '#a3a29d' },
    { id = 'beton_brut',   label = 'Béton brut',        kind = 'opaque', color = '#8b8a84' },
    { id = 'beton_cire',   label = 'Béton ciré',        kind = 'opaque', color = '#bdbab2' },
    { id = 'brique',       label = 'Brique',            kind = 'opaque', color = '#9c4a33' },
    { id = 'pierre',       label = 'Pierre',            kind = 'opaque', color = '#b5a68a' },
    { id = 'bois',         label = 'Bois',              kind = 'opaque', color = '#8a5a32' },
    { id = 'metal',        label = 'Métal',             kind = 'opaque', color = '#7c8288' },
    { id = 'acier',        label = 'Acier',             kind = 'opaque', color = '#5d646b' },
    { id = 'aluminium',    label = 'Aluminium',         kind = 'opaque', color = '#c9cdd1' },
    { id = 'verre_clair',  label = 'Verre transparent', kind = 'glass',  color = '#bfe3f2' },
    { id = 'verre_teinte', label = 'Verre teinté',      kind = 'glass',  color = '#3c5a66' },
    { id = 'verre_opaque', label = 'Verre opaque',      kind = 'glass',  color = '#dfe8ea' },
    { id = 'carrelage',    label = 'Carrelage',         kind = 'opaque', color = '#e4e0d6' },
    { id = 'marbre',       label = 'Marbre',            kind = 'opaque', color = '#efede8' },
    { id = 'platre',       label = 'Plâtre',            kind = 'opaque', color = '#f2efe6' },
    { id = 'asphalte',     label = 'Asphalte',          kind = 'opaque', color = '#3a3b3d' },
    -- Terrains (îles, plages, collines)
    { id = 'sable',        label = 'Sable',             kind = 'opaque', color = '#d9c38f' },
    { id = 'herbe',        label = 'Herbe',             kind = 'opaque', color = '#5d7f3a' },
    { id = 'terre',        label = 'Terre',             kind = 'opaque', color = '#6e5137' },
    { id = 'roche',        label = 'Roche',             kind = 'opaque', color = '#77736b' },
}

BKits.materialById = {}
for _, m in ipairs(BKits.materials) do BKits.materialById[m.id] = m end

-- Modules du kit personnalisé : dimensions EXACTES (mètres), origine au centre
-- de la face du bas. x = longueur, y = épaisseur / profondeur, z = hauteur.
-- Les mêmes valeurs sont utilisées par tools/kit_generator.js.
BKits.ubkModules = {
    wall = {
        { s = 'w4',   x = 4.0, y = 0.2, z = 1.0 },
        { s = 'w2',   x = 2.0, y = 0.2, z = 1.0 },
        { s = 'w1',   x = 1.0, y = 0.2, z = 1.0 },
        { s = 'w05',  x = 0.5, y = 0.2, z = 1.0 },
        { s = 'w4h',  x = 4.0, y = 0.2, z = 0.5 },
        { s = 'w2h',  x = 2.0, y = 0.2, z = 0.5 },
        { s = 'w1h',  x = 1.0, y = 0.2, z = 0.5 },
        { s = 'w05h', x = 0.5, y = 0.2, z = 0.5 },
    },
    floor = {
        { s = 'f4', x = 4.0, y = 4.0, z = 0.2 },
        { s = 'f2', x = 2.0, y = 2.0, z = 0.2 },
        { s = 'f1', x = 1.0, y = 1.0, z = 0.2 },
        { s = 'f05', x = 0.5, y = 0.5, z = 0.2 },
    },
    column  = { { s = 'col',  x = 0.4,  y = 0.4,  z = 1.0 }, { s = 'colh', x = 0.4, y = 0.4, z = 0.5 } },
    pillar  = { { s = 'pil',  x = 0.8,  y = 0.8,  z = 1.0 }, { s = 'pilh', x = 0.8, y = 0.8, z = 0.5 } },
    step    = { { s = 'step', x = 1.0,  y = 0.3,  z = 0.18 } },
    trim    = { { s = 'trim', x = 0.5,  y = 0.08, z = 0.08 } },
    door    = { { s = 'door', x = 1.0,  y = 0.05, z = 2.0 } },
    shutter = { { s = 'shut', x = 0.5,  y = 0.04, z = 1.0 } },
}
-- Le verre est fin : même découpe, épaisseur différente
BKits.glassThickness = 0.03
-- Modules non générés pour le verre (une colonne en verre n'a pas de sens)
BKits.glassModules = { wall = true, floor = true, door = true }

BKits.kits = {
    ubk = {
        id = 'ubk',
        label = 'Kit architectural (assets personnalisés)',
        custom = true,
        prefix = 'ubk_',
        defaultMaterial = 'beton',
        resource = 'builder_studio_kit',
    },
    blocs = {
        id = 'blocs',
        label = 'Blocs vanilla (teintables, sans installation)',
        custom = false,
        defaultMaterial = 't0',
        tints = 16,
        -- Modèles candidats par module : le générateur prend ceux qui existent
        -- et utilise leurs dimensions mesurées en jeu. Modifiable librement.
        modules = {
            wall    = { 'stt_prop_stunt_bblock_sml1', 'stt_prop_stunt_bblock_sml2', 'stt_prop_stunt_bblock_sml3' },
            floor   = { 'stt_prop_stunt_bblock_mdm1', 'stt_prop_stunt_bblock_sml1' },
            column  = { 'stt_prop_stunt_bblock_sml1' },
            pillar  = { 'stt_prop_stunt_bblock_sml2' },
            step    = { 'stt_prop_stunt_bblock_sml1' },
            trim    = { 'stt_prop_stunt_bblock_sml1' },
            -- Talus des terrains : gros blocs d'abord (4 fois moins d'objets qu'avec des blocs de 1 m)
            slope   = { 'stt_prop_stunt_bblock_mdm1', 'stt_prop_stunt_bblock_sml1' },
            door    = { 'prop_com_ls_door_01' },
            shutter = {},
        },
    },
}
BKits.order = { 'ubk', 'blocs' }

-- Liste des matériaux proposés par un kit
function BKits.materialsOf(kitId)
    local kit = BKits.kits[kitId]
    if not kit then return {} end
    if kit.custom then return BKits.materials end
    local out = {}
    for i = 0, (kit.tints or 1) - 1 do
        out[#out + 1] = { id = 't' .. i, label = ('Teinte %d'):format(i), kind = 'tint', tint = i }
    end
    return out
end

function BKits.validMaterial(kitId, matId)
    local kit = BKits.kits[kitId]
    if not kit or type(matId) ~= 'string' then return false end
    if kit.custom then return BKits.materialById[matId] ~= nil end
    local n = tonumber(matId:match('^t(%d+)$'))
    return n ~= nil and n >= 0 and n < (kit.tints or 1)
end

local function boxDims(x, y, z)
    return { min = { x = -x / 2, y = -y / 2, z = 0.0 }, max = { x = x / 2, y = y / 2, z = z } }
end

-- Modules disponibles : liste de { model, dims (ou nil si à mesurer), tint }
-- measured(model) -> dims mesurées en jeu (client) ou en cache (serveur)
function BKits.modules(kitId, moduleType, matId, measured)
    local kit = BKits.kits[kitId]
    local out = {}
    if not kit then return out end
    if kit.custom then
        local mat = BKits.materialById[matId] or BKits.materialById[kit.defaultMaterial]
        local glass = mat.kind == 'glass'
        if glass and not BKits.glassModules[moduleType] then
            mat = BKits.materialById.aluminium   -- montants / colonnes d'une verrière : alu
            glass = false
        end
        for _, m in ipairs(BKits.ubkModules[moduleType == 'slope' and 'wall' or moduleType] or {}) do
            local y = m.y
            if glass and (moduleType == 'wall' or moduleType == 'door') then y = BKits.glassThickness end
            if glass and moduleType == 'floor' then y = m.y end
            out[#out + 1] = {
                model = ('%s%s_%s'):format(kit.prefix, m.s, mat.id),
                dims = boxDims(m.x, y, m.z),
                glass = glass,
            }
        end
    else
        local tint = tonumber((matId or ''):match('^t(%d+)$')) or 0
        for _, model in ipairs((kit.modules or {})[moduleType] or {}) do
            local d = measured and measured(model) or nil
            if d then out[#out + 1] = { model = model, dims = d, tint = tint } end
        end
    end
    return out
end

-- Tous les modèles d'un kit (vérification en jeu : /mapping_kit)
function BKits.allModels(kitId)
    local kit, out, seen = BKits.kits[kitId], {}, {}
    if not kit then return out end
    local function add(m) if not seen[m] then seen[m] = true out[#out + 1] = m end end
    if kit.custom then
        for _, mat in ipairs(BKits.materials) do
            for t in pairs(BKits.ubkModules) do
                for _, m in ipairs(BKits.modules(kitId, t, mat.id)) do add(m.model) end
            end
        end
    else
        for _, list in pairs(kit.modules or {}) do for _, m in ipairs(list) do add(m) end end
    end
    table.sort(out)
    return out
end

return BKits
