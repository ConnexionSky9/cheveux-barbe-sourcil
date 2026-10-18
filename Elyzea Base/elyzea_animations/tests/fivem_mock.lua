-- =====================================================================
--  Simulation minimale de l'environnement FiveM pour tester elyzea_animations hors jeu.
--  Ce n'est PAS le jeu : les natives sont remplacées par des fonctions qui imitent
--  leur comportement documenté. Sert à tester la logique (invitations, sessions, sécurité).
-- =====================================================================
Mock = { now = 0, timers = {}, threads = {}, sent = {}, handlers = {}, commands = {}, kvp = {}, players = {}, aces = {}, convars = { onesync = 'on' }, prints = {} }

-- Vecteurs
local V = {}
V.__index = V
V.__add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__mul = function(a, b) if type(a) == 'number' then a, b = b, a end return vector3(a.x * b, a.y * b, a.z * b) end
V.__div = function(a, b) return vector3(a.x / b, a.y / b, a.z / b) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end

-- Temps, threads, minuteries
function GetGameTimer() return Mock.now end
function SetTimeout(ms, fn) Mock.timers[#Mock.timers + 1] = { at = Mock.now + ms, fn = fn } end
function CreateThread(fn)
    local co = coroutine.create(fn)
    Mock.threads[#Mock.threads + 1] = { co = co, at = Mock.now }
end
Citizen = { CreateThread = CreateThread, Wait = function(ms) coroutine.yield(ms or 0) end }
-- promise / Citizen.Await (fournis par FiveM)
promise = { new = function()
    local p = { done = false }
    function p:resolve(v) self.done, self.value = true, v end
    return p
end }
function Citizen.Await(p)
    while not p.done do coroutine.yield(1) end
    return p.value
end
function Wait(ms) coroutine.yield(ms or 0) end

local function runDue()
    local progressed = true
    while progressed do
        progressed = false
        for i = #Mock.timers, 1, -1 do
            local t = Mock.timers[i]
            if t.at <= Mock.now then table.remove(Mock.timers, i) t.fn() progressed = true end
        end
        for i = #Mock.threads, 1, -1 do
            local th = Mock.threads[i]
            if th and th.at <= Mock.now then
                local ok, ms = coroutine.resume(th.co)
                if not ok then error('thread : ' .. tostring(ms)) end
                if coroutine.status(th.co) == 'dead' then table.remove(Mock.threads, i)
                else th.at = Mock.now + math.max(ms or 0, 1) end
                progressed = true
            end
        end
    end
end
-- Avance le temps virtuel par pas de 50 ms
function Mock.Advance(ms)
    local target = Mock.now + ms
    runDue()
    while Mock.now < target do
        Mock.now = math.min(target, Mock.now + 50)
        runDue()
    end
end

-- Réseau
local function addHandler(name, fn)
    Mock.handlers[name] = Mock.handlers[name] or {}
    table.insert(Mock.handlers[name], fn)
end
function RegisterNetEvent(name, fn) if fn then addHandler(name, fn) end end
function AddEventHandler(name, fn) addHandler(name, fn) end
function Mock.Fire(name, ...)
    for _, fn in ipairs(Mock.handlers[name] or {}) do fn(...) end
end
function TriggerClientEvent(name, target, ...) Mock.sent[#Mock.sent + 1] = { name = name, target = target, args = { ... } } end
function Mock.Call(src, name, ...)
    assert(Mock.handlers[name], 'événement inconnu : ' .. name)
    source = src
    Mock.Fire(name, ...)
    source = nil
end
function Mock.Sent(name, target)
    local out = {}
    for _, m in ipairs(Mock.sent) do if m.name == name and (target == nil or m.target == target) then out[#out + 1] = m end end
    return out
end
function Mock.Clear() Mock.sent = {} end
function RegisterCommand(name, fn) Mock.commands[name] = fn end

-- Joueurs
function Mock.AddPlayer(id, x, y, opts)
    opts = opts or {}
    Mock.players[id] = { name = 'Joueur' .. id, ped = 1000 + id, pos = vector3(x, y, 0.0), health = opts.health or 200,
        vehicle = 0, bucket = 0, state = {} }
end
function Mock.Move(id, x, y) Mock.players[id].pos = vector3(x, y, 0.0) end
function Mock.Drop(id)
    Mock.players[id] = nil
    source = id
    Mock.Fire('playerDropped', 'Exiting')
    source = nil
end
local function byPed(ped) for _, p in pairs(Mock.players) do if p.ped == ped then return p end end end
function GetPlayerName(id) local p = Mock.players[tonumber(id)] return p and p.name or nil end
function GetPlayerPed(id) local p = Mock.players[tonumber(id)] return p and p.ped or 0 end
function DoesEntityExist(ped) return byPed(ped) ~= nil end
function GetEntityHealth(ped) local p = byPed(ped) return p and p.health or 0 end
function GetEntityCoords(ped) local p = byPed(ped) return p and p.pos or vector3(0, 0, 0) end
function GetVehiclePedIsIn(ped) local p = byPed(ped) return p and p.vehicle or 0 end
function GetPlayerRoutingBucket(id) local p = Mock.players[tonumber(id)] return p and p.bucket or 0 end
function Player(id) local p = Mock.players[tonumber(id)] return { state = p and p.state or {} } end
function IsPlayerAceAllowed(id, ace) return Mock.aces[tonumber(id) .. ':' .. ace] == true end
function GetCurrentResourceName() return 'elyzea_animations' end
function GetResourceKvpString(k) return Mock.kvp[k] end
function SetResourceKvp(k, v) Mock.kvp[k] = v end
function GetConvar(k, d) return Mock.convars[k] or d end
-- exports('Nom', fn) enregistre ; exports.ressource:Nom() appelle Mock.foreign[ressource][Nom] s'il existe
Mock.exported, Mock.foreign, Mock.resources = {}, {}, { elyzea_animations = 'started' }
exports = setmetatable({}, {
    __call = function(_, name, fn) Mock.exported[name] = fn end,
    __index = function(_, res)
        return setmetatable({}, { __index = function(_, fname)
            return function(_, ...) local f = Mock.foreign[res] and Mock.foreign[res][fname] if f then return f(...) end end
        end })
    end,
})
function GetResourceState(res) return Mock.resources[res] or 'missing' end

local rawprint = print
function print(...)
    local parts = {}
    for i = 1, select('#', ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    Mock.prints[#Mock.prints + 1] = table.concat(parts, ' ')
end
Mock.rawprint = rawprint

-- JSON minimal (FiveM fournit json.encode / json.decode)
json = {}
local function enc(v)
    local t = type(v)
    if t == 'nil' then return 'null' end
    if t == 'boolean' or t == 'number' then return tostring(v) end
    if t == 'string' then return '"' .. v:gsub('[%c"\\]', function(c) return string.format('\\u%04x', c:byte()) end) .. '"' end
    if t == 'table' then
        if #v > 0 or next(v) == nil then
            local out = {}
            for _, x in ipairs(v) do out[#out + 1] = enc(x) end
            if #out > 0 or next(v) == nil then return '[' .. table.concat(out, ',') .. ']' end
        end
        local out = {}
        for k, x in pairs(v) do out[#out + 1] = enc(tostring(k)) .. ':' .. enc(x) end
        return '{' .. table.concat(out, ',') .. '}'
    end
    error('json : type ' .. t)
end
json.encode = enc
function json.decode(s)
    if s == nil then return nil end
    local i = 1
    local function ws() i = s:find('[^%s]', i) or #s + 1 end
    local val
    local function str()
        local j, out = i + 1, {}
        while true do
            local c = s:sub(j, j)
            if c == '' then error('json invalide', 0) end   -- comme FiveM : texte abîmé = erreur
            if c == '"' then i = j + 1 return table.concat(out) end
            if c == '\\' then
                local n = s:sub(j + 1, j + 1)
                if n == 'u' then out[#out + 1] = utf8.char(tonumber(s:sub(j + 2, j + 5), 16)) j = j + 6
                else out[#out + 1] = ({ n = '\n', t = '\t', r = '\r' })[n] or n j = j + 2 end
            else out[#out + 1] = c j = j + 1 end
        end
    end
    function val()
        ws()
        local c = s:sub(i, i)
        if c == '{' then
            local t = {} i = i + 1 ws()
            if s:sub(i, i) == '}' then i = i + 1 return t end
            while true do
                ws()
                if s:sub(i, i) ~= '"' then error('json invalide', 0) end
                local k = str() ws() i = i + 1 t[k] = val() ws()
                local d = s:sub(i, i) i = i + 1
                if d == '}' then return t end
            end
        elseif c == '[' then
            local t = {} i = i + 1 ws()
            if s:sub(i, i) == ']' then i = i + 1 return t end
            while true do
                t[#t + 1] = val() ws()
                local d = s:sub(i, i) i = i + 1
                if d == ']' then return t end
            end
        elseif c == '"' then return str()
        elseif s:sub(i, i + 3) == 'true' then i = i + 4 return true
        elseif s:sub(i, i + 4) == 'false' then i = i + 5 return false
        elseif s:sub(i, i + 3) == 'null' then i = i + 4 return nil
        else
            local num = s:match('^-?[%d%.eE+-]+', i)
            if not num then error('json invalide', 0) end
            i = i + #num return tonumber(num)
        end
    end
    return val()
end
