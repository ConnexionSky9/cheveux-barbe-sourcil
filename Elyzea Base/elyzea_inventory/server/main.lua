--[[
    ELYZEA FA — Inventaire (serveur)
    - Inventaire du personnage (citizenid de la base Elyzea), sauvegardé dans players.inventory.
    - Coffres (stashs), boutiques, fouille d'un joueur, objets au sol.
    - Poids en GRAMMES entiers. Capacité 18 000 g, 28 000 g avec un sac porté.
    - Toute action est validée ici ; la NUI ne fait que demander.
]]

Inv        = {}   -- [src] = { id, slots = {}, size, bag, dirty }
Containers = {}   -- [id] = { id, kind, label, size, maxWeight, slots = {}, groups, coords, owner, dirty, shop }
Viewing    = {}   -- [src] = { kind = 'stash' | 'shop' | 'player', id, target }
Usable     = {}
local Drops   = {}
local Open    = {}
local Rate    = {}
local DropSeq = 0
local Msg     = Config.Messages
local core    = exports.elyzea_core

-- ───────── Helpers ─────────

local function int(v, min, max)
    v = tonumber(v)
    if not v or v ~= v then return nil end
    v = math.floor(v)
    if v < min or v > max then return nil end
    return v
end

local function identifier(src)
    local ok, cid = pcall(function() return core:GetCitizenId(src) end)
    return ok and cid or nil
end

local function playerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function limited(src)
    local now = GetGameTimer()
    local r = Rate[src]
    if not r or now - r.t > Config.RateLimit.window then
        Rate[src] = { t = now, n = 1 }
        return false
    end
    r.n = r.n + 1
    return r.n > Config.RateLimit.max
end

local function bagBonus()
    local d = Items[Config.BagItem]
    return (d and d.bonus) or 0
end

-- Capacité d'un « stockage » (inventaire joueur ou coffre)
local function capOf(st)
    if st.maxWeight then return st.maxWeight end
    return Config.BaseCapacity + (st.bag and bagBonus() or 0)
end

local function weightOf(st)
    local w = 0
    for i = 1, st.size do
        local it = st.slots[i]
        if it then w = w + Shared.ItemWeight(it) end
    end
    return w
end

local function firstEmpty(st)
    for i = 1, st.size do
        if not st.slots[i] then return i end
    end
end

local function countOf(st, name, metadata)
    local n = 0
    for i = 1, st.size do
        local it = st.slots[i]
        if it and it.name == name and Shared.MetaMatches(it.metadata, metadata) then n = n + it.count end
    end
    return n
end

-- Métadonnées par défaut (armes : munitions + numéro de série)
local function defaultMeta(name, metadata)
    local d = Items[name]
    if d and d.kind == 'weapon' and not d.throwable then
        metadata = type(metadata) == 'table' and metadata or {}
        metadata.ammo = tonumber(metadata.ammo) or 0
        metadata.durability = metadata.durability or 100
        metadata.serial = metadata.serial or ('%s%s'):format(math.random(100000, 999999), string.char(math.random(65, 90), math.random(65, 90), math.random(65, 90)))
        metadata.components = metadata.components or {}
    end
    return metadata
end

-- ───────── Sérialisation ─────────

local function serialize(it, slot, extra)
    local def = Items[it.name] or {}
    local meta = it.metadata or {}
    local desc = meta.description or def.description
    if def.kind == 'weapon' and meta.ammo then desc = (desc and desc .. ' · ' or '') .. ('Munitions : %d'):format(meta.ammo) end
    if meta.serial and def.kind == 'weapon' then desc = (desc and desc .. ' · ' or '') .. ('N° %s'):format(meta.serial) end
    local img = meta.imageurl or meta.image or def.image or (it.name .. '.png')
    local isUrl = type(img) == 'string' and img:find('://') ~= nil
    local out = {
        slot = slot, name = it.name, count = it.count,
        label = meta.label or def.label or it.name, icon = def.icon,
        image = not isUrl and img or nil, imageUrl = isUrl and img or nil,
        weight = math.floor(def.weight or 0) / 1000,
        description = desc,
        stack = def.stack == true, max = Shared.MaxStack(it.name),
        plain = Shared.IsEmptyMeta(it.metadata),
        metadata = it.metadata,
        equip = def.clothing, bonus = def.bonus and def.bonus / 1000 or nil,
        buttons = def.buttons and #def.buttons or 0,
        weapon = def.kind == 'weapon' or nil,
    }
    if extra then for k, v in pairs(extra) do out[k] = v end end
    return out
end

local function nearestDrop(src)
    local c = playerCoords(src)
    if not c then return nil end
    local best, bestDist
    for _, d in pairs(Drops) do
        local dist = #(c - d.coords)
        if dist <= Config.DropDistance and (not bestDist or dist < bestDist) then best, bestDist = d, dist end
    end
    return best
end

