Shared = {}

Shared.EquipByName = {}
for _, slot in ipairs(Config.EquipSlots) do Shared.EquipByName[slot.name] = slot end

function Shared.IsEmptyMeta(m) return m == nil or next(m) == nil end

-- Comparaison de metadata (comme ox : toutes les clés demandées doivent correspondre)
function Shared.MetaMatches(itemMeta, wanted)
    if wanted == nil then return true end
    if type(wanted) ~= 'table' then return false end
    itemMeta = itemMeta or {}
    for k, v in pairs(wanted) do
        if type(v) == 'table' then
            if not Shared.MetaMatches(itemMeta[k], v) then return false end
        elseif itemMeta[k] ~= v then return false end
    end
    return true
end

function Shared.SameMeta(a, b)
    return Shared.MetaMatches(a, b or {}) and Shared.MetaMatches(b, a or {})
end

function Shared.IsStackable(name)
    local d = Items[name]
    return d ~= nil and d.stack == true
end

function Shared.MaxStack(name)
    local d = Items[name]
    if not d or not d.stack then return 1 end
    return d.max or Config.DefaultMaxStack
end

-- Poids en grammes (entier) d'une pile : jamais d'arrondi flottant.
-- perGram : nombre d'unités pour 1 g (ex. argent : 1 000 $ = 1 g), arrondi au gramme supérieur.
function Shared.StackWeight(name, count)
    local d = Items[name]
    if not d then return 0 end
    count = count or 1
    if d.perGram and d.perGram > 0 then return math.ceil(count / d.perGram) end
    return math.floor(d.weight or 0) * count
end

function Shared.ItemWeight(item)
    if not item then return 0 end
    return Shared.StackWeight(item.name, item.count or 1)
end

function Shared.Copy(t)
    if type(t) ~= 'table' then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = Shared.Copy(v) end
    return r
end

function Shared.DecodeJson(v, default)
    if type(v) == 'table' then return v end
    if type(v) ~= 'string' or v == '' then return default end
    local ok, res = pcall(json.decode, v)
    if ok and res ~= nil then return res end
    return default
end

-- Liste d'objets enregistrée (tableau ou objet à clés numériques)
function Shared.DecodeList(v)
    local data = Shared.DecodeJson(v, {})
    if type(data) ~= 'table' then return {} end
    if data.items then data = data.items end
    local out = {}
    for _, it in pairs(data) do if type(it) == 'table' then out[#out + 1] = it end end
    return out
end
