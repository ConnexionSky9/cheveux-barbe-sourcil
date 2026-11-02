-- =====================================================================
--  Simulation hors jeu d'elyzea_restaurant : scripts serveur RÉELS, vraie base
--  MariaDB (passée par tests/run_tests.py), 2 restaurants, 5 joueurs imités.
--  Imités : natives FiveM, elyzea_core (argent, métiers, sociétés), elyzea_inventory
--  (objets avec métadonnées), admin_menu (permissions staff).
-- =====================================================================
local ROOT, MySQL = ...
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
local players, notes, clientEvents = {}, {}, {}
local jobs, society = {}, {}
local function makePlayer(src, cid, first, last, pos)
    local pl = { src = src, cid = cid, name = first .. ' ' .. last, money = { bank = 5000, cash = 500 }, job = { name = 'unemployed', grade = { level = 0 }, onduty = false },
        pos = pos, items = {}, invFull = false }
    pl.obj = {
        PlayerData = { citizenid = cid, charinfo = { firstname = first, lastname = last }, job = pl.job, metadata = {} },
        Functions = {
            GetMoney = function(m) return pl.money[m] or 0 end,
            RemoveMoney = function(m, a) if (pl.money[m] or 0) < a then return false end pl.money[m] = pl.money[m] - a return true end,
            AddMoney = function(m, a) pl.money[m] = (pl.money[m] or 0) + a return true end,
            SetJobDuty = function(on) pl.job.onduty = on end,
        },
    }
    players[src], notes[src] = pl, {}
    return pl
end
local function noteHas(src, pat) for _, n in ipairs(notes[src] or {}) do if n.msg:find(pat, 1, true) then return true end end return false end
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

-- Inventaire : objets avec métadonnées (comparaison partielle comme Shared.MetaMatches)
local usable = {}
local function metaOk(m, want)
    if want == nil then return true end
    m = m or {}
    for k, v in pairs(want) do if m[k] ~= v then return false end end
    return true
end
-- Stockages : joueurs (id numérique) et coffres (id texte, ex. « resto:1 »)
local stashes, stashFull = {}, {}
local function store(inv)
    if type(inv) == 'string' then stashes[inv] = stashes[inv] or { items = {} } return stashes[inv], stashFull[inv] end
    local p = players[tonumber(inv) or -1]
    if p then return p, p.invFull end
end
local function count(src, name, meta)
    local st = store(src)
    local n = 0
    for _, it in ipairs(st and st.items or {}) do if it.name == name and metaOk(it.metadata, meta) then n = n + it.count end end
    return n
