-- Environnement simulé : temps, joueurs, inventaire, base de données (tables en mémoire), exports
_PRINT = print
NOW = 1800000000
os.time = function() return NOW end
local realRandom = math.random
RAND = nil
math.random = function(a, b) if RAND then return RAND(a, b) end if a and b then return realRandom(a, b) end return realRandom(a) end
THREADS = {}
function CreateThread(fn) local co = coroutine.create(fn) THREADS[#THREADS + 1] = co local ok, e = coroutine.resume(co) if not ok then _PRINT('thread: ' .. tostring(e)) end end
function Wait() coroutine.yield() end
function PUMP() for _ = 1, 4 do for _, co in ipairs(THREADS) do if coroutine.status(co) == 'suspended' then coroutine.resume(co) end end end end
function SetTimeout() end
function print() end
function GetHashKey(s) return s end
function GetResourceState() return 'started' end
function GetInvokingResource() return 'test' end
HANDLERS = {}
function AddEventHandler(ev, fn) HANDLERS[ev] = HANDLERS[ev] or {} table.insert(HANDLERS[ev], fn) end
function RegisterNetEvent(ev, fn) if fn then AddEventHandler(ev, fn) end end
function FIRE(ev, src, ...) source = src for _, fn in ipairs(HANDLERS[ev] or {}) do fn(...) end end
SENT = {}
function TriggerClientEvent(ev, target, ...) SENT[#SENT + 1] = { ev = ev, target = target, args = { ... } } end
function TriggerEvent() end
function exports(name, fn) EXPORTED = EXPORTED or {} EXPORTED[name] = fn end
-- joueurs
PLAYERS = {}   -- [src] = { pos = {x,y,z}, cid, inv = {}, hp = 200, state = {}, admin = bool, police = bool, cash = 0 }
function GetPlayers() local o = {} for s in pairs(PLAYERS) do o[#o + 1] = tostring(s) end return o end
function GetPlayerName(s) return PLAYERS[s] and ('Joueur' .. s) or nil end
function GetPlayerPed(s) return PLAYERS[s] and s or 0 end
function GetEntityCoords(p) local pl = PLAYERS[p] return pl and setmetatable({ x = pl.pos[1], y = pl.pos[2], z = pl.pos[3] }, {}) or nil end
function GetEntityHealth(p) return PLAYERS[p] and PLAYERS[p].hp or 0 end
function SetEntityCoords() end
function Player(s) return { state = (PLAYERS[s] or {}).state or {} } end
-- Ely (callbacks)
CB = {}
Ely = { callback = { register = function(name, fn) CB[name] = fn end } }
function CALL(name, src, ...) return CB['elyzea_drogues:' .. name](src, ...) end
-- inventaire
ITEMS_DEF = {}
local inv = {
    GetItemCount = function(_, s, it) return (PLAYERS[s].inv[it] or 0) end,
    RemoveItem = function(_, s, it, n) local h = PLAYERS[s].inv[it] or 0 if h < n then return false end PLAYERS[s].inv[it] = h - n return true end,
    AddItem = function(_, s, it, n) if PLAYERS[s].full then return false end PLAYERS[s].inv[it] = (PLAYERS[s].inv[it] or 0) + n return true end,
    CanCarryItems = function(_, s) return not PLAYERS[s].full end,
    Items = function(_, it) if it == 'nope_item' then return nil end return { label = 'L:' .. it } end,
    RegisterUsableItem = function(_, it, fn) USABLE = USABLE or {} USABLE[it] = fn end,
    RegisterShop = function(_, id, d) SHOP = d end,
    OpenInventory = function(_, s, k, id) OPENED = { s, k, id } return true end,
}
local core = {
    Notify = function(_, s, msg) NOTES = NOTES or {} NOTES[#NOTES + 1] = msg end,
    GetPlayerData = function(_, s) local p = PLAYERS[s] return p and { citizenid = p.cid, charinfo = { firstname = 'P', lastname = tostring(s) }, metadata = { hunger = 50, thirst = 50, stress = 50 } } end,
    AddNeeds = function() return true end,
    AddMoney = function(_, s, acc, n) PLAYERS[s].cash = (PLAYERS[s].cash or 0) + n return true end,
}
EMS = {}
exports = setmetatable({}, { __call = function(_, name, fn) EXPORTED = EXPORTED or {} EXPORTED[name] = fn end, __index = function(_, res)
    if res == 'elyzea_inventory' then return inv end
    if res == 'elyzea_core' then return core end
    if res == 'admin_menu' then return { HasPermission = function(_, s, perm) return PLAYERS[s] and ((PLAYERS[s].admin and perm == 'drugs_manage') or (PLAYERS[s].effects and perm == 'drugs_effects')) end,
        -- props de l'éditeur de map avec un rôle (four / plan de travail à gâteaux)
        GetPropsByRole = function(_, role) local out = {} for _, p in ipairs(EDITOR_PROPS or {}) do if p.role == role then out[#out + 1] = p end end return out end } end
    if res == 'elyzea_police' then return { IsOnDuty = function(_, s) return PLAYERS[s] and PLAYERS[s].police == true end } end
    if res == 'elyzea_ems' then return { RecordConsumption = function(_, s, k) EMS[#EMS + 1] = { s, k } return true end } end
    return setmetatable({}, { __index = function() return function() end end })
end })
-- json
json = { encode = function(t) JSON_LAST = t return 'json' end, decode = function(s) return JSON_STORE and JSON_STORE[s] end }
-- base de données en mémoire
DB = { kv = {}, sites = {}, plants = {}, logs = {}, nextSite = 1, nextPlant = 1 }
local function handle(kind, q, p)
    p = p or {}
    if q:find('^%s*CREATE') or q:find('^%s*ALTER') then return {} end
    if q:find('SHOW COLUMNS') then return { {} } end
    if q:find('elyzea_drogues_settings') then
        local k = q:match("'(%w+)'")
        if q:find('^%s*SELECT') then local v = DB.kv[k] return v end
        if q:find('^%s*INSERT') then DB.kv[k] = p[1] return 1 end
    end
    if q:find('drogues_logs') then
        if q:find('^%s*INSERT') then DB.logs[#DB.logs + 1] = p return #DB.logs end
        return {}
    end
    if q:find('drogues_sites') then
        if q:find('^%s*SELECT') then local o = {} for _, r in pairs(DB.sites) do o[#o + 1] = r end return o end
        if q:find('^%s*INSERT') then local id = DB.nextSite DB.nextSite = id + 1
            DB.sites[id] = { id = id, type = p[1], model = p[2], x = p[3], y = p[4], z = p[5], h = p[6], rx = p[7], ry = p[8], created_by = p[9] } return id end
        if q:find('^%s*UPDATE') then local r = DB.sites[p[9]] if r then r.type, r.model, r.x, r.y, r.z, r.h = p[1], p[2], p[3], p[4], p[5], p[6] end return 1 end
        if q:find('^%s*DELETE') then DB.sites[p[1]] = nil return 1 end
    end
    if q:find('drogues_plants') then
        if q:find('^%s*SELECT') then local o = {} for _, r in pairs(DB.plants) do o[#o + 1] = r end return o end
        if q:find('^%s*INSERT') then local id = DB.nextPlant DB.nextPlant = id + 1
            DB.plants[id] = { id = id, owner_cid = p[1], owner_name = p[2], x = p[3], y = p[4], z = p[5], h = p[6], last_at = p[7], progress = 0, water = 0, health = 100, lamp = 0, fert = 0, dead = 0 } return id end
        if q:find('^%s*UPDATE') then local r = DB.plants[p[12]] if r then r.variety, r.planted_at, r.progress, r.water, r.health, r.lamp, r.fert, r.dead, r.dead_at, r.last_at, r.watered_at =
            p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9], p[10], p[11] end return 1 end
        if q:find('^%s*DELETE') then DB.plants[p[1]] = nil return 1 end
    end
    return {}
end
local function method(kind)
    return setmetatable({ await = function(q, p) local r = handle(kind, q, p) if kind == 'scalar' and type(r) == 'table' then return nil end return r end },
        { __call = function(_, q, p, cb) if type(p) == 'function' then cb, p = p, nil end local r = handle(kind, q, p) if cb then cb(r) end end })
end
MySQL = { ready = { await = function() end }, query = method('query'), insert = method('insert'), update = method('update'), scalar = method('scalar'), single = method('single') }
