-- =========================================================
--  BUILDER STUDIO - VALIDATION DES DONNÉES (partagé)
--  Tout ce qui vient d'un client passe par BSchema.element() côté serveur :
--  champs connus seulement, nombres finis et bornés, textes courts.
-- =========================================================
BSchema = {}
BSchema.VERSION = 1

local WORLD = 20000.0

local function finite(v) return type(v) == 'number' and v == v and v ~= math.huge and v ~= -math.huge end

local function numIn(v, lo, hi, def)
    if not finite(v) then return def end
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

local function vec(v, lo, hi, def)
    if type(v) ~= 'table' then return def and { x = def, y = def, z = def } or nil end
    return { x = numIn(v.x, lo, hi, def or 0.0), y = numIn(v.y, lo, hi, def or 0.0), z = numIn(v.z, lo, hi, def or 0.0) }
end

function BSchema.id(v)
    return type(v) == 'string' and #v >= 1 and #v <= 40 and v:match('^[%w_%-]+$') ~= nil
end

function BSchema.model(v)
    return type(v) == 'string' and #v >= 1 and #v <= 64 and v:match('^[%w_%-]+$') ~= nil
end

function BSchema.text(v, maxLen)
    if type(v) ~= 'string' then return nil end
    v = v:gsub('[%c<>]', ''):sub(1, maxLen or 64)
    return v
end

-- Copie bornée d'un tableau de paramètres libres
local function cleanParams(v, depth, budget)
    if depth > 5 then return nil end
    local t = type(v)
    if t == 'number' then return finite(v) and numIn(v, -WORLD, WORLD, 0) or nil end
    if t == 'boolean' then return v end
    if t == 'string' then return BSchema.text(v, 64) end
    if t ~= 'table' then return nil end
    local out = {}
    local n = 0
    for k, val in pairs(v) do
        budget.n = budget.n - 1
        if budget.n < 0 then break end
        n = n + 1
        if n > 20000 then break end
        local kt = type(k)
        if (kt == 'string' and #k <= 32 and k:match('^[%w_]+$')) or (kt == 'number' and k >= 1 and k <= 20000 and k % 1 == 0) then
            local c = cleanParams(val, depth + 1, budget)
            if c ~= nil then out[k] = c end
        end
    end
    return out
end

-- Renvoie un élément propre ou nil, raison
function BSchema.element(raw, opts)
    opts = opts or {}
    if type(raw) ~= 'table' then return nil, 'élément invalide' end
    if not BSchema.id(raw.id) then return nil, 'identifiant invalide' end
    if not BGeo.TYPES[raw.type] then return nil, 'type inconnu : ' .. tostring(raw.type) end
    local el = {
        id = raw.id,
        type = raw.type,
        name = BSchema.text(raw.name, 64) or BGeo.TYPES[raw.type].label,
        parent = BSchema.id(raw.parent) and raw.parent or nil,
        pos = vec(raw.pos, -WORLD, WORLD, 0.0),
        rot = vec(raw.rot, -720, 720, 0.0),
        locked = raw.locked == true or nil,
        hidden = raw.hidden == true or nil,
        level = math.floor(numIn(raw.level, -50, 500, 0)),
    }
    if raw.type ~= 'prop' and raw.type ~= 'group' and raw.type ~= 'light' and raw.type ~= 'scatter' then
        el.kit = BKits.kits[raw.kit] and raw.kit or 'ubk'
        el.mat = BKits.validMaterial(el.kit, raw.mat) and raw.mat or BKits.kits[el.kit].defaultMaterial
    end
    if raw.type == 'prop' then
        if not BSchema.model(raw.model) then return nil, 'modèle invalide' end
        el.model = raw.model
        el.vehicle = raw.vehicle == true or nil
        el.dynamic = raw.dynamic == true or nil
        if raw.scale then el.scale = vec(raw.scale, 0.05, 20.0, 1.0) end
    end
    if raw.tint ~= nil then el.tint = math.floor(numIn(raw.tint, 0, 15, 0)) end
    if raw.alpha ~= nil then el.alpha = math.floor(numIn(raw.alpha, 0, 255, 255)) end
    local budget = { n = opts.paramBudget or 40000 }
    el.params = cleanParams(raw.params or {}, 0, budget) or {}
    if budget.n < 0 then return nil, 'paramètres trop volumineux' end
    -- Modèles cités dans les paramètres (dispersion, luminaire) : noms valides seulement
    if el.params.models then
        local ok = {}
        for _, m in ipairs(el.params.models) do if BSchema.model(m) then ok[#ok + 1] = m end end
        el.params.models = ok
    end
    if el.params.fixture ~= nil and not BSchema.model(el.params.fixture) then el.params.fixture = nil end
    return el
end

-- Projet vide
function BSchema.newProject(id, name, owner, origin)
    return {
        id = id,
        schema = BSchema.VERSION,
        name = BSchema.text(name, 48) or 'Projet',
        owner = owner,
        created = os.time(),
        updated = os.time(),
        active = false,
        origin = origin and vec(origin, -WORLD, WORLD, 0.0) or { x = 0.0, y = 0.0, z = 0.0 },
        elements = {},
        textures = {},
        history = {},
        meta = {},
    }
end

-- Mise à niveau des anciens fichiers (compatibilité ascendante)
function BSchema.upgrade(p)
    if type(p) ~= 'table' then return nil end
    p.schema = p.schema or 1
    p.elements = p.elements or {}
    p.textures = p.textures or {}
    p.history = p.history or {}
    p.meta = p.meta or {}
    p.origin = p.origin or { x = 0.0, y = 0.0, z = 0.0 }
    return p
end

return BSchema
