-- =====================================================================
--  Simulation hors jeu d'elyzea_club : 1 serveur, 2 boîtes, 7 joueurs imités.
--  Les natives, elyzea_core, elyzea_inventory, admin_menu et la base sont imités
--  (la base garde les insertions en mémoire ; les données vivent dans les caches
--  du script, comme en jeu). Lancé par tests/run_tests.py (Lua 5.4 via lupa).
-- =====================================================================
local ROOT = ...
local passes, fails = 0, 0
local function P(...) print(...) end
local function check(ok, label)
    if ok then passes = passes + 1 P('  ok   ' .. label) else fails = fails + 1 P('  ÉCHEC ' .. label) end
end

-- ---------------------------------------------------------------------
-- JSON (petit encodeur / décodeur)
-- ---------------------------------------------------------------------
local json = {}
do
    local function esc(s) return s:gsub('[%c"\\]', function(c) local m = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' } return m[c] or ('\\u%04x'):format(c:byte()) end) end
    local function isArray(t) local n = 0 for k in pairs(t) do if type(k) ~= 'number' then return false end n = n + 1 end return n == #t end
    function json.encode(v)
        local t = type(v)
        if t == 'nil' then return 'null' elseif t == 'boolean' then return tostring(v)
        elseif t == 'number' then return (math.type(v) == 'integer' or v ~= math.floor(v)) and tostring(v) or ('%d'):format(v)
        elseif t == 'string' then return '"' .. esc(v) .. '"'
        elseif t == 'table' then
            local out = {}
            if next(v) == nil then return '[]' end
            if isArray(v) then for _, x in ipairs(v) do out[#out + 1] = json.encode(x) end return '[' .. table.concat(out, ',') .. ']' end
            for k, x in pairs(v) do out[#out + 1] = json.encode(tostring(k)) .. ':' .. json.encode(x) end
            return '{' .. table.concat(out, ',') .. '}'
        end
        return 'null'
    end
    function json.decode(s)
        local i = 1
        local function ws() i = s:find('%S', i) or #s + 1 end
        local val
        local function str()
            local out = {}
            i = i + 1
            while true do
                local c = s:sub(i, i)
                if c == '"' then i = i + 1 break end
                if c == '\\' then
                    local n = s:sub(i + 1, i + 1)
                    local m = { n = '\n', r = '\r', t = '\t', ['"'] = '"', ['\\'] = '\\', ['/'] = '/' }
                    if n == 'u' then out[#out + 1] = utf8.char(tonumber(s:sub(i + 2, i + 5), 16)) i = i + 6
                    else out[#out + 1] = m[n] or n i = i + 2 end
                else out[#out + 1] = c i = i + 1 end
            end
            return table.concat(out)
        end
        function val()
            ws()
            local c = s:sub(i, i)
            if c == '{' then
                local t = {} i = i + 1 ws()
                if s:sub(i, i) == '}' then i = i + 1 return t end
                while true do ws() local k = str() ws() i = i + 1 t[k] = val() ws() local d = s:sub(i, i) i = i + 1 if d == '}' then break end end
                return t
            elseif c == '[' then
                local t = {} i = i + 1 ws()
                if s:sub(i, i) == ']' then i = i + 1 return t end
                while true do t[#t + 1] = val() ws() local d = s:sub(i, i) i = i + 1 if d == ']' then break end end
                return t
            elseif c == '"' then return str()
            elseif s:sub(i, i + 3) == 'true' then i = i + 4 return true
            elseif s:sub(i, i + 4) == 'false' then i = i + 5 return false
            elseif s:sub(i, i + 3) == 'null' then i = i + 4 return nil
            else local num = s:match('^-?%d+%.?%d*[eE]?[-+]?%d*', i) i = i + #num return tonumber(num) end
        end
        if type(s) ~= 'string' then error('json') end
        return val()
    end
end

-- ---------------------------------------------------------------------
-- Horloge, fils, vecteurs
-- ---------------------------------------------------------------------
local GT = 0
local BASE = 1800000000
local threads = {}
local function CreateThread(fn) threads[#threads + 1] = { co = coroutine.create(fn), at = GT } end
local function Wait(ms) coroutine.yield(ms or 0) end
local errors = {}
local function run(ms)
    local stop = GT + (ms or 0)
    repeat
        local moved = true
        while moved do
            moved = false
            for i = #threads, 1, -1 do
                local t = threads[i]
                if t and coroutine.status(t.co) ~= 'dead' and t.at <= GT then
                    local ok, w = coroutine.resume(t.co)
                    if not ok then errors[#errors + 1] = tostring(w) P('  ^1 erreur Lua : ' .. tostring(w)) end
                    if coroutine.status(t.co) == 'dead' then table.remove(threads, i) else t.at = GT + math.max(1, w or 0) moved = true end
                end
            end
        end
        if GT >= stop then break end
        local nextAt = stop
        for _, t in ipairs(threads) do if t.at > GT and t.at < nextAt then nextAt = t.at end end
        GT = nextAt
    until false
end

local V = {}
V.__index = V
local function vector3(x, y, z) return setmetatable({ x = x + 0.0, y = y + 0.0, z = z + 0.0 }, V) end
V.__add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__mul = function(a, b) if type(a) == 'number' then a, b = b, a end return vector3(a.x * b, a.y * b, a.z * b) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end

-- ---------------------------------------------------------------------
-- Joueurs imités
-- ---------------------------------------------------------------------
local players = {}       -- [src] = { cid, name, money, job, pos, heading, items, duty }
local clientEvents = {}  -- { src, name, args }
local notes = {}         -- [src] = { { msg, kind } }
local jobs = {}
local society = {}
local function makePlayer(src, cid, first, last, pos)
    local pl = { src = src, cid = cid, name = first .. ' ' .. last, money = { bank = 5000, cash = 500 }, job = { name = 'unemployed', grade = { level = 0 }, onduty = false },
        pos = pos, heading = 90.0, items = {}, invFull = false }
    pl.obj = {
        PlayerData = { citizenid = cid, charinfo = { firstname = first, lastname = last }, job = pl.job },
        Functions = {
            GetMoney = function(m) return pl.money[m] or 0 end,
            RemoveMoney = function(m, a) if (pl.money[m] or 0) < a then return false end pl.money[m] = pl.money[m] - a return true end,
            AddMoney = function(m, a) pl.money[m] = (pl.money[m] or 0) + a return true end,
            SetJobDuty = function(on) pl.job.onduty = on end,
        },
    }
    players[src] = pl
    notes[src] = {}
    return pl
end
local function lastNote(src) local n = notes[src] return n[#n] and n[#n].msg or '' end

local core = {
    Notify = function(_, src, msg, kind) if notes[src] then notes[src][#notes[src] + 1] = { msg = msg, kind = kind } end end,
    GetPlayer = function(_, src) local p = players[tonumber(src) or -1] return p and p.obj or nil end,
    GetPlayers = function() local t = {} for s, p in pairs(players) do t[s] = p.obj end return t end,
    GetSourceByCitizenId = function(_, cid) for s, p in pairs(players) do if p.cid == cid then return s end end end,
    CreateJob = function(_, name, def) jobs[name] = def end,
    RemoveJob = function(_, name) jobs[name] = nil end,
    GetJob = function(_, name) return jobs[name] end,
    AddPlayerToJob = function(_, cid, job, level) for _, p in pairs(players) do if p.cid == cid then p.job.name = job p.job.grade = { level = level } end end end,
    RemovePlayerFromJob = function(_, cid) for _, p in pairs(players) do if p.cid == cid then p.job.name = 'unemployed' p.job.grade = { level = 0 } end end end,
    GetSocietyMoney = function(_, s) society[s] = society[s] or 0 return society[s] end,
    AddSocietyMoney = function(_, s, a) society[s] = (society[s] or 0) + a return true end,
    RemoveSocietyMoney = function(_, s, a) if (society[s] or 0) < a then return false end society[s] = society[s] - a return true end,
    GetSocietyLogs = function() return {} end,
    ToUtf8mb4 = function() end,
    GetOfflinePlayer = function() return nil end,
    SaveOffline = function() return true end,
}
local stashAccess, stashes, opened = {}, {}, {}
local inventory = {
    AddItem = function(_, src, item, qty) local p = players[src] if not p or p.invFull then return false end p.items[item] = (p.items[item] or 0) + qty return true end,
    CanCarryItems = function(_, src) local p = players[src] return p ~= nil and not p.invFull end,
    RegisterStash = function(_, id, label) stashes[id] = label end,
    RegisterStashAccess = function(_, prefix, cb) stashAccess[prefix] = cb end,
    OpenInventory = function(_, src, kind, id)
        for prefix, cb in pairs(stashAccess) do if id:sub(1, #prefix) == prefix and not cb(src, id) then return false end end
        opened[#opened + 1] = { src = src, id = id }
        return true
    end,
}
local staff = { [1] = false }
local adminMenu = {
    HasPermission = function(_, src, perm) return perm == 'club_manage' and staff[src] == true end,
    AddLog = function() end,
}

-- Base : identifiants auto, requêtes enregistrées
local queries, nextId = {}, 100
local function q(sql) queries[#queries + 1] = sql end
local MySQL = {
    query = setmetatable({ await = function(sql) q(sql) return {} end }, { __call = function(_, sql) q(sql) end }),
    insert = setmetatable({ await = function(sql) q(sql) nextId = nextId + 1 return nextId end }, { __call = function(_, sql) q(sql) end }),
    update = setmetatable({ await = function(sql) q(sql) return 1 end }, { __call = function(_, sql) q(sql) end }),
    single = { await = function(sql) q(sql) return {} end },
}

-- ---------------------------------------------------------------------
-- Environnement du script serveur
-- ---------------------------------------------------------------------
local callbacks, handlers, exportsTbl = {}, {}, {}
local GlobalState = {}
local states = {}
local httpTitles = {}
local env = setmetatable({}, { __index = _G })
env.json = json
env.vector3 = vector3
env.CreateThread = CreateThread
env.Wait = Wait
env.GetGameTimer = function() return GT end
env.os = setmetatable({ time = function(t) if t then return os.time(t) end return BASE + GT // 1000 end }, { __index = os })
env.MySQL = MySQL
env.GlobalState = GlobalState
env.Config = nil
env.print = function(...) local s = table.concat({ ... }, ' ') if s:find('%^1') then errors[#errors + 1] = s P('  ' .. s) end end
env.exports = setmetatable({ elyzea_core = core, elyzea_inventory = inventory, admin_menu = adminMenu }, {
    __call = function(_, name, fn) exportsTbl[name] = fn end,
    __index = function(_, k) return nil end,
})
env.GetResourceState = function(r) return (r == 'admin_menu' or r == 'elyzea_inventory') and 'started' or 'missing' end
env.GetCurrentResourceName = function() return 'elyzea_club' end
env.Ely = { callback = { register = function(n, fn) callbacks[n] = fn end } }
env.AddEventHandler = function(name, fn) handlers[name] = handlers[name] or {} table.insert(handlers[name], fn) end
env.RegisterNetEvent = function(name, fn) if fn then env.AddEventHandler(name, fn) end end
env.TriggerEvent = function(name, ...) for _, fn in ipairs(handlers[name] or {}) do fn(...) end end
env.TriggerClientEvent = function(name, src, ...) clientEvents[#clientEvents + 1] = { src = src, name = name, args = { ... } } end
env.GetPlayerName = function(src) local p = players[tonumber(src) or -1] return p and p.name or nil end
env.GetPlayerPed = function(src) return players[src] and src or 0 end
env.GetEntityCoords = function(ped) local p = players[ped] return p and p.pos or vector3(0, 0, 0) end
env.GetEntityHeading = function(ped) local p = players[ped] return p and p.heading or 0.0 end
env.SetEntityCoords = function(ped, x, y, z) local p = players[ped] if p then p.pos = vector3(x, y, z) end end
env.SetEntityHeading = function(ped, h) local p = players[ped] if p then p.heading = h end end
env.GetVehiclePedIsIn = function() return 0 end
env.Player = function(src) states[src] = states[src] or {} local st = states[src] return { state = setmetatable({ set = function(_, k, v) st[k] = v end }, { __index = st }) } end
env.PerformHttpRequest = function(url, cb) local id = url:match('v=([%w_-]+)') cb(httpTitles[id] and 200 or 404, httpTitles[id] and json.encode({ title = httpTitles[id] }) or '') end
env.source = 0

local function loadFile(path)
    local f = assert(io.open(ROOT .. '/' .. path, 'r'))
    local src = f:read('a') f:close()
    local chunk = assert(load(src, '@' .. path, 't', env))
    chunk()
end
for _, f in ipairs({ 'config.lua', 'shared/perms.lua', 'shared/youtube.lua', 'server/main.lua', 'server/service.lua', 'server/finance.lua', 'server/commission.lua',
    'server/direction.lua', 'server/bar.lua', 'server/door.lua', 'server/music.lua', 'server/club.lua', 'server/admin.lua', 'server/phone.lua', 'server/api.lua' }) do loadFile(f) end
local Club = env.Club
local Config = env.Config

-- Raccourcis : requêtes comme le client
-- Une requête toutes les 120 ms au plus (comme un joueur qui clique) : l'anti-spam du serveur reste actif
local function req(src, action, data) run(120) return callbacks['club:req'](src, action, data or {}) end
local function pub(src, action, data) run(120) return callbacks['club:pub'](src, action, data or {}) end
local function adm(src, action, data) run(120) return callbacks['club:admin'](src, action, data or {}) end
local function lastClient(src, name) for i = #clientEvents, 1, -1 do local e = clientEvents[i] if e.src == src and e.name == name then return e end end end

-- ---------------------------------------------------------------------
-- Démarrage
-- ---------------------------------------------------------------------
P('\n[Démarrage]')
run(100)
check(Club.ready, 'ressource prête')
local created = 0
for _, sql in ipairs(queries) do if sql:find('CREATE TABLE IF NOT EXISTS') then created = created + 1 end end
check(created >= 13, ('%d tables créées (cl_*)'):format(created))
check(#errors == 0, 'aucune erreur au démarrage')

-- Joueurs : 1 staff, 2 patron A, 3 serveur A, 4 DJ A, 5 client, 6 patron B, 7 client à interdire
local BAR, DOOR, INSIDE, OUT = vector3(100, 100, 30), vector3(120, 100, 30), vector3(100, 80, 30), vector3(400, 400, 30)
makePlayer(1, 'STAFF', 'Sam', 'Staff', DOOR)
makePlayer(2, 'PAT_A', 'Alice', 'Patron', BAR)
makePlayer(3, 'SRV_A', 'Bruno', 'Serveur', OUT)
makePlayer(4, 'DJ_A', 'Chloé', 'Dj', OUT)
makePlayer(5, 'CLI', 'Dan', 'Client', OUT)
makePlayer(6, 'PAT_B', 'Eva', 'Rival', OUT)
makePlayer(7, 'BAD', 'Fred', 'Bagarreur', OUT)
staff[1] = true

-- ---------------------------------------------------------------------
P('\n[Staff : plusieurs boîtes]')
check(adm(5, 'data').error ~= nil, 'un joueur sans permission « club_manage » n\'ouvre pas l\'administration')
local rA = adm(1, 'shopSave', { name = 'Galaxy Club', address = 'Vinewood' })
local rB = adm(1, 'shopSave', { name = 'Bahama Mamas', job = 'bahama' })
check(rA.ok and rB.ok and rA.id ~= rB.id, 'deux boîtes créées')
local A, B = Club.shops[rA.id], Club.shops[rB.id]
check(A.job ~= B.job and jobs[A.job] and jobs[B.job] and jobs[A.job].type == 'nightclub', ('deux métiers distincts déclarés dans le core (%s, %s)'):format(A.job, B.job))
check(#Club.SortedGrades(A.id) == 5 and Club.SortedGrades(A.id)[5].name == 'Patron', '5 grades par boîte (Serveur → Patron)')
check(Club.menu[A.id] and Club.menu[A.id].nc_mojito and Club.menu[A.id].nc_mojito.stock == Config.Bar.startStock, 'carte du bar créée avec un stock de départ')
check(adm(1, 'shopSave', { name = 'Copie', job = A.job }).error ~= nil, 'métier déjà pris par une autre boîte : refusé')
check(adm(1, 'shopEnable', { id = A.id, enabled = true }).error ~= nil, 'activation refusée sans point Entrée / Bar')
players[1].pos = DOOR check(adm(1, 'point', { id = A.id, key = 'door' }).ok, 'point Entrée placé')
players[1].pos = BAR check(adm(1, 'point', { id = A.id, key = 'bar' }).ok, 'point Bar placé')
players[1].pos = INSIDE check(adm(1, 'point', { id = A.id, key = 'inside' }).ok, 'point Intérieur placé')
players[1].pos = vector3(90, 100, 30) check(adm(1, 'point', { id = A.id, key = 'stash' }).ok, 'point Coffre placé')
check(adm(1, 'shopEnable', { id = A.id, enabled = true }).ok and A.enabled, 'boîte A activée')
players[1].pos = vector3(500, 500, 30) adm(1, 'point', { id = B.id, key = 'door' })
players[1].pos = vector3(510, 500, 30) adm(1, 'point', { id = B.id, key = 'bar' })
check(adm(1, 'shopEnable', { id = B.id, enabled = true }).ok, 'boîte B activée')
check(adm(1, 'setBoss', { id = A.id, target = 2 }).ok and players[2].job.name == A.job and players[2].job.grade.level == 5, 'Alice nommée Patron de A (métier donné)')
check(adm(1, 'setBoss', { id = B.id, target = 6 }).ok and players[6].job.name == B.job, 'Eva nommée Patron de B')
check(adm(1, 'setBoss', { id = B.id, target = 2 }).error ~= nil, 'impossible d\'être dans deux boîtes à la fois')
Club.Hire(A, 'SRV_A', 'Bruno Serveur', Club.GradeByLevel(A.id, 1))
Club.Hire(A, 'DJ_A', 'Chloé Dj', Club.GradeByLevel(A.id, 3))
check(Club.Grade(3).name == 'Serveur' and Club.Grade(4).name == 'DJ', 'Bruno Serveur, Chloé DJ')
local pub1 = pub(5, 'shops').list
check(#pub1 == 2 and pub1[1].door ~= nil, 'les deux boîtes sont visibles en ville (points publics)')

-- ---------------------------------------------------------------------
P('\n[Bar]')
check(req(3, 'barOpen').error and req(3, 'barOpen').error:find('service'), 'servir demande d\'être en service')
check(req(3, 'duty', { on = true }).ok and Club.OnDuty(3), 'Bruno prend son service')
check((req(3, 'barOpen').error or ''):find('bar'), 'servir loin du point Bar : refusé')
players[3].pos = BAR + vector3(1, 0, 0)
players[5].pos = BAR + vector3(2, 1, 0)
local bo = req(3, 'barOpen')
local seen5 = false
for _, c in ipairs(bo.customers or {}) do if c.id == 5 then seen5 = true end end
check(seen5, 'le client proche est proposé')
check(req(2, 'financeCommission', { id = Club.GradeByLevel(A.id, 1).id, pct = 10 }).ok, 'le patron fixe 10 % de commission aux serveurs')
local balance0 = society[A.society] or 0
local s1 = req(3, 'barSell', { target = 5, lines = { { item = 'nc_mojito', qty = 2 }, { item = 'nc_shot', qty = 3 } } })
local ev = lastClient(5, 'club:client:barOffer')
local expected = 2 * 45 + 3 * 15
check(s1.ok and ev and ev.args[1].total == expected, ('commande envoyée au client : %d $ (prix de la carte)'):format(expected))
check(req(3, 'barSell', { target = 5, lines = { { item = 'nc_mojito', qty = 999 } } }).error ~= nil, 'quantité hors limite refusée')
local cash0 = players[5].money.cash
local pay = pub(5, 'barAnswer', { id = ev.args[1].id, accept = true, method = 'cash' })
check(pay.ok and players[5].money.cash == cash0 - expected, 'le client paie en espèces')
check(players[5].items.nc_mojito == 2 and players[5].items.nc_shot == 3, 'les boissons sont dans son inventaire')
check(Club.menu[A.id].nc_mojito.stock == Config.Bar.startStock - 2, 'le stock baisse')
local com = math.floor(expected * 10 / 100)
check(society[A.society] == balance0 + expected - com and players[3].money.bank == 5000 + com, ('argent sur le compte de la boîte, commission de %d $ au serveur'):format(com))
check(pub(5, 'barAnswer', { id = ev.args[1].id, accept = true }).error ~= nil, 'la même commande ne se paie pas deux fois')
-- refus, inventaire plein
req(3, 'barSell', { target = 5, lines = { { item = 'nc_soda', qty = 1 } } })
ev = lastClient(5, 'club:client:barOffer')
check(pub(5, 'barAnswer', { id = ev.args[1].id, accept = false }).ok and lastNote(3):find('refusé'), 'refus : le serveur est prévenu')
players[5].invFull = true
req(3, 'barSell', { target = 5, lines = { { item = 'nc_soda', qty = 1 } } })
ev = lastClient(5, 'club:client:barOffer')
local bank0 = players[5].money.bank
check((pub(5, 'barAnswer', { id = ev.args[1].id, accept = true, method = 'bank' }).error or ''):find('place') and players[5].money.bank == bank0, 'inventaire plein : rien n\'est payé')
players[5].invFull = false
-- carte et stock
check(req(3, 'menuSet', { item = 'nc_mojito', price = 1 }).error ~= nil, 'un serveur ne change pas les prix')
check(req(2, 'menuSet', { item = 'nc_mojito', price = 55 }).ok and Club.menu[A.id].nc_mojito.price == 55, 'le patron change un prix')
check(Club.menu[B.id].nc_mojito.price == 45, 'la carte de l\'autre boîte ne change pas')
society[A.society] = 1000
check(req(2, 'stockOrder', { item = 'nc_champagne', qty = 5 }).ok and society[A.society] == 1000 - 5 * 140 and Club.menu[A.id].nc_champagne.stock == Config.Bar.startStock + 5,
    'commande de stock payée par le compte de la boîte')
check(req(2, 'stockOrder', { item = 'nc_champagne', qty = 50 }).error ~= nil, 'stock refusé si le compte ne suffit pas')
check(pub(7, 'menuPublic', { shop = A.id }).error ~= nil, 'carte publique : il faut être près du bar')
players[7].pos = BAR + vector3(3, 0, 0)
check(#(pub(7, 'menuPublic', { shop = A.id }).list or {}) > 0, 'carte publique visible au bar')
players[7].pos = OUT

-- ---------------------------------------------------------------------
P('\n[Entrée, bracelets, VIP, liste noire]')
players[5].pos = DOOR
check((pub(5, 'enter', { shop = A.id }).error or ''):find('fermée'), 'boîte fermée au public : entrée refusée')
check(req(3, 'openSet', { publicOpen = true }).error ~= nil, 'un serveur n\'ouvre pas la boîte')
check(req(2, 'openSet', { publicOpen = true, fee = 80 }).ok and Club.PublicOpen(A) and Club.EntryFee(A) == 80, 'le patron ouvre au public, entrée 80 $')
local soc = society[A.society]
cash0 = players[5].money.cash
check(pub(5, 'enter', { shop = A.id, method = 'cash' }).ok and players[5].money.cash == cash0 - 80 and society[A.society] == soc + 80, 'le client paie 80 $ : argent sur le compte de la boîte')
check(#(players[5].pos - INSIDE) < 0.1, 'avec un point Intérieur, il est téléporté dedans')
check(pub(5, 'leave', { shop = A.id }).ok and #(players[5].pos - DOOR) < 0.1, 'E à l\'intérieur : il ressort à l\'entrée')
cash0 = players[5].money.cash
check(pub(5, 'enter', { shop = A.id, method = 'cash' }).ok and players[5].money.cash == cash0, 'avec son bracelet, il rentre sans repayer')
players[3].pos = DOOR
check(pub(3, 'enter', { shop = A.id }).ok, 'le personnel entre gratuitement')
-- liste noire
players[7].pos = DOOR
players[2].pos = DOOR + vector3(1, 0, 0)
check(req(2, 'listAdd', { kind = 'ban', target = 7, reason = 'Bagarre', days = 3 }).ok, 'le patron met Fred sur la liste noire (3 jours)')
check((pub(7, 'enter', { shop = A.id, method = 'bank' }).error or ''):find('liste noire'), 'Fred ne peut plus entrer')
players[7].pos = vector3(500, 500, 30)
local okB = pub(7, 'enter', { shop = B.id, method = 'bank' })
check(okB.error and okB.error:find('fermée') and not okB.error:find('liste noire'), 'la liste noire de A ne vaut pas pour B')
check(req(2, 'listAdd', { kind = 'ban', target = 3 }).error ~= nil, 'un employé ne peut pas être sur la liste noire')
-- VIP
players[1].pos = DOOR
check(req(2, 'listAdd', { kind = 'vip', target = 1 }).ok, 'Sam ajouté à la liste VIP')
cash0, bank0 = players[1].money.cash, players[1].money.bank
check(pub(1, 'enter', { shop = A.id, method = 'cash' }).ok and players[1].money.cash == cash0 and players[1].money.bank == bank0, 'un VIP entre gratuitement')
-- videur
players[2].pos = DOOR players[5].pos = DOOR + vector3(1.5, 0, 0) players[1].pos = OUT players[7].pos = OUT players[3].pos = OUT
req(2, 'duty', { on = true })
local chk = req(2, 'doorCheck')
check(chk.target and chk.target.id == 5 and chk.target.band ~= nil, 'contrôle du videur : bracelet valable vu')
check(req(2, 'doorKick', { target = 5 }).ok and not Club.Band(A.id, 'CLI'), 'raccompagné : bracelet retiré')
check(req(2, 'listRemove', { kind = 'ban', cid = 'BAD' }).ok and not Club.IsBanned(A.id, 'BAD'), 'retrait de la liste noire')
-- annonce
check(req(2, 'announce', { text = 'Soirée Neon ce soir !' }).ok and lastClient(-1, 'club:client:announce'), 'annonce envoyée à toute la ville')
check((req(2, 'announce', { text = 'Encore une annonce' }).error or ''):find('min'), 'deuxième annonce trop tôt : refusée')
-- coffre
players[2].pos = vector3(90, 100, 30)
check(req(2, 'stash').ok and opened[#opened].id == ('club:%d'):format(A.id), 'le patron ouvre le coffre de sa boîte')
check(stashAccess['club:'](6, ('club:%d'):format(A.id)) == false, 'le patron de B ne peut pas ouvrir le coffre de A')
check(stashAccess['club:'](3, ('club:%d'):format(A.id)) == false, 'un serveur sans la permission « coffre » non plus')

-- ---------------------------------------------------------------------
P('\n[Enceintes et musique : réservées à la boîte qui les pose]')
players[4].pos = vector3(200, 200, 30)
check((req(4, 'musicPlay').error or ''):find('enceinte'), 'pas d\'enceinte : rien à piloter')
check(req(4, 'speakerPlace', { model = 'prop_speaker_06', x = 201, y = 200, z = 30 }).error ~= nil, 'le DJ n\'a pas la permission de poser des enceintes')
players[2].pos = vector3(200, 200, 30)
check(req(2, 'speakerPlace', { model = 'inconnu', x = 201, y = 200, z = 30 }).error ~= nil, 'modèle inconnu refusé')
check(req(2, 'speakerPlace', { model = 'prop_speaker_06', x = 260, y = 200, z = 30 }).error ~= nil, 'enceinte trop loin du joueur refusée')
local sp = req(2, 'speakerPlace', { model = 'ba_prop_battle_club_speaker_large', x = 203, y = 200, z = 30, h = 90 })
check(sp.ok and Club.SpeakerCount(A.id) == 1, 'le patron pose une enceinte (elle appartient à A)')
check(#(pub(5, 'shops').list[1].speakers) == 1, 'l\'enceinte est publiée à tous les joueurs')
httpTitles['dQw4w9WgXcQ'] = 'Titre un'
httpTitles['9bZkp7q19f0'] = 'Titre deux'
local add = req(4, 'musicAdd', { urls = { 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', 'https://youtu.be/9bZkp7q19f0', 'https://exemple.com/video' } })
check(add.ok and #add.tracks == 2, 'le DJ ajoute 2 titres (le lien non YouTube est ignoré)')
check(add.tracks[1].title == 'Titre un', 'titre de la vidéo récupéré')
check(req(4, 'musicAdd', { url = 'https://site-pirate.com/x' }).error ~= nil, 'lien qui n\'est pas YouTube refusé')
players[4].pos = vector3(400, 400, 30)
check((req(4, 'musicPlay').error or ''):find('Approchez'), 'loin des enceintes : lecture refusée')
players[4].pos = vector3(205, 202, 30)
local play = req(4, 'musicPlay')
local gm = GlobalState.clubMusic and GlobalState.clubMusic[tostring(A.id)]
check(play.ok and gm and gm.yt == 'dQw4w9WgXcQ' and gm.title == 'Titre un', 'le DJ lance la playlist : publiée à tous (vidéo, heure de début)')
-- autres grades, autre boîte
players[3].pos = vector3(204, 200, 30)
check((req(3, 'musicPause').error or ''):find('grade'), 'le serveur (sans « music ») ne peut pas toucher la musique')
players[6].pos = vector3(204, 201, 30)
check(req(6, 'speakerRemove', { id = sp.id }).error ~= nil and Club.SpeakerCount(A.id) == 1, 'le patron de B ne peut pas retirer l\'enceinte de A')
check((req(6, 'musicPause').error or ''):find('enceinte'), 'le patron de B ne pilote pas la musique de A (sa boîte n\'a pas d\'enceinte)')
check(GlobalState.clubMusic[tostring(A.id)].paused == false, 'la musique de A continue')
-- le patron donne la permission au grade Serveur
local srv = Club.GradeByLevel(A.id, 1)
local list = {}
for k in pairs(srv.perms) do list[#list + 1] = k end
list[#list + 1] = 'music'
check(req(2, 'gradePerms', { id = srv.id, perms = list }).ok, 'le patron coche « Utiliser les enceintes » pour le grade Serveur')
check(req(3, 'musicPause').ok and GlobalState.clubMusic[tostring(A.id)].paused == true, 'le serveur peut maintenant mettre en pause')
check(req(3, 'musicPlay').ok and GlobalState.clubMusic[tostring(A.id)].paused == false, 'et reprendre')
-- défilement
run(1000)
local t1 = GlobalState.clubMusic[tostring(A.id)].track
pub(4, 'musicReport', { shop = A.id, track = t1, duration = 30 })
check(Club.tracks[A.id][1].duration == 30, 'durée du titre envoyée par un joueur qui écoute')
pub(5, 'musicReport', { shop = A.id, track = t1, duration = 9999 })
check(Club.tracks[A.id][1].duration == 30, 'un joueur loin des enceintes n\'est pas écouté')
run(33000)
gm = GlobalState.clubMusic[tostring(A.id)]
check(gm and gm.yt == '9bZkp7q19f0', 'fin du titre : la playlist passe au suivant toute seule')
run(2000)
pub(4, 'musicReport', { shop = A.id, track = gm.track, error = 150 })
gm = GlobalState.clubMusic[tostring(A.id)]
check(Club.tracks[A.id][2].broken and gm and gm.yt == 'dQw4w9WgXcQ', 'vidéo refusée par YouTube : sautée, retour au premier titre (boucle)')
check(req(4, 'musicSet', { volume = 40, range = 60 }).ok and GlobalState.clubMusic[tostring(A.id)].volume == 40 and GlobalState.clubMusic[tostring(A.id)].range == 60, 'volume et portée réglés')
check(req(4, 'musicNext', { dir = 1 }).ok, 'titre suivant à la main')
-- fin de boucle
req(4, 'musicSet', { loop = false })
Club.tracks[A.id][2].broken = false
req(4, 'musicPlay', { track = Club.tracks[A.id][2].id })
pub(4, 'musicReport', { shop = A.id, track = Club.tracks[A.id][2].id, duration = 10 })
run(13000)
check(GlobalState.clubMusic[tostring(A.id)] == nil, 'sans boucle : la musique s\'arrête après le dernier titre')
-- staff
req(4, 'musicPlay')
check(GlobalState.clubMusic[tostring(A.id)] ~= nil, 'relancée')
check(adm(1, 'shopEnable', { id = A.id, enabled = false }).ok and GlobalState.clubMusic[tostring(A.id)] == nil, 'boîte désactivée par le staff : musique coupée')
check((req(4, 'musicPlay').error or ''):find('fermée'), 'boîte désactivée : plus aucune action')
adm(1, 'shopEnable', { id = A.id, enabled = true })
check(req(2, 'speakerRemove', { id = sp.id }).ok and Club.SpeakerCount(A.id) == 0, 'le patron retire son enceinte')

-- ---------------------------------------------------------------------
P('\n[Tablette, finances, suppression]')
local dash = req(2, 'dashboard')
check(dash.shop and dash.shop.name == 'Galaxy Club' and dash.publicOpen == true, 'tableau de bord')
check(req(2, 'finance').balance ~= nil, 'finances (compte de la boîte)')
check(req(3, 'finance').error ~= nil, 'un serveur ne voit pas les finances')
check(#(req(2, 'sales').list or {}) >= 0 and req(2, 'lists').canEdit == true, 'ventes et listes')
local del = adm(1, 'shopDelete', { id = B.id, confirm = 'Bahama Mamas' })
check(del.ok and B.deleted and players[6].job.name == 'unemployed', 'boîte B supprimée : employés retirés du métier')
check(#pub(5, 'shops').list == 1, 'B n\'apparaît plus en ville')

check(#errors == 0, ('aucune erreur Lua (%d)'):format(#errors))
P(('\nRésultat : %d réussis, %d échecs'):format(passes, fails))
return fails
