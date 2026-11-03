-- Natives FiveM, elyzea_core et elyzea_inventory simulés (voir run_server_sim.py)
SIM = { players = {}, events = {}, client = {}, commands = {}, money = {}, items = {}, now = 0, errors = {} }
local _print = print
SIM.print = _print
print = function(...) if SIM.verbose then _print(...) end end

-- horloge et fils
local threads = {}
function GetGameTimer() return SIM.now end
function CreateThread(fn) threads[#threads + 1] = { co = coroutine.create(fn), wake = SIM.now } end
Citizen = { CreateThread = CreateThread, Wait = function(ms) coroutine.yield(ms or 0) end, Await = function(p) return p:await() end }
function Wait(ms) if coroutine.isyieldable() then coroutine.yield(ms or 0) end end
function SetTimeout(ms, fn) threads[#threads + 1] = { co = coroutine.create(function() Wait(ms) fn() end), wake = SIM.now } end
function SIM.step()
    local list = threads
    threads = {}
    for _, t in ipairs(list) do
        if coroutine.status(t.co) ~= 'dead' then
            if t.wake <= SIM.now then
                local ok, ms = coroutine.resume(t.co)
                if not ok then SIM.errors[#SIM.errors + 1] = tostring(ms) _print('  ERREUR (fil) : ' .. tostring(ms) .. '\n' .. debug.traceback(t.co)) end
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
function SIM.call(fn, ...)
    local args, res, done = table.pack(...), nil, false
    CreateThread(function() res = table.pack(fn(table.unpack(args, 1, args.n))) done = true end)
    local guard = 0
    while not done and guard < 2000 do SIM.step() guard = guard + 1 end
    if not done then error('appel bloqué') end
    return table.unpack(res, 1, res.n)
end

-- vecteurs
local V = {}
V.__index = V
V.__add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
function vector3(x, y, z) return setmetatable({ x = x + 0.0, y = y + 0.0, z = z + 0.0 }, V) end
function vector4(x, y, z, w) local v = vector3(x, y, z) v.w = w + 0.0 return v end

-- divers
function GetCurrentResourceName() return 'elyzea_pier' end
function IsDuplicityVersion() return true end
function GetResourceState(r) if r == 'elyzea_core' or r == 'elyzea_inventory' then return 'started' end return 'missing' end
function IsPlayerAceAllowed(src) return SIM.players[src] and SIM.players[src].admin == true end
function RegisterCommand(name, fn) SIM.commands[name] = fn end
GlobalState = {}
json = { encode = function() return '{}' end, decode = function() return {} end }

-- événements
function RegisterNetEvent(name, fn) if fn then AddEventHandler(name, fn) end end
function AddEventHandler(name, fn) SIM.events[name] = SIM.events[name] or {} table.insert(SIM.events[name], fn) end
function TriggerEvent(name, ...) for _, fn in ipairs(SIM.events[name] or {}) do fn(...) end end
function TriggerClientEvent(name, target, ...)
    SIM.client[target] = SIM.client[target] or {}
    table.insert(SIM.client[target], { name = name, args = table.pack(...) })
end
function SIM.emit(src, name, ...)
    local args = table.pack(...)
    return SIM.call(function() for _, fn in ipairs(SIM.events[name] or {}) do source = src fn(table.unpack(args, 1, args.n)) end end)
end
local rid = 0
-- appel serveur comme le ferait le client (Ely.callback) : renvoie la réponse
function SIM.rpc(src, name, ...)
    rid = rid + 1
    if not SIM.burst then SIM.now = SIM.now + 300 end   -- un humain ne clique pas plus vite
    SIM.emit(src, '__elycb:elyzea_pier:' .. name, 'elyzea_pier', rid, ...)
    local list = SIM.client[src] or {}
    for i = #list, 1, -1 do
        local e = list[i]
        if e.name == '__elycb_r:elyzea_pier' and e.args[1] == rid then return table.unpack(e.args, 2, e.args.n) end
    end
    return nil, 'aucune réponse'
end
function SIM.last(src, name)
    local list = SIM.client[src] or {}
    for i = #list, 1, -1 do if list[i].name == name then return table.unpack(list[i].args, 1, list[i].args.n) end end
end
function SIM.count(src, name)
    local n = 0
    for _, e in ipairs(SIM.client[src] or {}) do if e.name == name then n = n + 1 end end
    return n
end

-- joueurs
local function bag() return setmetatable({}, { __index = { set = function(self, k, v) rawset(self, k, v) end } }) end
function SIM.addPlayer(id, pos, cash, bank)
    SIM.players[id] = { pos = pos, health = 200, bucket = 0, vehicle = 0, state = bag(), name = 'Joueur ' .. id }
    SIM.money[id] = { cash = cash or 1000, bank = bank or 10000 }
    SIM.items[id] = {}
    SIM.client[id] = {}
end
function SIM.removePlayer(id)
    SIM.players[id] = nil
    SIM.call(function() for _, fn in ipairs(SIM.events.playerDropped or {}) do source = id fn('quit') end end)
end
function SIM.move(id, v) SIM.players[id].pos = v end
function GetPlayers() local o = {} for id in pairs(SIM.players) do o[#o + 1] = tostring(id) end return o end
function GetPlayerName(id) local p = SIM.players[tonumber(id)] return p and p.name or nil end
function GetPlayerPed(id) return SIM.players[tonumber(id)] and (tonumber(id) + 1000) or 0 end
function GetEntityCoords(ped) local p = SIM.players[ped - 1000] return p and p.pos or vector3(0, 0, 0) end
function GetEntityHeading() return 90.0 end
function GetEntityHealth(ped) local p = SIM.players[ped - 1000] return p and p.health or 0 end
function GetVehiclePedIsIn(ped) local p = SIM.players[ped - 1000] return p and p.vehicle or 0 end
function GetPlayerRoutingBucket(id) local p = SIM.players[tonumber(id)] return p and p.bucket or 0 end
function Player(id) local p = SIM.players[tonumber(id)] return { state = p and p.state or bag() } end

-- elyzea_core et elyzea_inventory
local function pl(src) return SIM.players[tonumber(src)] end
exports = {
    elyzea_core = {
        GetPlayerData = function(_, src) local p = pl(src) return p and { citizenid = 'CID' .. src, charinfo = { firstname = 'Joueur', lastname = tostring(src) } } or nil end,
        GetMoney = function(_, src, acc) return (SIM.money[tonumber(src)] or {})[acc] or 0 end,
        RemoveMoney = function(_, src, acc, n) local m = SIM.money[tonumber(src)] if not m or m[acc] < n then return false end m[acc] = m[acc] - n return true end,
        AddMoney = function(_, src, acc, n) local m = SIM.money[tonumber(src)] if not m then return false end m[acc] = m[acc] + n return true end,
        Notify = function() end,
    },
    elyzea_inventory = {
        GetItemCount = function(_, src, name) return (SIM.items[tonumber(src)] or {})[name] or 0 end,
        CanCarryItem = function(_, src, name, n) return not SIM.full end,
        AddItem = function(_, src, name, n)
            if SIM.full or SIM.addFails then return false end
            local it = SIM.items[tonumber(src)] it[name] = (it[name] or 0) + n return true
        end,
        RemoveItem = function(_, src, name, n)
            local it = SIM.items[tonumber(src)]
            if not it or (it[name] or 0) < n then return false end
            it[name] = it[name] - n
            SIM.removed = (SIM.removed or 0) + n
            return true
        end,
    },
}
setmetatable(exports, { __call = function() end })
