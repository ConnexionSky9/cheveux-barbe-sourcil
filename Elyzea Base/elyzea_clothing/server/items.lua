-- =====================================================================
--  ELYZEA CLOTHING · VÊTEMENTS EN OBJETS (serveur)
--  Un vêtement = un objet d'elyzea_inventory qui garde son modèle, son coloris
--  et, pour un pack, sa collection + son n° dans le pack (il reste juste
--  même si on ajoute ou retire d'autres packs).
--  Porter : l'objet est retiré, ce qu'on portait revient en objet.
-- =====================================================================
Items = {}

local INV = 'elyzea_inventory'
local core = exports.elyzea_core
local ITEM_OF, CAT_OF_ITEM = {}, {}
for cat, name in pairs(Config.Items.names or {}) do ITEM_OF[cat] = name CAT_OF_ITEM[name] = cat end
local function inv() return exports[INV] end
local function notify(src, msg, kind) TriggerClientEvent('elyzea_clothing:notify', src, msg, kind or 'error') end

function Items.enabled() return Config.Items.enabled and GetResourceState(INV) == 'started' end
function Items.setBag(src, state) return inv():SetBagEquipped(src, state) end

function Items.sexOf(src)
    local m = GetEntityModel(GetPlayerPed(src))
    if m == `mp_m_freemode_01` then return 'male' end
    if m == `mp_f_freemode_01` then return 'female' end
end

function Items.isNaked(sex, cat, d)
    if d < 0 then return true end
    local n = Config.Naked[sex] and Config.Naked[sex][cat]
    return n ~= nil and d == n[1]
end

-- Pièce reçue du client : nombres propres, collection en minuscules
function Items.cleanPiece(p)
    p = type(p) == 'table' and p or {}
    local out = { drawable = math.floor(tonumber(p.drawable) or -1), texture = math.max(0, math.floor(tonumber(p.texture) or 0)) }
    if type(p.col) == 'string' and p.col ~= '' and p.col:len() <= 64 and tonumber(p.li) then
        out.col, out.li = p.col:lower():gsub('[^%w_%-]', ''), math.max(0, math.floor(tonumber(p.li)))
    end
    return out
end

function Items.same(a, b)
    if a.col or b.col then return a.col == b.col and a.li == b.li and a.texture == b.texture end
    return a.drawable == b.drawable and a.texture == b.texture
end

local function charKey(src)
    local ok, cid = pcall(function() return core:GetCitizenId(src) end)
    if ok and cid then return tostring(cid) end
    for _, id in ipairs(GetPlayerIdentifiers(src)) do if id:sub(1, 8) == 'license:' then return id end end
    return tostring(src)
end

-- Noms donnés aux pièces portées : [rayon] = { piece, label }
local function wornNames(src)
    local raw = GetResourceKvpString('worn:' .. charKey(src))
    local ok, t = pcall(json.decode, raw or '{}')
    return ok and type(t) == 'table' and t or {}
end
local function saveWornNames(src, t)
    SetResourceKvp('worn:' .. charKey(src), json.encode(t))
    local labels = {}
    for cat, v in pairs(t) do labels[cat] = v.label end
    Player(src).state:set('elyzeaWornNames', labels, true)
end
local function cleanName(n) return (tostring(n or ''):gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, 32) end

function Items.metadata(sex, cat, p, custom)
    local pack = Packs.ofCollection(p.col)
    return {
        cat = cat, drawable = p.drawable, texture = p.texture, col = p.col, li = p.li, sex = sex,
        pack = pack and pack.label or nil, custom = custom and true or nil,
        label = custom or ClothingLabel(cat, p, pack and pack.label),
        description = ('%s · coloris %d · %s%s'):format(Cat[cat].label, p.texture + 1, sex == 'male' and 'Homme' or 'Femme',
            pack and (' · ' .. pack.label) or ''),
    }
end

-- Tous les objets vêtements existent-ils dans l'inventaire ?
function Items.declared(list)
    for _, it in ipairs(list) do
        local name = ITEM_OF[it.cat]
        local ok, def = pcall(function() return inv():Items(name) end)
        if not ok or not def then
            print(('^1[elyzea_clothing] objet « %s » inconnu : déclarez-le dans elyzea_inventory/shared/items.lua^0'):format(tostring(name)))
            return false
        end
    end
    return true
end

function Items.canCarry(src, sex, list)
    local items = {}
    for _, it in ipairs(list) do
        if it.piece.drawable >= 0 and ITEM_OF[it.cat] then items[#items + 1] = { ITEM_OF[it.cat], 1, Items.metadata(sex, it.cat, it.piece) } end
    end
    return #items == 0 or inv():CanCarryItems(src, items)
end

-- Donne un vêtement en objet (garde le nom si la pièce portée avait été renommée)
function Items.give(src, sex, cat, p)
    local name = ITEM_OF[cat]
    if not name then return false end
    local names = wornNames(src)
    local w = names[cat]
    local wp = w and (w.piece or (w.d and { drawable = w.d, texture = w.t }))   -- ancien format : { d, t, label }
    local custom = wp and Items.same(Items.cleanPiece(wp), p) and w.label or nil
    local md = Items.metadata(sex, cat, p, custom)
    if not inv():CanCarryItem(src, name, 1, md) then return false end
    local ok = inv():AddItem(src, name, 1, md)
    if ok and w then names[cat] = nil saveWornNames(src, names) end
    return ok and true or false
end

-- ---------------------------------------------------------------------
-- Porter / retirer / renommer
-- ---------------------------------------------------------------------
local busy = {}
local function lock(src)
    if busy[src] then return false end
    busy[src] = true
    SetTimeout(600, function() busy[src] = nil end)
    return true
end

RegisterNetEvent('elyzea_clothing:equip', function(slot, current)
    local src = source
    if not Items.enabled() or not lock(src) then return end
    local item = inv():GetSlot(src, tonumber(slot) or -1)
    local cat = item and CAT_OF_ITEM[item.name]
    local md = item and item.metadata or {}
    if not cat or md.cat ~= cat then return notify(src, 'Ce vêtement est vide ou abîmé.') end
    local sex = Items.sexOf(src)
    if not sex then return notify(src, 'Personnage non compatible.') end
    if md.sex and md.sex ~= sex then return notify(src, md.sex == 'male' and 'Ce vêtement est pour homme.' or 'Ce vêtement est pour femme.') end
    local p = Items.cleanPiece(md)
    if not inv():RemoveItem(src, item.name, 1, nil, item.slot) then return end
    local old = Items.cleanPiece(current)
    if not Items.isNaked(sex, cat, old.drawable) and not Items.same(old, p) then
        if not Items.give(src, sex, cat, old) then
            inv():AddItem(src, item.name, 1, md, item.slot)   -- on rend l'objet à sa place : rien ne change
            return notify(src, 'Inventaire plein : impossible de ranger ce que tu portes.')
        end
    end
    if cat == 'bags' then Items.setBag(src, true) end
    local names = wornNames(src)
    names[cat] = md.custom and { piece = p, label = md.label } or nil
    saveWornNames(src, names)
    TriggerClientEvent('elyzea_clothing:apply', src, cat, p, md.label)
end)

RegisterNetEvent('elyzea_clothing:unequip', function(cat, current)
    local src = source
    if not Items.enabled() or not Cat[cat] or not lock(src) then return end
    local sex = Items.sexOf(src)
    if not sex then return end
    local old = Items.cleanPiece(current)
    if Items.isNaked(sex, cat, old.drawable) then return notify(src, 'Tu ne portes rien à cet endroit.') end
    if cat == 'bags' then   -- la capacité baisse : refusé si le joueur porte trop lourd
        local ok, err = Items.setBag(src, false)
        if not ok then return notify(src, err or 'Impossible de retirer le sac.') end
    end
    if not Items.give(src, sex, cat, old) then
        if cat == 'bags' then Items.setBag(src, true) end
        return notify(src, 'Inventaire plein ou trop lourd.')
    end
    local n = Config.Naked[sex][cat] or { -1, 0 }
    TriggerClientEvent('elyzea_clothing:apply', src, cat, { drawable = n[1], texture = n[2] }, nil, true)
end)

RegisterNetEvent('elyzea_clothing:rename', function(slot, newName)
    local src = source
    if not Items.enabled() then return end
    local item = inv():GetSlot(src, tonumber(slot) or -1)
    local cat = item and CAT_OF_ITEM[item.name]
    if not cat then return end
    local md = item.metadata or {}
    local name = cleanName(newName)
    if name == '' then
        local pack = Packs.ofCollection(md.col)
        md.label, md.custom = ClothingLabel(cat, Items.cleanPiece(md), pack and pack.label), nil
    else
        md.label, md.custom = name, true
    end
    inv():SetMetadata(src, item.slot, md)
    notify(src, name == '' and 'Nom d\'origine remis.' or ('Renommé : %s'):format(name), 'success')
end)

RegisterNetEvent('elyzea_clothing:renameWorn', function(cat, current, newName)
    local src = source
    if not Cat[cat] then return end
    local names = wornNames(src)
    local name = cleanName(newName)
    names[cat] = name ~= '' and { piece = Items.cleanPiece(current), label = name } or nil
    saveWornNames(src, names)
    notify(src, name == '' and 'Nom d\'origine remis.' or ('Renommé : %s'):format(name), 'success')
    TriggerClientEvent('elyzea_clothing:wardrobeRefresh', src)
end)

local function pushNames(src) saveWornNames(src, wornNames(src)) end
AddEventHandler('elyzea:server:playerLoaded', function(src) pushNames(src) end)
RegisterNetEvent('elyzea_clothing:requestNames', function() pushNames(source) end)
AddEventHandler('playerDropped', function() busy[source] = nil end)

-- « Utiliser » un vêtement (raccourcis 1-5) : le porter
local function onUse(src, item)
    if item and item.slot then TriggerClientEvent('elyzea_clothing:equipSlot', src, item.slot) end
    return false   -- jamais consommé ici : porter retire l'objet lui-même
end
local function registerUsables()
    if GetResourceState(INV) ~= 'started' then return end
    for _, name in pairs(ITEM_OF) do
        if not pcall(function() inv():RegisterUsableItem(name, onUse) end) then
            print('^3[elyzea_clothing] Raccourcis 1-5 indisponibles pour les vêtements (le reste fonctionne).^0')
            return
        end
    end
end
AddEventHandler('elyzea_inventory:ready', registerUsables)
AddEventHandler('onServerResourceStart', function(res) if res == GetCurrentResourceName() then registerUsables() end end)
