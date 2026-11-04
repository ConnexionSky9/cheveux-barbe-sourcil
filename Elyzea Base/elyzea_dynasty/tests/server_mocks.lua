-- =====================================================================
--  Bouchons FiveM / elyzea pour tester le serveur Dynasty 8 hors jeu (lupa + MariaDB).
--  La base est réelle (MySQL relié en Python) ; le reste est simulé.
-- =====================================================================
local NOW = 1800000000
local realTime = os.time
os.time = function(t) if t then return realTime(t) end return NOW end
function AdvanceTime(s) NOW = NOW + s end
local CLOCK = 0
function GetGameTimer() return CLOCK end

-- JSON minimal
json = {}
local function esc(s) return (s:gsub('[%c"\\]', function(c) local m = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' } return m[c] or string.format('\\u%04x', c:byte()) end)) end
function json.encode(v)
    local t = type(v)
    if v == nil then return 'null' elseif t == 'boolean' then return tostring(v) elseif t == 'number' then
        if v ~= v or v == math.huge or v == -math.huge then return 'null' end
        if math.type(v) == 'integer' or v == math.floor(v) and math.abs(v) < 1e15 then return string.format('%d', math.floor(v)) end
        return string.format('%.14g', v)
    elseif t == 'string' then return '"' .. esc(v) .. '"' elseif t == 'table' then
        local n = #v
        if n > 0 or next(v) == nil then local o = {} for i = 1, n do o[i] = json.encode(v[i]) end return '[' .. table.concat(o, ',') .. ']' end
        local o = {} for k, x in pairs(v) do o[#o + 1] = '"' .. esc(tostring(k)) .. '":' .. json.encode(x) end return '{' .. table.concat(o, ',') .. '}'
    end
    return 'null'
end
function json.decode(s)
    if type(s) ~= 'string' then return nil end
    local i = 1
    local function ws() i = s:find('[^%s]', i) or #s + 1 end
    local val
    local function str()
        local out, j = {}, i + 1
        while true do
            local c = s:sub(j, j)
            if c == '"' then i = j + 1 return table.concat(out) end
            if c == '\\' then local n = s:sub(j + 1, j + 1)
                local m = { n = '\n', r = '\r', t = '\t', ['"'] = '"', ['\\'] = '\\', ['/'] = '/' }
                if n == 'u' then out[#out + 1] = utf8.char(tonumber(s:sub(j + 2, j + 5), 16)) j = j + 6 else out[#out + 1] = m[n] or n j = j + 2 end
            elseif c == '' then error('json') else out[#out + 1] = c j = j + 1 end
        end
    end
    function val()
        ws()
        local c = s:sub(i, i)
        if c == '{' then i = i + 1 local o = {} ws() if s:sub(i, i) == '}' then i = i + 1 return o end
            while true do ws() local k = str() ws() i = i + 1 o[k] = val() ws() local d = s:sub(i, i) i = i + 1 if d == '}' then return o end end
        elseif c == '[' then i = i + 1 local o = {} ws() if s:sub(i, i) == ']' then i = i + 1 return o end
            while true do o[#o + 1] = val() ws() local d = s:sub(i, i) i = i + 1 if d == ']' then return o end end
        elseif c == '"' then return str()
        elseif s:sub(i, i + 3) == 'true' then i = i + 4 return true
        elseif s:sub(i, i + 4) == 'false' then i = i + 5 return false
        elseif s:sub(i, i + 3) == 'null' then i = i + 4 return nil
        else local n = s:match('^-?%d+%.?%d*[eE]?[-+]?%d*', i) i = i + #n return tonumber(n) end
    end
    local ok, r = pcall(val)
    if not ok then error('json decode') end
    return r
end

-- vector3
local V = {}
V.__index = V
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end

-- Planificateur de fils (CreateThread / Wait / SetTimeout)
local threads = {}
function CreateThread(fn) threads[#threads + 1] = { co = coroutine.create(fn), at = CLOCK } end
Citizen = { CreateThread = CreateThread }
function SetTimeout(ms, fn) CreateThread(function() Wait(ms) fn() end) end
function Wait(ms)
    local co, main = coroutine.running()
    if main or not coroutine.isyieldable() then CLOCK = CLOCK + (ms or 0) return end
    coroutine.yield(ms or 0)
end
function RunFor(ms)
    local stop = CLOCK + ms
    while CLOCK <= stop do
        local ran = false
        for _, t in ipairs(threads) do
            if not t.dead and t.at <= CLOCK then
                local ok, w = coroutine.resume(t.co)
                if not ok then print('ERREUR FIL : ' .. tostring(w)) t.dead = true
                elseif coroutine.status(t.co) == 'dead' then t.dead = true
                else t.at = CLOCK + (tonumber(w) or 0) ran = true end
            end
        end
        CLOCK = CLOCK + 50
    end
end

-- Évènements
HANDLERS, NET, SENT, NOTES, CMDS = {}, {}, {}, {}, {}
function AddEventHandler(name, fn) HANDLERS[name] = HANDLERS[name] or {} table.insert(HANDLERS[name], fn) end
function RegisterNetEvent(name, fn) if fn then NET[name] = fn end end
function TriggerEvent(name, ...) for _, f in ipairs(HANDLERS[name] or {}) do f(...) end end
function TriggerClientEvent(name, target, ...) SENT[#SENT + 1] = { name = name, target = target, args = { ... } } end
function RegisterCommand(name, fn) CMDS[name] = fn end
function GetCurrentResourceName() return 'elyzea_dynasty' end
GlobalState = {}
function Player(src) return { state = { set = function() end } } end
CB = {}
Ely = { callback = { register = function(name, fn) CB[name] = fn end } }

-- Joueurs
PLAYERS = {}
STAFF = {}
INV = {}
SOCIETY = {}
function AddPlayer(src, cid, first, last, coords)
    PLAYERS[src] = { cid = cid, coords = coords, heading = 90.0, money = { bank = 1000000, cash = 5000 }, first = first, last = last, md = {} }
    INV[src] = {}
end
local function playerObj(src)
    local p = PLAYERS[src]
    if not p then return nil end
    return { PlayerData = { citizenid = p.cid, charinfo = { firstname = p.first, lastname = p.last }, job = { name = 'unemployed', grade = { level = 0 } }, metadata = p.md, source = src },
        Functions = {
            GetMoney = function(m) return p.money[m] end,
            RemoveMoney = function(m, n) if p.money[m] < n then return false end p.money[m] = p.money[m] - n return true end,
            AddMoney = function(m, n) p.money[m] = p.money[m] + n return true end,
            SetJobDuty = function() end, SetMetaData = function(k, v) p.md[k] = v end,
        } }
end
function GetPlayers() local l = {} for s in pairs(PLAYERS) do l[#l + 1] = tostring(s) end return l end
function GetPlayerName(src) local p = PLAYERS[tonumber(src)] return p and (p.first .. ' ' .. p.last) or nil end
function GetPlayerPed(src) return PLAYERS[tonumber(src)] and tonumber(src) * 100 or 0 end
function GetEntityCoords(ped) local p = PLAYERS[ped // 100] return p and p.coords or vector3(0, 0, 0) end
function GetEntityHeading(ped) local p = PLAYERS[ped // 100] return p and p.heading or 0.0 end
function GetVehiclePedIsIn() return 0 end
function SetPlayerRoutingBucket() end
function SetEntityCoords() end
function GetResourceState(res)
    if res == 'elyzea_agences' or res == 'elyzea_aura' then return 'missing' end
    return 'started'
end

-- exports : ressources simulées + exports de la ressource testée
OWN = {}
local MOCK = {
    elyzea_core = {
        Notify = function(src, msg, kind) NOTES[#NOTES + 1] = { src = src, msg = msg, kind = kind } end,
        GetPlayer = function(src) return playerObj(tonumber(src)) end,
        GetPlayers = function() local m = {} for s in pairs(PLAYERS) do m[s] = playerObj(s) end return m end,
        GetSourceByCitizenId = function(cid) for s, p in pairs(PLAYERS) do if p.cid == cid then return s end end end,
        SetMetadata = function(src, k, v) if PLAYERS[src] then PLAYERS[src].md[k] = v end end,
        GetMetadata = function(src, k) return PLAYERS[src] and PLAYERS[src].md[k] end,
        AddSocietyMoney = function(soc, n) SOCIETY[soc] = (SOCIETY[soc] or 0) + n return true end,
        RemoveSocietyMoney = function(soc, n) SOCIETY[soc] = (SOCIETY[soc] or 0) - n return true end,
        GetSocietyMoney = function(soc) return SOCIETY[soc] or 0 end,
        ToUtf8mb4 = function() end, CreateJob = function() return true end,
    },
    admin_menu = { HasPermission = function(src, perm) return STAFF[tonumber(src)] == true end, AddLog = function() end },
    elyzea_inventory = {
        GetItemCount = function(src, item) return (INV[src] or {})[item] or 0 end,
        RemoveItem = function(src, item, n) local i = INV[src] or {} if (i[item] or 0) < n then return false end i[item] = i[item] - n return true end,
        AddItem = function(src, item, n) local i = INV[src] or {} i[item] = (i[item] or 0) + n return true end,
        CanCarryItems = function() return true end, RegisterStash = function() return true end, RegisterStashAccess = function() end,
        OpenInventory = function() return true end,
    },
}
exports = setmetatable({}, {
    __call = function(_, name, fn) OWN[name] = fn end,
    __index = function(_, res)
        return setmetatable({}, { __index = function(_, fn)
            local f = MOCK[res] and MOCK[res][fn]
            return function(self, ...) if f then return f(...) end return nil end
        end })
    end,
})

-- Toute autre fonction native (en Majuscules) inconnue : fonction vide
local NOT = { Police = true, Ems = true, Meca = true, Concess = true, PoliceC = true, EmsC = true, MecaC = true, CDC = true, D8C = true, Dynasty = true, Config = true, D8Perms = true, D8PermSet = true }
setmetatable(_G, { __index = function(_, k) if type(k) == 'string' and k:match('^%u') and not NOT[k] then return function() return nil end end end })