end
local function copy(t) if type(t) ~= 'table' then return t end local o = {} for k, v in pairs(t) do o[k] = copy(v) end return o end
local inventory = {
    AddItem = function(_, src, name, qty, meta)
        local p, full = store(src)
        if not p or full then return false end
        p.items[#p.items + 1] = { name = name, count = qty or 1, metadata = copy(meta) }
        return true
    end,
    RemoveItem = function(_, src, name, qty, meta)
        local p = store(src)
        if not p or count(src, name, meta) < (qty or 1) then return false end
        local left = qty or 1
        for i = #p.items, 1, -1 do
            local it = p.items[i]
            if left > 0 and it.name == name and metaOk(it.metadata, meta) then
                local take = math.min(left, it.count)
                it.count, left = it.count - take, left - take
                if it.count <= 0 then table.remove(p.items, i) end
            end
        end
        return true
    end,
    GetItemCount = function(_, src, name, meta) return store(src) and count(src, name, meta) or 0 end,
    Search = function(_, src, kind, name, meta)
        local out = {}
        for i, it in ipairs(players[src].items) do if it.name == name and metaOk(it.metadata, meta) then out[#out + 1] = { slot = i, name = it.name, count = it.count, metadata = copy(it.metadata) } end end
        return out
    end,
    CanCarryItem = function(_, src) local p, full = store(src) return p ~= nil and not full end,
    CanCarryItems = function(_, src) local p, full = store(src) return p ~= nil and not full end,
    RegisterUsableItem = function(_, name, cb) usable[name] = cb end,
    RegisterStash = function(_, id) store(id) end,
    RegisterStashAccess = function() end,
    OpenInventory = function() return true end,
}
local function useItem(src, name)
    for i, it in ipairs(players[src].items) do
        if it.name == name then return usable[name](src, { name = name, slot = i, count = it.count, metadata = copy(it.metadata) }) end
    end
end
local staff = {}
local adminMenu = {
    HasPermission = function(_, src, perm) return staff[src] == true and perm == 'resto_manage' end,
    AddLog = function() end,
}

-- ---------------------------------------------------------------------
-- Environnement du script serveur
-- ---------------------------------------------------------------------
local callbacks, handlers, exportsTbl = {}, {}, {}
local GlobalState, states = {}, {}
local env = setmetatable({}, { __index = _G })
env.json = json
env.vector3 = vector3
env.CreateThread = CreateThread
env.Wait = Wait
env.SetTimeout = function(ms, fn) CreateThread(function() Wait(ms) fn() end) end
env.GetGameTimer = function() return GT end
env.os = setmetatable({ time = function(t) if t then return os.time(t) end return BASE + GT // 1000 end }, { __index = os })
env.MySQL = MySQL
env.GlobalState = GlobalState
env.print = function(...) local s = table.concat({ ... }, ' ') if s:find('%^1') then errors[#errors + 1] = s P('  ' .. s) end end
env.exports = setmetatable({ elyzea_core = core, elyzea_inventory = inventory, admin_menu = adminMenu }, {
    __call = function(_, name, fn) exportsTbl[name] = fn end,
})
env.GetResourceState = function(r) return (r == 'admin_menu' or r == 'elyzea_inventory') and 'started' or 'missing' end
env.GetCurrentResourceName = function() return 'elyzea_restaurant' end
env.Ely = { callback = { register = function(n, fn) callbacks[n] = fn end } }
env.AddEventHandler = function(name, fn) handlers[name] = handlers[name] or {} table.insert(handlers[name], fn) end
env.RegisterNetEvent = function(name, fn) if fn then env.AddEventHandler(name, fn) end end
local pushes = 0
env.TriggerEvent = function(name, ...) if name == 'elyzea_jobphone:pushRes' then pushes = pushes + 1 end for _, fn in ipairs(handlers[name] or {}) do fn(...) end end
env.TriggerClientEvent = function(name, src, ...) clientEvents[#clientEvents + 1] = { src = src, name = name, args = { ... } } end
env.GetPlayerName = function(src) local p = players[tonumber(src) or -1] return p and p.name or nil end
env.GetPlayerPed = function(src) return players[src] and src or 0 end
env.GetEntityCoords = function(ped) local p = players[ped] return p and p.pos or vector3(0, 0, 0) end
env.GetEntityHeading = function() return 90.0 end
env.SetEntityCoords = function(ped, x, y, z) local p = players[ped] if p then p.pos = vector3(x, y, z) end end
env.Player = function(src) states[src] = states[src] or {} local st = states[src] return { state = setmetatable({ set = function(_, k, v) st[k] = v end }, { __index = st }) } end
env.source = 0
env.IsDuplicityVersion = function() return true end
env.LoadResourceFile = function(res, file)
    local f = io.open(ROOT .. '/../' .. res .. '/' .. file, 'r')
    if not f then return nil end
    local s = f:read('a') f:close()
    return s
end

local function loadFile(path)
    local f = assert(io.open(ROOT .. '/' .. path, 'r'))
    local s = f:read('a') f:close()
    assert(load(s, '@' .. path, 't', env))()
end
for _, f in ipairs({ 'config.lua', 'shared/cuisine.lua', 'shared/perms.lua', 'shared/games.lua', 'server/main.lua', 'server/service.lua', 'server/finance.lua', 'server/commission.lua',
    'server/direction.lua', 'server/resto.lua', 'server/pesos.lua', 'server/orders.lua', 'server/kitchen.lua', 'server/bag.lua', 'server/admin.lua', 'server/phone.lua', 'server/api.lua' }) do loadFile(f) end
local R, Config, RSGames = env.Resto, env.Config, env.RSGames

local function req(src, action, data) run(120) return callbacks['resto:req'](src, action, data or {}) end
local function pub(src, action, data) run(120) return callbacks['resto:pub'](src, action, data or {}) end
local function adm(src, action, data) run(120) return callbacks['resto:admin'](src, action, data or {}) end
local function lastClient(src, name) for i = #clientEvents, 1, -1 do local e = clientEvents[i] if e.src == src and e.name == name then return e end end end
local function dbOrder(id) return MySQL.single.await('SELECT * FROM `rs_orders` WHERE `id` = ?', { id }) end

-- Bonne réponse d'un mini-jeu à partir des paramètres envoyés par le serveur
local function solve(game, p)
    local mid = function(z) return (z.from + z.to) / 2 end
    if game == 'burger' then local g = {} for i, z in ipairs(p.cook) do g[i] = mid(z) end return { gauge = g, seq = copy(p.recipe) } end
    if game == 'pizza' then local s = {} for i, x in ipairs(p.spots) do s[i] = { x = x.x + 1, y = x.y - 1 } end return { spots = s, gauge = mid(p.bake) } end
    if game == 'drink' then return { level = mid(p) } end
    if game == 'dessert' then return { picked = copy(p.need) } end
    if game == 'fries' then return { t = mid(p) } end
    if game == 'plat' then return { gauge = p.cook and mid(p.cook) or nil, picked = copy(p.need) } end
end

-- ---------------------------------------------------------------------
P('\n[Démarrage]')
run(200)
check(R.ready, 'ressource prête (tables rs_* créées dans MariaDB)')
local tables = MySQL.query.await("SHOW TABLES LIKE 'rs\\_%'")
check(#tables >= 10, ('%d tables rs_* en base'):format(#tables))

-- Joueurs : 1 staff, 2 patron du restaurant A, 3 client, 4 cuisinier A, 5 patron du restaurant B
local A0 = vector3(100, 100, 30)
makePlayer(1, 'STAFF1', 'Sam', 'Staff', A0)
makePlayer(2, 'EMP2', 'Paul', 'Patron', A0)
makePlayer(3, 'CLI3', 'Claire', 'Cliente', A0)
makePlayer(4, 'EMP4', 'Kevin', 'Cuistot', A0)
makePlayer(5, 'EMP5', 'Bea', 'Autre', vector3(500, 500, 30))
staff[1] = true

P('\n[Staff : création et réglage du restaurant A]')
local r = adm(1, 'shopSave', { name = 'Pizza This', job = 'resto_pizza', logo = '🍕', color = '#ef4444' })
check(r.ok and r.id, 'restaurant A créé : ' .. tostring(r.message or r.error))
local A = r.id
check(jobs.resto_pizza ~= nil, 'métier elyzea_core « resto_pizza » déclaré')
r = adm(1, 'shopEnable', { id = A, enabled = true })
check(r.error and r.error:find('point de commande'), 'activation refusée sans point de commande')
players[1].pos = vector3(100, 100, 30) check(adm(1, 'point', { id = A, key = 'order' }).ok, 'point de commande posé')
players[1].pos = vector3(105, 100, 30) check(adm(1, 'station', { id = A, types = { 'grill', 'oven' } }).ok, 'station 1 (grill + four) posée')
players[1].pos = vector3(110, 100, 30) check(adm(1, 'station', { id = A, types = { 'fountain', 'pastry', 'fryer' } }).ok, 'station 2 (fontaine, pâtisserie, friteuse) posée')
check(adm(1, 'station', { id = A, types = { 'inconnu' } }).error ~= nil, 'station sans type valable refusée')
check(adm(1, 'shopEnable', { id = A, enabled = true }).ok, 'restaurant A activé')
check(adm(1, 'setBoss', { id = A, target = 2 }).ok, 'patron nommé (joueur 2)')
local okHire = exportsTbl.AdminSetGrade(1, 4, (function() for _, g in ipairs(R.SortedGrades(A)) do if g.name == 'Cuisinier' then return g.id end end end)())
check(okHire, 'joueur 4 recruté Cuisinier (admin_menu › Métier staff)')
check(adm(3, 'data').error ~= nil, 'panneau staff refusé à un joueur sans permission')

P('\n[Commande du client]')
check(req(2, 'duty', { on = true }).duty == true, 'patron en service')
check(req(4, 'duty', { on = true }).duty == true, 'cuisinier en service')
local card = pub(3, 'menuCard', { shop = A })
check(card.shop and card.shop.open and #card.products >= 5, ('carte publique : %d produit(s), ouverte'):format(#(card.products or {})))
local priceOf = {} for _, p in ipairs(card.products) do priceOf[p.id] = p.price end
players[3].pos = vector3(130, 100, 30)
check((pub(3, 'order', { shop = A, method = 'bank', lines = { { id = 'classic', qty = 1 } } }).error or ''):find('Approchez'), 'commande refusée loin du point de commande')
players[3].pos = vector3(100.5, 100, 30)
check(pub(3, 'order', { shop = A, method = 'bank', lines = { { id = 'inexistant', qty = 1 } } }).error ~= nil, 'produit inconnu refusé')
check(pub(3, 'order', { shop = A, method = 'bank', lines = { { id = 'veggie', qty = 1 } } }).error ~= nil, 'produit retiré de la carte refusé')
check(pub(3, 'order', { shop = A, method = 'bank', lines = { { id = 'classic', qty = 0 } } }).error ~= nil, 'quantité 0 refusée')
check(pub(3, 'order', { shop = A, method = 'crypto', lines = { { id = 'classic', qty = 1 } } }).error ~= nil, 'moyen de paiement inconnu refusé')
check(pub(3, 'order', { shop = A, method = 'bank', expect = 1, lines = { { id = 'classic', qty = 1 } } }).reload == true, 'total différent du client (prix changé) refusé')
players[3].money.cash = 10
check((pub(3, 'order', { shop = A, method = 'cash', lines = { { id = 'classic', qty = 3 } } }).error or ''):find('espèces'), 'espèces insuffisantes : refusé, rien débité')
players[3].money.cash = 500
local total = priceOf.classic * 3 + priceOf.cola
local bank0, soc0 = players[3].money.bank, society.resto_pizza or 0
r = pub(3, 'order', { shop = A, method = 'bank', expect = total, lines = { { id = 'classic', qty = 2 }, { id = 'cola', qty = 1 }, { id = 'classic', qty = 1 } } })
check(r.ok and r.order and r.order.num == '#001', 'commande #001 payée : ' .. tostring(r.message or r.error))
local O1 = r.order.id
check(players[3].money.bank == bank0 - total, ('client débité de %d $ (banque)'):format(total))
check((society.resto_pizza or 0) == soc0 + total, 'compte du restaurant crédité')
check(#r.order.lines == 2 and r.order.lines[1].qty == 3, 'doublons fusionnés : 3 × Classic, 1 × Cola')
check(noteHas(2, 'Nouvelle commande reçue ! Commande #001 – 4 produit(s)'), 'patron (en service) prévenu : « Nouvelle commande reçue ! Commande #001 – 4 produit(s)… »')
check(noteHas(4, 'Commande #001'), 'cuisinier (en service) prévenu')
check(not noteHas(5, 'Commande #001'), 'employé d\'un autre restaurant non prévenu')
check(not noteHas(1, 'Commande #001'), 'non-employé non prévenu')
local row = dbOrder(O1)
check(row and row.status == 'pending' and tonumber(row.total) == total, 'commande enregistrée en base (pending)')
check(pushes > 0, 'appli « Commande » rafraîchie (téléphones ouverts)')

P('\n[Prise en charge (jamais deux employés)]')
local list4 = req(4, 'ordersList')
check(#list4.pending == 1 and list4.pending[1].num == '#001', 'cuisinier voit la commande en attente')
r = req(2, 'orderTake', { id = O1 })
check(r.ok, 'patron prend la commande #001')
r = req(4, 'orderTake', { id = O1 })
check(r.error and r.error:find('Paul Patron'), 'cuisinier refusé : « déjà prise en charge par Paul Patron »')
list4 = req(4, 'ordersList')
check(#list4.pending == 0 and #list4.others == 1, 'la commande disparaît de « En attente » pour les autres')
check(#req(2, 'ordersList').mine == 1, 'elle est dans « Mes commandes » du patron')
check(dbOrder(O1).status == 'preparing' and dbOrder(O1).employee_cid == 'EMP2', 'base : En préparation, employé EMP2')
check(noteHas(3, 'en préparation'), 'client prévenu : en préparation')

P('\n[Cuisine : stations et mini-jeux validés par le serveur]')
players[2].pos = vector3(120, 100, 30)
check((req(2, 'stationOptions', { station = 1 }).error or ''):find('Approchez'), 'station : refusée de loin')
players[2].pos = vector3(105.5, 100, 30)
local opts = req(2, 'stationOptions', { station = 1 })
check(#opts.list == 1 and opts.list[1].label == 'Le Classic', 'grill : seul le burger est proposé (pas le cola)')
players[4].pos = vector3(105.2, 100.5, 30)
local o4 = req(4, 'stationOptions', { station = 1 })
check(o4.list and #o4.list == 0 and o4.empty ~= nil, 'le cuisinier ne voit pas la commande du patron à la station')
check(req(4, 'cookStart', { station = 1, order = O1, line = 1 }).error ~= nil, 'le cuisinier ne peut pas cuisiner la commande du patron')
check(req(2, 'cookStart', { station = 1, order = O1, line = 2 }).error ~= nil, 'cola refusé au grill (mauvaise station)')
local c = req(2, 'cookStart', { station = 1, order = O1, line = 1 })
check(c.ok and c.game == 'burger' and c.token, 'mini-jeu burger lancé (jeton à usage unique)')
r = req(2, 'cookFinish', { token = c.token, result = solve('burger', c.params) })
check(r.failed and (r.message or ''):find('trop rapide'), 'réussite en moins de 3,5 s refusée')
c = req(2, 'cookStart', { station = 1, order = O1, line = 1 })
run(6000)
local bad = solve('burger', c.params) bad.seq[1], bad.seq[2] = bad.seq[2], bad.seq[1]
r = req(2, 'cookFinish', { token = c.token, result = bad })
check(r.failed and (r.message or ''):find('ordre'), 'mauvais ordre de montage : raté')
check(R.orders[O1].lines[1].done == 0, 'raté : rien n\'est préparé')
c = req(2, 'cookStart', { station = 1, order = O1, line = 1 })
run(40000)
r = req(2, 'cookFinish', { token = c.token, result = solve('burger', c.params) })
check(r.failed and (r.message or ''):find('lent'), 'trop lent (au-delà de la durée) : raté')
c = req(2, 'cookStart', { station = 1, order = O1, line = 1 })
run(6000)
r = req(2, 'cookFinish', { token = c.token, result = solve('burger', c.params) })
check(r.ok and r.done == 2, 'burger réussi : 2 / 3 prêts (2 unités par mini-jeu)')
check(req(2, 'cookFinish', { token = c.token, result = solve('burger', c.params) }).error ~= nil, 'jeton rejoué : refusé')
c = req(2, 'cookStart', { station = 1, order = O1, line = 1 })
run(6000)
players[2].pos = vector3(120, 100, 30)
r = req(2, 'cookFinish', { token = c.token, result = solve('burger', c.params) })
check(r.failed and (r.message or ''):find('quitté'), 'employé parti de la station : raté')
players[2].pos = vector3(105.5, 100, 30)
c = req(2, 'cookStart', { station = 1, order = O1, line = 1 })
run(6000)
r = req(2, 'cookFinish', { token = c.token, result = solve('burger', c.params) })
check(r.ok and r.done == 3, 'burgers : 3 / 3')
players[2].pos = vector3(110.3, 100, 30)
c = req(2, 'cookStart', { station = 2, order = O1, line = 2 })
check(c.ok and c.game == 'drink', 'fontaine : mini-jeu boisson')
run(6000)
r = req(2, 'cookFinish', { token = c.token, result = { level = 100 } })
check(r.failed, 'verre trop rempli : raté')
c = req(2, 'cookStart', { station = 2, order = O1, line = 2 })
run(6000)
r = req(2, 'cookFinish', { token = c.token, result = solve('drink', c.params) })
check(r.ok and r.complete, 'dernier produit prêt : commande terminée')
check(R.orders[O1].status == 'ready' and dbOrder(O1).status == 'ready', 'statut « Terminée » (mémoire + base)')
local uid = R.orders[O1].bag
check(count(2, 'restaurant_bag', { uid = uid }) == 1, 'UN sac « restaurant_bag » dans l\'inventaire du patron')
check(count(2, 'bs_burger_classic') == 0 and count(2, 'bs_drink_cola') == 0, 'aucun produit individuel donné à l\'employé')
local bagItem = players[2].items[#players[2].items]
check(bagItem.metadata.num == '#001' and bagItem.metadata.order == O1 and (bagItem.metadata.description or ''):find('3 × Le Classic'), 'métadonnées du sac : numéro, commande, contenu')
check(noteHas(3, 'prête'), 'client prévenu : commande prête')

P('\n[Le sac ne s\'ouvre pas avant la remise]')
useItem(2, 'restaurant_bag')
check(lastNote(2):find('pas encore été remis'), 'employé : ouverture refusée (commande non livrée)')
check(count(2, 'restaurant_bag', { uid = uid }) == 1, 'le sac est toujours là')

P('\n[Remise au client]')
check((req(4, 'orderDeliver', { id = O1 }).error or ''):find('sac'), 'cuisinier sans le sac : refusé')
players[3].pos = vector3(140, 100, 30)
check((req(2, 'orderDeliver', { id = O1 }).error or ''):find('moins de'), 'client trop loin : refusé')
players[3].pos = vector3(111, 100, 30)
players[3].invFull = true
check((req(2, 'orderDeliver', { id = O1 }).error or ''):find('plein'), 'inventaire du client plein : refusé, sac gardé')
check(count(2, 'restaurant_bag', { uid = uid }) == 1, 'sac toujours chez l\'employé')
players[3].invFull = false
local bankEmp = players[2].money.bank
r = req(2, 'orderDeliver', { id = O1 })
check(r.ok, 'sac remis : ' .. tostring(r.message or r.error))
check(count(2, 'restaurant_bag') == 0 and count(3, 'restaurant_bag', { uid = uid }) == 1, 'le sac passe de l\'employé au client')
check(dbOrder(O1).status == 'delivered' and R.orders[O1] == nil, 'statut « Livrée »')
check(noteHas(3, 'vous a été remise'), 'client prévenu de la remise')
check(req(2, 'orderDeliver', { id = O1 }).error ~= nil, 'double remise : refusée')

P('\n[Ouverture du sac par le client]')
useItem(3, 'restaurant_bag')
local ev = lastClient(3, 'resto:client:bag')
check(ev and #ev.args[1].lines == 2, 'sac ouvert : 2 produits affichés')
players[3].invFull = true
check((pub(3, 'bagTake', { uid = uid }).error or ''):find('place'), 'inventaire plein : rien pris')
players[3].invFull = false
r = pub(3, 'bagTake', { uid = uid, line = 2 })
check(r.ok and count(3, 'bs_drink_cola') == 1 and count(3, 'restaurant_bag') == 1, 'cola pris, le sac reste (burgers dedans)')
check(pub(3, 'bagTake', { uid = uid, line = 2 }).error ~= nil, 'cola repris : rien (déjà sorti)')
r = pub(3, 'bagTake', { uid = uid })
check(r.ok and r.empty and count(3, 'bs_burger_classic') == 3, '« Tout prendre » : 3 burgers, sac vide')
check(count(3, 'restaurant_bag') == 0, 'sac vide supprimé')
check(tonumber(dbOrder(O1).opened) == 1, 'base : sac ouvert (opened = 1)')
inventory:AddItem(3, 'restaurant_bag', 1, bagItem.metadata)   -- copie frauduleuse du même sac
useItem(3, 'restaurant_bag')
check(lastNote(3):find('vide') and count(3, 'bs_burger_classic') == 3, 'copie du sac (même numéro) : vide, aucun produit en double')
check(count(3, 'restaurant_bag') == 0, 'copie jetée')
check(pub(4, 'bagTake', { uid = uid }).error ~= nil, 'prendre sans avoir le sac : refusé')

P('\n[Annulation, remboursement, expiration, limites]')
players[3].pos = vector3(100.5, 100, 30)
r = pub(3, 'order', { shop = A, method = 'cash', lines = { { id = 'fries', qty = 1 } } })
check(r.ok and r.order.num == '#002', 'commande #002 (espèces)')
local O2 = r.order.id
r = pub(3, 'order', { shop = A, method = 'cash', lines = { { id = 'donut', qty = 2 } } })
local O3 = r.order and r.order.id
check(O3 ~= nil, 'commande #003')
check((pub(3, 'order', { shop = A, method = 'cash', lines = { { id = 'donut', qty = 1 } } }).error or ''):find('en cours'), '3e commande en cours refusée (max 2 par client)')
check(req(4, 'orderCancel', { id = O2 }).error ~= nil, 'cuisinier sans « orders_manage » : annulation refusée')
check(req(4, 'orderTake', { id = O2 }).ok, 'cuisinier prend #002')
players[4].pos = vector3(110.3, 100, 30)
c = req(4, 'cookStart', { station = 2, order = O2, line = 1 })
run(7000)
check(req(4, 'cookFinish', { token = c.token, result = solve('fries', c.params) }).complete, 'frites prêtes : #002 terminée, sac au cuisinier')
local uid2 = R.orders[O2].bag
local cash0 = players[3].money.cash
r = req(2, 'orderCancel', { id = O2, reason = 'Test' })
check(r.ok, 'patron annule #002 (sac prêt)')
check(count(4, 'restaurant_bag', { uid = uid2 }) == 0, 'sac repris au cuisinier')
check(players[3].money.cash == cash0 + priceOf.fries, 'client remboursé en espèces')
check(dbOrder(O2).status == 'cancelled', 'base : Annulée')
cash0 = players[3].money.cash
run(61 * 60 * 1000)
check(dbOrder(O3).status == 'cancelled' and players[3].money.cash == cash0 + priceOf.donut * 2, '#003 jamais prise en 60 min : annulée et remboursée')

P('\n[Deux restaurants séparés]')
players[1].pos = vector3(500, 500, 30)
local B = adm(1, 'shopSave', { name = 'Burger B', job = 'resto_b' }).id
adm(1, 'point', { id = B, key = 'order' })
adm(1, 'station', { id = B, types = { 'grill' } })
adm(1, 'shopEnable', { id = B, enabled = true })
check(adm(1, 'setBoss', { id = B, target = 5 }).ok, 'restaurant B : patron joueur 5')
req(5, 'duty', { on = true })
players[3].pos = vector3(100.5, 100, 30)
r = pub(3, 'order', { shop = A, method = 'bank', lines = { { id = 'cola', qty = 1 } } })
local O4 = r.order and r.order.id
check(O4 ~= nil and r.order.num == '#004', 'nouvelle commande au restaurant A (#004)')
check(not noteHas(5, '#004'), 'patron de B non prévenu')
check(#req(5, 'ordersList').pending == 0, 'B ne voit pas les commandes de A')
check(req(5, 'orderTake', { id = O4 }).error ~= nil, 'B ne peut pas prendre une commande de A')
players[3].pos = vector3(500.5, 500, 30)
r = pub(3, 'order', { shop = B, method = 'bank', lines = { { id = 'classic', qty = 1 } } })
check(r.ok and r.order.num == '#001', 'restaurant B : sa propre numérotation (#001)')
check(society.resto_b == priceOf.classic, 'argent de B sur le compte de B')

P('\n[Téléphone de service (appli Commande)]')
local ph = exportsTbl.PhoneBridge('cmd', 4, { op = 'list' })
check(ph and #ph.pending == 1 and ph.pending[1].num == '#004', 'appli : « En attente » du cuisinier de A')
check(exportsTbl.PhoneBridge('cmd', 4, { op = 'take', data = { id = O4 } }).ok, 'appli : prise en charge')
check(exportsTbl.PhoneBridge('cmd', 2, { op = 'take', data = { id = O4 } }).error ~= nil, 'appli : second employé refusé')
check(exportsTbl.PhoneBridge('cmd', 4, { op = 'release', data = { id = O4 } }).ok, 'appli : commande rendue (remise en attente)')
check(exportsTbl.PhoneBridge('cmd', 3, { op = 'list' }) == nil or exportsTbl.PhoneBridge('cmd', 3, { op = 'list' }).error ~= nil, 'appli : refusée à un non-employé')
req(4, 'duty', { on = false })
check(exportsTbl.PhoneBridge('cmd', 4, { op = 'take', data = { id = O4 } }).error ~= nil, 'hors service : prise en charge refusée')

P('\n[Recettes elyzea_cuisine au catalogue]')
do
    local ids = {}
    for id, o in pairs(R.orders) do if o.cid == 'CLI3' then ids[#ids + 1] = id end end
    for _, id in ipairs(ids) do adm(1, 'orderCancel', { order = id }) end
end
check(env.RSCuisine.count == 80, ('%d recettes ajoutées au catalogue (80 attendues)'):format(env.RSCuisine.count))
local PR = R.Products
check(PR.it_lasagnes and PR.it_lasagnes.item == 'it_lasagnes' and PR.it_lasagnes.station == 'oven' and PR.it_lasagnes.game == 'plat', 'lasagnes : objet it_lasagnes, mini-jeu plat au four')
check(PR.jp_sushi_saumon.game == 'plat' and PR.jp_sushi_saumon.cook == false and PR.jp_sushi_saumon.station == 'prep', 'sushi : dressage sans cuisson, plan de travail')
check(PR.ff_cheeseburger.game == 'burger' and PR.it_pizza_margherita.game == 'pizza' and PR.ff_frites.game == 'fries', 'burgers, pizzas et fritures : mini-jeux existants')
check(PR.mx_agua_fresca.station == 'fountain' and PR.it_tiramisu.station == 'pastry' and PR.jp_ramen_porc.station == 'stove', 'boissons → fontaine, desserts → pâtisserie, ramen → piano')
local nCat = 0 for _, cc in ipairs(Config.Categories) do if cc.cuisine then nCat = nCat + 1 end end
check(nCat == 4, '4 catégories ajoutées (italien, fast-food, japonais, mexicain)')
local coherent = true
for _, p in ipairs(Config.Products) do
    if not Config.StationTypes[p.station] or not RSGames[p.game] or not Config.MiniGames[p.game] or not p.price or p.price < 1 then coherent = false P('    incohérent : ' .. p.id) end
end
check(coherent, ('chaque produit (%d) : station, mini-jeu et prix valables'):format(#Config.Products))
local nMenu = 0 for _ in pairs(R.menu[A]) do nMenu = nMenu + 1 end
check(nMenu == #Config.Products, 'carte de A : une ligne par produit du catalogue')
card = pub(3, 'menuCard', { shop = A })
local anyCu = false for _, p in ipairs(card.products) do if PR[p.id].cuisine then anyCu = true end end
check(not anyCu, 'recettes pas à la carte tant que personne ne les met')

P('\n[Staff (admin_menu) : produits vendus par restaurant]')
local dd = adm(1, 'data')
check(#dd.products == #Config.Products and dd.cuisine.count == 80, ('panneau staff : catalogue complet (%d produits)'):format(#dd.products))
check(adm(1, 'catalogSet', { id = A, products = {} }).error ~= nil, 'aucune case cochée : refusé')
check(adm(3, 'catalogSet', { id = A, all = true }).error ~= nil, 'joueur sans permission staff : refusé')
r = adm(1, 'catalogSet', { id = A, products = { 'classic', 'cola', 'it_lasagnes', 'jp_sushi_saumon', 'jp_ramen_porc', 'inconnu' } })
check(r.ok, 'A : 5 produits autorisés : ' .. tostring(r.message or r.error))
check(#R.shops[A].options.catalog == 5, 'identifiant inconnu ignoré')
local saved = MySQL.single.await('SELECT `options` FROM `rs_shops` WHERE `id` = ?', { A })
check(saved and saved.options:find('it_lasagnes', 1, true), 'liste enregistrée en base (rs_shops.options)')
card = pub(3, 'menuCard', { shop = A })
local on = {} for _, p in ipairs(card.products) do on[p.id] = true end
check(#card.products == 5 and on.it_lasagnes and on.jp_sushi_saumon and on.classic, 'carte publique : exactement les 5 produits autorisés')
check(not on.fries and not on.donut, 'produits non autorisés retirés de la carte publique')
local tm = req(2, 'menu')
check(#tm.list == 5 and tm.restricted == true, 'tablette du patron : seulement les 5 produits autorisés')
check(req(2, 'menuSet', { id = 'fries', enabled = true }).error ~= nil, 'patron : remettre un produit non autorisé refusé')
check(req(2, 'menuSet', { id = 'it_lasagnes', price = 31 }).ok, 'patron : prix des lasagnes fixé à 31 $')
players[3].pos = vector3(100.5, 100, 30)
check(pub(3, 'order', { shop = A, method = 'bank', lines = { { id = 'fries', qty = 1 } } }).error ~= nil, 'commande d\'un produit non autorisé refusée')
local cardB = pub(3, 'menuCard', { shop = B })
local onB = {} for _, p in ipairs(cardB.products) do onB[p.id] = true end
check(onB.fries and not onB.it_lasagnes, 'restaurant B non touché (sa carte de départ)')
dd = adm(1, 'data')
local sA for _, x in ipairs(dd.shops) do if x.id == A then sA = x end end
check(sA and #sA.onMenu == 5 and #sA.options.catalog == 5, 'panneau staff : liste et carte de A à jour')

P('\n[Recette commandée, préparée aux stations, livrée]')
players[1].pos = vector3(115, 100, 30)
check(adm(1, 'station', { id = A, types = { 'prep', 'stove' } }).ok, 'station 3 (plan de travail + piano) posée')
r = pub(3, 'order', { shop = A, method = 'bank', expect = 31 + PR.jp_sushi_saumon.price, lines = { { id = 'it_lasagnes', qty = 1 }, { id = 'jp_sushi_saumon', qty = 1 } } })
check(r.ok, 'commande lasagnes + sushi payée : ' .. tostring(r.message or r.error))
local OC = r.order.id
check(req(2, 'orderTake', { id = OC }).ok, 'patron prend la commande')
players[2].pos = vector3(105.5, 100, 30)
c = req(2, 'cookStart', { station = 1, order = OC, line = 1 })
check(c.ok and c.game == 'plat' and c.params.cook and c.params.labels and c.params.labels[c.params.need[1]], 'lasagnes au four : cuisson + dressage (ingrédients italiens envoyés)')
local itOk = true for k in pairs(c.params.labels) do if not Config.Cuisine.ingredients.italien[k] then itOk = false end end
check(itOk, 'ingrédients proposés : ceux de la cuisine italienne')
run(4000)
local w = solve('plat', c.params) w.gauge = c.params.cook.to + 4
check(req(2, 'cookFinish', { token = c.token, result = w }).failed, 'cuisson ratée : refusé')
c = req(2, 'cookStart', { station = 1, order = OC, line = 1 })
run(4000)
check(req(2, 'cookFinish', { token = c.token, result = solve('plat', c.params) }).ok, 'lasagnes prêtes')
check(req(2, 'cookStart', { station = 1, order = OC, line = 2 }).error ~= nil, 'sushi refusé au four (mauvaise station)')
players[2].pos = vector3(115.3, 100, 30)
c = req(2, 'cookStart', { station = 3, order = OC, line = 2 })
check(c.ok and c.game == 'plat' and c.params.cook == nil, 'sushi au plan de travail : dressage seul')
run(4000)
w = solve('plat', c.params) w.picked[1] = 'zzz'
check(req(2, 'cookFinish', { token = c.token, result = w }).failed, 'mauvais ingrédient : raté')
c = req(2, 'cookStart', { station = 3, order = OC, line = 2 })
run(4000)
r = req(2, 'cookFinish', { token = c.token, result = solve('plat', c.params) })
check(r.ok and r.complete, 'commande terminée, sac donné')
local uidC = R.orders[OC].bag
players[3].pos = vector3(116, 100, 30)
check(req(2, 'orderDeliver', { id = OC }).ok, 'sac remis au client')
check(pub(3, 'bagTake', { uid = uidC }).ok, 'client vide le sac')
check(count(3, 'it_lasagnes') == 1 and count(3, 'jp_sushi_saumon') == 1, 'client : 1 objet it_lasagnes + 1 objet jp_sushi_saumon (consommables elyzea_cuisine)')

P('\n[Paiement en pesos]')
players[3].pos = vector3(100.5, 100, 30)
local SID = 'resto:' .. A
card = pub(3, 'menuCard', { shop = A })
local hasP = false for _, m in ipairs(card.methods) do if m == 'pesos' then hasP = true end end
check(not hasP, 'par défaut : pesos non proposés')
check((pub(3, 'order', { shop = A, method = 'pesos', lines = { { id = 'cola', qty = 1 } } }).error or ''):find('non accepté'), 'paiement en pesos refusé tant que le staff ne l\'a pas coché')
check(adm(1, 'paymentsSet', { id = A, methods = {} }).error ~= nil, 'aucun moyen coché : refusé')
r = adm(1, 'paymentsSet', { id = A, methods = { 'bank', 'pesos', 'crypto' } })
check(r.ok, 'staff : banque + pesos : ' .. tostring(r.message or r.error))
card = pub(3, 'menuCard', { shop = A })
check(#card.methods == 2 and card.methods[1] == 'bank' and card.methods[2] == 'pesos', 'carte : banque et pesos (moyen inconnu ignoré)')
check(pub(3, 'order', { shop = A, method = 'cash', lines = { { id = 'cola', qty = 1 } } }).error ~= nil, 'espèces décochées : refusé')
check((pub(3, 'order', { shop = A, method = 'pesos', lines = { { id = 'it_lasagnes', qty = 1 } } }).error or ''):find('pesos'), 'pas de pesos sur soi : refusé')
inventory:AddItem(3, 'pesos', 100)
local socP = society.resto_pizza
local bankP = players[3].money.bank
r = pub(3, 'order', { shop = A, method = 'pesos', expect = 31, lines = { { id = 'it_lasagnes', qty = 1 } } })
check(r.ok and r.order.method == 'pesos' and r.order.paid == 31 and r.order.currency == 'pesos', 'commande payée en pesos : ' .. tostring(r.message or r.error))
local OP = r.order.id
check(count(3, 'pesos') == 69 and players[3].money.bank == bankP, 'client : 31 pesos retirés, banque intacte')
check(count(SID, 'pesos') == 31, 'coffre du restaurant : +31 pesos')
check(society.resto_pizza == socP, 'compte de société en $ inchangé')
local rowP = dbOrder(OP)
check(rowP.method == 'pesos' and tonumber(rowP.paid) == 31 and tonumber(rowP.total) == 31, 'base : method = pesos, paid = 31')
Config.Pesos.rate = 1.5
check(R.PesosPrice(31) == 47 and R.PesosPrice(8) == 12, 'taux 1,5 : 31 $ → 47 pesos (arrondi au-dessus)')
Config.Pesos.rate = 1.0
stashFull[SID] = true
local before = count(3, 'pesos')
local rr = pub(3, 'order', { shop = A, method = 'pesos', lines = { { id = 'cola', qty = 1 } } })
check((rr.error or ''):find('coffre', 1, true) ~= nil, 'coffre du restaurant plein : commande refusée (' .. tostring(rr.error) .. ')')
stashFull[SID] = nil
check(count(3, 'pesos') == before, 'coffre plein : aucun peso perdu')
local p0, s0 = count(3, 'pesos'), count(SID, 'pesos')
r = adm(1, 'orderCancel', { order = OP })
check(r.ok, 'staff annule la commande en pesos')
check(count(3, 'pesos') == p0 + 31 and count(SID, 'pesos') == s0 - 31, 'remboursée en pesos, repris dans le coffre')
check(noteHas(3, '31 pesos remboursés'), 'client prévenu : « 31 pesos remboursés »')
r = pub(3, 'order', { shop = A, method = 'pesos', lines = { { id = 'cola', qty = 1 } } })
local OP2 = r.order and r.order.id
check(OP2 ~= nil, 'nouvelle commande en pesos (cola)')
inventory:RemoveItem(SID, 'pesos', count(SID, 'pesos'))
check((adm(1, 'orderCancel', { order = OP2 }).error or ''):find('coffre'), 'coffre vidé par le patron : annulation refusée (rien n\'est inventé)')
inventory:AddItem(SID, 'pesos', PR.cola and R.menu[A].cola.price or 8)
local p3 = players[3]
local held = count(3, 'pesos')
players[3] = nil   -- le client se déconnecte
run(61 * 60 * 1000)
check(dbOrder(OP2).status == 'cancelled', 'client absent, commande jamais prise : annulée après 60 min')
local pend = MySQL.query.await('SELECT * FROM `rs_refunds` WHERE `citizenid` = ?', { 'CLI3' })
check(#pend == 1 and tonumber(pend[1].amount) == R.menu[A].cola.price and pend[1].item == 'pesos', 'remboursement en pesos mis de côté (rs_refunds)')
players[3] = p3
p3.invFull = true
env.TriggerEvent('elyzea:server:playerLoaded', 3)
run(6000)
check(#MySQL.query.await('SELECT * FROM `rs_refunds` WHERE `citizenid` = ?', { 'CLI3' }) == 1 and count(3, 'pesos') == held, 'reconnexion, inventaire plein : gardé pour plus tard')
p3.invFull = false
env.TriggerEvent('elyzea:server:playerLoaded', 3)
env.TriggerEvent('elyzea:server:playerLoaded', 3)
run(6000)
check(count(3, 'pesos') == held + R.menu[A].cola.price, 'reconnexion : pesos rendus une seule fois')
check(#MySQL.query.await('SELECT * FROM `rs_refunds` WHERE `citizenid` = ?', { 'CLI3' }) == 0, 'rs_refunds vidé')
r = pub(3, 'order', { shop = A, method = 'pesos', lines = { { id = 'cola', qty = 2 } } })
check(r.ok, 'commande en pesos pour les statistiques')
local fin = req(2, 'finance')
check(fin.methods and fin.methods.pesos and fin.methods.pesos.n >= 1 and fin.methods.pesos.paid >= 2 * R.menu[A].cola.price, 'finances : ventes en pesos comptées à part')
local dash = req(2, 'dashboard')
check(dash.last and dash.last[1] and dash.last[1].method == 'pesos' and tonumber(dash.last[1].paid) == 2 * R.menu[A].cola.price, 'tableau de bord : dernière commande affichée en pesos')
check(adm(1, 'catalogSet', { id = A, all = true }).ok and R.shops[A].options.catalog == nil, 'staff : retour à « tout le catalogue »')

P('\n[Mini-jeux : tous les jeux, toutes les difficultés]')
math.randomseed(7)
local platProduct = { cat = 'japonais', cook = true }
for _, game in ipairs({ 'burger', 'pizza', 'drink', 'dessert', 'fries', 'plat' }) do
    local okAll, badAll = true, true
    for d = 1, 3 do
        for _ = 1, 30 do
            local p = RSGames.Generate(game, d, 4, nil, platProduct)
            if not RSGames.Check(game, p, solve(game, p), 60000) then okAll = false end
            local wrong = solve(game, p)
            if game == 'burger' then wrong.gauge[1] = p.cook[1].to + 5
            elseif game == 'pizza' then wrong.spots[1] = { x = 0, y = 0 }
            elseif game == 'drink' then wrong.level = p.to + 3
            elseif game == 'dessert' then wrong.picked[1] = 'inconnu'
            elseif game == 'fries' then wrong.t = p.to + 3
            elseif game == 'plat' then wrong.gauge = p.cook.to + 5 end
            if RSGames.Check(game, p, wrong, 60000) then badAll = false end
        end
    end
    check(okAll, game .. ' : bonne réponse acceptée (90 défis)')
    check(badAll, game .. ' : mauvaise réponse refusée (90 défis)')
end
check(not RSGames.Check('burger', RSGames.Generate('burger', 1, 4), 'texte', 1), 'résultat non-table refusé')

P('\n[Erreurs Lua]')
check(#errors == 0, ('aucune erreur Lua (%d)'):format(#errors))
return fails