local function containerPayload(src)
    local v = Viewing[src]
    if not v then return nil end
    if v.kind == 'player' then
        local t = Inv[v.target]
        if not t then return nil end
        local items = {}
        for i = 1, t.size do if t.slots[i] then items[#items + 1] = serialize(t.slots[i], i) end end
        return { kind = 'player', id = v.target, label = v.label or ('Fouille · ID %d'):format(v.target), size = t.size,
            weight = weightOf(t) / 1000, capacity = capOf(t) / 1000, items = items }
    end
    local c = Containers[v.id]
    if not c then return nil end
    local items = {}
    if c.kind == 'shop' then
        for i, e in ipairs(c.shop) do
            if Items[e.name] then
                items[#items + 1] = serialize({ name = e.name, count = e.count or 1, metadata = e.metadata }, i, { price = e.price, currency = e.currency })
            end
        end
        return { kind = 'shop', id = c.id, label = c.label, size = #c.shop, items = items }
    end
    for i = 1, c.size do if c.slots[i] then items[#items + 1] = serialize(c.slots[i], i) end end
    return { kind = c.kind, id = c.id, label = c.label, size = c.size, weight = weightOf(c) / 1000, capacity = capOf(c) / 1000, items = items }
end

local function buildPayload(src)
    local inv = Inv[src]
    local items = {}
    for i = 1, inv.size do
        local it = inv.slots[i]
        if it then items[#items + 1] = serialize(it, i) end
    end
    local ground
    local drop = nearestDrop(src)
    if drop then
        ground = { id = drop.id, items = {} }
        for i, it in ipairs(drop.items) do ground.items[i] = serialize(it, i) end
    end
    return {
        slots = inv.size, hotbar = Config.HotbarSlots, items = items,
        weight = weightOf(inv) / 1000, capacity = capOf(inv) / 1000,
        baseCapacity = Config.BaseCapacity / 1000, bag = inv.bag == true,
        ground = ground,
        container = containerPayload(src),
    }
end

function Sync(src, toast)
    if not Inv[src] then return end
    TriggerClientEvent('elyzea_inv:sync', src, buildPayload(src), toast)
    if CheckEquippedWeapon then CheckEquippedWeapon(src) end
    if UpdateBodyWeapons then UpdateBodyWeapons(src) end
end
local sync = Sync

local function broadcastDrops(target)
    local list = {}
    for id, d in pairs(Drops) do list[#list + 1] = { id = id, coords = d.coords } end
    TriggerClientEvent('elyzea_inv:drops', target or -1, list)
end

local function refreshOpen(except)
    for s in pairs(Open) do if s ~= except then sync(s) end end
end

-- Rafraîchit tous ceux qui regardent ce coffre / ce joueur
local function refreshViewers(kind, id, except)
    for s, v in pairs(Viewing) do
        if s ~= except and v.kind == kind and (v.id == id or v.target == id) then sync(s) end
    end
end

-- ───────── Coeur : ajout / retrait (sur un « stockage » quelconque) ─────────

local function planAdd(st, name, count, metadata)
    local plan, remaining = {}, count
    local max = Shared.MaxStack(name)
    if Shared.IsStackable(name) then
        for i = 1, st.size do
            if remaining <= 0 then break end
            local it = st.slots[i]
            if it and it.name == name and Shared.SameMeta(it.metadata, metadata) and it.count < max then
                local add = math.min(max - it.count, remaining)
                plan[#plan + 1] = { slot = i, add = add }
                remaining = remaining - add
            end
        end
    end
    for i = 1, st.size do
        if remaining <= 0 then break end
        if not st.slots[i] then
            local add = math.min(max, remaining)
            plan[#plan + 1] = { slot = i, add = add, new = true }
            remaining = remaining - add
        end
    end
    if remaining > 0 then return nil end
    return plan
end

local function canCarryWeight(st, name, count)
    local d = Items[name]
    if not d then return false end
    return weightOf(st) + math.floor(d.weight or 0) * count <= capOf(st)
end

local function addTo(st, name, count, metadata, preferSlot)
    if not st then return false, 'no_inventory' end
    name = ResolveItemName(name)
    if not name then return false, 'unknown_item' end
    count = math.floor(tonumber(count) or 0)
    if count < 1 then return false, 'invalid_count' end
    if type(metadata) ~= 'table' then metadata = nil end
    preferSlot = int(preferSlot, 1, st.size)

    if not canCarryWeight(st, name, count) then return false, 'too_heavy' end

    -- Objets non empilables : chacun reçoit ses propres métadonnées
    if not Shared.IsStackable(name) and count > 1 then
        local plan = planAdd(st, name, count, metadata)
        if not plan then return false, 'no_space' end
        local first
        for _, p in ipairs(plan) do
            st.slots[p.slot] = { name = name, count = 1, metadata = defaultMeta(name, Shared.Copy(metadata)) }
            first = first or p.slot
        end
        st.dirty = true
        return true, first
    end

    local plan
    local target = preferSlot and st.slots[preferSlot]
    if preferSlot and not target and count <= Shared.MaxStack(name) then
        plan = { { slot = preferSlot, add = count, new = true } }
    elseif target and target.name == name and Shared.IsStackable(name)
        and Shared.SameMeta(target.metadata, metadata) and target.count + count <= Shared.MaxStack(name) then
        plan = { { slot = preferSlot, add = count } }
    else
        plan = planAdd(st, name, count, metadata)
    end
    if not plan then return false, 'no_space' end

    for _, p in ipairs(plan) do
        if p.new then
            st.slots[p.slot] = { name = name, count = p.add, metadata = defaultMeta(name, Shared.Copy(metadata)) }
        else
            st.slots[p.slot].count = st.slots[p.slot].count + p.add
        end
    end
    st.dirty = true
    return true, plan[1].slot
end

local function removeFrom(st, name, count, metadata, slot)
    if not st then return false, 'no_inventory' end
    name = ResolveItemName(name) or name
    count = math.floor(tonumber(count) or 1)
    if count < 1 then return false, 'invalid_count' end
    if type(metadata) ~= 'table' then metadata = nil end

    slot = tonumber(slot)
    if slot then
        local it = st.slots[slot]
        if not it or it.name ~= name or it.count < count or not Shared.MetaMatches(it.metadata, metadata) then
            return false, 'not_enough'
        end
        it.count = it.count - count
        if it.count <= 0 then st.slots[slot] = nil end
        st.dirty = true
        return true
    end

    if countOf(st, name, metadata) < count then return false, 'not_enough' end
    for i = st.size, 1, -1 do
        if count <= 0 then break end
        local it = st.slots[i]
        if it and it.name == name and Shared.MetaMatches(it.metadata, metadata) then
            local take = math.min(it.count, count)
            it.count = it.count - take
            count = count - take
            if it.count <= 0 then st.slots[i] = nil end
        end
    end
    st.dirty = true
    return true
end

-- Raccourcis sur l'inventaire d'un joueur
local function addItem(src, name, count, metadata, slot) return addTo(Inv[src], name, count, metadata, slot) end
local function removeItem(src, name, count, metadata, slot) return removeFrom(Inv[src], name, count, metadata, slot) end
AddItemTo, RemoveItemFrom = addTo, removeFrom

-- ───────── Sac porté (piloté par elyzea_clothing) ─────────

local function setBagEquipped(src, state)
    local inv = Inv[src]
    if not inv then return false, 'no_inventory' end
    state = state == true
    if inv.bag == state then return true end
    if not state then
        local w = weightOf(inv)
        if w > Config.BaseCapacity then
            return false, Msg.bag_heavy:format(w / 1000, Config.BaseCapacity / 1000)
        end
    end
    inv.bag = state
    inv.dirty = true
    sync(src)
    return true
end

-- ───────── Coffres (stashs) ─────────

local function stashKey(id, owner) return owner and (tostring(id) .. ':' .. tostring(owner)) or tostring(id) end

-- Ancienne table ox_inventory présente en base ? (vérifié une seule fois)
local oxTable
local function hasOxTable()
    if oxTable == nil then
        local ok, n = pcall(MySQL.scalar.await, "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ox_inventory'")
        oxTable = ok and (tonumber(n) or 0) > 0
    end
    return oxTable
end

local function loadContainer(c)
    if c.loaded then return end
    c.loaded = true
    local row = MySQL.single.await('SELECT `items` FROM `elyzea_stashes` WHERE `id` = ?', { c.id })
    local data = row and Shared.DecodeList(row.items) or {}
    -- Première ouverture : reprise du contenu de l'ancien coffre ox_inventory (même nom, même propriétaire)
    if not row and hasOxTable() then
        local ok, old = pcall(MySQL.scalar.await, 'SELECT `data` FROM `ox_inventory` WHERE `name` = ? AND `owner` = ? LIMIT 1',
            { c.def, c.owner and tostring(c.owner) or '' })
        if ok and old then
            data = Shared.DecodeList(old)
            if #data > 0 then
                c.dirty = true
                print(('[elyzea_inventory] Coffre « %s » repris de l\'ancien inventaire (%d pile(s)).'):format(c.id, #data))
            end
        end
    end
    for _, it in ipairs(data) do
        local name = ResolveItemName(it.name)
        local slot = int(it.slot, 1, c.size)
        if name and slot and not c.slots[slot] then
            c.slots[slot] = { name = name, count = math.max(1, math.floor(it.count or 1)), metadata = it.metadata }
        end
    end
end

local function saveContainer(c)
    if not c.dirty or c.kind ~= 'stash' or c.temporary then c.dirty = false return end
    local items = {}
    for i = 1, c.size do
        local it = c.slots[i]
        if it then items[#items + 1] = { slot = i, name = it.name, count = it.count, metadata = it.metadata } end
    end
    MySQL.query('INSERT INTO `elyzea_stashes` (`id`, `items`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `items` = VALUES(`items`)',
        { c.id, json.encode(items) })
    c.dirty = false
end

-- RegisterStash(id, label, slots, maxWeight (grammes), owner, groups, coords)
-- owner = true : un coffre par personnage ; groups = { [métier] = gradeMin }
local StashDefs = {}
function RegisterStash(id, label, slots, maxWeight, owner, groups, coords, opts)
    if type(id) ~= 'string' and type(id) ~= 'number' then return false end
    id = tostring(id)
    StashDefs[id] = {
        id = id, label = label or id, size = math.max(1, math.min(500, math.floor(tonumber(slots) or 50))),
        maxWeight = math.floor(tonumber(maxWeight) or 100000), owner = owner, groups = groups,
        coords = coords and vector3(coords.x, coords.y, coords.z) or nil,
        temporary = opts and opts.temporary or nil,
    }
    -- Coffre déjà chargé : on met à jour sa taille et son libellé
    for key, c in pairs(Containers) do
        if c.def == id then
            c.label, c.size, c.maxWeight, c.groups, c.coords = StashDefs[id].label, StashDefs[id].size, StashDefs[id].maxWeight, groups, StashDefs[id].coords
        end
    end
    return true
end

local function getStash(id, src)
    local def = StashDefs[tostring(id)]
    if not def then return nil end
    local owner = nil
    if def.owner == true then owner = identifier(src) elseif type(def.owner) == 'string' then owner = def.owner end
    local key = stashKey(def.id, owner)
    local c = Containers[key]
    if not c then
        c = { id = key, def = def.id, owner = owner, kind = 'stash', label = def.label, size = def.size, maxWeight = def.maxWeight,
              slots = {}, groups = def.groups, coords = def.coords, temporary = def.temporary }
        Containers[key] = c
    end
    if not c.temporary then loadContainer(c) end
    return c
end

-- Accès par métier / gang
local function hasGroup(src, groups)
    if not groups then return true end
    local pd = core:GetPlayerData(src)
    if not pd then return false end
    if type(groups) == 'string' then groups = { [groups] = 0 } end
    for name, minGrade in pairs(groups) do
        if type(name) == 'number' then name, minGrade = minGrade, 0 end
        local job, gang = pd.job, pd.gang
        if job and job.name == name and (job.grade and job.grade.level or 0) >= (tonumber(minGrade) or 0) then return true end
        if gang and gang.name == name and (gang.grade and gang.grade.level or 0) >= (tonumber(minGrade) or 0) then return true end
    end
    return false
end

-- Accès supplémentaires (ex. elyzea_illegal) : fonction(src, stashId) -> true / false
local AccessChecks = {}
function RegisterStashAccess(prefix, cb) AccessChecks[prefix] = cb end

local function canAccessStash(src, c)
    if not hasGroup(src, c.groups) then return false end
    for prefix, cb in pairs(AccessChecks) do
        if c.def:sub(1, #prefix) == prefix then
            local ok, res = pcall(cb, src, c.def)
            if not ok or res == false then return false end
        end
    end
    return true
end

-- ───────── Boutiques ─────────

-- RegisterShop(id, { name, inventory = { { name, price, count?, metadata?, grade? } }, groups, locations })
local ShopDefs = {}
function RegisterShop(id, data)
    if type(id) ~= 'string' or type(data) ~= 'table' then return false end
    local list = {}
    for _, e in ipairs(data.inventory or {}) do
        local name = ResolveItemName(e.name)
        if name then
            list[#list + 1] = { name = name, price = math.max(0, math.floor(tonumber(e.price) or 0)), count = e.count,
                metadata = e.metadata, grade = e.grade, currency = e.currency }
        else
            print(('^3[elyzea_inventory] boutique %s : objet inconnu %s^0'):format(id, tostring(e.name)))
        end
    end
    ShopDefs[id] = { id = id, label = data.name or id, shop = list, groups = data.groups, locations = data.locations }
    Containers['shop:' .. id] = { id = 'shop:' .. id, def = id, kind = 'shop', label = data.name or id, shop = list, size = #list, slots = {}, groups = data.groups }
    return true
end

-- ───────── Ouverture d'un second inventaire ─────────

local function openFor(src, payloadViewing)
    if not Inv[src] then return false end
    Viewing[src] = payloadViewing
    Open[src] = true
    TriggerClientEvent('elyzea_inv:open', src, buildPayload(src))
    return true
end

-- forceOpenInventory(src, 'stash' | 'shop' | 'player', id)
function ForceOpen(src, kind, id)
    src = tonumber(src)
    if not src or not Inv[src] then return false end
    if type(id) == 'table' then id = kind == 'shop' and (id.type or id.id) or (id.id or id.type) end
    if kind == 'stash' then
        local c = getStash(id, src)
        if not c then return false end
        return openFor(src, { kind = 'stash', id = c.id })
    elseif kind == 'shop' then
        if not ShopDefs[tostring(id)] then return false end
        return openFor(src, { kind = 'shop', id = 'shop:' .. tostring(id) })
    elseif kind == 'player' then
        local target = tonumber(id)
        if not target or not Inv[target] or target == src then return false end
        return openFor(src, { kind = 'player', target = target, id = target })
    end
    return false
end

-- Ouverture demandée par le client (vérifie l'accès)
RegisterNetEvent('elyzea_inv:openContainer', function(kind, id)
    local src = source
    if not Inv[src] or limited(src) then return end
    if kind == 'stash' then
        local c = getStash(id, src)
        if not c then return end
        if not canAccessStash(src, c) then return sync(src, { type = 'error', text = Msg.no_access }) end
        if c.coords then
            local pc = playerCoords(src)
            if not pc or #(pc - c.coords) > 6.0 then return sync(src, { type = 'error', text = Msg.too_far }) end
        end
        openFor(src, { kind = 'stash', id = c.id })
    elseif kind == 'shop' then
        local s = ShopDefs[tostring(type(id) == 'table' and id.type or id)]
        if not s then return end
        if s.groups and not hasGroup(src, s.groups) then return sync(src, { type = 'error', text = Msg.no_access }) end
        openFor(src, { kind = 'shop', id = 'shop:' .. s.id })
    end
end)

-- ───────── Actions NUI ─────────

local Actions = {}

function Actions.move(src, inv, d)
    local from, to = int(d.from, 1, inv.size), int(d.to, 1, inv.size)
    if not from or not to or from == to then return false end
    local a = inv.slots[from]
    if not a then return false end
    local count = int(d.count, 1, a.count) or a.count
    local b = inv.slots[to]
    if not b then
        if count == a.count then
            inv.slots[to], inv.slots[from] = a, nil
        else
            inv.slots[to] = { name = a.name, count = count, metadata = Shared.Copy(a.metadata) }
            a.count = a.count - count
        end
    elseif b.name == a.name and Shared.IsStackable(a.name) and Shared.SameMeta(a.metadata, b.metadata) then
        local add = math.min(count, Shared.MaxStack(a.name) - b.count)
        if add <= 0 then return false, 'stack_full' end
        b.count = b.count + add
        a.count = a.count - add
        if a.count <= 0 then inv.slots[from] = nil end
    else
        inv.slots[to], inv.slots[from] = a, b
    end
    if MovedWeaponSlot then MovedWeaponSlot(src, from, to) end
    return true
end

function Actions.drop(src, inv, d)
    local from = int(d.from, 1, inv.size)
    local item = from and inv.slots[from]
    if not item then return false end
    local count = int(d.count, 1, item.count) or item.count
    local c = playerCoords(src)
    if not c then return false end

    local drop, created = nearestDrop(src), false
    if not drop then
        DropSeq = DropSeq + 1
        drop = { id = DropSeq, coords = vector3(c.x, c.y, c.z - 0.95), items = {}, created = os.time() }
        created = true
    end
    local placed = false
    if Shared.IsStackable(item.name) then
        for _, g in ipairs(drop.items) do
            if g.name == item.name and Shared.SameMeta(g.metadata, item.metadata) then
                g.count = g.count + count
                placed = true
                break
            end
        end
    end
    if not placed then
        if #drop.items >= Config.DropMaxItems then return false, 'ground_full' end
        drop.items[#drop.items + 1] = { name = item.name, count = count, metadata = Shared.Copy(item.metadata) }
    end
    item.count = item.count - count
    if item.count <= 0 then inv.slots[from] = nil end
    if created then Drops[drop.id] = drop broadcastDrops() end
    TriggerEvent('elyzea_inventory:itemMoved', src, 'drop', item.name, count)
    return true, nil, true
end

function Actions.pickup(src, inv, d)
    local drop = Drops[int(d.drop, 1, 2 ^ 31) or -1]
    if not drop then return false end
    local c = playerCoords(src)
    if not c or #(c - drop.coords) > Config.DropDistance + 1.0 then return false, 'too_far' end
    local idx = int(d.index, 1, #drop.items)
    local it = idx and drop.items[idx]
    if not it then return false end
    local count = int(d.count, 1, it.count) or it.count
    local ok, err = addItem(src, it.name, count, it.metadata, d.to)
    if not ok then return false, err end
    it.count = it.count - count
    if it.count <= 0 then table.remove(drop.items, idx) end
    if #drop.items == 0 then Drops[drop.id] = nil broadcastDrops() end
    return true, nil, true
end

-- Second inventaire ouvert (coffre / joueur fouillé) : le « stockage » correspondant
local function viewedStore(src)
    local v = Viewing[src]
    if not v then return nil end
    if v.kind == 'player' then
        local t = Inv[v.target]
        if not t then return nil end
        local a, b = playerCoords(src), playerCoords(v.target)
        if not a or not b or #(a - b) > 5.0 then return nil, 'too_far' end
        return t, v
    end
    local c = Containers[v.id]
    if not c then return nil end
    if c.coords then
        local pc = playerCoords(src)
        if not pc or #(pc - c.coords) > 10.0 then return nil, 'too_far' end
    end
    return c, v
end

-- Inventaire -> second inventaire
function Actions.store(src, inv, d)
    local st, v = viewedStore(src)
    if not st then return false, v end
    if st.kind == 'shop' then return false end
    local from = int(d.from, 1, inv.size)
    local item = from and inv.slots[from]
    if not item then return false end
    local count = int(d.count, 1, item.count) or item.count
    local ok, err = addTo(st, item.name, count, item.metadata, d.to)
    if not ok then return false, err == 'too_heavy' and 'container_heavy' or err end
    removeFrom(inv, item.name, count, nil, from)
    if v.kind == 'player' then sync(v.target) else refreshViewers('stash', v.id, src) end
    TriggerEvent('elyzea_inventory:itemMoved', src, 'store', item.name, count, v.kind, v.id)
    return true
end

-- Second inventaire -> inventaire (ou achat en boutique)
function Actions.take(src, inv, d)
    local st, v = viewedStore(src)
    if not st then return false, v end

    if st.kind == 'shop' then
        local e = st.shop[int(d.from, 1, #st.shop) or -1]
        if not e then return false end
        local count = int(d.count, 1, 1000) or 1
        if not Shared.IsStackable(e.name) then count = math.min(count, 10) end
        if e.grade then
            local pd = core:GetPlayerData(src)
            if not pd or (pd.job.grade.level or 0) < e.grade then return false, 'no_access' end
        end
        local price = (e.price or 0) * count
        if not API.CanCarryItem(src, e.name, count, e.metadata) then return false, 'too_heavy' end
        if price > 0 then
            local paid = core:RemoveMoney(src, 'cash', price, 'shop')
            if not paid then paid = core:RemoveMoney(src, 'bank', price, 'shop') end
            if not paid then return false, 'no_money' end
        end
        local ok, err = addItem(src, e.name, count, e.metadata, d.to)
        if not ok then
            if price > 0 then core:AddMoney(src, 'cash', price, 'shop_refund') end
            return false, err
        end
        TriggerEvent('elyzea_inventory:bought', src, st.def, e.name, count, price)
        return true
    end

    local from = int(d.from, 1, st.size)
    local item = from and st.slots[from]
    if not item then return false end
    local count = int(d.count, 1, item.count) or item.count
    local ok, err = addItem(src, item.name, count, item.metadata, d.to)
    if not ok then return false, err end
    removeFrom(st, item.name, count, nil, from)
    if v.kind == 'player' then sync(v.target) else refreshViewers('stash', v.id, src) end
    TriggerEvent('elyzea_inventory:itemMoved', src, 'take', item.name, count, v.kind, v.id)
    return true
end

-- Déplacement à l'intérieur du second inventaire
function Actions.cmove(src, _, d)
    local st, v = viewedStore(src)
    if not st or st.kind == 'shop' then return false end
    local from, to = int(d.from, 1, st.size), int(d.to, 1, st.size)
    if not from or not to or from == to then return false end
    local a, b = st.slots[from], st.slots[to]
    if not a then return false end
    if b and b.name == a.name and Shared.IsStackable(a.name) and Shared.SameMeta(a.metadata, b.metadata) then
        local add = math.min(a.count, Shared.MaxStack(a.name) - b.count)
        if add <= 0 then return false, 'stack_full' end
        b.count = b.count + add
        a.count = a.count - add
        if a.count <= 0 then st.slots[from] = nil end
    else
        st.slots[to], st.slots[from] = a, b
    end
    st.dirty = true
    if v.kind == 'player' then sync(v.target) else refreshViewers('stash', v.id, src) end
    return true
end

-- ───────── Utilisation ─────────

local Pending = {}   -- [src] = { slot, name, token, expires }

local function callExport(path, ...)
    local res, fn = tostring(path or ''):match('^([^.]+)%.(.+)$')
    if not res or GetResourceState(res) ~= 'started' then return false end
    local ok, r = pcall(function(...) return exports[res][fn](exports[res], ...) end, ...)
    if not ok then print(('^1[elyzea_inventory] %s : %s^0'):format(path, tostring(r))) return false end
    return true, r
end

local function slotData(st, i)
    local it = st.slots[i]
    if not it then return nil end
    local d = Items[it.name] or {}
    return {
        name = it.name, label = (it.metadata and it.metadata.label) or d.label or it.name, count = it.count, slot = i,
        metadata = Shared.Copy(it.metadata or {}), weight = Shared.ItemWeight(it),
        stack = d.stack == true, description = d.description,
    }
end

function UseSlot(src, from)
    local inv = Inv[src]
    local item = inv and from and inv.slots[from]
    if not item then return false end
    local def = Items[item.name] or {}

    if def.kind == 'weapon' then return UseWeapon(src, from, item, def) end
    if def.kind == 'ammo' then return UseAmmo(src, from, item, def) end

    local fn = Usable[item.name]
    if fn then
        local okCall, consume = pcall(fn, src, { name = item.name, slot = from, count = item.count, metadata = Shared.Copy(item.metadata), label = def.label })
        if not okCall then
            print(('^1[elyzea_inventory] erreur dans l\'objet utilisable %s : %s^0'):format(item.name, consume))
            return false
        end
        if consume == true then
            local cur = inv.slots[from]
            if cur and cur.name == item.name then removeItem(src, item.name, 1, nil, from) end
        end
        return true
    end

    if def.server and def.server.export then
        local ok, consume = callExport(def.server.export, 'usingItem', { id = src }, slotData(inv, from))
        if ok and consume == true then removeItem(src, item.name, 1, nil, from) end
        return ok
    end

    if def.client then
        local c = def.client
        if c.export and not (c.status or c.usetime or c.anim) then
            TriggerClientEvent('elyzea_inv:clientExport', src, c.export, def.label, slotData(inv, from))
            return true
        end
        if c.status or c.usetime or c.anim then
            local token = math.random(100000, 999999)
            Pending[src] = { slot = from, name = item.name, token = token, expires = os.time() + 30 }
            TriggerClientEvent('elyzea_inv:consume', src, {
                token = token, slot = from, name = item.name, label = def.label,
                anim = c.anim, prop = c.prop, usetime = c.usetime or 2500, notification = c.notification,
                disable = c.disable, cancel = c.cancel ~= false, export = c.export,
            })
            return true
        end
    end
    return false, 'not_usable'
end

-- Fin d'une consommation (nourriture, boisson…) : retrait de l'objet et effets
RegisterNetEvent('elyzea_inv:consumed', function(token, success)
    local src = source
    local p = Pending[src]
    Pending[src] = nil
    if not p or p.token ~= token or os.time() > p.expires or success ~= true then return end
    local inv = Inv[src]
    local it = inv and inv.slots[p.slot]
    if not it or it.name ~= p.name then return end
    local def = Items[p.name] or {}
    local consume = def.consume
    if consume == nil or consume > 0 then removeItem(src, p.name, 1, nil, p.slot) end
    local st = def.client and def.client.status
    if st then
        pcall(function()
            core:AddNeeds(src, (tonumber(st.hunger) or 0) / 10000, (tonumber(st.thirst) or 0) / 10000, (tonumber(st.stress) or 0) / 10000)
        end)
    end
    sync(src)
    TriggerEvent('elyzea_inventory:usedItem', src, p.name, slotData(inv, p.slot))
end)

function Actions.use(src, inv, d)
    return UseSlot(src, int(d.from, 1, inv.size))
end

-- Donner à un joueur proche
function Actions.give(src, inv, d)
    local target = tonumber(d.target)
    local from = int(d.from, 1, inv.size)
    local item = from and inv.slots[from]
    if not item or not target or target == src or not Inv[target] then return false end
    local a, b = playerCoords(src), playerCoords(target)
    if not a or not b or #(a - b) > 3.0 then return false, 'too_far' end
    local count = int(d.count, 1, item.count) or item.count
    local ok, err = addItem(target, item.name, count, item.metadata)
    if not ok then return false, err == 'too_heavy' and 'target_heavy' or err end
    removeItem(src, item.name, count, nil, from)
    sync(target, { type = 'success', text = ('+%dx %s'):format(count, (Items[item.name] or {}).label or item.name) })
    TriggerEvent('elyzea_inventory:itemMoved', src, 'give', item.name, count, 'player', target)
    return true
end

RegisterNetEvent('elyzea_inv:action', function(action, data)
    local src = source
    local inv = Inv[src]
    if not inv or type(action) ~= 'string' or type(data) ~= 'table' then return end
    local handler = Actions[action]
    if not handler then return end
    if limited(src) then return sync(src, { type = 'error', text = Msg.rate_limited }) end
    local ok, err, touchesGround = handler(src, inv, data)
    if ok then inv.dirty = true end
    sync(src, (not ok and err) and { type = 'error', text = Msg[err] or err } or nil)
    if ok and touchesGround then refreshOpen(src) end
end)

-- ───────── Chargement / sauvegarde (par personnage, table players) ─────────

local function serializeSlots(st)
    local items = {}
    for i = 1, st.size do
        local it = st.slots[i]
        if it then items[#items + 1] = { slot = i, name = it.name, count = it.count, metadata = it.metadata } end
    end
    return items
end

function SaveInventory(src)
    local inv = Inv[src]
    if not inv or not inv.id then return end
    local data = json.encode({ items = serializeSlots(inv), bag = inv.bag == true })
    MySQL.update('UPDATE `players` SET `inventory` = ? WHERE `citizenid` = ?', { data, inv.id })
    inv.dirty = false
end
local save = SaveInventory

-- Lit l'inventaire enregistré (format Elyzea { items, bag } ou ancien format « liste d'objets »)
local function decodeStored(raw)
    local data = Shared.DecodeJson(raw, nil)
    if type(data) ~= 'table' then return nil end
    if data.items then return data.items, data.bag == true end
    return data, nil
end

local function loadInventory(src)
    local id = identifier(src)
    local inv = { id = id, slots = {}, size = Config.Slots, bag = false, dirty = false }
    Inv[src] = inv
    if not id then return end
    local raw = MySQL.scalar.await('SELECT `inventory` FROM `players` WHERE `citizenid` = ?', { id })
    local list, bag = decodeStored(raw)
    if not list then
        -- Ancien stockage KVP d'elyzea_inventory (version autonome)
        local kvp = GetResourceKvpString('inv:' .. id)
        if kvp then list, bag = decodeStored(kvp) end
    end
    if bag == nil then bag = GetResourceKvpInt('bag:' .. id) == 1 end
    inv.bag = bag == true
    if list then
        local overflow = {}
        for _, it in pairs(list) do
            local name = ResolveItemName(it.name)
            local count = math.max(1, math.floor(tonumber(it.count or it.amount) or 1))
            local meta = it.metadata or it.info
            if type(meta) ~= 'table' or next(meta) == nil then meta = nil end
            local slot = int(it.slot, 1, inv.size)
            if name then
                if slot and not inv.slots[slot] then inv.slots[slot] = { name = name, count = count, metadata = meta }
                else overflow[#overflow + 1] = { name = name, count = count, metadata = meta } end
            elseif it.name and not IgnoredItems[it.name] then
                print(('^3[elyzea_inventory] objet inconnu ignoré au chargement : %s (%s)^0'):format(tostring(it.name), id))
            end
        end
        for _, it in ipairs(overflow) do
            local s = firstEmpty(inv)
            if s then inv.slots[s] = it end
        end
        return
    end
    for _, s in ipairs(Config.StarterItems) do addItem(src, s.name, s.count, s.metadata) end
    inv.dirty = true
end

local function ensureLoaded(src)
    local id = identifier(src)
    local inv = Inv[src]
    if inv and inv.id == id then return inv end
    if inv then save(src) end   -- changement de personnage
    loadInventory(src)
    return Inv[src]
end

RegisterNetEvent('elyzea_inv:ready', function()
    local src = source
    if not identifier(src) then return end
    ensureLoaded(src)
    sync(src)
    broadcastDrops(src)
end)

AddEventHandler('elyzea:server:playerLoaded', function(src)
    src = tonumber(src)
    if not src then return end
    ensureLoaded(src)
    sync(src)
    broadcastDrops(src)
end)

AddEventHandler('elyzea:server:playerUnloaded', function(src)
    src = tonumber(src)
    if not src or not Inv[src] then return end
    save(src)
    Inv[src], Open[src], Viewing[src], Pending[src] = nil, nil, nil, nil
    TriggerClientEvent('elyzea_inv:unload', src)
end)

RegisterNetEvent('elyzea_inv:open', function()
    local src = source
    if not Inv[src] then return end
    Open[src] = true
    TriggerClientEvent('elyzea_inv:open', src, buildPayload(src))
end)

RegisterNetEvent('elyzea_inv:close', function()
    local src = source
    Open[src] = nil
    local v = Viewing[src]
    Viewing[src] = nil
    if v and v.kind == 'stash' and Containers[v.id] then
        saveContainer(Containers[v.id])
        if Containers[v.id].temporary then
            local empty = next(Containers[v.id].slots) == nil
            if empty then TriggerEvent('elyzea_inventory:stashEmptied', Containers[v.id].def) end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    save(src)
    for s, v in pairs(Viewing) do
        if v.kind == 'player' and v.target == src then Viewing[s] = nil TriggerClientEvent('elyzea_inv:closeContainer', s) end
    end
    Inv[src], Open[src], Rate[src], Viewing[src], Pending[src] = nil, nil, nil, nil, nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(Inv) do save(src) end
    for _, c in pairs(Containers) do saveContainer(c) end
end)

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `elyzea_stashes` (
        `id` varchar(120) NOT NULL,
        `items` longtext DEFAULT NULL,
        `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    -- Joueurs déjà connectés (redémarrage de la ressource)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src and identifier(src) then ensureLoaded(src) sync(src) end
    end
    while true do
        Wait(Config.SaveInterval * 1000)
        for src, inv in pairs(Inv) do if inv.dirty then save(src) end end
        for _, c in pairs(Containers) do if c.dirty then saveContainer(c) end end
        local now, changed = os.time(), false
        for id, d in pairs(Drops) do
            if now - d.created > Config.DropLifetime then Drops[id] = nil changed = true end
        end
        if changed then broadcastDrops() refreshOpen() end
    end
end)

-- ───────── API publique (exports) ─────────
-- Le premier argument accepte un id joueur (nombre), une table { id = src } ou l'id d'un coffre (texte).

local function srcOf(inv)
    if type(inv) == 'table' then inv = inv.id or inv.source end
    local n = tonumber(inv)
    return n and Inv[n] and n or nil
end

-- Stockage visé : joueur, ou coffre déclaré
local function storeOf(inv)
    local src = srcOf(inv)
    if src then return Inv[src], src end
    if type(inv) == 'string' or (type(inv) == 'table' and type(inv.id) == 'string') then
        local id = type(inv) == 'table' and inv.id or inv
        local c = Containers[id]
        if not c and StashDefs[id] then c = getStash(id, nil) end
        if c and c.kind == 'stash' then return c, nil end
    end
    return nil
end

local function after(st, src)
    if src then sync(src) elseif st then refreshViewers('stash', st.id) end
end

function RegisterUsableItem(name, cb)
    local t = type(cb)
    if type(name) ~= 'string' or (t ~= 'function' and t ~= 'table') then
        error('RegisterUsableItem(name, function(source, item) ... end) attendu', 2)
    end
    Usable[ResolveItemName(name) or name] = cb
end

API = {}

function API.AddItem(inv, name, count, metadata, slot)
    local st, src = storeOf(inv)
    if not st then return false, 'no_inventory' end
    local ok, res = addTo(st, name, count, metadata, slot)
    if ok then after(st, src) end
    return ok, res
end

function API.RemoveItem(inv, name, count, metadata, slot)
    local st, src = storeOf(inv)
    if not st then return false, 'no_inventory' end
    local ok, res = removeFrom(st, name, count, metadata, slot)
    if ok then after(st, src) end
    return ok, res
end

function API.CanCarryItem(inv, name, count, metadata)
    local st = storeOf(inv)
    name = ResolveItemName(name)
    if not st or not name then return false end
    count = math.floor(tonumber(count) or 1)
    if count < 1 then return false end
    return canCarryWeight(st, name, count) and planAdd(st, name, count, type(metadata) == 'table' and metadata or nil) ~= nil
end

function API.CanCarryItems(inv, list)
    local st = storeOf(inv)
    if not st or type(list) ~= 'table' then return false end
    local sim = { slots = Shared.Copy(st.slots), bag = st.bag, size = st.size, maxWeight = st.maxWeight }
    for _, e in ipairs(list) do
        local name, count = ResolveItemName(e[1] or e.name), math.floor(tonumber(e[2] or e.count) or 1)
        local md = e[3] or e.metadata
        if not name or count < 1 or not canCarryWeight(sim, name, count) then return false end
        local plan = planAdd(sim, name, count, md)
        if not plan then return false end
        for _, p in ipairs(plan) do
            if p.new then sim.slots[p.slot] = { name = name, count = p.add, metadata = md }
            else sim.slots[p.slot].count = sim.slots[p.slot].count + p.add end
        end
    end
    return true
end

function API.CanCarryWeight(inv, grams)
    local st = storeOf(inv)
    if not st then return false end
    return weightOf(st) + (tonumber(grams) or 0) <= capOf(st)
end

function API.GetSlot(inv, slot)
    local st = storeOf(inv)
    slot = st and int(slot, 1, st.size)
    if not st or not slot then return nil end
    return slotData(st, slot)
end

function API.SetMetadata(inv, slot, metadata)
    local st, src = storeOf(inv)
    slot = st and int(slot, 1, st.size)
    if not st or not slot or type(metadata) ~= 'table' then return false end
    local it = st.slots[slot]
    if not it then return false end
    it.metadata = Shared.Copy(metadata)
    st.dirty = true
    after(st, src)
    return true
end

function API.GetItem(inv, name, metadata, returnsCount)
    local st = storeOf(inv)
    name = ResolveItemName(name)
    local d = name and Items[name]
    if not st or not d then return returnsCount and 0 or nil end
    local count = countOf(st, name, type(metadata) == 'table' and metadata or nil)
    if returnsCount then return count end
    return { name = name, label = d.label, weight = d.weight, stack = d.stack == true, description = d.description, count = count }
end

function API.GetItemCount(inv, name, metadata)
    local st = storeOf(inv)
    name = ResolveItemName(name)
    if not st or not name then return 0 end
    return countOf(st, name, type(metadata) == 'table' and metadata or nil)
end

function API.Search(inv, kind, name, metadata)
    local st = storeOf(inv)
    if not st then return kind == 'count' and 0 or {} end
    if type(name) == 'table' then
        local out = {}
        for _, n in ipairs(name) do out[n] = API.Search(inv, kind, n, metadata) end
        return out
    end
    name = ResolveItemName(name) or name
    if kind == 'count' then return countOf(st, name, metadata) end
    local out = {}
    for i = 1, st.size do
        local it = st.slots[i]
        if it and it.name == name and Shared.MetaMatches(it.metadata, metadata) then out[#out + 1] = slotData(st, i) end
    end
    return out
end

function API.GetInventoryItems(inv)
    local st = storeOf(inv)
    if not st then return nil end
    local out = {}
    for i = 1, st.size do
        if st.slots[i] then out[i] = slotData(st, i) end
    end
    return out
end

function API.GetInventory(inv)
    local st, src = storeOf(inv)
    if not st then return nil end
    return { id = src or st.id, owner = src and st.id or st.owner, slots = st.size, weight = weightOf(st), maxWeight = capOf(st),
        label = st.label, items = API.GetInventoryItems(inv) }
end

function API.GetEmptySlot(inv)
    local st = storeOf(inv)
    return st and firstEmpty(st) or nil
end

function API.GetWeight(inv)
    local st = storeOf(inv)
    if not st then return 0, Config.BaseCapacity end
    return weightOf(st), capOf(st)
end

function API.ClearInventory(inv, keep)
    local st, src = storeOf(inv)
    if not st then return false end
    local keepSet = {}
    if type(keep) == 'string' then keepSet[keep] = true elseif type(keep) == 'table' then for _, k in ipairs(keep) do keepSet[k] = true end end
    for i = 1, st.size do
        local it = st.slots[i]
        if it and not keepSet[it.name] then st.slots[i] = nil end
    end
    st.dirty = true
    after(st, src)
    return true
end

-- Retire tout et le renvoie (saisie police, prison…) : { { name, count, metadata } }
function API.ConfiscateInventory(inv)
    local st, src = storeOf(inv)
    if not st then return {} end
    local out = {}
    for i = 1, st.size do
        local it = st.slots[i]
        if it then out[#out + 1] = { name = it.name, count = it.count, metadata = it.metadata } st.slots[i] = nil end
    end
    st.dirty = true
    after(st, src)
    return out
end

function API.Items(name)
    if name then return Items[ResolveItemName(name) or name] end
    return Items
end
API.GetItemList = function() return Items end

function API.UseSlot(inv, slot)
    local src = srcOf(inv)
    if not src then return false end
    local ok, err = UseSlot(src, int(slot, 1, Inv[src].size))
    sync(src, (not ok and err) and { type = 'error', text = Msg[err] or err } or nil)
    return ok
end

function API.RegisterUsableItem(name, cb) return RegisterUsableItem(name, cb) end

function API.SetBagEquipped(inv, state)
    local src = srcOf(inv)
    if not src then return false, 'no_inventory' end
    return setBagEquipped(src, state)
end

function API.IsBagEquipped(inv)
    local src = srcOf(inv)
    return src ~= nil and Inv[src].bag == true
end

function API.Refresh(inv)
    local src = srcOf(inv)
    if src then sync(src) end
end

-- Coffres, boutiques, fouille
API.RegisterStash = RegisterStash
API.RegisterShop = RegisterShop
API.RegisterStashAccess = RegisterStashAccess
function API.OpenInventory(src, kind, id) return ForceOpen(src, kind, id) end
API.forceOpenInventory = API.OpenInventory
function API.CloseInventory(src) TriggerClientEvent('elyzea_inv:forceClose', src) end
function API.ClearStash(id)
    local c = Containers[tostring(id)] or (StashDefs[tostring(id)] and getStash(id, nil))
    if not c then return false end
    c.slots = {}
    c.dirty = true
    saveContainer(c)
    refreshViewers('stash', c.id)
    return true
end
function API.GetStashItems(id)
    local c = Containers[tostring(id)] or (StashDefs[tostring(id)] and getStash(id, nil))
    if not c then return {} end
    local out = {}
    for i = 1, c.size do if c.slots[i] then out[#out + 1] = slotData(c, i) end end
    return out
end

for name, fn in pairs(API) do exports(name, fn) end

-- Prévient les ressources qu'elles peuvent enregistrer leurs objets utilisables
CreateThread(function()
    Wait(0)
    TriggerEvent('elyzea_inventory:ready')
end)

-- ───────── Commande admin ─────────
-- Permission :  add_ace group.admin command.giveitem allow
local function giveCommand(source, args)
    local target = tonumber(args[1])
    local name, count = ResolveItemName(args[2]), tonumber(args[3]) or 1
    local function reply(msg)
        if source == 0 then print(msg) else TriggerClientEvent('elyzea:client:notify', source, msg, 'inform') end
    end
    if not target or not args[2] then return reply('Usage : /giveitem [id joueur] [objet] [quantité]') end
    if not Inv[target] then return reply(('Le joueur %s n\'a pas d\'inventaire chargé.'):format(tostring(target))) end
    if not name then return reply(('Objet inconnu : %s'):format(args[2])) end
    local ok, err = addItem(target, name, count)
    sync(target, ok and { type = 'success', text = ('+%dx %s'):format(count, Items[name].label) } or { type = 'error', text = Msg[err] or err })
    reply(ok and ('%dx %s donné(s) à %d.'):format(count, Items[name].label, target) or ('Refusé : %s'):format(Msg[err] or err))
end
RegisterCommand('giveitem', giveCommand, true)
RegisterCommand('egive', giveCommand, true)

RegisterCommand('clearinv', function(source, args)
    local target = tonumber(args[1]) or source
    if not Inv[target] then return end
    API.ClearInventory(target)
end, true)
