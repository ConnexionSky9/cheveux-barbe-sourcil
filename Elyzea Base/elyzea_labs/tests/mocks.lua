-- Simulations FiveM, base de données, inventaire, groupes (elyzea_illegal) et admin_menu pour les tests hors jeu
local M = {}
_PRINT = print
-- ---------------------------------------------------------------- JSON minimal
json = {}
local function enc(v)
    local t = type(v)
    if t == 'nil' then return 'null' elseif t == 'boolean' then return tostring(v) elseif t == 'number' then return string.format('%.14g', v)
    elseif t == 'string' then return '"' .. v:gsub('[%c"\\]', function(c) return string.format('\\u%04x', c:byte()) end) .. '"' end
    local n, isArr = 0, true
    for k in pairs(v) do n = n + 1 if type(k) ~= 'number' then isArr = false end end
    if n == 0 then return '[]' end
    if isArr and #v == n then local o = {} for i = 1, #v do o[i] = enc(v[i]) end return '[' .. table.concat(o, ',') .. ']' end
    local o = {} for k, x in pairs(v) do o[#o + 1] = enc(tostring(k)) .. ':' .. enc(x) end return '{' .. table.concat(o, ',') .. '}'
end
json.encode = enc
function json.decode(s)
    local i = 1
    local function ws() i = s:find('[^%s]', i) or #s + 1 end
    local val
    local function str()
        local o = {} i = i + 1
        while true do
            local c = s:sub(i, i)
            if c == '"' then i = i + 1 return table.concat(o) end
            if c == '\\' then local n = s:sub(i + 1, i + 1)
                if n == 'u' then o[#o + 1] = string.char(tonumber(s:sub(i + 2, i + 5), 16)) i = i + 6 else o[#o + 1] = ({ n = '\n', t = '\t' })[n] or n i = i + 2 end
            else o[#o + 1] = c i = i + 1 end
        end
    end
    function val()
        ws()
        local c = s:sub(i, i)
        if c == '{' then local o = {} i = i + 1 ws() if s:sub(i, i) == '}' then i = i + 1 return o end
            while true do ws() local k = str() ws() i = i + 1 o[k] = val() ws() local d = s:sub(i, i) i = i + 1 if d == '}' then return o end end
        elseif c == '[' then local o = {} i = i + 1 ws() if s:sub(i, i) == ']' then i = i + 1 return o end
            while true do o[#o + 1] = val() ws() local d = s:sub(i, i) i = i + 1 if d == ']' then return o end end
        elseif c == '"' then return str()
        elseif s:sub(i, i + 3) == 'true' then i = i + 4 return true
        elseif s:sub(i, i + 4) == 'false' then i = i + 5 return false
        elseif s:sub(i, i + 3) == 'null' then i = i + 4 return nil
        else local n = s:match('^-?[%d%.eE+-]+', i) i = i + #n return tonumber(n) end
    end
    if type(s) ~= 'string' then error('json') end
    return val()
end

-- ---------------------------------------------------------------- temps, fils, événements
M.now, M.ms = 1704135600, 0     -- 2024-01-01 19:00 UTC (lundi)
os.time = function(t) if t then return M.now end return M.now end
function GetGameTimer() return M.ms end
local threads = {}
function CreateThread(f) threads[#threads + 1] = coroutine.create(f) end
function Wait() coroutine.yield() end
local timeouts = {}
function SetTimeout(ms, f) timeouts[#timeouts + 1] = f end
function M.Pump(n)
    for _ = 1, n or 1 do
        for _, co in ipairs(threads) do
            if coroutine.status(co) == 'suspended' then local ok, e = coroutine.resume(co) if not ok then error(e) end end
        end
    end
end
function M.RunTimeouts() local t = timeouts timeouts = {} for _, f in ipairs(t) do f() end end
M.handlers, M.events, M.callbacks, M.exports, M.commands = {}, {}, {}, {}, {}
function RegisterNetEvent(n, f) if f then M.handlers[n] = f end end
function AddEventHandler(n, f) M.handlers[n] = M.handlers[n] or f end
function TriggerClientEvent(n, src, ...) M.events[#M.events + 1] = { name = n, src = src, args = { ... } } end
function RegisterCommand(n, f) M.commands[n] = f end
Ely = { callback = { register = function(n, f) M.callbacks[n] = f end } }
function GetResourceState(r) return (M.stopped or {})[r] and 'stopped' or 'started' end
function GetCurrentResourceName() return 'elyzea_labs' end
local KV = {}
function GetResourceKvpString(k) return KV[k] end
function SetResourceKvp(k, v) KV[k] = v end
function DeleteResourceKvp(k) KV[k] = nil end

vector3 = function(x, y, z) return setmetatable({ x = x, y = y, z = z or 0 }, M.vmt) end
vector2 = function(x, y) return setmetatable({ x = x, y = y, z = 0 }, M.vmt) end
M.vmt = { __sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)) end,
    __add = function(a, b) return vector3(a.x + b.x, a.y + b.y, (a.z or 0) + (b.z or 0)) end,
    __len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + (a.z or 0) * (a.z or 0)) end }

-- ---------------------------------------------------------------- joueurs
M.players = {}   -- [src] = { pos, health, bucket, vehicle, name, cid }
function M.AddPlayer(src, cid, pos) M.players[src] = { pos = pos, health = 200, bucket = 0, vehicle = 0, name = 'P' .. src, cid = cid } return M.players[src] end
function GetPlayerPed(src) return M.players[src] and (1000 + src) or 0 end
function GetEntityCoords(ped) local p = M.players[ped - 1000] return p and p.pos end
function GetEntityHeading() return 90.0 end
function GetEntityHealth(ped) local p = M.players[ped - 1000] return p and p.health or 0 end
function GetVehiclePedIsIn(ped) local p = M.players[ped - 1000] return p and p.vehicle or 0 end
function GetPlayerRoutingBucket(src) return M.players[src] and M.players[src].bucket or 0 end
function SetPlayerRoutingBucket(src, b) if M.players[src] then M.players[src].bucket = b end end
function GetPlayerName(src) return M.players[src] and M.players[src].name or nil end
function GetPlayers() local t = {} for s in pairs(M.players) do t[#t + 1] = tostring(s) end table.sort(t) return t end

-- ---------------------------------------------------------------- base de données simulée
M.db = { labs = {}, labs_equipment = {}, labs_raids = {}, labs_settings = {}, labs_logs = {}, seq = {} }
local function nextId(t) M.db.seq[t] = (M.db.seq[t] or 0) + 1 return M.db.seq[t] end
local function find(t, id) for _, r in ipairs(M.db[t]) do if r.id == id then return r end end end
local function sqlFn(sql, p)
    p = p or {}
    local s = sql:gsub('%s+', ' ')
    if s:match('^CREATE TABLE') or s:match('^DELETE FROM `labs_logs` WHERE `created_at`') then return {} end
    if s:match("^INSERT INTO `labs_settings`") then
        local k, v = p[1], p[2]
        if s:match("VALUES %('schema'") then k, v = 'schema', p[1] end
        for _, r in ipairs(M.db.labs_settings) do if r.k == k then r.v = v return 1 end end
        M.db.labs_settings[#M.db.labs_settings + 1] = { k = k, v = v } return 1
    end
    if s:match("^UPDATE `labs_raids` SET `status` = 'cancelled', `reason` = 'Redémarrage") then
        local n = 0 for _, r in ipairs(M.db.labs_raids) do if r.status == 'preparing' or r.status == 'active' then r.status = 'cancelled' n = n + 1 end end return n end
    if s:match('^SELECT `k`, `v` FROM `labs_settings`') then return M.db.labs_settings end
    if s:match('^SELECT %* FROM `labs`$') then local o = {} for _, r in ipairs(M.db.labs) do o[#o + 1] = r end return o end
    if s:match('^SELECT %* FROM `labs_equipment`') then return M.db.labs_equipment end
    if s:match('MAX%(`ended_at`%)') then
        local best = {}
        for _, r in ipairs(M.db.labs_raids) do if (r.status == 'success' or r.status == 'failed') and r.ended then best[r.lab_id] = math.max(best[r.lab_id] or 0, r.ended) end end
        local o = {} for id, t in pairs(best) do o[#o + 1] = { lab_id = id, t = t } end return o
    end
    if s:match('^INSERT INTO `labs_logs`') then M.db.labs_logs[#M.db.labs_logs + 1] = { lab_id = p[1], kind = p[2], actor = p[3], detail = p[4] } return nextId('logs') end
    if s:match('^INSERT INTO `labs` ') then
        local id = nextId('labs')
        M.db.labs[#M.db.labs + 1] = { id = id, name = p[1], interior = p[2], x = p[3], y = p[4], z = p[5], h = p[6], price = p[7], level = 1, xp = 0, perms = '{}', upgrades = '[]', disabled = 0 }
        return id
    end
    if s:match('^UPDATE `labs` SET `owner_group` = %?, `owner_since` = NOW%(%), `code_hash` = %?, `code_salt` = %?, `perms` = \'{}\' WHERE `id` = %? AND `owner_group` IS NULL') then
        local r = find('labs', p[4]) if not r or r.owner_group then return 0 end r.owner_group, r.code_hash, r.code_salt, r.perms = p[1], p[2], p[3], '{}' return 1 end
    if s:match('^UPDATE `labs` SET `owner_group` = %?, `owner_since` = NOW%(%)') then
        local r = find('labs', p[4]) r.owner_group, r.code_hash, r.code_salt, r.perms = p[1], p[2], p[3], '{}' return 1 end
    if s:match('^UPDATE `labs` SET `owner_group` = NULL') then local r = find('labs', p[1]) r.owner_group, r.code_hash, r.code_salt, r.perms = nil, nil, nil, '{}' return 1 end
    if s:match('^UPDATE `labs` SET `xp` = `xp` %+ %?') then local r = find('labs', p[2]) r.xp = r.xp + p[1] return 1 end
    if s:match('^UPDATE `labs` SET `level` = %?, `upgrades` = %? WHERE `id` = %? AND `level` = %?') then
        local r = find('labs', p[3]) if r.level ~= p[4] then return 0 end r.level, r.upgrades = p[1], p[2] return 1 end
    if s:match('^UPDATE `labs` SET `level` = %?, `xp` = %?') then local r = find('labs', p[3]) r.level, r.xp = p[1], p[2] return 1 end
    if s:match('^UPDATE `labs` SET `code_hash` = %?, `code_salt` = %?') then local r = find('labs', p[3]) r.code_hash, r.code_salt = p[1], p[2] return 1 end
    if s:match('^UPDATE `labs` SET `perms` = %?') then local r = find('labs', p[2]) r.perms = p[1] return 1 end
    if s:match('^UPDATE `labs` SET `name` = %?') then local r = find('labs', p[5]) r.name, r.interior, r.price, r.disabled = p[1], p[2], p[3], p[4] return 1 end
    if s:match('^UPDATE `labs` SET `x` = %?') then local r = find('labs', p[5]) r.x, r.y, r.z, r.h = p[1], p[2], p[3], p[4] return 1 end
    if s:match('^INSERT INTO `labs_equipment`') then
        local id = nextId('eq')
        M.db.labs_equipment[#M.db.labs_equipment + 1] = { id = id, lab_id = p[1], type = p[2], placed = p[3], x = p[4], y = p[5], z = p[6], rx = p[7], ry = p[8], rz = p[9], price = p[10] }
        return id
    end
    if s:match('^UPDATE `labs_equipment` SET `placed` = 1') then local r = find('labs_equipment', p[7]) r.placed, r.x, r.y, r.z, r.rx, r.ry, r.rz = 1, p[1], p[2], p[3], p[4], p[5], p[6] return 1 end
    if s:match('^UPDATE `labs_equipment` SET `placed` = 0 WHERE `id`') then local r = find('labs_equipment', p[1]) r.placed = 0 return 1 end
    if s:match('^UPDATE `labs_equipment` SET `placed` = 0 WHERE `lab_id`') then for _, r in ipairs(M.db.labs_equipment) do if r.lab_id == p[1] then r.placed = 0 end end return 1 end
    if s:match('^DELETE FROM `labs_equipment` WHERE `id`') then
        for i, r in ipairs(M.db.labs_equipment) do if r.id == p[1] and r.lab_id == p[2] then table.remove(M.db.labs_equipment, i) return 1 end end return 0 end
    if s:match('^DELETE FROM `labs_equipment` WHERE `lab_id`') then for i = #M.db.labs_equipment, 1, -1 do if M.db.labs_equipment[i].lab_id == p[1] then table.remove(M.db.labs_equipment, i) end end return 1 end
    if s:match('^DELETE FROM `labs` WHERE') then for i, r in ipairs(M.db.labs) do if r.id == p[1] then table.remove(M.db.labs, i) end end return 1 end
    if s:match('^INSERT INTO `labs_raids`') then
        local id = nextId('raids')
        M.db.labs_raids[#M.db.labs_raids + 1] = { id = id, lab_id = p[1], attacker_group = p[2], defender_group = p[3], attacker_label = p[4], defender_label = p[5], status = p[6], started_by = p[7], t = M.now }
        return id
    end
    if s:match("^UPDATE `labs_raids` SET `status` = 'active'") then find('labs_raids', p[1]).status = 'active' return 1 end
    if s:match('^UPDATE `labs_raids` SET `status` = %?, `reason`') then local r = find('labs_raids', p[3]) r.status, r.reason, r.ended = p[1], p[2], M.now return 1 end
    if s:match('FROM `labs_raids`') then local o = {} for i = #M.db.labs_raids, 1, -1 do o[#o + 1] = M.db.labs_raids[i] end return o end
    if s:match('FROM `labs_logs`') then return M.db.labs_logs end
    error('SQL non simulée : ' .. s)
end
local function method() return setmetatable({ await = function(q, p) return sqlFn(q, p) end }, { __call = function(_, q, p, cb) local r = sqlFn(q, p) if cb then cb(r) end return r end }) end
MySQL = { query = method(), insert = method(), update = method(), scalar = method(), single = method() }
M.failTx = false
MySQL.transaction = { await = function(list)
    if M.failTx then return false end
    for _, q in ipairs(list) do sqlFn(q.query, q.values) end
    return true
end }

-- ---------------------------------------------------------------- inventaire
M.inv = {}           -- [src] = { item = n }
M.stashes, M.stashAccess, M.opened = {}, {}, {}
M.items = setmetatable({}, { __index = function(_, k) return (k ~= 'fake') and { label = 'L:' .. k } or nil end })
local invApi = {
    GetItemCount = function(src, item) return (M.inv[src] or {})[item] or 0 end,
    RemoveItem = function(src, item, n) local i = M.inv[src] or {} if (i[item] or 0) < n then return false end i[item] = i[item] - n return true end,
    AddItem = function(src, item, n) M.inv[src] = M.inv[src] or {} M.inv[src][item] = (M.inv[src][item] or 0) + n return true end,
    CanCarryItems = function(src) return not M.full end,
    Items = function(item) return M.items[item] end,
    GetItemList = function() return M.items end,
    RegisterStash = function(id, label, slots, weight) M.stashes[id] = { slots = slots, weight = weight } return true end,
    RegisterStashAccess = function(prefix, cb) M.stashAccess[prefix] = cb end,
    OpenInventory = function(src, kind, id)
        for prefix, cb in pairs(M.stashAccess) do if id:sub(1, #prefix) == prefix and not cb(src, id) then return false end end
        M.opened[#M.opened + 1] = { src = src, id = id } return true
    end,
}
-- ---------------------------------------------------------------- groupes (elyzea_illegal)
M.groups = {
    [1] = { id = 1, label = 'Ballas', grades = { { id = 11, label = 'Recrue', level = 1 }, { id = 12, label = 'Lieutenant', level = 2 }, { id = 13, label = 'Chef', level = 3, boss = true } }, dirty = 1000000 },
    [2] = { id = 2, label = 'Vagos', grades = { { id = 21, label = 'Soldat', level = 1 }, { id = 23, label = 'Patron', level = 3, boss = true } }, dirty = 1000000 },
}
M.members = {}   -- [src] = { group, grade }
local function gradeOf(g, id) for _, gr in ipairs(g.grades) do if gr.id == id then return gr end end end
local illegal = {
    GetPlayerGroupFull = function(src)
        local m = M.members[src] if not m then return nil end
        local g = M.groups[m.group] local gr = gradeOf(g, m.grade)
        return { id = g.id, label = g.label, gradeId = gr.id, gradeLevel = gr.level, boss = gr.boss == true }
    end,
    GetGroupInfo = function(gid) local g = M.groups[gid] if not g then return nil end return { id = g.id, label = g.label, grades = g.grades } end,
    GetGroupOnline = function(gid)
        local o = {} for src, m in pairs(M.members) do if m.group == gid and M.players[src] then o[#o + 1] = { src = src, gradeId = m.grade, boss = gradeOf(M.groups[gid], m.grade).boss == true } end end
        table.sort(o, function(a, b) return a.src < b.src end) return o
    end,
    GroupPay = function(gid, acc, amount) local g = M.groups[gid] if g.dirty < amount then return false, 'Solde insuffisant.' end g.dirty = g.dirty - amount return true end,
    GroupCredit = function(gid, acc, amount) M.groups[gid].dirty = M.groups[gid].dirty + amount return true end,
    GetGroupIds = function() return { { id = 1, label = 'Ballas' }, { id = 2, label = 'Vagos' } } end,
}
M.staff = {}
M.down = {}
exports = setmetatable({}, {
    __call = function(_, name, f) M.exports[name] = f end,
    __index = function(_, res)
        local api = res == 'elyzea_inventory' and invApi or res == 'elyzea_illegal' and illegal
            or res == 'admin_menu' and { HasPermission = function(src) return M.staff[src] == true end }
            or res == 'elyzea_ems' and { IsDown = function(src) return M.down[src] == true end }
            or res == 'elyzea_core' and { GetPlayer = function(src) local p = M.players[src] return p and { PlayerData = { citizenid = p.cid, charinfo = { firstname = p.name } } } end }
            or {}
        return setmetatable({}, { __index = function(_, fn) local f = api[fn] return function(_, ...) if not f then error('export simulé absent ' .. res .. ':' .. fn) end return f(...) end end })
    end,
})
print = function() end
MOCK = M
return M
