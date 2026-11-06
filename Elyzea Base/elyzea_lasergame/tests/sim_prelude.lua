-- =====================================================================
--  Natives FiveM simulées pour exécuter le code serveur hors jeu (voir run_server_sim.py)
-- =====================================================================
local ROOT = ...
SIM = { players = {}, events = {}, client = {}, commands = {}, entities = {}, nextEnt = 50000, money = {}, admins = {}, cids = {} }

-- ---------------------------------------------------------------- horloge et fils
SIM.now = 0
local threads = {}
function GetGameTimer() return SIM.now end
function CreateThread(fn) threads[#threads + 1] = { co = coroutine.create(fn), wake = SIM.now } end
Citizen = { CreateThread = CreateThread, Wait = function(ms) coroutine.yield(ms or 0) end }
function Wait(ms)
    if not coroutine.isyieldable() then return end
    coroutine.yield(ms or 0)
end
function SetTimeout(ms, fn) threads[#threads + 1] = { co = coroutine.create(function() Wait(ms) fn() end), wake = SIM.now } end
local BASE = 1762000000
local realTime = os.time
os.time = function(t) if t then return realTime(t) end return BASE + math.floor(SIM.now / 1000) end
SIM.errors = {}
function SIM.step()
    local list = threads
    threads = {}
    for _, t in ipairs(list) do
        if coroutine.status(t.co) ~= 'dead' then
            if t.wake <= SIM.now then
                local ok, ms = coroutine.resume(t.co)
                if not ok then SIM.errors[#SIM.errors + 1] = tostring(ms) SIM.print('  ERREUR (fil) : ' .. tostring(ms) .. '\n' .. debug.traceback(t.co)) end
                if coroutine.status(t.co) ~= 'dead' then t.wake = SIM.now + (ms or 0) threads[#threads + 1] = t end
            else threads[#threads + 1] = t end
        end
    end
end
function SIM.run(ms)
    local stop = SIM.now + ms
    while SIM.now < stop do SIM.step() SIM.now = SIM.now + 50 end
    SIM.step()
end
-- exécute une fonction qui peut appeler Wait (RPC, événements) dans un fil et attend sa fin
function SIM.call(fn, ...)
    local args = table.pack(...)
    local res, done
    CreateThread(function() res = table.pack(fn(table.unpack(args, 1, args.n))) done = true end)
    local guard = 0
    while not done and guard < 4000 do SIM.step() if not done then SIM.now = SIM.now + 10 end guard = guard + 1 end
    if not done then error('appel bloqué') end
    return table.unpack(res, 1, res.n)
end

-- ---------------------------------------------------------------- vecteurs
local V = {}
V.__index = V
V.__add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__mul = function(a, k) return vector3(a.x * k, a.y * k, a.z * k) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
function vector3(x, y, z) return setmetatable({ x = x + 0.0, y = y + 0.0, z = z + 0.0 }, V) end
function vector4(x, y, z, w) local v = vector3(x, y, z) v.w = w + 0.0 return v end

-- ---------------------------------------------------------------- json, fichiers, divers
json = { encode = function(t) return py_json_encode(t) end, decode = function(s) return py_json_decode(s) end }
function GetCurrentResourceName() return 'elyzea_lasergame' end
function IsDuplicityVersion() return true end
function LoadResourceFile(_, path) return py_read(path) end
function SaveResourceFile() return true end
function GetResourceState(r) if r == 'elyzea_core' or r == 'admin_menu' then return 'started' end return 'missing' end
function GetConvar(_, d) return d end
function PerformHttpRequest() end
function IsPlayerAceAllowed() return false end
function GetHashKey(s) local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end return h end
function RegisterCommand(name, fn) SIM.commands[name] = fn end
GlobalState = {}
local quiet = true
local _print = print
SIM.print = _print
print = function(...) if not quiet then _print(...) end end
function SIM.verbose(on) quiet = not on end
SIM.print = _print

-- ---------------------------------------------------------------- événements
function RegisterNetEvent(name, fn) if fn then AddEventHandler(name, fn) end end
function AddEventHandler(name, fn)
    SIM.events[name] = SIM.events[name] or {}
    table.insert(SIM.events[name], fn)
end
function TriggerEvent(name, ...) for _, fn in ipairs(SIM.events[name] or {}) do fn(...) end end
-- un client envoie un événement au serveur
function SIM.emit(src, name, ...)
    local args = table.pack(...)
    return SIM.call(function()
        for _, fn in ipairs(SIM.events[name] or {}) do
            source = src
            fn(table.unpack(args, 1, args.n))
        end
    end)
end
function TriggerClientEvent(name, target, ...)
    local targets = {}
    if target == -1 then for id in pairs(SIM.players) do targets[#targets + 1] = id end else targets = { target } end
    for _, t in ipairs(targets) do
        SIM.client[t] = SIM.client[t] or {}
        table.insert(SIM.client[t], { name = name, args = table.pack(...) })
    end
end
-- derniers événements client reçus par un joueur
function SIM.last(src, name)
    local list = SIM.client[src] or {}
    for i = #list, 1, -1 do if list[i].name == name then return table.unpack(list[i].args, 1, list[i].args.n) end end
    return nil
end
function SIM.count(src, name)
    local n = 0
    for _, e in ipairs(SIM.client[src] or {}) do if e.name == name then n = n + 1 end end
    return n
end
function SIM.clear(src) SIM.client[src] = {} end

-- appel RPC comme le ferait le client : renvoie les valeurs de réponse
function SIM.rpc(src, name, ...)
    local before = #(SIM.client[src] or {})
    SIM.emit(src, 'elyzea_lasergame:rpc', name, 777, ...)
    local list = SIM.client[src] or {}
    for i = #list, before + 1, -1 do
        if list[i].name == 'elyzea_lasergame:rpcr' then return table.unpack(list[i].args, 2, list[i].args.n) end
    end
    return nil, 'aucune réponse'
end

-- ---------------------------------------------------------------- joueurs
local function stateBag()
    local st = {}
    return setmetatable(st, { __index = { set = function(self, k, v) rawset(self, k, v) end } })
end
function SIM.addPlayer(id, first, last, cash, pos)
    SIM.players[id] = { id = id, name = first .. ' ' .. last, first = first, last = last, cid = 'CID' .. id, bucket = 0,
        pos = pos or vector3(-1256.0, -1440.0, 4.4), heading = 90.0, health = 180, armor = 25, state = stateBag() }
    SIM.money[id] = { bank = cash or 100000, cash = 0 }
    SIM.cids['CID' .. id] = id
    SIM.client[id] = {}
end
function SIM.removePlayer(id)
    SIM.players[id] = nil
    SIM.call(function() for _, fn in ipairs(SIM.events.playerDropped or {}) do source = id fn('quit') end end)
end
function GetPlayers() local out = {} for id in pairs(SIM.players) do out[#out + 1] = tostring(id) end table.sort(out) return out end
function GetPlayerName(id) local p = SIM.players[tonumber(id)] return p and p.name or nil end
function GetPlayerPed(id) return SIM.players[tonumber(id)] and (tonumber(id) + 1000) or 0 end
function Player(id) local p = SIM.players[tonumber(id)] return { state = p and p.state or stateBag() } end
function GetPlayerRoutingBucket(id) local p = SIM.players[tonumber(id)] return p and p.bucket or 0 end
function SetPlayerRoutingBucket(id, b) local p = SIM.players[tonumber(id)] if p then p.bucket = b end end
function SetRoutingBucketPopulationEnabled() end
function SetRoutingBucketEntityLockdownMode() end
function GetPlayerIdentifierByType(id) return 'license:' .. id end
function SIM.move(id, x, y, z) SIM.players[id].pos = vector3(x, y, z) end

-- ---------------------------------------------------------------- entités (peds des joueurs)
function GetEntityCoords(ent)
    if ent > 1000 and ent < 50000 then local p = SIM.players[ent - 1000] return p and p.pos or vector3(0, 0, 0) end
    local e = SIM.entities[ent]
    return e and e.pos or vector3(0, 0, 0)
end
function GetEntityHeading(ent) local p = SIM.players[ent - 1000] return p and p.heading or 0.0 end
function GetEntityHealth(ent) local p = SIM.players[ent - 1000] return p and p.health or 0 end
function GetPedArmour(ent) local p = SIM.players[ent - 1000] return p and p.armor or 0 end
function CreatePed(_, model, x, y, z, h)
    SIM.nextEnt = SIM.nextEnt + 1
    SIM.entities[SIM.nextEnt] = { pos = vector3(x, y, z), model = model, state = stateBag(), net = SIM.nextEnt - 40000 }
    return SIM.nextEnt
end
function DoesEntityExist(ent) return SIM.entities[ent] ~= nil end
function DeleteEntity(ent) SIM.entities[ent] = nil end
function SetEntityRoutingBucket(ent, b) if SIM.entities[ent] then SIM.entities[ent].bucket = b end end
function SetEntityOrphanMode() end
function NetworkGetNetworkIdFromEntity(ent) return SIM.entities[ent] and SIM.entities[ent].net or 0 end
function Entity(ent) return { state = SIM.entities[ent] and SIM.entities[ent].state or stateBag() } end

-- ---------------------------------------------------------------- base de données (SQLite via Python)
local function method(kind)
    local m = setmetatable({}, { __call = function(_, sql, params, cb)
        local r = py_sql(kind, sql, params)
        if type(params) == 'function' then params(r) elseif cb then cb(r) end
        return r
    end })
    m.await = function(sql, params) return py_sql(kind, sql, params) end
    return m
end
MySQL = { query = method('query'), single = method('single'), scalar = method('scalar'), insert = method('insert'), update = method('update'),
    ready = setmetatable({ await = function() end }, { __call = function(_, cb) cb() end }) }

-- ---------------------------------------------------------------- ressources Elyzea simulées
local function player(src) return SIM.players[tonumber(src)] end
exports = {
    elyzea_core = {
        GetPlayerData = function(_, src)
            local p = player(src)
            if not p then return nil end
            return { citizenid = p.cid, charinfo = { firstname = p.first, lastname = p.last } }
        end,
        GetMoney = function(_, src, acc) return (SIM.money[tonumber(src)] or {})[acc] or 0 end,
        RemoveMoney = function(_, src, acc, amount)
            local m = SIM.money[tonumber(src)]
            if not m or m[acc] < amount then return false end
            m[acc] = m[acc] - amount
            return true
        end,
        AddMoney = function(_, src, acc, amount)
            local m = SIM.money[tonumber(src)]
            if not m then return false end
            m[acc] = m[acc] + amount
            return true
        end,
    },
    admin_menu = {
        HasPermission = function(_, src) return SIM.admins[tonumber(src)] == true end,
        AddLog = function() end,
        GetLaserGameNpcs = function() return {} end,
    },
}
-- exports(nom, fn) de la ressource testée : gardés pour appeler les vrais exports (ceux qu'admin_menu utilise)
SIM.exports = {}
setmetatable(exports, { __call = function(_, name, fn) SIM.exports[name] = fn end })
