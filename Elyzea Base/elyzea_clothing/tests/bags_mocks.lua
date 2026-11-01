-- Imitations pour run_bags_sim.py : base MariaDB réelle (via Python), inventaire + coffres, joueurs, minuteries
json = { encode = py_json_encode, decode = py_json_decode }
local function both(fn) return setmetatable({ await = fn }, { __call = function(_, s, a) return fn(s, a) end }) end
MySQL = {
    query = both(function(s, a) return py_query(s, a) end), single = both(function(s, a) return py_single(s, a) end),
    scalar = both(function(s, a) return py_scalar(s, a) end), update = both(function(s, a) return py_update(s, a) end),
    insert = both(function(s, a) return py_insert(s, a) end), ready = { await = function() end },
}
-- Minuteries (cadeaux qui expirent)
TIMERS = {}
function SetTimeout(ms, fn) TIMERS[#TIMERS + 1] = { at = NOW + ms, fn = fn } end
function ADVANCE(ms)
    NOW = NOW + ms
    local due = {}
    for i = #TIMERS, 1, -1 do if TIMERS[i].at <= NOW then due[#due + 1] = TIMERS[i].fn table.remove(TIMERS, i) end end
    for _, f in ipairs(due) do f() end
end
-- Joueurs : position, nom, personnage
POS, ONLINE, CID = {}, {}, {}
local vmeta = { __sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, { __len = function(v) return math.sqrt(v.x ^ 2 + v.y ^ 2 + v.z ^ 2) end }) end }
vector3 = function(x, y, z) return setmetatable({ x = x, y = y, z = z }, vmeta) end
function GetEntityCoords(e) return POS[e] or vector3(0, 0, 0) end
function GetPlayerName(s) if ONLINE[s] == false then return nil end return 'Joueur' .. s end
function GetEntityHealth() return 200 end
-- Inventaire imité : joueurs (src) et coffres (« trunk:PLAQUE »), avec métadonnées et place limitée
INVS = {}
local function store(h) INVS[h] = INVS[h] or { slots = {}, size = 10 } return INVS[h] end
local function matches(md, want)
    if want == nil then return true end
    md = md or {}
    for k, v in pairs(want) do if md[k] ~= v then return false end end
    return true
end
local function copy(t) if type(t) ~= 'table' then return t end local o = {} for k, v in pairs(t) do o[k] = copy(v) end return o end
local function used(st) local n = 0 for i = 1, st.size do if st.slots[i] then n = n + 1 end end return n end
USABLE = {}
local inv = {}
function inv.Items(_, name) return { name = name } end
function inv.GetItemCount(_, h, name, md)
    local st, n = store(h), 0
    for i = 1, st.size do local it = st.slots[i] if it and it.name == name and matches(it.metadata, md) then n = n + it.count end end
    return n
end
function inv.Search(_, h, kind, name, md)
    local st, out = store(h), {}
    for i = 1, st.size do local it = st.slots[i] if it and it.name == name and matches(it.metadata, md) then out[#out + 1] = { slot = i, name = it.name, count = it.count, metadata = copy(it.metadata) } end end
    return out
end
function inv.CanCarryItem(_, h, name, n) local st = store(h) return used(st) < st.size end
function inv.CanCarryItems(_, h, list) local st = store(h) return used(st) + #list <= st.size end
function inv.AddItem(_, h, name, n, md)
    local st = store(h)
    for i = 1, st.size do if not st.slots[i] then st.slots[i] = { name = name, count = n or 1, metadata = copy(md) or {} } return true end end
    return false, 'full'
end
function inv.RemoveItem(_, h, name, n, md)
    local st = store(h)
    for i = st.size, 1, -1 do local it = st.slots[i] if it and it.name == name and matches(it.metadata, md) then st.slots[i] = nil return true end end
    return false
end
function inv.SetMetadata(_, h, slot, md) local it = store(h).slots[slot] if it then it.metadata = copy(md) end return true end
function inv.SetBagEquipped() return true end
function inv.RegisterUsableItem(_, name, fn) USABLE[name] = fn end
VEH = {}   -- [netId] = { plate, dist, locked, keys, size }
function inv.PrepareTrunk(_, src, netId, class)
    local v = VEH[tonumber(netId) or -1]
    if not v then return nil, 'Véhicule introuvable.' end
    if v.dist > 4.0 then return nil, 'Trop loin.' end
    if v.locked and not v.keys then return nil, 'Le véhicule est verrouillé.' end
    local id = 'trunk:' .. v.plate
    store(id).size = v.size or 10
    return id, v.keys
end
INV = inv
local prev = exports
exports = setmetatable({}, { __call = function() end, __index = function(_, k)
    if k == 'elyzea_inventory' then return inv end
    if k == 'elyzea_core' then return setmetatable({}, { __index = function(_, f)
        if f == 'GetMoney' then return function(_, src) return MONEY[src] or 0 end end
        if f == 'RemoveMoney' then return function(_, src, kind, n) if (MONEY[src] or 0) < n then return false end MONEY[src] = MONEY[src] - n return true end end
        if f == 'AddMoney' then return function(_, src, kind, n) MONEY[src] = (MONEY[src] or 0) + n return true end end
        if f == 'GetCitizenId' then return function(_, src) return CID[src] end end
        if f == 'GetCharName' then return function(_, src) return 'Perso ' .. src end end
        return function() return true end
    end }) end
    return prev[k]
end })
function GetResourceState() return 'started' end
-- Événements : plusieurs gestionnaires par nom (playerDropped est utilisé par plusieurs fichiers)
EV = {}
function RegisterNetEvent(ev, fn) if fn then EV[ev] = EV[ev] or {} table.insert(EV[ev], fn) end end
function AddEventHandler(ev, fn) EV[ev] = EV[ev] or {} table.insert(EV[ev], fn) end
FIRE = function(ev, src, ...) source = src local r for _, f in ipairs(EV[ev] or {}) do r = f(...) source = src end return r end
local KVP = {}
function GetResourceKvpString(k) return KVP[k] end
function SetResourceKvp(k, v) KVP[k] = v end
