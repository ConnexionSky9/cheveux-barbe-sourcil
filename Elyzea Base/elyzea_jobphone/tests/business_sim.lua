-- =====================================================================
--  Simulation hors jeu des ENTREPRISES : vrais scripts serveur
--    · elyzea_jobphone : config.lua, server/main.lua, server/business.lua
--    · elyzea_aura     : config.lua, server/main.lua (téléphone perso)
--  chargés ensemble, reliés par leurs exports, sur une vraie base MariaDB.
--  Imités : natives FiveM, elyzea_core, pont d'un métier (restaurant,
--  2 établissements), admin_menu (portes de l'éditeur de map).
-- =====================================================================
local ROOT, MySQL = ...
local passes, fails = 0, 0
local function P(...) print(...) end
local function check(ok, label)
    if ok then passes = passes + 1 P('  ok   ' .. label) else fails = fails + 1 P('  ÉCHEC ' .. label) end
end

-- JSON minimal
local json = {}
do
    local function esc(s) return s:gsub('[%c"\\]', function(c) local m = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n' } return m[c] or ('\\u%04x'):format(c:byte()) end) end
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
            local out = {} i = i + 1
            while true do
                local c = s:sub(i, i)
                if c == '"' then i = i + 1 break end
                if c == '\\' then local n = s:sub(i + 1, i + 1) out[#out + 1] = ({ n = '\n', ['"'] = '"', ['\\'] = '\\', ['/'] = '/' })[n] or n i = i + 2
                else out[#out + 1] = c i = i + 1 end
            end
            return table.concat(out)
        end
        function val()
            ws()
            local c = s:sub(i, i)
            if c == '{' then local t = {} i = i + 1 ws() if s:sub(i, i) == '}' then i = i + 1 return t end
                while true do ws() local k = str() ws() i = i + 1 t[k] = val() ws() local d = s:sub(i, i) i = i + 1 if d == '}' then break end end return t
            elseif c == '[' then local t = {} i = i + 1 ws() if s:sub(i, i) == ']' then i = i + 1 return t end
                while true do t[#t + 1] = val() ws() local d = s:sub(i, i) i = i + 1 if d == ']' then break end end return t
            elseif c == '"' then return str()
            elseif s:sub(i, i + 3) == 'true' then i = i + 4 return true
            elseif s:sub(i, i + 4) == 'false' then i = i + 5 return false
            elseif s:sub(i, i + 3) == 'null' then i = i + 4 return nil
            else local num = s:match('^-?%d+%.?%d*[eE]?[-+]?%d*', i) i = i + #num return tonumber(num) end
        end
        if type(s) ~= 'string' or s == '' then return nil end
        return val()
    end
end

-- Horloge et fils
local GT = 0
local threads, errors = {}, {}
local function CreateThread(fn) threads[#threads + 1] = { co = coroutine.create(fn), at = GT } end
local function Wait(ms) coroutine.yield(ms or 0) end
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
                    if not ok then errors[#errors + 1] = tostring(w) P('  erreur Lua : ' .. tostring(w)) end
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
-- Appel « dans un fil » (les scripts attendent la base avec .await)
local function call(fn, ...)
    local args, res, done = table.pack(...), nil, false
    CreateThread(function() res = table.pack(fn(table.unpack(args, 1, args.n))) done = true end)
    run(10)
    if not done then run(20000) end
    return table.unpack(res or {}, 1, res and res.n or 0)
end

-- ---------------------------------------------------------------------
-- Monde : joueurs, notifications, événements client
-- ---------------------------------------------------------------------
local players, notes, client = {}, {}, {}
local function makePlayer(src, cid, first, last, emp)
    players[src] = { src = src, cid = cid, first = first, last = last, emp = emp }
    notes[src] = {}
end
local function ev(src, name) local out = {} for _, e in ipairs(client) do if e.src == src and e.name == name then out[#out + 1] = e.args end end return out end
local function lastEv(src, name) local l = ev(src, name) return l[#l] end
local function clearEv() client = {} end
local function noteHas(src, pat) for _, n in ipairs(notes[src] or {}) do if tostring(n):find(pat, 1, true) then return true end end return false end

local core = {
    Notify = function(_, src, msg) if notes[src] then table.insert(notes[src], msg) end end,
    GetPlayer = function(_, src)
        local p = players[tonumber(src) or -1]
        if not p then return nil end
        return { PlayerData = { citizenid = p.cid, charinfo = { firstname = p.first, lastname = p.last }, job = { name = 'x' } },
            Functions = { GetItemByName = function() return {} end, GetMoney = function() return 0 end } }
    end,
    GetPlayerByCitizenId = function() return nil end,
    GetSourceByCitizenId = function(_, cid) for s, p in pairs(players) do if p.cid == cid then return s end end end,
}

-- Pont d'un métier (restaurant, 2 établissements) : mêmes opérations que server/phone.lua
local units = {
    { unit = 'elyzea_restaurant:1', label = 'Pizza This', color = '#ef4444', enabled = true },
    { unit = 'elyzea_restaurant:2', label = 'Taco Libre', color = '#f59e0b', enabled = true },
}
local function meOf(src)
    local p = players[src]
    if not p or not p.emp then return nil end
    local e = p.emp
    return { res = 'elyzea_restaurant', unit = e.unit, unitLabel = e.unit == units[1].unit and 'Pizza This' or 'Taco Libre', cid = p.cid,
        name = p.first .. ' ' .. p.last, numberKey = e.unit, matricule = 'RS-00' .. src, grade = e.boss and 'Patron' or 'Commis', level = e.boss and 5 or 1,
        duty = e.duty, canDuty = true, tablet = true, canOpen = e.boss == true, times = { session = 0, total = 0 }, status = 'available' }
end
local function crewOf(unit)
    local l = {}
    for s, p in pairs(players) do if p.emp and p.emp.unit == unit and p.emp.duty then l[#l + 1] = s end end
    table.sort(l)
    return l
end
local bridge = {
    PhoneBridge = function(_, op, src, data)
        if op == 'me' then return meOf(src) end
        if op == 'units' then
            local out = {}
            for _, u in ipairs(units) do out[#out + 1] = { unit = u.unit, label = u.label, color = u.color, enabled = u.enabled, onDuty = #crewOf(u.unit) } end
            return out
        end
        if op == 'unitCrew' then return crewOf(data.unit) end
        if op == 'crew' then local m = meOf(src) return m and crewOf(m.unit) or {} end
        if op == 'roster' then return {} end
        return nil
    end,
}

-- admin_menu : portes de l'éditeur de map
local doors = {
    { id = 1, name = 'Entrée Pizza This', locked = true, business = 'elyzea_restaurant:1' },
    { id = 2, name = 'Porte arrière Pizza This', locked = true, business = 'elyzea_restaurant:1' },
    { id = 3, name = 'Entrée Taco Libre', locked = true, business = 'elyzea_restaurant:2' },
    { id = 4, name = 'Porte sans entreprise', locked = true },
}
local adminLogs = {}
local adminMenu = {
    GetBusinessDoors = function(_, unit)
        local out = {}
        for _, d in ipairs(doors) do if d.business == unit then out[#out + 1] = { id = d.id, name = d.name, locked = d.locked } end end
        return out
    end,
    SetDoorLocked = function(_, id, locked) for _, d in ipairs(doors) do if d.id == id then d.locked = locked == true return true end end return false end,
    AddLog = function(_, src, a, d) adminLogs[#adminLogs + 1] = a .. ' ' .. tostring(d) end,
    HasPermission = function() return false end,
}

-- ---------------------------------------------------------------------
-- Deux ressources : chacune son environnement et ses exports
-- ---------------------------------------------------------------------
local resExports, callbacks, handlers = {}, {}, {}
local function proxy(res)
    return setmetatable({}, { __index = function(_, k)
        return function(_, ...)
            local f = resExports[res] and resExports[res][k]
            if not f then error(('export %s:%s absent'):format(res, k)) end
            return f(...)
        end
    end })
end
local STARTED = { elyzea_jobphone = true, elyzea_aura = true, admin_menu = true, elyzea_core = true, elyzea_restaurant = true, ['pma-voice'] = true }
local function makeEnv(res)
    local env = {}
    env.json, env.vector3 = json, function(x, y, z) return { x = x, y = y, z = z } end
    env.CreateThread, env.Wait = CreateThread, Wait
    env.SetTimeout = function(ms, fn) CreateThread(function() Wait(ms) fn() end) end
    env.GetGameTimer = function() return GT end
    env.os = setmetatable({ time = function(t) if t then return os.time(t) end return 1800000000 + GT // 1000 end }, { __index = os })
    env.MySQL = MySQL
    env.print = function(...)
        local s = table.concat({ ... }, ' ')
        -- Avertissements de configuration d'Aura (clé photo absente du dépôt) : pas des erreurs de code
        if s:find('Appareil photo', 1, true) or s:find('Fivemanage', 1, true) then return end
        if s:find('%^1') then errors[#errors + 1] = s P('  ' .. s) end
    end
    env.exports = setmetatable({ elyzea_core = core, elyzea_restaurant = bridge, admin_menu = adminMenu,
        elyzea_jobphone = proxy('elyzea_jobphone'), elyzea_aura = proxy('elyzea_aura') }, {
        __call = function(_, name, fn) resExports[res] = resExports[res] or {} resExports[res][name] = fn end,
        __index = function(_, k) return setmetatable({}, { __index = function() return function() return nil end end }) end,
    })
    env.GetResourceState = function(r) return STARTED[r] and 'started' or 'missing' end
    env.GetCurrentResourceName = function() return res end
    env.LoadResourceFile = function(r, f) local h = io.open(ROOT .. '/../' .. r .. '/' .. f, 'r') if not h then return nil end local s = h:read('a') h:close() return s end
    env.Ely = { callback = { register = function(n, fn) callbacks[n] = fn end } }
    env.RegisterNetEvent = function(name, fn) if fn then handlers[res .. '|' .. name] = handlers[res .. '|' .. name] or {} table.insert(handlers[res .. '|' .. name], fn) end end
    env.AddEventHandler = function(name, fn) handlers[res .. '|' .. name] = handlers[res .. '|' .. name] or {} table.insert(handlers[res .. '|' .. name], fn) end
    env.TriggerEvent = function() end
    env.TriggerClientEvent = function(name, src, ...) client[#client + 1] = { src = src, name = name, args = ... } end
    env.TriggerLatentClientEvent = env.TriggerClientEvent
    env.GetPlayerName = function(src) local p = players[tonumber(src) or -1] return p and (p.first .. ' ' .. p.last) or nil end
    env.GetPlayers = function() local t = {} for s in pairs(players) do t[#t + 1] = tostring(s) end return t end
    env.GetPlayerIdentifiers = function() return {} end
    env.GetPlayerPed = function(src) return src end
    env.GetEntityCoords = function() return { x = 0.0, y = 0.0, z = 0.0 } end
    env.RegisterCommand = function() end
    env.GlobalState, env.source = {}, 0
    env.Player = function() return { state = {} } end
    -- Natives inconnues : fonction vide (ces scripts en appellent beaucoup qui ne servent pas ici)
    setmetatable(env, { __index = function(_, k) local v = _G[k] if v ~= nil then return v end return function() return nil end end })
    return env
end
local function loadInto(env, root, path)
    local f = assert(io.open(root .. '/' .. path, 'r'))
    local s = f:read('a') f:close()
    assert(load(s, '@' .. path, 't', env))()
end

local J, A = makeEnv('elyzea_jobphone'), makeEnv('elyzea_aura')
for _, f in ipairs({ 'config.lua', 'server/main.lua', 'server/business.lua' }) do loadInto(J, ROOT, f) end
loadInto(A, ROOT .. '/../elyzea_aura', 'config.lua')
A.Config.Framework = 'elyzea'
loadInto(A, ROOT .. '/../elyzea_aura', 'server/main.lua')

-- Joueurs : 1 client, 2 patron Pizza This (en service), 3 commis Pizza This (en service), 4 commis hors service, 5 patron Taco (hors service)
makePlayer(1, 'CLI1', 'Claire', 'Cliente')
makePlayer(2, 'EMP2', 'Paul', 'Patron', { unit = 'elyzea_restaurant:1', duty = true, boss = true })
makePlayer(3, 'EMP3', 'Kevin', 'Commis', { unit = 'elyzea_restaurant:1', duty = true })
makePlayer(4, 'EMP4', 'Lea', 'Repos', { unit = 'elyzea_restaurant:1', duty = false })
makePlayer(5, 'EMP5', 'Tom', 'Taco', { unit = 'elyzea_restaurant:2', duty = false, boss = true })
run(3000)

-- Requêtes
local function jp(src, action, data) GT = GT + 1500 return call(callbacks['jobphone:req'], src, action, data or {}) end
local function aura(src, name, args)
    GT = GT + 1500
    local before = #client
    call(function() A.source = src for _, fn in ipairs(handlers['elyzea_aura|elyzea_aura:server:cb'] or {}) do fn(name, 99, args or {}) end end)
    for i = #client, before + 1, -1 do local e = client[i] if e.src == src and e.name == 'elyzea_aura:client:cb' then return select(2, table.unpack(e.args)) end end
end
-- TriggerClientEvent garde le 1er argument seulement : on le reprend en entier
J.TriggerClientEvent = function(name, src, ...) client[#client + 1] = { src = src, name = name, args = ... } end
A.TriggerClientEvent = function(name, src, ...) client[#client + 1] = { src = src, name = name, args = table.pack(...) } end
local function auraRes(src, name, args)
    GT = GT + 1500
    local before = #client
    call(function() A.source = src for _, fn in ipairs(handlers['elyzea_aura|elyzea_aura:server:cb'] or {}) do fn(name, 99, args or {}) end end)
    for i = #client, before + 1, -1 do local e = client[i] if e.src == src and e.name == 'elyzea_aura:client:cb' then return e.args[2] end end
end
aura = auraRes

P('\n[Démarrage]')
check(J.JP.ready and J.JP.Biz.ready, 'téléphone de service prêt (tables jobphone_business, jobphone_biz_messages)')
local myNum = (auraRes(1, 'getConversations') and A ~= nil) and call(function() return resExports.elyzea_aura.GetPhoneNumber(1) end)
check(type(myNum) == 'string' and myNum:match('^555%-%d%d%d%d$'), 'téléphone perso du client : numéro ' .. tostring(myNum))

P('\n[Annuaire des entreprises (appli « Services »)]')
local r = auraRes(1, 'servicesList')
check(r and r.ok and #r.list == 2, 'servicesList : 2 entreprises (les 2 restaurants)')
local pizza, taco
for _, b in ipairs(r.list or {}) do if b.label == 'Pizza This' then pizza = b elseif b.label == 'Taco Libre' then taco = b end end
check(pizza and pizza.number and pizza.number:match('^918%-%d%d%d%d$'), 'numéro public de Pizza This : ' .. tostring(pizza and pizza.number))
check(pizza and taco and pizza.number ~= taco.number, 'numéros publics différents')
check(pizza and pizza.open == false and pizza.onDuty == 2, 'Pizza This : fermée par défaut, 2 employés en service')
local again = call(function() return resExports.elyzea_jobphone.GetBusinesses() end)
check(again[1].number == r.list[1].number or again[2].number == r.list[1].number, 'numéros conservés (même numéro au 2e appel)')
local row = MySQL.single.await('SELECT * FROM `jobphone_business` WHERE `unit` = ?', { 'elyzea_restaurant:1' })
check(row and row.number == pizza.number, 'numéro enregistré en base')

P('\n[Appli « Entreprise » : ouvrir / fermer + portes]')
r = jp(4, 'biz', { op = 'state' })
check(r.error and r.error:find('service'), 'hors service : appli verrouillée')
r = jp(3, 'biz', { op = 'state' })
check(r.business and r.business.label == 'Pizza This' and r.canOpen == false and #r.doors == 2, 'commis : voit l\'entreprise et ses 2 portes principales, sans droit d\'ouvrir')
check((jp(3, 'biz', { op = 'toggle', data = { open = true } }).error or ''):find('grade'), 'commis : ouverture refusée (grade)')
check(doors[1].locked and doors[2].locked, 'portes toujours verrouillées')
clearEv()
r = jp(2, 'biz', { op = 'toggle', data = { open = true } })
check(r.ok and r.open == true, 'patron : entreprise ouverte · ' .. tostring(r.message or r.error))
check(not doors[1].locked and not doors[2].locked, 'les 2 portes principales de Pizza This sont déverrouillées')
check(doors[3].locked and doors[4].locked, 'portes des autres entreprises / sans entreprise : inchangées')
check(noteHas(3, 'a ouvert'), 'collègue en service prévenu')
check(tonumber(MySQL.scalar.await('SELECT `open` FROM `jobphone_business` WHERE `unit` = ?', { 'elyzea_restaurant:1' })) == 1, 'état « ouverte » enregistré en base')
r = auraRes(1, 'servicesList')
local p2 for _, b in ipairs(r.list) do if b.label == 'Pizza This' then p2 = b end end
check(p2 and p2.open == true, 'appli « Services » : Pizza This affichée ouverte')

P('\n[Message d\'un client → entreprise → réponse]')
clearEv()
r = auraRes(1, 'sendMessage', { number = pizza.number, message = 'Bonjour, vous livrez ce soir ?' })
check(r and r.ok, 'client : message envoyé au numéro public')
local inbox = MySQL.query.await('SELECT * FROM `jobphone_biz_messages` WHERE `unit` = ?', { 'elyzea_restaurant:1' })
check(#inbox == 1 and inbox[1].client_number == myNum and inbox[1].client_name == 'Claire Cliente' and inbox[1].direction == 'in', 'message rangé pour Pizza This (numéro + nom du client)')
check(#ev(2, 'elyzea_jobphone:client:bizMessage') == 1 and #ev(3, 'elyzea_jobphone:client:bizMessage') == 1, 'employés en service prévenus sur le téléphone de service')
check(#ev(4, 'elyzea_jobphone:client:bizMessage') == 0 and #ev(5, 'elyzea_jobphone:client:bizMessage') == 0, 'hors service / autre entreprise : pas prévenus')
r = jp(3, 'biz', { op = 'state' })
check(r.unread == 1 and #r.threads == 1 and r.threads[1].name == 'Claire Cliente', 'appli Entreprise : 1 conversation non lue')
r = jp(3, 'biz', { op = 'thread', data = { number = myNum } })
check(#r.list == 1 and r.list[1].body:find('livrez'), 'conversation ouverte')
check(jp(3, 'biz', { op = 'state' }).unread == 0, 'marquée lue')
clearEv()
r = jp(3, 'biz', { op = 'reply', data = { number = myNum, body = 'Oui, jusqu\'à 23 h !' } })
check(r.ok, 'employé : réponse envoyée')
local back = MySQL.single.await('SELECT * FROM `elyzea_messages` WHERE `sender` = ? AND `receiver` = ?', { pizza.number, myNum })
check(back and back.message:find('23 h'), 'réponse dans les Messages du client, envoyée par le numéro public')
local nm = lastEv(1, 'elyzea_aura:client:newMessage')
check(nm and nm[1] and nm[1].from == pizza.number, 'client connecté : notification de nouveau message')
check(jp(3, 'biz', { op = 'reply', data = { number = '555-0000', body = 'spam' } }).error ~= nil, 'réponse à un numéro qui n\'a jamais écrit : refusée')
check(jp(5, 'biz', { op = 'thread', data = { number = myNum } }).error ~= nil or #(jp(5, 'biz', { op = 'thread', data = { number = myNum } }).list or {}) == 0, 'autre entreprise : ne voit pas la conversation')

P('\n[Appel d\'un client → entreprise]')
clearEv()
r = auraRes(1, 'startCall', { number = pizza.number })
check(r and r.ok and r.id, 'client : appel lancé vers le numéro public')
local auraId = r and r.id
local in2, in3 = lastEv(2, 'elyzea_jobphone:client:call'), lastEv(3, 'elyzea_jobphone:client:call')
check(in2 and in2.state == 'incoming' and in3 and in3.state == 'incoming' and in2.business == 'Pizza This', 'ça sonne sur le téléphone de service des 2 employés en service')
check(#ev(4, 'elyzea_jobphone:client:call') == 0, 'employé hors service : ne sonne pas')
local jid = in2.id
clearEv()
r = jp(3, 'answer', { id = jid })
check(r.ok, 'commis décroche')
local act = lastEv(3, 'elyzea_jobphone:client:call')
check(act and act.state == 'active' and act.channel == auraId, 'commis en ligne, canal de voix = celui de l\'appel du client')
local st = lastEv(1, 'elyzea_aura:client:callStarted')
check(st and st[1] and st[1].id == auraId, 'client : appel décroché (même canal)')
local e2 = lastEv(2, 'elyzea_jobphone:client:call')
check(e2 and e2.state == 'ended', 'patron : la sonnerie s\'arrête (décroché par un collègue)')
check(jp(2, 'answer', { id = jid }).error ~= nil, 'patron ne peut plus décrocher')
clearEv()
auraRes(1, 'endCall', { id = auraId })
local e3 = lastEv(3, 'elyzea_jobphone:client:call')
check(e3 and e3.state == 'ended', 'client raccroche : fin d\'appel chez le commis')
check(J.JP.inCall[3] == nil and J.JP.calls[jid] == nil, 'commis libéré')

-- Raccroché côté employé
r = auraRes(1, 'startCall', { number = pizza.number })
auraId = r.id
jid = lastEv(2, 'elyzea_jobphone:client:call').id
jp(2, 'answer', { id = jid })
clearEv()
jp(2, 'hangup', {})
check(lastEv(1, 'elyzea_aura:client:callEnded') ~= nil, 'employé raccroche : fin d\'appel chez le client')
check(auraRes(1, 'startCall', { number = pizza.number }).ok, 'client peut rappeler')

-- Tous refusent
jid = lastEv(2, 'elyzea_jobphone:client:call').id
clearEv()
jp(2, 'hangup', { id = jid })
check(lastEv(1, 'elyzea_aura:client:callEnded') == nil, 'un employé refuse : ça sonne encore chez l\'autre')
jp(3, 'hangup', { id = jid })
local ce = lastEv(1, 'elyzea_aura:client:callEnded')
check(ce and ce[1] and ce[1].reason == 'declined', 'tous refusent : « Appel refusé » chez le client')

-- Sans réponse
r = auraRes(1, 'startCall', { number = pizza.number })
jid = lastEv(2, 'elyzea_jobphone:client:call').id
clearEv()
run(31000)
ce = lastEv(1, 'elyzea_aura:client:callEnded')
check(ce and ce[1].reason == 'timeout' and J.JP.calls[jid] == nil, 'sans réponse en 30 s : appel terminé des deux côtés')
check(lastEv(2, 'elyzea_jobphone:client:call') and lastEv(2, 'elyzea_jobphone:client:call').state == 'ended', 'sonnerie arrêtée chez les employés')

P('\n[Entreprise fermée / personne en service]')
r = auraRes(1, 'startCall', { number = taco.number })
check(r and not r.ok and (r.error or ''):find('fermée'), 'Taco Libre fermée : appel refusé (« laissez-lui un message ») · ' .. tostring(r and r.error))
check(auraRes(1, 'sendMessage', { number = taco.number, message = 'Ouvert demain ?' }).ok, 'message possible même fermée')
check(#MySQL.query.await('SELECT * FROM `jobphone_biz_messages` WHERE `unit` = ?', { 'elyzea_restaurant:2' }) == 1, 'message gardé pour Taco Libre')
players[5].emp.duty = true
check(jp(5, 'biz', { op = 'toggle', data = { open = true } }).ok and not doors[3].locked, 'patron Taco ouvre : sa porte se déverrouille')
players[5].emp.duty = false
r = auraRes(1, 'startCall', { number = taco.number })
check(r and not r.ok and (r.error or ''):find('Personne'), 'ouverte mais personne en service : « laissez-lui un message »')

P('\n[Fermeture]')
clearEv()
r = jp(2, 'biz', { op = 'toggle', data = { open = false } })
check(r.ok and r.open == false and doors[1].locked and doors[2].locked, 'patron ferme : les 2 portes se reverrouillent')
check(not doors[3].locked, 'porte de Taco Libre (ouverte) inchangée')
check(#adminLogs >= 2, 'ouverture / fermeture dans les logs admin')
units[1].enabled = false
r = call(function() return resExports.elyzea_jobphone.GetBusinesses() end)
local dis for _, b in ipairs(r) do if b.unit == 'elyzea_restaurant:1' then dis = b end end
check(dis and dis.disabled and not dis.open, 'restaurant désactivé par le staff : affiché indisponible')
check((jp(2, 'biz', { op = 'toggle', data = { open = true } }).error or ''):find('staff'), 'désactivé : ouverture refusée')

P('\n[Erreurs Lua]')
check(#errors == 0, ('aucune erreur Lua (%d)'):format(#errors))
return fails
