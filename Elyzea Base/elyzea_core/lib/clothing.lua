--[[
    ELYZEA CORE — vêtements par « collection » (client)
    Dans le fxmanifest :  client_script '@elyzea_core/lib/clothing.lua'

    Pourquoi : GTA numérote tous les vêtements à la suite (n° « global »). Quand on ajoute
    ou retire un pack, les n° des autres packs changent : une tenue enregistrée avec un
    n° global peut devenir un autre vêtement. Une « collection » (= un pack ou un DLC) garde,
    elle, ses propres n° (n° « local ») : on enregistre donc { collection, n° local } en plus.

      ElyCloth.read(ped, kind, slot)          -> { drawable, texture, col, li }
      ElyCloth.resolve(ped, kind, slot, p)    -> n° global à utiliser (nil = pack absent)
      ElyCloth.apply(ped, kind, slot, p)      -> true si appliqué
      ElyCloth.ranges(ped, kind, slot)        -> { { col, first, count }, ... } (blocs de n° globaux)
    kind = 'component' (vêtement) ou 'prop' (accessoire), slot = n° GTA du composant / accessoire.
    Sans les natives de collection (très vieux serveur), tout marche avec les n° globaux.
]]
if IsDuplicityVersion() then return end

ElyCloth = ElyCloth or {}

local function has(...)
    for _, f in ipairs({ ... }) do if type(f) ~= 'function' then return false end end
    return true
end

ElyCloth.enabled = has(GetPedCollectionsCount, GetPedCollectionName,
    GetPedCollectionNameFromDrawable, GetPedCollectionLocalIndexFromDrawable, GetPedDrawableGlobalIndexFromCollection,
    GetNumberOfPedCollectionDrawableVariations,
    GetPedCollectionNameFromProp, GetPedCollectionLocalIndexFromProp, GetPedPropGlobalIndexFromCollection,
    GetNumberOfPedCollectionPropDrawableVariations)

local function isProp(kind) return kind == 'prop' end

-- Collection et n° local d'un n° global
function ElyCloth.info(ped, kind, slot, drawable)
    if not ElyCloth.enabled or not drawable or drawable < 0 then return nil, nil end
    if isProp(kind) then
        return GetPedCollectionNameFromProp(ped, slot, drawable) or '', GetPedCollectionLocalIndexFromProp(ped, slot, drawable)
    end
    return GetPedCollectionNameFromDrawable(ped, slot, drawable) or '', GetPedCollectionLocalIndexFromDrawable(ped, slot, drawable)
end

-- Ce que le personnage porte à cet emplacement
function ElyCloth.read(ped, kind, slot)
    local d, t
    if isProp(kind) then
        d, t = GetPedPropIndex(ped, slot), math.max(0, GetPedPropTextureIndex(ped, slot))
    else
        d, t = GetPedDrawableVariation(ped, slot), GetPedTextureVariation(ped, slot)
    end
    local p = { drawable = d, texture = t }
    local col, li = ElyCloth.info(ped, kind, slot, d)
    if col and col ~= '' and li and li >= 0 then p.col, p.li = col, li end
    return p
end

-- N° global à appliquer : par la collection si elle est connue, sinon le n° global enregistré.
-- Renvoie nil si le vêtement vient d'un pack qui n'est plus installé.
function ElyCloth.resolve(ped, kind, slot, p)
    if type(p) ~= 'table' then return nil end
    local d = tonumber(p.drawable) or -1
    if d < 0 then return -1 end
    if p.col and p.col ~= '' and p.li and ElyCloth.enabled then
        local g = isProp(kind) and GetPedPropGlobalIndexFromCollection(ped, slot, p.col, math.floor(p.li))
            or GetPedDrawableGlobalIndexFromCollection(ped, slot, p.col, math.floor(p.li))
        if g and g >= 0 then return g end
        return nil
    end
    return d
end

function ElyCloth.apply(ped, kind, slot, p)
    local d = ElyCloth.resolve(ped, kind, slot, p)
    if d == nil then return false end
    local t = math.max(0, math.floor(tonumber(p.texture) or 0))
    if isProp(kind) then
        if d < 0 then ClearPedProp(ped, slot)
        else
            if t >= GetNumberOfPedPropTextureVariations(ped, slot, d) then t = 0 end
            SetPedPropIndex(ped, slot, d, t, true)
        end
    else
        if d < 0 then d = 0 end
        if t >= GetNumberOfPedTextureVariations(ped, slot, d) then t = 0 end
        SetPedComponentVariation(ped, slot, d, t, 0)
    end
    return true
end

-- Blocs de n° globaux par collection (les vêtements d'un pack se suivent)
function ElyCloth.ranges(ped, kind, slot)
    if not ElyCloth.enabled then return {} end
    local out = {}
    for i = 0, GetPedCollectionsCount(ped) - 1 do
        local col = GetPedCollectionName(ped, i) or ''
        local n = isProp(kind) and GetNumberOfPedCollectionPropDrawableVariations(ped, slot, col)
            or GetNumberOfPedCollectionDrawableVariations(ped, slot, col)
        if n and n > 0 then
            local first = isProp(kind) and GetPedPropGlobalIndexFromCollection(ped, slot, col, 0)
                or GetPedDrawableGlobalIndexFromCollection(ped, slot, col, 0)
            if first and first >= 0 then out[#out + 1] = { col = col, first = first, count = n } end
        end
    end
    table.sort(out, function(a, b) return a.first < b.first end)
    return out
end
